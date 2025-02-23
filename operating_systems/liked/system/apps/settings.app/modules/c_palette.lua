local graphic = require("graphic")
local fs = require("filesystem")
local gui_container = require("gui_container")
local paths = require("paths")
local unicode = require("unicode")
local event = require("event")
local calls = require("calls")
local palette = require("palette")
local uix = require("uix")
local registry = require("registry")
local sysinit = require("sysinit")
local thread = require("thread")
local gui = require("gui")

local colors = gui_container.colors

------------------------------------

local screen, posX, posY = ...
local gpu = graphic.findGpu(screen)
local rx, ry = gpu.getResolution()

local themesPath = "/system/palettes"
local palettePath = "/data/palette.plt"

------------------------------------

local selectWindow = graphic.createWindow(screen, posX, posY, 16, ry - (posY - 1))
local colorsWindow = graphic.createWindow(screen, posX + 17, posY, 8, 18)
local settingsWindow = graphic.createWindow(screen, posX + 17 + 8, posY, 50, ry - 1)

local layout = uix.create(settingsWindow)
local visionProtection = layout:createSwitch(2, 2, registry.visionProtection)
layout:createText(2 + 7, 2, uix.colors.white, "vision protection")

function visionProtection:onSwitch()
	local screenOn = gui.hideScreen(screen)
	if self.state then
		registry.visionProtection = true
	else
		registry.visionProtection = nil
	end
	sysinit.applyPalette(sysinit.initPalPath, screen, true)
	selfReload(screenOn)
end

local selected = 1
local themes = {}
for i, file in ipairs(fs.list(themesPath) or {}) do
	table.insert(themes, file)
end

if fs.exists(palettePath) then
	selected = nil
	for i, file in ipairs(fs.list(themesPath, true)) do
		if fs.equals(file, palettePath) then
			selected = i
			break
		end
	end
end

------------------------------------

function draw(set)
	selectWindow:clear(colors.black)
	colorsWindow:fill(1, 1, colorsWindow.sizeX, colorsWindow.sizeY, colors.black, colors.brown, "▒")
	selectWindow:setCursor(1, 1)

	for i, v in ipairs(gui_container.indexsColors) do
		colorsWindow:set(2, i + 1, v, 0, "      ")
	end

	for i, file in ipairs(themes) do
		file = paths.hideExtension(file)
		local str = file .. string.rep(" ", (selectWindow.sizeX - 2) - unicode.len(file))

		local background = colors.black
		local foreground = selected == i and colors.white or colors.gray

		selectWindow:write("╔" .. string.rep("═", unicode.len(str)) .. "╗\n", background, foreground)
		selectWindow:write("║", background, foreground)
		selectWindow:write(str, background, foreground)
		selectWindow:write("║" .. "\n", background, foreground)
		selectWindow:write("╚" .. string.rep("═", unicode.len(str)) .. "╝", background, foreground)

		if i ~= #themes then selectWindow:write("\n") end
	end

	layout:draw()

	if set then
		local screenOn = gui.hideScreen(screen)
		local palPath = paths.concat(themesPath, themes[selected])
		palette.reBaseColor(palPath)
		palette.setSystemPalette(palPath, nil, true)
		gui_container.refresh()
		event.push("redrawDesktop")
		selfReload(screenOn)
	end
end
draw()
if afterDraw then
	graphic.forceUpdate(screen)
	afterDraw()
end

------------------------------------

return function(eventData)
	layout:uploadEvent(eventData)

	local selectWindowEventData = selectWindow:uploadEvent(eventData)

	if selectWindowEventData[1] == "scroll" then
		if selected then
			local oldselected = selected
			if selectWindowEventData[5] > 0 then
				selected = selected - 1
				if selected < 1 then selected = 1 end
			else
				selected = selected + 1
				if selected > #themes then selected = #themes end
			end
			if selected ~= oldselected then
				draw(true)
			end
		else
			selected = 1
		end
	elseif selectWindowEventData[1] == "touch" then
		local posY = ((selectWindowEventData[4] - 1) // 3) + 1

		if posY >= 1 and posY <= #themes then
			if posY ~= selected then
				selected = posY
				draw(true)
			end
		end
	elseif selectWindowEventData[1] == "key_down" then
		if selected then
			local oldselected = selected
			if selectWindowEventData[4] == 200 then
				selected = selected - 1
				if selected < 1 then selected = 1 end
			elseif selectWindowEventData[4] == 208 then
				selected = selected + 1
				if selected > #themes then selected = #themes end
			end
			if selected ~= oldselected then
				draw(true)
			end
		else
			selected = 1
		end
	end
end