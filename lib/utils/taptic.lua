-- библиотека таптика для ios
local taptic = {}

taptic.IMPACT_LIGHT = "IMPACT_LIGHT"
taptic.IMPACT_MEDIUM = "IMPACT_MEDIUM"
taptic.IMPACT_HEAVY = "IMPACT_HEAVY"
taptic.NOTIFICATION_SUCCESS = "NOTIFICATION_SUCCESS"
taptic.NOTIFICATION_WARNING = "NOTIFICATION_WARNING"
taptic.NOTIFICATION_ERROR = "NOTIFICATION_ERROR"
taptic.SELECTION = "SELECTION"

function taptic.run(event)
	local vibration_switch = lb.get("vibration_switch", true)
	
	if html5 and vibration_switch then
		if event == taptic.IMPACT_LIGHT then
			html5.run("Telegram.WebApp.HapticFeedback.impactOccurred('light')")
		elseif event == taptic.IMPACT_MEDIUM then
			html5.run("Telegram.WebApp.HapticFeedback.impactOccurred('medium')")
		elseif event == taptic.IMPACT_HEAVY then
			html5.run("Telegram.WebApp.HapticFeedback.impactOccurred('heavy')")
		elseif event == taptic.NOTIFICATION_SUCCESS then
			html5.run("Telegram.WebApp.HapticFeedback.notificationOccurred('success')")
		elseif event == taptic.NOTIFICATION_WARNING then
			html5.run("Telegram.WebApp.HapticFeedback.notificationOccurred('warning')")
		elseif event == taptic.NOTIFICATION_ERROR then
			html5.run("Telegram.WebApp.HapticFeedback.notificationOccurred('error')")
		elseif event == taptic.SELECTION then
			html5.run("Telegram.WebApp.HapticFeedback.selectionChanged()")
		end
	end
end

return taptic