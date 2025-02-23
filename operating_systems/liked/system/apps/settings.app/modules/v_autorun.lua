local graphic = require("graphic")
local uix = require("uix")
local gobjs = require("gobjs")
local autorun = require("autorun")
local paths = require("paths")
local iowindows = require("iowindows")
local gui = require("gui")

local colors = uix.colors

------------------------------------

local screen, posX, posY = ...
local gpu = graphic.findGpu(screen)
local rx, ry = gpu.getResolution()

------------------------------------

local window = graphic.createWindow(screen, posX, posY, rx - (posX - 1), ry - (posY - 1))
local layout = uix.create(window, colors.black)

local function redraw()
	gRedraw()
	layout:draw()
end

layout:createText(2, 2, colors.white, "autorun scripts:")
layout:createText(2, window.sizeY - 2, colors.white, "in case of failure, use the system recovery mode:")
layout:createText(2, window.sizeY - 1, colors.white, "Run System Recovery Script > Start The System In Recovery Mode")
local autorunScriptsListSizeX = window.sizeX - 25
local autorunList = layout:createCustom(2, 4, gobjs.checkboxgroup, autorunScriptsListSizeX, window.sizeY - 9)
local function refreshList()
	autorun.check()
	autorunList.list = {}
	for _, item in ipairs(autorun.list("user")) do
		table.insert(autorunList.list, 1, {gui.fpath(screen, item[1], autorunList.sizeX - 3), item[2], item[1]})
	end
end
refreshList()

function autorunList:onTextClick(_, _, _, usertbl, eventData)
	if eventData[5] then
		if gui.yesno(screen, nil, nil, "are you sure you want to remove the script from autorun?") then
			autorun.reg("user", usertbl[3], true)
			refreshList()
		end
	end
	redraw()
end

function autorunList:onSwitch(_, _, state, usertbl)
	autorun.reg("user", usertbl[3], nil, state)
	refreshList()
end

local addScriptButton = layout:createButton(2, window.sizeY - 4, autorunScriptsListSizeX, 1, nil, nil, "add script to autorun")
function addScriptButton:onDrop()
	local scriptPath = iowindows.selectfile(screen, "lua")
	if scriptPath then
		autorun.reg("user", scriptPath)
		refreshList()
	end
	redraw()
end

redraw()

return function(eventData)
	local windowEventData = window:uploadEvent(eventData)
	layout:uploadEvent(windowEventData)
end