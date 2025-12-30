local amplitude = {}

function amplitude.init()
	amplitude.api_key = sys.get_config("amplitude.api_key")
	amplitude.timer_id = nil
	amplitude.events_pool = {}
	amplitude.event_id = 0
	amplitude.session_id = math.floor(socket.gettime()*1000)
	
	-- Настройки повторных попыток (можно переопределить через конфиг)
	amplitude.retry_attempts = 3
	amplitude.retry_delay = 5
end

-- Вызывается из всего кода, отправляет событие в скрипт
function amplitude.track(event_name, event_properties, user_properties)
	-- создаем запрос через скрипт - чтобы он сохранился даже после закрытия хозяина
	msg.post("loader:/scripts#amplitude", "track", {
		event_name = event_name, 
		event_properties = event_properties, 
		user_properties = user_properties
	})
end

-- Вызывается из скрипта, отправляет событие в амплитуду
function amplitude.create(event_name, event_properties, user_properties)
	if sys.get_engine_info().is_debug then
		--return
	end
	
	amplitude.event_id = amplitude.event_id + 1
	
	-- стандартные данные
	local data = {
		user_id = 10000 + db.game_id,
		device_id = sys_info.device_ident,
		event_type = event_name,
		time =  math.floor(socket.gettime()*1000),
		app_version = sys.get_config("project.version"),
		platform = sys_info.system_name,
		user_agent = sys_info.user_agent,
		os_name =  sys_info.system_name,
		os_version =  sys_info.system_version,
		device_manufacturer = sys_info.manufacturer,
		device_model = sys_info.device_model,
		country =  sys_info.territory,
		language = sys_info.language,
		event_id = amplitude.event_id,
		session_id = amplitude.session_id,
		event_properties = event_properties or {},
		user_properties = user_properties or {}
	}
	-- Уникальный идентификатор события для предотвращения дублирования
	-- Формат: device_id_user_id_timestamp_event_id
	data.insert_id = data.device_id.."_"..data.user_id.."_"..data.time.."_"..data.event_id
	-- дополнительные данные
	if event_properties then
		for k, v in pairs(event_properties) do
			-- фиксируем доход
			if k == "revenue" then
				data.revenue = v
			end

			if k == "product_name" then
				data.productId = v
			end

			if k == "product_type" then
				data.revenueType = v
			end
		end
	end

	local delayed = 0.1

	-- добавляем данные в ожидание
	table.insert(amplitude.events_pool, data)

	-- пересоздаем таймер отправки
	if amplitude.timer_id then
		timer.cancel(amplitude.timer_id)
		amplitude.timer_id = nil
	end

	-- если пулл переполнен, то отправляем сразу
	if #amplitude.events_pool == 10 then
		delayed = 0
	end
	
	-- спустя delayed аналитика отправится
	amplitude.timer_id = timer.delay(delayed, false, function ()
		if #amplitude.events_pool > 0 then
			local post_data = json_stringify({api_key = amplitude.api_key, events = amplitude.events_pool})
			amplitude.sendRequest(post_data)
		end
		amplitude.events_pool = {}
		amplitude.timer_id = nil
	end)
end

function amplitude.sendRequest(post_data)
	http.request("https://api.amplitude.com/2/httpapi", "POST", function(self, _, response)
		
		-- связь удачная и мы не отменили соединение
		if response.status == 200 then
			-- удачно отправили событие
		else
			-- ошибка - пытаемся переотправить
			pprint("Amplitude request failed with status:", response.status)
			amplitude.retryRequest(post_data)
		end
	end, {["Content-Type"] = "application/json", ["Accept"] = "*/*"}, post_data, nil)
end

-- Функция для повторной отправки запроса
function amplitude.retryRequest(post_data, attempt)
	attempt = attempt or 1
	
	if attempt <= amplitude.retry_attempts then
		pprint("Retrying Amplitude request, attempt:", attempt, "of", amplitude.retry_attempts)
		
		-- Увеличиваем задержку с каждой попыткой (exponential backoff)
		local delay = amplitude.retry_delay * (2 ^ (attempt - 1))
		
		timer.delay(delay, false, function()
			http.request("https://api.amplitude.com/2/httpapi", "POST", function(self, _, response)
				if response.status == 200 then
					pprint("Amplitude retry successful on attempt:", attempt)
				else
					pprint("Amplitude retry failed on attempt:", attempt, "status:", response.status)
					-- Рекурсивно пытаемся еще раз
					amplitude.retryRequest(post_data, attempt + 1)
				end
			end, {["Content-Type"] = "application/json", ["Accept"] = "*/*"}, post_data, nil)
		end)
	else
		pprint("Amplitude request failed after", amplitude.retry_attempts, "attempts. Giving up.")
		-- Здесь можно добавить логирование в файл или отправку в другую систему мониторинга
	end
end

return amplitude