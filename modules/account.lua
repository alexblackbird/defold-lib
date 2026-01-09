local account = {}

-- Модуль для работы с аккаунтами пользователей
-- Поддерживает получение данных кампании привлечения (acquisition data) и рефералов
-- Данные получаются из Telegram Mini App через HTML5 интерфейс

local function error_callback(jd)
	msg.post('/loader#gui', 'hide_background')
	if jd.error then
		popup.show("error", {}, {code = jd.error})
	else
		-- Неизвестная ошибка
		popup.show("error", {}, {code = "Unkhnown"})
	end
end

function account.login()
	local params = {}

	-- добавляем рефферала
	if sys_info.system_name == "HTML5" then
		local referral_id = html5.run("getRefferal()")
		if referral_id then
			params.referral_id = referral_id
		end

		-- добавляем данные кампании привлечения
		local acquisition_data_json = html5.run("getAcquisitionData()")
		if acquisition_data_json and type(acquisition_data_json) == "string" then
			local success, acquisition_data = pcall(json.decode, acquisition_data_json)
			if success and acquisition_data and type(acquisition_data) == "table" then
				-- Проверяем и добавляем каждое поле, если оно существует
				if acquisition_data.publisher_id then
					params.publisher_id = acquisition_data.publisher_id
				end
				if acquisition_data.click_id then
					params.click_id = acquisition_data.click_id
				end
				if acquisition_data.campaign_id then
					params.campaign_id = acquisition_data.campaign_id
				end
				if acquisition_data.banner_id then
					params.banner_id = acquisition_data.banner_id
				end
				if acquisition_data.utm_source then
					params.utm_source = acquisition_data.utm_source
				end
				print("Successfully parsed acquisition data")
			else
				print("Failed to parse acquisition data JSON")
			end
		else
			print("No valid acquisition data received")
		end

		print("acquisition_data_json:")
		print(acquisition_data_json)
	end

	-- для авторизации
	params.init_data = json.encode(telegram.params)

	-- для противодействия ботомайнеров
	params.device_fingerprint = lb.get("device_fingerprint", "")
	
	-- game_id и token не хранится на устройстве
	-- каждый раз при вызове account выдается новый токен
	-- при заходе всё равно обращаемся к account
	-- отдаем данные для авторизации
	request('account', params, function (jd)
		-- сохраняем данные для использования
		db = jd

		ab_test.init()

		if jd.new_user then
			-- создание аккаунта c данными кампании привлечения
			amplitude.track("visits", { new_user = true }, {
				is_debug = sys.get_engine_info().is_debug,
				referral = db.referral_id,
				ab_group = ab_test.ab_group,
				publisher_id = params.publisher_id or nil,
				click_id = params.click_id or nil,
				campaign_id = params.campaign_id or nil,
				banner_id = params.banner_id or nil,
				utm_source = params.utm_source or nil,
			})

			-- фиксируем как заработанные деньги
			amplitude.track("earn", { type = "coins", value = db.coins })

			-- показать термсы
			--popup.show("laws_documents")
			-- приветствие
			popup.show("welcome", {no_stack = true})
		else
			amplitude.track("visits", { new_user = false })
		end

		-- если пользователь не завершил регистрацию
		if db.avatar_id == 0 then
			-- приветствие
			popup.show("welcome", {no_stack = true}) 
		end
		
		-- время пошло
		msg.post("loader:/loader", "synchronizeTime")
		
		-- скрыть лоадер
		msg.post('/loader#gui', 'hide_background')
		
		-- Запускаем главное меню
		msg.post("loader:/loader", "MAIN_MENU")
	end, error_callback, false)
end

function account.create(params, callback)
	request('account', params, function (jd)
		-- успешная регистрация
		callback()

	end, error_callback, true)
end

return account