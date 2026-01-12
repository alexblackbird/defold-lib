sys.set_connectivity_host("www.google.com")

local network = {}

function network.is_connected()
	local status = false
	if (sys.NETWORK_CONNECTED_CELLULAR == sys.get_connectivity()) or sys.NETWORK_CONNECTED == sys.get_connectivity() then
		status = true
	else
		status = false
	end
	return status
end
	

return network