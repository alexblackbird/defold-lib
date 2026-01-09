local M = {}

M._handlers = {}

-- Добавить обработчик для кнопки
function M.add(node_id, handler)
    M._handlers[node_id] = handler
end

-- Вызвать обработчик для кнопки (вызывается из on_input)
function M.handle(self, action_id, action)
    if action_id == hash("touch") then
        for node_id, handler in pairs(M._handlers) do
            local node
            if type(node_id) == "table" and node_id.node then
                node = node_id.node
            elseif type(node_id) == "string" then
                node = gui.get_node(node_id)
            else
                node = node_id
            end
            touch(self, action, node, function()
                handler(self, node_id, action)
                return true
            end)
        end
    end
    return false
end

-- Очистить все обработчики (например, при переходе между экранами)
function M.clear()
    M._handlers = {}
end

return M 