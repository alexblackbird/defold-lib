-- соединяет 2 таблицы
function tableMerge(t1, t2)
	for k,v in pairs(t2)
	do table.insert(t1, v)
	end
	return t1
end

function tableGetIndex (_table, _value)
	local status = nil
	for i,value in ipairs(_table) do
		if value == _value then
			status = i
			break
		end
	end
	return status
end

function tableFindAndRemove (_table, _value)
	local status = false
	for i,value in ipairs(_table) do
		if value == _value then
			table.remove(_table, i)
			status = true
			break
		end
	end
	return status
end

function tableCopy (t) -- shallow-copy a table
	if type(t) ~= "table" then return t end
	local meta = getmetatable(t)
	local target = {}
	for k, v in pairs(t) do target[k] = v end
	setmetatable(target, meta)
	return target
end

function tableJoin(_table, _delimeter)
	local str = ''
	for i,v in ipairs(_table) do
		if str ~= '' then
			str = str.._delimeter
		end
		str = str..v
	end
	return str
end
