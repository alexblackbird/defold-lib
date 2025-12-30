local device_fingerprint = {}

function device_fingerprint.js_listener(self, message_id, message)
	pprint("js_listener", message_id, message)
	
	if message_id == "deviceFingerprint" then
		lb.set("device_fingerprint", message)

		device_fingerprint.deactivate_listener()
	end
end

function device_fingerprint.init()
	-- активировать слушатель если еще не активирован
	device_fingerprint.activate_listener()

	if html5 then
		html5.run("getDeviceFingerprint()")
	end
end

function device_fingerprint.deactivate_listener()
	if jstodef then 
		jstodef.remove_listener(device_fingerprint.js_listener)
		device_fingerprint.is_js_listener_activated = false
	end
end

function device_fingerprint.activate_listener()
	if jstodef and not device_fingerprint.is_js_listener_activated then
		device_fingerprint.is_js_listener_activated = true
		jstodef.add_listener(device_fingerprint.js_listener)
	end
end

return device_fingerprint