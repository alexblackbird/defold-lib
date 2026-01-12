-- Универсальный модуль Telegram
-- Использование:
--   telegram.init({ fallback_data = "..." })  -- fallback для dev режима
--  1 - Запустить проект в web или с eruda
--  2 - Получить ключ из вывода
--  3 - Вставить в fallback_data

local telegram = {}

telegram.initData = ""
telegram.params = {}
telegram.user = {}

local config = {
	fallback_data = nil,  -- данные для dev режима (каждый проект свои)
	js_function = "getTelegramAccount",
}

function telegram.init(params)
	params = params or {}
	
	-- Настройки
	if params.fallback_data then config.fallback_data = params.fallback_data end
	if params.js_function then config.js_function = params.js_function end
	
	if html5 then
		-- получить данные из telegram
		telegram.initData = html5.run(config.js_function .. "()")
	else
		-- подставить тестовые данные
		telegram.initData = config.fallback_data or ""
	end
	
	-- Функция для парсинга строки запроса
	local function url_decode(str)
		str = str:gsub("+", " ")
		str = str:gsub("%%(%x%x)", function(hex)
			return string.char(tonumber(hex, 16))
		end)
		return str
	end

	-- Функция для парсинга строки запроса
	local function parse_query_string(query)
		local params = {}
		for key, value in query:gmatch("([^&=?]-)=([^&=?]+)") do
			params[key] = url_decode(value)
		end
		return params
	end

	pprint(telegram.initData)
	
	-- Парсим строку запроса
	telegram.params = parse_query_string(telegram.initData)

	pprint(telegram.params)

	-- Декодирование JSON из параметра 'user'
	if telegram.params['user'] then
		telegram.user = json.decode(telegram.params['user'])
		
		-- иногда нет никнейма
		if not telegram.user.username then
			telegram.user.username = (telegram.user.first_name or "") .. " " .. (telegram.user.last_name or "")
		end
	else
		telegram.user = {
			id = 0,
			first_name = "Unknown",
			last_name = "",
			username = "unknown",
			language_code = "en"
		}
	end
end

return telegram