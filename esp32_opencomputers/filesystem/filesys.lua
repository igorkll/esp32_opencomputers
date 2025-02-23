local filesys = {}

function filesys.writeFile(path, content)
	local file = io.open(path, "wb")
	if file then
		file:write(content)
		file:close()
		return true
	end
	return false
end

function filesys.readFile(path)
	local file = io.open(path, "rb")
	if file then
		local data = file:read("*a")
		file:close()
		return data
	end
end

return filesys