local M = {}

function M.add(_type, params, additionally)
	
	if type(additionally) == 'table' then
		additionally = json_stringify(additionally)
	else
		additionally = false
	end
	request("tools/analytics/client", {	type = _type, params = json_stringify(params), additionally = additionally})
end

return M