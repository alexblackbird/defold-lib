--[[
    УНИВЕРСАЛЬНЫЙ МОДУЛЬ TELEGRAM STARS ПОКУПОК
    
    init({
        request = request,                -- функция запроса к серверу (обязательно)
        analytics = amplitude или mixpanel или nil,   -- модуль аналитики (опционально)
        loot_module = loot_module или nil, -- модуль лута для показа монет (опционально)
        offers_module = offers или nil,   -- модуль офферов для cryptodwarves (опционально)
        loader_url = "loader:/loader",    -- url для показа/скрытия лоадера
        star_to_usd = 0.013,              -- курс звезд к доллару
        on_success = function(type, data) end,  -- кастомный обработчик успеха
        on_error = function(type, reason) end,  -- кастомный обработчик ошибки
        get_offer_data = function(offer_id) end, -- функция для получения данных оффера
        apply_offer_results = function(offer_id, offer_data) end, -- применение результатов оффера
    })
]]

local M = {}

-- ВНУТРЕННЕЕ СОСТОЯНИЕ

local config = {
    request = nil,
    analytics = nil,
    loot_module = nil,
    offers_module = nil,
    loader_url = "loader:/loader",
    star_to_usd = 0.013,
    on_success = nil,
    on_error = nil,
    get_offer_data = nil,
    apply_offer_results = nil,
}

-- Типы продуктов
local PRODUCT_TYPES = {
    COINS = "coins",
    OFFER = "offer",
    EQUIPMENT = "equipment",
    BOOSTERS = "boosters",
    OFFERS = "offers",
    ENERGY = "energy"
}

M.PRODUCT_TYPES = PRODUCT_TYPES

-- Текущая покупка
local current_purchase = {
    type = nil,
    id = nil,
    data = nil,
    callback = nil,
    offer_id = nil,
    stable_count = nil,
    coins_count = nil,
    rate = nil
}

-- Таблица callback'ов для успешных покупок офферов
M.offer_success_callbacks = {}

-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ

local function hide_loader()
    msg.post(config.loader_url, "request_loader_hide")
end

local function show_loader()
    msg.post(config.loader_url, "request_loader_show")
end

local function show_coins_loot(coins_count)
    if config.loot_module and coins_count and coins_count > 0 then
        config.loot_module.drop({
            count = coins_count, type = "coins"
        })
    end
end

local function get_product_name(product_type, id_or_offer)
    if product_type == PRODUCT_TYPES.COINS then
        return tostring(id_or_offer or "coins_pack")
    else
        return tostring(id_or_offer or "offer")
    end
end

-- АНАЛИТИКА

local function track_event(event_name, event_data)
    if config.analytics and config.analytics.track then
        config.analytics.track(event_name, event_data)
    end
end

local function track_purchase_start(product_type, product_name, additional_data)
    local event_data = {
        product_type = product_type,
        product_name = product_name
    }
    if additional_data then
        for k, v in pairs(additional_data) do
            event_data[k] = v
        end
    end
    track_event("purchase_start", event_data)
end

local function track_purchase_success(product_type, product_name, additional_data)
    local event_data = {
        product_type = product_type,
        product_name = product_name
    }
    if additional_data then
        for k, v in pairs(additional_data) do
            event_data[k] = v
        end
    end
    track_event("purchase_success", event_data)
end

local function track_purchase_error(product_type, product_name, reason)
    track_event("purchase_error", {
        product_type = product_type,
        product_name = product_name,
        reason = reason
    })
end

-- ОБРАБОТКА ОФФЕРОВ

local function extract_offer_data(offer_id)
    -- Если передана кастомная функция - используем её
    if config.get_offer_data then
        return config.get_offer_data(offer_id)
    end
    
    -- Иначе пробуем использовать offers_module
    if config.offers_module and config.offers_module.get then
        local cfg = config.offers_module.get(offer_id)
        if not cfg or not cfg.options then
            return { coins = 0, vassals = 0, price_stars = 0, price_usd = 0 }
        end
        
        local coins_count = 0
        local vassals_count = 0
        
        for _, option in ipairs(cfg.options) do
            if option.type == "coins" then
                coins_count = coins_count + (tonumber(option.value) or 0)
            elseif option.type == "vassals" then
                vassals_count = vassals_count + (tonumber(option.value) or 0)
            end
        end
        
        local price_stars = tonumber(cfg.price) or 0
        local price_usd = price_stars * config.star_to_usd
        
        return {
            coins = coins_count,
            vassals = vassals_count,
            price_stars = price_stars,
            price_usd = price_usd
        }
    end
    
    return { coins = 0, vassals = 0, price_stars = 0, price_usd = 0 }
end

local function apply_purchase_results(offer_id, offer_data)
    if config.apply_offer_results then
        config.apply_offer_results(offer_id, offer_data)
        return
    end
    
    -- Дефолтная логика - показать монеты
    show_coins_loot(offer_data.coins)
end

-- ОБРАБОТЧИКИ СООБЩЕНИЙ ОТ JAVASCRIPT

local function handle_buy_success()
    hide_loader()
    
    local product_type = current_purchase.type or "unknown"
    local product_name = get_product_name(product_type, current_purchase.id or current_purchase.offer_id)
    
    pprint("tg_stars: purchase success", product_type, product_name)
    
    local analytics_data = {}
    
    if product_type == PRODUCT_TYPES.COINS then
        local stars = tonumber(current_purchase.stable_count) or 0
        local coins = tonumber(current_purchase.coins_count) or 0
        local rate = tonumber(current_purchase.rate) or 0
        local usd = stars * config.star_to_usd
        
        analytics_data = {
            stars = stars,
            coins = coins,
            rate = rate,
            revenue = usd,
            currency = "USD"
        }
        
        show_coins_loot(coins)
        
    elseif product_type == PRODUCT_TYPES.OFFER and current_purchase.offer_id then
        local offer_data = extract_offer_data(current_purchase.offer_id)
        analytics_data = {
            stars = offer_data.price_stars,
            revenue = offer_data.price_usd,
            currency = "USD",
            coins_included = offer_data.coins,
        }
        
        apply_purchase_results(current_purchase.offer_id, offer_data)
        
        -- Вызываем callback если он зарегистрирован
        local callback = M.offer_success_callbacks[current_purchase.offer_id]
        if callback then
            callback()
        end
    end
    
    track_purchase_success(product_type, product_name, analytics_data)
    
    -- Кастомный обработчик успеха
    if config.on_success then
        config.on_success(product_type, current_purchase.data or current_purchase)
    end
    
    -- Callback покупки
    if current_purchase.callback then
        current_purchase.callback()
    end
end

local function handle_buy_cancelled()
    hide_loader()
    local product_name = get_product_name(current_purchase.type, current_purchase.id or current_purchase.offer_id)
    track_purchase_error(current_purchase.type, product_name, "cancelled")
    if config.on_error then
        config.on_error(current_purchase.type, "cancelled")
    end
end

local function handle_buy_declined()
    hide_loader()
    local product_name = get_product_name(current_purchase.type, current_purchase.id or current_purchase.offer_id)
    track_purchase_error(current_purchase.type, product_name, "declined")
    if config.on_error then
        config.on_error(current_purchase.type, "declined")
    end
end

local function handle_buy_unknown()
    hide_loader()
    local product_name = get_product_name(current_purchase.type, current_purchase.id or current_purchase.offer_id)
    track_purchase_error(current_purchase.type, product_name, "unknown")
    if config.on_error then
        config.on_error(current_purchase.type, "unknown")
    end
end

local function js_listener(self, message_id, message)
    pprint("tg_stars js_listener", message_id, message)

    local handlers = {
        ["tgStarsBuySuccess"] = handle_buy_success,
        ["tgStarsBuyCancelled"] = handle_buy_cancelled,
        ["tgStarsBuyDeclined"] = handle_buy_declined,
        ["tgStarsBuyUnknown"] = handle_buy_unknown
    }
    
    local handler = handlers[message_id]
    if handler then
        handler()
    end
end

-- ПУБЛИЧНЫЙ API

function M.init(params)
    params = params or {}
    
    if params.request then config.request = params.request end
    if params.analytics then config.analytics = params.analytics end
    if params.loot_module then config.loot_module = params.loot_module end
    if params.offers_module then config.offers_module = params.offers_module end
    if params.loader_url then config.loader_url = params.loader_url end
    if params.star_to_usd then config.star_to_usd = params.star_to_usd end
    if params.on_success then config.on_success = params.on_success end
    if params.on_error then config.on_error = params.on_error end
    if params.get_offer_data then config.get_offer_data = params.get_offer_data end
    if params.apply_offer_results then config.apply_offer_results = params.apply_offer_results end
    if params.lang_module then config.lang_module = params.lang_module end
    
    -- Активируем jstodef listener
    if jstodef then
        jstodef.add_listener(js_listener)
    end
end

-- Функция для регистрации callback при успешной покупке оффера
function M.register_offer_callback(offer_id, callback)
    M.offer_success_callbacks[offer_id] = callback
end

-- Применение результатов покупки оффера (может вызываться извне)
function M.on_offer_purchased(offer_id, server_offers_map)
    local offer_data = extract_offer_data(offer_id)
    apply_purchase_results(offer_id, offer_data)
    
    local callback = M.offer_success_callbacks[offer_id]
    if callback then
        callback()
    end
end

-- Создать инвойс и обработать результат
local function create_invoice_and_buy(request_data, product_name)
    show_loader()
    
    if not config.request then
        pprint("Error: request function not configured in tg_stars")
        hide_loader()
        return
    end
    
    config.request("create-invoice", request_data, function(response)
        if response.invoiceLink then
            if html5 then
                html5.run("tgStarsBuy('"..response.invoiceLink.."')")
            else
                pprint("tg_stars: invoice link (not html5):", response.invoiceLink)
            end
        end
    end, function(error_response)
        hide_loader()
        pprint("tg_stars: create invoice error", error_response)
        track_purchase_error(request_data.type, product_name, "create_invoice_failed")
        if config.on_error then
            config.on_error(request_data.type, "create_invoice_failed")
        end
    end, false)
end

-- Покупка монет (совместимость с cryptodwarves API)
function M.buy(id, stable_count, coins_count, rate)
    current_purchase.type = PRODUCT_TYPES.COINS
    current_purchase.id = id
    current_purchase.stable_count = stable_count
    current_purchase.coins_count = coins_count
    current_purchase.rate = rate
    
    local product_name = get_product_name(PRODUCT_TYPES.COINS, id)
    local stars = tonumber(stable_count) or 0
    
    track_purchase_start(PRODUCT_TYPES.COINS, product_name, {
        stars = stars,
        coins = tonumber(coins_count) or 0,
        rate = tonumber(rate) or 0
    })
    
    create_invoice_and_buy({type = PRODUCT_TYPES.COINS, option_id = id}, product_name)
end

-- Покупка оффера (совместимость с cryptodwarves API)
function M.buy_offer(offer_id)
    current_purchase.type = PRODUCT_TYPES.OFFER
    current_purchase.offer_id = offer_id
    
    local offer_data = extract_offer_data(offer_id)
    
    track_purchase_start(PRODUCT_TYPES.OFFER, offer_id, {
        stars = offer_data.price_stars
    })
    
    create_invoice_and_buy({type = PRODUCT_TYPES.OFFER, offer_id = offer_id}, offer_id)
end

-- Универсальная покупка (совместимость с tondiggers/memesrace API)
function M.buy_product(type, indx, data, callback)
    current_purchase.type = type
    current_purchase.id = indx
    current_purchase.data = data
    current_purchase.callback = callback
    
    local lang_code = "en"
    if config.lang_module then lang_code = config.lang_module.language end
    
    track_purchase_start(type, tostring(indx), {})
    
    create_invoice_and_buy({type = type, indx = indx, language_code = lang_code}, tostring(indx))
end

return M