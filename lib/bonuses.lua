local bonuses = {}
local loot_manager = require "lib.gui.loot_manager"

-- Функция для проверки валидности значения из веб-интерфейса
local function is_valid_value(value)
	return value and 
	value ~= "" and 
	value ~= "null" and 
	value ~= "undefined" and 
	value ~= "false" and
	value ~= false
end

-- Получить bonus_id из веб-интерфейса Telegram
function bonuses.get_bonus_id_from_web()
	if html5 then
		local bonus_id = html5.run("getBonusId()")

		if is_valid_value(bonus_id) then
			print("Получен bonus_id из веб-интерфейса:", bonus_id)
			return bonus_id
		else
			print("bonus_id не найден в start_param, получено:", tostring(bonus_id))
			return nil
		end
	else
		print("bonuses.get_bonus_id_from_web() не работает вне HTML5")
		return nil
	end
end

-- Обратиться к серверу за бонусом
function bonuses.claim_bonus(bonus_id, success_callback, error_callback)
	if not is_valid_value(bonus_id) then
		print("Ошибка: bonus_id не валиден:", tostring(bonus_id))
		if error_callback then
			error_callback({error = {text = "bonus_id отсутствует или не валиден"}})
		end
		return
	end

	print("Отправляем запрос на получение бонуса:", bonus_id)

	-- Используем существующую систему запросов к серверу
	request('bonuses', {
		method = "claim",
		bonus_id = bonus_id
	}, function(response)
		print("Бонус успешно получен:")
		pprint(response)

		-- Если в ответе есть награда - выдаем через loot_manager
		if response.reward and response.reward.type and response.reward.value then
			local reward = response.reward
			print(string.format("Выдаем награду: %s x%d", reward.type, reward.value))

			-- Выдаем лут с анимацией в центр экрана
			loot_manager.loot({
				x = 1080/2, 
				y = 1920/2 - 420, 
				count = reward.value, 
				type = reward.type
			})
		end

		if success_callback then
			success_callback(response)
		end
	end, function(error_data)
		print("Ошибка при получении бонуса:")
		pprint(error_data)

		if error_callback then
			error_callback(error_data)
		else
			-- Показать стандартное окно ошибки
			popup.show("error", {}, {code = error_data.error or "unknown_bonus_error"})
		end
	end, true) -- true = показать лоадер
end

-- Проверить и получить бонус при запуске игры
function bonuses.check_and_claim_startup_bonus(success_callback, error_callback)
	local bonus_id = bonuses.get_bonus_id_from_web()

	if bonus_id then
		print("Найден стартовый бонус, пытаемся его получить...")
		bonuses.claim_bonus(bonus_id, success_callback, error_callback)
	else
		print("Стартовый бонус не найден")
		if error_callback then
			error_callback({error = {text = "Стартовый бонус не найден"}})
		end
	end
end

-- Получить информацию о бонусе (без его получения)
function bonuses.get_bonus_info(bonus_id, success_callback, error_callback)
	if not is_valid_value(bonus_id) then
		print("Ошибка: bonus_id не валиден для получения информации:", tostring(bonus_id))
		if error_callback then
			error_callback({error = {text = "bonus_id отсутствует или не валиден"}})
		end
		return
	end

	print("Запрашиваем информацию о бонусе:", bonus_id)

	request('bonuses', {
		method = "info",
		bonus_id = bonus_id
	}, function(response)
		print("Информация о бонусе получена:")
		pprint(response)

		if success_callback then
			success_callback(response)
		end
	end, function(error_data)
		print("Ошибка при получении информации о бонусе:")
		pprint(error_data)

		if error_callback then
			error_callback(error_data)
		end
	end, false) -- false = не показывать лоадер для информационного запроса
end

-- Функция для ручного получения бонуса (для тестирования)
function bonuses.manual_claim_bonus(bonus_id)
	print("=== РУЧНОЕ ПОЛУЧЕНИЕ БОНУСА ===")
	print("bonus_id:", tostring(bonus_id))

	if not is_valid_value(bonus_id) then
		print("❌ Ошибка: bonus_id не валиден:", tostring(bonus_id))
		return
	end

	bonuses.claim_bonus(bonus_id, 
	function(response)
		print("✅ УСПЕХ: Бонус получен!")
		print("Ответ сервера:")
		pprint(response)
	end,
	function(error_data)
		print("❌ ОШИБКА: Не удалось получить бонус")
		print("Ошибка:")
		pprint(error_data)
	end
)
end

-- Функция для тестирования бонусов (для отладки)
function bonuses.test_bonus()
	print("=== ТЕСТИРОВАНИЕ БОНУСОВ ===")
	
	local bonus_id = bonuses.get_bonus_id_from_web()
	print("bonus_id:", tostring(bonus_id))
	
	if bonus_id then
		print("Найден бонус, тестируем получение...")
		bonuses.manual_claim_bonus(bonus_id)
	else
		print("Бонус не найден")
	end
	
	print("=== ТЕСТИРОВАНИЕ ЗАВЕРШЕНО ===")
end

return bonuses