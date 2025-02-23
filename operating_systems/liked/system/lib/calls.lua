--ЛЮТАЯ ЛЕГАСИ ДИЧ, раньше была в ядре но я ее от туда еле как выкарчивал. надеюсь скоро смогу выпелить полностью

local fs = require("filesystem")
local unicode = require("unicode")
local paths = require("paths")
local bootloader = require("bootloader")

------------------------------------

local calls = {} --calls позваляет вызывать функции с жеского диска, что экономит оперативную память
calls.paths = {"/data/calls", "/vendor/calls", "/system/calls", "/system/core/calls"} --позиция по мере снижения приоритета(первый элемент это самый высокий приоритет)
calls.loaded = { --тут записаны функции которые раньше были hdd функциями, но стали перемешены в библиотеки
	map = math.map,
	constrain = math.clamp,

	deepclone = table.deepclone,

	getPath = function ()
		return require("system").getSelfScriptPath()
	end,
	getDeviceType = function ()
		return require("system").getDeviceType()
	end,

	getFile = fs.readFile,
	saveFile = fs.writeFile,

	serialization = function (...)
		return require("serialization").serialize(...)
	end,
	unserialization = function (...)
		return require("serialization").unserialize(...)
	end,

	uuid = function ()
		return require("uuid").next()
	end,
	sha256 = function (msg)
		return require("sha256").sha256(msg)
	end,

	getInternetFile = function (url)
		return require("internet").getInternetFile(url)
	end,

	createEnv = bootloader.createEnv,
	writebit = bit32.writebit,
	readbit = bit32.readbit,

	getGameTime = function ()
		local time = require("time")
		local gametime = time.getGameTime()
		return time.parseHours(gametime), time.parseMinute(gametime), time.parseSecond(gametime)
	end,
	getRawRealtime = function ()
		return require("time").getRealTime()
	end,
	getRealTime = function (timezone)
		local time = require("time")
		local realtime = time.addTimeZone(time.getRealTime(), timezone or 0)
		return time.parseHours(realtime), time.parseMinute(realtime), time.parseSecond(realtime)
	end,

	split = function (str, sep)
		return require("parser").split(string, str, sep)
	end,
	split2 = function (tool, str, seps)
		return require("parser").split(tool, str, seps)
	end,
	toParts = function (str, max)
		return require("parser").toParts(string, str, max)
	end,
	toPartsUnicode = function (str, max)
		return require("parser").toParts(unicode, str, max)
	end,

	isLikeOsDisk = function (address)
		return require("system").isLikeOSDisk(address)
	end,

	screenshot = function (screen, x, y, sx, sy)
		return require("graphic").screenshot(screen, x, y, sx, sy)
	end,

	gui_filepicker = function (screen, cx, cy, dir, exp, save, dirmode, dircombine, defname)
		local iowindows = require("iowindows")
		if dirmode then
			if save then
				return iowindows.savefolder(screen, exp)
			else
				return iowindows.selectfolder(screen, exp)
			end
		else
			if save then
				return iowindows.savefile(screen, exp)
			else
				return iowindows.selectfile(screen, exp)
			end
		end
	end
} --вы можете записать сюда функции которые не должны выгружаться
calls.cache = {}

function calls.find(name)
	if unicode.sub(name, 1, 1) == "/" then
		return name
	else
		for i, v in ipairs(calls.paths) do
			local path = paths.concat(v, name .. ".lua")
			if fs.exists(path) then
				return path
			end
		end
	end
end

function calls.load(name)
	if calls.loaded[name] or calls.cache[name] then
		local lib = calls.loaded[name] or calls.cache[name]
		if lib then
			if lib == true then
				return
			end
			return lib
		end
	end

	local path = calls.find(name)
	if not path then
		calls.cache[name] = true
		return nil, "no such call"
	end

	local file, err = fs.open(path, "rb")
	if not file then return nil, err end
	local data = file.readAll()
	file.close()

	local code, err = load(data, "=" .. path, nil, _G) --не _ENV потому что там "личьные" глобалы в _G то что нужно системным вызовам
	if not code then return nil, err end

	calls.cache[name] = code
	return code
end

function calls.call(name, ...)
	local code = calls.load(name)
	if not code then
		error("call \"" .. name .. "\" not found", 2)
	end
	return code(...)
end

setmetatable(_G, {__index = function(self, key)
	return calls.load(key)
end})

return calls