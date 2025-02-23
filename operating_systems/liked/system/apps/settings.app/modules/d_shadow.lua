local graphic = require("graphic")
local gui_container = require("gui_container")
local unicode = require("unicode")
local registry = require("registry")
local system = require("system")
local paths = require("paths")
local event = require("event")
local thread = require("thread")
local gui = require("gui")
local image = require("image")

local colors = gui_container.colors

------------------------------------

local screen, posX, posY = ...
local gpu = graphic.findGpu(screen)
local rx, ry = gpu.getResolution()

local selfpath = system.getSelfScriptPath()

------------------------------------

local selectModeWindow = graphic.createWindow(screen, posX + 16, posY, 16, ry - (posY - 1))
local selectWindow = graphic.createWindow(screen, posX, posY, 16, ry - (posY - 1))

local shadows = {"advanced", "smart", "simple", "none"}
local selected = 4
for index, value in ipairs(shadows) do
	if value == registry.shadowType then
		selected = index
		break
	end
end

local modes = {"full", "compact", "round", "screen"}
local selectedMode = 1
for index, value in ipairs(modes) do
	if value == registry.shadowMode then
		selectedMode = index
		break
	end
end

------------------------------------

local function draw(set)
	selectWindow:clear(colors.black)
	selectWindow:setCursor(1, 1)
	for i, shadowType in ipairs(shadows) do
		local str = shadowType .. string.rep(" ", (selectWindow.sizeX - 2) - unicode.len(shadowType))

		local background = colors.black
		local foreground = selected == i and colors.white or colors.gray

		selectWindow:write("╔" .. string.rep("═", unicode.len(str)) .. "╗\n", background, foreground)
		selectWindow:write("║", background, foreground)
		selectWindow:write(str, background, foreground)
		selectWindow:write("║" .. "\n", background, foreground)
		selectWindow:write("╚" .. string.rep("═", unicode.len(str)) .. "╝", background, foreground)

		if i ~= #shadows then selectWindow:write("\n") end
	end

	selectModeWindow:clear(colors.black)
	selectModeWindow:setCursor(1, 1)
	for i, shadowMode in ipairs(modes) do
		local str = shadowMode .. string.rep(" ", (selectModeWindow.sizeX - 2) - unicode.len(shadowMode))

		local background = colors.black
		local foreground = selectedMode == i and colors.white or colors.gray

		selectModeWindow:write("╔" .. string.rep("═", unicode.len(str)) .. "╗\n", background, foreground)
		selectModeWindow:write("║", background, foreground)
		selectModeWindow:write(str, background, foreground)
		selectModeWindow:write("║" .. "\n", background, foreground)
		selectModeWindow:write("╚" .. string.rep("═", unicode.len(str)) .. "╝", background, foreground)

		if i ~= #modes then selectModeWindow:write("\n") end
	end

	if graphic.getDepth(screen) < 8 then
		selectWindow:set(2, ry - 3, colors.black, colors.white, "* It is not recommended to use advanced shadows")
		selectWindow:set(2, ry - 2, colors.black, colors.white, "on tier2 screens")
	end

	if set then
		registry.shadowType = shadows[selected]
		registry.shadowMode = modes[selectedMode]
	end

	local ix, iy = ((rx // 3) * 2) + 8, (ry // 2) - 4
	local imagePath = paths.concat(paths.path(paths.path(selfpath)), "shadow_demo.t2p")
	image.draw(screen, imagePath, ix, iy)
	local isx, isy = image.size(imagePath)
	if registry.shadowMode == "screen" then
		gui.shadow(screen, ix, iy, isx, isy, nil, true)
	end
	local th = thread.create(gui.context, screen, ix + 2, iy + 1, {"shutdown", "reboot"}, nil, registry.shadowMode == "screen")
	th:resume()
	event.yield()
	th:kill()
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
				if selected > #shadows then selected = #shadows end
			end
			if selected ~= oldselected then
				draw(true)
			end
		else
			selected = 1
		end
	elseif selectWindowEventData[1] == "touch" then
		local posY = ((selectWindowEventData[4] - 1) // 3) + 1

		if posY >= 1 and posY <= #shadows then
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
				if selected > #shadows then selected = #shadows end
			end
			if selected ~= oldselected then
				draw(true)
			end
		else
			selected = 1
		end
	end


	local selectWindowEventData = selectModeWindow:uploadEvent(eventData)
	if selectWindowEventData[1] == "scroll" then
		if selectedMode then
			local oldselected = selectedMode
			if selectWindowEventData[5] > 0 then
				selectedMode = selectedMode - 1
				if selectedMode < 1 then selectedMode = 1 end
			else
				selectedMode = selectedMode + 1
				if selectedMode > #modes then selectedMode = #modes end
			end
			if selectedMode ~= oldselected then
				draw(true)
			end
		else
			selectedMode = 1
		end
	elseif selectWindowEventData[1] == "touch" then
		local posY = ((selectWindowEventData[4] - 1) // 3) + 1

		if posY >= 1 and posY <= #modes then
			if posY ~= selectedMode then
				selectedMode = posY
				draw(true)
			end
		end
	elseif selectWindowEventData[1] == "key_down" then
		if selectedMode then
			local oldselected = selectedMode
			if selectWindowEventData[4] == 200 then
				selectedMode = selectedMode - 1
				if selectedMode < 1 then selectedMode = 1 end
			elseif selectWindowEventData[4] == 208 then
				selectedMode = selectedMode + 1
				if selectedMode > #modes then selectedMode = #modes end
			end
			if selectedMode ~= oldselected then
				draw(true)
			end
		else
			selectedMode = 1
		end
	end
end