local defsave = require("defsave.defsave")
lb = {}

function lb.init(app_name)
	defsave.appname = app_name
	defsave.load("config")
end

function lb.set(key, value)
	local data = defsave.get("config", "data") or {}

	data[key] = value
	
	defsave.set("config", "data", data)
	defsave.save_all()
end

function lb.multi_set(pool)
	local data = defsave.get("config", "data") or {}
	
	for key, value in pairs(pool) do
		data[key] = value
	end
	
	defsave.set("config", "data", data)
	defsave.save_all()
end

function lb.get(key, default)
	local data = defsave.get("config", "data") or {}

	if data[key] or data[key] == false then
		return data[key]
	elseif default ~= nil then
		return default
	else
		return nil
	end

	if data[key] == nil then
		if default ~= nil then
			return default
		else
			return nil
		end
	else
		return data[key]
	end
end

function lb.get_stucture()
	return defsave.get("config", "data") or {}
end

function lb.delete_data()
	defsave.set("config", "data", {})
	defsave.save_all()
end


function lb.final()
	defsave.save_all()
end

return lb