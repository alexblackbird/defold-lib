local time = {}

function time.synchronizeTime(unixtime)
  if not unixtime then
    unixtime = os.time()
  end

  delta_time = os.time() - unixtime

  db.unixtime = os.time() - delta_time
  timer.delay(1.0, true, function()
    db.unixtime = os.time() - delta_time
  end)
end

time.time_translations = {
  ['en'] = {
    days = {'d', 'd', 'd'},
    hours = {'h', 'h', 'h'},
    minutes = {'m', 'm', 'm'},
    seconds = {'s', 's', 's'},
    space = ''
  },
  ['ru'] = {
    days = {'д', 'дн', 'дн'},
    hours = {'ч', 'ч', 'ч'},
    minutes = {'м', 'м', 'м'},
    seconds = {'с', 'с', 'с'},
    space = ''
  },
  ['de'] = {
    days = {'Tg', 'Tg', 'Tg'},
    hours = {'Std', 'Std', 'Std'},
    minutes = {'M', 'M', 'M'},
    seconds = {'S', 'S', 'S'},
    space = ''
  },
  ['fr'] = {
    days = {'j', 'j', 'j'},
    hours = {'h', 'h', 'h'},
    minutes = {'m', 'm', 'm'},
    seconds = {'s', 's', 's'},
    space = ''
  },
  ['it'] = {
    days = {'g', 'g', 'g'},
    hours = {'h', 'h', 'h'},
    minutes = {'m', 'm', 'm'},
    seconds = {'s', 's', 's'},
    space = ''
  },
  ['es'] = {
    days = {'d', 'd', 'd'},
    hours = {'h', 'h', 'h'},
    minutes = {'m', 'm', 'm'},
    seconds = {'s', 's', 's'},
    space = ''
  },
  ['pt'] = {
    days = {'d', 'd', 'd'},
    hours = {'h', 'h', 'h'},
    minutes = {'m', 'm', 'm'},
    seconds = {'s', 's', 's'},
    space = ''
  },
  ['ko'] = {
    days = {'일', '일', '일'},
    hours = {'시', '시', '시'},
    minutes = {'분', '분', '분'},
    seconds = {'초', '초', '초'},
    space = ' '
  },
  ['ja'] = {
    days = {'日', '日', '日'},
    hours = {'時', '時', '時'},
    minutes = {'分', '分', '分'},
    seconds = {'秒', '秒', '秒'},
    space = ''
  },
  ['ar'] = {
    days = {'ي', 'أ', 'أ'},
    hours = {'س', 'س', 'س'},
    minutes = {'د', 'د', 'د'},
    seconds = {'ث', 'ث', 'ث'},
    space = ' '
  },
  ['tr'] = {
    days = {'g', 'g', 'g'},
    hours = {'s', 's', 's'},
    minutes = {'dk', 'dk', 'dk'},
    seconds = {'sn', 'sn', 'sn'},
    space = ''
  }
}

-- Функция для определения правильного спряжения
function time.get_proper_form(value, forms)
  if value == 1 then
    return forms[1]
  elseif value > 1 and value < 5 then
    return forms[2]
  else
    return forms[3]
  end
end

function time.get_human_time_symbol(seconds)
  local lang = lang.language
  local seconds = tonumber(seconds)
  local space = time.time_translations[lang].space or " "

  if seconds <= 0 then
    return "00:00"
  else
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)

    local result = ""

    if days > 0 then
      result = result .. days .. space .. time.get_proper_form(days, time.time_translations[lang].days)
    end

    if hours > 0 then
      result = result .. (result ~= "" and " " or "") .. hours .. space .. time.get_proper_form(hours, time.time_translations[lang].hours)
    end

    if mins > 0 then
      result = result .. (result ~= "" and " " or "") .. mins .. space .. time.get_proper_form(mins, time.time_translations[lang].minutes)
    end

    if secs > 0 and result == "" then
      -- Добавляем секунды только если ничего больше не отображается
      result = secs .. space .. time.get_proper_form(secs, time.time_translations[lang].seconds)
    end

    return result
  end
end


function time.get_human_time(seconds)
  local seconds = tonumber(seconds)

  if seconds <= 0 then
    return "00:00";
  else
    hours = string.format("%02.f", math.floor(seconds/3600));
    mins = string.format("%02.f", math.floor(seconds/60 - (hours*60)));
    secs = string.format("%02.f", math.floor(seconds - hours*3600 - mins *60));
    if hours == '00' then
      return mins..":"..secs
    else
      return hours..":"..mins..":"..secs
    end

  end
end

-- сатурация времени - вместо недель атака за максимум 24 часа
function time.clamp(x, a, b)
  return math.max(a, math.min(x, b))
end

function time.saturating_time_pvp(sectocoin, bet, cap_pvp_s, min_time_s)
  local t_raw = sectocoin * bet
  local t = cap_pvp_s * (1 - math.exp(- t_raw / cap_pvp_s))
  t = time.clamp(t, min_time_s, cap_pvp_s)
  return math.ceil(t) -- секунды вверх
end

return time