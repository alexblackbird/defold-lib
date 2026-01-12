-- Универсальный модуль локализации
-- Использование: lang.init({ pool = {...} })

-- Попытка загрузить arabic модуль для конвертации
local arabic_ok, arabic = pcall(require, "modules.arabic.arabic")

local lang = {}

lang.language = "en"
lang.font = "font"
lang.pool = {}
lang.russian_group = {"be", "ua", "kk", "tg"}

local lang_configs = nil
local config = {
	translations_path = "/configs/languages.json",
	arabic_converter = arabic_ok and arabic.convert or nil,
	use_font_variants = false,  -- true для font_regular/font_bold, false для font
	switch_lang_action_id = hash("key_lshift"), -- кнопка переключения языка (debug)
}

-- Стандартный пул языков (можно переопределить)
local DEFAULT_POOL = {
	{name = "English", code = "en", font = "font"},
	{name = "Español", code = "es", font = "font"},
	{name = "日本語", code = "ja", font = "font_ja"},
	{name = "Русский", code = "ru", font = "font"},
	{name = "Français", code = "fr", font = "font"},
	{name = "Deutsch", code = "de", font = "font"},
	{name = "Italiano", code = "it", font = "font"},
	{name = "Português", code = "pt", font = "font"},
	{name = "한국어", code = "ko", font = "font_ko"},
	{name = "العربية", code = "ar", font = "font_ar"},
	{name = "Türkçe", code = "tr", font = "font"}
}

function lang.init(params)
	params = params or {}
	
	-- Настройки
	if params.pool then lang.pool = params.pool else lang.pool = DEFAULT_POOL end
	if params.translations_path then config.translations_path = params.translations_path end
	if params.arabic_converter then config.arabic_converter = params.arabic_converter end
	if params.russian_group then lang.russian_group = params.russian_group end
	if params.use_font_variants ~= nil then config.use_font_variants = params.use_font_variants end
	if params.switch_lang_action_id then config.switch_lang_action_id = hash(params.switch_lang_action_id) end
	
	-- Загрузка переводов
	local resource = sys.load_resource(config.translations_path)
	if resource then
		lang_configs = json.decode(resource)
	else
		lang_configs = {}
		print("lang: translations not found at", config.translations_path)
	end
	
	-- Определение языка
	if params.force_lang then
		lang.language = params.force_lang
	else
		lang.language = lb.get("language", sys_info.language)
	end
	
	-- Проверка языка в pool
	local found = false
	for _, v in ipairs(lang.pool) do
		if lang.language == v.code then
			found = true
			lang.font = v.font
			break
		end
	end
	
	-- Fallback
	if not found then
		local is_russian_group = false
		for _, code in ipairs(lang.russian_group) do
			if lang.language == code then
				is_russian_group = true
				break
			end
		end
		lang.language = is_russian_group and "ru" or "en"
	end
end

function lang.next_lang()
	local indx = 1
	for i, v in ipairs(lang.pool) do
		if lang.language == v.code then
			indx = i
			break
		end
	end
	
	indx = (indx % #lang.pool) + 1
	lang.language = lang.pool[indx].code
	lang.font = lang.pool[indx].font
end

function lang.get_lang_name_by_code(code)
	for _, v in ipairs(lang.pool) do
		if code == v.code then
			return v.name
		end
	end
	return code
end

function lang.get(text_key)
	if not lang_configs then return text_key end
	
	for _, v in ipairs(lang_configs) do
		if v.key == text_key then
			if v[lang.language] then
				return v[lang.language]
			elseif v["en"] then
				return v["en"]
			end
			break
		end
	end
	return text_key
end

-- Таблица для хранения scale
local scaleTable = {}

function lang.get_font_name(node, font)
	local font_name = font or lang.font
	
	-- Если не используем варианты шрифтов (font_regular/font_bold) - просто возвращаем базовое имя
	if not config.use_font_variants or not node then
		return font_name
	end
	
	-- Если используем варианты - добавляем суффикс _regular или _bold
	local current_font = gui.get_font(node)
	
	if font_name == "font" then
		if current_font == hash("font_regular") then
			return "font_regular"
		else
			return "font_bold"
		end
	elseif font_name == "font_ar" then
		if current_font == hash("font_regular") or current_font == hash("font_ar_regular") then
			return "font_ar_regular"
		else
			return "font_ar_bold"
		end
	elseif font_name == "font_ko" then
		return "font_ko_regular"
	elseif font_name == "font_ja" then
		return "font_ja_regular"
	end
	
	return font_name
end

function lang.set(nodeName, textKey, params)
	params = params or {scale = true, translate = true}
	
	local node = type(nodeName) == 'string' and gui.get_node(nodeName) or nodeName
	local text = params.translate == false and textKey or lang.get(textKey)
	
	-- Подстановка переменных
	if params.vars and type(params.vars) == 'table' then
		for k, v in pairs(params.vars) do
			text = string.gsub(text, ':'..k..':', v)
			text = string.gsub(text, '%{'..k..'%}', v)
		end
	end
	
	local font_name = lang.get_font_name(node, params.font)
	gui.set_font(node, font_name)
	
	-- Обработка арабского текста
	if string.find(font_name, "font_ar") and config.arabic_converter then
		text = config.arabic_converter(text)
	end
	
	gui.set_text(node, text)
	
	-- Авто-масштабирование текста
	if params.scale == false then return end
	
	local uniqkey = type(nodeName) == 'string' and tostring(msg.url())..nodeName or nodeName
	local text_data = gui.get_text_metrics_from_node(node)
	local target_width = gui.get_size(node).x
	
	local scale = scaleTable[uniqkey]
	if not scale then
		scale = gui.get_scale(node)
		scaleTable[uniqkey] = scale
	end
	
	if text_data.width > target_width then
		local factor = target_width / text_data.width
		gui.set_scale(node, vmath.vector3(scale.x * factor, scale.y * factor, 1))
	end
end

function lang.isEnglishLetter(char)
	return char:match("[%a%s%-]") ~= nil
end

-- Арабский стиль для правых строк
function lang.convert_to_arabic_style_for_right(node, pivot)
	local font_name = lang.get_font_name(node)
	if string.find(font_name, "font_ar") then
		gui.set_pivot(node, pivot or gui.PIVOT_E)
		local pos = gui.get_position(node)
		gui.set_position(node, vmath.vector3(-pos.x, pos.y, 0))
	end
end

function lang.on_input(self, action_id, action)
	if action_id == config.switch_lang_action_id and action.released and sys.get_engine_info().is_debug then
		lang.next_lang()
		if lb then
			lb.set("language", lang.language)
		end
	end
end

return lang
