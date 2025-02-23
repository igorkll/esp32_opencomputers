local graphic = require("graphic")
local gui_container = require("gui_container")
local thread = require("thread")
local component = require("component")
local system = require("system")
local gui = require("gui")

local colors = gui_container.colors

------------------------------------

local screen, posX, posY = ...
local gpu = graphic.findGpu(screen)
local rx, ry = gpu.getResolution()

------------------------------------

local window = graphic.createWindow(screen, posX, posY, rx - (posX - 1), ry - (posY - 1))

------------------------------------

local function drawInfo()
	local currentCount = 0
	for addr in component.list() do
		currentCount = currentCount + 1
	end
	currentCount = currentCount - 3
	window:set(2, 2, colors.black, colors.white, "component count: " .. math.roundTo(system.getCurrentComponentCount(), 2) .. "/" .. system.getMaxComponentCount() .. "    ")
	window:set(2, window.sizeY - 2, colors.black, colors.white, "note: filesystems consume 0.25 of the component budget")
	window:set(2, window.sizeY - 1, colors.black, colors.white, "note: self component does not spend the budget")
end

local base = thread.current()

local componentSelector = thread.createBackground(function ()
	while true do
		window:clear(colors.black)
		drawInfo()

		local x, y = window:toRealPos((window.sizeX // 2) - 27, (window.sizeY // 2) - 8)
		gui.selectcomponent(screen, x, y, nil, nil, true, {onEdit = function()
			base:suspend()
			upTask:suspend()
		end, onCloseEdit = function()
			base:resume()
			upTask:resume()
		end}, nil, true)
	end
end)
componentSelector.parentData.screen = screen
componentSelector:resume()

return function(eventData)
	if eventData[1] == "component_added" or eventData[1] == "component_removed" then
		drawInfo()
	end
end, function ()
	componentSelector:kill()
end