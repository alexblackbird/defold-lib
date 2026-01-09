
function touch(self, action, node_string, callback, without_animation, sound_file)
  local node = (type(node_string) == 'string' and gui.get_node(node_string) or node_string)

  if not self.active_button then
    self.active_button = {}
  end
  
  if action.pressed then
    td = action
  end
  
  if gui.pick_node(node, action.x, action.y) and gui.is_enabled(node, true) then
    -- ищем, есть ли в кнопках
    local search = nil
    for i, v in ipairs(self.active_button) do
      if v.node == node then
        search = v
        search.id = i
      end
    end
    
    if action.pressed and not search then
      local scale = gui.get_scale(node)
      local to_scale = scale * 0.9
      
      if not sound_file then
        sound_file = "menu:/sound#click"
      end

      sound.play(sound_file)
      
      if not without_animation then
        gui.animate(node, "scale", to_scale, gui.EASING_OUTSINE, 0.1, 0, function (self)
        end)
      end
      table.insert(self.active_button, {scale = scale, node = node, callback = callback, sound_file = sound_file, to_scale = to_scale})
    end

    if action.pressed and search then
      -- я нажал на кнопку и она найдена - значит нужно взять to_scale и совершить нажатие
      local scale = gui.get_scale(node)
      local to_scale = search.to_scale -- мы просто подменяем скейл на наш сохраненный
      if not sound_file then
        sound_file = "menu:/sound#click"
      end

      -- без добавления в анимации
      if not without_animation then
        gui.animate(node, "scale", to_scale, gui.EASING_OUTSINE, 0.1)
      end
    end

    if action.released and search then
      if not without_animation then
        gui.animate(node, "scale", search.scale, gui.EASING_OUTSINE, 0.1, 0, function (self)
          table.remove(self.active_button, search.id)
        end)
      end
      taptic.run(taptic.IMPACT_LIGHT)
      search.callback()
    end
  else
    for i, v in ipairs(self.active_button) do
      if v.node == node then
        if not without_animation then
          gui.animate(v.node, "scale", v.scale, gui.EASING_OUTSINE, 0.1)
        end
        table.remove(self.active_button, i)
      end
    end
  end
end

function touch_deactivate(self)
  if self.active_button then
    for i, v in ipairs(self.active_button) do
      if not without_animation then
        gui.animate(v.node, "scale", v.scale, gui.EASING_OUTSINE, 0.1)
      end
      table.remove(self.active_button, i)
    end
  end
end