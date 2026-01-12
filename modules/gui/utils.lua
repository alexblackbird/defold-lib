function enable(nodeName)
	if type(nodeName) == "string" then
		gui.set_enabled(gn(nodeName), true)
	else
		gui.set_enabled(nodeName, true)
	end
end

function disable(nodeName)
	if type(nodeName) == "string" then
		gui.set_enabled(gn(nodeName), false)
	else
		gui.set_enabled(nodeName, false)
	end
end

function visible(nodeName, enable)
	gui.set_visible(gn(nodeName), enable)
end

function color(nodeName, hex)

	if type(nodeName) == "string" then
		gui.set_color(gn(nodeName), hexToVector4(hex))
	else
		gui.set_color(nodeName, hexToVector4(hex))
	end
end

-- Play flipbook
function pf(nodeName, flipbook)
	if type(nodeName) == "userdata" then
		gui.play_flipbook(nodeName, flipbook)
	else
		gui.play_flipbook(gn(nodeName), flipbook)
	end
end

function gn(nodeName)
	return gui.get_node(nodeName)
end

function vector(x,y,z)
	return vmath.vector3(x, y or x, z or x)
end

-- равняет ценнки на кнопке
function gui_align_text()
	local text_data = gui.get_text_metrics_from_node(gui.get_node("buy/label"))
	local BUTTON_SCALE = 1.2
	local MAX_WIDTH = 120
	local new_scale = BUTTON_SCALE / (text_data.width / MAX_WIDTH)

	if new_scale < BUTTON_SCALE then
		gui.set_scale(gui.get_node("buy/label"), vmath.vector4(new_scale))
		gui.set_scale(gui.get_node("buy/label_shadow"), vmath.vector4(new_scale))
		gui.set_scale(gui.get_node("buy/price_shadow"), vmath.vector4(new_scale))
		gui.set_scale(gui.get_node("buy/price"), vmath.vector4(new_scale))
	else
		new_scale = BUTTON_SCALE
	end

	-- выравниваем
	-- как понять что у нас длинная строка?
	local text_data_1 = gui.get_text_metrics_from_node(gui.get_node("buy/label"))
	local text_data_2 = gui.get_text_metrics_from_node(gui.get_node("buy/price"))
	local result = text_data_1.width / text_data_2.width
	local alt_result = text_data_1.width - text_data_2.width
	local pos1 = gui.get_position(gui.get_node("buy/label"))
	local pos2 = gui.get_position(gui.get_node("buy/label_shadow"))
	local pos3 = gui.get_position(gui.get_node("buy/price_shadow"))
	local pos4 = gui.get_position(gui.get_node("buy/price"))
	local pos5 = gui.get_position(gui.get_node("buy/box"))

	--окей - если он больше в два раза, то что нужно сделать
	pos1.x = -55 + ((result - 1) * (35 * new_scale))
	pos2.x = -55  + ((result - 1) * (35 * new_scale))
	pos3.x = 53 + ((result - 1) * (35 * new_scale))
	pos4.x = 53 + ((result - 1) * (35 * new_scale))
	pos5.x = 0 + ((result - 1) * (35 * new_scale))

	gui.set_position(gui.get_node("buy/label"), pos1)
	gui.set_position(gui.get_node("buy/label_shadow"), pos2)
	gui.set_position(gui.get_node("buy/price_shadow"), pos3)
	gui.set_position(gui.get_node("buy/price"), pos4)
	gui.set_position(gui.get_node("buy/box"), pos5)
end


-- текстовое поле
function gui_new_text_node(pos, text, params)
	local node = gui.new_text_node(pos, text)
	gui.set_font(node, hash("font"))

	if params.parent then
		gui.set_parent(node, gui.get_node(params.parent))
	end

	if params.layer then
		gui.set_layer(node, hash(params.layer))
	end

	if params.color then
		gui.set_color(node, params.color)
	end

	if params.outline then
		gui.set_outline(node, params.outline)
	end

	return node
end

-- иконка на поле
function gui_new_box_node(pos, texture, icon, params)
	local node = gui.new_box_node(pos, vmath.vector3(0,0,0))
	gui.set_texture(node, texture)
	gui.play_flipbook(node, icon)
	gui.set_size_mode(node, gui.SIZE_MODE_AUTO)

	if params.scale then
		gui.set_scale(node, vmath.vector3(params.scale, params.scale, 1))
	end

	if params.parent then
		gui.set_parent(node, gui.get_node(params.parent))
	end

	if params.layer then
		gui.set_layer(node, params.layer)
	end
	return node
end

-- очищаем gui table
function gui_delete_table(tables)

	if not tables then
		return {}
	end

	if #tables > 0 then
		for i,node in ipairs(tables) do
			if node then
				gui.delete_node(node)
			end
		end
		tables = {}
	end
	return {}
end

function getDistance(objA, objB)
	local xDist = objB.x - objA.x
	local yDist = objB.y - objA.y
	return math.sqrt( (xDist ^ 2) + (yDist ^ 2) ) 
end

-- функция, которая проверяет, есть ли число number в таблице table
function contains(t, n)
	for _, value in pairs(t) do
		if value == n then
			return true
		end
	end
	return false
end

function has_value (tab, val)
	local str = string.gsub(val, "%s+", "")
	for index, value in ipairs(tab) do
		if string.find(str, value) then
			return true
		end
	end
	return false
end

function split(str, delimiter)
	local result = {}
	for token in string.gmatch(str, "([^" .. delimiter .. "]+)") do
		table.insert(result, token)
	end
	return result
end

function get_random(n, m)
	math.randomseed(os.time())
	math.random(n,m)
	math.random(n,m)
	math.random(n,m)
	return math.random(n,m)
end

-- кастомизируем надпись subscriptions_data.namekey
function replace_pattern(msg, new_data, pattern)
	-- Заменяем шаблонный тег на новую цену
	msg = string.gsub(msg, ":%s*"..pattern.."%s*:", new_data)
	-- Заменяем шаблонный тег с пробелами на новую цену
	return string.gsub(msg, ":%s*"..pattern.."%s*:", new_data)
end

function no_animation(node)
	local pos = gui.get_position(node)
	gui.animate(node, "position.x", pos.x + 60, gui.EASING_OUTQUAD, 0.1, 0, function ()
		gui.animate(node, "position.x", pos.x -30, gui.EASING_OUTQUAD, 0.1, 0, function ()
			gui.animate(node, "position.x", pos.x + 15, gui.EASING_OUTQUAD, 0.1, 0, function ()
				gui.animate(node, "position.x", pos.x -10, gui.EASING_OUTQUAD, 0.05, 0, function ()
					gui.animate(node, "position.x", pos.x + 2, gui.EASING_OUTQUAD, 0.05)
				end)
			end)
		end)
	end)
end

local animateLevitationEffectTable = {}
function animateLevitaitonEffect(nodeName)
	local node

	if type(nodeName) == "string" then
		node = gui.get_node(nodeName)
	else
		node = nodeName
		nodeName = gui.get_id(nodeName)
	end

	local uniqkey = tostring(msg.url())..nodeName

	-- Проверяем, есть ли уже значение scale для данного uniqkey
	local params = animateLevitaitonEffectTable[uniqkey]

	if not params then
		-- Если нет, то сохраняем текущее значение в таблице
		params = {rot = gui.get_euler(node), pos = gui.get_position(node)}
		animateLevitaitonEffectTable[uniqkey] = params
	else
		-- Остановить предыдущие анимации перед запуском новых
		gui.cancel_animation(node, 'position.y')
		gui.cancel_animation(node, 'euler.z')
		gui.set_euler(node, params.rot)
		gui.set_position(node, params.pos)
	end

	gui.animate(node, 'position.y', params.pos.y + 4, gui.EASING_INOUTSINE, 2, 0, nil, gui.PLAYBACK_LOOP_PINGPONG)
	gui.animate(node, 'euler.z', params.rot.z - 6, gui.EASING_INOUTSINE, 4, 0, nil, gui.PLAYBACK_LOOP_PINGPONG)
end

function animateScaleEffect(self, nodeName)
	local node

	if not self.animateScaleEffectTable then
		self.animateScaleEffectTable = {}
	end

	if type(nodeName) == "string" then
		node = gui.get_node(nodeName)
	else
		node = nodeName
		nodeName = gui.get_id(nodeName)
	end

	local uniqkey = tostring(msg.url()) .. nodeName

	-- Проверяем, есть ли уже плейсхолдер для данного uniqkey
	local data = self.animateScaleEffectTable[uniqkey]

	if not data then
		-- Создаём новый плейсхолдер
		local placeholder = gui.new_box_node(gui.get_position(node), vmath.vector3(0,0,0))
		gui.set_parent(placeholder, gui.get_parent(node))
		gui.set_parent(node, placeholder)
		gui.set_position(node, vmath.vector3(0, 0, 0))

		-- Сохраняем начальные параметры
		data = {
			placeholder = placeholder,
			node = node,
			scale = gui.get_scale(node) -- Сохраняем масштаб оригинального узла
		}
	else
		-- Останавливаем текущие анимации и восстанавливаем параметры
		gui.cancel_animation(data.placeholder, "scale")
		gui.set_scale(data.placeholder, data.scale)
		timer.cancel(data.timer_id)
	end

	function scale_it()
		gui.animate(data.placeholder, "scale", data.scale * 1.1, gui.EASING_INOUTSINE, 1.5, 0, nil, gui.PLAYBACK_ONCE_PINGPONG)
	end

	--timer.delay(1, false, scale_it)
	local timer_id = timer.delay(3, true, scale_it)

	data.timer_id = timer_id
	self.animateScaleEffectTable[uniqkey] = data
end

function clearAllAnimationEffects(self)
	if not self.animateScaleEffectTable then
		return
	end
	for uniqkey, data in pairs(self.animateScaleEffectTable) do
		-- Останавливаем анимации
		gui.cancel_animation(data.placeholder, "scale")

		-- Восстанавливаем масштаб оригинального узла
		gui.set_scale(data.node, data.scale)

		-- Убираем оригинальный узел из временного узла
		gui.set_parent(data.node, gui.get_parent(data.placeholder))
		gui.set_position(data.node, gui.get_position(data.placeholder))

		-- Удаляем временный узел
		gui.delete_node(data.placeholder)

		-- Останавливаем таймер
		if data.timer_id then
			timer.cancel(data.timer_id)
		end
	end

	-- Очищаем таблицу
	self.animateScaleEffectTable = {}
end

function hexToVector4(hexColor)
	-- Удаляем символ "#" из строки
	hexColor = string.sub(hexColor, 2)

	-- Извлекаем красный, зеленый и синий компоненты
	local r = tonumber(string.sub(hexColor, 1, 2), 16) / 255
	local g = tonumber(string.sub(hexColor, 3, 4), 16) / 255
	local b = tonumber(string.sub(hexColor, 5, 6), 16) / 255

	-- Создаем vmath.vector4 с компонентами цвета и альфа-каналом 1
	local color = vmath.vector4(r, g, b, 1)

	return color
end

function updateProgressBar(node, width, height, progress_count, overall_count, duration, min_width)
	gui.set_enabled(node, true)

	-- Определяем минимальную ширину
	local actual_min_width = min_width or height

	-- Используем интерполяцию между минимальной и максимальной шириной
	-- При progress_count = 0: current_weight = actual_min_width
	-- При progress_count = overall_count: current_weight = width
	local progress_ratio = progress_count / overall_count
	local current_weight = math.ceil(actual_min_width + (width - actual_min_width) * progress_ratio)

	-- Убеждаемся что не выходим за границы
	if current_weight < actual_min_width then
		current_weight = actual_min_width
	end

	if current_weight > width then
		current_weight = width
	end

	if not duration then
		duration = 0
	end

	gui.animate(node, "size", vmath.vector3(current_weight, height, 0), gui.EASING_INOUTSINE, duration, 0, function ()
		-- вообще ничего нет - скрыть наш бегунок
		if progress_count == 0 then
			--	gui.set_enabled(node, false)
			--	gui.set_size(node, vmath.vector3(min_width or height, height, 0))
		end
	end)
end

function align_icon_and_text(text_node, root_node, icon_node, alignment)
	alignment = alignment or "left"  -- по умолчанию left

	-- получаем длинну текста
	local icon_width = gui.get_size(icon_node).x
	local space = 10
	local text_metrics = gui.get_text_metrics_from_node(text_node)

	-- суммируем весь контент
	local scale_text = gui.get_scale(text_node)
	local scale_icon = gui.get_scale(icon_node)

	local width = (icon_width*scale_icon.x)  + space + (text_metrics.width*scale_text.x)

	local pos = gui.get_position(root_node)
	local x_pos

	if alignment == "right" then
		x_pos = width/2
	else
		x_pos = -(width/2)
	end
	-- выравниваем
	gui.set_position(root_node, vmath.vector3(x_pos, pos.y, 0))
end

function clone_tree(self, template_id, parent_id)
	local nodes = gui.clone_tree(gui.get_node(template_id))
	local node_root = nodes[template_id]

	if self.instances then
		self.instances["reward1"] = nodes
	end

	gui.set_enabled(node_root, true)

	if parent_id then
		gui.set_parent(node_root, gui.get_node(parent_id))
	end

	return nodes, node_root
end

--------------------------------------------------------------------
-- helper: выполнить JS-функцию window.<fn>(arg1,arg2,…)
--------------------------------------------------------------------
function esc(s)        -- грубое экранирование для JS-строки
	return s:gsub("\\","\\\\"):gsub("'", "\\'"):gsub("\n","\\n")
end

function js(fn, ...)
	if sys_info.system_name ~= "HTML5" then 
		return 
	end

	local buf = {}
	for i,v in ipairs({...}) do
		if type(v) == "string" then
			buf[i] = "'" .. esc(v) .. "'"
		else                      -- таблицы / числа → JSON
			buf[i] = json.encode(v)
		end
	end
	html5.run( string.format("%s(%s);", fn, table.concat(buf, ",")) )
end

function draw(self, node_name)
	local node = gn(node_name)
	local size = gui.get_size(gn(node_name))

	-- Если это текстовая нода, используем реальную высоту текста
	if gui.get_type(node) == gui.TYPE_TEXT then
		local text_data = gui.get_text_metrics_from_node(node)
		if text_data and text_data.height > 0 then
			size.y = text_data.height
		end
	end

	local position = vmath.vector3(0, self.y_position - (size.y/2), 1)
	gui.set_position(node, position)

	self.y_position = self.y_position - size.y - self.y_space
end

function clone_tree(self, template_id, parent_id)
    local nodes = gui.clone_tree(gui.get_node(template_id))
    local node_root = nodes[template_id]
    
    if self.instances then
        self.instances["reward1"] = nodes
    end

    gui.set_enabled(node_root, true)

	if parent_id then
		gui.set_parent(node_root, gui.get_node(parent_id))
	end

    return nodes, node_root
end