local ab_test = {}

ab_test.GROUP_A = "A"
ab_test.GROUP_B = "B"
ab_test.GROUP_C = "C"
ab_test.groups_name = {ab_test.GROUP_A, ab_test.GROUP_B, ab_test.GROUP_C}
ab_test.group_index = 1
-- для совместимости
ab_test.ab_groups_name = ab_test.groups_name
ab_test.ab_group_index = ab_test.group_index

ab_test.ab_group = ab_test.GROUP_A

function ab_test.init()
	
	-- тестовая группа
	if math.fmod(db.game_id, 3) == 0 then
		ab_test.ab_group = ab_test.GROUP_A
		ab_test.group_index = 1
		ab_test.ab_group_index = 1
	elseif math.fmod(db.game_id, 3) == 1 then
		ab_test.ab_group = ab_test.GROUP_B
		ab_test.group_index = 2
		ab_test.ab_group_index = 2
	else
		ab_test.ab_group = ab_test.GROUP_C
		ab_test.group_index = 3
		ab_test.ab_group_index = 3
	end

	-- настройки игры
	if sys_info.ab_group == ab_test.GROUP_A then

	elseif sys_info.ab_group == ab_test.GROUP_B then

	elseif sys_info.ab_group == ab_test.GROUP_C then
		
	end
end

function ab_test.start(toggling_pool)
	-- функция для запуска A/B тестирования
	-- toggling_pool - параметры для переключения групп
	-- здесь можно добавить логику обработки параметров
	print("AB Test started for group: " .. (ab_test.ab_group or "unknown"))
end

return ab_test