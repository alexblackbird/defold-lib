local M = {}

local config = {
    request = nil,      -- функция запроса к серверу request(endpoint, params, callback, use_post)
    on_change = nil     -- коллбек при изменении адреса: function(address)
}

M.address = nil
M.raw = nil
M.in_process = false
M.is_js_listener_activated = false

function M.init(params)
    if params.request then config.request = params.request end
    if params.on_change then config.on_change = params.on_change end
end

-- Установить адрес (например, при загрузке профиля с сервера)
function M.set_address(addr, raw)
    M.address = addr
    M.raw = raw
end

function M.is_connected()
    return M.address ~= nil
end

local function js_listener(self, message_id, message)
    pprint("js_listener", message_id, message)

    M.in_process = false
    
    if message_id == "connectedWalletSuccess" then
        pprint(message)

        M.address = message.friendly
        M.raw = message.raw
        
        -- Уведомляем внешний код об изменении
        if config.on_change then
            config.on_change(M.address)
        end

        if M.callback then
            M.callback()
            M.callback = nil
        end

        -- записать кошелек на севрере
        if config.request then
            config.request('wallet', {method = "connect", wallet_address = M.address}, function (jd)
                
            end, true)
        else
            -- Fallback to global request if available?
            if request then
                 request('wallet', {method = "connect", wallet_address = M.address}, function (jd) end, true)
            end
        end
        
    elseif message_id == "disconnectedWalletSuccess" then
        -- затереть кошелек
        M.address = nil
        M.raw = nil
        
        -- Уведомляем внешний код об изменении
        if config.on_change then
            config.on_change(nil)
        end

        if M.callback then
            M.callback()
            M.callback = nil
        end

        -- удалить кошелек на севрере
        if config.request then
            config.request('wallet', {method = "disconnect"}, function (jd)
                
            end, true)
        else
            if request then
                 request('wallet', {method = "disconnect"}, function (jd) end, true)
            end
        end
        
    elseif message_id == "connectedWalletError" then
        pprint("error")
    end

    M.deactivate_listener()
end

function M.connectWallet(callback)
    -- активировать слушатель если еще не активирован
    M.activate_listener()
    
    -- сохранить коллбек
    M.callback = callback
    
    M.in_process = true
    
    if html5 then
        html5.run('connectWallet()')
    end
end

function M.disconnectWallet(callback)
    print("disconnectWallet")
    -- активировать слушатель если еще не активирован
    M.activate_listener()
    
    -- сохранить коллбек
    M.callback = callback
    
    if html5 then
        html5.run('disconnectWallet()')
    end
end

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
