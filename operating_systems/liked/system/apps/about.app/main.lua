local computer = require("computer")
local system = require("system")
local uix = require("uix")
local fs = require("filesystem")
local liked = require("liked")

local screen = ...
local ui = uix.manager(screen)
local rx, ry = ui:zoneSize()

---------------------------------

local cpuLevel, isApu, isCreative = system.getCpuLevel()
local hddTotalSpace = fs.get("/").spaceTotal()
local hddUsedSpace = fs.get("/").spaceUsed()
local score = liked.getComputerScore()

local layout = ui:create("About", uix.colors.white)
layout:createText(2, 2, uix.colors.black, "Operating System : " .. tostring(_OSVERSION) .. " / " .. tostring(_COREVERSION))
layout:createText(2, 3, uix.colors.black, "Computer Address : " .. computer.address())
layout:createText(2, 4, uix.colors.black, "Boot Disk        : " .. fs.bootaddress)
layout:createText(2, 5, uix.colors.black, "Device Type      : " .. system.getDeviceType())
layout:createText(2, 6, uix.colors.black, "Processor        : tier-" .. tostring(cpuLevel) .. (isApu and " (APU)" or "") .. (isCreative and " (Creative)" or ""))
layout:createText(2, 7, uix.colors.black, "Computer Score   : ")
layout:createText(21, 7, liked.getScoreColor(score), tostring(score) .. " / 10")

local linePoses = 22
local textSizes = 16
local paramsPoses = linePoses + (rx - linePoses - textSizes) + 1
local paramsPoses2 = linePoses + (rx - linePoses - textSizes) + 8

local emptyPlane = layout:createPlane(paramsPoses, ry - 4, 16, 8, uix.colors.white)

layout:createText(2, ry - 1, uix.colors.black, "CPU load level")
local cpuBar = layout:createProgress(linePoses, ry - 1, rx - linePoses - textSizes, uix.colors.red, uix.colors.lightGray, 0)
local cpuParam = layout:createText(paramsPoses, cpuBar.y, uix.colors.black, "")
local cpuParam2 = layout:createText(paramsPoses2, cpuBar.y, uix.colors.black, "")

layout:createText(2, ry - 2, uix.colors.black, "amount of used RAM")
local ramBar = layout:createProgress(linePoses, ry - 2, rx - linePoses - textSizes, uix.colors.green, uix.colors.lightGray, 0)
local ramParam = layout:createText(paramsPoses, ramBar.y, uix.colors.black, "")
local ramParam2 = layout:createText(paramsPoses2, ramBar.y, uix.colors.black, "")

layout:createText(2, ry - 3, uix.colors.black, "amount of used ROM")
local romBar = layout:createProgress(linePoses, ry - 3, rx - linePoses - textSizes, uix.colors.purple, uix.colors.lightGray, 0)
local romParam = layout:createText(paramsPoses, romBar.y, uix.colors.black, "")
local romParam2 = layout:createText(paramsPoses2, romBar.y, uix.colors.black, "")

layout:createText(2, ry - 4, uix.colors.black, "energy reserve")
local energyBar = layout:createProgress(linePoses, ry - 4, rx - linePoses - textSizes, uix.colors.orange, uix.colors.lightGray, 0)
local energyParam = layout:createText(paramsPoses, energyBar.y, uix.colors.black, "")
local energyParam2 = layout:createText(paramsPoses2, energyBar.y, uix.colors.black, "")

local coreLicenseButton = layout:createButton(rx - 18, 2, 17, 1, uix.colors.orange, uix.colors.white, "core license", true)
coreLicenseButton.back2 = uix.colors.lightGray
function coreLicenseButton:onClick(_, nickname)
	ui:fullStop()
	require("viewer").license(screen, "/system/core/LICENSE", nil, nil, nil, true)
	ui:fullStart()
	ui:draw()
end

local licenseButton = layout:createButton(rx - 18, 4, 17, 1, uix.colors.orange, uix.colors.white, "liked license", true)
licenseButton.back2 = uix.colors.lightGray
function licenseButton:onClick(_, nickname)
	ui:fullStop()
	require("viewer").license(screen, "/system/LICENSE", nil, nil, nil, true)
	ui:fullStart()
	ui:draw()
end

local function updateBars(cpuLoadLevel)
	local totalMemory = computer.totalMemory()
	local freeMemory = computer.freeMemory()

	local totalEnergy = computer.energy()
	local maxEnergy = computer.maxEnergy()
	
	local hddUsedValue = hddUsedSpace / hddTotalSpace
	local ramUsedValue = 1 - (freeMemory / totalMemory)
	local energyVal = totalEnergy / maxEnergy

	ramBar.value = ramUsedValue
	romBar.value = hddUsedValue
	energyBar.value = energyVal
	cpuBar.value = cpuLoadLevel

	cpuParam.text = tostring(math.round(cpuLoadLevel * 100)) .. "%"
	cpuParam2.text = "/ " .. tostring(100) .. "%"

	ramParam.text = tostring(math.round((totalMemory - freeMemory) / 1024)) .. "KB"
	ramParam2.text = "/ " .. tostring(math.round(totalMemory / 1024)) .. "KB"

	romParam.text = tostring(math.round(hddUsedSpace / 1024)) .. "KB"
	romParam2.text = "/ " .. tostring(math.round(hddTotalSpace / 1024)) .. "KB"

	energyParam.text = tostring(math.round(computer.energy()))
	energyParam2.text = "/ " .. tostring(math.round(computer.maxEnergy()))
end

function layout:onRedraw()
	updateBars(0)
end

layout:thread(function ()
	while true do
		updateBars(system.getCpuLoadLevel())

		emptyPlane:draw()

		ramBar:draw()
		romBar:draw()
		energyBar:draw()
		cpuBar:draw()

		cpuParam:draw()
		cpuParam2:draw()

		ramParam:draw()
		ramParam2:draw()

		romParam:draw()
		romParam2:draw()

		energyParam:draw()
		energyParam2:draw()
	end
end):resume()

---------------------------------

ui:loop()