local lvgl = require("lvgl")
local dataman_ok, dataman = pcall(require, "dataman")
local topic_ok, topic = pcall(require, "topic")
local SCRIPT_PATH = rawget(_G, "SCRIPT_PATH") or ""

local function file_exists(path)
  local file = io.open(path, "r")
  if file then
    file:close()
    return true
  end
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
  local ok, font = pcall(lvgl.Font, name, size)
  if ok and font then
    return font
  end
  return lvgl.Font("montserrat", clamp_montserrat_size(size), "normal")
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
  table.insert(candidates, "/data/app/watchface/market/849698804/images/")
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

local bg_image = lvgl.Image(root, {
  src = img_path("weather-bgs/11.png"),
  align = lvgl.ALIGN.CENTER,
})

local time_label = lvgl.Label(root, {
  text = "--:--",
  text_color = 0xDCE4F0,
  text_font = get_text_font(20),
  align = { type = lvgl.ALIGN.TOP_MID, y_ofs = 8 },
})

local location_label = lvgl.Label(root, {
  text = "位置",
  text_color = 0xEAF1FA,
  text_font = get_text_font(24),
  align = { type = lvgl.ALIGN.TOP_MID, y_ofs = 34 },
})

local update_label = lvgl.Label(root, {
  text = "--",
  text_color = 0xC3D0E2,
  text_font = get_text_font(18),
  align = { type = lvgl.ALIGN.TOP_MID, y_ofs = 64 },
})


local hero_group_w = screen_w - 32
local hero_group = lvgl.Object(root, {
  w = hero_group_w,
  h = 240,
  bg_opa = 0,
  border_width = 0,
  align = { type = lvgl.ALIGN.TOP_MID, y_ofs = 96 },
})
hero_group:clear_flag(lvgl.FLAG.SCROLLABLE)
hero_group:add_flag(lvgl.FLAG.EVENT_BUBBLE)

local icon_image = lvgl.Image(hero_group, {
  src = img_path("weather-icons/cloudy.png"),
  align = { type = lvgl.ALIGN.TOP_MID, y_ofs = 4 },
})

local temp_label = lvgl.Label(hero_group, {
  text = "--°",
  text_color = 0xFFFFFF,
  text_font = get_text_font(48),
  align = { type = lvgl.ALIGN.TOP_MID, x_ofs = 8, y_ofs = 56 },
})

local condition_label = lvgl.Label(hero_group, {
  text = "--",
  text_color = 0xEAF1FA,
  text_font = get_text_font(22),
  align = { type = lvgl.ALIGN.TOP_MID, y_ofs = 130 },
})

local range_label = lvgl.Label(hero_group, {
  text = "--°/--°",
  text_color = 0xC3D0E2,
  text_font = get_text_font(22),
  align = { type = lvgl.ALIGN.TOP_MID, x_ofs = 3, y_ofs = 160 },
})

local detail_card_w = screen_w - 36
local detail_card_h = 138

local detail_card = lvgl.Object(root, {
  w = detail_card_w,
  h = detail_card_h,
  radius = 22,
  bg_color = 0xFFFFFF,
  bg_opa = lvgl.OPA(24),
  border_width = 0,
  pad_all = 0,
  align = { type = lvgl.ALIGN.BOTTOM_MID, y_ofs = -24 },
})
detail_card:clear_flag(lvgl.FLAG.SCROLLABLE)
detail_card:add_flag(lvgl.FLAG.EVENT_BUBBLE)

local detail_col_w = math.floor(detail_card_w / 2)

local uv_value_label = lvgl.Label(detail_card, {
  text = "--",
  text_color = 0xFFFFFF,
  text_font = get_text_font(22),
  align = { type = lvgl.ALIGN.TOP_LEFT, x_ofs = 10, y_ofs = 12 },
})

local uv_title_label = lvgl.Label(detail_card, {
  text = "紫外线",
  text_color = 0xFFFFFF,
  text_font = get_text_font(16),
  align = { type = lvgl.ALIGN.TOP_LEFT, x_ofs = 10, y_ofs = 44 },
})

local hum_value_label = lvgl.Label(detail_card, {
  text = "--",
  text_color = 0xFFFFFF,
  text_font = get_text_font(22),
  align = { type = lvgl.ALIGN.TOP_LEFT, x_ofs = detail_col_w + 6, y_ofs = 12 },
})

local hum_title_label = lvgl.Label(detail_card, {
  text = "湿度",
  text_color = 0xFFFFFF,
  text_font = get_text_font(16),
  align = { type = lvgl.ALIGN.TOP_LEFT, x_ofs = detail_col_w + 6, y_ofs = 44 },
})

local wind_value_label = lvgl.Label(detail_card, {
  text = "--",
  text_color = 0xFFFFFF,
  text_font = get_text_font(20),
  align = { type = lvgl.ALIGN.TOP_LEFT, x_ofs = 10, y_ofs = 74 },
})

local wind_title_label = lvgl.Label(detail_card, {
  text = "风力",
  text_color = 0xFFFFFF,
  text_font = get_text_font(16),
  align = { type = lvgl.ALIGN.TOP_LEFT, x_ofs = 10, y_ofs = 104 },
})

local pressure_value_label = lvgl.Label(detail_card, {
  text = "--",
  text_color = 0xFFFFFF,
  text_font = get_text_font(20),
  align = { type = lvgl.ALIGN.TOP_LEFT, x_ofs = detail_col_w + 6, y_ofs = 74 },
})

local pressure_title_label = lvgl.Label(detail_card, {
  text = "气压",
  text_color = 0xFFFFFF,
  text_font = get_text_font(16),
  align = { type = lvgl.ALIGN.TOP_LEFT, x_ofs = detail_col_w + 6, y_ofs = 104 },
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
  [900] = 99,
  [901] = 99,
  [999] = 99,
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

local function format_time_ago(update_time_text)
  local timestamp = parse_iso_time(update_time_text)
  if not timestamp then
    return "--"
  end
  local diff_seconds = os.time() - timestamp
  local diff_minutes = math.floor(diff_seconds / 60)
  local diff_hours = math.floor(diff_minutes / 60)
  local diff_days = math.floor(diff_hours / 24)

  if diff_minutes < 1 then
    return "刚刚"
  elseif diff_minutes < 60 then
    return tostring(diff_minutes) .. "分钟前更新"
  elseif diff_hours < 24 then
    return tostring(diff_hours) .. "小时前更新"
  else
    return tostring(diff_days) .. "天前更新"
  end
end

local function format_current_time()
  return os.date("%H:%M")
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
  local now = os.date("*t")
  local current_minutes = now.hour * 60 + now.min
  local sunrise_minutes = parse_time_to_minutes(sunrise)
  local sunset_minutes = parse_time_to_minutes(sunset)
  if sunrise_minutes and sunset_minutes then
    return current_minutes < sunrise_minutes or current_minutes >= sunset_minutes
  end
  return now.hour >= 18 or now.hour < 6
end

local function get_mapped_icon_code(icon_code, night)
  local numeric = tonumber(icon_code)
  local mapped = WeatherIconMap[numeric or icon_code] or icon_code or "--"
  if night then
    if mapped == "sunny" then
      mapped = "sunny-night"
    elseif mapped == "cloudy" then
      mapped = "cloudy-night"
    elseif mapped == "fog" then
      mapped = "fog-night"
    end
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

  local now = os.time()
  local threshold = now - 7200
  local result = {}
  for _, item in ipairs(hourly_list) do
    local fx_time = item.fxTime
    local timestamp = parse_iso_time(fx_time)
    if timestamp and timestamp >= threshold then
      table.insert(result, item)
    end
  end
  return result
end

local function read_weather_file()
  local path = "/data/quickapp/files/com.application.zaona.weather/weather.txt"
  local file = io.open(path, "r")
  if not file then
    return nil
  end
  local content = file:read("*a")
  file:close()
  if content and #content > 0 then
    return content
  end
  return nil
end

local function parse_weather_v24(raw)
  if type(raw) ~= "string" or raw == "" then
    return nil
  end

  local function pick_value(text, field)
    return text:match('"' .. field .. '"%s*:%s*"(.-)"')
  end

  local function parse_array_objects(text, field)
    local array_text = text:match('"' .. field .. '"%s*:%s*%[([%s%S]-)%]')
    if not array_text then
      return {}
    end
    local result = {}
    for obj in array_text:gmatch("%b{}") do
      table.insert(result, obj)
    end
    return result
  end

  local daily = {}
  for _, obj in ipairs(parse_array_objects(raw, "daily")) do
    table.insert(daily, {
      fxDate = pick_value(obj, "fxDate"),
      sunrise = pick_value(obj, "sunrise"),
      sunset = pick_value(obj, "sunset"),
      tempMax = pick_value(obj, "tempMax"),
      tempMin = pick_value(obj, "tempMin"),
      iconDay = pick_value(obj, "iconDay"),
      textDay = pick_value(obj, "textDay"),
      humidity = pick_value(obj, "humidity"),
      uvIndex = pick_value(obj, "uvIndex"),
      pressure = pick_value(obj, "pressure"),
      windScaleDay = pick_value(obj, "windScaleDay"),
    })
  end

  local hourly = {}
  for _, obj in ipairs(parse_array_objects(raw, "hourly")) do
    table.insert(hourly, {
      fxTime = pick_value(obj, "fxTime"),
      temp = pick_value(obj, "temp"),
      icon = pick_value(obj, "icon"),
      text = pick_value(obj, "text"),
    })
  end

  if not daily[1] then
    return nil
  end

  return {
    code = pick_value(raw, "code"),
    location = pick_value(raw, "location"),
    updateTime = pick_value(raw, "updateTime"),
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
    temp_label:set({ text = "无数据", align = { type = lvgl.ALIGN.TOP_MID, x_ofs = 0, y_ofs = 70 } })
    condition_label:set({ text = "--" })
    time_label:set({ text = "--:--" })
    location_label:set({ text = "--" })
    update_label:set({ text = "--" })
    range_label:set({ text = "--°/--°" })
    uv_value_label:set({ text = "--" })
    hum_value_label:set({ text = "--" })
    wind_value_label:set({ text = "--" })
    pressure_value_label:set({ text = "--" })
    bg_image:set_src(img_path("weather-bgs/11.png"))
    icon_image:set_src(img_path("weather-icons/cloudy.png"))
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
  local text_day = today.textDay or "--"
  local humidity = today.humidity or "--"
  local uv_index = today.uvIndex or "--"
  local wind_scale = today.windScaleDay or "--"
  local pressure = today.pressure or "--"
  local update_time = data.updateTime or "--"
  local time_ago = format_time_ago(update_time)
  local night = is_night_time(today.sunrise, today.sunset)
  local icon_code = get_mapped_icon_code(today.iconDay, night)
  local background = get_mapped_background_image(today.iconDay, night)
  local hourly_list = parse_hourly_list(data.hourly)
  local current_temp = get_current_temperature(today, hourly_list)
  local safe_location = to_ascii(location, "位置")
  local safe_text = to_ascii(text_day, icon_code)
  local safe_wind_scale = to_ascii(wind_scale, "--")

  location_label:set({ text = safe_location })
  time_label:set({ text = format_current_time() })
  update_label:set({ text = time_ago })
  temp_label:set({ text = current_temp .. "°", align = { type = lvgl.ALIGN.TOP_MID, x_ofs = 8, y_ofs = 70 } })
  range_label:set({ text = temp_min .. "°/" .. temp_max .. "°" })
  condition_label:set({ text = safe_text })
  uv_value_label:set({ text = uv_index })
  hum_value_label:set({ text = humidity .. "%" })
  wind_value_label:set({ text = safe_wind_scale })
  pressure_value_label:set({ text = pressure })
  bg_image:set_src(img_path("weather-bgs/" .. background .. ".png"))
  icon_image:set_src(img_path("weather-icons/" .. icon_code .. ".png"))
end

local current_weather_data = load_weather()
local last_update_time = current_weather_data and current_weather_data.updateTime or nil
update_weather_view(current_weather_data)

local function safe_run(fn)
  pcall(fn)
end

local function refresh_weather_data(force)
  safe_run(function()
    local new_data = load_weather()
    local new_update_time = new_data and new_data.updateTime or nil
    if not force and new_update_time and last_update_time and new_update_time == last_update_time then
      return
    end
    current_weather_data = new_data
    last_update_time = new_update_time or last_update_time
    update_weather_view(current_weather_data)
  end)
end

if dataman_ok and dataman and dataman.subscribe then
  dataman.subscribe("timeMinute", time_label, function(obj, value)
    if value ~= 2147483647 then
      refresh_weather_data(true)
    end
  end)
end

if topic_ok and topic and topic.subscribe then
  local function on_data_event()
    refresh_weather_data()
  end

  topic.subscribe("event_data_sync", on_data_event)
  topic.subscribe("event_new_day", on_data_event)
  topic.subscribe("app_data_update", on_data_event)
end
