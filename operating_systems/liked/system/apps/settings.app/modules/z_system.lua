local graphic = require("graphic")
local gui_container = require("gui_container")
local computer = require("computer")
local fs = require("filesystem")
local system = require("system")
local paths = require("paths")
local serialization = require("serialization")
local registry = require("registry")
local liked = require("liked")
local gui = require("gui")
local uix = require("uix")
local sysdata = require("sysdata")

local colors = gui_container.colors

------------------------------------

local screen, posX, posY = ...
local rx, ry = graphic.getResolution(screen)
local window = graphic.createWindow(screen, posX, posY, rx - (posX - 1), ry - (posY - 1))
local layout = uix.create(window, colors.black)

local currentVersion = liked.version()
local lastVersion, lastVersionErr

------------------------------------

layout:createButton(2, 8, 16, 1, nil, nil, "WIPE USER DATA", true).onClick = function ()
	if gui.checkPasswordLoop(screen) and gui.pleaseType(screen, "WIPE") then
		if liked.assert(screen, fs.remove("/data")) then
			computer.shutdown("fast")
		end
	end
	layout:draw()
end

local branch = sysdata.get("branch")
local currentMode = sysdata.get("mode")

local function update(newBranch)
	if not lastVersion then
		gui.warn(screen, nil, nil, "connection problems\ntry again later")
	elseif gui.pleaseCharge(screen, 80, "update") and gui.pleaseSpace(screen, 512, "update") and gui.checkPasswordLoop(screen) then
		local updatelib = require("update")
		if updatelib.needWipe(newBranch or branch, currentMode) then
			gui.warn(screen, nil, nil, "to upgrade to this version, you need to erase the data")
			if gui.pleaseType(screen, "WIPE") then
				updatelib.run(newBranch or branch, currentMode, true)
			end
		elseif gui.yesno(screen, nil, nil, currentVersion ~= lastVersion and "start updating now?" or "you have the latest version installed. do you still want to start updating?") then
			updatelib.run(newBranch or branch, currentMode)
		end
	end
	layout:draw()
end

layout:createButton(20, 8, 16, 1, nil, nil, "UPDATE SYSTEM", true).onClick = function ()
	update()
end

if not registry.disableSystemSettings then
	local planeSize = 9
	local planePos = layout.sizeY - planeSize
	local hidePlane = layout:createPlane(2, planePos, layout.sizeX - 2, planeSize, colors.red)
	local show = layout:createButton(layout.sizeX - 9, planePos+1, 8, 1, colors.orange, colors.white, "show")
	local showText = layout:createText(3, planePos+1, colors.white, "dangerous settings")

	function show:onDrop()
		if gui.checkPasswordLoop(screen) and gui.pleaseType(screen, "DNGRUS") then
			hidePlane.disabledHidden = true
			show.disabledHidden = true
			showText.disabledHidden = true

			layout:createPlane(2, planePos, layout.sizeX - 2, planeSize, colors.lightGray)
			layout:createText(layout.sizeX - 18, planePos, colors.black, "dangerous settings")

			local disableRecoverySwitch = layout:createSwitch(3, planePos+1, registry.disableRecovery)
			local disableLogoSwitch = layout:createSwitch(3, planePos+3, registry.disableLogo)
			local disableAutoReboot = layout:createSwitch(3, planePos+5, registry.disableAutoReboot)
			if not registry.disableChangeBranch then
				local changeBranchButton = layout:createButton(3, planePos+7, nil, 1, nil, nil, "update to another branch", true)
				function changeBranchButton:onClick()
					local branchs = {"main", "test", "dev"}
					for i = #branchs, 1, -1 do
						if branchs[i] == branch then
							table.remove(branchs, i)
							break
						end
					end
					local newBranch = gui.select(screen, nil, nil, "select a new branch", branchs)
					if newBranch then
						newBranch = branchs[newBranch]
						gRedraw()
						layout:draw()
						update(newBranch)
					end
					gRedraw()
					layout:draw()
				end
			end

			layout:createText(10, planePos+1, colors.white, "disable system recovery menu")
			layout:createText(10, planePos+3, colors.white, "disable startup logo")
			layout:createText(10, planePos+5, colors.white, "disable auto-reboot on system error")
			
			function disableRecoverySwitch:onSwitch()
				registry.data.disableRecovery = self.state
				if registry.data.disableRecovery == false then registry.data.disableRecovery = nil end
				registry.save()
			end
			
			function disableLogoSwitch:onSwitch()
				registry.data.disableLogo = self.state
				if registry.data.disableLogo == false then registry.data.disableLogo = nil end
				registry.save()
			end
			
			function disableAutoReboot:onSwitch()
				registry.data.disableAutoReboot = self.state
				if registry.data.disableAutoReboot == false then registry.data.disableAutoReboot = nil end
				registry.save()
			end
		end

		layout:draw()
	end
end

local function systemWeight()
	local _, initOnDisk = fs.size("/init.lua")
	local _, sysOnDisk = fs.size("/system")
	return math.round((initOnDisk + sysOnDisk) / 1024)
end

layout:createText(2, 2, colors.white, "current version: " .. currentVersion)
layout:createText(2, 4, colors.white, "current branch : " .. branch)
layout:createText(2, 5, colors.white, "current edition: " .. currentMode)

local lastVersionText = layout:createText(2, 3, colors.white, "last    version: loading...")
local systemWeightLabel = layout:createText(2, 6, colors.white, "system  weight : calculation...")
layout:draw()
graphic.forceUpdate(screen)
systemWeightLabel.text = "system  weight : " .. tostring(systemWeight()) .. "KB"
layout:draw()
graphic.forceUpdate(screen)

lastVersion, lastVersionErr = liked.lastVersion()
if lastVersion then
	lastVersionText.text = "last    version: " .. lastVersion
else
	lastVersionText.text = "last    version: " .. lastVersionErr
end

layout:draw()
graphic.forceUpdate(screen)

return function(eventData)
	local windowEventData = window:uploadEvent(eventData)
	layout:uploadEvent(windowEventData)
end