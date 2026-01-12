local transitions = require "monarch.transitions.gui"
local monarch = require "monarch.monarch"

local popup = {}
popup.pool = {}

local config = {
    enable_fade = true
}

-- MONARCH
function popup.set_animation(self, background_node)
	self.custom = function (node, to, easing, duration, delay, cb)
		gui.set_scale(node, vmath.vector4(0.95, 0.95, 1, 1))
		gui.animate(node, gui.PROP_SCALE, to.scale, easing, duration, delay, cb)
	end
	self.transition = transitions.create(gui.get_node(background_node))
	.show_in(self.custom, gui.EASING_LINEAR, 0.1, 0)

	monarch.on_transition(self.MONARCH_ID, self.transition)
end

function popup.set_animation_by_id(MONARCH_ID, background_node)
	local custom = function (node, to, easing, duration, delay, cb)
		gui.set_scale(node, vmath.vector4(0.8, 0.8, 1, 1))
		gui.animate(node, gui.PROP_SCALE, to.scale, easing, duration, delay, cb)
	end
	local transition = transitions.create(gui.get_node(background_node))
	.show_in(custom, gui.EASING_OUTBACK, 0.4, 0)

	monarch.on_transition(MONARCH_ID, transition)
end

function popup.on_message_monarch(self, message_id, message, sender, params)
	if not params then 
		params = {is_popup = true}
	end
		
	if self.transition then
		self.transition.handle(message_id, message, sender)
	end
	
	if message_id == hash("transition_show_in") then
		if params.is_popup and config.enable_fade then
			msg.post("loader:/fade#gui", "show", fade_params)
		end
		self.active_button = {}
		-- msg.post("loader:/sound#woosh", "play_sound")
		self.data = monarch.data(self.MONARCH_ID)
	elseif message_id == hash("transition_back_out") then
		if config.enable_fade then
			msg.post("loader:/fade#gui", "hide")
		end
		self.active_button = {}
	end
end

function popup.show(window_id, options, data)
	if not popup.current_top then -- or popup.current_top ~= window_id
		monarch.show(window_id, options, data, function ()
			
		end)
		
		popup.current_top = window_id
		popup.current_data = data
	else
		table.insert(popup.pool, {window_id = window_id, options = options, data = data})
	end
end

function popup.hide(window_id)
	monarch.hide(window_id)
	popup.current_top = nil
	popup.current_data = nil

	popup.open_next()
end

function popup.open_next(delay)
	if not delay then
		delay = 0
	end

	-- если есть очередь - то запускаем поледний добавленный о очередь
	if next(popup.pool) then
		local i = #popup.pool
		popup.show(popup.pool[i].window_id, popup.pool[i].options, popup.pool[i].data)
		-- удалем из очереди 
		table.remove(popup.pool, i)
	end
end

function popup.init(params)
    params = params or {}
    if params.enable_fade ~= nil then
        config.enable_fade = params.enable_fade
    end
end

return popup