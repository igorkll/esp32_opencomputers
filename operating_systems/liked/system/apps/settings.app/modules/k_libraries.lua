local graphic = require("graphic")
local gui_container = require("gui_container")
local package = require("package")
local thread = require("thread")
local gui = require("gui")
local event = require("event")

local colors = gui_container.colors

------------------------------------

local screen, posX, posY = ...
local gpu = graphic.findGpu(screen)
local rx, ry = gpu.getResolution()

------------------------------------

local window = graphic.createWindow(screen, posX, posY, rx - (posX - 1), ry - (posY - 1))

------------------------------------

local selector = thread.create(function ()
	local scroll
	while true do
		window:clear(colors.black)
		local x, y = window:toRealPos((window.sizeX // 2) - 27, (window.sizeY // 2) - 6)

		local raw_names = {}
		local loadedLibraries = {}
		local constCount = 0
		local unloadableCount = 0
		for name, data in pairs(package.loaded) do
			table.insert(raw_names, name)
			table.insert(loadedLibraries, gui_container.short(name, 47))
			constCount = constCount + 1
		end
		for name, data in pairs(package.cache) do
			table.insert(raw_names, name)
			table.insert(loadedLibraries, gui_container.short(name .. " (unloadable)", 47))
			unloadableCount = unloadableCount + 1
		end

		window:set(2, 2, colors.black, colors.white, "total      count: " .. math.round(constCount + unloadableCount))
		window:set(2, 3, colors.black, colors.white, "static     count: " .. math.round(constCount))
		window:set(2, 4, colors.black, colors.white, "unloadable count: " .. math.round(unloadableCount))

		local num, lscroll = gui.select(screen, x, y, "loaded libraries", loadedLibraries, scroll, true, nil, nil, nil, true)
		scroll = lscroll

		if num then
			local name = raw_names[num]
			if name then
				package.unload(name, true)
			end
		end

		event.yield()
	end
end)
selector:resume()

return function(eventData)
	
end, function ()
	selector:kill()
end