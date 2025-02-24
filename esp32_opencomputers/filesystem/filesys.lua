local strlib = string
local filesys = {}

function filesys.segments(path)
	local parts = {}
	for part in path:gmatch("[^\\/]+") do
		local current, up = part:find("^%.?%.$")
		if current then
			if up == 2 then
				table.remove(parts)
			end
		else
			table.insert(parts, part)
		end
	end
	return parts
end

function filesys.xconcat(...) --работает как concat но пути начинаюшиеся со / НЕ обрабатываються как отновительные а откидывают путь в начало
	local set = {...}
	for index, value in ipairs(set) do
		if strlib.sub(value, 1, 1) == "/" and index > 1 then
			local newset = {}
			for i = index, #set do
				table.insert(newset, set[i])
			end
			return filesys.xconcat(table.unpack(newset))
		end
	end
	return filesys.canonical(table.concat(set, "/"))
end

function filesys.sconcat(main, ...) --работает так же как concat но если итоговый путь не указывает на целевой обьект первого путя то вернет nil
	main = filesys.canonical(main) .. "/"
	local path = filesys.concat(main, ...) .. "/"
	if strlib.sub(path, 1, strlib.len(main)) == main then
		return filesys.canonical(path)
	end
end

function filesys.xsconcat(main, ...) --работает так же как concat но если итоговый путь не указывает на целевой обьект первого путя то вернет nil, пути начинаюшиеся со / НЕ обрабатываються как отновительные а откидывают путь в начало
	main = filesys.canonical(main) .. "/"
	local path = filesys.xconcat(main, ...) .. "/"
	if strlib.sub(path, 1, strlib.len(main)) == main then
		return filesys.canonical(path)
	end
	return false
end

function filesys.concat(...) --класический concat как в openOS
	return filesys.canonical(table.concat({...}, "/"))
end

function filesys.canonical(path)
	local result = table.concat(filesys.segments(path), "/")
	if strlib.sub(path, 1, 1) == "/" then
		return "/" .. result
	end
	return result
end

local function rawEquals(pathsList)
	local mainPath = pathsList[1]
	for i = 2, #pathsList do
		if mainPath ~= pathsList[i] then
			return false
		end
	end
	return true
end

function filesys.equals(...)
	local pathsList = {...}
	for i, path in ipairs(pathsList) do
		pathsList[i] = filesys.canonical(path)
	end
	return rawEquals(pathsList)
end

function filesys.path(path)
	path = filesys.canonical(path)
	local parts = filesys.segments(path)
	local result = table.concat(parts, "/", 1, #parts - 1) .. "/"
	if strlib.sub(path, 1, 1) == "/" and strlib.sub(result, 1, 1) ~= "/" then
		return filesys.canonical("/" .. result)
	else
		return filesys.canonical(result)
	end
end

function filesys.name(path)
	local parts = filesys.segments(path)
	return parts[#parts]
end

function filesys.extension(path)
	local name = filesys.name(path)
	if not name then
		return
	end

	local exp
	for i = 1, strlib.len(name) do
		local char = strlib.sub(name, i, i)
		if char == "." then
			if i ~= 1 then
				exp = {}
			end
		elseif exp then
			table.insert(exp, char)
		end
	end

	if exp and strlib.len(exp) > 0 then
		return table.concat(exp)
	end
end

function filesys.changeExtension(path, exp)
	return filesys.hideExtension(path) .. (exp and ("." .. exp) or "")
end

function filesys.hideExtension(path)
	local exp = filesys.extension(path)
	if exp then
		return strlib.sub(path, 1, strlib.len(path) - (strlib.len(exp) + 1))
	else
		return path
	end
end

----------------------------------------------------

function filesys.open(path, mode)
	return io.open(path, mode)
end

function filesys.writeFile(path, content)
	local file, err = filesys.open(path, "wb")
	if file then
		file:write(content)
		file:close()
		return true
	end
	return nil, tostring(err)
end

function filesys.appendFile(path, content)
	local file, err = filesys.open(path, "ab")
	if file then
		file:write(content)
		file:close()
		return true
	end
	return nil, tostring(err)
end

function filesys.readFile(path)
	local file, err = filesys.open(path, "rb")
	if file then
		local data = file:read("*a")
		file:close()
		return data
	end
	return nil, tostring(err)
end

function filesys.exists(path)
	return hal_filesystem_exists(path)
end

function filesys.isDirectory(path)
	return hal_filesystem_isDirectory(path)
end

function filesys.isFile(path)
	return filesys.exists(path) and not filesys.isDirectory(path)
end

function filesys.size(path)
	return hal_filesystem_size(path), hal_filesystem_count(path, true, false), hal_filesystem_count(path, false, true)
end

function filesys.makeDirectory(path)
	return hal_filesystem_mkdir(path)
end

function filesys.lastModified(path)
	return hal_filesystem_lastModified(path)
end

function filesys.list(path)
	return {hal_filesystem_list(path)}
end

function filesys.remove(path)
	os.remove(path)
end

function filesys.rename(path, path2)
	os.rename(path, path2)
end

return filesys