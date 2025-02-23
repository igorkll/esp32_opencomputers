local graphic = require("graphic")
local gui_container = require("gui_container")
local paths = require("paths")
local unicode = require("unicode")
local liked = require("liked")
local registry = require("registry")

local colors = gui_container.colors

------------------------------------

local screen, posX, posY = ...
local gpu = graphic.findGpu(screen)
local rx, ry = gpu.getResolution()

------------------------------------

local selectWindow = graphic.createWindow(screen, posX, posY, 32, ry - (posY - 1))
local selected = 1
local modes = {"power", "energy saving"}
for index, value in ipairs(modes) do
	if value == registry.powerMode then
		selected = index
		break
	end
end

------------------------------------

local function draw(set)
	selectWindow:clear(colors.black)
	selectWindow:setCursor(1, 1)
	for i, file in ipairs(modes) do
		file = paths.hideExtension(file)
		local str = file .. string.rep(" ", (selectWindow.sizeX - 2) - unicode.len(file))

		local background = colors.black
		local foreground = selected == i and colors.white or colors.gray

		selectWindow:write("╔" .. string.rep("═", unicode.len(str)) .. "╗\n", background, foreground)
		selectWindow:write("║", background, foreground)
		selectWindow:write(str, background, foreground)
		selectWindow:write("║" .. "\n", background, foreground)
		selectWindow:write("╚" .. string.rep("═", unicode.len(str)) .. "╝", background, foreground)

		if i ~= #modes then selectWindow:write("\n") end
	end

	if set then
		registry.powerMode = modes[selected] or "none"
		liked.applyPowerMode()
	end
end
draw()

------------------------------------

return function(eventData)
	local selectWindowEventData = selectWindow:uploadEvent(eventData)
	if selectWindowEventData[1] == "scroll" then
		if selected then
			local oldselected = selected
			if selectWindowEventData[5] > 0 then
				selected = selected - 1
				if selected < 1 then selected = 1 end
			else
				selected = selected + 1
				if selected > #modes then selected = #modes end
			end
			if selected ~= oldselected then
				draw(true)
			end
		else
			selected = 1
		end
	elseif selectWindowEventData[1] == "touch" then
		local posY = ((selectWindowEventData[4] - 1) // 3) + 1

		if posY >= 1 and posY <= #modes then
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
				if selected > #modes then selected = #modes end
			end
			if selected ~= oldselected then
				draw(true)
			end
		else
			selected = 1
		end
	end
end