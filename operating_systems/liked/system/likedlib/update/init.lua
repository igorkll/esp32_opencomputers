local paths = require("paths")
local system = require("system")
local fs = require("filesystem")
local computer = require("computer")
local serialization = require("serialization")
local sysdata = require("sysdata")
local registry = require("registry")
local liked = require("liked")
local update = {}
update.updaterPath = paths.concat(paths.path(system.getSelfScriptPath()), "update.lua")

function update._generate(data)
	local updater = assert(fs.readFile(update.updaterPath))
	local strdata = serialization.serialize(data)
	return "local installdata = " .. strdata .. "\n" .. updater
end

function update._write(data)
	data.self = "/likeOS_startup.lua"
	assert(fs.writeFile(data.self, update._generate(data)))
end

function update.needWipe(branch, mode)
	if sysdata.get("branch") ~= branch then return true end
	return liked.getFileFromRepo("/system/dataVersion.cfg", branch) ~= fs.readFile("/system/dataVersion.cfg")
end

function update.run(branch, mode, wipedata)
	local data = sysdata.list()
	data.branch = branch or data.branch
	data.mode = mode or data.mode
	
	update._write({data = data, filesBlackList = registry.filesBlackList})
	if wipedata then
		fs.remove("/data")
	end
	computer.shutdown("fast")
end

update.unloadable = true
return update