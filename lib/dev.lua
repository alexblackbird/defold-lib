local dev = {}

function dev.init()
	if sys_info.system_name == "Windows" then
		defos.set_window_size(40, 40, 900, 2000)
		--sys_info.wallet_address = "0x08B4b984877eAaa728AcfF3Eb7063D186603e675"
	end

	if sys_info.system_name == "Darwin" then
		--defos.set_window_size(70, 50, 480, 900)
		--defos.set_window_size(70, 50, 350, 700)
		defos.set_window_size(700, 100, 1080/2, 1920/2)
		--sys_info.wallet_address = "0x08B4b984877eAaa728AcfF3Eb7063D186603e675"
	end
end

return dev