---
--- loot_module - универсальный модуль анимации лута
---
--- Использование:
---
--- 1. Инициализация (loader.script):
---    В секцию с импортом
---    loot_module = require "lib.modules.loot_module"
--- 
---    В секцию с инициализацией
---    loot_module.init({
---        center_offset = {x = 0, y = -420},
---        default_place = "coins_panel",
---        items = {
---            coins = {
---                place = "coins_panel",
---                icon = "loot_coins",
---                sound = "loot_coins",
---                counting = true,
---                is_spine = true,
---                spine_scene = "coins"
---            }
---        }
---    })
--- 2. Добавить в menu (или где будет начисляться лут - есть панели куда лут может улетать)
--- 
--- 3. Регистрация handler в menu.gui_script или где будет начисляться лут:
---    loot_module.set_handler(function(data)
---        loot_module.create(self, data)
---    end)
---
--- 4. Вызов:
---    loot_module.drop({type = "coins", count = 100})
---    loot_module.drop({type = "coins", count = 100, x = 500, y = 800})
---
--- 5. Авторегистрация любого спрайта:
---    loot_module.drop({type = "energy", count = 50})  -- найдёт спрайт "energy"
---

local M = {}

-- ============================================================
-- DEFAULTS: все настройки по умолчанию (переопределяются через init)
-- ============================================================

M.DEFAULTS = {
    -- Количество элементов лута
    default_volume = 14,
    
    -- Смещение от центра экрана
    center_offset = {x = 0, y = 0},
    
    -- Панель по умолчанию для незарегистрированных типов
    default_place = nil,  -- устанавливается при init, например "coins_panel"
    
    -- Настройки звука
    sound_gain = 0.6,
    sound_path = "loader:/sound#sound_gate",
    sound_prefix = "loader:/sound#",
    
    -- Настройки партиклов
    particle_name = "loot_trail",
    
    -- Настройки слоя
    layer_name = "front",
    
    -- Тайминги анимации появления
    timings = {
        spawn_delay_step = 0.03,       -- задержка между появлением каждого элемента
        spawn_time_base = 0.5,         -- базовое время анимации появления
        spawn_time_random = 0.1,       -- случайное отклонение времени появления
        spawn_easing = "OUTBACK",      -- easing появления
        
        particle_delay_step = 0.05,    -- задержка между запуском партиклов
        
        fade_in_time = 0.1,            -- время появления (fade in)
        
        fly_delay = 0.9,               -- задержка перед полётом к цели
        fly_time_base = 0.7,           -- базовое время полёта
        fly_time_random = 0.1,         -- случайное отклонение времени полёта
        fly_delay_step = 0.03,         -- задержка между полётом каждого элемента
        fly_scale = 0.3,               -- финальный размер при полёте
        
        target_pulse_time = 0.6,       -- время пульсации цели
        target_pulse_scale = 0.9,      -- масштаб пульсации
        
        counter_step_delay = 0.05,     -- задержка между шагами счётчика
        counter_steps = 10,            -- количество шагов анимации счётчика
        
        text_scale_up = 2,             -- масштаб текста "+count" при появлении
        text_scale_time = 0.5,         -- время анимации текста
        text_hide_delay = 0.4          -- задержка перед скрытием текста
    },
    
    -- Настройки положения
    spawn_spread = {x = 150, y_min = -100, y_max = 100, y_offset = 50},
    fly_spread_x = 20,
    text_offset_x = 100,
    
    -- Настройки масштаба
    scale_initial = 0.1,
    scale_base = 1.1,
    scale_random = 0.05,
    spine_scale = 1,
    spine_playback_rate = 0.7
}

-- Внутреннее состояние модуля
M._config = {}
M._initialized = false
M._handler = nil
M.in_process = false

-- Зарегистрированные типы (для удобного доступа: loot_module.types.coins)
M.types = {}

-- ============================================================
-- UTILS
-- ============================================================

--- Глубокое копирование таблицы
local function deep_copy(orig)
    local copy
    if type(orig) == 'table' then
        copy = {}
        for k, v in pairs(orig) do
            copy[k] = deep_copy(v)
        end
    else
        copy = orig
    end
    return copy
end

--- Слияние таблиц (override накладывается на base)
local function merge_tables(base, override)
    if not override then return base end
    local result = deep_copy(base)
    for k, v in pairs(override) do
        if type(v) == 'table' and type(result[k]) == 'table' then
            result[k] = merge_tables(result[k], v)
        else
            result[k] = v
        end
    end
    return result
end

--- Получить размеры экрана из game.project
local function get_screen_size()
    local width = tonumber(sys.get_config("display.width", "1080"))
    local height = tonumber(sys.get_config("display.height", "1920"))
    return {width = width, height = height}
end

--- Получить easing по строке
local function get_easing(name)
    local easings = {
        OUTBACK = gui.EASING_OUTBACK,
        INBACK = gui.EASING_INBACK,
        INQUAD = gui.EASING_INQUAD,
        OUTQUAD = gui.EASING_OUTQUAD,
        LINEAR = gui.EASING_LINEAR,
        OUTSINE = gui.EASING_OUTSINE,
        INSINE = gui.EASING_INSINE,
        INOUTQUAD = gui.EASING_INOUTQUAD
    }
    return easings[name] or gui.EASING_OUTBACK
end

-- ============================================================
-- PUBLIC API
-- ============================================================

--- Инициализация модуля с конфигурацией
--- @param config table конфигурация модуля (опциональная)
function M.init(config)
    config = config or {}
    
    -- Начинаем с копии дефолтов
    M._config = deep_copy(M.DEFAULTS)
    
    -- Автоматически получаем размеры экрана
    M._config.screen = config.screen or get_screen_size()
    
    -- Переопределяем базовые настройки
    if config.center_offset then
        M._config.center_offset = merge_tables(M._config.center_offset, config.center_offset)
    end
    
    if config.default_volume then
        M._config.default_volume = config.default_volume
    end
    
    -- Переопределяем тайминги
    if config.timings then
        M._config.timings = merge_tables(M._config.timings, config.timings)
    end
    
    -- Переопределяем настройки звука
    if config.sound_gain then M._config.sound_gain = config.sound_gain end
    if config.sound_path then M._config.sound_path = config.sound_path end
    if config.sound_prefix then M._config.sound_prefix = config.sound_prefix end
    
    -- Переопределяем настройки партиклов
    if config.particle_name then M._config.particle_name = config.particle_name end
    
    -- Переопределяем настройки слоя
    if config.layer_name then M._config.layer_name = config.layer_name end
    
    -- Переопределяем default_place (для авторегистрации незарегистрированных типов)
    if config.default_place then M._config.default_place = config.default_place end
    
    -- Переопределяем spawn_spread
    if config.spawn_spread then
        M._config.spawn_spread = merge_tables(M._config.spawn_spread, config.spawn_spread)
    end
    
    -- Переопределяем остальные настройки
    if config.fly_spread_x then M._config.fly_spread_x = config.fly_spread_x end
    if config.text_offset_x then M._config.text_offset_x = config.text_offset_x end
    if config.scale_initial then M._config.scale_initial = config.scale_initial end
    if config.scale_base then M._config.scale_base = config.scale_base end
    if config.scale_random then M._config.scale_random = config.scale_random end
    if config.spine_scale then M._config.spine_scale = config.spine_scale end
    if config.spine_playback_rate then M._config.spine_playback_rate = config.spine_playback_rate end
    
    -- Регистрируем типы предметов
    M._config.items = {}
    if config.items then
        for name, item_config in pairs(config.items) do
            M.register(name, item_config)
        end
    end
    
    M._initialized = true
    print("[loot_module] Initialized with", M._count_items(), "item types")
end

--- Регистрация нового типа предмета
function M.register(name, config)
    assert(name, "loot_module.register: name is required")
    assert(config.place, "loot_module.register: place is required for " .. name)
    
    M._config.items[name] = {
        place = config.place,
        texture = config.texture or "ui",
        icon = config.icon or name,  -- по умолчанию спрайт = имя типа
        sound = config.sound,
        counting = config.counting or false,
        is_spine = config.is_spine or false,
        spine_scene = config.spine_scene,
        spine_anim = config.spine_anim or "animation",
        particlefx = config.particlefx,
        counter_node = config.counter_node
    }
    
    -- Добавляем в types для удобного доступа: loot_module.types.coins
    M.types[name] = name
    
    print("[loot_module] Registered item type:", name)
end

--- Установить handler для создания лута в GUI
function M.set_handler(handler)
    assert(type(handler) == "function", "loot_module.set_handler: handler must be a function")
    M._handler = handler
    print("[loot_module] Handler registered")
end

--- Убрать handler
function M.clear_handler()
    M._handler = nil
end

--- Автоматическая регистрация незарегистрированного типа
--- Создаёт конфигурацию по умолчанию: спрайт = имя типа, без звука, без счётчика
--- @param name string имя типа (будет использовано как имя спрайта)
--- @param options table опции (можно передать place, texture и т.д.)
function M._auto_register(name, options)
    options = options or {}
    
    -- Создаём минимальную конфигурацию
    local auto_config = {
        place = options.place or M._config.default_place, -- fallback place
        texture = options.texture or "ui",
        icon = name,  -- спрайт = имя типа
        sound = nil,
        counting = false,
        is_spine = false
    }
    
    M._config.items[name] = auto_config
    M.types[name] = name
    
    print("[loot_module] Auto-registered item type:", name, "(sprite:", name .. ")")
end

--- Запустить анимацию лута
--- Принимает объект: {type = "coins", count = 100, x = 540, y = 540, volume = 14}
--- @param params table параметры лута {type, count, x?, y?, volume?, not_particlefx?}
function M.drop(params)
    assert(M._initialized, "loot_module: call init() first")
    assert(params and params.type, "loot_module.drop: params.type is required")
    assert(params.count, "loot_module.drop: params.count is required")
    
    local item_type = params.type
    local count = params.count
    
    -- Автоматическая регистрация незарегистрированного типа
    if not M._config.items[item_type] then
        M._auto_register(item_type, params)
    end
    
    local center_x = M._config.screen.width / 2 + M._config.center_offset.x
    local center_y = M._config.screen.height / 2 + M._config.center_offset.y
    
    local drop_params = {
        type = item_type,
        count = count,
        x = params.x or center_x,
        y = params.y or center_y,
        volume = params.volume or M._config.default_volume,
        not_particlefx = params.not_particlefx
    }
    
    -- Обновляем ресурс в базе
    if db and db[item_type] ~= nil then
        db[item_type] = db[item_type] + count
    end
    
    -- Analytics
    if amplitude and amplitude.track then
        amplitude.track("earn", {type = item_type, value = count})
    end
    
    -- Вызываем handler
    if M._handler then
        M._handler(drop_params)
    elseif monarch and monarch.post then
        monarch.post('menu', 'loot_module', drop_params)
    else
        print("[loot_module] WARNING: no handler registered and monarch not available")
    end
end

--- Создать анимацию лута (вызывается из gui_script)
function M.create(self, data)
    M.in_process = true
    
    local cfg = M._config
    local t = cfg.timings
    local item_config = cfg.items[data.type]
    
    if not item_config then
        print("[loot_module] ERROR: unknown item type:", data.type)
        return
    end
    
    local pos = vmath.vector3(data.x, data.y, 0)
    local target_node = gui.get_node(item_config.place)
    local target_anchor = gui.get_xanchor(target_node)
    local nodes = {}
    local volume = data.volume or cfg.default_volume
    
    for i = 1, volume do
        local delay = i * t.spawn_delay_step
        local time = t.spawn_time_base + (math.random(-1, 1) * t.spawn_time_random)
        local node
        local randomscale
        
        if item_config.is_spine and item_config.spine_scene then
            node = gui.new_spine_node(pos, item_config.spine_scene)
            local play_properties = {offset = 0, playback_rate = cfg.spine_playback_rate}
            gui.play_spine_anim(node, item_config.spine_anim, gui.PLAYBACK_LOOP_FORWARD, play_properties)
            randomscale = vmath.vector3(cfg.spine_scale)
        else
            node = gui.new_box_node(pos, vmath.vector3(0))
            gui.set_texture(node, item_config.texture)
            gui.play_flipbook(node, item_config.icon)
            gui.set_size_mode(node, gui.SIZE_MODE_AUTO)
            randomscale = vmath.vector3(cfg.scale_base + math.random(-cfg.scale_random, cfg.scale_random))
        end
        
        local spread = cfg.spawn_spread
        local target_pos = vmath.vector3(
            pos.x + math.random(-spread.x, spread.x),
            pos.y + spread.y_offset + math.random(spread.y_min, spread.y_max),
            0
        )
        
        gui.set_scale(node, vmath.vector3(cfg.scale_initial))
        gui.animate(node, "scale", randomscale, get_easing(t.spawn_easing), time, delay)
        gui.animate(node, "position", target_pos, get_easing(t.spawn_easing), time, delay)
        gui.set_color(node, vmath.vector4(1, 1, 1, 0))
        gui.animate(node, "color.w", 1, gui.EASING_LINEAR, t.fade_in_time, delay)
        table.insert(nodes, node)
        gui.set_layer(node, cfg.layer_name)
        
        local particle = gui.new_particlefx_node(vmath.vector3(0), cfg.particle_name)
        gui.set_parent(particle, node, 0)
        timer.delay(i * t.particle_delay_step, false, function()
            gui.play_particlefx(particle)
            if taptic and taptic.run then
                taptic.run(taptic.IMPACT_LIGHT)
            end
        end)
        
        gui.set_xanchor(node, target_anchor)
    end
    
    -- Текст "+count"
    if gui_new_text_node then
        local text_node = gui_new_text_node(vmath.vector3(pos.x + cfg.text_offset_x, pos.y, pos.z), "+" .. data.count, {
            scale = 0,
            layer = 'text',
            outline = vmath.vector4(0, 0, 0, 1)
        })
        
        gui.animate(text_node, "scale", vmath.vector3(t.text_scale_up), gui.EASING_OUTQUAD, t.text_scale_time, 0, function()
            gui.animate(text_node, "scale", vmath.vector3(0), gui.EASING_INBACK, t.text_scale_time, t.text_hide_delay, function()
                gui.delete_node(text_node)
            end)
        end)
    end
    
    -- Звук
    if item_config.sound then
        msg.post(cfg.sound_path, "play_gated_sound", {
            soundcomponent = cfg.sound_prefix .. item_config.sound,
            gain = cfg.sound_gain
        })
    end
    
    timer.delay(t.fly_delay, false, function()
        M._fly_loot(self, nodes, data, item_config)
    end)
end

--- Анимация полёта к цели
function M._fly_loot(self, nodes, data, item_config)
    local cfg = M._config
    local t = cfg.timings
    local target_node = gui.get_node(item_config.place)
    local target_position = gui.get_screen_position(target_node)
    
    if rendercam and rendercam.screen_to_gui then
        target_position.x, target_position.y = rendercam.screen_to_gui(target_position.x, target_position.y, gui.ADJUST_FIT)
    end
    
    for i, node in ipairs(nodes) do
        local delay = i * t.fly_delay_step
        local time = t.fly_time_base + (math.random(-1, 1) * t.fly_time_random)
        
        gui.animate(node, "position.y", target_position.y, gui.EASING_INQUAD, time, delay, function()
            gui.delete_node(node)
            if taptic and taptic.run then
                taptic.run(taptic.IMPACT_LIGHT)
            end
        end)
        gui.animate(node, "position.x", target_position.x + math.random(-cfg.fly_spread_x, cfg.fly_spread_x), gui.EASING_OUTQUAD, time, delay)
        timer.delay(delay, false, function()
            gui.animate(node, "scale", vmath.vector3(t.fly_scale), gui.EASING_OUTQUAD, time, 0, nil)
        end)
    end
    
    timer.delay(t.fly_time_base, false, function()
        -- Анимация счётчика
        if item_config.counting and db then
            local counter_node = item_config.counter_node or (data.type .. "_count_txt")
            M._animate_counter(counter_node, data.type, data.count)
        end
        
        -- Партиклы
        if item_config.particlefx and not data.not_particlefx then
            gui.play_particlefx(gui.get_node(item_config.particlefx))
        end
        
        -- Пульсация цели
        gui.set_scale(target_node, vmath.vector3(1))
        gui.animate(target_node, "scale", vmath.vector3(t.target_pulse_scale), gui.EASING_OUTQUAD, t.target_pulse_time, 0, nil, gui.PLAYBACK_ONCE_PINGPONG)
        
        M.in_process = false
    end)
end

--- Анимация счётчика ресурсов
function M._animate_counter(node_name, item_type, value)
    local t = M._config.timings
    local old_value = db[item_type] - value
    local step = value / t.counter_steps
    local update_timer = nil
    
    update_timer = timer.delay(t.counter_step_delay, true, function()
        old_value = old_value + step
        gui.set_text(gui.get_node(node_name), M.format_number(math.floor(old_value)))
        
        if db[item_type] == old_value or db[item_type] < old_value + step then
            gui.set_text(gui.get_node(node_name), M.format_number(db[item_type]))
            timer.cancel(update_timer)
        end
    end)
end

--- Форматирование числа с разделителями тысяч
function M.format_number(number)
    local i, j, minus, int, fraction = tostring(number):find('([-]?)(%d+)([.]?%d*)')
    int = int:reverse()
    int = int:gsub("(%d%d%d)", "%1 ")
    int = int:reverse()
    int = int:gsub("^ ", "")
    return minus .. int .. fraction
end

--- Подсчёт зарегистрированных типов
function M._count_items()
    local count = 0
    for _ in pairs(M._config.items) do
        count = count + 1
    end
    return count
end

return M
