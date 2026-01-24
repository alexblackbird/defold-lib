local loader = {}

-- данные с сервера
db = {}

-- данные о девайсе
sys_info = sys.get_sys_info()

function loader.init(self)
	msg.post(".", "acquire_input_focus")
end

function loader.wait_connection(callback)
	-- несколько секунд ждем подключения
	local wait_connection = nil
	wait_connection = timer.delay(1, true, function (self)
		if network.is_connected() then
			-- отключить таймер
			timer.cancel(wait_connection)

			-- теперь можем логиниться - связь есть
			callback()
		end
	end)
end

function loader.local_status(callback)
	-- Локальный статус
	timer.delay(4, false, function (self)
		if not network.is_connected() then
			callback()
		end
	end)
end

function loader.on_message(self, message_id, message, sender)
	-- показываем обращение к серверу
	if message_id == hash("request_loader_show") then
		msg.post('/loader#gui', 'request_loader_show')

	elseif message_id == hash("request_loader_hide") then
		msg.post('/loader#gui', 'request_loader_hide')
	end
end

return loader