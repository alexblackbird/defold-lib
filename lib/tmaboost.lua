local tmaboost = {}

-- Хранилище задач
tmaboost.tasks = {}

-- Функция для получения задач пользователя
function tmaboost.get_tasks(telegram_id, language, callback)
    if not network.is_connected() then
        print("tmaboost: No network connection")
        if callback then callback(nil) end
        return
    end

    local url = sys.get_config("tmaboost.api_base_url") .. "/tasks?telegram_id=" .. tostring(telegram_id) .. "&language=" .. (language or "ru")

    print("tmaboost: Making request to:", url)

    local headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = "Bearer " .. sys.get_config("tmaboost.api_key")
    }

    http.request(url, "GET", function(self, id, response)
        print("tmaboost: Response body:", response.response)

        if response.status == 200 then
            local success, data = pcall(json.decode, response.response)
            if success then
                -- Сохраняем задачи в tmaboost.tasks
                if data and data.data then
                    tmaboost.tasks = data.data
                    print("tmaboost: Saved", #data.data, "tasks to tmaboost.tasks")
                elseif data and data.tasks then
                    tmaboost.tasks = data.tasks
                    print("tmaboost: Saved", #data.tasks, "tasks to tmaboost.tasks")
                elseif data then
                    tmaboost.tasks = data
                    print("tmaboost: Saved data to tmaboost.tasks")
                end

                if callback then callback(data) end
            else
                print("tmaboost: Failed to parse JSON:", data)
                if callback then callback(nil) end
            end
        else
            print("tmaboost: HTTP error:", response.status)
            if callback then callback(nil) end
        end
    end, headers)
end

-- Функция для получения задач текущего пользователя
function tmaboost.get_user_tasks(callback)
    if not telegram or not telegram.user then
        print("tmaboost: Telegram user not available")
        if callback then callback(nil) end
        return
    end

    local telegram_id = telegram.user.id
    local language = lang.language or "ru"

    print("tmaboost: Getting tasks for user:", telegram_id, "language:", language)

    tmaboost.get_tasks(telegram_id, language, callback)
end

-- Функция для преобразования tmaboost задач в формат внутренних задач
function tmaboost.convert_to_internal_tasks()
    if not tmaboost.tasks or #tmaboost.tasks == 0 then
        print("tmaboost: No tasks to convert")
        return
    end

    local converted_tasks = {}

    -- Создаем функцию для создания задачи
    local function create_task(task, index)
        local final_link = task.app_url or task.url or task.link or ""

        -- Используем переданную конфигурацию (без fallback значений)
        if not tmaboost.config.reward then
            print("tmaboost: ERROR - config.reward is missing!")
        end
        if not tmaboost.config.description then
            print("tmaboost: ERROR - config.description is missing!")
        end

        local reward = tmaboost.config.reward
        local description = tmaboost.config.description

        return {
            id = "tmaboost_" .. (task.id or index),
            reward = reward,
            link = final_link,
            link_type = "internal",
            auto_check = false,
            type = "manual",
            header = task.title or task.app_name or task.name or "TmaBoost Task",
            desc = description,
            action_button = "ACTION_OPEN",
            has_clicked = task.has_clicked or false, -- Сохраняем состояние нажатия из API
            reward_check_url = task.reward_check_url or "" -- Сохраняем URL для проверки награды
        }
    end

    -- Затем остальные задачи (кроме 1 и 3)
    for i, task in ipairs(tmaboost.tasks) do
        table.insert(converted_tasks, create_task(task, i))
    end

    -- Модифицируем db.configs.partners_tasks
    if not db.configs then
        db.configs = {}
    end
    if not db.configs.partners_tasks then
        db.configs.partners_tasks = {}
    end

    -- Добавляем tmaboost задачи в начало существующих задач
    for i = #converted_tasks, 1, -1 do
        table.insert(db.configs.partners_tasks, 1, converted_tasks[i])
    end

    print("tmaboost: Added", #converted_tasks, "tasks to db.configs.partners_tasks")
    print("tmaboost: Total tasks in db.configs.partners_tasks:", #db.configs.partners_tasks)
    print("tmaboost: Final db.configs.partners_tasks content:")
    pprint(db.configs.partners_tasks)
end

-- Функция для проверки выполнения задачи
function tmaboost.check_task_completion(task_id, callback)
    if not network.is_connected() then
        print("tmaboost: No network connection for task check")
        if callback then callback(false) end
        return
    end

    -- Ищем задачу в db.configs.tasks чтобы получить reward_check_url
    local reward_check_url = nil
    for _, task in ipairs(db.configs.partners_tasks or {}) do
        if task.id == task_id then
            reward_check_url = task.reward_check_url
            break
        end
    end

    if not reward_check_url or reward_check_url == "" then
        print("tmaboost: No reward_check_url found for task:", task_id)
        if callback then callback(false) end
        return
    end

    print("tmaboost: Checking task completion using reward_check_url:", reward_check_url)

    local headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = "Bearer " .. API_KEY
    }

    http.request(reward_check_url, "GET", function(self, id, response)
        print("tmaboost: Task check response received")
        print("tmaboost: Status:", response.status)
        print("tmaboost: Response body:", response.response)

        if response.status == 200 then
            local success, data = pcall(json.decode, response.response)
            if success and data then
                if data.completed or data.status == "completed" or data.status == "reward_already_given" or data.status == "installed_reward_available" or data.reward_available then
                    print("tmaboost: Task completed successfully:", task_id)
                    -- Помечаем задачу как выполненную в локальной базе
                    if not db.partners_tasks then
                        db.partners_tasks = {}
                    end
                    db.partners_tasks[task_id] = 1

                    if callback then callback(true) end
                else
                    print("tmaboost: Task not completed yet:", task_id)
                    if callback then callback(false) end
                end
            else
                print("tmaboost: Failed to parse task check response")
                if callback then callback(false) end
            end
        else
            print("tmaboost: Task check HTTP error:", response.status)
            if callback then callback(false) end
        end
    end, headers)
end

-- Альтернативная функция для проверки выполнения задачи через обновление списка задач
function tmaboost.check_task_completion_via_refresh(task_id, callback)
    if not network.is_connected() then
        print("tmaboost: No network connection for task check")
        if callback then callback(false) end
        return
    end

    -- Извлекаем оригинальный ID задачи из tmaboost_ префикса
    local original_task_id = string.gsub(task_id, "tmaboost_", "")

    if not telegram or not telegram.user then
        print("tmaboost: Telegram user not available for task check")
        if callback then callback(false) end
        return
    end

    local telegram_id = telegram.user.id
    local language = lang.language or "ru"

    print("tmaboost: Checking task completion via refresh for:", original_task_id)

    -- Получаем обновленный список задач
    tmaboost.get_tasks(telegram_id, language, function(data)
        if data and tmaboost.tasks then
            -- Ищем нашу задачу в обновленном списке
            for _, task in ipairs(tmaboost.tasks) do
                if tostring(task.id) == original_task_id then
                    -- Проверяем, изменился ли статус задачи
                    if task.completed or task.status == "completed" or task.is_completed then
                        print("tmaboost: Task completed via refresh:", original_task_id)
                        -- Помечаем задачу как выполненную в локальной базе
                        if not db.partners_tasks then
                            db.partners_tasks = {}
                        end
                        db.partners_tasks[task_id] = 1

                        if callback then callback(true) end
                        return
                    else
                        print("tmaboost: Task not completed yet via refresh:", original_task_id)
                        if callback then callback(false) end
                        return
                    end
                end
            end
            print("tmaboost: Task not found in refreshed list:", original_task_id)
            if callback then callback(false) end
        else
            print("tmaboost: Failed to refresh tasks for completion check")
            if callback then callback(false) end
        end
    end)
end

-- Функция для обновления состояния has_clicked в существующих задачах
function tmaboost.update_has_clicked_state()
    if not tmaboost.tasks or #tmaboost.tasks == 0 then
        print("tmaboost: No tasks to update")
        return
    end

    if not db.configs or not db.configs.partners_tasks then
        print("tmaboost: No db.configs.partners_tasks to update")
        return
    end

    -- Обновляем состояние has_clicked в существующих задачах
    for _, tmaboost_task in ipairs(tmaboost.tasks) do
        local task_id = "tmaboost_" .. tmaboost_task.id
        for _, internal_task in ipairs(db.configs.partners_tasks) do
            if internal_task.id == task_id then
                internal_task.has_clicked = tmaboost_task.has_clicked or false
                print("tmaboost: Updated has_clicked for task", task_id, "to", internal_task.has_clicked)
                break
            end
        end
    end
end

-- Функция для инициализации tmaboost (вызывается при загрузке)
function tmaboost.init(config)
    -- Сохраняем конфигурацию
    tmaboost.config = config or {}

    -- Получаем задачи пользователя при инициализации
    tmaboost.get_user_tasks(function(data)
        if data then
            -- Конвертируем задачи в формат внутренних задач
            tmaboost.convert_to_internal_tasks()

            -- Обновляем состояние has_clicked в существующих задачах
            tmaboost.update_has_clicked_state()
        else
            print("tmaboost: Failed to get tasks")
        end
    end)
end

return tmaboost
