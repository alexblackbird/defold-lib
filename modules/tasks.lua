-- Универсальный модуль для работы с задачами (tasks)
-- Не содержит UI-специфики и game-специфичной логики, работает через adapter

--[[
CHECK LIST как заставить работать
1 - Импортировать buttons и list.
2 - Создать tasks_adapter.
3 - Инициализировать модуль через:
tasks.init(self, db.configs.tasks, tasks_adapter, buttons, false).
4 - В базе добавить поле:
ALTER TABLE users
ADD COLUMN `tasks` varchar(4000) COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '{}';
5 - В account отдавать:
$response['tasks'] = $data['tasks'];
]]

local list = require("modules.list")

local tasks = {}
tasks.send_data_pool = {}
tasks.request_in_progress = false
tasks.button_clicked = {} -- Отслеживание нажатий кнопок для всех задач
tasks.active_buttons = {} -- Храним ссылки на активные кнопки для обновления состояния
tasks.adapter = nil -- Сохраняем адаптер для использования в send_data

-- Функции для проверки состояния кнопки (используют adapter)
function tasks.is_open_state(button_node, adapter)
    local node = type(button_node) == "string" and gn(button_node) or button_node
    return gui.get_flipbook(node) == hash(adapter.button_states.primary)
end

function tasks.is_check_state(button_node, adapter)
    local node = type(button_node) == "string" and gn(button_node) or button_node
    return gui.get_flipbook(node) == hash(adapter.button_states.secondary)
end

-- Главная функция инициализации
-- adapter - конфигурация UI (tasks_adapter.lua)
-- configs - данные задач
-- buttons - модуль для обработки кнопок
-- layout - (опционально) Druid Layout для добавления созданных нод
function tasks.init(self, configs, adapter, buttons, layout)
    -- Сохраняем адаптер для использования в других функциях
    tasks.adapter = adapter

    -- Сбрасываем флаг запроса на случай если предыдущий запрос не завершился
    tasks.request_in_progress = false

    -- Параметры из адаптера
    local template_id = adapter.template_id
    local parent_id = adapter.parent_id
    local y_space = adapter.y_space

    -- Динамически определяем высоту элемента
    local template_node = gui.get_node(template_id)
    local element_height = gui.get_size(template_node).y

    -- Сохраняем layout для использования
    tasks.layout = layout

    -- если позиция не установлена и layout не передан, устанавливаем в 0
    if not layout and not self.y_position then
        self.y_position = 0
    end

    -- Парсим tasks если это строка JSON
    if db.tasks and type(db.tasks) == "string" then
        local success, parsed_tasks = pcall(json.decode, db.tasks)
        if success and parsed_tasks then
            db.tasks = parsed_tasks
            print("Parsed tasks from JSON string:", db.tasks)
        else
            print("Failed to parse tasks JSON string:", db.tasks)
            db.tasks = {}
        end
    elseif not db.tasks then
        db.tasks = {}
    end

    -- Динамическая генерация всех TASKS через list.create
    local function fill_task(nodes, task, i)
        -- Заполняем ноды данными задачи используя маппинг из конфигурации
        lang.set(nodes[hash(adapter.nodes.header_txt)], task.header)
        lang.set(nodes[hash(adapter.nodes.description_txt)], task.desc)
        lang.set(nodes[hash(adapter.nodes.action_button_txt)], task.action_button)
        gui.set_text(nodes[hash(adapter.nodes.value_txt)], "+" .. task.reward.quantity)

        -- Иконка (закомментирована в оригинале)
        -- pf(nodes[hash(adapter.nodes.icon)], task.reward.id.."_mini_icon")

        -- Проверяем, была ли кнопка нажата ранее
        local button_was_clicked = task.has_clicked or tasks.button_clicked[task.id] or false

        if tasks.is_completed(task.id) then
            -- Задача выполнена - показываем галочку, скрываем кнопку
            enable(nodes[hash(adapter.nodes.check_icon)])
            disable(nodes[hash(adapter.nodes.action_button)])
        else
            -- Задача активна - скрываем галочку, показываем кнопку
            disable(nodes[hash(adapter.nodes.check_icon)])
            enable(nodes[hash(adapter.nodes.action_button)])

            local action_button_node = nodes[hash(adapter.nodes.action_button)]

            -- Восстанавливаем состояние кнопки
            print("Task:", task.id, "button_was_clicked:", button_was_clicked)
            if button_was_clicked then
                print("Setting button to check state for task:", task.id)
                -- Состояние "Проверить"
                gui.play_flipbook(action_button_node, adapter.button_states.secondary)
                lang.set(nodes[hash(adapter.nodes.action_button_txt)], adapter.lang_keys.action_check)
            else
                print("Setting button to open state for task:", task.id)
                -- Состояние "Открыть"
                gui.play_flipbook(action_button_node, adapter.button_states.primary)
                lang.set(nodes[hash(adapter.nodes.action_button_txt)], task.action_button)
            end

            -- проверяем подписку
            if task.auto_check then
                tasks.add_pool_check(task.id)
            end
        end

        -- Создаём данные кнопки для buttons модуля
        local btn = {
            node = nodes[hash(adapter.nodes.action_button)],
            button_text_node = nodes[hash(adapter.nodes.action_button_txt)],
            check_icon_node = nodes[hash(adapter.nodes.check_icon)],
            task_id = task.id,
            task_link = task.link,
            link_type = task.link_type,
            auto_check = task.auto_check,
            invite = task.invite,
            channels = task.channels,
            action_button_text = task.action_button,
            reward_check_url = task.reward_check_url, -- URL для проверки TMABoost тасков
        }

        -- Регистрируем обработчик кнопки
        buttons.add(btn, function(self, node, action)
            -- Проверяем текущее состояние кнопки
            local is_check_state = tasks.is_check_state(node.node, adapter)

            if is_check_state then
                -- Кнопка уже в состоянии "Проверить" - отправляем запрос
                print("tasks: Button in check state, sending verification for:", node.task_id)

                -- Сохраняем ссылку на кнопку
                tasks.active_buttons[node.task_id] = {
                    button_node = node.node,
                    text_node = node.button_text_node,
                    check_icon_node = node.check_icon_node,
                    action_button_text = node.action_button_text,
                    adapter = adapter,
                    reward_check_url = node.reward_check_url, -- URL для проверки TMABoost тасков
                }

                if not node.auto_check then
                    tasks.send_data(node.task_id, node.task_id, node.reward_check_url)
                else
                    tasks.add_pool_check(node.task_id)
                    tasks.check_to_complete()
                end
            else
                -- Кнопка в состоянии "Открыть" - открываем ссылку
                local link_to_open = nil

                -- Если есть прямая ссылка
                if node.task_link and node.task_link ~= false then
                    link_to_open = node.task_link
                    -- Если есть channels, выбираем по языку
                elseif node.channels then
                    local current_lang = lang.language or "en"
                    local channel = node.channels[current_lang]

                    if not channel and current_lang ~= "en" then
                        channel = node.channels["en"]
                    end

                    if channel and channel.url then
                        link_to_open = channel.url
                    end
                end

                -- Открываем ссылку
                -- На мобильных для t.me используем sys.open_url (нативный Telegram)
                -- Для всех остальных ссылок везде используем JS openExternal
                if link_to_open then
                    -- Проверяем, является ли это Telegram ссылкой
                    local is_telegram_link = string.find(link_to_open, "t%.me/") or string.find(link_to_open, "telegram%.me/") or string.find(link_to_open, "tmaboost%.com/")
                    
                    -- Проверяем платформу через JS
                    local is_mobile = false
                    if sys.get_sys_info().system_name == "HTML5" then
                        local platform_check = html5.run("(Telegram.WebApp.platform === 'ios' || Telegram.WebApp.platform === 'android') ? 'mobile' : 'desktop'")
                        is_mobile = (platform_check == "mobile")
                    end
                    
                    if is_telegram_link and is_mobile then
                        -- iOS/Android + t.me: используем нативный sys.open_url
                        print("tasks: Opening Telegram link (native sys.open_url):", link_to_open)
                        sys.open_url(link_to_open)
                    else
                        -- Desktop/Web или внешние ссылки: используем JS openExternal
                        print("tasks: Opening link (JS openExternal):", link_to_open)
                        js("openExternal", link_to_open)
                    end
                else
                    print("tasks: No task link or channel provided!")
                end

                -- Обработка invite через адаптер (специфично для игры)
                if node.invite and adapter.handle_invite then
                    adapter.handle_invite(self)
                end

                -- Меняем состояние кнопки на "Проверить" используя конфигурацию
                gui.play_flipbook(node.node, adapter.button_states.secondary)
                lang.set(node.button_text_node, adapter.lang_keys.action_check)

                -- Отмечаем нажатие
                tasks.button_clicked[node.task_id] = true

                -- Обновляем has_clicked в конфигах
                for i, task in ipairs(db.configs.tasks) do
                    if task.id == node.task_id then
                        task.has_clicked = true
                        break
                    end
                end
                for i, task in ipairs(db.configs.partners_tasks or {}) do
                    if task.id == node.task_id then
                        task.has_clicked = true
                        break
                    end
                end
            end
        end)
    end

    -- Получаем количество тасков
    local tasks_count = #(configs or {})
    local content_height = 0
    local created_nodes = {}

    if layout then
        -- Используем Druid Layout - создаём ноды и добавляем в layout
        for i, task in ipairs(configs or {}) do
            local nodes = gui.clone_tree(template_node)
            local root = nodes[hash(template_id)]
            gui.set_enabled(root, true)

            -- Заполняем данными через fill_task
            fill_task(nodes, task, i)

            -- Добавляем в layout
            layout:add(root)

            table.insert(created_nodes, root)
        end

        if tasks_count > 0 then
            content_height = tasks_count * element_height + (tasks_count - 1) * y_space
        end
    else
        -- Старый режим с y_position
        local adjusted_start_y = self.y_position - (element_height / 2)

        created_nodes, last_y_position = list.create(
            "all_tasks",
            parent_id,
            template_id,
            configs or {},
            fill_task,
            {
                start_y = adjusted_start_y,
                y_space = y_space
            }
        )

        if tasks_count > 0 then
            content_height = tasks_count * element_height + (tasks_count - 1) * y_space
        end

        -- обновляем позицию y только в старом режиме
        self.y_position = self.y_position - content_height
    end

    -- Проверить все таски на выполнение
    tasks.check_to_complete()

    -- Возвращаем информацию о созданном контенте
    return {
        nodes = created_nodes,
        content_height = content_height,
        tasks_count = tasks_count
    }
end

function tasks.is_completed(id)
if not db.tasks then
    db.tasks = {}
end
return db.tasks[id] == 1 or db.tasks[id] == true
end

function tasks.data_update(data)
db.tasks = data
end

-- Загрузить состояние всех задач при открытии экрана
function tasks.load_all_tasks_state()
local all_task_ids = {}

if db.configs and db.configs.tasks then
    for _, task in ipairs(db.configs.tasks) do
        if task.id then
            table.insert(all_task_ids, task.id)
        end
    end
end

if db.configs and db.configs.partners_tasks then
    for _, task in ipairs(db.configs.partners_tasks) do
        if task.id then
            table.insert(all_task_ids, task.id)
        end
    end
end

if #all_task_ids > 0 then
    local task_ids_string = table.concat(all_task_ids, ",")
    print("Loading tasks state for:", task_ids_string)
    tasks.send_data(task_ids_string)
end
end

function tasks.add_pool_check(task_id)
table.insert(tasks.send_data_pool, task_id)
end

function tasks.check_to_complete(self)
if #tasks.send_data_pool > 0 then
    tasks.send_data(table.concat(tasks.send_data_pool, ","))
end
tasks.send_data_pool = {}
end

function tasks.send_data(task_ids, current_task_id, reward_check_url)

-- Проверяем, не выполняется ли уже запрос
if tasks.request_in_progress then
    pprint("tasks.send_data: request already in progress, skipping")
    return
end

tasks.request_in_progress = true

-- Таймаут для запроса
local request_timeout = timer.delay(10.0, false, function()
    pprint("tasks.send_data: request timeout, recreating tasks")
    tasks.request_in_progress = false
    monarch.post("bonuses", "tasks_recreate")
end)

local req = request('tasks', {method = "check", tasks_ids = task_ids, reward_check_url = reward_check_url or ""}, function (jd)
    timer.cancel(request_timeout)
    tasks.request_in_progress = false

    print("=== TASKS SERVER RESPONSE ===")
    pprint(jd)
    print("=============================")

    -- Проверяем ошибки
    local response_data = jd.response or jd
    local has_errors = false
    local has_real_errors = false
    local error_messages = {}

    local errors = response_data.errors or jd.errors
    if errors then
        local error_count = 0
        if type(errors) == "table" then
            for k, v in pairs(errors) do
                error_count = error_count + 1
                local error_msg = tostring(v)
                table.insert(error_messages, error_msg)
                if not string.find(error_msg:lower(), "already completed") then
                    has_real_errors = true
                end
            end
        end

        if error_count > 0 then
            has_errors = true
            print("=== TASKS ERRORS ===")
            for i, error_msg in ipairs(error_messages) do
                print("Error " .. i .. ": " .. tostring(error_msg))
            end
            print("====================")
            if not has_real_errors then
                print("All errors are 'Task already completed' - treating as success")
                has_errors = false
            end
        end
    end

    local tasks_updated = false
    local tasks_data = response_data.tasks or jd.tasks
    local completed_task_ids = {}

    -- Обрабатываем выполненные задачи
    if tasks_data then
        local has_tasks = false
        for k, v in pairs(tasks_data) do
            has_tasks = true
            break
        end

        if has_tasks then
            tasks.data_update(tasks_data)
            tasks_updated = true
            print("Tasks updated:", tasks_data)

            -- Обновляем кнопки для выполненных задач
            for task_id, task_status in pairs(tasks_data) do
                if task_status == 1 or task_status == true then
                    completed_task_ids[task_id] = true
                    local button_info = tasks.active_buttons[task_id]
                    if button_info and button_info.button_node then
                        if button_info.check_icon_node then
                            enable(button_info.check_icon_node)
                        end
                        disable(button_info.button_node)
                        print("Task completed, showing check icon for:", task_id)
                    end

                    tasks.active_buttons[task_id] = nil
                    tasks.button_clicked[task_id] = false
                end
            end
        end
    end

    -- Если есть реальные ошибки, возвращаем кнопки
    if has_real_errors then
        print("=== RESETTING BUTTON STATES DUE TO REAL ERRORS ===")
        local task_ids_array = {}
        if type(task_ids) == "string" then
            for task_id in string.gmatch(task_ids, "([^,]+)") do
                table.insert(task_ids_array, task_id:match("^%s*(.-)%s*$"))
            end
        else
            task_ids_array = {task_ids}
        end

        for _, task_id in ipairs(task_ids_array) do
            if not completed_task_ids[task_id] then
                local button_info = tasks.active_buttons[task_id]
                if button_info and button_info.button_node and button_info.adapter then
                    -- Возвращаем кнопку в состояние "Открыть" через адаптер
                    gui.play_flipbook(button_info.button_node, button_info.adapter.button_states.primary)
                    lang.set(button_info.text_node, button_info.action_button_text)
                    print("Reset button to primary state for task:", task_id)
                end

                tasks.button_clicked[task_id] = false
                tasks.active_buttons[task_id] = nil

                -- Сбрасываем has_clicked
                for i, task in ipairs(db.configs.tasks or {}) do
                    if task.id == task_id then
                        task.has_clicked = false
                        break
                    end
                end
                for i, task in ipairs(db.configs.partners_tasks or {}) do
                    if task.id == task_id then
                        task.has_clicked = false
                        break
                    end
                end
            end
        end
        print("=============================================")
    end

    -- Обработка наград через адаптер (специфично для игры)
    local rewards_data = response_data.rewards or jd.rewards
    local has_rewards = false
    if tasks.adapter and tasks.adapter.process_rewards then
        has_rewards = tasks.adapter.process_rewards(rewards_data)
    end

    -- Обновляем UI если нужно
    if tasks_updated or has_rewards then
        print("Recreating tasks UI - tasks_updated:", tasks_updated, "has_rewards:", has_rewards)
        monarch.post("bonuses", "tasks_recreate")
    end
end, function(error_data)
    timer.cancel(request_timeout)
    tasks.request_in_progress = false
    pprint("tasks.send_data: request error", error_data)
    monarch.post("bonuses", "tasks_recreate")
end, false)
end

function tasks.final()
	-- Очистка при закрытии экрана
	tasks.send_data_pool = {}
	tasks.request_in_progress = false
	tasks.button_clicked = {}
	tasks.active_buttons = {}
end

return tasks
