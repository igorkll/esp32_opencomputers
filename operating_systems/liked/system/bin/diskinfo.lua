local screen, nickname, diskUuid = ...

local graphic = require("graphic")
local gui_container = require("gui_container")
local colors = gui_container.colors
local event = require("event")
local fs = require("filesystem")
local paths = require("paths")
local gui = require("gui")
local uix = require("uix")
local registry = require("registry")
local component = require("component")
local system = require("system")
local liked = require("liked")

local window = gui.customWindow(screen)
local layout = uix.create(window, nil, uix.styles[2])
local rx, ry = layout.sizeX, layout.sizeY

window:clear(colors.white)
window:fill(1, 1, window.sizeX, 1, colors.gray, 0, " ")
window:set(window.sizeX - 2, 1, colors.red, colors.white, " X ")
window:set(2, 1, colors.gray, colors.white, "disk-info")

local proxy = component.proxy(diskUuid)
local point = fs.point(diskUuid)
local size, sizeWithBaseCost, filesCount, dirsCount = fs.size(point)
local totalSpace = proxy.spaceTotal() / 1024
local usedSpace = proxy.spaceUsed() / 1024
local maxDiskSize = 1024 * 4 * 3 --raid completely filled with tier 3 disks

layout:createText(2, 3, 0x000000, "uuid     : " .. diskUuid)
layout:createText(2, 4, 0x000000, "label    : " .. (proxy.getLabel() or "[NONE]"))
layout:createText(2, 5, 0x000000, "type     : " .. system.getDiskLevel(diskUuid))
layout:createText(2, 6, 0x000000, "read only: " .. tostring(fs.isReadOnly(proxy)))
layout:createText(2, 7, 0x000000, "label  RO: " .. tostring(fs.isLabelReadOnly(proxy)))
layout:createText(2, 8, 0x000000, "f/d count: " .. filesCount .. "-files / " .. (dirsCount - 1) .. "-dirs")

layout:createText(2, ry - 4, 0x000000, "disk space:")
layout:createText(2, ry - 3, 0x000000, "total: " .. math.roundTo(totalSpace, 1) .. " KB")
layout:createText(2, ry - 2, 0x000000, "used : " .. math.roundTo(usedSpace, 1) .. " KB")
layout:createText(2, ry - 1, 0x000000, "free : " .. math.roundTo(totalSpace - usedSpace, 1) .. " KB")

layout:createProgress(20, ry - 3, 30, uix.colors.red, uix.colors.orange, totalSpace / maxDiskSize)
layout:createProgress(20, ry - 2, 30, uix.colors.red, uix.colors.orange, usedSpace / totalSpace)
layout:createProgress(20, ry - 1, 30, uix.colors.red, uix.colors.orange, (totalSpace - usedSpace) / totalSpace)

layout:createImage(rx - 9, 5, liked.getIcon(screen, point), true)

layout:draw()

while true do
	local eventData = {event.pull()}
	local windowEventData = window:uploadEvent(eventData)
	layout:uploadEvent(windowEventData)

	if windowEventData[1] == "key_down" then
		if windowEventData[4] == 28 then
			break
		end
	elseif windowEventData[1] == "touch" then
		if windowEventData[3] >= window.sizeX - 2 and windowEventData[4] == 1 then
			break
		end
	end
end