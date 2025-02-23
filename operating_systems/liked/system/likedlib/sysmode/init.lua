local sysdata = require("sysdata")
local system = require("system")
local registry = require("registry")
local serialization = require("serialization")
local fs = require("filesystem")
local paths = require("paths")

local sysmode = {}
sysmode.modes = {
	full = {
		reg = system.getResourcePath("full.reg")
	},
	classic = {
		reg = system.getResourcePath("classic.reg")
	},
	demo = {
		reg = system.getResourcePath("classic.reg"),
		modifier = system.getResourcePath("demo.reg")
	}
}

function sysmode.current()
	return sysmode.modes[sysdata.get("mode")] or error("unknown current system mode", 2)
end

function sysmode.init()
	local smode = sysmode.current()

	local function apply(vtag, regPath)
		if regPath then
			local sdata = assert(serialization.load(regPath))
			if not registry[vtag] or registry[vtag] ~= sdata[vtag] then
				registry.apply(sdata)
			end
		end
	end

	apply("sysmodeVersion", smode.reg)
	apply("modifierVersion", smode.modifier)

	if registry.settingsBlackList then
		registry.data.filesBlackList = registry.data.filesBlackList or {}
		local modulesPath = "/system/apps/settings.app/modules"
		for _, setting in ipairs(registry.settingsBlackList) do
			for _, module in ipairs(fs.list(modulesPath)) do
				if paths.hideExtension(module:sub(3, #module)) == setting then
					table.insert(registry.data.filesBlackList, paths.concat(modulesPath, module))
					break
				end
			end
		end
	end
	
	if registry.filesBlackList then
		for _, path in ipairs(registry.filesBlackList) do
			if fs.exists(path) then
				fs.remove(path)
			end
		end
	end

	registry.save()
end

sysmode.unloadable = true
return sysmode