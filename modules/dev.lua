local dev = {}

function dev.init()
	local sys_info = sys.get_sys_info()
	if sys_info.system_name == "Windows" then
		defos.set_window_size(40, 40, 900, 2000)
	end

	if sys_info.system_name == "Darwin" then
		defos.set_window_size(700, 100, 1080/2, 1920/2)
	end
end

function dev.on_input(self, action_id, action)
	if action_id == hash("key_p") and action.released and sys.get_engine_info().is_debug then
		if not self.profiler_flag then
			profiler.enable_ui(true)
			self.profiler_flag = true
		else
			profiler.enable_ui(false)
			self.profiler_flag = false
		end
	end
end

return dev