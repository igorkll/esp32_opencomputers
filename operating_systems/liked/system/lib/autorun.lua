local registry = require("registry")
local fs = require("filesystem")
local programs = require("programs")
local logs = require("logs")
local cache = require("cache")
local component = require("component")
local autorun = {}

local groudList = {
	["system"] = true,
	["user"] = true
}

local function removePath(tbl, path)
	for i = #tbl, 1, -1 do
		if tbl[i][1] == path then
			table.remove(tbl, i)
		end
	end
end

if not cache.static[1] then
	function autorun.autorun()
		if registry.autorun then
			local function doAutorun(tbl)
				local needSave = false
				for i = #tbl, 1, -1 do
					local path, enable, disk = table.unpack(tbl[i])
					if path and fs.exists(path) then
						if enable then
							logs.checkWithTag("autorun error", programs.xexecute(path))
						end
					elseif component.isConnected(disk) then --если диск с файлом существует, а файл нет значит нужно удалять запись. если нет самого диска значит возможно просто кто-то выташил сьемный наситель и запись удалять не нужно
						removePath(tbl, path)
						needSave = true
					end
				end
				return needSave
			end

			local needSave = false
			if registry.autorun.system then
				needSave = doAutorun(registry.autorun.system)
			end
			if registry.autorun.user then
				if doAutorun(registry.autorun.user) then
					needSave = true
				end
			end
			if needSave then
				registry.save()
			end
		end
		autorun.autorun = nil
		cache.static[1] = true
	end
end

function autorun.check()
	if registry.autorun then
		local function doCheck(tbl)
			local needSave = false
			for i = #tbl, 1, -1 do
				local path, enable, disk = table.unpack(tbl[i])
				if not fs.exists(path) and component.isConnected(disk) then
					removePath(tbl, path)
					needSave = true
				end
			end
			return needSave
		end

		local needSave = false
		if registry.autorun.system then
			needSave = doCheck(registry.autorun.system)
		end
		if registry.autorun.user then
			if doCheck(registry.autorun.user) then
				needSave = true
			end
		end
		if needSave then
			registry.save()
		end
	end
end

function autorun.reg(group, path, rm, enable)
	if not groudList[group] then return end
	if not registry.data.autorun then registry.data.autorun = {} end
	if not registry.data.autorun[group] then registry.data.autorun[group] = {} end
	if enable == nil then enable = true end
	
	removePath(registry.data.autorun[group], path)
	if not rm then
		table.insert(registry.data.autorun[group], {path, enable, fs.get(path).address})
	end
	registry.save()
end

function autorun.list(group)
	if registry.data.autorun and registry.data.autorun[group] then
		return table.deepclone(registry.data.autorun[group])
	end
	return {}
end

autorun.unloadable = true
return autorun