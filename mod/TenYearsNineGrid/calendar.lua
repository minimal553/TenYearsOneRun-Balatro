-- Fixed Beijing UTC+08:00 calendar adapter, verified against lunar-python 1.4.8.
-- Pure Lua 5.1: no OS clock, files, HTTP, Python, DST or true-solar-time conversion.
-- The compact generated table supplies exact Jie boundaries and year/month pillars.
return function(data)
  assert(type(data) == 'table' and data.format_version == 1 and
         type(data.terms) == 'table' and #data.terms > 0, '节气数据缺失或版本不兼容。')
  local C = {}
  local floor = math.floor
  local stems = {'甲','乙','丙','丁','戊','己','庚','辛','壬','癸'}
  local branches = {'子','丑','寅','卯','辰','巳','午','未','申','酉','戌','亥'}
  local elements = {'木','火','土','金','水'}
  local terms = data.terms
  local function pillar(index)
    return stems[index % 10 + 1] .. branches[index % 12 + 1]
  end
  local function leap(year)
    return year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)
  end
  local function days_in_month(year, month)
    if month == 2 then return leap(year) and 29 or 28 end
    return ({31,28,31,30,31,30,31,31,30,31,30,31})[month]
  end
  -- Gregorian day count independent of locale and the operating system time zone.
  local function days_before_year(year)
    local y = year - 1
    return 365*y + floor(y/4) - floor(y/100) + floor(y/400)
  end
  local epoch_days = days_before_year(1900)
  local function day_number(year, month, day)
    local value = days_before_year(year) - epoch_days + day - 1
    for m = 1, month - 1 do value = value + days_in_month(year, m) end
    return value
  end
  local function seconds(date)
    return day_number(date[1],date[2],date[3])*86400 + date[4]*3600 + date[5]*60 + date[6]
  end
  local function from_seconds(value)
    local days = floor(value / 86400)
    local year = 1900 + floor(days / 365.2425)
    while day_number(year + 1,1,1) <= days do year = year + 1 end
    while day_number(year,1,1) > days do year = year - 1 end
    local rest = days - day_number(year,1,1)
    local month = 1
    while rest >= days_in_month(year,month) do
      rest = rest - days_in_month(year,month)
      month = month + 1
    end
    local tod = value - days*86400
    return {year,month,rest+1,floor(tod/3600),floor(tod/60)%60,tod%60}
  end
  local function copy(date)
    return {date[1],date[2],date[3],date[4],date[5],date[6]}
  end
  local function next_year(date, count)
    local result = copy(date)
    result[1] = result[1] + count
    result[3] = math.min(result[3],days_in_month(result[1],result[2]))
    return result
  end
  local function next_month(date, count)
    local result = copy(date)
    local months = date[1]*12 + date[2] - 1 + count
    result[1], result[2] = floor(months/12), months%12+1
    result[3] = math.min(result[3],days_in_month(result[1],result[2]))
    return result
  end
  local function iso(date)
    return string.format('%04d-%02d-%02dT%02d:%02d:%02d+08:00',unpack(date))
  end
  -- Last term <= instant; upstream prevJie includes equality, nextJie excludes it.
  local function previous_term(value)
    local low, high, found = 1, #terms, 0
    while low <= high do
      local middle = floor((low+high)/2)
      if terms[middle][1] <= value then found,low=middle,middle+1 else high=middle-1 end
    end
    return found
  end
  local function indices(date)
    local position = previous_term(seconds(date))
    if position < 1 or position >= #terms then return nil,'日期超出节气表覆盖范围。' end
    local day = (day_number(date[1],date[2],date[3]) + data.day_epoch_index) % 60
    local time_branch = floor((date[4]+1)/2)%12
    -- Upstream sect 2 preserves the late-Zi day pillar but uses next day's stem
    -- for the hour pillar at 23:00. Keep those two rules deliberately separate.
    local time_day = day + (date[4] == 23 and 1 or 0)
    local time_stem = (time_day%5*2 + time_branch)%10
    return {terms[position][2],terms[position][3],day}, position,
           stems[time_stem+1] .. branches[time_branch+1]
  end
  local function valid_date(date)
    for i = 1,6 do
      if type(date[i]) ~= 'number' or date[i] ~= floor(date[i]) then return false end
    end
    return date[1]>=1900 and date[1]<=2201 and date[2]>=1 and date[2]<=12 and
           date[3]>=1 and date[3]<=days_in_month(date[1],date[2]) and
           date[4]>=0 and date[4]<24 and date[5]>=0 and date[5]<60 and date[6]>=0 and date[6]<60
  end
  -- Seconds-capable helper for exact astronomical boundary verification.
  function C.pillars(year,month,day,hour,minute,second)
    local date = {year,month,day,hour or 0,minute or 0,second or 0}
    if not valid_date(date) then return nil,'公历日期或时间无效。' end
    local ix, err, time = indices(date)
    if not ix then return nil,err end
    return {pillar(ix[1]),pillar(ix[2]),pillar(ix[3]),time}
  end
  local function completed_years(birth,boundary)
    local age = boundary[1]-birth[1]
    for i=2,6 do
      if boundary[i] < birth[i] then return age-1 end
      if boundary[i] > birth[i] then return age end
    end
    return age
  end
  function C.calculate(payload)
    if type(payload) ~= 'table' then return nil,'请填写出生日期、时间和排运性别。' end
    if payload.gender ~= 0 and payload.gender ~= 1 then return nil,'排运性别须选择女（0）或男（1）。' end
    if type(payload.date) ~= 'string' or #payload.date ~= 10 then return nil,'出生日期格式须为 YYYY-MM-DD。' end
    if type(payload.time) ~= 'string' or #payload.time ~= 5 then return nil,'出生时间格式须为 HH:MM（24小时制）。' end
    local year,month,day = payload.date:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    local hour,minute = payload.time:match('^(%d%d):(%d%d)$')
    if not year then return nil,'出生日期格式须为 YYYY-MM-DD。' end
    if not hour then return nil,'出生时间格式须为 HH:MM（24小时制）。' end
    local birth = {tonumber(year),tonumber(month),tonumber(day),tonumber(hour),tonumber(minute),0}
    if birth[1]<1901 or birth[1]>2099 then return nil,'出生日期仅支持公历1901至2099年。' end
    if not valid_date(birth) then return nil,'出生日期或时间无效，请检查日期、小时和分钟。' end
    local ix, position, time = indices(birth)
    if not ix then return nil,position end
    local forward = (ix[1]%2 == 0) == (payload.gender == 1)
    local birth_seconds = seconds(birth)
    -- subtractMinute ignores each endpoint's seconds separately. Subtracting
    -- first and flooring would be one minute wrong for backwards nonzero seconds.
    local minutes
    if forward then minutes=floor(terms[position+1][1]/60)-floor(birth_seconds/60)
    else minutes=floor(birth_seconds/60)-floor(terms[position][1]/60) end
    local years = floor(minutes/4320)
    minutes = minutes-years*4320
    local months = floor(minutes/360)
    minutes = minutes-months*360
    local days = floor(minutes/12)
    local hours = (minutes-days*12)*2
    -- Preserve upstream's order: year clamp, month clamp, days, then hours.
    local first = next_month(next_year(birth,years),months)
    first = from_seconds(seconds(first)+days*86400+hours*3600)
    local profile = {
      chart={pillar(ix[1]),pillar(ix[2]),pillar(ix[3]),time},selected_decade=1,
      calendar={library=data.library,day_sect=2,yun_sect=2,
        calculation_timezone='UTC+08:00',calculation_utc_offset='+08:00',
        gender=payload.gender,forward=forward,start_date=iso(first),
        age_convention='completed_years',year_sampling='anniversary_midpoint'},
      decades={}
    }
    for index=1,8 do
      -- Every decade is anchored directly to first交运, preserving leap-day rules.
      local start = next_year(first,(index-1)*10)
      local finish = next_year(first,index*10)
      local annual = {}
      for offset=0,9 do
        local midpoint = next_month(start,offset*12+6)
        local yi = indices(midpoint)
        if not yi then return nil,'大运日期超出节气表覆盖范围。' end
        annual[#annual+1] = {year=midpoint[1],gan_zhi=pillar(yi[1]),element=elements[floor(yi[1]%10/2)+1]}
      end
      profile.decades[index] = {index=index,gan_zhi=pillar(ix[2]+(forward and index or -index)),
        start_date=iso(start),end_date=iso(finish),start_age=completed_years(birth,start),
        end_age=completed_years(birth,finish),years=annual}
    end
    return profile
  end
  return C
end
