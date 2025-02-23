local fs = require("filesystem")
local paths = require("paths")

local sysdata = {}
local varsPath = "/system/sysdata"
local defaults = {
	["branch"] = "main",
	["mode"] = "full"
}

function sysdata.path(key)
	return paths.concat(varsPath, key)
end

function sysdata.get(key)
	local path = sysdata.path(key)
	if fs.exists(path) then
		return fs.readFile(path) or defaults[key]
	else
		return defaults[key]
	end
end

function sysdata.set(key, value)
	local path = sysdata.path(key)
	return fs.writeFile(path, value or defaults[key])
end

function sysdata.list()
	local lst = {}
	for k, v in pairs(defaults) do
		lst[k] = v
	end
	for _, name in ipairs(fs.list(varsPath)) do
		lst[name] = sysdata.get(name)
	end
	return lst
end

sysdata.unloadable = true
return sysdata