function is_mobile()
	if sys_info.system_name == "Android" or sys_info.system_name == "iPhone OS" or sys_info.system_name == "iPad OS" then
		return true
	else
		return false
	end
end

function is_ios()
	if sys_info.system_name == "iPhone OS" or sys_info.system_name == "iPad OS" then
		return true
	else
		return false
	end
end

function is_android()
	if sys_info.system_name == "Android" then
		return true
	else
		return false
	end
end