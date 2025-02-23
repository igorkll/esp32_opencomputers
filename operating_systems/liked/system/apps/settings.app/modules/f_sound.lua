local graphic = require("graphic")
local gui_container = require("gui_container")
local registry = require("registry")
local uix = require("uix")
local liked = require("liked")

local colors = gui_container.colors

------------------------------------

local screen, posX, posY = ...
local gpu = graphic.findGpu(screen)
local rx, ry = gpu.getResolution()

------------------------------------

local selectWindow = graphic.createWindow(screen, posX, posY, rx - (posX - 1), ry - (posY - 1))
local layout = uix.create(selectWindow, colors.black)

layout:createSwitch(2, 2, registry.soundEnable).onSwitch = function (self)
	registry.soundEnable = self.state
end
layout:createText(9, 2, colors.white, "System Sounds")

layout:createSwitch(2, 4, registry.diskSound).onSwitch = function (self)
	registry.diskSound = self.state
end
layout:createText(9, 4, colors.white, "Disk Attach/Detach Sounds")

layout:createSwitch(2, 6, registry.lowPowerSound).onSwitch = function (self)
	registry.lowPowerSound = self.state
end
layout:createText(9, 6, colors.white, "Low-Power Sound")

layout:createSwitch(2, 8, registry.fullBeepDisable, colors.red).onSwitch = function (self)
	registry.fullBeepDisable = self.state
	liked.applyBeepState()
end
layout:createText(9, 8, colors.white, "Full PC Speaker Disable")

layout:draw()

------------------------------------

return function(eventData)
	layout:uploadEvent(eventData)
end