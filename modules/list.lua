local M = {}

-- Внутреннее хранилище всех списков по id
local _lists = {}

-- parent_id — id родительской ноды, куда будут добавляться клоны (обычно background)
-- template_id — id шаблона (root node в tree)
-- data — массив данных
-- customizer(node_tree, data_item, index) — функция, которая кастомизирует клон
-- opts: { start_y, spacing, after_node_id, tail_nodes = {...}, tail_spacing = 60, placeholder_node_id = "", placeholder_height = 0, clear_old = false, scroll = nil, scroll_width = 1080 }
function M.create(id, parent_id, template_id, data, customizer, opts)
    opts = opts or {}
    local start_y = opts.start_y or -643
    local spacing = opts.spacing or 30
    local after_node_id = opts.after_node_id
    local tail_nodes = opts.tail_nodes or {}
    local tail_spacing = opts.tail_spacing or 60
    local placeholder_node_id = opts.placeholder_node_id
    local placeholder_height = opts.placeholder_height or 0
    local clear_old = opts.clear_old == true -- по умолчанию false
    local scroll = opts.scroll
    local scroll_width = opts.scroll_width or 1080
    local scroll_height = opts.scroll_height or 1080

    -- Удаляем старые ноды, если есть и если clear_old=true
    if clear_old and _lists[id] then
        for _, node in ipairs(_lists[id]) do
            gui.delete_node(node)
        end
        _lists[id] = nil
    end
    if not _lists[id] then
        _lists[id] = {}
    end

    local parent = gui.get_node(parent_id)
    local template = gui.get_node(template_id)
    local table_height = gui.get_size(template).y

    if after_node_id then
        local after_node = gui.get_node(after_node_id)
        local pos = gui.get_position(after_node)
        start_y = pos.y - table_height - spacing
    end

    local y = start_y
    local has_data = data and #data > 0
    local total_content_height = 0
    if has_data then
        total_content_height = #data * table_height + math.max(0, (#data-1)) * spacing



    elseif placeholder_node_id and placeholder_node_id ~= "" then
        local ph = (placeholder_height > 0 and placeholder_height or table_height)
        total_content_height = ph
    end
    total_content_height = total_content_height + tail_spacing

    if has_data then
        for i, item in ipairs(data) do
            local nodes = gui.clone_tree(template)
            local root = nodes[hash(template_id)]
            gui.set_enabled(root, true)
            gui.set_parent(root, parent)
            gui.set_position(root, vmath.vector3(0, y, 0))
            if customizer then
                customizer(nodes, item, i)
            end
            table.insert(_lists[id], root)
            y = y - table_height - spacing
        end
        -- Скрываем плейсхолдер, если он был показан ранее
        if placeholder_node_id and placeholder_node_id ~= "" then
            local node = gui.get_node(placeholder_node_id)
            gui.set_enabled(node, false)
        end
    elseif placeholder_node_id and placeholder_node_id ~= "" then
        local node = gui.get_node(placeholder_node_id)
        gui.set_enabled(node, true)
        gui.set_parent(node, parent)
        -- Центрируем плейсхолдер по высоте
        local ph = (placeholder_height > 0 and placeholder_height or table_height)
        gui.set_position(node, vmath.vector3(0, y - ph/2, 0))
        table.insert(_lists[id], node)
        y = y - ph - spacing
    end

    -- Сдвигаем хвостовые ноды (например, TERMS OF SERVICE, PRIVACY)
    local tail_result = {}
    for _, node_id in ipairs(tail_nodes) do
        local node = gui.get_node(node_id)
        gui.set_position(node, vmath.vector3(gui.get_position(node).x, y - tail_spacing, 0))
        table.insert(tail_result, node)
    end

    -- Возвращаем все ноды (клоны + плейсхолдер + хвостовые)
    local all_nodes = {}
    for _, n in ipairs(_lists[id]) do table.insert(all_nodes, n) end
    for _, n in ipairs(tail_result) do table.insert(all_nodes, n) end

    -- Если передан druid scroll, обновляем его размер
    if scroll then
        local scroll_height = scroll_height + total_content_height
        scroll:set_size(vmath.vector3(scroll_width, scroll_height, 0))
    end

    return all_nodes, y - tail_spacing
end

-- Удалить все ноды списка по id
function M.clear(id)
    if _lists[id] then
        for _, node in ipairs(_lists[id]) do
            gui.delete_node(node)
        end
        _lists[id] = nil
    end
end

return M 