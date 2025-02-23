local graphic = require("graphic")
local gui_container = require("gui_container")
local paths = require("paths")
local unicode = require("unicode")
local liked = require("liked")
local registry = require("registry")
local component = require("component")
local computer = require("computer")
local gui = require("gui")
local sysinit = require("sysinit")

local colors = gui_container.colors

------------------------------------

local screen, posX, posY = ...
local gpu = graphic.findGpu(screen)
local rx, ry = gpu.getResolution()

------------------------------------

local selectWindow = graphic.createWindow(screen, posX, posY, 16, ry - (posY - 1))
local selected = 1
local modes = {"none", "software", "hardware"}
for index, value in ipairs(modes) do
	if value == registry.bufferType then
		selected = index
		break
	end
end

------------------------------------

local oldselected
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
		local minRam = liked.minRamForDBuff()
		if selected ~= 2 or computer.totalMemory() >= (minRam * 1024) then
			local inits = {}
			for address in component.list("screen") do
				table.insert(inits, {address, graphic.screenshot(address)})
			end

			registry.bufferType = modes[selected] or "none"
			liked.applyBufferType()

			for _, init in ipairs(inits) do
				sysinit.applyPalette(sysinit.initPalPath, init[1])
				init[2]()
			end
		else
			local clear = graphic.screenshot(screen)
			gui.warn(screen, nil, nil, "A minimum of " .. math.round(minRam) .. "kb of RAM is required to activate software buffering")
			selected = oldselected
			clear()
			draw()
		end
	end

	oldselected = selected
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