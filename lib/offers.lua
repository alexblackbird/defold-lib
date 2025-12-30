local offers = {}

-- Возвращает таблицу офферов из конфига игры
function offers.get_offers_config()
    if db and db.configs and db.configs.shop and db.configs.shop.offers then
        return db.configs.shop.offers
    end
    return {}
end

-- Возвращает конфиг конкретного оффера по идентификатору
function offers.get(offer_id)
    local cfg = offers.get_offers_config()
    return cfg and cfg[offer_id] or nil
end

-- Проверка купленного оффера по новому контракту: db.offers
function offers.is_purchased(offer_id)
    local user_offers = db and db.offers
    -- Может прийти строкой (JSON) — пробуем распарсить
    if type(user_offers) == "string" then
        local ok, decoded = pcall(json.decode, user_offers)
        if ok and type(decoded) == "table" then
            user_offers = decoded
            db.offers = decoded
        end
    end
    
    if type(user_offers) ~= "table" then
        return false
    end

    -- Вариант 1: map вида { starterpack = true }
    if user_offers[offer_id] ~= nil and user_offers[offer_id] ~= false then
        return true
    end

    -- Вариант 2: массив значений (строки/id) или объектов
    for _, v in pairs(user_offers) do
        if v == offer_id then
            return true
        end
        if type(v) == "table" then
            if v.id == offer_id or v.offer_id == offer_id or v.key == offer_id then
                return true
            end
        end
    end

    return false
end

-- Оффер доступен если он присутствует в конфиге и ещё не куплен
function offers.is_available(offer_id)
    if not offers.get(offer_id) then
        return false
    end
    return not offers.is_purchased(offer_id)
end

return offers


