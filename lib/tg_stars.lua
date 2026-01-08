local tg_stars = {}
local offers = require "lib.offers"

-- КОНСТАНТЫ И КОНФИГУРАЦИЯ

local STAR_TO_USD = 0.013  -- 1 star = 0.013 USD

-- Типы продуктов
local PRODUCT_TYPES = {
    COINS = "coins",
    OFFER = "offer"
}

-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ

-- Показать визуальный эффект получения монет
local function show_coins_loot(coins_count)
    if coins_count and coins_count > 0 then
        loot_module.drop({
            count = coins_count, type = "coins"
        })
    end
end

-- Скрыть загрузчик
local function hide_loader()
    msg.post("loader:/loader", "request_loader_hide")
end

-- Показать загрузчик
local function show_loader()
    msg.post("loader:/loader", "request_loader_show")
end

-- Показать ошибку пользователю
local function show_error(message)
    hide_loader()
    popup.show("message", {}, {msg = message or "Unknown error"})
end

-- Получить название продукта для аналитики
local function get_product_name(product_type, id_or_offer)
    if product_type == PRODUCT_TYPES.COINS then
        return tostring(id_or_offer or "coins_pack")
    else
        return tostring(id_or_offer or "offer")
    end
end

-- АНАЛИТИКА

-- Отправить событие начала покупки
local function track_purchase_start(product_type, product_name, additional_data)
    local event_data = {
        product_type = product_type,
        product_name = product_name
    }
    
    -- Добавляем дополнительные данные
    if additional_data then
        for k, v in pairs(additional_data) do
            event_data[k] = v
        end
    end
    
    amplitude.track("purchase_start", event_data)
end

-- Отправить событие успешной покупки
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

    amplitude.track("purchase_success", event_data)
end

-- Отправить событие ошибки покупки
local function track_purchase_error(product_type, product_name, reason)
    amplitude.track("purchase_error", {
        product_type = product_type,
        product_name = product_name,
        reason = reason
    })
end

-- ОБРАБОТКА ОФФЕРОВ

-- Извлечь данные из конфигурации оффера
local function extract_offer_data(offer_id)
    local cfg = offers.get(offer_id)
    if not cfg or not cfg.options then
        return {
            coins = 0,
            vassals = 0,
            price_stars = 0,
            price_usd = 0
        }
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
    local price_usd = price_stars * STAR_TO_USD
    
    return {
        coins = coins_count,
        vassals = vassals_count,
        price_stars = price_stars,
        price_usd = price_usd
    }
end

-- Применить результаты покупки оффера
local function apply_purchase_results(offer_id, offer_data)
    -- Обновить состояние купленных офферов
    db.offers = db.offers or {}
    db.offers[offer_id] = 1
    
    -- Показать полученные монеты
    show_coins_loot(offer_data.coins)
    
    -- Добавить вассалов
    if offer_data.vassals > 0 then
        db.paid_vassals_count = (db.paid_vassals_count or 0) + offer_data.vassals
        monarch.post("menu", "account_updated", { 
            nickname = db.nickname, 
            avatar_id = db.avatar_id 
        })
    end
    
    -- Обновить интерфейс
    monarch.post("mines", "rebuild_banners", {})
    monarch.post("mines", "to_update_mines", {})
end

-- ОБРАБОТЧИКИ СООБЩЕНИЙ ОТ JAVASCRIPT

-- Обработать успешную покупку
local function handle_buy_success()
    hide_loader()  -- Скрываем лоадер после успешной покупки

    -- ВСЕГДА отправляем аналитику успешной покупки первым делом
    local product_type = tg_stars.current_type or "unknown"
    local product_name = get_product_name(product_type, tg_stars.id or tg_stars.current_offer_id)
    
    pprint("Product type:", product_type)
    pprint("Product name:", product_name)
    
    -- Базовые данные для аналитики
    local analytics_data = {}
    
    if product_type == PRODUCT_TYPES.COINS then
        local stars = tonumber(tg_stars.stable_count) or 0
        local coins = tonumber(tg_stars.coins_count) or 0
        local rate = tonumber(tg_stars.rate) or 0
        local usd = stars * STAR_TO_USD
        
        pprint("Coins purchase - stars:", stars, "coins:", coins, "rate:", rate)
        
        analytics_data = {
            stars = stars,
            coins = coins,
            rate = rate,
            revenue = usd,
            currency = "USD"
        }
        
        
    elseif product_type == PRODUCT_TYPES.OFFER and tg_stars.current_offer_id then
        pprint("Offer purchase:", tg_stars.current_offer_id)
        local offer_data = extract_offer_data(tg_stars.current_offer_id)
        analytics_data = {
            stars = offer_data.price_stars,
            revenue = offer_data.price_usd,
            currency = "USD",
            coins_included = offer_data.coins,
            vassals_included = offer_data.vassals
        }
    end
    
    -- Отправляем аналитику ВСЕГДА, независимо от условий
    pprint("Sending analytics...")
    track_purchase_success(product_type, product_name, analytics_data)
    pprint("Analytics sent")

    -- Теперь обрабатываем визуальную часть (с защитой от ошибок)
    local success, error_msg = pcall(function()
        if tg_stars.current_type == PRODUCT_TYPES.COINS and tg_stars.coins_count then
            pprint("Showing coins loot...")
            show_coins_loot(tg_stars.coins_count)
            pprint("Coins loot shown")
        elseif tg_stars.current_type == PRODUCT_TYPES.OFFER and tg_stars.current_offer_id then
            pprint("Processing offer results...")
            -- Применяем результаты покупки оффера (без повторной аналитики)
            local offer_data = extract_offer_data(tg_stars.current_offer_id)
            apply_purchase_results(tg_stars.current_offer_id, offer_data)
            
            -- Вызываем callback если он зарегистрирован
            local callback = tg_stars.offer_success_callbacks[tg_stars.current_offer_id]
            if callback then
                callback()
            end
            pprint("Offer processing complete")
        end
    end)
    
    if not success then
        pprint("ERROR in visual processing:", error_msg)
    end
    
    pprint("=== handle_buy_success END ===")
end

-- Обработать отмену покупки
local function handle_buy_cancelled()
    hide_loader()
    track_purchase_error(
        tg_stars.current_type,
        get_product_name(tg_stars.current_type, tg_stars.id or tg_stars.current_offer_id),
        "cancelled"
    )
end

-- Обработать отклонение покупки
local function handle_buy_declined()
    hide_loader()
    track_purchase_error(
        tg_stars.current_type,
        get_product_name(tg_stars.current_type, tg_stars.id or tg_stars.current_offer_id),
        "declined"
    )
end

-- Обработать неизвестную ошибку
local function handle_buy_unknown()
    hide_loader()
    track_purchase_error(
        tg_stars.current_type,
        get_product_name(tg_stars.current_type, tg_stars.id or tg_stars.current_offer_id),
        "unknown"
    )
end

-- ОСНОВНОЙ ОБРАБОТЧИК СООБЩЕНИЙ

-- Глобальный listener, не привязанный к конкретному инстансу GUI
local function js_listener(self, message_id, message)
    pprint("js_listener", message_id, message)

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

-- ФУНКЦИИ ИНИЦИАЛИЗАЦИИ И ДЕАКТИВАЦИИ

-- Глобальная активация listener'а - вызывается один раз и остается активным
function tg_stars.init()
    if jstodef then
        jstodef.add_listener(js_listener)
    end
end

-- ОБРАБОТКА ПОКУПКИ ОФФЕРОВ

-- Таблица callback'ов для успешных покупок офферов
tg_stars.offer_success_callbacks = {}

-- Функция для регистрации callback при успешной покупке оффера
function tg_stars.register_offer_callback(offer_id, callback)
    tg_stars.offer_success_callbacks[offer_id] = callback
end

function tg_stars.on_offer_purchased(offer_id, server_offers_map)
    local offer_data = extract_offer_data(offer_id)
    apply_purchase_results(offer_id, offer_data)
    
    
    -- Вызываем callback если он зарегистрирован
    local callback = tg_stars.offer_success_callbacks[offer_id]
    if callback then
        callback()
    end
end

-- ФУНКЦИИ ПОКУПОК

-- Создать инвойс и обработать результат
local function create_invoice_and_buy(request_data, product_type, product_name)
    show_loader()
    
    request("create-invoice", request_data, function(response)
        print(response.invoiceLink)
        html5.run("tgStarsBuy('"..response.invoiceLink.."')")
    end, function(error_response)
        show_error("Unknown error")
        print(error_response)
        track_purchase_error(request_data.type, product_name, "create_invoice_failed")
    end, false)
end

-- Покупка монет (совместимость со старым API)
function tg_stars.buy(id, stable_count, coins_count, rate)
    -- Сохраняем данные текущей покупки
    tg_stars.current_type = PRODUCT_TYPES.COINS
    tg_stars.id = id
    tg_stars.stable_count = stable_count
    tg_stars.coins_count = coins_count
    tg_stars.rate = rate
    
    local product_name = get_product_name(PRODUCT_TYPES.COINS, id)
    local stars = tonumber(stable_count) or 0
    
    -- Аналитика начала покупки
    track_purchase_start(PRODUCT_TYPES.COINS, product_name, {
        stars = stars,
        coins = tonumber(coins_count) or 0,
        rate = tonumber(rate) or 0
    })
    
    -- Создаем инвойс
    create_invoice_and_buy({type = PRODUCT_TYPES.COINS, option_id = id}, product_name)
end

-- Покупка оффера
function tg_stars.buy_offer(offer_id)
    tg_stars.current_type = PRODUCT_TYPES.OFFER
    tg_stars.current_offer_id = offer_id
    
    local offer_data = extract_offer_data(offer_id)
    
    -- Аналитика начала покупки
    track_purchase_start(PRODUCT_TYPES.OFFER, offer_id, {
        stars = offer_data.price_stars
    })
    
    -- Продакшен: создаем инвойс
    create_invoice_and_buy({type = PRODUCT_TYPES.OFFER, offer_id = offer_id}, offer_id)
end

return tg_stars