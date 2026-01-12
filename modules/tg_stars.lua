local M = {}

local config = {
    request = nil,      -- network request function
    on_success = nil,   -- on success logic handler
    loader_url = "loader:/loader", -- optional loader url default
    lang_module = nil   -- optional lang module reference
}

function M.init(params)
    if params.request then config.request = params.request end
    if params.on_success then config.on_success = params.on_success end
    if params.loader_url then config.loader_url = params.loader_url end
    if params.lang_module then config.lang_module = params.lang_module end
end

local function js_listener(self, message_id, message)
    pprint("js_listener", message_id, message)

    if message_id == "tgStarsBuySuccess" then
        if config.on_success then
            config.on_success(M.type, M.indx, M.data)
        end
        
        if M.callback then
            M.callback()
        end
        
        -- Mixpanel tracking logic could also be injected or handled via on_success if highly project specific, 
        -- but generic tracking could be here. For now, assuming caller handles major business logic in on_success.
        
    elseif message_id == "tgStarsBuyCancelled" then
       -- Optional: tracking cancelled
       
    elseif message_id == "tgStarsBuyDeclined" then
       -- Optional: tracking declined

    elseif message_id == "tgStarsBuyUnknown" then
       -- Optional: tracking unknown
    end

    msg.post(config.loader_url, "request_loader_hide")

    M.deactivate()
end

function M.deactivate(self)
    if jstodef then 
        jstodef.remove_listener(js_listener)
        M.is_js_listener_activated = false
    end
end

function M.activate(self)
    if jstodef and not M.is_js_listener_activated then
        M.is_js_listener_activated = true
        jstodef.add_listener(js_listener) 
    end
end

function M.buy(type, indx, data, callback)
    M.activate()
    
    M.indx = indx
    M.type = type
    M.data = data
    M.callback = callback

    msg.post(config.loader_url, "request_loader_show")
    
    local lang_code = "en"
    if config.lang_module then lang_code = config.lang_module.language end
    
    if config.request then
        config.request("create-invoice", {type = type, indx = indx, language_code = lang_code}, function(jd)
            if jd.invoiceLink then
                if html5 then
                    html5.run("tgStarsBuy('"..jd.invoiceLink.."')")
                else
                    print("Generic buy called (not html5): " .. jd.invoiceLink)
                end
            end
            
        end, function (jd)
            msg.post(config.loader_url, "request_loader_hide")
            -- error handling popup injection?
            pprint(jd)
        end, false)
    else
        print("Error: db.request not configured in tg_stars")
    end
end

return M
