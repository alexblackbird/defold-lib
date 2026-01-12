# Стандарты Модулей

Для обеспечения совместимости и повторного использования в различных проектах (`tondiggers`, `memesrace`, `cryptodwarves` и др.), все общие модули в `defold-lib` должны соответствовать следующим стандартам.

## Паттерн `init`

Общие модули не должны напрямую зависеть от глобальных переменных (таких как `db`, `sys_info`, `lang`, `request`). Вместо этого они должны экспортировать функцию `init` для получения зависимостей и конфигурации.

### Шаблон

```lua
local M = {}

-- Внутреннее хранилище конфигурации
local config = {
    request = nil,      -- функция сетевых запросов
    lang_module = nil,  -- модуль локализации
    on_success = nil,   -- коллбек для успешных событий
    base_url = "https://api.default.com"
}

-- Инициализация модуля с переопределениями для конкретного проекта
function M.init(params)
    params = params or {}
    
    -- Переопределение значений по умолчанию, если они предоставлены
    if params.request then config.request = params.request end
    if params.lang_module then config.lang_module = params.lang_module end
    if params.on_success then config.on_success = params.on_success end
    if params.base_url then config.base_url = params.base_url end
    
    -- Опционально: Выполнение логики запуска
end

function M.do_something()
    -- Использование внедренных зависимостей
    if config.request then
        config.request("endpoint", {}, function(response)
             -- ...
        end)
    else
        print("Error: request function not configured")
    end
end

return M
```

### Использование в проекте

В вашем `loader.script` (или точке входа):

```lua
local my_module = require "modules.my_module"

function init(self)
    -- ... другие инициализации ...
    
    my_module.init({
        request = request,            -- Передаем глобальную функцию request
        lang_module = lang,           -- Передаем загруженный модуль lang
        base_url = PROD_SERVER_PATCH, -- Передаем константу проекта
        on_success = function(data)   -- Передаем бизнес-логику проекта
            db.user_data = data
            propellerads.onEvent()
        end
    })
end
```

## Лучшие практики

1.  **Нет глобальным переменным**: Избегайте прямого доступа к `db`, `sys_info`, `hash`, `gui` (если это чистая логика), если это не стандартные API Defold. Глобальные переменные проекта должны быть внедрены через `init`.
2.  **Настраиваемые коллбеки**: Используйте коллбеки для бизнес-логики (например, обновление баланса пользователя, трекинг аналитики) вместо того, чтобы хардкодить их внутри модуля.
3.  **Кросс-проектная совместимость**: Если модуль ведет себя по-разному в двух проектах, вынесите различие в параметр конфигурации или коллбек.
