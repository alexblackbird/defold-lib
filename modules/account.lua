local account = {}

-- Универсальный модуль аккаунта со встроенными провайдерами
-- Использование:
--   account.init({ telegram = true, fingerprint = true, acquisition = true, on_success = fn, on_error = fn })
--   account.login()

local config = {
	providers = {},
	on_success = function(data) end,
	on_error = function(error) end,
	endpoint = 'account',
	request_fn = nil
}

-- Встроенные провайдеры
local builtin_providers = {
	telegram = function()
		if telegram and telegram.params then
			return { init_data = json.encode(telegram.params) }
		end
		return {}
	end,
	
	fingerprint = function()
		if lb then
			return { device_fingerprint = lb.get("device_fingerprint", "") }
		end
		return {}
	end,
	
	acquisition = function()
		if sys_info.system_name ~= "HTML5" then return {} end
		local params = {}
		
		local referral_id = html5.run("getRefferal()")
		if referral_id and referral_id ~= "" then
			params.referral_id = referral_id
		end
		
		local ad_json = html5.run("getAcquisitionData()")
		if ad_json and type(ad_json) == "string" and ad_json ~= "" then
			local ok, data = pcall(json.decode, ad_json)
			if ok and type(data) == "table" then
				for _, field in ipairs({"publisher_id", "click_id", "campaign_id", "banner_id", "utm_source"}) do
					if data[field] then params[field] = data[field] end
				end
			end
		end
		return params
	end
}

function account.init(params)
	if not params then return end
	
	-- Включаем встроенные провайдеры по флагам
	if params.telegram then config.providers.telegram = builtin_providers.telegram end
	if params.fingerprint then config.providers.fingerprint = builtin_providers.fingerprint end
	if params.acquisition then config.providers.acquisition = builtin_providers.acquisition end
	
	-- Коллбэки
	if params.on_success then config.on_success = params.on_success end
	if params.on_error then config.on_error = params.on_error end
	if params.endpoint then config.endpoint = params.endpoint end
	if params.request_fn then config.request_fn = params.request_fn end
end

function account.add_provider(name, provider_fn)
	config.providers[name] = provider_fn
end

local function collect_params()
	local params = {}
	for _, provider in pairs(config.providers) do
		local result = provider()
		if result and type(result) == "table" then
			for k, v in pairs(result) do
				params[k] = v
			end
		end
	end
	return params
end

function account.login(custom_params)
	local params = collect_params()
	
	if custom_params then
		for k, v in pairs(custom_params) do
			params[k] = v
		end
	end
	
	local req_fn = config.request_fn or request
	if not req_fn then
		error("account: request function not defined")
		return
	end
	
	req_fn(config.endpoint, params, function(data)
		config.on_success(data, params)
	end, function(err)
		config.on_error(err, params)
	end, false)
end

function account.create(params, callback)
	local req_fn = config.request_fn or request
	req_fn(config.endpoint, params, function(data)
		if callback then callback(data) end
	end, config.on_error, true)
end

return account