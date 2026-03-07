local lvgl = require("lvgl")

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

local time_label = lvgl.Label(root, {
  text = "--:--",
  text_color = 0x7E93AE,
  text_font = get_text_font(14),
  align = { type = lvgl.ALIGN.TOP_MID, y_ofs = 6 },
})

local title = lvgl.Label(root, {
  text = "今日天气",
  text_color = 0xC7D4E5,
  text_font = get_text_font(18),
  align = { type = lvgl.ALIGN.TOP_MID, y_ofs = 28 },
})

local location_label = lvgl.Label(root, {
  text = "位置",
  text_color = 0x8EA4C0,
  text_font = get_text_font(16),
  align = { type = lvgl.ALIGN.TOP_MID, y_ofs = 52 },
})

local update_label = lvgl.Label(root, {
  text = "--:--  --",
  text_color = 0x7E93AE,
  text_font = get_text_font(14),
  align = { type = lvgl.ALIGN.TOP_MID, y_ofs = 74 },
})

local main_card = lvgl.Object(root, {
  w = screen_w - 36,
  h = 182,
  radius = 22,
  bg_color = 0x141A24,
  bg_opa = lvgl.OPA(100),
  border_width = 1,
  border_color = 0x1F2A3A,
  align = { type = lvgl.ALIGN.CENTER, y_ofs = 4 },
})
main_card:clear_flag(lvgl.FLAG.SCROLLABLE)
main_card:add_flag(lvgl.FLAG.EVENT_BUBBLE)

local temp_label = lvgl.Label(main_card, {
  text = "--°",
  text_color = 0xE8EEF5,
  text_font = get_text_font(32),
  align = { type = lvgl.ALIGN.TOP_MID, y_ofs = 20 },
})

local range_label = lvgl.Label(main_card, {
  text = "--°/--°",
  text_color = 0xC7D4E5,
  text_font = get_text_font(16),
  align = { type = lvgl.ALIGN.TOP_MID, y_ofs = 76 },
})

local condition_label = lvgl.Label(main_card, {
  text = "--",
  text_color = 0x9FB3C8,
  text_font = get_text_font(16),
  align = { type = lvgl.ALIGN.TOP_MID, y_ofs = 110 },
})

local detail_card = lvgl.Object(root, {
  w = screen_w - 36,
  h = 86,
  radius = 18,
  bg_color = 0x11161F,
  bg_opa = lvgl.OPA(100),
  border_width = 1,
  border_color = 0x1B2533,
  align = { type = lvgl.ALIGN.BOTTOM_MID, y_ofs = -14 },
})
detail_card:clear_flag(lvgl.FLAG.SCROLLABLE)
detail_card:add_flag(lvgl.FLAG.EVENT_BUBBLE)

local detail_label = lvgl.Label(detail_card, {
  text = "湿度 --%  紫外线 --\n风力 --  气压 --",
  text_color = 0x7E93AE,
  text_font = get_text_font(14),
  align = lvgl.ALIGN.CENTER,
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
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
    hour = tonumber(hour),
    min = tonumber(min),
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

local function format_time_hm(update_time_text)
  local timestamp = parse_iso_time(update_time_text)
  if timestamp then
    return os.date("%H:%M", timestamp)
  end
  return update_time_text:match("T(%d%d:%d%d)") or "--:--"
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
      local temp_value = entry.temp or entry.temperature
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

local function parse_hourly_list(hourly_data)
  if not hourly_data or not hourly_data.hourly or type(hourly_data.hourly) ~= "table" then
    return {}
  end
  local now = os.time()
  local threshold = now - 3600
  local result = {}
  for _, item in ipairs(hourly_data.hourly) do
    local fx_time = item.fxTime or item.time
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
    return nil, path
  end
  local content = file:read("*a")
  file:close()
  if content and #content > 0 then
    return content, path
  end
  return nil, path
end

local function decode_json(text)
  local ok, json = pcall(require, "cjson")
  if ok and json and json.decode then
    local decoded_ok, data = pcall(json.decode, text)
    if decoded_ok then
      return data
    end
  end
  ok, json = pcall(require, "json")
  if ok and json and json.decode then
    local decoded_ok, data = pcall(json.decode, text)
    if decoded_ok then
      return data
    end
  end
  return nil
end

local function read_hourly_file()
  local path = "/data/quickapp/files/com.application.zaona.weather/weather-hourly.txt"
  local file = io.open(path, "r")
  if not file then
    return nil, path
  end
  local content = file:read("*a")
  file:close()
  if content and #content > 0 then
    return content, path
  end
  return nil, path
end

local function parse_weather_fallback(text)
  local location = text:match('"location"%s*:%s*"(.-)"')
  local update_time = text:match('"updateTime"%s*:%s*"(.-)"')
  local daily_block = text:match('"daily"%s*:%s*%[(%b{})')
  if not daily_block then
    return nil
  end
  local function pick(field)
    return daily_block:match('"' .. field .. '"%s*:%s*"(.-)"')
  end
  return {
    location = location,
    updateTime = update_time,
    daily = {
      {
        fxDate = pick("fxDate"),
        tempMax = pick("tempMax"),
        tempMin = pick("tempMin"),
        sunrise = pick("sunrise"),
        sunset = pick("sunset"),
        iconDay = pick("iconDay"),
        textDay = pick("textDay"),
        humidity = pick("humidity"),
        uvIndex = pick("uvIndex"),
        pressure = pick("pressure"),
        precip = pick("precip"),
        windDirDay = pick("windDirDay"),
        windScaleDay = pick("windScaleDay"),
        wind360Day = pick("wind360Day"),
      },
    },
  }
end

local function load_weather()
  local raw, source_path = read_weather_file()
  if not raw then
    return nil, source_path
  end
  local data = decode_json(raw)
  if data and data.daily and data.daily[1] then
    return data, source_path
  end
  return parse_weather_fallback(raw), source_path
end

local function load_hourly_weather()
  local raw = read_hourly_file()
  if not raw then
    return nil
  end
  local data = decode_json(raw)
  if data and data.hourly and data.hourly[1] then
    return data
  end
  return nil
end

local function update_weather_view(data, source_path)
  if not data or not data.daily or not data.daily[1] then
    temp_label:set({ text = "暂无天气数据" })
    condition_label:set({ text = "--" })
    time_label:set({ text = "--:--" })
    location_label:set({ text = "--" })
    update_label:set({ text = "--" })
    range_label:set({ text = "--°/--°" })
    detail_label:set({ text = "湿度 --%  紫外线 --\n风力 --  气压 --" })
    return
  end

  local today = data.daily[1]
  local location = data.location or "--"
  local temp_max = today.tempMax or "--"
  local temp_min = today.tempMin or "--"
  local text_day = today.textDay or "--"
  local humidity = today.humidity or "--"
  local uv_index = today.uvIndex or "--"
  local wind_dir = today.windDirDay or today.windDir or "--"
  local wind_scale = today.windScaleDay or today.windScale or "--"
  local pressure = today.pressure or "--"
  local sunrise = today.sunrise or "--"
  local sunset = today.sunset or "--"
  local update_time = data.updateTime or "--"
  local time_ago = format_time_ago(update_time)
  local update_hm = format_time_hm(update_time)
  local night = is_night_time(today.sunrise, today.sunset)
  local icon_code = get_mapped_icon_code(today.iconDay, night)
  local background = get_mapped_background_image(today.iconDay, night)
  local hourly_data = load_hourly_weather()
  local hourly_list = hourly_data and parse_hourly_list(hourly_data) or {}
  local current_temp = get_current_temperature(today, hourly_list)
  local safe_location = to_ascii(location, "位置")
  local safe_text = to_ascii(text_day, icon_code)
  local safe_wind_dir = to_ascii(wind_dir, "--")

  location_label:set({ text = safe_location })
  time_label:set({ text = format_current_time() })
  update_label:set({ text = time_ago })
  temp_label:set({ text = current_temp .. "°" })
  range_label:set({ text = temp_min .. "°/" .. temp_max .. "°" })
  condition_label:set({ text = safe_text })
  detail_label:set({
    text = "湿度 " .. humidity .. "%  紫外线 " .. uv_index .. "\n风力 "
      .. safe_wind_dir
      .. " "
      .. wind_scale
      .. "  气压 "
      .. pressure,
  })
end

local weather_data, weather_path = load_weather()
update_weather_view(weather_data, weather_path)
