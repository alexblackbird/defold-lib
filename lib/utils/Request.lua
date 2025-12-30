local md5 = require "lib.utils.md5"

-- BODY
local M = {}
M.__index = M

function M.new(script, params, successCb, errorCb, loader, method)
  local self = setmetatable({}, M)
  self.script = script
  self.params = params
  self.successCb = successCb
  self.errorCb = errorCb
  self.loader = loader
  self.method = method
  self.cancelled = false
  self.try_count = 1
  self.post_data = ""

  -- формируем ссылку
  if sys.get_engine_info().is_debug then
    self.SERVER_PATCH = DEV_SERVER_PATCH
  else
    self.SERVER_PATCH = PROD_SERVER_PATCH
  end

  self.raw_data = {
    device_ident = sys_info.device_ident,
    game_id = db.game_id,
    token = db.token,
    system_name = sys_info.system_name
  }

  -- add additional params
  for k,v in pairs(self.params) do
    self.raw_data[k] = v
  end

  -- создаю таблицу для ключей
  local tkeys = {}

  -- добавляю туда ключи
  for k in pairs(self.raw_data) do 
    table.insert(tkeys, k) 
  end

  -- сортирую только ключи
  table.sort(tkeys)

  -- формирую подпись
  local sig = ""
  for i, k in ipairs(tkeys) do
    sig = sig..k.."="..tostring(self.raw_data[k])
    if i < #tkeys then
      sig = sig.."&"
    end
  end

  -- снимаю ключ
  self.raw_data.key = md5.sumhexa(sig.."j9jj6j5j15j4j7j8j7jj7j6j5j1")

  -- add random key
  self.raw_data.random = math.random(1, 10000000)

  -- у Петра не пропускал +
  function url_encode(str)
    if str then
      str = string.gsub(str, "([^%w%-%_%.%~])", function(c)
        return string.format("%%%02X", string.byte(c))
      end)
    end
    return str
  end

  -- формируем данные для отправки "key=value&key=value"
  for k, v in pairs(self.raw_data) do
    self.post_data = self.post_data..k.."="..url_encode(tostring(v)).."&"
  end
  
  -- удаление последнего символа '&'
  self.post_data = self.post_data:sub(1, -2)
  
  
  self.url = self.SERVER_PATCH.."/"..script..".php"

  print(self.url.."?"..self.post_data)

  if not self.method then
    -- tсли не указан тип - значит это GET
    self.method = "GET"
    self.url = self.url.."?"..self.post_data
    self.post_data = nil
  end
  
  self.headers = {["Content-Type"] = "application/x-www-form-urlencoded"}

  -- создаем прелоадер
  if self.loader then
    msg.post("loader:/loader", "request_loader_show")
  end
  --
  M.sendRequest(self)

  return self
end

function M.sendRequest(params)
  
  http.request(params.url, params.method, function(self, _, response)
    -- связь удачная и мы не отменили соединение
    if response.status == 200 and not self.cancelled then
    -- pprint(response)
      pprint(json.decode(response.response))
      -- лоадер убираем
      if params.loader then
        msg.post("loader:/loader", "request_loader_hide")
      end

      local jd = json.decode(response.response)

      if jd.response then
        -- оповещаем об успехе
        if params.successCb then
          params.successCb(jd.response)
        end
      elseif jd.error then   
        pprint(jd.error)
        if params.errorCb then
          params.errorCb(jd)
        else
          popup.show("error", {}, {code = jd.error})
        end
      else
        pprint(jd)
        if params.errorCb then
          params.errorCb({error = { text = 'Отсутствует доступ к серверу. Попробуйте позже'}})
        else
          popup.show("error", {}, {code = "-1"})
        end
      end
    else
      -- Попытка неудачная - пытаемся переподключиться
      pprint(response)
      params.try_count = params.try_count + 1
      if params.try_count <= 6 then
        -- пытемся соединиться 6 раз
        M.sendRequest(params)
      else
        -- рапартуем об ошибке
        params.errorCb({error = { text = 'Отсутствует доступ к серверу. Проверьте связь или сервер'}})
      end
    end
  end, params.headers, params.post_data, nil)
end


function M.cancel(self, newval)
  self.cancelled = true
end

-- REQUEST INTERFACE
function request (script, params, successCb, errorCb, loader, method)
  local _req = M.new(script, params, successCb, errorCb, loader, method)
	return _req
end

-- отмена реквеста - после загрузки callback не сработает
function request_cancel(_req)
	_req:cancel()
end
