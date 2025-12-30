local avatar = {}

-- Установка аватара пользователя
function avatar.set_avatar(portrait_node, avatar_id)
    if portrait_node and avatar_id then
        gui.play_flipbook(portrait_node, "avatar-" .. avatar_id)
    end
end

-- Установка премиум статуса
function avatar.set_premium_status(frame_node, nickname_node, is_premium, nickname)
    if not frame_node then return end
    
    local frame = is_premium == 1 and "avatar_frame_mini_premium" or "avatar_frame_mini"
    gui.play_flipbook(frame_node, frame)
    
    if is_premium == 1 then
        if nickname_node then
            gui.set_color(nickname_node, hexToVector4("#fecb00"))
            gui.set_outline(nickname_node, hexToVector4("#7d0900"))
        end
    end
end

-- Установка никнейма
function avatar.set_nickname(nickname_node, nickname, translate)
    if nickname_node and nickname then
        if translate then
            lang.set(nickname_node, nickname, {translate = false})
        else
            gui.set_text(nickname_node, nickname)
        end
    end
end

-- Полная настройка аватара пользователя
function avatar.setup_user_avatar(user_data, nodes)
    if not user_data or not nodes then return end
    
    -- Аватар
    if nodes.portrait then
        avatar.set_avatar(nodes.portrait, user_data.avatar_id)
    end
    
    -- Никнейм
    if nodes.nickname then
        avatar.set_nickname(nodes.nickname, user_data.nickname, nodes.nickname_translate)
    end
    
    -- Премиум статус
    if nodes.frame then
        avatar.set_premium_status(
            nodes.frame, 
            nodes.nickname, 
            user_data.is_premium, 
            user_data.nickname
        )
    end
end

-- Настройка аватара для топ-3 мест (специальный случай)
function avatar.setup_top_avatar(user_data, avatar_prefix)
    if not user_data or not avatar_prefix then return end
    
    -- Аватар
    avatar.set_avatar(gn(avatar_prefix .. "/portait"), user_data.avatar_id)
    
    -- Никнейм
    avatar.set_nickname(gn(avatar_prefix .. "/avatar_name_txt"), user_data.nickname, true)
    
    -- Премиум статус
    avatar.set_premium_status(
        gn(avatar_prefix .. "/frame"),
        gn(avatar_prefix .. "/avatar_name_txt"),
        user_data.is_premium,
        user_data.nickname
    )
end

-- Универсальная функция создания аватара
function avatar.create(user_data, root_or_nodes, nodes)
    if not user_data then return end
    
    -- Если передан root name (строка)
    if not nodes then
        
        local root = root_or_nodes
        local avatar_node = gn(root_or_nodes.."/avatar")
        -- Аватар
        avatar.set_avatar(gn(root .. "/portait"), user_data.avatar_id)
        
        -- Никнейм (проверяем разные варианты названий)
        local nickname_node = gn(root .. "/avatar_name_txt") or gn(root .. "/nickname_txt")
        if nickname_node then
            avatar.set_nickname(nickname_node, user_data.nickname, true)
        end
        
        -- Премиум статус
        local frame_node = gn(root .. "/frame")
        if frame_node then
            avatar.set_premium_status(
                frame_node,
                nickname_node,
                user_data.is_premium,
                user_data.nickname
            )
        end
        
        -- Ribbon (если присутствует)
        local ribbon_node = gn(root .. "/avatar_name_ribbon")
        if ribbon_node then
            gui.set_enabled(ribbon_node, true)
            local is_me = (user_data.is_me == true) or (user_data.game_id and db and user_data.game_id == db.game_id)
            local ribbon_flip = is_me and "avatar_name_ribbon_me" or "avatar_name_ribbon"
            gui.play_flipbook(ribbon_node, ribbon_flip)
        end
        gui.set_enabled(avatar_node, true)
    
    -- Если передан nodes (таблица)
    elseif nodes then
        local avatar_node = nodes[hash(root_or_nodes.."/avatar")]
        local portrait = nodes[hash(root_or_nodes.."/portait")]
        local frame = nodes[hash(root_or_nodes.."/frame")]
        local ribbon = nodes[hash(root_or_nodes.."/avatar_name_ribbon")]
        local nickname_node = nodes[hash(root_or_nodes.."/avatar_name_txt")] or nodes[hash(root_or_nodes.."/nickname_txt")]

        -- Аватар
        avatar.set_avatar(portrait, user_data.avatar_id)

        -- Премиум статус
        local frame_img = user_data.is_premium == 1 and "avatar_frame_mini_premium" or "avatar_frame_mini"
        gui.play_flipbook(frame, frame_img)

        -- Никнейм (если есть нода)
        if nickname_node and user_data.nickname then
            lang.set(nickname_node, user_data.nickname, { translate = false })
        end
        
        -- Ribbon (если присутствует)
        if ribbon then
            gui.set_enabled(ribbon, true)
            local is_me = (user_data.is_me == true) or (user_data.game_id and db and user_data.game_id == db.game_id)
            local ribbon_flip = is_me and "avatar_name_ribbon_me" or "avatar_name_ribbon"
            gui.play_flipbook(ribbon, ribbon_flip)
        end
        gui.set_enabled(avatar_node, true)
    end

   
end

-- Создание мини-аватара без ribbon
function avatar.create_mini(user_data, root_or_nodes, nodes)
    -- Если передан root name (строка)
    if not nodes then
        local root = root_or_nodes
        
        -- Аватар
        avatar.set_avatar(gn(root .. "/portait"), user_data.avatar_id)
        
        -- Премиум статус (только фрейм, без ribbon)
        local frame_node = gn(root .. "/frame")
        if frame_node then
            local frame = user_data.is_premium == 1 and "avatar_frame_mini_premium" or "avatar_frame_mini"
            gui.play_flipbook(frame_node, frame)
        end
        
        -- Скрываем ribbon если он есть
        local ribbon_node = gn(root .. "/avatar_name_ribbon")
        if ribbon_node then
            gui.set_enabled(ribbon_node, false)
        end
    
    -- Если передан nodes (таблица)
    elseif nodes then
        local portrait = nodes[hash(root_or_nodes.."/portait")]
        local frame = nodes[hash(root_or_nodes.."/frame")]
        local ribbon = nodes[hash(root_or_nodes.."/avatar_name_ribbon")]
        
        -- Аватар
        avatar.set_avatar(portrait, user_data.avatar_id)
        
        -- Премиум статус (только фрейм, без ribbon)
        local frame_img = user_data.is_premium == 1 and "avatar_frame_mini_premium" or "avatar_frame_mini"
        gui.play_flipbook(frame, frame_img)
        
        -- Скрываем ribbon если он есть
        gui.set_enabled(ribbon, false)
    end
end

return avatar 