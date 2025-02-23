local graphic = require("graphic")
local fs = require("filesystem")
local gui_container = require("gui_container")
local paths = require("paths")
local unicode = require("unicode")
local event = require("event")
local registry = require("registry")
local uix = require("uix")
local colorslib = require("colors")

local colors = gui_container.colors

------------------------------------

local screen, posX, posY = ...
local gpu = graphic.findGpu(screen)
local rx, ry = gpu.getResolution()

local wallpapersPath = "/system/wallpapers"
local wallpaperPath = "/data/wallpaper.t2p"

------------------------------------

local colorpicColor = registry.wallpaperBaseColor or "lightBlue"
if type(colorpicColor) == "string" then
	colorpicColor = uix.colors[colorslib[colorpicColor]]
end

--local selectColorWindow = graphic.createWindow(screen, posX + 16, posY, rx, ry - (posY - 1))

local colorsNames = {}
for key, value in pairs(colors) do
	table.insert(colorsNames, key)
end
table.sort(colorsNames)

local selectWindow = graphic.createWindow(screen, posX, posY, rx, ry - (posY - 1))
local selected = 1
local wallpapaers = {"none"}
for i, file in ipairs(fs.list(wallpapersPath)) do
	table.insert(wallpapaers, file)
end

if fs.exists(wallpaperPath) then
	selected = nil
	for i, file in ipairs(fs.list(wallpapersPath, true)) do
		if fs.equals(file, wallpaperPath) then
			selected = i + 1
			break
		end
	end
end


local layout = uix.create(selectWindow)
local colorpic = layout:createColorpic(18, 2, 24, 1, "wallpaper base color", colorpicColor or colors.lightBlue, true)
local wallpaperLight = layout:createSeek(18, 4, 25, nil, nil, nil, (registry.wallpaperLight or 1) / 2)
local wallpaperLightText = layout:createText(18 + 25 + 1, 4)
local wallpaperLightReset = layout:createButton(18 + 25 + 8 + 5, 4, 3, 1, nil, nil, "R")

local text1 = layout:createText(18, selectWindow.sizeY - 2, nil, "* It is not recommended to use wallpaper")
local text2 = layout:createText(18, selectWindow.sizeY - 1, nil, "light on tier2 screens")
if graphic.getDepth(screen) == 8 then
	text1.hidden = true
	text2.hidden = true
end

local function updateText()
	wallpaperLightText.text = "light: " .. tostring(math.round(wallpaperLight.value * 200)) .. "%     "
	wallpaperLightText:draw()
	wallpaperLightReset:draw()
end

function wallpaperLight:onSeek(value)
	registry.wallpaperLight = value * 2
	updateText()
end

function wallpaperLightReset:onClick()
	registry.wallpaperLight = 1
	wallpaperLight.value = 0.5
	updateText()
	wallpaperLight:draw()
end

function colorpic:onColor(color)
	registry.wallpaperBaseColor = color
	event.push("redrawDesktop")
end

updateText()
layout:draw()

------------------------------------

local colors_names2ids = {}
local colors_ids2names = {}
local function draw(set)
	selectWindow:clear(colors.black)
	selectWindow:setCursor(1, 1)
	for i, file in ipairs(wallpapaers) do
		file = paths.hideExtension(file)
		local str = file .. string.rep(" ", 14 - unicode.len(file))

		local background = colors.black
		local foreground = selected == i and colors.white or colors.gray

		selectWindow:write("╔" .. string.rep("═", unicode.len(str)) .. "╗\n", background, foreground)
		selectWindow:write("║", background, foreground)
		selectWindow:write(str:gsub("_", " "), background, foreground)
		selectWindow:write("║" .. "\n", background, foreground)
		selectWindow:write("╚" .. string.rep("═", unicode.len(str)) .. "╝", background, foreground)

		if i ~= #wallpapaers then selectWindow:write("\n") end
	end

	--[[
	local currentColorName = registry.wallpaperBaseColor or "lightBlue"
	selectColorWindow:clear(colors.black)
	selectColorWindow:setCursor(1, 1)
	for i, name in ipairs(colorsNames) do
		colors_ids2names[i] = name
		colors_names2ids[name] = i

		local str = name .. string.rep(" ", (selectColorWindow.sizeX - 2) - unicode.len(name))

		local background = currentColorName == name and gui_container.colors[name] or colors.gray
		local foreground = colors.black
		if background == foreground or (currentColorName == "gray" and name == "gray") then
			foreground = colors.white
		end

		selectColorWindow:write(str, background, foreground)

		if i ~= #colorsNames then selectColorWindow:write("\n") end
	end
	]]

	if set then
		if selected == 1 then
			fs.remove("/data/wallpaper.t2p")
		else
			fs.copy(paths.concat(wallpapersPath, wallpapaers[selected]), "/data/wallpaper.t2p")
		end
		event.push("redrawDesktop")
	end

	updateText()
	layout:draw()
end
draw()

------------------------------------

return function(eventData)
	local selectWindowEventData = selectWindow:uploadEvent(eventData)
	if selectWindowEventData[1] == "scroll" then
		if selectWindowEventData[3] <= 16 then
			if selected then
				local oldselected = selected
				if selectWindowEventData[5] > 0 then
					selected = selected - 1
					if selected < 1 then selected = 1 end
				else
					selected = selected + 1
					if selected > #wallpapaers then selected = #wallpapaers end
				end
				if selected ~= oldselected then
					draw(true)
				end
			else
				selected = 1
			end
		end
	elseif selectWindowEventData[1] == "touch" then
		if selectWindowEventData[3] <= 16 then
			local posY = ((selectWindowEventData[4] - 1) // 3) + 1

			if posY >= 1 and posY <= #wallpapaers then
				if posY ~= selected then
					selected = posY
					draw(true)
				end
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
				if selected > #wallpapaers then selected = #wallpapaers end
			end
			if selected ~= oldselected then
				draw(true)
			end
		else
			selected = 1
		end
	end

	layout:uploadEvent(selectWindowEventData)

	--[[
	local currentColorName = registry.wallpaperBaseColor or "lightBlue"
	local selectWindowEventData = selectColorWindow:uploadEvent(eventData)
	if selectWindowEventData[1] == "scroll" then
		if selected then
			local oldselected = selected
			if selectWindowEventData[5] > 0 then
				selected = selected - 1
				if selected < 1 then selected = 1 end
			else
				selected = selected + 1
				if selected > #colorsNames then selected = #colorsNames end
			end
			if selected ~= oldselected then
				draw(true)
			end
		else
			selected = 1
		end
	elseif selectWindowEventData[1] == "touch" then
		local posY = (selectWindowEventData[4] - 1) + 1
		local colorName = colors_ids2names[posY]

		if colorName and currentColorName ~= colorName then
			registry.wallpaperBaseColor = colorName
			draw(true)
		end
	elseif selectWindowEventData[1] == "key_down" then
		local id = colors_names2ids[currentColorName]
		

		if selectWindowEventData[4] == 200 then
			id = id - 1
		elseif selectWindowEventData[4] == 208 then
			id = id + 1
		end

		local colorName = colors_ids2names[id]

		if colorName and currentColorName ~= colorName then
			registry.wallpaperBaseColor = colorName
			draw(true)
		end
	end
	]]
end