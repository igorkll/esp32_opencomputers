local graphic = require("graphic")
local gui_container = require("gui_container")
local registry = require("registry")
local calls = require("calls")
local gui = require("gui")
local liked = require("liked")

local colors = gui_container.colors

------------------------------------

local screen, posX, posY = ...
local gpu = graphic.findGpu(screen)
local rx, ry = gpu.getResolution()

------------------------------------

local window = graphic.createWindow(screen, posX, posY, rx - (posX - 1), ry - (posY - 1))

local function draw()
	window:clear(colors.black)
	window:set(1, 1, colors.lightGray, colors.white, "current timezone: " .. tostring(registry.timeZone or 0))
	window:set(1, 2, colors.lightGray, colors.white, "set new timezone")
end
draw()

------------------------------------

return function(eventData)
	local windowEventData = window:uploadEvent(eventData)
	if windowEventData[1] == "touch" then
		if windowEventData[4] == 2 and windowEventData[3] >= 1 and windowEventData[3] <= 16 then
			local data = gui.input(screen, nil, nil, "timezone")
			if data then
				data = tonumber(data)
				if not data then
					gui.warn(screen, nil, nil, "uncorrent input")
				else
					registry.timeZone = data
					liked.applyTimeZone()
				end
			end
			draw()
		end
	end
end