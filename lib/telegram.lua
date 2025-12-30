local telegram = {}

telegram.initData = ""

function telegram.init()
	if html5 then
		-- получить данные из telegram
		telegram.initData = html5.run("getTelegramAccount()")
	else
		-- подставить тестовые данные
		-- TODO нужно вынести в какой то файл котоырй будет подтягиваться
		telegram.initData = "query_id=AAHqG-wcAAAAAOob7BxcooAb&user=%7B%22id%22%3A485235690%2C%22first_name%22%3A%22Alexander%22%2C%22last_name%22%3A%22Chizhevsky%22%2C%22username%22%3A%22a_chizhevskiy%22%2C%22language_code%22%3A%22ru%22%2C%22allows_write_to_pm%22%3Atrue%2C%22photo_url%22%3A%22https%3A%5C%2F%5C%2Ft.me%5C%2Fi%5C%2Fuserpic%5C%2F320%5C%2FKl5GbdSyjrGyS6AnW9zWGcASQtkkBBizIdoHLfDy6AU.svg%22%7D&auth_date=1731805362&hash=0fff6fc28d3f6744517a4d2876f40cd12cbeb61d284431f985992b5d9c314209"
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
	telegram.user = json.decode(telegram.params['user'])

	-- иногда нет никнейма
	if not telegram.user.username then
		telegram.user.username = telegram.user.first_name.." "..telegram.user.last_name
	end
end

return telegram