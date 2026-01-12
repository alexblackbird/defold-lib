--[[
	ИНСТРУКЦИЯ: Как создать аватар на сцене из картинки пользователя

	1. Подключите модуль:
	local avatar = require "modules.avatar"

	2. Инициализируйте модуль в loader.script:
    -- base_url - это путь к вашему прокси-скрипту (get_photo_redirect.php), который нужен для обхода CORS.
    -- Браузеры могут блокировать прямую загрузку картинок с чужих доменов (например, Telegram).
    -- Если у вас нет своего прокси и вы уверены, что картинки грузятся напрямую, оставьте base_url пустым или не передавайте.
	avatar.init({ base_url = "https://your-backend.com/api" })

	3. Используйте в GUI скрипте:
	avatar.createAvatar(photo_url, function(texture_id, img_data)
		-- Проверяем, существует ли нода и создана ли текстура
		if gui.get_node("avatar_node") and texture_id then
			gui.set_texture(gui.get_node("avatar_node"), texture_id)
		end
	end)

    Примечание:
    - Убедитесь, что у "avatar_node" есть назначенная текстура (например, любая текстура-заглушка), иначе set_texture может не сработать.
    - Генерируемый texture_id является динамическим и уникальным.
    - Модуль внутри себя использует gui.new_texture, создавая текстуры "на лету".
      Помните, что такие текстуры занимают память. Если вы часто создаете аватары, следите за их удалением (gui.delete_texture), если это необходимо.
      В текущей реализации модуля кэширование или удаление текстур не предусмотрено (textures = {} используется в проектах для этого, но модуль не зависит от глобальной переменной).
]]


local M = {}
M.__index = M

local textures = {} -- Cache for created textures


local config = {
	base_url = ""
}

function M.init(params)
	if params.base_url then config.base_url = params.base_url end
end

function M.new(link, cb)
	local self = setmetatable({}, M)
	self.link = link
	self.cb = cb
	self.try_count = 1
	self.headers = {["Content-Type"] = "application/x-www-form-urlencoded"}

	-- BLOKED CONTENT!
	if link == 'https://vk.com/images/camera_100.png?ava=1' then
		return nil
	end

    -- Используем base_url из конфига
	self.SERVER_PATCH = config.base_url

	-- Сразу преобразуем: сходить на ваш get_photo_redirect.php
	self.link = self.SERVER_PATCH .. "/get_photo_redirect.php?url=" .. self.link

	M.sendRequest(self)
	return self
end

function M.sendRequest(params)
	pprint("sendRequest: " .. params.link)

	http.request(params.link, "GET", function(_, id, res)
		-- pprint(res)

		-- 1) Сначала проверяем 302
		if res.status == 302 then
			local new_location = res.headers["Location"] or res.headers["location"]
			if new_location then
				params.link = new_location
				M.sendRequest(params)
				return
			end
		end

		-- 2) Если статус не 200/304 - пробуем повторять
		if res.status ~= 200 and res.status ~= 304 then
			params.try_count = params.try_count + 1
			if params.try_count <= 3 then
				M.sendRequest(params)
			end
			return
		end

		-- 3) Пробуем понять, JSON это или нет
		local success, data = pcall(function()
			return json.decode(res.response)
		end)

		-- Если это JSON, и там есть photo_url - повторяем запрос
		if success and data and data.photo_url then
			pprint("Нашли photo_url:", data.photo_url)
			params.link = data.photo_url
			M.sendRequest(params)
			return
		end

		-- 4) Если не JSON, считаем, что это финальный ответ (изображение)
		local img = image.load(res.response)
		if not img then
			print("image.load вернул nil (возможно, .svg или другой неподдерживаемый формат)")
			return
		end

		local texture_id = "avatars/" .. params.link
		if gui.new_texture(texture_id, img.width, img.height, img.type, img.buffer, false) then
            textures[params.original_link] = texture_id -- Cache it
			params.cb(texture_id, img)
		else
            textures[params.original_link] = texture_id -- Cache even if new_texture failed/returned false but existed? Defold api intricacies. Assuming success references ID.
			params.cb(texture_id, img)
		end
	end, params.headers)
end

-- REQUEST INTERFACE
function M.createAvatar(link, cb)
    if textures[link] then
        -- Return cached texture immediately via callback (simulate async if needed, but sync is fine usually)
        if cb then cb(textures[link]) end
        return nil
    end

	local _req = M.new(link, cb)
    _req.original_link = link -- Store original link for caching key
	return _req
end


return {
    init = M.init,
	createAvatar = M.createAvatar
}
