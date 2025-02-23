local graphic = require("graphic")
local fs = require("filesystem")
local gui_container = require("gui_container")
local paths = require("paths")
local unicode = require("unicode")
local registry = require("registry")
local event = require("event")

local colors = gui_container.colors

------------------------------------

local screen, posX, posY = ...
local gpu = graphic.findGpu(screen)
local rx, ry = gpu.getResolution()

local screenSaverPath = "/data/screenSaver.scrsv"
local screenSaversPath = "/system/screenSavers"

------------------------------------

local selectWindow = graphic.createWindow(screen, posX, posY, rx - (posX - 1), ry - (posY - 1))
local selected = 1
local objs = {"none"}
for i, file in ipairs(fs.list(screenSaversPath) or {}) do
	table.insert(objs, file)
end

if fs.exists(screenSaverPath) then
	selected = nil
	for i, file in ipairs(fs.list(screenSaversPath, true)) do
		if fs.equals(file, screenSaverPath) then
			selected = i + 1
			break
		end
	end
end

------------------------------------

local function draw(set)
	selectWindow:clear(colors.black)
	selectWindow:setCursor(1, 1)
	for i, file in ipairs(objs) do
		file = paths.hideExtension(file)
		local str = file .. string.rep(" ", 14 - unicode.len(file))

		local background = colors.black
		local foreground = selected == i and colors.white or colors.gray

		selectWindow:write("╔" .. string.rep("═", unicode.len(str)) .. "╗\n", background, foreground)
		selectWindow:write("║", background, foreground)
		selectWindow:write(str:gsub("_", " "), background, foreground)
		selectWindow:write("║" .. "\n", background, foreground)
		selectWindow:write("╚" .. string.rep("═", unicode.len(str)) .. "╝", background, foreground)

		if i ~= #objs then selectWindow:write("\n") end
	end

	selectWindow:set(18, 2, colors.blue, colors.white, " DEMO ")
	selectWindow:set(18, 3, colors.black, colors.white, "screensaver timer: ")
	selectWindow:set(18 + 20, 3, colors.gray, colors.white, "-")
	selectWindow:set(18 + 6 + 20, 3, colors.gray, colors.white, "+")
	selectWindow:set(18 + 2 + 20, 3, colors.black, colors.white, tostring(registry.screenSaverTimer or "OFF"))

	if set then
		if selected == 1 then
			fs.remove(screenSaverPath)
		else
			fs.copy(paths.concat(screenSaversPath, objs[selected]), screenSaverPath)
		end
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
				if selected > #objs then selected = #objs end
			end
			if selected ~= oldselected then
				draw(true)
			end
		else
			selected = 1
		end
	elseif selectWindowEventData[1] == "touch" then
		if selectWindowEventData[3] <= 16 then
			local posY = ((selectWindowEventData[4] - 1) // 3) + 1
			if posY >= 1 and posY <= #objs then
				if posY ~= selected then
					selected = posY
					draw(true)
				end
			end
		end

		local x, y = selectWindowEventData[3], selectWindowEventData[4]
		if y == 2 and x >= 18 and x < 18 + 6 then
			event.push("screenSaverDemo", screen)
		end

		if y == 3 then
			local function mathAdd(offset)
				local addCount = 5
				if registry.screenSaverTimer then
					if (registry.screenSaverTimer + offset) >= 60 then
						addCount = 30
					elseif (registry.screenSaverTimer + offset) >= 30 then
						addCount = 10
					end
				end
				return addCount
			end
			

			if x == 18 + 20 then
				if registry.screenSaverTimer then
					local addCount = mathAdd(-1)
					registry.screenSaverTimer = registry.screenSaverTimer - addCount
					if registry.screenSaverTimer < addCount then
						registry.screenSaverTimer = false
					end
					draw()
				end
			elseif x == 18 + 6 + 20 then
				if not registry.screenSaverTimer then
					registry.screenSaverTimer = mathAdd(0)
					draw()
				elseif registry.screenSaverTimer < (3 * 60) then
					registry.screenSaverTimer = registry.screenSaverTimer + mathAdd(0)
					draw()
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
				if selected > #objs then selected = #objs end
			end
			if selected ~= oldselected then
				draw(true)
			end
		else
			selected = 1
		end
	end
end