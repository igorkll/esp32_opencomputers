local sysinit = {}
sysinit.screenThreads = {}
sysinit.initedScreens = {}
sysinit.defaultPalettePath = "/system/palettes/light.plt"

function sysinit.applyPalette(path, screen, doNotOffScreen)
	local fs = require("filesystem")
	local serialization = require("serialization")
	local component  = require("component")
	local graphic = require("graphic")
	local gui_container = require("gui_container")
	local registry = require("registry")

	local colors = assert(serialization.load(path))

	local function movetable(maintable, newtable)
		for k, v in pairs(maintable) do
			maintable[k] = nil
		end
		for k, v in pairs(newtable) do
			maintable[k] = v
		end
	end

	local t3default = colors.t3default
	colors.t3default = nil

	if registry.visionProtection then
		local colorlib = require("colors")
		local format = require("format")
		
		for i, v in ipairs(colors) do
			colors[i] = format.visionProtectionConvert(v)
		end
	end

	movetable(gui_container.indexsColors, colors)
	movetable(gui_container.colors, {
		white     = colors[1],
		orange    = colors[2],
		magenta   = colors[3],
		lightBlue = colors[4],
		yellow    = colors[5],
		lime      = colors[6],
		pink      = colors[7],
		gray      = colors[8],
		lightGray = colors[9],
		cyan      = colors[10],
		purple    = colors[11],
		blue      = colors[12],
		brown     = colors[13],
		green     = colors[14],
		red       = colors[15],
		black     = colors[16]
	})

	if screen ~= true then
		local blackWhile
		local function applyOnScreen(address)
			if graphic.maxDepth(address) ~= 1 then
				if not doNotOffScreen then pcall(component.invoke, address, "turnOff") end
				if t3default and graphic.getDepth(address) == 8 then
					graphic.fakePalette = table.low(colors)
					if not blackWhile then
						blackWhile = assert(serialization.load("/system/t3default.plt"))
					end
					graphic.setPalette(address, blackWhile)
				else
					graphic.fakePalette = nil
					graphic.setPalette(address, colors)
				end
				if not doNotOffScreen then pcall(component.invoke, address, "turnOn") end
			end
		end

		if screen then
			applyOnScreen(screen)
		else
			for address in component.list("screen") do
				applyOnScreen(address)
			end
		end
	end
end

function sysinit.getResolution(screen)
	local graphic = require("graphic")
	local mx, my = graphic.maxResolution(screen)
	if mx and (mx > 80 or my > 25) then
		mx = 80
		my = 25
	end
	return mx, my
end

function sysinit.generatePrimaryScreen()
	local lastinfo = require("lastinfo")
	local screen
	local screenValue

	local component = require("component")
	for address in component.list("screen", true) do
		local x, y = component.invoke(address, "getAspectRatio")
		local value = x * y
		if #lastinfo.keyboards[address] == 0 then
			value = 0
		end
		if not screenValue or value > screenValue then
			screen = address
			screenValue = value
		end
	end

	return screen
end

function sysinit.initScreen(screen)
	local graphic = require("graphic")
	local component = require("component")
	local event = require("event")
	local lastinfo = require("lastinfo")
	
	pcall(component.invoke, screen, "turnOff")
	if graphic.isAvailable(screen) then
		-- resolution & depth
		graphic.setDepth(screen, graphic.maxDepth(screen))
		graphic.setResolution(screen, sysinit.getResolution(screen))

		-- clear
		graphic.setPaletteColor(15, 0)
		graphic.clear(screen, 15, true)
		graphic.forceUpdate(screen)

		-- palette
		sysinit.applyPalette(sysinit.initPalPath, screen, true)

		-- show
		graphic.clear(screen, 0x000000)
		graphic.forceUpdate(screen)
		pcall(component.invoke, screen, "turnOn")
	end

	if not sysinit.initedScreens[screen] then
		event.listen("key_down", function(_, uuid, c1, c2, nickname)
			if not lastinfo.keyboards[screen] then
				sysinit.initedScreens[screen] = nil
				return false
			end

			if table.exists(lastinfo.keyboards[screen], uuid) and c1 == 23 and c2 == 17 then
				event.push("close", screen, nickname)
			end
		end)

		sysinit.initedScreens[screen] = true
	end
end

function sysinit.runShell(screen, customShell)
	local graphic = require("graphic")
	if not graphic.isAvailable(screen) then
		return
	end

	local thread = require("thread")
	local registry = require("registry")
	local apps = require("apps")
	local bootloader = require("bootloader")

	sysinit.initScreen(screen)
	if sysinit.screenThreads[screen] then
		sysinit.screenThreads[screen]:kill()
	end
	
	local shellName = "shell"
	if customShell then
		shellName = customShell
	elseif registry.data.shell and registry.data.shell[screen] then
		shellName = registry.data.shell[screen]
	end

	local env = bootloader.createEnv()
	env.shellMode = true
	local t = thread.create(assert(apps.load(shellName, screen, nil, env)))
	t.parentData.screen = screen
	t:resume() --поток по умалчанию спит

	sysinit.screenThreads[screen] = t
end

function sysinit.init(box, lscreen)
	local package = require("package")
	table.insert(package.paths, "/system/likedlib")
	package.hardAutoUnloading = true
	if package.isInstalled("sysmode") then
		require("sysmode").init()
	end

	local registry = require("registry")
	local fs = require("filesystem")
	local component = require("component")
	local computer = require("computer")
	local bootloader = require("bootloader")
	local sysdata = not box and require("sysdata")

	local targetEeprom = sysdata and sysdata.get("eeprom")
	if targetEeprom and component.list("eeprom")() ~= targetEeprom then
		bootloader.bootSplash("the liked was expecting an EEPROM: " .. targetEeprom:sub(1, 6))
		bootloader.waitEnter()
		computer.shutdown()
		return
	elseif registry.onlyInternalDisk and component.slot(fs.bootaddress) < 0 then
		bootloader.bootSplash("loading from external disk is disabled")
		bootloader.waitEnter()
		computer.shutdown()
		return
	elseif registry.noBootViaBootmanager and _G._bootmanager then
		bootloader.bootSplash("booting via bootmanager is disabled")
		bootloader.waitEnter()
		computer.shutdown()
		return
	end 

	if registry.noBootmanager then
		fs.remove("/bootmanager")
	end

	_G._OSVERSION = "liked-v" .. assert(fs.readFile("/system/version.cfg"))
	bootloader.runlevel = "user"
	require("calls") --подгрузка лютай легаси дичи

	if lscreen and bootloader.recoveryApi then
		bootloader.recoveryApi.offScreens()
	end

	local graphic = require("graphic")
	local programs = require("programs")
	table.insert(programs.paths, "/data/apps")
	table.insert(programs.paths, "/system/apps")
	table.insert(programs.paths, "/vendor/apps")

	------------------------------------

	if not lscreen then
		if not registry.primaryScreen or not component.isConnected(registry.primaryScreen) then
			registry.primaryScreen = sysinit.generatePrimaryScreen()
		end
		component.setPrimary("screen", registry.primaryScreen)
	end

	------------------------------------

	local screens = {}
	local minDepth = math.huge
	local maxDepth = 0
	local screensCount = 0
	local hardwareBufferAvailable = false
	for address in component.list("screen") do
		local gpu = graphic.findGpu(address)
		if gpu then
			if gpu.setActiveBuffer then
				hardwareBufferAvailable = true
				if gpu.getActiveBuffer() ~= 0 then
					gpu.setActiveBuffer(0)
				end
			end
			local depth = gpu.maxDepth()
			if gpu then
				table.insert(screens, address)
				maxDepth = math.max(maxDepth, depth)
				minDepth = math.min(minDepth, depth)
			end
			screensCount = screensCount + 1
		end
	end
	minDepth = math.round(minDepth)
	maxDepth = math.round(maxDepth)

	------------------------------------

	if box or lscreen then --likedbox or recovery mode
		if lscreen then
			sysinit.initPalPath = "/system/palettes/original.plt" --recovery mode
			sysinit.savePalPath = "/data/palette.plt"
		else
			sysinit.initPalPath = "/system/palette.plt" --likedbox
		end
		sysinit.applyPalette(sysinit.initPalPath, true)
	else
		sysinit.initPalPath = "/data/palette.plt"
		sysinit.savePalPath = "/data/palette.plt"

		if fs.exists(sysinit.initPalPath) then
			sysinit.applyPalette(sysinit.initPalPath, true)
		else
			local palette = require("palette")
			if minDepth == 1 then
				palette.setSystemPalette("/system/palettes/original.plt", true)
			else
				palette.setSystemPalette(sysinit.defaultPalettePath, true)
			end
		end
	end

	local gui_container = require("gui_container")
	local gui = require("gui") --нужно подключить заранию чтобы функции записались в calls.loaded
	local thread = require("thread")
	local liked = require("liked")
	local apps = require("apps")
	local event = require("event")
	local system = require("system")

	local devicetype = system.getDeviceType()
	local isTablet = devicetype == "tablet"
	
	------------------------------------

	if not box and not registry.wallpaperBaseColor then
		if minDepth == 1 then
			registry.wallpaperBaseColor = "black"
		else
			registry.wallpaperBaseColor = "lightBlue"
		end
	end

	------------------------------------

	if not registry.powerMode then
		if isTablet and not box then
			registry.powerMode = "energy saving"
		else
			registry.powerMode = "power"
		end
	end
	liked.applyPowerMode()

	------------------------------------

	local minDbuffRam = liked.minRamForDBuff() * 1024
	if not registry.bufferType then
		if not box and screensCount <= 2 and computer.totalMemory() >= minDbuffRam then
			registry.bufferType = "software"
		elseif not box and hardwareBufferAvailable then
			registry.bufferType = "hardware"
		else
			registry.bufferType = "none"
		end
	elseif registry.bufferType == "software" and computer.totalMemory() < minDbuffRam then
		registry.bufferType = "none"
	end
	liked.applyBufferType()

	------------------------------------

	if not box and not fs.exists(gui_container.screenSaverPath) and not registry.screenSaverDefaultSetted then
		if isTablet then
			pcall(fs.copy, registry.defaultScreenSaverPath or "/system/screenSavers/black_screen.scrsv", gui_container.screenSaverPath)
		else
			pcall(fs.copy, registry.defaultScreenSaverPath or "/system/screenSavers/color_dots.scrsv", gui_container.screenSaverPath)
		end
		registry.defaultScreenSaverPath = nil
		registry.screenSaverDefaultSetted = true
	end

	------------------------------------

	if not registry.shadowType then
		registry.shadowMode = "full"
		if minDepth == 4 then
			registry.shadowType = "smart"
		elseif minDepth == 8 then
			registry.shadowType = "advanced"
		else
			registry.shadowType = "none"
		end
	end

	------------------------------------

	liked.applyBeepState()
	liked.applyTimeZone()
	gui_container.refresh()

	------------------------------------

	if not liked.recoveryMode then
		bootloader.unittests("/vendor/unittests")
		bootloader.unittests("/data/unittests")

		bootloader.autorunsIn("/vendor/autoruns")
		bootloader.autorunsIn("/data/autoruns")

		require("autorun").autorun()
	end
	
	if programs.find("preinit") then
		apps.execute("preinit")
	end

	------------------------------------

	if lscreen then
		sysinit.runShell(lscreen)
	else
		sysinit.runShell(registry.primaryScreen)
		for index, address in ipairs(screens) do
			if registry.primaryScreen ~= address then
				sysinit.runShell(address)
			end
		end
	end

	event.hyperListen(function (eventType, cuuid, ctype)
		if ctype == "screen" then
			if eventType == "component_added" then
				if not liked.recoveryMode and not sysinit.screenThreads[cuuid] then
					sysinit.runShell(cuuid)
				end
			elseif eventType == "component_removed" then
				if sysinit.screenThreads[cuuid] then
					sysinit.screenThreads[cuuid]:kill()
					sysinit.screenThreads[cuuid] = nil
				end
			end
		end
	end)

	thread.create(function ()
		while true do
			for screen, th in pairs(sysinit.screenThreads) do
				if th:status() == "dead" then
					th:kill()
					sysinit.runShell(screen)
				end
			end
			os.sleep(1)
		end
	end):resume()

	sysinit.init = nil
	sysinit.inited = true
	event.timer(1, function ()
		sysinit.full = true
	end)
end

return sysinit