local lvgl = require("lvgl")
local dataman_ok, dataman = pcall(require, "dataman")
local topic_ok, topic = pcall(require, "topic")
local SCRIPT_PATH = rawget(_G, "SCRIPT_PATH") or ""
local DATAMAN_INVALID_VALUE = 2147483647
local PERIODIC_WEATHER_REFRESH_MINUTES = 10
local MAX_WEATHER_FILE_SIZE = 64 * 1024
local TOPIC_REFRESH_THROTTLE_SECONDS = 5
local MAX_DAILY_ITEMS = 31
local MAX_HOURLY_ITEMS = 168
local RECOVERY_TIMEOUT_SECONDS = 1800

local font_cache = {}
local file_exists_cache = {}
local label_text_cache = setmetatable({}, { __mode = "k" })
local last_bg_src = nil
local last_icon_src = nil
local last_topic_refresh_at = 0
local topic_subscribe_disabled = false
local topic_needs_refresh = false

local function file_exists(path)
  local cached = file_exists_cache[path]
  if cached ~= nil then
    return cached
  end
  local file = io.open(path, "r")
  if file then
    file:close()
    file_exists_cache[path] = true
    return true
  end
  file_exists_cache[path] = false
  return false
end

local function clamp_montserrat_size(size)
  if size <= 14 then
    return 14
  end
  if size <= 16 then
    return 16
  end
  if size <= 18 then
    return 18
  end
  if size <= 24 then
    return 24
  end
  return 32
end

local function safe_font(name, size)
  local cache_key = name .. ":" .. tostring(size)
  local cached = font_cache[cache_key]
  if cached ~= nil then
    return cached
  end

  local ok, font = pcall(lvgl.Font, name, size)
  if ok and font then
    font_cache[cache_key] = font
    return font
  end

  local fallback_key = "montserrat:" .. tostring(clamp_montserrat_size(size))
  local fallback = font_cache[fallback_key]
  if fallback ~= nil then
    font_cache[cache_key] = fallback
    return fallback
  end

  local fallback_ok, fallback_font = pcall(lvgl.Font, "montserrat", clamp_montserrat_size(size), "normal")
  if fallback_ok and fallback_font then
    font_cache[fallback_key] = fallback_font
    font_cache[cache_key] = fallback_font
    return fallback_font
  end

  font_cache[cache_key] = nil
  return nil
end

local use_misans = file_exists("/font/MiSans-Demibold.ttf")

local function get_text_font(size)
  if use_misans then
    return safe_font("MiSans-Demibold", size)
  end
  return safe_font("misansw_demibold", size)
end

local screen_w = lvgl.HOR_RES()
local screen_h = lvgl.VER_RES()

local root = lvgl.Object(nil, {
  w = screen_w,
  h = screen_h,
  bg_color = 0x0C111B,
  border_width = 0,
})
root:clear_flag(lvgl.FLAG.SCROLLABLE)
root:add_flag(lvgl.FLAG.EVENT_BUBBLE)

local function resolve_images_root()
  local candidates = {}
  if type(SCRIPT_PATH) == "string" then
    local normalized = SCRIPT_PATH:gsub("\\", "/")
    local replaced = normalized:gsub("/lua/?$", "/images/")
    table.insert(candidates, replaced)
    table.insert(candidates, normalized .. "../images/")
  end
  table.insert(candidates, "/watchface/images/")

  for _, path in ipairs(candidates) do
    if file_exists(path .. "weather-bgs/11.png") then
      return path
    end
  end
  return candidates[1]
end

local images_root = resolve_images_root()

local function img_path(relative)
  return images_root .. relative
end

local icon_path_cache = {}
local function get_icon_path(icon_code)
  local cached = icon_path_cache[icon_code]
  if not cached then
    cached = img_path("weather-icons/" .. icon_code .. ".png")
    icon_path_cache[icon_code] = cached
  end
  return cached
end

local bg_path_cache = {}
local function get_bg_path(code)
  local cached = bg_path_cache[code]
  if not cached then
    cached = img_path("weather-bgs/" .. code .. ".png")
    bg_path_cache[code] = cached
  end
  return cached
end

local function set_label_text(label, text, extra)
  local last_text = label_text_cache[label]
  local text_changed = last_text ~= text
  if not text_changed and not extra then
    return false
  end
  local props = { text = text }
  if extra then
    for key, value in pairs(extra) do
      props[key] = value
    end
  end
  label:set(props)
  if text_changed then
    label_text_cache[label] = text
  end
  return true
end

local function set_image_src_if_needed(image_obj, src, fallback_src, last_src)
  local target_src = src
  if fallback_src and not file_exists(target_src) then
    target_src = fallback_src
  end
  if last_src == target_src then
    return last_src
  end

  local ok = pcall(function()
    image_obj:set_src(target_src)
  end)
  if ok then
    return target_src
  end

  if fallback_src and fallback_src ~= target_src then
    local fallback_ok = pcall(function()
      image_obj:set_src(fallback_src)
    end)
    if fallback_ok then
      return fallback_src
    end
  end

  return last_src
end

local bg_image = lvgl.Image(root, {
  src = img_path("weather-bgs/11.png"),
  align = lvgl.ALIGN.CENTER,
})

local time_label = lvgl.Label(root, {
  text = "--:--",
  text_color = 0xDCE4F0,
  text_font = get_text_font(24),
  align = { type = lvgl.ALIGN.TOP_MID, y_ofs = -16 },
})

local hero_group_w = screen_w - 24
local hero_group = lvgl.Object(root, {
  w = hero_group_w,
  h = 300,
  bg_opa = 0,
  border_width = 0,
  pad_all = 0,
  align = { type = lvgl.ALIGN.TOP_MID, y_ofs = 20 },
})
hero_group:clear_flag(lvgl.FLAG.SCROLLABLE)
hero_group:add_flag(lvgl.FLAG.EVENT_BUBBLE)

local icon_image = lvgl.Image(hero_group, {
  src = img_path("weather-icons/cloudy.png"),
  align = { type = lvgl.ALIGN.TOP_MID, y_ofs = 0 },
})

local location_label = lvgl.Label(hero_group, {
  text = "位置",
  text_color = 0xEAF1FA,
  text_font = get_text_font(28),
  align = { type = lvgl.ALIGN.TOP_MID, y_ofs = 48 },
})

local temp_label = lvgl.Label(hero_group, {
  text = "--°",
  text_color = 0xFFFFFF,
  text_font = get_text_font(72),
  align = { type = lvgl.ALIGN.TOP_MID, x_ofs = 48, y_ofs = 132 },
})

local range_label = lvgl.Label(hero_group, {
  text = "--°/--°",
  text_color = 0xC3D0E2,
  text_font = get_text_font(30),
  align = { type = lvgl.ALIGN.TOP_MID, x_ofs = 4, y_ofs = 222 },
})

local metrics_group_w = screen_w - 24
local metrics_group_h = 128

local metrics_group = lvgl.Object(root, {
  w = metrics_group_w,
  h = metrics_group_h,
  bg_opa = 0,
  border_width = 0,
  pad_all = 0,
  align = { type = lvgl.ALIGN.BOTTOM_MID, y_ofs = -24 },
})
metrics_group:clear_flag(lvgl.FLAG.SCROLLABLE)
metrics_group:add_flag(lvgl.FLAG.EVENT_BUBBLE)

local update_label = lvgl.Label(root, {
  text = "--",
  text_color = 0xDCE4F0,
  text_font = get_text_font(20),
  align = { type = lvgl.ALIGN.BOTTOM_MID, y_ofs = 4 },
})

local metric_col_w = math.floor(metrics_group_w / 2)

local uv_col = lvgl.Object(metrics_group, {
  w = metric_col_w,
  h = metrics_group_h,
  bg_opa = 0,
  border_width = 0,
  pad_all = 0,
  align = { type = lvgl.ALIGN.TOP_LEFT, x_ofs = 0, y_ofs = 0 },
})

local hum_col = lvgl.Object(metrics_group, {
  w = metric_col_w,
  h = metrics_group_h,
  bg_opa = 0,
  border_width = 0,
  pad_all = 0,
  align = { type = lvgl.ALIGN.TOP_LEFT, x_ofs = metric_col_w, y_ofs = 0 },
})

local uv_value_label = lvgl.Label(uv_col, {
  text = "--",
  text_color = 0xFFFFFF,
  text_font = get_text_font(30),
  align = { type = lvgl.ALIGN.TOP_MID, y_ofs = 48 },
})

local uv_title_label = lvgl.Label(uv_col, {
  text = "UVI",
  text_color = 0xFFFFFF,
  text_font = get_text_font(20),
  align = { type = lvgl.ALIGN.TOP_MID, y_ofs = 14 },
})

local hum_value_label = lvgl.Label(hum_col, {
  text = "--",
  text_color = 0xFFFFFF,
  text_font = get_text_font(30),
  align = { type = lvgl.ALIGN.TOP_MID, y_ofs = 48 },
})

local hum_title_label = lvgl.Label(hum_col, {
  text = "湿度",
  text_color = 0xFFFFFF,
  text_font = get_text_font(20),
  align = { type = lvgl.ALIGN.TOP_MID, y_ofs = 14 },
})


local WeatherIconMap = {
  [100] = "sunny",
  [101] = "cloudy",
  [102] = "cloudy",
  [103] = "cloudy",
  [104] = "overcast",
  [150] = "sunny",
  [151] = "cloudy",
  [152] = "cloudy",
  [153] = "cloudy",
  [300] = "moderate-rain",
  [301] = "moderate-rain",
  [302] = "t-storm",
  [303] = "t-storm",
  [304] = "t-storm",
  [305] = "light-rain",
  [306] = "moderate-rain",
  [307] = "heavy-rain",
  [308] = "heavy-rain",
  [309] = "light-rain",
  [310] = "heavy-rain",
  [311] = "heavy-rain",
  [312] = "heavy-rain",
  [313] = "ice-rain",
  [314] = "light-rain",
  [315] = "moderate-rain",
  [316] = "heavy-rain",
  [317] = "heavy-rain",
  [318] = "heavy-rain",
  [350] = "moderate-rain",
  [351] = "moderate-rain",
  [399] = "light-rain",
  [400] = "light-snow",
  [401] = "moderate-snow",
  [402] = "heavy-snow",
  [403] = "heavy-snow",
  [404] = "rain-snow",
  [405] = "rain-snow",
  [406] = "rain-snow",
  [407] = "light-snow",
  [408] = "light-snow",
  [409] = "moderate-snow",
  [410] = "heavy-snow",
  [456] = "rain-snow",
  [457] = "moderate-snow",
  [499] = "light-snow",
  [500] = "fog",
  [501] = "fog",
  [502] = "fog",
  [503] = "sand",
  [504] = "float-dirt",
  [507] = "sand",
  [508] = "sand",
  [509] = "fog",
  [510] = "fog",
  [511] = "fog",
  [512] = "fog",
  [513] = "fog",
  [514] = "fog",
  [515] = "fog",
  [900] = "cloudy",
  [901] = "sunny",
  [999] = "cloudy",
}

local WeatherBackgroundImageMap = {
  [100] = "21",
  [101] = "11",
  [102] = "11",
  [103] = "11",
  [104] = "31",
  [150] = "22",
  [151] = "12",
  [152] = "12",
  [153] = "12",
  [154] = "12",
  [300] = "51",
  [301] = "51",
  [302] = "51",
  [303] = "51",
  [304] = "51",
  [305] = "51",
  [306] = "51",
  [307] = "51",
  [308] = "51",
  [309] = "51",
  [310] = "51",
  [311] = "51",
  [312] = "51",
  [313] = "51",
  [314] = "51",
  [315] = "51",
  [316] = "51",
  [317] = "51",
  [318] = "51",
  [350] = "52",
  [351] = "52",
  [399] = "51",
  [400] = "61",
  [401] = "61",
  [402] = "61",
  [403] = "61",
  [404] = "61",
  [405] = "61",
  [406] = "61",
  [407] = "61",
  [408] = "61",
  [409] = "61",
  [410] = "61",
  [456] = "62",
  [457] = "62",
  [499] = "61",
  [500] = "41",
  [501] = "41",
  [502] = "41",
  [503] = "41",
  [504] = "41",
  [507] = "41",
  [508] = "41",
  [509] = "42",
  [510] = "42",
  [511] = "42",
  [512] = "42",
  [513] = "42",
  [514] = "42",
  [515] = "42",
  [900] = "21",
  [901] = "22",
  [999] = "11",
}

local function to_ascii(value, fallback)
  if not value then
    return fallback
  end
  if type(value) ~= "string" then
    value = tostring(value)
  end
  if use_misans then
    return value
  end
  if value:match("[^\x20-\x7E]") then
    return fallback
  end
  return value
end

local function format_one_decimal_percent(value)
  local numeric = tonumber(value)
  if not numeric then
    return "--"
  end
  return string.format("%.1f", numeric)
end

local function parse_iso_time(text)
  if not text then
    return nil
  end
  local year, month, day, hour, min, sec = text:match("(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):?(%d*)")
  if not year then
    return nil
  end
  return os.time({
    year = tonumber(year) or 0,
    month = tonumber(month) or 0,
    day = tonumber(day) or 0,
    hour = tonumber(hour) or 0,
    min = tonumber(min) or 0,
    sec = tonumber(sec) or 0,
  })
end

local function format_time_ago_short(update_time_text)
  local timestamp = parse_iso_time(update_time_text)
  if not timestamp then
    return "--"
  end
  local diff_seconds = os.time() - timestamp
  if diff_seconds < 0 then
    diff_seconds = 0
  end
  local diff_minutes = math.floor(diff_seconds / 60)
  local diff_hours = math.floor(diff_minutes / 60)
  local diff_days = math.floor(diff_hours / 24)

  if diff_minutes < 1 then
    return "刚刚"
  elseif diff_minutes < 60 then
    return tostring(diff_minutes) .. "分钟前"
  elseif diff_hours < 24 then
    return tostring(diff_hours) .. "小时前"
  else
    return tostring(diff_days) .. "天前"
  end
end

local function format_current_time()
  return os.date("%H:%M")
end

local function refresh_time_view(update_time)
  set_label_text(time_label, format_current_time())
  if update_time then
    set_label_text(update_label, format_time_ago_short(update_time))
  else
    set_label_text(update_label, "--")
  end
end

local function parse_time_to_minutes(time_text)
  if not time_text or type(time_text) ~= "string" then
    return nil
  end
  local hour, minute = time_text:match("^(%d%d):(%d%d)$")
  if not hour then
    return nil
  end
  return tonumber(hour) * 60 + tonumber(minute)
end

local function is_night_time(sunrise, sunset)
  local h = tonumber(os.date("%H")) or 0
  local m = tonumber(os.date("%M")) or 0
  local current_minutes = h * 60 + m
  local sunrise_minutes = parse_time_to_minutes(sunrise)
  local sunset_minutes = parse_time_to_minutes(sunset)
  if sunrise_minutes and sunset_minutes then
    return current_minutes < sunrise_minutes or current_minutes >= sunset_minutes
  end
  return current_minutes >= 1080 or current_minutes < 360
end

local function get_mapped_icon_code(icon_code, night)
  local numeric = tonumber(icon_code)
  local mapped = WeatherIconMap[numeric or icon_code] or icon_code or "--"
  if type(mapped) ~= "string" then
    mapped = tostring(mapped)
  end
  if night then
    if mapped == "sunny" then
      mapped = "sunny-night"
    elseif mapped == "cloudy" then
      mapped = "cloudy-night"
    elseif mapped == "fog" then
      mapped = "fog-night"
    end
  end
  if not file_exists(get_icon_path(mapped)) then
    if night then
      return "cloudy-night"
    end
    return "cloudy"
  end
  return mapped
end

local function get_mapped_background_image(icon_code, night)
  local numeric = tonumber(icon_code)
  local mapped = WeatherBackgroundImageMap[numeric or icon_code] or WeatherBackgroundImageMap[999]
  if night then
    if mapped == "11" then
      mapped = "12"
    elseif mapped == "21" then
      mapped = "22"
    elseif mapped == "31" then
      mapped = "12"
    elseif mapped == "41" then
      mapped = "42"
    elseif mapped == "51" then
      mapped = "52"
    elseif mapped == "61" then
      mapped = "62"
    end
  end
  return mapped
end

local function calculate_average_temperature(today)
  if not today then
    return "--"
  end
  local min_temp = tonumber(today.tempMin)
  local max_temp = tonumber(today.tempMax)
  if not min_temp or not max_temp then
    return "--"
  end
  return tostring(math.floor((min_temp + max_temp) / 2 + 0.5))
end

local function normalize_temperature_value(value)
  if value == nil then
    return "--"
  end
  local numeric = tonumber(value)
  if not numeric then
    return tostring(value)
  end
  return tostring(math.floor(numeric + 0.5))
end

local function get_current_temperature(today, hourly_list)
  if type(hourly_list) == "table" then
    for _, entry in ipairs(hourly_list) do
      local temp_value = entry.temp
      if temp_value ~= nil then
        if type(temp_value) == "string" then
          local stripped = temp_value:gsub("°", "")
          return stripped
        end
        return normalize_temperature_value(temp_value)
      end
    end
  end
  return calculate_average_temperature(today)
end

local function parse_hourly_list(hourly_list)
  if type(hourly_list) ~= "table" then
    return {}
  end

  local now_str = os.date("%Y-%m-%dT%H:%M")
  local result = {}
  local count = 0
  for _, item in ipairs(hourly_list) do
    local fx_time = item.fxTime
    if fx_time and type(fx_time) == "string" and fx_time >= now_str then
      result[#result + 1] = item
      count = count + 1
      if count >= 24 then
        break
      end
    end
  end
  return result
end

local function read_file_raw(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end
  local size = file:seek("end")
  if size and size > MAX_WEATHER_FILE_SIZE then
    file:close()
    return nil
  end
  if size then
    file:seek("set", 0)
  end
  local content = file:read(MAX_WEATHER_FILE_SIZE + 1)
  file:close()
  if content and #content > MAX_WEATHER_FILE_SIZE then
    return nil
  end
  if content and #content > 0 then
    return content
  end
  return nil
end

local function read_weather_file()
  local path = "/data/quickapp/files/com.application.zaona.weather/weather.txt"

  local content1 = read_file_raw(path)
  if not content1 then
    return nil
  end

  local content2 = read_file_raw(path)
  if not content2 then
    return nil
  end

  if content1 == content2 then
    return content1
  end

  return nil
end

-- 安全 JSON 辅助函数：逐字符扫描，无正则回溯风险
local function json_skip_ws(s, pos)
  while pos <= #s do
    local b = s:byte(pos)
    if b == 32 or b == 9 or b == 10 or b == 13 then
      pos = pos + 1
    else
      break
    end
  end
  return pos
end

local function json_field_pos(s, name, start)
  local target = '"' .. name .. '"'
  local pos = start or 1
  while pos <= #s do
    local found_start, found_end = s:find(target, pos, true)
    if not found_start then
      return nil
    end
    local after = json_skip_ws(s, found_end + 1)
    if after <= #s and s:byte(after) == 58 then
      return after + 1
    end
    pos = found_end + 1
  end
  return nil
end

local function json_extract_value(s, pos)
  if not pos then
    return nil, pos
  end
  pos = json_skip_ws(s, pos)
  if pos > #s then
    return nil, pos
  end

  local b = s:byte(pos)
  if b == 34 then
    local parts = {}
    local i = pos + 1
    local seg_start = i
    while i <= #s do
      local c = s:byte(i)
      if c == 92 then
        parts[#parts + 1] = s:sub(seg_start, i - 1)
        i = i + 1
        if i <= #s then
          parts[#parts + 1] = s:sub(i, i)
        end
        i = i + 1
        seg_start = i
      elseif c == 34 then
        parts[#parts + 1] = s:sub(seg_start, i - 1)
        return table.concat(parts), i + 1
      else
        i = i + 1
      end
    end
    return nil, i
  elseif b == 123 then
    local depth = 1
    local i = pos + 1
    while i <= #s and depth > 0 do
      local c = s:byte(i)
      if c == 34 then
        i = i + 1
        while i <= #s do
          local sc = s:byte(i)
          if sc == 92 then
            i = i + 1
          elseif sc == 34 then
            break
          end
          i = i + 1
        end
      elseif c == 123 then
        depth = depth + 1
      elseif c == 125 then
        depth = depth - 1
      end
      i = i + 1
    end
    if depth > 0 then
      return nil, i
    end
    return s:sub(pos, i - 1), i
  else
    local i = pos
    while i <= #s do
      local c = s:byte(i)
      if c == 44 or c == 125 or c == 93 or c <= 32 then
        break
      end
      i = i + 1
    end
    return s:sub(pos, i - 1), i
  end
end

local function json_extract_field(s, name)
  local pos = json_field_pos(s, name)
  local value = json_extract_value(s, pos)
  return value
end

local function json_extract_array(s, field_name)
  local pos = json_field_pos(s, field_name)
  if not pos then
    return {}
  end

  pos = json_skip_ws(s, pos)
  if pos > #s or s:byte(pos) ~= 91 then
    return {}
  end
  pos = pos + 1

  local result = {}
  local limit = field_name == "daily" and MAX_DAILY_ITEMS or MAX_HOURLY_ITEMS
  local max_scan = math.min(#s, 256 * 1024)
  local scanned = 0

  while pos <= #s and #result < limit and scanned < max_scan do
    pos = json_skip_ws(s, pos)
    scanned = scanned + 1
    if pos > #s then
      break
    end
    if s:byte(pos) == 93 then
      break
    end

    local obj_text, new_pos = json_extract_value(s, pos)
    if not obj_text or type(obj_text) ~= "string" then
      break
    end
    result[#result + 1] = obj_text
    pos = new_pos

    pos = json_skip_ws(s, pos)
    if pos <= #s and s:byte(pos) == 44 then
      pos = pos + 1
    end
  end

  return result
end

local function parse_weather_v24(raw)
  if type(raw) ~= "string" or raw == "" then
    return nil
  end

  if not raw:find('"code"', 1, true) then
    return nil
  end

  local daily = {}
  local daily_objects = json_extract_array(raw, "daily")
  for _, obj in ipairs(daily_objects) do
    table.insert(daily, {
      fxDate = json_extract_field(obj, "fxDate"),
      sunrise = json_extract_field(obj, "sunrise"),
      sunset = json_extract_field(obj, "sunset"),
      tempMax = json_extract_field(obj, "tempMax"),
      tempMin = json_extract_field(obj, "tempMin"),
      iconDay = json_extract_field(obj, "iconDay"),
      textDay = json_extract_field(obj, "textDay"),
      humidity = json_extract_field(obj, "humidity"),
      uvIndex = json_extract_field(obj, "uvIndex"),
      pressure = json_extract_field(obj, "pressure"),
      windScaleDay = json_extract_field(obj, "windScaleDay"),
    })
  end

  local hourly = {}
  local hourly_objects = json_extract_array(raw, "hourly")
  for _, obj in ipairs(hourly_objects) do
    table.insert(hourly, {
      fxTime = json_extract_field(obj, "fxTime"),
      temp = json_extract_field(obj, "temp"),
      icon = json_extract_field(obj, "icon"),
      text = json_extract_field(obj, "text"),
    })
  end

  if not daily[1] then
    return nil
  end

  return {
    code = json_extract_field(raw, "code"),
    location = json_extract_field(raw, "location"),
    updateTime = json_extract_field(raw, "updateTime"),
    daily = daily,
    hourly = hourly,
  }
end

local function load_weather()
  local raw = read_weather_file()
  if not raw then
    return nil
  end
  local data = parse_weather_v24(raw)
  if data and type(data.daily) == "table" and data.daily[1] then
    return data
  end
  return nil
end

local function update_weather_view(data)
  local function render_no_data()
    set_label_text(temp_label, "无数据", { align = { type = lvgl.ALIGN.TOP_MID, x_ofs = 0, y_ofs = 132 } })
    set_label_text(time_label, format_current_time())
    set_label_text(location_label, "--")
    set_label_text(update_label, "--")
    set_label_text(range_label, "--°/--°")
    set_label_text(uv_value_label, "--")
    set_label_text(hum_value_label, "--")
    last_bg_src = set_image_src_if_needed(bg_image, img_path("weather-bgs/11.png"), nil, last_bg_src)
    last_icon_src = set_image_src_if_needed(icon_image, img_path("weather-icons/cloudy.png"), nil, last_icon_src)
  end

  if not data or not data.daily or not data.daily[1] then
    render_no_data()
    return
  end

  local function normalize_date(value)
    if not value then
      return nil
    end
    local text = tostring(value)
    local dashed = text:match("(%d%d%d%d%-%d%d%-%d%d)")
    if dashed then
      return dashed
    end
    local year, month, day = text:match("^(%d%d%d%d)(%d%d)(%d%d)$")
    if year then
      return year .. "-" .. month .. "-" .. day
    end
    return nil
  end

  local today_str = normalize_date(os.date("%Y-%m-%d"))
  local today = nil
  for _, day_item in ipairs(data.daily) do
    if type(day_item) == "table" and normalize_date(day_item.fxDate) == today_str then
      today = day_item
      break
    end
  end

  if not today then
    render_no_data()
    return
  end
  local location = data.location or "--"
  local temp_max = today.tempMax or "--"
  local temp_min = today.tempMin or "--"
  local humidity = today.humidity or "--"
  local uv_index = today.uvIndex or "--"
  local update_time = data.updateTime or "--"
  local night = is_night_time(today.sunrise, today.sunset)
  local icon_code = get_mapped_icon_code(today.iconDay, night)
  local background = get_mapped_background_image(today.iconDay, night)
  local hourly_list = parse_hourly_list(data.hourly)
  local current_temp = get_current_temperature(today, hourly_list)
  local safe_location = to_ascii(location, "位置")

  refresh_time_view(update_time)
  set_label_text(location_label, safe_location)
  set_label_text(temp_label, current_temp .. "°", { align = { type = lvgl.ALIGN.TOP_MID, x_ofs = 8, y_ofs = 132 } })
  set_label_text(range_label, temp_min .. "°/" .. temp_max .. "°")
  set_label_text(uv_value_label, format_one_decimal_percent(uv_index))
  set_label_text(hum_value_label, humidity .. "%")
  last_bg_src = set_image_src_if_needed(bg_image, get_bg_path(background), img_path("weather-bgs/11.png"), last_bg_src)
  last_icon_src = set_image_src_if_needed(icon_image, get_icon_path(icon_code), img_path("weather-icons/cloudy.png"), last_icon_src)
end

local current_weather_data = nil
local last_update_time = nil
local last_successful_refresh_at = os.time()

local function safe_run(fn)
  local ok, err = pcall(fn)
  if not ok and err then
    print(err)
  end
end

local function refresh_weather_data(force)
  safe_run(function()
    local new_data = load_weather()
    if not new_data then
      local since_last = os.time() - last_successful_refresh_at
      if current_weather_data and since_last < RECOVERY_TIMEOUT_SECONDS then
        refresh_time_view(last_update_time)
      else
        current_weather_data = nil
        last_update_time = nil
        update_weather_view(nil)
      end
      return
    end
    local new_update_time = new_data.updateTime
    if not force and new_update_time and last_update_time and new_update_time == last_update_time then
      refresh_time_view(last_update_time)
      last_successful_refresh_at = os.time()
      return
    end
    current_weather_data = new_data
    last_update_time = new_update_time
    update_weather_view(current_weather_data)
    last_successful_refresh_at = os.time()
  end)
end

refresh_weather_data(true)

local dataman_minute_token = nil

if dataman_ok and dataman and dataman.subscribe then
  local ok, token = pcall(dataman.subscribe, "timeMinute", root, function(obj, value)
    safe_run(function()
      if value == DATAMAN_INVALID_VALUE then
        return
      end
      local minute = value // 256
      refresh_time_view(last_update_time)
      local should_refresh = minute % PERIODIC_WEATHER_REFRESH_MINUTES == 0 or topic_needs_refresh
      if should_refresh then
        topic_needs_refresh = false
        refresh_weather_data(false)
      end
    end)
  end)
  if ok then
    dataman_minute_token = token
  end
end

local topic_subscriptions = {}

local function unsubscribe_topic_events()
  for i = 1, #topic_subscriptions do
    local sub = topic_subscriptions[i]
    if sub and sub.unsubscribe then
      pcall(function()
        sub:unsubscribe()
      end)
    end
  end
  topic_subscriptions = {}
end

local function subscribe_topic_events()
  if topic_subscribe_disabled or not (topic_ok and topic and topic.subscribe) then
    return
  end
  if #topic_subscriptions > 0 then
    return
  end

  local function on_data_event()
    if dataman_ok and dataman and dataman.subscribe then
      topic_needs_refresh = true
    else
      local now = os.time()
      if now - last_topic_refresh_at < TOPIC_REFRESH_THROTTLE_SECONDS then
        return
      end
      last_topic_refresh_at = now
      refresh_weather_data(false)
    end
  end

  local ok1, sub1 = pcall(topic.subscribe, "event_data_sync", on_data_event)
  local ok2, sub2 = pcall(topic.subscribe, "event_new_day", on_data_event)
  local ok3, sub3 = pcall(topic.subscribe, "app_data_update", on_data_event)
  if ok1 and sub1 then
    table.insert(topic_subscriptions, sub1)
  end
  if ok2 and sub2 then
    table.insert(topic_subscriptions, sub2)
  end
  if ok3 and sub3 then
    table.insert(topic_subscriptions, sub3)
  end
  if #topic_subscriptions == 0 then
    topic_subscribe_disabled = true
  end
end

if topic_ok and topic and topic.subscribe then
  subscribe_topic_events()
end

local function on_screen_on()
  if dataman_ok and dataman and dataman.resume and dataman_minute_token then
    pcall(function()
      dataman.resume(dataman_minute_token)
    end)
  end
  subscribe_topic_events()
  refresh_weather_data(true)
end

local function on_screen_off()
  if dataman_ok and dataman and dataman.pause and dataman_minute_token then
    pcall(function()
      dataman.pause(dataman_minute_token)
    end)
  end
  unsubscribe_topic_events()
end

function ScreenStateChangedCB(pre, now, reason)
  if pre ~= "ON" and now == "ON" then
    on_screen_on()
  elseif pre == "ON" and now ~= "ON" then
    on_screen_off()
  end
end
