local fs = require("filesystem")
local bootloader = require("bootloader")
local computer = require("computer")
local component = require("component")
local programs = require("programs")
local gui = require("gui")
local paths = require("paths")
local registry = require("registry")
local graphic = require("graphic")
local time = require("time")
local system = require("system")
local serialization = require("serialization")
local gui_container = require("gui_container")
local event = require("event")
local unicode = require("unicode")
local thread = require("thread")
local cache = require("cache")
local natives = require("natives")
local colorlib = require("colors")
local palette = require("palette")
local package = require("package")
local screensaver = require("screensaver")
local image = require("image")
local logs = require("logs")
local sysinit = require("sysinit")
local lastinfo = require("lastinfo")
local vcomponent = require("vcomponent")
local liked = {recoveryMode = bootloader.recoveryMode, colors = gui_container.colors}

local colors = gui_container.colors

--------------------------------------------------------

function liked.isLikedDisk(address)
	local signature = "--liked"

	local file = component.invoke(address, "open", "/system/main.lua", "rb")
	if file then
		local data = component.invoke(address, "read", file, #signature)
		component.invoke(address, "close", file)
		return signature == data
	end

	return false
end

function liked.isUserdata(path)
	local data = "/data/userdata/"
	return path:sub(1, #data) == data
end
	
function liked.wait(screen)
	while true do
		local eventData = {event.pull()}
		if eventData[1] == "close" and eventData[2] == screen then
			break
		elseif eventData[1] == "key_down" and table.exists(lastinfo.keyboards[screen], eventData[2]) and eventData[3] == 13 and eventData[4] == 28 then
			break
		end
	end
end

function liked.isUninstallScript(path)
	return fs.exists(paths.concat(path, "uninstall.lua"))
end

function liked.isUninstallAvailable(path)
	if fs.isReadOnly(path) then return false end

	local data = "/data/"
	local vendor = "/vendor/"
	if path:sub(1, #data) == data then --вы всегда можете удалить приложения из data
		return true
	elseif path:sub(1, #vendor) == vendor then --вы можете удалить приложения вендора только если в нем есть uninstall.lua
		return liked.isUninstallScript(path)
	end
	return false
end

function liked.isExecuteAvailable(path)
	if not registry.disableCustomPrograms then return true end
	return not liked.isUserdata(path)
end

--------------------------------------------------------

function liked.publicMode(screen, path)
	if registry.disableCustomFiles then
		if not path or liked.isUserdata(path) then
			local clear = saveZone(screen)
			gui.warn(screen, nil, nil, "this file cannot be used on your liked edition")
			clear()
			return false
		end
	end
	return true
end

function liked.getFileFromRepo(path, branch)
	if not branch then
		if package.isInstalled("sysdata") then
			branch = require("sysdata").get("branch")
		else
			branch = "main"
		end
	end
	if path:sub(1, 1) ~= "/" then
		path = "/" .. path
	end
	return require("internet").getInternetFile("https://raw.githubusercontent.com/igorkll/liked/" .. branch .. path)
end

function liked.lastVersion()
	local lastVersion, err = liked.getFileFromRepo("/system/version.cfg")
	if not lastVersion then return nil, err end
	return tonumber(lastVersion) or -1
end

function liked.version()
	return tonumber(assert(fs.readFile("/system/version.cfg")))
end

function liked.umountAll()
	local hdd = require("hdd")

	for address in component.list("filesystem") do
		if address ~= computer.tmpAddress() and address ~= fs.bootaddress then
			fs.umount(component.proxy(address))
		end
	end
end

function liked.mountAll()
	local hdd = require("hdd")

	for address in component.list("filesystem") do
		if address ~= computer.tmpAddress() and address ~= fs.bootaddress then
			fs.mount(address, hdd.genName(address))
		end
	end
end

--------------------------------------------------------

function liked.assert(screen, ...)
	local successful, err = ...
	if not successful then
		local clear = saveZone(screen)
		gui.warn(screen, nil, nil, err or "unknown error")
		clear()
	end
	return ...
end

function liked.bigAssert(screen, ...)
	local successful, err = ...
	if not successful then
		local clear = saveBigZone(screen)
		gui.bigWarn(screen, nil, nil, err or "unknown error")
		clear()
	end
	return ...
end

function liked.assertNoClear(screen, ...)
	local successful, err = ...
	if not successful then
		gui.warn(screen, nil, nil, err or "unknown error")
	end
	return ...
end

--------------------------------------------------------

function liked.applyReg(path, screen, regObj)
	regObj = regObj or registry
	if screen then
		if liked.assert(screen, regObj.apply(path)) then
			gui_container.refresh()
			regObj.save()
		end
	elseif regObj.apply(path) then
		gui_container.refresh()
		regObj.save()
	end
end

local bufferTimerId
function liked.applyBufferType()
	graphic.unloadBuffers()

	if liked.recoveryMode then
		graphic.allowSoftwareBuffer = false
		graphic.allowHardwareBuffer = false

		if bufferTimerId then
			event.cancel(bufferTimerId)
			bufferTimerId = nil
		end
	else
		graphic.allowSoftwareBuffer = registry.bufferType == "software"
		graphic.allowHardwareBuffer = registry.bufferType == "hardware"

		if graphic.allowHardwareBuffer or graphic.allowSoftwareBuffer then
			if not bufferTimerId then
				bufferTimerId = event.timer(0.1, function ()
					for address in component.list("screen") do
						graphic.update(address)
					end
				end, math.huge)
			end
		else
			if bufferTimerId then
				event.cancel(bufferTimerId)
				bufferTimerId = nil
			end
		end
	end
end

local energyTh
local wakeupEvents = {
	touch = true,
	drop = true,
	drag = true,
	scroll = true,
	key_down = true,
	key_up = true
}
function liked.applyPowerMode()
	if registry.powerMode == "power" then
		event.minTime = 0
		if energyTh then
			energyTh:kill()
			energyTh = nil
		end
	else
		event.minTime = 0.05
		if not energyTh then
			energyTh = thread.createBackground(function ()
				local oldWakeTIme = computer.uptime()
				while true do
					local eventData = {event.pull(1)}
					if eventData[1] and wakeupEvents[eventData[1]] then
						event.minTime = 0.05
						oldWakeTIme = computer.uptime()
					elseif computer.uptime() - oldWakeTIme > 10 then
						event.minTime = 4
					end
				end
			end)
			energyTh:resume()
		end
	end
end

function liked.noEnergySaver()
	if registry.powerMode == "power" then
		return function () end
	end

	energyTh:suspend()
	event.minTime = 0.05
	return function ()
		energyTh:resume()
	end
end

function liked.applyBeepState()
	if registry.fullBeepDisable then
		computer.beep = system.stub
	else
		computer.beep = natives.computer.beep
	end
end

function liked.applyTimeZone()
	logs.timeZone = registry.timeZone or 0
	if not gui_container.timeZoneHook then
		package.applyHook(function (libname, lib)
			if libname == "logs" then
				lib.timeZone = registry.timeZone or 0
			end
			return lib
		end)
		gui_container.timeZoneHook = true
	end
end

--------------------------------------------------------

local function raw_drawUpBarTask(method, screen, ...)
	local tbl = {...}
	local localBeforeCallback
	local function redraw(beforeCallback)
		localBeforeCallback = beforeCallback or localBeforeCallback
		if localBeforeCallback and localBeforeCallback ~= true then
			localBeforeCallback()
		end
		liked.drawUpBar(screen, table.unpack(tbl))
		graphic.updateFlag(screen)
	end
	local th = method(function ()
		while true do
			redraw()
			os.sleep(5)
		end
	end)
	th:resume()
	return th, redraw
end

function liked.upBarShadow(screen)
	if gui.scrShadow[screen] and gui.scrShadow[screen] > 0 then
		local rx = graphic.getResolution(screen)
		gui.shadow(screen, 1, 1, rx, 1, nil, true)
	end
end

function liked.drawUpBarTask(...)
	return raw_drawUpBarTask(require("thread").create, ...)
end

function liked.drawUpBarTaskBg(...)
	return raw_drawUpBarTask(require("thread").createBackground, ...)
end


function liked.drawUpBar(screen, withoutFill, bgcolor, guiOffset, noShadow)
	local rtc = "RTC-" .. time.formatTime(time.addTimeZone(time.getRealTime(), registry.timeZone or 0))
	local gtc = "GTC-" .. time.formatTime(time.getGameTime())
	local charge = system.getCharge()
	
	local gpu = graphic.findGpu(screen)
	local rx, ry = gpu.getResolution()
	gpu.setBackground(bgcolor or gui_container.colors.gray)
	gpu.setForeground(gui_container.colors.white)
	if not withoutFill then
		gpu.fill(1, 1, rx, 1, " ")
	end

	local battery = "⣏⣉⣉⡷"
	local batteryLen = unicode.len(battery)
	local offset = (batteryLen + 1) - (guiOffset or 0)

	gpu.set(rx - #rtc - 7 - offset, 1, rtc)
	gpu.set(rx - #gtc - 18 - offset, 1, gtc)
	if charge <= gui_container.criticalChargeLevel then
		gpu.setForeground(gui_container.colors.red)
	end
	local chargestr = tostring(charge)
	gpu.set(rx - 5 - offset, 1, "   ")
	gpu.set(rx - #chargestr - 2 - offset, 1, tostring(chargestr) .. "%")

	gpu.setBackground(bgcolor or gui_container.colors.gray)
	gpu.setForeground(gui_container.colors.white)

	for i = 1, batteryLen do
		local char = unicode.sub(battery, i, i)
		if i == batteryLen then
			gpu.setBackground(bgcolor or gui_container.colors.gray)
		else
			if charge <= gui_container.criticalChargeLevel then
				if i == 1 then
					gpu.setBackground(gui_container.colors.red)
				else
					gpu.setBackground(bgcolor or gui_container.colors.gray)
				end
			else
				local last = 3
				if charge <= 50 then
					last = 1
				elseif charge <= 75 then
					last = 2
				end

				if i <= last then
					gpu.setBackground(gui_container.colors.lime)
				else
					gpu.setBackground(bgcolor or gui_container.colors.gray)
				end
			end
		end
		gpu.set((rx - offset) + (i - 1), 1, char)
	end

	if not noShadow then
		liked.upBarShadow(screen)
	end

	graphic.updateFlag(screen)
end

--------------------------------------------------------

local function raw_drawFullUpBarTask(method, screen, title, withoutFill, bgcolor, wideExit)
	if wideExit == nil then wideExit = true end
	local callbacks = {}
	local localBeforeCallback
	local function redraw(beforeCallback)
		localBeforeCallback = beforeCallback or localBeforeCallback
		if localBeforeCallback and localBeforeCallback ~= true then
			localBeforeCallback()
		end
		liked.drawFullUpBar(screen, title, withoutFill, bgcolor, wideExit)
		if callbacks.draw then
			callbacks.draw()
		end
		graphic.updateFlag(screen)
	end
	local th = method(function ()
		thread.create(function ()
			local rx, ry = graphic.getResolution(screen)
			local window = graphic.createWindow(screen, 1, 1, rx, 1)
			while true do
				local eventData = {event.pull()}
				local windowEventData = window:uploadEvent(eventData)
				if windowEventData[1] == "touch" then
					if callbacks.exit then
						if wideExit then
							if windowEventData[3] >= rx - 2 then
								callbacks.exit()
							end
						else
							if windowEventData[3] == rx then
								callbacks.exit()
							end
						end
					end
				end
			end
		end):resume()

		while true do
			redraw()
			os.sleep(5)
		end
	end)
	th:resume()
	return th, redraw, callbacks
end

function liked.drawFullUpBarTask(...)
	return raw_drawFullUpBarTask(thread.create, ...)
end

function liked.drawFullUpBarTaskBg(...)
	return raw_drawFullUpBarTask(thread.createBackground, ...)
end

function liked.drawFullUpBar(screen, title, withoutFill, bgcolor, wideExit, noShadow)
	liked.drawUpBar(screen, withoutFill, bgcolor, wideExit and -2, true)
	local gpu = graphic.findGpu(screen)
	local rx, ry = gpu.getResolution()

	gpu.setForeground(gui_container.colors.white)
	if title then
		gpu.set(2, 1, title)
	end
	gpu.setBackground(gui_container.colors.red)
	if wideExit then
		gpu.set(rx - 2, 1, " X ")
	else
		gpu.set(rx, 1, "X")
	end

	if not noShadow then
		liked.upBarShadow(screen)
	end
end

--------------------------------------------------------

--[[
function liked.getRegistry(address)
	local mountpoint = os.tmpname()
	fs.mount(address or fs.get("/"), mountpoint)
	local regPath = paths.concat(mountpoint, "data/registry.dat")

	if fs.exists(regPath) or not fs.isDirectory(regPath) then
		local regData = fs.readFile(regPath)
		fs.umount(mountpoint)
		if regData then
			local ok, regTbl = pcall(serialization.unserialize, regData)
			if ok and type(regTbl) == "table" then
				return regTbl
			end
		end
	else
		fs.umount(mountpoint)
	end
end

function liked.labelReadonly(proxy)
	if type(proxy) == "string" then
		proxy = component.proxy(proxy)
	end
	return not pcall(proxy.setLabel, proxy.getLabel() or nil)
end

function liked.reg(str, key, value)
	gui_container[str][key] = value
	if not registry.gui_container then registry.gui_container = {} end
	if not registry.gui_container[str] then registry.gui_container[str] = {} end
	registry.gui_container[str][key] = value
	registry.save()
end
]]

function liked.getName(screen, path, isAlias)
	local name
	if not isAlias and gui_container.viewFileExps[screen] then
		name = paths.name(path)
	else
		name = paths.name(paths.hideExtension(path))
	end
	
	if unicode.len(name) > 12 then
		return unicode.sub(name, 1, 12) .. gui_container.chars.threeDots, name
	end
	return name, name
end

function liked.selfApplicationName()
	local scriptPath = system.getSelfScriptPath()
	local application = paths.path(scriptPath)
	if paths.extension(application) == "app" then
		application = scriptPath
	end
	return paths.hideExtension(paths.name(scriptPath))
end

function liked.applicationWindow(screen, title, bgcolor)
	local sx, sy = graphic.getResolution(screen)
	return graphic.createWindow(screen, 1, 2, sx, sy - 1), liked.drawFullUpBarTask(screen, title, bgcolor)
end

--------------------------------------------------------

function liked.getActions(path)
	local files, strs, actives = {}, {}, {}
	if fs.exists(path) and fs.isDirectory(path) then
		local actionPath = paths.concat(path, "actions.cfg") --раньше тут был lua файл, который выполнялся, но это слишком небезопастно

		if fs.exists(actionPath) and not fs.isDirectory(actionPath) then
			local content = fs.readFile(actionPath)
			if type(content) == "string" then
				local result = {pcall(serialization.unserialize, content)}
				event.yield() --предотващения краша при долгой десереализации

				if result and result[1] and type(result[2]) == "table" then
					for _, value in ipairs(result[2]) do
						if type(value) == "table" and type(value[1]) == "string" and type(value[3]) == "string" then
							local action = value[1]
							if unicode.len(action) < 24 then
								table.insert(files, paths.xconcat(path, value[3]))
								table.insert(strs, action)
								table.insert(actives, not not value[2])
								if #files >= 5 then --защита от приложений с большим количеством доп действий, так как это может использоваться для защиты от удаления
									break
								end
							end
						end
					end
				end
			end
		end
	end
	return files, strs, actives
end

function liked.findIcon(name)
	cache.cache.findIcon = cache.cache.findIcon or {}
	if cache.cache.findIcon[name] then
		return cache.cache.findIcon[name]
	end

	if registry.icons and registry.icons[name] then
		return registry.icons[name]
	end

	local path = bootloader.find(paths.concat("icons", name .. ".t2p"))
	cache.cache.findIcon[name] = path
	return path
end

function liked.getIcon(screen, path)
	cache.cache.getIcon = cache.cache.getIcon or {}
	if cache.cache.getIcon[path] then
		if not fs.exists(path) then
			cache.cache.getIcon[path] = nil
			return liked.findIcon("badicon")
		end
		return cache.cache.getIcon[path]
	end

	local exp = paths.extension(path)
	local isDir = fs.isDirectory(path)
	local icon
	
	if isDir then
		local fsProxy, fsLocalPath = fs.get(path)
		if fsLocalPath ~= "/" then
			fsProxy = nil
		end
		if fsProxy then
			local disklevel = system.getDiskLevel(fsProxy.address)
			if fsProxy.cloud then
				icon = liked.findIcon("cloud")
			elseif fsProxy.public then
				icon = liked.findIcon("publicStorage")
			elseif disklevel == "tmp" then
				icon = liked.findIcon("tmp")
			elseif disklevel == "fdd" then
				if fsProxy.exists("/init.lua") then
					icon = liked.findIcon("bootdevice")
				else
					icon = liked.findIcon("fdd")
				end
			elseif disklevel == "raid" then
				icon = liked.findIcon("raid")
			elseif disklevel == "tier1" then
				icon = liked.findIcon("hdd1")
			elseif disklevel == "tier2" then
				icon = liked.findIcon("hdd2")
			elseif disklevel == "tier3" then
				icon = liked.findIcon("hdd3")
			else
				icon = liked.findIcon("hdd")
			end
		end

		local iconpath = paths.concat(path, "icon.t2p")
		if fs.exists(iconpath) and not fs.isDirectory(iconpath) then
			icon = iconpath
		elseif not fsProxy then
			if exp == "app" then
				icon = liked.findIcon("app")
			else
				icon = liked.findIcon("folder")
			end
		end
	else
		if exp == "t2p" then
			if path then
				local ok, sx, sy = pcall(image.size, path)
				if ok and sx == 8 and sy == 4 then
					icon = path
				else
					icon = liked.findIcon("t2p")
				end
			else
				icon = liked.findIcon("t2p")
			end
		elseif exp and #exp > 0 then
			icon = liked.findIcon(exp)
			if not icon then
				icon = liked.findIcon("unknown")
			end
		else
			icon = liked.findIcon("file")
		end
	end

	if not icon or not fs.exists(icon) then
		icon = liked.findIcon("unknown")
	end

	local ok, sx, sy = pcall(image.size, icon)
	if not ok or sx ~= 8 or sy ~= 4 then
		icon = nil
	end

	if not icon or not fs.exists(icon) then
		icon = liked.findIcon("badicon")
	end

	cache.cache.getIcon[path] = icon
	return icon
end

function liked.getBaseWallpaperColor()
	local baseColor = colors.lightBlue
	if registry.wallpaperBaseColor then
		if type(registry.wallpaperBaseColor) == "string" then
			baseColor = colors[registry.wallpaperBaseColor]
		elseif type(registry.wallpaperBaseColor) == "number" then
			baseColor = registry.wallpaperBaseColor
		end
	end
	return baseColor
end

local function demoTitle(screen, gpu)
	if registry.demoMode then
		local rx, ry = gpu.getResolution()
		if liked.recoveryMode then
			gpu.set(2, ry - 3, "a demo version is likeOS")
			gpu.set(2, ry - 2, "some functions may be disabled")
		else
			gui.drawtext(screen, 2, ry - 3, liked.colors.white, "a demo version is likeOS")
			gui.drawtext(screen, 2, ry - 2, liked.colors.white, "some functions may be disabled")
		end
	end
end

function liked.drawWallpaper(screen, customFolder)
	local gpu = graphic.findGpu(screen)
	local rx, ry = gpu.getResolution()

	if liked.recoveryMode then
		gpu.setBackground(liked.colors.black)
		gpu.setForeground(liked.colors.white)
		gpu.fill(1, 1, rx, ry, " ")
		gpu.set(rx - 14, ry - 2, "Recovery mode")
		demoTitle(screen, gpu)
		return
	end

	local baseColor = liked.getBaseWallpaperColor()
	
	gpu.setBackground(colorlib.colorMul(baseColor, registry.wallpaperLight or 1))
	gpu.fill(1, 1, rx, ry, " ")

	local function wdraw(path)
		local ok, sx, sy = pcall(image.size, path)
		if ok then
			local ix, iy = math.round((rx / 2) - (sx / 2)) + 1, math.round((ry / 2) - (sy / 2)) + 1
			pcall(image.draw, screen, path, ix, iy, nil, nil, registry.wallpaperLight)
		end
	end

	local wallpaperPath = "/data/wallpaper.t2p"
	if fs.exists(wallpaperPath) then
		wdraw(wallpaperPath)
	end

	demoTitle(screen, gpu)

	--[[ обои для папок были отключены, потому что это не совмем безопастно и в теории позволит сделать папку в которую нельзя будет зайти
	local customPath = paths.concat(customFolder or paths.path(wallpaperPath), paths.name(wallpaperPath))
	if fs.exists(customPath) then
		wdraw(customPath)
	elseif fs.exists(wallpaperPath) then
		wdraw(wallpaperPath)
	end
	]]
end

function liked.minRamForDBuff()
	local kb = 512
	for _ in component.list("screen") do
		kb = kb + 512
	end
	return kb
end

function liked.isRealKeyboards(screen)
	for i, address in ipairs(lastinfo.keyboards[screen]) do
		if not vcomponent.isVirtual(address) then
			return true
		end
	end
	return false
end

-------------------------------------------------------- simple api

liked.regBar = liked.drawFullUpBarTask

function liked.regExit(screen, close, closeButton, enterAlias)
	local baseTh = thread.current()
	
	thread.listen("close", function (_, uuid)
		if uuid == screen then
			if close then
				close()
			else
				baseTh:kill()
			end
		end
	end)

	if enterAlias then
		thread.listen("key_down", function (_, uuid, code1, code2)
			if table.exists(lastinfo.keyboards[screen], uuid) and code1 == 13 and code2 == 28 then
				if close then
					close()
				else
					baseTh:kill()
				end
			end
		end)
	end

	if closeButton then
		thread.listen("touch", function (_, uuid, px, py)
			if uuid == screen then
				local rx, ry = graphic.getResolution(screen)
				if py == 1 and px >= rx - 2 then
					if close then
						close()
					else
						baseTh:kill()
					end
				end
			end
		end)
	end
end

--------------------------------------------------------

package.attachFunctionFolder(liked, "funcs")
liked.unloadable = true
return liked