local graphic = require("graphic")
local computer = require("computer")
local event = require("event")
local unicode = require("unicode")
local gui_container = require("gui_container")
local fs = require("filesystem")
local paths = require("paths")
local component = require("component")
local registry = require("registry")
local thread = require("thread")
local gui = require("gui")
local lastinfo = require("lastinfo")
local system = require("system")
local liked = require("liked")
local screensaver = require("screensaver")
local image = require("image")
local palette = require("palette")
local apps = require("apps")
local account = require("account")
local cache = require("cache")
local sysinit = require("sysinit")

------------------------------------------------------------------------ init

local screen = ...
local colors = gui_container.colors

local listens = {}
local function desktopUnload()
	for i, v in ipairs(listens) do
		event.cancel(v)
	end
end

gui_container.desktopData = gui_container.desktopData or {}
gui_container.desktopData[screen] = gui_container.desktopData[screen] or {}
local desktopData = gui_container.desktopData[screen]

local rx, ry = graphic.getResolution(screen)

local statusWindow = graphic.createWindow(screen, 1, 1, rx, 1)
local window = graphic.createWindow(screen, 1, 2, rx, ry - 1)

------------------------------------------------------------------------ paths

local iconsPath = gui_container.defaultUserRoot
local userPath = desktopData[1] or gui_container.getUserRoot(screen)

local iconAliases = {
}
local userPaths = {
	"/system/apps",
	"/vendor/apps",
	"/data/apps",
}

fs.makeDirectory(userPath)

------------------------------------------------------------------------ service

local function isFileExps()
	return not not gui_container.viewFileExps[screen]
end

local redrawFlag = true

local copyObject
local isCut = false

local wallpaperPath = "/data/wallpaper.t2p"

------------------------------------------------------------------------ icons

local iconmode = 0
-- 0 - all
-- 1 - apps
-- 2 - files
-- 3 - disks

local iconsX = 3
local iconsY = 2
if rx == 160 and ry == 50 then
	iconsX = 9
	iconsY = 7
elseif rx == 80 and ry == 25 then
	iconsX = 5
	iconsY = 3
end

local iconSizeX = 8
local iconSizeY = 4

local startIconsPoss = desktopData[2] or {} --тут храниться страница выбраная на конкретном пути
desktopData[2] = startIconsPoss
--local selectedIcons = {}
local icons

local function checkData()
	if not startIconsPoss[paths.canonical(userPath)] then
		startIconsPoss[paths.canonical(userPath)] = 1
	end
end

local imgexps = {"t1p", "t2p", "t3p"}
local function isImage(exp)
	return table.exists(imgexps, exp)
end

------------------------------------------------------------------------ draw

local contextMenuOpen = nil

local function getBarsColor(baseColor, toColor)
	if liked.getBaseWallpaperColor() == (baseColor or colors.gray) then
		return toColor or colors.black
	end
	return baseColor or colors.gray
end

local function drawStatus()
	if screensaver.current(screen) then return end

	--[[
	local timeZone = registry.timeZone or 0
	
	local hours, minutes, seconds = getRealTime(timeZone)
	hours = tostring(hours)
	minutes = tostring(minutes)
	if #hours == 1 then hours = "0" .. hours end
	if #minutes == 1 then minutes = "0" .. minutes end

	local gameHours, gameMinutes = getGameTime()
	gameHours = tostring(gameHours)
	gameMinutes = tostring(gameMinutes)
	if #gameHours == 1 then gameHours = "0" .. gameHours end
	if #gameMinutes == 1 then gameMinutes = "0" .. gameMinutes end

	local str = "real time: " .. hours .. ":" .. minutes .. "   game time: " .. gameHours .. ":" .. gameMinutes .. "   " .. tostring(system.getCharge()) .. "%"

	statusWindow:fill(1, 1, rx, 1, colors.gray, 0, " ")
	statusWindow:set(window.sizeX - unicode.len(str), 1, colors.gray, colors.white, str)
	]]

	liked.drawUpBar(screen, nil, getBarsColor(), nil, true)
	statusWindow:set(1, 1, contextMenuOpen == 1 and colors.blue or colors.lightGray, colors.white, " OS ")
	statusWindow:set(6, 1, contextMenuOpen == 2 and colors.blue or colors.lightGray, colors.white, " FILES ")
	statusWindow:set(14, 1, contextMenuOpen == 3 and colors.blue or colors.lightGray, colors.white, " TYPES ")
	liked.upBarShadow(screen)
end

local function drawWallpaper()
	liked.drawWallpaper(screen, userPath)
end

local function drawBar(lUserPath, iconsCount)
	local curentPath = gui_container.toUserPath(screen, userPath)

	local currentPage = math.floor(startIconsPoss[lUserPath] // (iconsX * iconsY)) + 1
	local pageCount = math.floor((iconsCount - 1) // (iconsX * iconsY)) + 1

	if currentPage < 1 then currentPage = 1 end
	if pageCount < 1 then pageCount = 1 end

	--[[
	window:fill(1, window.sizeY - 1, rx, 1, colors.gray, 0, " ")
	if copyObject then
		window:set(2, window.sizeY - 1, colors.gray, colors.white, (isCut and "cutted: " or "copied: ") .. gui_container.short(copyObject, window.sizeX - 2))
	end
	]]

	local col = getBarsColor()
	window:fill(1, window.sizeY, rx, 1, col, 0, " ")
	window:set(16, window.sizeY, col, colors.white, "path: " .. gui_container.short(curentPath, window.sizeX - 35))
	window:set(window.sizeX - 10, window.sizeY, col, colors.white, tostring(currentPage))
	window:set(window.sizeX - 8, window.sizeY, col, colors.white, "/")
	window:set(window.sizeX - 6, window.sizeY, col, colors.white, tostring(pageCount))

	--window:set(1, window.sizeY - 3, colors.lightGray, colors.white, " /")
	--window:set(1, window.sizeY - 2, colors.lightGray, colors.white, "/ ")
	--window:set(1, window.sizeY - 1, colors.lightGray, colors.white, "\\ ")
	--window:set(1, window.sizeY - 0, colors.lightGray, colors.white, " \\")

	--window:set(3, window.sizeY - 3, colors.red, colors.white, " /")
	--window:set(3, window.sizeY - 2, colors.red, colors.white, "/ ")
	--window:set(3, window.sizeY - 1, colors.red, colors.white, "\\ ")
	--window:set(3, window.sizeY - 0, colors.red, colors.white, " \\")
	window:set(1, window.sizeY, colors.red, colors.white, " << ")

	--window:set(window.sizeX - 3, window.sizeY - 3, colors.blue, colors.white, "RE")
	--window:set(window.sizeX - 3, window.sizeY - 2, colors.blue, colors.white, "FR")
	--window:set(window.sizeX - 3, window.sizeY - 1, colors.blue, colors.white, "ES")
	--window:set(window.sizeX - 3, window.sizeY - 0, colors.blue, colors.white, "H ")
	window:set(6, window.sizeY, colors.blue, colors.white, " @@ ")
	window:set(11, window.sizeY, colors.green, colors.white, "HOME")

	--window:set(window.sizeX - 1, window.sizeY - 3, colors.lightGray, colors.white, "\\ ")
	--window:set(window.sizeX - 1, window.sizeY - 2, colors.lightGray, colors.white, " \\")
	--window:set(window.sizeX - 1, window.sizeY - 1, colors.lightGray, colors.white, " /")
	--window:set(window.sizeX - 1, window.sizeY - 0, colors.lightGray, colors.white, "/ ")

	window:set(window.sizeX - 3, window.sizeY, colors.lightGray, colors.white, "<-")
	window:set(window.sizeX - 1, window.sizeY, colors.lightGray, colors.white, "->")
end

local function draw(old, check) --вызывает все перерисовки
	gui.scrShadow[screen] = nil

	checkData()
	if not fs.exists(userPath) or not fs.isDirectory(userPath) then
		userPath = gui_container.defaultUserRoot
		desktopData[1] = userPath
	end

	local tbl = fs.list(userPath)
	if not tbl then
		userPath = gui_container.getUserRoot(screen)
		desktopData[1] = userPath
		return draw()
	end

	local lUserPath = paths.canonical(userPath)
	if check and startIconsPoss[lUserPath] == (old or 1) then
		return
	end

	--gui.status(screen, nil, nil, "loading file-list...")

	icons = {}

	local count = 0

	local function checkIcon(v, customPath)
		local path
		if customPath then
			path = customPath
		else
			path = paths.concat(userPath, v)
		end

		local fsProxy, localFsPath = fs.get(path)
		local isFs = paths.equals(localFsPath, "/")

		if gui.isVisible(screen, path) then
			if iconmode == 0 or not paths.equals(userPath, gui_container.defaultUserRoot) then
				return true
			elseif iconmode == 3 then
				if isFs then
					return true
				end
			elseif iconmode == 2 then
				if not customPath and not isFs then
					return true
				end
			elseif iconmode == 1 then
				if customPath then
					return true
				end
			end
		end
	end

	local function addIcon(i, v, customPath)
		count = count + 1
		if count > (iconsX * iconsY) then
			return true
		end
		
		local path
		if customPath then
			path = customPath
		else
			path = paths.concat(userPath, v)
		end

		local exp = paths.extension(path)
		local fsProxy, localFsPath = fs.get(path)
		local isFs = paths.equals(localFsPath, "/")

		local shortName, fullName = liked.getName(screen, path, not not customPath)
		local icon = liked.getIcon(screen, path)

		local icondata = {
			shortName = shortName,
			fs = fsProxy,
			readonly = fs.isReadOnly(path),
			icon = icon,
			path = path,
			exp = exp,
			index = i,
			name = fullName,
			isAlias = not not customPath,
			isDir = fs.isDirectory(path),
			hidden = fs.getAttribute(path, "hidden")
		}

		if isFs then
			icondata.isFs = isFs
			icondata.labelReadonly = fs.isLabelReadOnly(path)
		end

		table.insert(icons, icondata)
	end

	local tbl = {}

	if paths.canonical(userPath) == paths.canonical(iconsPath) then
		for i, v in ipairs(iconAliases) do
			if fs.exists(v) and checkIcon(nil, v) then
				table.insert(tbl, {nil, v})
			end
		end
		for i, path in ipairs(userPaths) do
			for i, file in ipairs(fs.list(path) or {}) do
				local v = paths.concat(path, file)
				if checkIcon(nil, v) then
					table.insert(tbl, {nil, v})
				end
			end
		end
	end

	for i, file in ipairs(fs.list(userPath)) do
		if checkIcon(file) then
			table.insert(tbl, {file})
		end
	end

	local iconsCount = #tbl

	if not startIconsPoss[lUserPath] or startIconsPoss[lUserPath] > iconsCount then
		startIconsPoss[lUserPath] = old or 1
	end

	for i, v in ipairs(tbl) do
		if i >= startIconsPoss[lUserPath] and i <= iconsCount then
			if addIcon(i, v[1], v[2]) then
				break
			end
		end
	end

	drawWallpaper()
	drawStatus()
	drawBar(lUserPath, iconsCount)
	local count = 0
	for cy = 1, iconsY do
		for cx = -(iconsX // 2), (iconsX // 2) do
			count = count + 1
			local centerIconX = math.floor(((window.sizeX / 2) + (cx * 16) + 1) + 0.5)
			local centerIconY = math.floor(((window.sizeY / (iconsY + 1)) * cy) + 0.5) - 1
			if ry <= 16 and centerIconY >= 5 then
				centerIconY = centerIconY + 1
			end
			local iconX = math.floor((centerIconX - (iconSizeX / 2)) + 0.5)
			local iconY = math.floor((centerIconY - (iconSizeY / 2)) + 0.5)
			local icon = icons[count]
			
			if icon then
				icon.iconX = iconX
				icon.iconY = iconY

				--if selectedIcons[userPath] == icon.index then
				--    window:fill(iconX - 2, iconY - 1, iconSizeX + 4, iconSizeY + 2, colors.blue, 0, " ")
				--end
				local baseColor = liked.getBaseWallpaperColor()
				local x, y = window:toRealPos(math.floor((centerIconX - (unicode.len(icon.shortName) / 2)) + 0.5), centerIconY + 2)
				gui.drawtext(screen, x, y, icon.hidden and getBarsColor(colors.lightGray, colors.gray) or (baseColor == colors.white and colors.black or colors.white), icon.shortName)
				--window:set(iconX - (unicode.len(icon.name) // 2), iconY + iconY - 2, colors.lightBlue, colors.white, icon.name)
				if icon.icon then
					local sx, sy = window:toRealPos(iconX, iconY)
					if baseColor ~= colors.lightBlue then
						pcall(image.draw, screen, icon.icon, sx, sy, true, nil, nil, nil, baseColor)
					else
						pcall(image.draw, screen, icon.icon, sx, sy, true)
					end
				end
			end
		end
	end
end

local function listForward()
	checkData()

	local lUserPath = paths.canonical(userPath)
	local old = startIconsPoss[lUserPath]
	startIconsPoss[lUserPath] = startIconsPoss[lUserPath] + (iconsX * iconsY)
	draw(old, true)
end

local function listBack()
	checkData()

	local lUserPath = paths.canonical(userPath)
	local old = startIconsPoss[lUserPath]
	startIconsPoss[lUserPath] = startIconsPoss[lUserPath] - (iconsX * iconsY)
	if startIconsPoss[lUserPath] < 1 then
		startIconsPoss[lUserPath] = 1
	end
	draw(old, true)
end

local function folderBack()
	local oldPath = userPath
	userPath = gui_container.checkPath(screen, paths.path(userPath))
	desktopData[1] = userPath
	if userPath ~= oldPath then
		draw()
	end
end

local timerEnable = true
table.insert(listens, event.timer(10, function()
	if not timerEnable then return end
	drawStatus()
end, math.huge))

local function warn(str)
	local clear = gui.saveZone(screen)
	gui.warn(screen, nil, nil, str or "unknown error")
	clear()
end

local function warnNoClear(str)
	gui.warn(screen, nil, nil, str or "unknown error")
end

local function simpleExecute(name, nickname, ...)
	liked.bigAssert(screen, apps.execute(name, screen, nickname, ...))
	graphic.setDepth(screen, graphic.maxDepth(screen))
	graphic.setResolution(screen, sysinit.getResolution(screen))
end

local function execute(name, nickname, ...)
	timerEnable = false
	--gui.status(screen, nil, nil, "loading...")
	simpleExecute(name, nickname, ...)
	draw()
	timerEnable = true
	redrawFlag = nil
end

local function fexecute(simple, ...)
	if simple then
		return simpleExecute(...)
	else
		return execute(...)
	end
end

local function uninstallApp(path, nickname)
	apps.uninstall(screen, nickname, path)
end

local function fileDescriptor(icon, alternative, nickname, simple) --открывает файл, сам решает через какую программу это сделать
	if alternative then
		if fs.isDirectory(icon.path) then
			userPath = icon.path
			desktopData[1] = userPath
			draw()
			return true
		elseif icon.exp == "lua" or icon.exp == "scrsv" then
			fexecute(simple, "edit", nickname, icon.path)
			return true
		end
	end

	if gui_container.openVia[icon.exp] then
		fexecute(simple, gui_container.openVia[icon.exp], nickname, icon.path)
	elseif icon.exp == "app" then
		if fs.isDirectory(icon.path) then
			fexecute(simple, paths.concat(icon.path, "main.lua"), nickname)
		else
			fexecute(simple, icon.path, nickname)
		end
		return true
	elseif fs.isDirectory(icon.path) then
		userPath = gui_container.checkPath(screen, icon.path)
		desktopData[1] = userPath
		draw()
		return true
	elseif isImage(icon.exp) then
		fexecute(simple, "paint", nickname, icon.path)
		return true
	elseif icon.exp == "lua" then
		fexecute(simple, icon.path, nickname)
		return true
	elseif icon.exp == "scrsv" then
		if liked.publicMode(screen) then
			timerEnable = false
			screensaver.waitStart(screen, icon.path)
			timerEnable = true
		end
	elseif icon.exp == "plt" then
		if liked.publicMode(screen) then
			local clear = saveZone(screen)
			local state = gui.yesno(screen, nil, nil, "apply this palette?")
			clear()

			if state then
				palette.setSystemPalette(icon.path)
				event.push("redrawDesktop")
			end
		end
	elseif icon.exp == "txt" or icon.exp == "log" or icon.exp == "cfg" or icon.exp == "dat" then
		fexecute(simple, "edit", nickname, icon.path, icon.exp == "log")
	else
		warn("file is not supported")
	end
end

local function openAsCurrent(icon, alternative, nickname)
	if alternative then
		if fs.isDirectory(icon.path) then
			return true
		elseif icon.exp == "lua" or icon.exp == "scrsv" then
			return false
		end
	end

	if gui_container.openVia[icon.exp] then
		return false
	elseif icon.exp == "app" then
		return false
	elseif fs.isDirectory(icon.path) then
		return true
	end

	return false
end

local function runFunc(func, ...)
	local ok, err = pcall(func, ...)
	if not ok then
		warn(err)
	end
end

local function getActions(icon, nickname, astrs, aactive, sep)
	local files, strs, actives = liked.getActions(icon.path)
	if #files > 0 then
		table.insert(astrs, true)
		table.insert(aactive, false)

		local funcs, count = {}, 1
		for i, file in ipairs(files) do
			table.insert(astrs, "  " .. strs[i])
			table.insert(aactive, not not actives[i])
			funcs[#astrs] = function ()
				execute(paths.xconcat(icon.path, file), nickname)
			end
			count = count + 1
		end
		return funcs, count
	end
end

local function failCheck(ok, err)
	if not ok then
		warn(err)
		return false
	end
	return true
end

local function loadLicense(icon)
	if not icon.isDir then return end

	local licensePath = paths.concat(icon.path, "LICENSE")
	if not fs.exists(licensePath) then licensePath = paths.concat(icon.path, "license") end
	if not fs.exists(licensePath) then licensePath = paths.concat(icon.path, "LICENSE.txt") end
	if not fs.exists(licensePath) then licensePath = paths.concat(icon.path, "license.txt") end
	if not fs.exists(licensePath) then licensePath = paths.concat(icon.path, "LICENSE.md") end
	if not fs.exists(licensePath) then licensePath = paths.concat(icon.path, "license.md") end
	if not fs.exists(licensePath) then licensePath = nil end
	return licensePath
end

local function doIcon(windowEventData)
	if windowEventData[1] == "touch" then
		if windowEventData[4] >= window.sizeY then
			if windowEventData[3] >= 1 and windowEventData[3] <= 4 then
				folderBack()
				return
			elseif windowEventData[3] <= window.sizeX and windowEventData[3] >= window.sizeX - 1 then
				listForward()
				return
			elseif windowEventData[3] <= window.sizeX - 2 and windowEventData[3] >= window.sizeX - 3 then
				listBack()
				return
			elseif windowEventData[3] >= 6 and windowEventData[3] <= 9 then
				cache.cache.getIcon = nil
				cache.cache.findIcon = nil
				draw()
				return
			elseif windowEventData[3] >= 11 and windowEventData[3] <= 14 then
				local root = gui_container.defaultUserRoot
				if windowEventData[5] == 1 then
					root = gui_container.getUserRoot(screen)
				end
				if not paths.equals(userPath, root) then
					userPath = root
					desktopData[1] = userPath
					draw()
				end
				return
			end
		end
		
		local iconCliked = false
		for i, v in ipairs(icons) do
			if windowEventData[3] >= v.iconX and windowEventData[3] < (v.iconX + iconSizeX) then
				if windowEventData[4] >= v.iconY and windowEventData[4] < (v.iconY + iconSizeY) then
					--selectedIcons[userPath] = v.index
					--draw()
					
					iconCliked = true
					if windowEventData[5] == 0 then
						--if v.isFs and gui_container.isDiskLocked(v.fs.address) and not gui_container.isDiskAccess(v.fs.address) then
						--    gui_container.getDiskAccess(screen, v.fs.address)
						--else
						if openAsCurrent(v, nil, windowEventData[6]) then
							fileDescriptor(v, nil, windowEventData[6])
						else
							return function ()
								fileDescriptor(v, nil, windowEventData[6], true)
							end
						end
						--end
					else
						if v.isFs then
							local strs, active =
							{"  open", "  create dump", "  flash os", "  flash archive", "  clone to", "  clone from", true, "  format", "  set label", "  clear label"},
							{true, true, not v.readonly, not v.readonly, true, not v.readonly, false, not v.readonly, not v.labelReadonly, not v.labelReadonly}

							table.insert(strs, true)
							table.insert(active, false)

							if v.fs.exists("/init.lua") then
								table.insert(strs, "  boot from this disk")
								table.insert(active, not registry.disableExternalBoot and not _restrictedLoader)
							end

							table.insert(strs, "  info")
							table.insert(active, true)

							table.insert(strs, "  unmount")
							table.insert(active, true)

							local ejectDrive
							for address in component.list("disk_drive", true) do
								local methods = component.methods(address)
								if methods.eject ~= nil and methods.media ~= nil then
									local media = component.invoke(address, "media")
									if media and media == v.fs.address then
										ejectDrive = address
										break
									end
								end
							end

							table.insert(strs, "  eject")
							table.insert(active, not not ejectDrive)

							local posX, posY = window:toRealPos(windowEventData[3], windowEventData[4])

							--posX, posY = findPos(posX, posY, 23, screenshotY, rx, ry)
							local posX, posY, sizeX, sizeY = gui.contextPos(screen, posX, posY, strs)
							local clear = screenshot(screen, posX, posY, sizeX + 2, sizeY + 1)
							local str, num = gui.context(screen, posX, posY,
							strs, active)
							clear()

							if str == "  open" then
								if openAsCurrent(v, nil, windowEventData[6]) then
									fileDescriptor(v, nil, windowEventData[6])
								else
									return function ()
										fileDescriptor(v, nil, windowEventData[6], true)
									end
								end
							elseif str == "  clone to" then
								require("hdd").clone(screen, v.fs)
								draw()
							elseif str == "  clone from" then
								require("hdd").clone(screen, v.fs, true)
								draw()
							elseif str == "  unmount" then
								fs.umount(v.path)
								draw()
							elseif str == "  info" then
								return function ()
									simpleExecute("diskinfo", windowEventData[6], v.fs.address)
								end
							elseif str == "  eject" then
								pcall(component.invoke, ejectDrive, "eject")
							elseif str == "  create dump" then
								local archiver = require("archiver")
								local clear = saveBigZone(screen)
								local targetPath = gui_filepicker(screen, nil, nil, nil, archiver.supported[1], true)
								
								if targetPath then
									clear()
									gui_status(screen, nil, nil, "creating dump...")
									local ok, err = archiver.pack(v.path, targetPath)
									if not ok then
										warn(err)
									end
								end
								draw()
							elseif str == "  flash os" then
								if require("installer").context(screen, posX, posY, v.fs) then
									draw()
								end
							elseif str == "  flash archive" then
								local archiver = require("archiver")
								local clear = saveBigZone(screen)
								local archivePath = gui_filepicker(screen, nil, nil, nil, archiver.supported[1])
								
								if archivePath then
									clear()
									if gui.yesno(screen, nil, nil, "are you sure you want to flash the \"" .. gui.hideExtension(screen, archivePath) .. "\" archive to the \"" .. v.name .. "\"?") then
										gui_status(screen, nil, nil, "archive flashing...")
										local ok, err = archiver.unpack(archivePath, v.path)
										if not ok then
											warn(err)
										end
									end
								end
								draw()
							elseif str == "  format" then
								local clear2 = saveZone(screen)
								local state = gui.pleaseType(screen, v.fs.address == fs.bootaddress and "FRMT_SYSROOT" or "FORMAT")
								
								if state then
									gui_status(screen, nil, nil, "formatting...")
									liked.assert(screen, v.fs.remove("/"))
									draw()
								else
									clear2()
								end
							--[[
							elseif str == "  make a disk" then
								local clear2 = saveZone(screen)
								local state = gui.yesno(screen, nil, nil, "wipe data?")
								
								if state then
									gui_status(screen, nil, nil, "wiping...")
									v.fs.remove("/data")
									draw()
								else
									clear2()
								end
							elseif str == "  erase data" then
								local clear2 = saveZone(screen)
								local state = gui.yesno(screen, nil, nil, "wipe data?")
								
								if state then
									gui_status(screen, nil, nil, "wiping...")
									v.fs.remove("/data")
									draw()
								else
									clear2()
								end
							]]
							elseif str == "  set label" then
								local label = ""
								local result = {pcall(v.fs.getLabel)}
								if result[1] then
									label = result[2] or ""
								end

								local clear2 = saveZone(screen)
								local newlabel = gui_input(screen, nil, nil, "new label", nil, nil, label)

								if newlabel then
									liked.umountAll()
									if not pcall(v.fs.setLabel, newlabel) then
										warn("invalid name")
									end
									liked.mountAll()
									draw()
								else
									clear2()
								end
							elseif str == "  clear label" then
								local clear2 = saveZone(screen)
								local state = gui.yesno(screen, nil, nil, "clear label on \"" .. (v.name or "disk") .. "\"?")

								if state then
									liked.umountAll()
									if not pcall(v.fs.setLabel, nil) and not pcall(v.fs.setLabel, "") then
										warn("invalid name")
									end
									liked.mountAll()
									draw()
								else
									clear2()
								end
							elseif str == "  boot from this disk" then
								if not registry.disableExternalBoot and not _restrictedLoader then
									fs.writeFile("/tmp/bootloader/bootaddr", v.fs.address)
									fs.writeFile("/tmp/bootloader/bootfile", "/init.lua")
									pcall(computer.shutdown, "fast")
								end
							end
						elseif v.isAlias then
							local screenshotY = 4
							local strs, active =
							{"  open", true, "  uninstall"},
							{true, false, liked.isUninstallAvailable(v.path)}

							local licensePath = loadLicense(v)
							if licensePath then
								table.insert(strs, 2, "  license")
								table.insert(active, 2, true)
								screenshotY = screenshotY + 1
							end

							local actions, count = getActions(v, windowEventData[6], strs, active, true)
							if count then
								screenshotY = screenshotY + count
							end

							local posX, posY = window:toRealPos(windowEventData[3], windowEventData[4])
							--posX, posY = findPos(posX, posY, 23, screenshotY, rx, ry)
							local posX, posY, sizeX, sizeY = gui.contextPos(screen, posX, posY, strs)
							local clear = screenshot(screen, posX, posY, sizeX + 2, sizeY + 1)
							local str, num = gui.context(screen, posX, posY, strs, active)
							clear()

							if str == "  open" then
								if openAsCurrent(v, nil, windowEventData[6]) then
									fileDescriptor(v, nil, windowEventData[6])
								else
									return function ()
										fileDescriptor(v, nil, windowEventData[6], true)
									end
								end
							elseif str == "  uninstall" then
								local clear = saveZone(screen)
								local ok = gui.yesno(screen, nil, nil, "uninstall \"" .. v.name .. "\"?")

								if ok then
									if not uninstallApp(v.path, windowEventData[6]) then
										draw()
									end
								else
									clear()
								end
							elseif str == "  license" then
								return function ()
									timerEnable = false
									require("viewer").license(screen, licensePath, nil, nil, nil, true)
									timerEnable = true
								end
							elseif actions and actions[num] then
								runFunc(actions[num])
							end
						else
							local strs, active =
							{"  open", true},
							{true, false}

							local licensePath = loadLicense(v)
							if licensePath then
								table.insert(strs, 2, "  license")
								table.insert(active, 2, true)
							end

							if v.exp == "app" then
								table.insert(strs, "  uninstall")
								table.insert(active, liked.isUninstallAvailable(v.path))
							end
							
							table.insert(strs, "  remove")
							table.insert(active, not v.readonly)

							table.insert(strs, "  rename")
							table.insert(active, not v.readonly)

							table.insert(strs, "  copy")
							table.insert(active, true)

							table.insert(strs, "  cut")
							table.insert(active, not v.readonly)

							table.insert(strs, "  info")
							table.insert(active, true)

							if v.isDir then
								table.insert(strs, "  pack to archive")
								table.insert(active, true)
							end

							local isLine
							local function addLine()
								if not isLine then
									table.insert(strs, true)
									table.insert(active, false)
									isLine = true
								end
							end
							
							if v.exp == "plt" and not v.isDir then
								addLine()

								table.insert(strs, "  set as palette")
								table.insert(active, true)
							elseif isImage(v.exp) and not v.isDir then
								addLine()

								table.insert(strs, "  set as wallpaper")
								table.insert(active, true)
							elseif v.exp == "scrsv" and not v.isDir then
								addLine()

								table.insert(strs, "  set as screensaver")
								table.insert(active, true)
							elseif v.exp == "app" then
								addLine()

								table.insert(active, true)
								if v.isDir then
									table.insert(strs, "  inside the package")
								elseif v.readonly then
									table.insert(strs, "  view")
								else
									table.insert(strs, "  edit")
								end
							end
							
							if gui_container.editable[v.exp] and not v.isDir then
								addLine()

								if v.readonly then
									table.insert(strs, "  view")
								else
									table.insert(strs, "  edit")
								end
								table.insert(active, true)
							elseif not v.isDir and not gui_container.knownExps[v.exp] then
								addLine()

								table.insert(strs, "  open is text editor")
								table.insert(active, true)
							end

							isLine = false
							for i, v2 in ipairs(gui_container.filesExps) do
								if (not v2[1] or v2[1] == v.exp) and (v2[5] == nil or v2[5] == v.isDir) then
									addLine()

									table.insert(strs, "  " .. v2[3])
									table.insert(active, v2[4])
								end
							end
							--[[
							if v.exp == "plt" and not v.isDir then
								addLine()

								table.insert(strs, "  set as palette")
								table.insert(active, true)

								screenshotY = screenshotY + 1
							end
							]]

							local actions = getActions(v, windowEventData[6], strs, active, true)

							local posX, posY = window:toRealPos(windowEventData[3], windowEventData[4])
							--posX, posY = findPos(posX, posY, 23, #strs + 1, rx, ry)
							local posX, posY, sizeX, sizeY = gui.contextPos(screen, posX, posY, strs)
							local clear = screenshot(screen, posX, posY, sizeX + 2, sizeY + 1)
							local str, num = gui.context(screen, posX, posY,
							strs, active)
							clear()

							if str == "  open" then
								if openAsCurrent(v, nil, windowEventData[6]) then
									fileDescriptor(v, nil, windowEventData[6])
								else
									return function ()
										fileDescriptor(v, nil, windowEventData[6], true)
									end
								end
							elseif str == "  info" then
								return function ()
									simpleExecute("fileinfo", windowEventData[6], v.path)
								end
							elseif str == "  pack to archive" then
								local clear = gui.saveBigZone(screen)
								local outPath = require("iowindows").savefile(screen, gui_container.archiveFormats)
								clear()

								if outPath then
									gui.status(screen, nil, nil, "packaging \"" .. gui.fpath(screen, v.path) .. "\" to \"" .. gui.fpath(screen, outPath) .. "\"")
									liked.assertNoClear(screen, require("archiver").pack(v.path, outPath))
									draw()
								end
							elseif str == "  remove" then
								local clear2 = saveZone(screen)
								local state = gui.yesno(screen, nil, nil, "remove \"" .. v.name .. "\"?")
								clear2()
								if state then
									gui.status(screen, nil, nil, "removing \"" .. v.name .. "\"...")
									liked.assert(screen, fs.remove(v.path))
									draw()
								end
							elseif str == "  uninstall" then
								local clear2 = saveZone(screen)
								local state = gui.yesno(screen, nil, nil, "uninstall \"" .. v.name .. "\"?")
								clear2()
								if state then
									if not uninstallApp(v.path, windowEventData[6]) then
										draw()
									end
								end
							elseif str == "  rename" then
								local clear2 = saveZone(screen)
								local fname = paths.name(v.path) or ""
								if not isFileExps() then
									fname = paths.hideExtension(fname)
								end
								local name = gui_input(screen, nil, nil, "new name", nil, nil, fname)
								clear2()

								if name then
									if #name ~= 0 and not name:find("%\\") and not name:find("%/") then
										--с показаными разширениями вы можете стереть разширения с файла, без этого разширения будет переноситься с старого имени
										if not isFileExps() and not name:find("%.") and v.exp and v.exp ~= "" then
											name = name .. "." .. v.exp
										end

										local path = paths.concat(userPath, name)
										if fs.exists(path) then
											warn("name exists")
										else
											gui.status(screen, nil, nil, "renaming...")
											fs.rename(v.path, path)
											draw()
										end
									else
										warn("invalid name")
									end
								end
							elseif str == "  copy" then
								copyObject = v.path
								isCut = false
							elseif str == "  cut" then
								copyObject = v.path
								isCut = true
							elseif str == "  set as wallpaper" then
								failCheck(fs.copy(v.path, wallpaperPath))
								event.push("redrawDesktop")
							elseif str == "  set as screensaver" then
								if liked.publicMode(screen) then
									failCheck(fs.copy(v.path, gui_container.screenSaverPath))
								end
							elseif str == "  set as palette" then
								if liked.publicMode(screen) then
									palette.setSystemPalette(v.path)
									event.push("redrawDesktop")
								end
							elseif str == "  inside the package" then
								fileDescriptor(v, true)
							elseif str == "  edit" or str == "  view" or str == "  open is text editor" then
								--execute("edit", windowEventData[6], v.path, str == "  open is text editor" and not isDev())
								return function ()
									simpleExecute("edit", windowEventData[6], v.path)
								end
							elseif str == "  license" then
								return function ()
									simpleExecute("edit", windowEventData[6], licensePath, true)
								end
							elseif actions and actions[num] then
								runFunc(actions[num])
							else
								for i, v2 in ipairs(gui_container.filesExps) do
									if "  " .. v2[3] == str then
										return function ()
											simpleExecute(v2[2], windowEventData[6], v.path .. (v2[6] or ""))
										end
									end
								end
							end
						end
					end
					break
				end
			end
		end
		--if not iconCliked and selectedIcons[userPath] then
			--selectedIcons[userPath] = nil
			--draw()
		--end
		if not iconCliked and windowEventData[5] == 1 then
			local posX, posY = window:toRealPos(windowEventData[3], windowEventData[4])

			if copyObject and not fs.exists(copyObject) then
				copyObject = nil
				isCut = false
			end

			local readonly = fs.isReadOnly(userPath)
			local strs = {"  paste", "  mount", "  download file", true, "  new directory", "  new text-file", "  new image"}
			local actives = {not not copyObject and not readonly, true, not not component.list("internet")() and not readonly,   false,   not readonly,   not readonly,   not readonly}

			local creaters = {}
			local creatersI = #strs + 1
			for _, obj in ipairs(gui_container.newCreate) do
				local name, exp, check, create = table.unpack(obj)
				if type(name) == "string" and type(exp) == "string" and type(check) == "function" and type(create) == "function" then
					table.insert(strs, "  new " .. obj[1])
					
					local allowCreate = false
					local result = {pcall(check, userPath)}
					if not result[1] then
						warn(result[2])
					else
						allowCreate = not not result[2]
					end

					table.insert(actives, allowCreate)

					creaters[creatersI] = {name, exp, create}
					creatersI = creatersI + 1
				end
			end

			local posX, posY, sizeX, sizeY = gui.contextPos(screen, posX, posY, strs)
			local clear = graphic.screenshot(screen, posX, posY, sizeX + 2, sizeY + 1)
			local str, num = gui.context(screen, posX, posY, strs, actives)
			clear()
			
			if str == "  new image" then --new image
				local clear = gui.saveZone(screen)
				local name = gui.input(screen, nil, nil, "image name")
				clear()

				if type(name) == "string" then
					local path = paths.concat(userPath, name .. ".t2p")
					if not fs.exists(path) then
						if #name == 0 or name:find("%.") or name:find("%/") or name:find("%\\") then
							warn("invalid name")
						else
							return function ()
								simpleExecute("paint", windowEventData[6], path)
							end
						end
					else
						warn("this name is occupied")
					end
				end
			elseif str == "  mount" then
				local clear = gui.saveBigZone(screen)
				local addr = gui.selectcomponent(screen, nil, nil, "filesystem")
				clear()
				
				if addr then
					local function doMount()
						local name = gui.input(screen, nil, nil, "mount name", nil, nil, paths.name(require("hdd").genName(addr)))
						if name and name ~= "" and not name:find("%\\") and not name:find("%/") then
							fs.mount(component.proxy(addr), paths.concat(userPath, name))
						end
					end

					if addr ~= fs.bootaddress then
						doMount()
					elseif registry.disableRootAccess then
						gui.warn(screen, nil, nil, "it is not possible to mount the root filesystem")
					elseif gui.pleaseType(screen, "MOUNTROOT", "mount root") then
						doMount()
					end
					draw()
				end
			elseif str == "  new directory" then --new directory
				local clear = gui.saveZone(screen)
				local name = gui.input(screen, nil, nil, "directory name")
				clear()

				if type(name) == "string" then
					local path = paths.concat(userPath, name)
					if not fs.exists(path) then
						if #name == 0 or name:find("%/") or name:find("%\\") then
							warn("invalid name")
						else
							liked.assertNoClear(screen, fs.makeDirectory(path))
							draw()
						end
					else
						warn("this name is occupied")
					end
				end
			elseif str == "  new text-file" then --new text-file
				local clear = saveZone(screen)
				local name = gui_input(screen, nil, nil, "text-file name")
				clear()

				if type(name) == "string" then
					local path = paths.concat(userPath, name .. (name:find("%.") and "" or ".txt"))
					if not fs.exists(path) then
						if #name == 0 or name:find("%/") or name:find("%\\") then
							warn("invalid name")
						else
							return function ()
								simpleExecute("edit", windowEventData[6], path)
							end
						end
					else
						warn("this name is occupied")
					end
				end
			elseif str == "  paste" then
				local copyFlag = true --произойдет ли копирования
				
				local toPath = paths.concat(userPath, paths.name(copyObject))
				local oneDir = paths.path(copyObject) == paths.path(toPath) --если копирования и вставка производиться из одной и той же директории

				if oneDir and fs.exists(toPath) then
					local name = paths.name(copyObject)
					local exp = paths.extension(name)
					if exp then
						name = paths.hideExtension(name)
					end

					for i = 1, math.huge do
						toPath = paths.concat(userPath, name .. "_" .. tostring(i) .. (exp and ("." .. exp) or ""))
						if not fs.exists(toPath) then break end
					end
				end
				
				local isDir = fs.isDirectory(copyObject)
				if fs.exists(toPath) then
					if isDir ~= fs.isDirectory(toPath) then
						warn("name is occupied")
						copyFlag = false
					else
						local clear = saveZone(screen)
						local replaseAllow = gui.yesno(screen, nil, nil, isDir and "merge directories?" or "overwrite the file?")
						if not replaseAllow then
							clear()
							copyFlag = false
						end
					end
				end

				if copyFlag then
					if paths.canonical(toPath) ~= paths.canonical(copyObject) then
						local tname = isDir and "directory" or "file"
						gui.status(screen, nil, nil, isCut and ("moving the " .. tname .. "...") or ("copying the " .. tname .. "..."))
						if isCut then
							failCheck(fs.rename(copyObject, toPath))
						else
							failCheck(fs.copy(copyObject, toPath))
						end
					end

					copyObject = nil
					isCut = false
					draw()
				end
			elseif str == "  download file" then
				local clear = gui.saveZone(screen)
				local url = gui.input(screen, nil, nil, "url")
				clear()

				if url and url ~= "" then
					local filename = url
					local index = string.find(filename, "/[^/]*$")
					if index then
						filename = string.sub(filename, index + 1)
					end
					index = string.find(filename, "?", 1, true)
					if index then
						filename = string.sub(filename, 1, index - 1)
					end

					filename = gui.input(screen, nil, nil, "file name", false, nil, filename)
					clear()

					if filename then
						if #filename == 0 or filename:find("%/") or filename:find("%\\") then
							warn("invalid name")
						else
							local path = paths.sconcat(userPath, filename)
							if path then
								local replaceAllow
								if fs.exists(path) then
									replaceAllow = gui.yesno(screen, nil, nil, "overwrite the file?")
									clear()
								end
								if not fs.exists(path) or replaceAllow then
									gui.status(screen, nil, nil, "downloading file...")
									local ok, err = require("internet").download(url, path)
									clear()

									if ok then
										clear = nil
										draw()
									else
										warn("download error: " .. (err or "unknown error"))
									end
								end
							else
								warn("invalid name")
							end
						end
					end
				end
				if clear then
					clear()
				end
			elseif creaters[num] then
				local clear = saveZone(screen)
				local name = gui.input(screen, nil, nil, creaters[num][1] .. " name")
				clear()

				if type(name) == "string" then
					local path = paths.concat(userPath, name .. (name:find("%.") and "" or ("." .. creaters[num][2])))
					if not fs.exists(path) then
						if #name == 0 or name:find("%/") or name:find("%\\") then
							warn("invalid name")
						else
							gui_status(screen, nil, nil, "creating a " .. creaters[num][1] .. "...")
							local result = {pcall(creaters[num][3], path)}
							if not result[1] then
								warnNoClear(result[2])
							else
								if not result[2] then
									warnNoClear(result[3])
								end
							end
							draw()
						end
					else
						warn("this name is occupied")
					end
				end
			end
		end
	end
end

------------------------------------------------------------------------ desktop

table.insert(listens, event.listen("redrawDesktop", function()
	redrawFlag = true
end))

local lastCheckTime
local lolzLock
local altLolzLock
local accountCheckTimeout = 25 + math.random(-5, 5)

table.insert(listens, event.listen("lolzLock", function ()
	if not lolzLock then
		altLolzLock = true
	end
end))

table.insert(listens, event.listen("noLolzLock", function ()
	lolzLock = nil
	altLolzLock = nil
end))

while true do
	if redrawFlag then --бля тут проблем, когда варнинги весят, не чекаеться на залоченость по аку
		redrawFlag = false
		draw()
		if not desktopData[3] then
			local clear = gui.saveZone(screen)
			for _, str in ipairs(require("warnings").list(screen)) do
				gui.warn(screen, nil, nil, str)
			end
			clear()

			desktopData[3] = true
		end
	end

	local eventData = {event.pull(0.5)}
	local windowEventData = window:uploadEvent(eventData)
	local statusWindowEventData = statusWindow:uploadEvent(eventData)
	if statusWindowEventData[1] == "touch" then
		if statusWindowEventData[4] == 1 and statusWindowEventData[3] >= 1 and statusWindowEventData[3] <= 4 then
			contextMenuOpen = 1
			drawStatus()
			local clear = graphic.screenshot(screen, 2, 2, 28, 7 + 4)
			local str, num = gui.context(screen, 2, 2,
			{"  lock screen", true, "  about", "  settings", "  market", true, "  shutdown", "  reboot"},
			{not not registry.password, false, true, true, true, false, not not computer.shutdown, not not computer.shutdown})
			contextMenuOpen = nil

			if str == "  about" then
				desktopUnload()
				return function()
					simpleExecute("about", statusWindowEventData[6])
				end
			elseif str == "  settings" then
				desktopUnload()
				return function()
					simpleExecute("settings", statusWindowEventData[6])
				end
			elseif str == "  market" then
				desktopUnload()
				return function()
					simpleExecute("market", statusWindowEventData[6])
				end
			elseif str == "  lock screen" then
				clear()
				drawStatus()
				execute("login")
			elseif str == "  shutdown" then
				computer.shutdown()
			elseif str == "  reboot" then
				computer.shutdown(true)
			else
				clear()
			end
			
			drawStatus()
		elseif statusWindowEventData[4] == 1 and statusWindowEventData[3] >= 6 and statusWindowEventData[3] <= 12 then
			contextMenuOpen = 2
			drawStatus()
			local str, num = gui.contextAuto(screen, 7, 2,
			{gui_container.viewFileExps[screen] and "  hide file extensions  " or "  show file extensions  ", gui_container.userRoot[screen] and "  hide root directory" or "  show root directory", gui_container.hiddenFiles[screen] and "  hide hidden files" or "  show hidden files"},
			{not registry.disableFileExps, not registry.disableRootAccess, not registry.disableHiddenFiles})
			contextMenuOpen = nil

			if num == 1 then
				gui_container.viewFileExps[screen] = not gui_container.viewFileExps[screen]
				draw()
			elseif num == 2 then
				if gui_container.userRoot[screen] then
					gui_container.userRoot[screen] = nil
				else
					gui_container.userRoot[screen] = "/"
				end
				userPath = gui_container.checkPath(screen, userPath)
				desktopData[1] = userPath
				draw()
			elseif num == 3 then
				gui_container.hiddenFiles[screen] = not gui_container.hiddenFiles[screen]
				draw()
			end
			
			drawStatus()
		elseif statusWindowEventData[4] == 1 and statusWindowEventData[3] >= 14 and statusWindowEventData[3] <= 20 then
			contextMenuOpen = 3
			drawStatus()
			local actives = {true, true, true, true}
			if iconmode then
				actives[iconmode + 1] = false
			end
			local str, num = gui.contextAuto(screen, 15, 2, {"All", "Applications", "Files", "Disks"}, actives)
			contextMenuOpen = nil
			if num then
				iconmode = num - 1
				draw()
			else
				drawStatus()
			end
		end
	end

	local ret = doIcon(windowEventData)
	if ret then
		desktopUnload()
		return ret
	end

	if eventData[1] == "key_down" then
		local ok
		for i, v in ipairs(lastinfo.keyboards[screen]) do
			if eventData[2] == v then
				ok = true
			end
		end
		if ok then
			if eventData[4] == 208 then
				folderBack()
			elseif eventData[4] == 203 then
				listBack()
			elseif eventData[4] == 205 then
				listForward()
			end
		end
	end

	if altLolzLock then
		timerEnable = false
		assert(apps.execute("/system/bin/setup.app/stub.lua", screen))
		while altLolzLock do
			event.yield()
		end
		timerEnable = true
		draw()
	elseif lolzLock then
		event.push("lolzLock")
		timerEnable = false
		account.loginWindow(screen)
		timerEnable = true
		draw()
		lolzLock = false
		event.push("noLolzLock")
	elseif component.isPrimary(screen) and (not lastCheckTime or computer.uptime() - lastCheckTime > accountCheckTimeout) then
		lastCheckTime = computer.uptime()
		accountCheckTimeout = 25 + math.random(-5, 5)
		
		thread.create(function ()
			if account.isLoginWindowNeed(screen) then
				lolzLock = true
			end
		end):resume()
	end
end