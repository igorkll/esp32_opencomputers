local gui_container = require("gui_container")
local registry = require("registry")
local colorslib = require("colors")
local colors = gui_container.colors
local calls = require("calls")
local graphic = require("graphic")
local event = require("event")
local computer = require("computer")
local unicode = require("unicode")
local component = require("component")
local thread = require("thread")
local paths = require("paths")
local system = require("system")
local sound = require("sound")
local fs = require("filesystem")
local programs = require("programs")
local clipboard = require("clipboard")
local parser = require("parser")
local lastinfo = require("lastinfo")
local gui = {colors = colors}
gui.blackMode = false
gui.smartShadowsColors = {
	colorslib.lightGray, --1)  white
	colorslib.brown,     --2)  orange
	colorslib.purple,    --3)  magenta
	colorslib.cyan,      --4)  lightBlue
	colorslib.orange,    --5)  yellow
	colorslib.green,     --6)  lime
	colorslib.magenta,   --7)  pink
	colorslib.black,     --8)  gray
	colorslib.gray,      --9)  lightGray
	colorslib.blue,      --10) cyan
	colorslib.blue,      --11) purple
	colorslib.brown,     --12) blue
	colorslib.black,     --13) brown
	colorslib.gray,      --14) green
	colorslib.brown,     --15) red
	colorslib.gray       --16) black
}

function gui.hideExtension(screen, path)
	local name = paths.name(path)
	if gui_container.viewFileExps[screen] then
		return name
	else
		return paths.hideExtension(name)
	end
end

function gui.hideExtensionPath(screen, path)
	if gui_container.viewFileExps[screen] then
		return path
	else
		return paths.hideExtension(path)
	end
end

function gui.fpath(screen, path, maxlen, endcheck)
	local lpath = gui.hideExtensionPath(screen, gui_container.toUserPath(screen, path))
	if maxlen then
		return gui_container.short(lpath, maxlen, endcheck)
	end
	return lpath
end

function gui.isVisible(screen, path)
	return gui_container.hiddenFiles[screen] or not fs.getAttribute(path, "hidden")
end

------------------------------------

local shot = graphic.screenshot
function graphic.screenshot(screen, x, y, sx, sy)
	local rx, ry = graphic.getResolution(screen)
	x = x or 1
	y = y or 1
	sx = sx or rx
	sy = sy or ry
	if x and sx and y and sy and screen then
		if registry.shadowMode == "round" then
			x = x - 2
			y = y - 1
			sx = sx + 2
			sy = sy + 1
		elseif registry.shadowMode == "screen" then
			x = 1
			y = 1
			sx = rx
			sy = ry
		end
	end
	if x < 1 then x = 1 end
	if y < 1 then y = 1 end
	return shot(screen, x, y, sx, sy)
end

------------------------------------

gui.zoneX = 32
gui.zoneY = 8

gui.bigZoneX = 50
gui.bigZoneY = 16

gui.veryBigZoneX = 60
gui.veryBigZoneY = 18

gui.scrShadow = {}

function gui.hideScreen(screen)
	pcall(component.invoke, screen, "turnOff")    
	return function ()
		pcall(component.invoke, screen, "turnOn")
	end
end

function gui.bwSize(screen)
	local rx, ry = graphic.getResolution(screen)
	if rx <= 50 then
		return 50, 16
	else
		return 60, 18
	end
end

function gui.getZone(screen)
	local cx, cy = graphic.getResolution(screen)
	cx = cx / 2
	cy = cy / 2
	cx = cx - 16
	cy = cy - 4
	cx = math.round(cx) + 1
	cy = math.round(cy) + 1
	return cx, cy, 34, 9
end

function gui.getBigZone(screen)
	local cx, cy = graphic.getResolution(screen)
	cx = cx / 2
	cy = cy / 2
	cx = cx - 25
	cy = cy - 8
	cx = math.round(cx) + 1
	cy = math.round(cy) + 1
	return cx, cy, 52, 17
end

function gui.getCustomZone(screen, sx, sy)
	local cx, cy = graphic.getResolution(screen)
	cx = cx / 2
	cy = cy / 2
	cx = cx - math.round(sx / 2)
	cy = cy - math.round(sy / 2)
	cx = math.round(cx) + 1
	cy = math.round(cy) + 1
	return cx, cy, sx + 2, sy + 1
end

function gui.saveZone(screen)
	return graphic.screenshot(screen, gui.getZone(screen))
end

function gui.saveBigZone(screen)
	local bwSizeX, bwSizeY = gui.bwSize(screen)
	return graphic.screenshot(screen, gui.getCustomZone(screen, bwSizeX, bwSizeY))
end

------------------------------------

function gui.getShadowWindow(screen, x, y, sx, sy, withWindow)
	local shadowMode = registry.shadowMode
	local gpu = graphic.findGpu(screen)
	local rx, ry = gpu.getResolution()
	local x2, y2, sx2, sy2
	if shadowMode == "screen" then
		x2, y2, sx2, sy2 = 1, 1, rx, ry
	elseif shadowMode == "round" then
		x2, y2, sx2, sy2 = x - 2, y - 1, sx + 4, sy + 2
	elseif shadowMode == "full" then
		if withWindow then
			x2, y2, sx2, sy2 = x, y, sx + 2, sy + 1
		else
			x2, y2, sx2, sy2 = x + 2, y + 1, sx, sy
		end
	else
		if withWindow then
			x2, y2, sx2, sy2 = x, y, sx + 1, sy + 1
		else
			x2, y2, sx2, sy2 = x + 1, y + 1, sx, sy
		end
	end
	if x2 < 1 then x2 = 1 end
	if y2 < 1 then y2 = 1 end
	if sx2 > rx then sx2 = rx end
	if sy2 > ry then sy2 = ry end
	return x2, y2, sx2, sy2
end

function gui.shadow(screen, x, y, sx, sy, mul, full, noSaveShadowState)
	if gui.skipShadow then
		gui.skipShadow = nil
		return
	end

	local gpu
	if type(screen) == "table" then
		gpu = screen
		screen = gpu.getScreen()
	else
		gpu = graphic.findGpu(screen)
	end
	local depth = graphic.getDepth(screen)

	mul = mul or 0.4
	local scr
	if not full and registry.shadowMode == "screen" then
		local rx, ry = gpu.getResolution()
		x = 1
		y = 1
		sx = rx
		sy = ry
		full = true

		if not noSaveShadowState then
			scr = true
			gui.scrShadow[screen] = (gui.scrShadow[screen] or 0) + 1
		end
	end

	local function getPoses()
		local shadowPosesX = {}
		local shadowPosesY = {}

		if full then
			for cx = x, x + (sx - 1) do
				for cy = y, y + (sy - 1) do
					table.insert(shadowPosesX, cx)
					table.insert(shadowPosesY, cy)
				end
			end
		else
			if registry.shadowMode == "round" then
				for i = x, (x + sx) - 1 do
					table.insert(shadowPosesX, i)
					table.insert(shadowPosesY, y - 1)
				end
				for i = x, (x + sx) - 1 do
					table.insert(shadowPosesX, i)
					table.insert(shadowPosesY, y + sy)
				end
				for i = y - 1, y + sy do
					table.insert(shadowPosesX, x - 1)
					table.insert(shadowPosesY, i)

					table.insert(shadowPosesX, x - 2)
					table.insert(shadowPosesY, i)

					table.insert(shadowPosesX, x + sx)
					table.insert(shadowPosesY, i)

					table.insert(shadowPosesX, x + sx + 1)
					table.insert(shadowPosesY, i)
				end
			else
				for i = x + 1, (x + sx) - 1 do
					table.insert(shadowPosesX, i)
					table.insert(shadowPosesY, y + sy)
				end
				for i = y + 1, y + sy do
					table.insert(shadowPosesX, x + sx)
					table.insert(shadowPosesY, i)
	
					if registry.shadowMode == "full" then
						table.insert(shadowPosesX, x + sx + 1)
						table.insert(shadowPosesY, i)
					end
				end
			end
		end

		return shadowPosesX, shadowPosesY
	end

	local origsX = {}
	local origsY = {}
	local origsC = {}
	local origsF = {}
	local origsB = {}
	if not require("liked").recoveryMode then
		if registry.shadowType == "advanced" then
			local shadowPosesX, shadowPosesY = getPoses()

			for i = 1, #shadowPosesX do
				local ok, char, fore, back = pcall(gpu.get, shadowPosesX[i], shadowPosesY[i])
				if ok and char and fore and back then
					table.insert(origsX, shadowPosesX[i])
					table.insert(origsY, shadowPosesY[i])
					table.insert(origsC, char)
					table.insert(origsF, fore)
					table.insert(origsB, back)

					gpu.setForeground(colorslib.colorMul(fore, mul))
					gpu.setBackground(colorslib.colorMul(back, mul))
					gpu.set(shadowPosesX[i], shadowPosesY[i], char)
				end
			end
		elseif registry.shadowType == "smart" then
			if depth > 1 then
				local shadowPosesX, shadowPosesY = getPoses()

				local function getPalCol(source)
					for i = 0, 15 do
						if gui_container.indexsColors[i + 1] == source then
							return i
						end
					end
				end

				for i = 1, #shadowPosesX do
					local ok, char, fore, back = pcall(gpu.get, shadowPosesX[i], shadowPosesY[i])
					if ok and char and fore and back then
						table.insert(origsX, shadowPosesX[i])
						table.insert(origsY, shadowPosesY[i])
						table.insert(origsC, char)
						table.insert(origsF, fore)
						table.insert(origsB, back)

						local forePal = getPalCol(fore)
						if forePal then
							gpu.setForeground(gui_container.indexsColors[gui.smartShadowsColors[forePal + 1] + 1])
						else
							gpu.setForeground(colorslib.colorMul(fore, mul))
						end
						
						local backPal = getPalCol(back)
						if backPal then
							gpu.setBackground(gui_container.indexsColors[gui.smartShadowsColors[backPal + 1] + 1])
						else
							gpu.setBackground(colorslib.colorMul(back, mul))
						end

						gpu.set(shadowPosesX[i], shadowPosesY[i], char)
					end
				end
			end
		elseif registry.shadowType == "simple" then
			local shadowPosesX, shadowPosesY = getPoses()
			for i = 1, #shadowPosesX do
				local ok, char, fore, back, forePal, backPal = pcall(gpu.get, shadowPosesX[i], shadowPosesY[i])
				if ok and char and fore and back then
					table.insert(origsX, shadowPosesX[i])
					table.insert(origsY, shadowPosesY[i])
					table.insert(origsC, char)
					table.insert(origsF, fore)
					table.insert(origsB, back)
				end
			end

			gpu.setBackground(colors.gray)
			if full then
				gpu.fill(x, y, sx, sy, " ")
			else
				if registry.shadowMode == "compact" then
					gpu.fill(x + 1, y + 1, sx, sy, " ")
				elseif registry.shadowMode == "full" then
					gpu.fill(x + 1, y + 1, sx + 1, sy, " ")
				elseif registry.shadowMode == "round" then
					gpu.fill(x - 2, y - 1, sx + 4, sy + 2, " ")
				end
			end
		end
	end

	local cleared
	return function ()
		if cleared then
			return
		end
		cleared = true

		if scr then
			gui.scrShadow[screen] = gui.scrShadow[screen] - 1
		end

		local gpu = graphic.findGpu(screen)
		for i, x in ipairs(origsX) do
			gpu.setForeground(origsF[i])
			gpu.setBackground(origsB[i])
			gpu.set(x, origsY[i], origsC[i])
		end
		
		origsX = nil
		origsY = nil
		origsC = nil
		origsF = nil
		origsB = nil
	end
end

function gui.pleaseType(screen, str, tostr)
	tostr = tostr or "confirm"
	while true do
		local input = gui.input(screen, nil, nil, "TYPE '" .. str .. "' TO " .. tostr:upper())
		if input then
			if input == str then
				return true
			else
				gui.warn(screen, nil, nil, "to " .. tostr .. ", you need to type '" .. str .. "'")
			end
		else
			return false
		end
	end
end

function gui.smallWindow(screen, cx, cy, str, backgroundColor, icon, sx, sy, noSaveShadowState)
	sx = sx or 32
	sy = sy or 8

	if not cx or not cy then
		cx, cy = gui.getCustomZone(screen, sx, sy)
	end

	local window = graphic.createWindow(screen, cx, cy, sx, sy, true)

	local color = backgroundColor or colors.lightGray

	--window:fill(2, 2, window.sizeX, window.sizeY, colors.gray, 0, " ")
	local noShadow = gui.shadow(screen, window.x, window.y, window.sizeX, window.sizeY, nil, nil, noSaveShadowState)
	window:clear(color)

	local textColor = colors.white
	if color == textColor then
		textColor = colors.black
	end
	if str then
		for i, v in ipairs(parser.parseTraceback(str, sx - 9, sy - 3)) do
			window:set(8, i + 1, color, textColor, v)
		end
	end

	if icon then
		icon(window, color)
	end

	return window, noShadow
end

function gui.customWindow(screen, sx, sy)
	sx = sx or 50
	sy = sy or 16

	local cx, cy = gui.getCustomZone(screen, sx, sy)
	local clear = graphic.screenshot(screen, cx, cy, sx, sy)
	local window = graphic.createWindow(screen, cx, cy, sx, sy, true)
	gui.shadow(screen, cx, cy, sx, sy)

	return window, clear
end

function gui.status(screen, cx, cy, str, backgroundColor)
	local window, noShadow = gui.smallWindow(screen, cx, cy, str, backgroundColor or colors.lightGray, function (window, color)
		window:set(2, 1, color, colors.blue, "  " .. unicode.char(0x2800+192) ..  "  ")
		window:set(2, 2, color, colors.blue, " ◢█◣ ")
		window:set(2, 3, color, colors.blue, "◢███◣")
		window:set(4, 2, colors.blue, colors.white, "P")
	end, nil, nil, true)
	graphic.forceUpdate(screen)
	event.yield()
	return window, noShadow
end

function gui.warn(screen, cx, cy, str, backgroundColor)
	local window, noShadow = gui.smallWindow(screen, cx, cy, str, backgroundColor, function (window, color)
		window:set(2, 1, color, colors.orange, "  " .. unicode.char(0x2800+192) ..  "  ")
		window:set(2, 2, color, colors.orange, " ◢█◣ ")
		window:set(2, 3, color, colors.orange, "◢███◣")
		window:set(4, 2, colors.orange, colors.white, "!")
	end)

	window:set(32 - 4, 7, colors.lightBlue, colors.white, " OK ")
	local function drawYes()
		window:set(32 - 4, 7, colors.blue, colors.white, " OK ")
		graphic.forceUpdate(screen)
		event.sleep(0.1)
	end

	graphic.forceUpdate(screen)
	if registry.soundEnable then
		sound.warn()
	end

	while true do
		local eventData = {computer.pullSignal()}
		local windowEventData = window:uploadEvent(eventData)
		if windowEventData[1] == "touch" and windowEventData[5] == 0 then
			if windowEventData[4] == 7 and windowEventData[3] > (32 - 5) and windowEventData[3] <= ((32 - 5) + 4) then
				drawYes()
				break
			end
		elseif windowEventData[1] == "key_down" and windowEventData[4] == 28 then
			drawYes()
			break
		end
	end
	noShadow()
end

function gui.simpleWarn(screen, cx, cy, str, backgroundColor)
	local window, noShadow = gui.smallWindow(screen, cx, cy, str, backgroundColor, function (window, color)
		window:set(2, 1, color, colors.orange, "  " .. unicode.char(0x2800+192) ..  "  ")
		window:set(2, 2, color, colors.orange, " ◢█◣ ")
		window:set(2, 3, color, colors.orange, "◢███◣")
		window:set(4, 2, colors.orange, colors.white, "!")
	end)

	graphic.forceUpdate(screen)
	if registry.soundEnable then
		sound.warn()
	end
end

function gui.done(screen, cx, cy, str, backgroundColor)
	local window, noShadow = gui.smallWindow(screen, cx, cy, str, backgroundColor, function (window, color)
		window:set(2, 1, color, colors.green, "  " .. unicode.char(0x2800+192) ..  "  ")
		window:set(2, 2, color, colors.green, " ◢█◣ ")
		window:set(2, 3, color, colors.green, "◢███◣")
		window:set(4, 2, colors.green, colors.white, "~")
	end)

	window:set(32 - 4, 7, colors.lightBlue, colors.white, " OK ")
	local function drawYes()
		window:set(32 - 4, 7, colors.blue, colors.white, " OK ")
		graphic.forceUpdate(screen)
		event.sleep(0.1)
	end

	graphic.forceUpdate(screen)
	if registry.soundEnable then
		sound.done()
	end

	while true do
		local eventData = {computer.pullSignal()}
		local windowEventData = window:uploadEvent(eventData)
		if windowEventData[1] == "touch" and windowEventData[5] == 0 then
			if windowEventData[4] == 7 and windowEventData[3] > (32 - 5) and windowEventData[3] <= ((32 - 5) + 4) then
				drawYes()
				break
			end
		elseif windowEventData[1] == "key_down" and windowEventData[4] == 28 then
			drawYes()
			break
		end
	end
	noShadow()
end

function gui.bigWarn(screen, cx, cy, str, backgroundColor)
	local bwSizeX, bwSizeY = gui.bwSize(screen)

	local window, noShadow = gui.smallWindow(screen, cx, cy, str, backgroundColor, function (window, color)
		window:set(2, 1, color, colors.orange, "  " .. unicode.char(0x2800+192) ..  "  ")
		window:set(2, 2, color, colors.orange, " ◢█◣ ")
		window:set(2, 3, color, colors.orange, "◢███◣")
		window:set(4, 2, colors.orange, colors.white, "!")
	end, bwSizeX, bwSizeY)

	window:set(bwSizeX - 4, bwSizeY - 1, colors.lightBlue, colors.white, " OK ")
	local function drawYes()
		window:set(bwSizeX - 4, bwSizeY - 1, colors.blue, colors.white, " OK ")
		graphic.forceUpdate(screen)
		event.sleep(0.1)
	end

	graphic.forceUpdate(screen)
	if registry.soundEnable then
		sound.warn()
	end

	while true do
		local eventData = {computer.pullSignal()}
		local windowEventData = window:uploadEvent(eventData)
		if windowEventData[1] == "touch" and windowEventData[5] == 0 then
			if windowEventData[4] == (bwSizeY - 1) and windowEventData[3] > (bwSizeX - 5) and windowEventData[3] <= ((bwSizeX - 5) + 4) then
				drawYes()
				break
			end
		elseif windowEventData[1] == "key_down" and windowEventData[4] == 28 then
			drawYes()
			break
		end
	end
	noShadow()
end

function gui.pleaseCharge(screen, minCharge, str)
	minCharge = minCharge or 40
	str = str or "this action"

	if system.getCharge() >= minCharge then return true end

	local clear = gui.saveZone(screen)

	local window = gui.smallWindow(screen, nil, nil, "in order to make " .. str .. ",\nthe charge level of the device must be at least " .. tostring(math.floor(minCharge)) .. "%", nil, function (window, color)
		window:set(2, 1, color, colors.red, "  " .. unicode.char(0x2800+192) ..  "  ")
		window:set(2, 2, color, colors.red, " ◢█◣ ")
		window:set(2, 3, color, colors.red, "◢███◣")
		window:set(4, 2, colors.red, colors.white, "!")
	end)

	window:set(32 - 4, 7, colors.lightBlue, colors.white, " OK ")
	local function drawYes()
		window:set(32 - 4, 7, colors.blue, colors.white, " OK ")
		graphic.forceUpdate(screen)
		event.sleep(0.1)
	end

	graphic.forceUpdate(screen)
	if registry.soundEnable then
		sound.warn()
	end

	while true do
		local eventData = {computer.pullSignal()}
		local windowEventData = window:uploadEvent(eventData)
		if windowEventData[1] == "touch" and windowEventData[5] == 0 then
			if windowEventData[4] == 7 and windowEventData[3] > (32 - 5) and windowEventData[3] <= ((32 - 5) + 4) then
				drawYes()
				clear()
				return false
			end
		elseif windowEventData[1] == "key_down" and windowEventData[4] == 28 then
			drawYes()
			clear()
			return false
		end
	end
end

function gui.pleaseSpace(screen, minSpace, str)
	minSpace = minSpace or 64
	str = str or "this action"

	local root = fs.get("/")
	if (root.spaceTotal() - root.spaceUsed()) >= minSpace then return true end

	local clear = gui.saveZone(screen)

	local window = gui.smallWindow(screen, nil, nil, "in order to make " .. str .. ",\nyou need a minimum " .. tostring(math.floor(minSpace)) .. "KB space", nil, function (window, color)
		window:set(2, 1, color, colors.red, "  " .. unicode.char(0x2800+192) ..  "  ")
		window:set(2, 2, color, colors.red, " ◢█◣ ")
		window:set(2, 3, color, colors.red, "◢███◣")
		window:set(4, 2, colors.red, colors.white, "!")
	end)

	window:set(32 - 4, 7, colors.lightBlue, colors.white, " OK ")
	local function drawYes()
		window:set(32 - 4, 7, colors.blue, colors.white, " OK ")
		graphic.forceUpdate(screen)
		event.sleep(0.1)
	end

	graphic.forceUpdate(screen)
	if registry.soundEnable then
		sound.warn()
	end

	while true do
		local eventData = {computer.pullSignal()}
		local windowEventData = window:uploadEvent(eventData)
		if windowEventData[1] == "touch" and windowEventData[5] == 0 then
			if windowEventData[4] == 7 and windowEventData[3] > (32 - 5) and windowEventData[3] <= ((32 - 5) + 4) then
				drawYes()
				clear()
				return false
			end
		elseif windowEventData[1] == "key_down" and windowEventData[4] == 28 then
			drawYes()
			clear()
			return false
		end
	end
end

function gui.selectcolor(screen, cx, cy, str)
	--◢▲◣▲▴▴
	local gpu = graphic.findGpu(screen)

	if not cx or not cy then
		cx, cy = gpu.getResolution()
		cx = cx / 2
		cy = cy / 2
		cx = cx - 12
		cy = cy - 6
		cx = math.round(cx) + 1
		cy = math.round(cy) + 1
	end

	local window = graphic.createWindow(screen, cx, cy, 24, 12, true)
	local noShadow = gui.shadow(screen, window.x, window.y, window.sizeX, window.sizeY)
	window:clear(colors.gray)
	window:fill(3, 2, 20, 10, colors.brown, colors.white, "▒")
	window:set(2, 1, colors.gray, colors.white, str or "select color")
	window:set(window.sizeX, 1, colors.red, colors.white, "X")

	local cols = {}
	for i = 1, 12 do
		cols[i] = {}
	end
	for x = 0, 3 do
		for y = 0, 3 do
			local colNum = x + (y * 4)
			local col = colors[colorslib[colNum]]
			local setX, setY = 5 + (x * 4), 3 + (y * 2)
			window:set(setX, setY, col, 0, "    ")
			window:set(setX, setY + 1, col, 0, "    ")
			for addY = 0, 1 do
				for addX = 0, 3 do
					cols[setY + addY][setX + addX] = colNum
				end
			end
		end
	end
	graphic.forceUpdate(screen)

	while true do
		local eventData = {computer.pullSignal()}
		local windowEventData = window:uploadEvent(eventData)
		if windowEventData[1] == "touch" then
			if windowEventData[3] == window.sizeX and windowEventData[4] == 1 then
				noShadow()
				return
			elseif cols[windowEventData[4]] and cols[windowEventData[4]][windowEventData[3]] then
				noShadow()
				return cols[windowEventData[4]][windowEventData[3]]
			end
		end
	end
end

function gui.selectfullcolor(screen, cx, cy, str)
	local col = gui.selectcolor(screen, cx, cy, str)
	if col and colorslib[col] and colors[colorslib[col]] then
		return colors[colorslib[col]]
	end
end

function gui.input(screen, cx, cy, str, hidden, backgroundColor, default, disableStartSound, noCancel)
	local gpu = graphic.findGpu(screen)

	if not cx or not cy then
		cx, cy = gui.getZone(screen)
	end

	local window = graphic.createWindow(screen, cx, cy, 32, 8, true)

	--window:fill(2, 2, window.sizeX, window.sizeY, colors.gray, 0, " ")
	local noShadow = gui.shadow(screen, window.x, window.y, window.sizeX, window.sizeY)
	window:clear(backgroundColor or colors.lightGray)

	local pos = math.round((window.sizeX / 2) - (unicode.wlen(str) / 2)) + 1
	window:fill(1, 1, window.sizeX, 1, colors.gray, 0, " ")
	window:set(pos, 1, colors.gray, colors.white, str)

	window:set(32 - 4 - 3, 7, colors.lightBlue, colors.white, " enter ")
	if not noCancel then
		window:set(2, 7, colors.red, colors.white, " cancel ")
	end

	local reader = window:read(2, 3, window.sizeX - 2, colors.gray, colors.white, nil, hidden, default)

	graphic.forceUpdate(screen)
	if registry.soundEnable and not disableStartSound then
		sound.input()
	end

	local function drawOk()
		window:set(32 - 4 - 3, 7, colors.blue, colors.white, " enter ")
		graphic.forceUpdate(screen)
		event.sleep(0.1)
	end

	local function drawCancel()
		window:set(2, 7, colors.brown, colors.white, " cancel ")
		graphic.forceUpdate(screen)
		event.sleep(0.1)
	end

	while true do
		local eventData = {event.pull()}
		local windowEventData = window:uploadEvent(eventData)
		local out = reader.uploadEvent(eventData)
		if out then
			if out == true then
				if not noCancel then
					drawCancel()
					noShadow()
					return false
				end
			else
				drawOk()
				noShadow()
				return out
			end
		end

		if windowEventData[1] == "touch" and windowEventData[5] == 0 then
			if windowEventData[4] == 7 and windowEventData[3] > (32 - 5 - 3) and windowEventData[3] <= ((32 - 5) + 4) then
				drawOk()
				noShadow()
				return reader.getBuffer()
			elseif windowEventData[4] == 7 and windowEventData[3] >= 2 and windowEventData[3] <= (2 + 7) then
				if not noCancel then
					drawCancel()
					noShadow()
					return false
				end
			end
		end
	end
end

function gui.contextPos(screen, posX, posY, strs)
	local gpu = graphic.findGpu(screen)
	local rx, ry = gpu.getResolution()
	local drawStrs = gui.contextStrs(strs)

	local sizeX, sizeY = 0, #drawStrs
	for i, v in ipairs(drawStrs) do
		if type(v) == "string" and unicode.wlen(v) > sizeX then
			sizeX = unicode.wlen(v)
		end
	end
	sizeX = sizeX + 1
	while posX + (sizeX - 1) > rx do
		posX = posX - 1
	end
	while posY + (sizeY - 1) > ry do
		posY = posY - 1
	end

	return posX, posY, sizeX, sizeY
end

function gui.contextStrs(strs)
	local drawStrs = {}
	for index, value in ipairs(strs) do
		if type(value) == "string" then
			if value:sub(1, 2) ~= "  " then
				drawStrs[index] = "  " .. value
			else
				drawStrs[index] = value
			end
		else
			drawStrs[index] = value
		end
	end
	return drawStrs
end

function gui.blackCall(func, ...)
	local oldBlackState = gui.blackMode
	gui.blackMode = true
	func(...)
	gui.blackMode = oldBlackState
end

function gui.context(screen, posX, posY, strs, active, disShadow)
	local white, black = colors.white, colors.black
	if gui.blackMode then
		white, black = black, white
	end

	local gpu = graphic.findGpu(screen)
	local drawStrs = gui.contextStrs(strs)
	local posX, posY, sizeX, sizeY = gui.contextPos(screen, posX, posY, drawStrs)
	local sep = string.rep(gui_container.chars.splitLine, sizeX)

	local window = graphic.createWindow(screen, posX, posY, sizeX, sizeY)
	--window:fill(2, 2, window.sizeX, window.sizeY, colors.gray, 0, " ")
	local clearShadow
	if not disShadow then
		clearShadow = gui.shadow(screen, window.x, window.y, window.sizeX, window.sizeY)
	end

	local function redrawStrs(selected)
		for i, str in ipairs(drawStrs) do
			local isSep
			if str == true then
				isSep = true
				str = sep
			end

			local color = white
			local color2 = black
			if (not active or active[i]) and not isSep then
				if selected == i then
					color = colors.blue
					color2 = colors.white
				end
				window:set(1, i, color, color2, str .. (string.rep(" ", sizeX - unicode.wlen(str))))
			else
				window:set(1, i, color, colors.lightGray, str .. (string.rep(" ", sizeX - unicode.wlen(str))))
			end
		end
		graphic.forceUpdate(screen)
	end
	redrawStrs()

	local selectedNum
	while true do
		local eventData = {computer.pullSignal()}
		if eventData[2] == screen then
			local windowEventData = window:uploadEvent(eventData)
			if windowEventData[1] == "drop" and windowEventData[5] == 0 then
				local num = windowEventData[4]
				if not active or active[num] then
					event.sleep(0.05)
					if clearShadow then clearShadow() end
					return strs[num], num
				end
			elseif (windowEventData[1] == "touch" or windowEventData[1] == "drag") and windowEventData[5] == 0 then
				if windowEventData[1] == "touch" and selectedNum and selectedNum == windowEventData[4] then
					if not active or active[selectedNum] then
						event.sleep(0.05)
						if clearShadow then clearShadow() end
						return strs[selectedNum], selectedNum
					end
				end
				redrawStrs(windowEventData[4])
				selectedNum = windowEventData[4]
			elseif eventData[1] == "drag" then
				selectedNum = nil
				redrawStrs()
			elseif eventData[1] == "touch" or eventData[1] == "scroll" then
				event.push(table.unpack(eventData))
				if clearShadow then clearShadow() end
				return nil, nil
			end
		end
	end
end

function gui.contextAuto(screen, posX, posY, strs, active)
	local posX, posY, sizeX, sizeY = gui.contextPos(screen, posX, posY, strs)
	local clear = graphic.screenshot(screen, posX, posY, sizeX + 2, sizeY + 1)
	local result = {gui.context(screen, posX, posY, strs, active)}
	clear()
	return table.unpack(result)
end

function gui.contextFunc(screen, posX, posY, strs, active, funcs)
	local posX, posY, sizeX, sizeY = gui.contextPos(screen, posX, posY, strs)
	local clear = graphic.screenshot(screen, posX, posY, sizeX + 2, sizeY + 1)
	local _, num = gui.context(screen, posX, posY, strs, active)
	clear()
	if num and funcs and funcs[num] then
		funcs[num]()
	end
end

--[[
{
	{
		title = "title",
		active = true,
		callback = function()

			return true --return from context
		end
	},
	true, --break line
	{
		title = "menu",
		active = true,
		menu = {
			{
				title = "1",
				active = true,
				callback = function() end
			},
			{
				title = "2",
				active = true,
				callback = function() end
			},
			{
				title = "3",
				active = true,
				callback = function() end
			}
		}
	}
}
]]

function gui.actionContext(screen, x, y, actions, isParent)
	local gpu = graphic.findGpu(screen)
	
	local selected
	local sizeX = 0
	local sizeY = #actions
	for i, action in ipairs(actions) do
		if type(action) == "table" then
			local title = action.title
			if #title > sizeX then
				sizeX = #title
			end
		end
	end
	sizeX = sizeX + 3

	local rx, ry = gpu.getResolution()
	x = math.min(x, (rx - sizeX) + 1)
	y = math.min(y, (ry - sizeY) + 1)

	local window = graphic.createWindow(screen, x, y, sizeX, sizeY)
	local clear
	if not isParent or registry.shadowMode ~= "screen" then
		clear = graphic.screenshot(screen, gui.getShadowWindow(screen, x, y, sizeX, sizeY, true))
		gui.shadow(screen, x, y, sizeX, sizeY)
	else
		clear = graphic.screenshot(screen, x, y, sizeX, sizeY)
	end

	for i, action in ipairs(actions) do
		if type(action) == "table" and action.active == nil then
			action.active = true
		end
	end

	local function redraw(noRedrawShadow)
		for i, action in ipairs(actions) do
			if action == true then
				window:fill(1, i, sizeX, 1, colors.white, colors.lightGray, gui_container.chars.splitLine)
			else
				if i == selected then
					window:fill(1, i, sizeX, 1, colors.blue, 0, " ")
					window:set(3, i, colors.blue, colors.white, action.title)
					if action.menu then
						window:set(sizeX, i, colors.blue, colors.white, ">")
					end
				else
					local col = action.active and colors.black or colors.lightGray
					window:fill(1, i, sizeX, 1, colors.white, 0, " ")
					window:set(3, i, colors.white, col, action.title)
					if action.menu then
						window:set(sizeX, i, colors.white, col, ">")
					end
				end
			end
		end
		graphic.update(screen)
	end
	redraw()

	while true do
		local eventData = {event.pull()}
		local isClick = eventData[1] == "touch"
		if eventData[1] == "scroll" then
			event.push(table.unpack(eventData))
			break
		elseif isClick or eventData[1] == "drag" then
			selected = nil
			local newSelected = (eventData[4] - y) + 1
			if eventData[3] >= x and eventData[3] < x + sizeX then
				if newSelected >= 1 and newSelected <= #actions then
					if eventData[5] == 0 then
						if type(actions[newSelected]) == "table" and actions[newSelected].active then
							selected = newSelected
						end
					elseif isClick then
						event.push(table.unpack(eventData))
						break
					end
				elseif isClick then
					event.push(table.unpack(eventData))
					break
				end
			elseif isClick then
				event.push(table.unpack(eventData))
				break
			end
			redraw()
		elseif eventData[1] == "drop" then
			if selected then
				local action = actions[selected]
				if type(action) == "table" and action.callback then
					if action.callback == true or action:callback() then
						clear()
						return selected
					end
					selected = nil
					redraw()
				elseif action.menu then
					if actions.redrawCallback then
						actions.redrawCallback()
						redraw()
						if not action.menu.redrawCallback then
							action.menu.redrawCallback = actions.redrawCallback
						end
					end
					if gui.actionContext(screen, x + sizeX, eventData[4], action.menu, true) then
						clear()
						return selected
					end
				else
					clear()
					return selected
				end
			end
		end
	end
	clear()
end

function gui.drawtext(screen, posX, posY, foreground, text)
	local gpu = graphic.findGpu(screen)

	------------------------------------

	gpu.setForeground(foreground)

	local buff = ""
	local oldBack, oldI
	for i = 1, unicode.wlen(text) do
		local ok, char, fore, back = pcall(gpu.get, posX + (i - 1), posY)
		if ok then
			oldI = oldI or i
			oldBack = oldBack or back
			if back ~= oldBack then
				gpu.setBackground(oldBack)
				gpu.set(posX + (oldI - 1), posY, buff)

				buff = ""
				oldBack = back
				oldI = i
			end
			buff = buff .. unicode.sub(text, i, i)
		end
	end

	if oldBack then
		gpu.setBackground(oldBack)
		gpu.set(posX + (oldI - 1), posY, buff)
	end
end

function gui.select(screen, cx, cy, label, actions, scroll, noCloseButton, overlay, windowEventCallback, noCleanShadow, disableShadow, alwaysConfirm)
	--=gui_select(screen, nil, nil, "LOLZ", {"test 1", "test 2", "test 3"})

	local gpu = graphic.findGpu(screen)
	if not cx or not cy then
		cx, cy = gui.getBigZone(screen)
	end

	local window = graphic.createWindow(screen, cx, cy, 50, 16, true)
	local noShadow
	if not disableShadow then
		noShadow = gui.shadow(screen, cx, cy, 50, 16)
	end

	--------------------------------------------

	scroll = scroll or 0
	local addrs
	local addrsIdx
	local sel

	local function drawScrollBar()
		window:fill(window.sizeX, 2, 1, window.sizeY - 2, colors.brown, 0, " ")
		if #actions == 1 then
			window:set(window.sizeX, 2, colors.white, 0, " ")
		else
			window:set(window.sizeX, math.round(math.map(scroll, 0, #actions - 1, 2, window.sizeY - 1)), colors.white, 0, " ")
		end
	end

	local function redrawButton()
		window:set(window.sizeX - 9, window.sizeY, (sel or alwaysConfirm) and colors.lime or colors.green, colors.white, " CONFIRM ")
	end

	local function drawBase()
		--window:clear(colors.brown)
		window:fill(1, 1, window.sizeX, 1, colors.lightGray, 0, " ")
		if label then
			window:set(2, 1, colors.lightGray, colors.white, label)
		end
		if not noCloseButton then
			window:set(window.sizeX - 2, 1, colors.red, colors.white, " X ")
		end
		window:fill(1, window.sizeY, window.sizeX, 1, colors.lightGray, 0, " ")
		if overlay then
			local ret = overlay(window)
			if ret ~= nil then
				alwaysConfirm = ret
			end
		end
		redrawButton()
	end

	local function getCol(idx, color)
		return sel == idx and colors.blue or color
	end

	local function parseAction(action)
		if type(action) == "table" then
			return action[1], action[2]
		else
			return action, colors.black
		end
	end

	local function draw(pos)
		if not pos then
			drawBase()
		end
		
		addrs = {}
		addrsIdx = {}
		local lastLine = 1
		for index, action in ipairs(actions) do
			local y = (index + 1) - scroll
			if y >= 2 and y < window.sizeY then
				local astr, acol = parseAction(action)

				if not pos or pos == index then
					window:fill(1, y, window.sizeX - 1, 1, getCol(index, acol), colors.white, " ")
					window:set(2, y, getCol(index, acol), colors.white, astr)
					lastLine = y
				end

				addrs[y] = astr
				addrsIdx[y] = index
			end
		end
		if not pos then
			lastLine = lastLine + 1
			window:fill(1, lastLine, window.sizeX - 1, window.sizeY - lastLine, colors.gray, 0, " ")
		end

		if not pos then
			drawScrollBar()
		end
	end

	local function drawUp()
		scroll = scroll - 1
		window:copy(1, 2, window.sizeX - 1, 13, 0, 1)
		
		addrs = {}
		addrsIdx = {}
		for index, action in ipairs(actions) do
			local y = (index + 1) - scroll
			if y >= 2 and y < window.sizeY then
				local astr, acol = parseAction(action)

				if y == 2 then
					window:fill(1, y, window.sizeX - 1, 1, getCol(index, acol), colors.white, " ")
					window:set(2, y, getCol(index, acol), colors.white, astr)
				end

				addrs[y] = astr
				addrsIdx[y] = index
			end
		end

		drawScrollBar()
	end

	local function drawDown()
		scroll = scroll + 1
		window:copy(1, 3, window.sizeX - 1, 13, 0, -1)
		
		local noDraw
		addrs = {}
		addrsIdx = {}
		for index, action in ipairs(actions) do
			local y = (index + 1) - scroll
			if y >= 2 and y < window.sizeY then
				local astr, acol = parseAction(action)

				if y == window.sizeY - 1 then
					window:fill(1, y, window.sizeX, 1, getCol(index, acol), 0, " ")
					window:set(2, y, getCol(index, acol), colors.white, astr)
					noDraw = true
				end

				addrs[y] = astr
				addrsIdx[y] = index
			end
		end
		if not noDraw then
			window:fill(1, window.sizeY - 1, window.sizeX - 1, 1, colors.gray, 0, " ")
		end

		drawScrollBar()
	end

	draw()

	while true do
		local eventData = {computer.pullSignal()}
		local windowEventData = window:uploadEvent(eventData)
		if windowEventCallback then
			local ret, lAlwaysConfirm = windowEventCallback(windowEventData, window)
			if ret ~= nil then
				if not noCleanShadow and noShadow then noShadow() end
				return ret, scroll, windowEventData[5], windowEventData, nil, noShadow
			end
			if alwaysConfirm ~= lAlwaysConfirm then
				alwaysConfirm = lAlwaysConfirm
				drawBase()
			end
		end

		if windowEventData[1] == "touch" then
			if windowEventData[3] >= window.sizeX - 2 and windowEventData[4] == 1 then
				if not noCloseButton then
					if not noCleanShadow and noShadow then noShadow() end
					return nil, scroll, windowEventData[5], windowEventData, nil, noShadow
				end
			elseif windowEventData[3] >= window.sizeX - 9 and windowEventData[3] < window.sizeX and windowEventData[4] == window.sizeY then
				if sel or alwaysConfirm then
					if not noCleanShadow and noShadow then noShadow() end
					return sel, scroll, windowEventData[5], windowEventData, true, noShadow
				end
			end
		end

		if windowEventData[1] == "touch" or windowEventData[1] == "drag" then
			if addrsIdx[windowEventData[4]] and windowEventData[3] < window.sizeX and windowEventData[4] < window.sizeY then
				if windowEventData[5] == 1 and (not sel or sel ~= addrsIdx[windowEventData[4]]) then
					local oldsel = sel
					sel = addrsIdx[windowEventData[4]]
					if sel ~= oldsel then
						if oldsel then
							draw(oldsel)
						end
						if sel then
							draw(sel)
						end
						redrawButton()
					end
				end
				if windowEventData[1] == "touch" and sel and sel == addrsIdx[windowEventData[4]] then
					draw(sel)
					redrawButton()
					if not noCleanShadow and noShadow then noShadow() end
					return sel, scroll, windowEventData[5], windowEventData, nil, noShadow
				end
				local oldsel = sel
				sel = addrsIdx[windowEventData[4]]
				if sel ~= oldsel then
					if oldsel then
						draw(oldsel)
					end
					if sel then
						draw(sel)
					end
					redrawButton()
				end
			elseif sel then
				local lsel = sel
				sel = nil
				draw(lsel)
				redrawButton()
			end

			if windowEventData[3] == window.sizeX and windowEventData[4] < window.sizeY and windowEventData[4] > 1 then
				scroll = math.mapRound(windowEventData[4], 2, window.sizeY - 1, 0, #actions - 1)
				if scroll > #actions - 1 then scroll = #actions - 1 end
				if scroll < 0 then scroll = 0 end
				draw()
			end
		end

		if windowEventData[1] == "scroll" then
			if windowEventData[5] > 0 then
				if scroll > 0 then
					drawUp()
				end
			else
				if scroll < #actions - 1 then
					drawDown()
				end
			end
		end
	end
end

function gui.selectcomponent(screen, cx, cy, types, allowAutoConfirm, control, callbacks, blacklist, disableShadow) --=gui_selectcomponent(screen, nil, nil, {"computer"}, true)
	local advLabeling = require("advLabeling")
	local vcomponent = require("vcomponent")

	if types and type(types) ~= "table" then
		types = {types}
	end

	if not cx or not cy then
		cx, cy = gui.getBigZone(screen)
	end
	local checkWindow = graphic.createWindow(screen, cx, cy, 50, 16)

	local function allTypes()
		types = {}
		local added = {}
		for addr, ctype in component.list() do
			if not added[ctype] then
				table.insert(types, ctype)
				added[ctype] = true
			end
		end
		table.sort(types)
	end

	local allTypesFlag
	local typesstr = "select "
	if types then
		typesstr = typesstr .. table.concat(types, "/")
	else
		typesstr = typesstr .. "component"
		allTypesFlag = true
	end
	if control then
		typesstr = "components"
	end

	local cancel, out
	local gNoShadow
	local selfAddress = computer.address()

	local th
	th = thread.create(function ()
		if allTypesFlag then
			allTypes()
		end

		local scroll
		local shadowDrawed
		if disableShadow then
			shadowDrawed = true
		end

		while true do
			local strs = {}
			local addresses = {}

			for _, ctype in ipairs(types) do
				local addrs = {}
				for addr in component.list(ctype, true) do
					table.insert(addrs, addr)
				end
				table.sort(addrs)
				for _, addr in ipairs(addrs) do
					if not blacklist or not table.exists(blacklist, addr) then
						table.insert(addresses, addr)

						local tags = {}
						if fs.bootaddress == addr then
							table.insert(tags, "system")
						elseif selfAddress == addr then
							table.insert(tags, "self")
						end
						if vcomponent.isVirtual(addr) then
							table.insert(tags, "virtual")
						end

						local ctype = component.type(addr)
						local clabel = advLabeling.getLabel(addr) or ""
						if #tags > 0 then
							clabel = clabel .. " (" .. table.concat(tags, "/") .. ")"
						end
						clabel = gui_container.short(clabel, 20)

						table.insert(strs, ctype .. string.rep(" ", 38 - unicode.wlen(ctype) - unicode.wlen(clabel)) .. clabel .. string.rep(" ", (1 - unicode.wlen(clabel)) + unicode.wlen(clabel)) .. addr:sub(1, 8))
					end
				end
			end

			if allowAutoConfirm and #addresses == 1 then
				out = addresses[1]
				th:kill()
				return
			end

			local idx, lscroll, button, eventData, _, noShadow = gui.select(screen, cx, cy, typesstr, strs, scroll, control, nil, nil, true, shadowDrawed)
			scroll = lscroll
			if not shadowDrawed then
				gNoShadow = noShadow
			end
			shadowDrawed = true

			local function openEdit(tempfile)
				local clear = graphic.screenshot(screen)
				if callbacks and callbacks.onEdit then
					callbacks.onEdit()
				end
				require("apps").execute("edit", screen, nil, tempfile, true)
				if callbacks and callbacks.onCloseEdit then
					callbacks.onCloseEdit()
				end
				clear()
				fs.remove(tempfile)
			end

			local subWindowX, subWindowY = (cx + 25) - 16, cy + 4
			if idx then
				local addr = addresses[idx]
				if button == 0 and not control then
					out = addr
					th:kill()
					return
				else
					local strs = {
						"copy name",
						"copy address",
						"set label",
						"clear label",
						"view api",
						"device info"
					}
					local px, py = checkWindow:toRealPos(eventData[3], eventData[4])
					local x, y, sx, sy = gui.contextPos(screen, px, py, strs)
					local clear = graphic.screenshot(screen, x, y, sx + 2, sy + 1)
					local _, action = gui.context(screen, x, y, strs)
					clear()
					if action == 1 then 
						clipboard.set(eventData[6], component.type(addr))
					elseif action == 2 then
						clipboard.set(eventData[6], addr)
					elseif action == 3 then
						local liked = require("liked")
						liked.umountAll()
						local str = gui.input(screen, subWindowX, subWindowY, "new name", nil, nil, advLabeling.getLabel(addr))
						if type(str) == "string" then
							advLabeling.setLabel(addr, str)
						end
						liked.mountAll()
					elseif action == 4 then
						if gui.yesno(screen, subWindowX, subWindowY, "clear label on \"" .. (advLabeling.getLabel(addr) or component.type(addr)) .. "\"?") then
							local liked = require("liked")
							liked.umountAll()
							if component.type(addr) == "filesystem" then
								if not pcall(component.invoke, addr, "setLabel", nil) then
									local clear = gui.saveZone(screen)
									gui.warn(screen, subWindowX, subWindowY, "invalid name")
									clear()
								end
							else
								advLabeling.setLabel(addr, nil)
							end
							liked.mountAll()
						end
					elseif action == 5 then
						local format = require("format")

						local tempfile = paths.concat("/tmp", component.type(addr) .. "_" .. math.round(math.random(0, 9999)) .. ".txt")
						local file = fs.open(tempfile, "wb")
						local methods = component.methods(addr)
						local maxMethodLen = 0
						for name in pairs(methods) do
							if unicode.len(name) > maxMethodLen then
								maxMethodLen = unicode.len(name)
							end
						end
						for name, direct in pairs(methods) do
							local smart = format.smartConcat()
							smart.add(1, name)
							smart.add(maxMethodLen + 2, direct and "DIRECT" or "INDIRECT")
							smart.add(maxMethodLen + 2 + 8, " - " .. (component.doc(addr, name) or "Undocumented") .. "\n")
							file.write(smart.get())
						end
						file.close()

						openEdit(tempfile)
					elseif action == 6 then
						local format = require("format")

						local ctype = component.type(addr)
						local tempfile = paths.concat("/tmp", ctype .. "_" .. math.round(math.random(0, 9999)) .. ".txt")
						local file = fs.open(tempfile, "wb")
						file.write("address - " .. tostring(addr) .. "\n")
						file.write("ctype   - " .. tostring(ctype) .. "\n")
						file.write("virtual - " .. tostring(vcomponent.isVirtual(addr)) .. "\n\n")
						local tbl = lastinfo.deviceinfo[addr] or {}
						local maxMethodLen = 0
						for name in pairs(tbl) do
							name = tostring(name)
							if unicode.len(name) > maxMethodLen then
								maxMethodLen = unicode.len(name)
							end
						end
						for k, v in pairs(tbl) do
							local smart = format.smartConcat()
							smart.add(1, tostring(k))
							smart.add(maxMethodLen + 2, "-")
							smart.add(maxMethodLen + 4, tostring(v) .. "\n")
							file.write(smart.get())
						end
						file.close()
						openEdit(tempfile)
					end
				end
			else
				cancel = true
				th:kill()
				return
			end
		end
	end)
	th:resume()
	
	while true do
		local eventData = {computer.pullSignal(0.1)}

		if cancel or out then
			if gNoShadow then gNoShadow() end
			return out
		end

		if eventData[1] == "component_added" or eventData[1] == "component_removed" then
			th:kill()
			th = thread.create(th.func)
			th:resume()
		end
	end
end

function gui.selectcomponentProxy(...)
	local addr = gui.selectcomponent(...)
	if addr then
		return component.proxy(addr)
	end
end

function gui.selectExternalFs(screen, cx, cy)
	return gui.selectcomponentProxy(screen, cx, cy, {"filesystem"}, false, false, nil, {fs.bootaddress, fs.tmpaddress})
end

function gui.comfurmPassword(screen, px, py)
	local password1 = gui.input(screen, px, py, "enter new password", true)
	if password1 then
		local password2 = gui.input(screen, px, py, "comfurm new password", true)
		if password2 then
			if password1 == password2 then
				return password1
			else
				gui.warn(screen, px, py, "passwords don't match")
			end
		end
	end
end

function gui.checkPassword(screen, cx, cy, disableStartSound, noCancel)
	local regData = registry.data
	if regData then
		if regData.password then
			local clear = gui.saveZone(screen)
			local password = gui.input(screen, cx, cy, "enter password", true, nil, nil, disableStartSound, noCancel)
			clear()

			if password then
				if require("sha256").sha256(password .. (regData.passwordSalt or "")) == regData.password then
					if regData.encrypt then
						require("efs").init(password)
					end
					return true, password
				else
					local clear = gui.saveZone(screen)
					gui.warn(screen, cx, cy, "invalid password")
					clear()
				end
			else
				return false, password --false означает что пользователь отказался от ввода пароля
			end
		else
			return true
		end
	else
		return true
	end
end

function gui.checkPasswordLoop(...)
	while true do
		local ret = gui.checkPassword(...)
		if ret ~= nil then
			return ret
		end
	end
end

function gui.yesno(screen, cx, cy, str, backgroundColor)
	local window, noShadow = gui.smallWindow(screen, cx, cy, str, backgroundColor, function (window, color)
		window:set(2, 1, color, colors.green, "  " .. unicode.char(0x2800+192) ..  "  ")
		window:set(2, 2, color, colors.green, " ◢█◣ ")
		window:set(2, 3, color, colors.green, "◢███◣")
		window:set(4, 2, colors.green, colors.white, "?")
	end)

	window:set(32 - 5, 7, colors.lime, colors.white, " yes ")
	window:set(2, 7, colors.red, colors.white, " no ")

	graphic.forceUpdate(screen)
	if registry.soundEnable then
		sound.question()
	end

	local function drawYes()
		window:set(32 - 5, 7, colors.green, colors.white, " yes ")
		graphic.forceUpdate(screen)
		event.sleep(0.1)
	end

	while true do
		local eventData = {computer.pullSignal()}
		local windowEventData = window:uploadEvent(eventData)
		if windowEventData[1] == "touch" and windowEventData[5] == 0 then
			if windowEventData[4] == 7 and windowEventData[3] > (32 - 6) and windowEventData[3] <= ((32 - 5) + 4) then
				drawYes()
				noShadow()
				return true
			elseif windowEventData[4] == 7 and windowEventData[3] >= 2 and windowEventData[3] <= (2 + 3) then
				window:set(2, 7, colors.brown, colors.white, " no ")
				graphic.forceUpdate(screen)
				event.sleep(0.1)
				noShadow()
				return false
			end
		elseif windowEventData[1] == "key_down" and windowEventData[4] == 28 then
			drawYes()
			noShadow()
			return true
		end
	end
end

function gui.nextOrCancel(screen, cx, cy, str, backgroundColor)
	local window, noShadow = gui.smallWindow(screen, cx, cy, str, backgroundColor, function (window, color)
		window:set(2, 1, color, colors.orange, "  " .. unicode.char(0x2800+192) ..  "  ")
		window:set(2, 2, color, colors.orange, " ◢█◣ ")
		window:set(2, 3, color, colors.orange, "◢███◣")
		window:set(4, 2, colors.orange, colors.white, "!")
	end, 50, 16)

	window:set(50 - 6, 15, colors.lightBlue, colors.white, " next ")
	window:set(2, 15, colors.red, colors.white, " cancel ")

	graphic.forceUpdate(screen)
	if registry.soundEnable then
		sound.warn()
	end

	local function drawYes()
		window:set(50 - 6, 15, colors.blue, colors.white, " next ")
		graphic.forceUpdate(screen)
		event.sleep(0.1)
	end

	while true do
		local eventData = {computer.pullSignal()}
		local windowEventData = window:uploadEvent(eventData)
		if windowEventData[1] == "touch" and windowEventData[5] == 0 then
			if windowEventData[4] == 15 and windowEventData[3] > (50 - 7) and windowEventData[3] <= ((50 - 5) + 4) then
				drawYes()
				noShadow()
				return true
			elseif windowEventData[4] == 15 and windowEventData[3] >= 2 and windowEventData[3] <= (2 + 3 + 4) then
				window:set(2, 15, colors.brown, colors.white, " cancel ")
				graphic.forceUpdate(screen)
				event.sleep(0.1)
				noShadow()
				return false
			end
		elseif windowEventData[1] == "key_down" and windowEventData[4] == 28 then
			drawYes()
			noShadow()
			return true
		end
	end
end

function gui.clearRun(func, screen, ...)
	local clear = gui.saveZone(screen)
	local result = {func(screen, ...)}
	clear()
	return table.unpack(result)
end

function gui.clearBigRun(func, screen, ...)
	local clear = gui.saveBigZone(screen)
	local result = {func(screen, ...)}
	clear()
	return table.unpack(result)
end

function gui.clearScreenRun(func, screen, ...)
	local clear = graphic.screenshot(screen)
	local result = {func(screen, ...)}
	clear()
	return table.unpack(result)
end

calls.loaded.gui_yesno = gui.yesno
calls.loaded.gui_warn = gui.warn
calls.loaded.gui_drawtext = gui.drawtext
calls.loaded.gui_context = gui.context
calls.loaded.gui_input = gui.input
calls.loaded.gui_select = gui.select
calls.loaded.gui_selectcomponent = gui.selectcomponent
calls.loaded.gui_checkPassword = gui.checkPassword
calls.loaded.gui_status = gui.status
calls.loaded.saveZone = gui.saveZone
calls.loaded.saveBigZone = gui.saveBigZone
return gui