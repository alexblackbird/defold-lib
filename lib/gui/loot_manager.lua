local loot_manager = {}

function loot_manager.format_number(number)
	local i, j, minus, int, fraction = tostring(number):find('([-]?)(%d+)([.]?%d*)')

	-- reverse the integer part of the number
	int = int:reverse()

	-- add the thousands separator
	int = int:gsub("(%d%d%d)", "%1 ")

	-- reverse the integer part back
	int = int:reverse()

	-- remove any leading thousands separator
	int = int:gsub("^ ", "")

	-- construct and return the formatted number
	return minus .. int .. fraction
end

-- быстрый запуск функции которая вызовет лут в нужном контексте и заранее добавит средства чтобы не блоы момента когда у пользователя нет денег
function loot_manager.loot(params)
	db[params.type] = db[params.type] + params.count

	-- analytics: earning resources (e.g., coins)
	amplitude.track("earn", { type = params.type, value = params.count })
	
	monarch.post('menu', 'loot_manager', params)
end

-- названия панелей - целей
local loot_params = {
	coins = {place = "coins_panel", icon = "loot_coins", sound = "loot_coins", counting = true, is_spine = true}
}

function loot_manager.flyLoot(self, nodes, data, type)
	local target_node = gui.get_node(loot_params[type].place)
	local target_position = gui.get_screen_position(target_node)

	target_position.x, target_position.y = rendercam.screen_to_gui(target_position.x, target_position.y, gui.ADJUST_FIT)
	
	local delay, time

	for i, node in ipairs(nodes) do
		delay = i * 0.03
		time = 0.7 + (math.random(-1, 1) * 0.1)

		gui.animate(node, "position.y", target_position.y, gui.EASING_INQUAD, time, delay, function()
			gui.delete_node(node)
			taptic.run(taptic.IMPACT_LIGHT)
		end)
		gui.animate(node, "position.x", target_position.x + math.random(-20, 20), gui.EASING_OUTQUAD, time, delay)
		timer.delay(delay, false, function ()
			gui.animate(node, "scale", vmath.vector3(0.3), gui.EASING_OUTQUAD, time, 0, nil)
		end)
	end

	timer.delay(0.7, false, function ()
		-- зачислить приз
		local value = 1
		if data.value then
			value = data.value
		end
		if data.count then
			value = data.count
		end

		-- анимируем начисление ресурсов в эту плашку ресурса
		if loot_params[type].counting then
			loot_manager.animate_resource_counter(data.type.."_count_txt", data.type, value)
		end

		-- партиклы плашки
		if loot_params[type].particlefx and not data.not_particlefx then
			gui.play_particlefx(gui.get_node(loot_params[type].particlefx))
		end

		-- небольшая анимация сущности, куда прилетает
		gui.set_scale(target_node, vmath.vector3(1))
		gui.animate(target_node, "scale", vmath.vector3(0.9), gui.EASING_OUTQUAD, 0.6, 0, nil, gui.PLAYBACK_ONCE_PINGPONG)
		--
		--msg.post(current_socket..":/sound#sound_gate", "play_gated_sound", { soundcomponent = current_socket..":/sound#into_the_box", gain = 1.0 })

		loot_manager.in_proccess = false
	end)
end

function loot_manager.create(self, data)

	loot_manager.in_proccess = true
	
	local type = data.type
	local pos = vmath.vector3(data.x, data.y, 0)
	local target_node = gui.get_node(loot_params[type].place)
	local target_anchor = gui.get_xanchor(target_node)
	local nodes = {}
	local node, delay, time
	local volume = 14
	local randomscale

	if data.volume then
		volume = data.volume
	end
	
	for i = 1, volume do
		
		delay = i * 0.03
		time = 0.5 + (math.random(-1, 1) * 0.1)

		if loot_params[type].is_spine then
			node = gui.new_spine_node(pos, "coins")
			local play_properties = {offset = 0, playback_rate = 0.7 }
			gui.play_spine_anim(node, "animation", gui.PLAYBACK_LOOP_FORWARD, play_properties)
			randomscale = vmath.vector3(1)
		else
			node = gui.new_box_node(pos, vmath.vector3(0))
			gui.set_texture(node, "ui")
			gui.play_flipbook(node, loot_params[type].icon)
			gui.set_size_mode(node, gui.SIZE_MODE_AUTO)
			randomscale = vmath.vector3(1.1 + math.random(-0.05, 0.05) )
		end

		gui.set_scale(node, vmath.vector3(0.1))
		gui.animate(node, "scale", randomscale, gui.EASING_OUTBACK, time, delay)
		gui.animate(node, "position", vmath.vector3(pos.x + math.random(-150, 150), pos.y + 50 + math.random(-100, 100), 0), gui.EASING_OUTBACK, time, delay)
		gui.set_color(node, vmath.vector4(1, 1, 1, 0))
		gui.animate(node, "color.w", 1, gui.EASING_LINEAR, 0.1, delay)
		table.insert(nodes, node)
		gui.set_layer(node, "front")

		local particle = gui.new_particlefx_node(vmath.vector3(0), "loot_trail")
		gui.set_parent(particle, node, 0)
		timer.delay(i*0.05, false, function ()
			gui.play_particlefx(particle)
			taptic.run(taptic.IMPACT_LIGHT)
		end)

		gui.set_xanchor(node, target_anchor)
	end

	-- Текст
	local text_node = gui_new_text_node(vmath.vector3(pos.x + 100, pos.y, pos.z), "+" .. data.count, {
		scale = 0,
		layer = 'text',
		--color = vmath.vector4(1, 0.7176471, 0, 1 ),
		outline = vmath.vector4(0, 0, 0, 1 )
	})
	
	gui.animate(text_node, "scale", vmath.vector3(2), gui.EASING_OUTQUAD, 0.5, 0, function()
		gui.animate(text_node, "scale", vmath.vector3(0), gui.EASING_INBACK, 0.5, 0.4, function()
			gui.delete_node(text_node)
		end)
	end)

	msg.post("loader:/sound#sound_gate", "play_gated_sound", { soundcomponent = "loader:/sound#"..loot_params[type].sound, gain = 0.6 })

	timer.delay(0.9, false, function()
		loot_manager.flyLoot(self, nodes, data, type)
	end)
end

function loot_manager.animate_resource_counter(node_name, type, value)
	local old_value = db[type] - value
	local step = value/10
	local update_timer = nil
	update_timer = timer.delay(0.05, true, function ()
		old_value = old_value + step
		
		gui.set_text(gui.get_node(node_name), loot_manager.format_number(math.floor(old_value)))
		if db[type] == old_value or db[type] < old_value + step then
			gui.set_text(gui.get_node(node_name), loot_manager.format_number(db[type]))
			timer.cancel(update_timer)
		end
	end)
end

return loot_manager