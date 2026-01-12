local arabic = require "modules.arabic.arabic"

local lang_configs = json.decode(sys.load_resource("/configs/languages.json"))

local lang = {}

lang.language = "en"
lang.font = "font"

lang.pool = {
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

lang.russian_group = {"be", "ua", "kk", "tg"}

function lang.init(force_lang)
	if force_lang then
		lang.language = force_lang
		return
	end
	-- язык хранится в sys_info.language - это язык устройства
	-- так же язык хранится в lb - language
	-- при инициализации мы принимаем сохраненный язык из lb
	-- если его нет, то по умолчанию ставим язык устройства
	-- далее ищем этот язык в pool и если не находим, то
	-- если это снг то русский, если же это другие языки то английский
	lang.language = lb.get("language", sys_info.language)

	-- проверяем, есть ли такой язык а базе языков
	local result = false 
	for i, v in ipairs(lang.pool) do
		if lang.language == v.code then
			result = true
			lang.font = v.font
			break
		end
	end

	-- язык не нашелся
	if not result then
		-- выбираем подходящий - если снг - русский, если другой - английский
		if tableGetIndex(lang.russian_group, lang.language) then
			lang.language = "ru"
		else
			lang.language = "en"
		end
	end

	if sys.get_engine_info().is_debug then
		--lang.language = "ko"
		--lang.font = "font_ko"
	end
end

function lang.next_lang()
	local indx = nil
	for i, v in ipairs(lang.pool) do
		if lang.language == v.code then
			indx = i
			break
		end
	end

	if lang.pool[indx+1] then
		lang.language = lang.pool[indx+1]["code"]
		lang.font = lang.pool[indx+1]["font"]
	else
		lang.language = lang.pool[1]["code"]
		lang.font = lang.pool[1]["font"]
	end

	pprint(lang.language)
end

function lang.get_lang_name_by_code(code)
	local data = nil
	for i, v in ipairs(lang.pool) do
		if code == v.code then
			data = v
			break
		end
	end
	return data.name
end

function lang.get(text_key)
	local data = nil
	for i, v in ipairs(lang_configs) do
		if v.key == text_key then
			data = v
			break
		end
	end

	if not data or not data[lang.language] then
		if data and data["en"] then
			print('TRANSLATE EMPTY ====>', text_key, lang.language)
			return data["en"]
		else
			print('TRANSLATE EMPTY ====>', text_key)
			return text_key
		end
	else
		return data[lang.language]
	end
end

-- Быстро задать текст для ноды + сохраненией скейла - не нужно прописывать
-- Глобальная таблица для хранения значений scale по ключу uniqkey
local scaleTable = {}

function lang.get_font_name(node, font)
	local font_name = font and font or lang.font

	local current_font = gui.get_font(node)
	--[[
	if font_name == "font" then
		if current_font == hash("font_regular") then
			font_name = font_name.."_regular"
		else
			font_name = font_name.."_bold"
		end

	elseif font_name == "font_ar" then
		if current_font == hash("font_regular") or current_font == hash("font_ar_regular") then
			font_name = font_name.."_regular"
		else
			font_name = font_name.."_bold"
		end

	elseif font_name == "font_ko" then
		if current_font == hash("font_regular") or current_font == hash("font_ko_regular") then
			font_name = font_name.."_regular"
		else
			font_name = font_name.."_bold"
		end

	elseif font_name == "font_ja" then
		if current_font == hash("font_regular") or current_font == hash("font_ja_regular") then
			font_name = font_name.."_regular"
		else
			font_name = font_name.."_bold"
		end
	end]]

	return font_name
end

-- Функция для разделения текста на слова
local function splitTextIntoWords(text)
	local words = {}
	for word in utf8.gmatch(text, "%S+") do
		table.insert(words, word)
	end
	return words
end

-- по первому символу возвращает изначальный размер строки в одну линию
local function getMaxHeightByFirstLetter(node, text)
	-- добавить 1 символ из набора xn бы посмотреть высоту
	gui.set_text(node, utf8.sub(text, 1, 1))
	local text_data = gui.get_text_metrics_from_node(node)

	-- строка снова пустая
	gui.set_text(node, "")

	return text_data.height
end

-- Функция для добавления текста в GUI-узел и обрезки его до указанной ширины
local function addTextAndTrimIfNeededAR(node, text, max_height)
	if not max_height then
		max_height = getMaxHeightByFirstLetter(node, text)
	end

	local current_text = gui.get_text(node)

	-- Разбиваем текст на слова
	local words = splitTextIntoWords(text)

	-- Добавляем весь текст в узел, разделяя его по словам
	if current_text == "" then
		gui.set_text(node, table.concat(words, " "))
	else
		gui.set_text(node, current_text .. "\n" .. table.concat(words, " "))
	end

	-- Получаем ширину текста
	local text_data = gui.get_text_metrics_from_node(node)
	local current_height = text_data.height
	local removed_text = "" -- Строка для хранения удаленного текста
	local increased_height = nil

	-- Если ширина превышает максимальное значение
	while current_height > max_height do
		-- Удаляем первое слово из текста
		local first_word = table.remove(words, 1)
		removed_text = removed_text .. first_word .. " "

		-- Добавляем весь текст в узел, разделяя его по словам
		if current_text == "" then
			gui.set_text(node, table.concat(words, " "))
		else
			gui.set_text(node, current_text .. "\n" .. table.concat(words, " "))
		end

		-- Получаем новую ширину текста
		text_data = gui.get_text_metrics_from_node(node)
		current_height = text_data.height

		-- сохраняем увеличиный размер строки
		if current_height <= max_height then
			increased_height = current_height
		end
	end

	--print("Удаленный текст:", removed_text)
	if removed_text and #removed_text > 0 then
		addTextAndTrimIfNeededAR(node, removed_text, current_height + 99) -- TODO вообщем так и не понял как добыть этот 99
	end
end

function addTextAndTrimIfNeededJA(node, text, max_height)
	if not max_height then
		max_height = getMaxHeightByFirstLetter(node, text)
	end

	-- Разбиваем текст на слова
	local words = {}
	for word in string.gmatch(text, "[^%s]+") do
		table.insert(words, word)
	end

	local test_text = ""

	-- Добавляем слова поочередно и проверяем высоту
	for _, word in ipairs(words) do
		gui.set_text(node, test_text.." "..word)

		-- Получаем высоту текста
		local text_data = gui.get_text_metrics_from_node(node)
		local current_height = text_data.height

		-- Если высота превышает максимальное значение, откатываемся на одно слово назад и завершаем цикл
		if current_height > max_height then
			test_text = test_text.." "..word
			gui.set_text(node, test_text)
			max_height = current_height
		else
			test_text = test_text..word
		end
	end
end

-- если арабский текст для правых строк - отразить
function convert_to_arabic_style_for_right(node, pivot)
	local font_name = lang.get_font_name(node)
	if string.find(font_name, "font_ar") then
		-- установить пивот
		gui.set_pivot(node, pivot or gui.PIVOT_E)
		local pos = gui.get_position(node)
		gui.set_position(node, vmath.vector3(-pos.x, pos.y, 0))
	end
end

function lang.set(nodeName, textKey, params)
	-- настройки по умолчанию
	if params == nil then
		params = {scale = true, translate = true, font = nil}
	end

	local node = (type(nodeName) == 'string' and gui.get_node(nodeName) or nodeName)

	local text

	if params.translate ~= nil and params.translate == false then
		text = textKey
	else
		text = lang.get(textKey)
	end

	-- Подстановка переменных вида {key} и :key: из params.vars
	if params.vars and type(params.vars) == 'table' then
		for k, v in pairs(params.vars) do
			-- Поддержка формата :key:
			text = string.gsub(text, ':'..k..':', v)
			-- Поддержка формата {key}
			text = string.gsub(text, '%{'..k..'%}', v)
			-- Поддержка формата :key:
			text = string.gsub(text, ': '..k..' :', v)
			-- Поддержка формата {key}
			text = string.gsub(text, '%{ '..k..' %}', v)
		end
	end

	local font_name = lang.get_font_name(node, params.font)

	-- нужно сохранять инфу в table дополнительно

	gui.set_font(node, font_name)

	if string.find(font_name, "font_ar") then
		-- если арабский текст
		-- мы инвертируем текст и слепляем его переходами
		-- мы печаетем по символу и переносим текст так чтобы он писался сверху вниз а не снизу вверх
		text = arabic.convert(text)
		gui.set_text(node, "")
		-- Добавляем текст и обрезаем его до указанной ширины
		addTextAndTrimIfNeededAR(node, text)

	elseif string.find(font_name, "font_ja") then
		-- если японский текст
		-- мы печатаем по символу и слепляем всё и если не хватает больше места - мы добавляем пробел
		gui.set_text(node, "")
		addTextAndTrimIfNeededJA(node, text)
	else
		gui.set_text(node, text)
	end

	if params.scale ~= nil and params.scale == false then
		-- делать текста не нужно
		return true
	end

	local uniqkey = (type(nodeName) == 'string' and tostring(msg.url())..nodeName or nodeName)
	local text_data = gui.get_text_metrics_from_node(node)
	local target_width = gui.get_size(node).x
	local target_height = gui.get_size(node).y

	-- Проверяем, есть ли уже значение scale для данного uniqkey
	local scale = scaleTable[uniqkey]

	if not scale then
		-- Если нет, то сохраняем текущее значение scale в таблице
		scale = gui.get_scale(node)
		scaleTable[uniqkey] = scale
	end

	if text_data.width > target_width then
		local factor = target_width / text_data.width
		gui.set_scale(node, vmath.vector3(scale.x * factor, scale.y * factor, 1))
	end
end

-- Функция для проверки, является ли символ английской буквой
function lang.isEnglishLetter(char)
	return char:match("[%a%s%-]") ~= nil
end

return lang
