--[[
    УНИВЕРСАЛЬНЫЙ МОДУЛЬ TELEGRAM WALLET
    
    init({
        request = request,                -- функция запроса к серверу
        lb = lb,                          -- модуль локального хранилища (lb.get/lb.set)
        loot_module = loot_module,        -- опционально, для показа награды
        on_connect = function(address, raw, reward) end,  -- callback при подключении
        on_disconnect = function() end,   -- callback при отключении
        on_change = function(address) end, -- callback при любом изменении адреса
    })
]]

local M = {}

local config = {
    request = nil,
    lb = nil,
    loot_module = nil,
    on_connect = nil,
    on_disconnect = nil,
    on_change = nil,
}

-- Текущее состояние
M.address = nil
M.raw = nil
M.in_process = false
M.is_js_listener_activated = false
M.callback = nil

function M.init(params)
    params = params or {}
    
    if params.request then config.request = params.request end
    if params.lb then config.lb = params.lb end
    if params.loot_module then config.loot_module = params.loot_module end
    if params.on_connect then config.on_connect = params.on_connect end
    if params.on_disconnect then config.on_disconnect = params.on_disconnect end
    if params.on_change then config.on_change = params.on_change end
    
    -- Восстановить адрес из локального хранилища
    if config.lb then
        M.address = config.lb.get("wallet_address", nil)
    end
    
    -- Активируем jstodef listener
    M.activate_listener()
end

function M.is_connected()
    if config.lb then
        return config.lb.get("wallet_address", nil) ~= nil
    end
    return M.address ~= nil
end

function M.get_address()
    return M.address
end

function M.set_address(address)
    M.address = address
    if config.lb then
        config.lb.set("wallet_address", address)
    end
    if config.on_change then
        config.on_change(address)
    end
end

local function js_listener(self, message_id, message)
    pprint("wallet js_listener", message_id, message)

    M.in_process = false
    
    if message_id == "connectedWalletSuccess" then
        M.address = message.friendly
        M.raw = message.raw
        
        if config.lb then
            config.lb.set("wallet_address", M.address)
        end
        
        -- Вызываем callback подключения
        if M.callback then
            M.callback()
            M.callback = nil
        end
        
        -- Записать кошелек на сервере
        if config.request then
            config.request('wallet', {method = "connect", wallet_address = M.address}, function(jd)
                if jd.reward and config.loot_module then
                    config.loot_module.drop({type = "coins", count = jd.reward})
                end
                
                if config.on_connect then
                    config.on_connect(M.address, M.raw, jd.reward)
                end
            end, function(err)
                pprint("wallet connect request error", err)
            end, true)
        else
            if config.on_connect then
                config.on_connect(M.address, M.raw, nil)
            end
        end
        
        if config.on_change then
            config.on_change(M.address)
        end
        
    elseif message_id == "disconnectedWalletSuccess" then
        if config.lb then
            config.lb.set("wallet_address", nil)
        end
        
        M.address = nil
        M.raw = nil
        
        if M.callback then
            M.callback()
            M.callback = nil
        end
        
        -- Удалить кошелек на сервере
        if config.request then
            config.request('wallet', {method = "disconnect"}, function(jd)
                if config.on_disconnect then
                    config.on_disconnect()
                end
            end, function(err)
                pprint("wallet disconnect request error", err)
            end, true)
        else
            if config.on_disconnect then
                config.on_disconnect()
            end
        end
        
        if config.on_change then
            config.on_change(nil)
        end
        
    elseif message_id == "connectedWalletError" then
        pprint("wallet connection error")
        M.in_process = false
    end
end

function M.connect(callback)
    M.activate_listener()
    M.callback = callback
    M.in_process = true
    
    if html5 then
        html5.run('connectWallet()')
    else
        pprint("wallet: connectWallet() called (not html5)")
    end
end

-- Alias для совместимости с cryptodwarves API
M.connectWallet = M.connect

function M.disconnect(callback)
    M.activate_listener()
    M.callback = callback
    
    if html5 then
        html5.run('disconnectWallet()')
    else
        pprint("wallet: disconnectWallet() called (not html5)")
    end
end

-- Alias для совместимости с cryptodwarves API
M.disconnectWallet = M.disconnect

function M.deactivate_listener()
    if jstodef then 
        jstodef.remove_listener(js_listener)
        M.is_js_listener_activated = false
    end
end

function M.activate_listener()
    if jstodef and not M.is_js_listener_activated then
        M.is_js_listener_activated = true
        jstodef.add_listener(js_listener)
    end
end

return M
