local registry = require("registry")
local serialization = require("serialization")
local paths = require("paths")
local system = require("system")
local fs = require("filesystem")
local storage = {}

function storage.getLang()
	local lang = registry.lang or "eng"
	local path = system.getResourcePath(paths.concat("lang", lang .. ".lang"))
	if fs.exists(path) then
		return path
	end

	path = system.getResourcePath("lang/eng.lang")
	if fs.exists(path) then
		return path
	end
end

function storage.getConf(default)
	return registry.new(system.getResourcePath("data.cfg"), default)
end

storage.unloadable = true
return storage