local graphic = require("graphic")
local fs = require("filesystem")
local gui_container = require("gui_container")
local calls = require("calls")
local unicode = require("unicode")
local computer = require("computer")
local lastinfo = require("lastinfo")
local gui = require("gui")
local imagelib = require("image")

local colors = gui_container.colors
local indexsColors = gui_container.indexsColors

------------------------------------

local screen, nickname, filepath = ...
local gpu = graphic.findGpu(screen)
local rx, ry = gpu.getResolution()

local statusWindow = graphic.createWindow(screen, 1, 1, rx, 1)
local mainWindow = graphic.createWindow(screen, 1, 2, rx - 8, ry - 1)
local paletteWindow = graphic.createWindow(screen, rx - 7, 2, 8, 18)
local nullWindow2 = graphic.createWindow(screen, rx - 7, 2 + paletteWindow.sizeY, 8, ry - 19)

------------------------------------

local imageOffsetX
local imageOffsetY

local selectedColor1 = 1
local selectedColor2 = 1
local noSaved
local selectedChar = " "
local image = 
{
	sizeX = 8,
	sizeY = 4,

	{
		{0, 0, " "},
		{0, 0, " "},
		{0, 0, " "},
		{0, 0, " "},
		{0, 0, " "},
		{0, 0, " "},
		{0, 0, " "},
		{0, 0, " "}
	},
	{
		{0, 0, " "},
		{0, 0, " "},
		{0, 0, " "},
		{0, 0, " "},
		{0, 0, " "},
		{0, 0, " "},
		{0, 0, " "},
		{0, 0, " "}
	},
	{
		{0, 0, " "},
		{0, 0, " "},
		{0, 0, " "},
		{0, 0, " "},
		{0, 0, " "},
		{0, 0, " "},
		{0, 0, " "},
		{0, 0, " "}
	},
	{
		{0, 0, " "},
		{0, 0, " "},
		{0, 0, " "},
		{0, 0, " "},
		{0, 0, " "},
		{0, 0, " "},
		{0, 0, " "},
		{0, 0, " "}
	},
}

local function reMathOffset()
	imageOffsetX = math.round(mainWindow.sizeX / 2) - math.round(image.sizeX / 2)
	imageOffsetY = math.round(mainWindow.sizeY / 2) - math.round(image.sizeY / 2)
end
reMathOffset()

local function drawSelectedColors()
	nullWindow2:fill(1, 1, nullWindow2.sizeX, nullWindow2.sizeY, colors.green, colors.black, "▒")

	nullWindow2:set(2, nullWindow2.sizeY, colors.green, colors.black, "B")
	nullWindow2:set(nullWindow2.sizeX - 2, nullWindow2.sizeY, colors.green, colors.black, "F")
	nullWindow2:set(nullWindow2.sizeX - 4, nullWindow2.sizeY, colors.green, colors.black, "C")

	nullWindow2:fill(2, 2, 2, nullWindow2.sizeY - 2, indexsColors[selectedColor1], 0, " ")
	nullWindow2:fill(nullWindow2.sizeX - 2, 2, 2, nullWindow2.sizeY - 2, indexsColors[selectedColor2], 0, " ")

	nullWindow2:set(nullWindow2.sizeX - 4, nullWindow2.sizeY - 1, colors.green, colors.lime, ">")
	nullWindow2:set(nullWindow2.sizeX - 3, nullWindow2.sizeY - 1, indexsColors[selectedColor1], indexsColors[selectedColor2], unicode.sub(selectedChar, 1, 1))
end

local function drawColors()
	paletteWindow:fill(1, 1, paletteWindow.sizeX, paletteWindow.sizeY, colors.brown, colors.black, "▒")
	for i, v in ipairs(indexsColors) do
		paletteWindow:set(2, i + 1, v, 0, "      ")
	end
	paletteWindow:fill(4, 1, 2, paletteWindow.sizeY, colors.brown, colors.black, "▒")
end

local function drawUi()
	statusWindow:clear(colors.gray)
	statusWindow:set(1, 1, colors.red, colors.white, "X")
	statusWindow:set(rx - 5, 1, colors.gray, colors.white, "paint")
	statusWindow:set(3, 1, colors.white, colors.black, "file")
	statusWindow:set(8, 1, colors.white, colors.black, "edit")

	statusWindow:set(13, 1, colors.white, colors.black, "<")
	statusWindow:set(15, 1, colors.white, colors.black, ">")
	statusWindow:set(17, 1, colors.white, colors.black, "^")
	statusWindow:set(19, 1, colors.white, colors.black, "v")

	statusWindow:set(22, 1, colors.white, colors.red, "<")
	statusWindow:set(24, 1, colors.white, colors.red, ">")
	statusWindow:set(26, 1, colors.white, colors.red, "^")
	statusWindow:set(28, 1, colors.white, colors.red, "v")
end

local function drawPixel(x, y, pixel)
	x = x + imageOffsetX
	y = y + imageOffsetY
	if x < 1 or x > mainWindow.sizeX or y < 1 or y > mainWindow.sizeY then return end

	local depth = graphic.getDepth(screen)
	if pixel[1] ~= 0 or pixel[2] ~= 0 then
		local bg, fg = indexsColors[pixel[1] + 1], indexsColors[pixel[2] + 1]
		if depth == 8 then
			if pixel[4] then
				bg = imagelib.t3colors[pixel[4]]
			end
			if pixel[5] then
				fg = imagelib.t3colors[pixel[5]]
			end
		end
		mainWindow:set(x, y, bg, fg, pixel[3])
	else
		mainWindow:set(x, y, colors.black, colors.lightGray, "░")
	end
end

local function raw_save(path)
	local buffer = ""
	buffer = buffer .. string.char(image.sizeX)
	buffer = buffer .. string.char(image.sizeY)
	if image[1][1][4] then
		buffer = buffer .. "3" .. string.rep(string.char(0), 7)
	else
		buffer = buffer .. string.rep(string.char(0), 8)
	end

	local writebit = calls.load("writebit")
	local readbit = calls.load("readbit")
	
	for y, tbl in ipairs(image) do
		for x, pixel in ipairs(tbl) do
			local bg = 0
			for i = 0, 3 do
				bg = writebit(bg, i, readbit(pixel[1], i))
				bg = writebit(bg, i + 4, readbit(pixel[2], i))
			end
			buffer = buffer .. string.char(bg)
			if image[1][1][4] then
				buffer = buffer .. string.char(pixel[4] or 0)
				buffer = buffer .. string.char(pixel[5] or 0)
			end
			buffer = buffer .. string.char(#pixel[3])
			buffer = buffer .. pixel[3]
		end
	end

	local file = assert(fs.open(path, "wb"))
	file.write(buffer)
	file.close()
end

local function drawImage()
	if image then
		local sx = image.sizeX
		local sy = image.sizeY
		while sx + imageOffsetX > mainWindow.sizeX do
			sx = sx - 1
		end
		while sy + imageOffsetY > mainWindow.sizeY do
			sy = sy - 1
		end
		mainWindow:fill(1 + imageOffsetX, 1 + imageOffsetY, sx, sy, colors.black, colors.lightGray, "░")
		--[[
		for y, tbl in ipairs(image) do
			for x, pixel in ipairs(tbl) do
				drawPixel(x, y, pixel)
			end
		end
		]]
		local tmp = os.tmpname()
		raw_save(tmp)
		imagelib.draw(screen, tmp, mainWindow:toRealPos(1 + imageOffsetX, 1 + imageOffsetY))
		fs.remove(tmp)
	end
end

local function draw()
	mainWindow:fill(1, 1, mainWindow.sizeX, mainWindow.sizeY, colors.black, colors.gray, "░")
	drawImage()
	drawUi()
	drawColors()
	drawSelectedColors()
end

local function load()
	image = {}

	local readbit = calls.load("readbit")

	local file = assert(fs.open(filepath, "rb"))
	local buffer = file.readAll()
	file.close()
	local function read(bytecount)
		local str = buffer:sub(1, bytecount)
		buffer = buffer:sub(bytecount + 1, #buffer)
		return str
	end

	local sizeX = string.byte(read(1))
	local sizeY = string.byte(read(1))
	local t3paletteSupport = read(1) == "3"
	read(7)

	image.sizeX = sizeX
	image.sizeY = sizeY

	local colorByte, countCharBytes, background, foreground, char
	for cy = 1, sizeY do
		image[cy] = {}
		for cx = 1, sizeX do
			colorByte      = string.byte(read(1))
			local fullBack, fullFore
			if t3paletteSupport then
				fullBack = string.byte(read(1))
				fullFore = string.byte(read(1))
			end
			countCharBytes = string.byte(read(1))

			background = 
			((readbit(colorByte, 0) and 1 or 0) * 1) + 
			((readbit(colorByte, 1) and 1 or 0) * 2) + 
			((readbit(colorByte, 2) and 1 or 0) * 4) + 
			((readbit(colorByte, 3) and 1 or 0) * 8)
			foreground = 
			((readbit(colorByte, 4) and 1 or 0) * 1) + 
			((readbit(colorByte, 5) and 1 or 0) * 2) + 
			((readbit(colorByte, 6) and 1 or 0) * 4) + 
			((readbit(colorByte, 7) and 1 or 0) * 8)

			char = read(countCharBytes)

			if background == foreground and not fullBack then --во избежаниия визуальных артефактов отбражения unicode
				char = " "
			end

			image[cy][cx] = {background, foreground, char, fullBack, fullFore}
		end
	end

	reMathOffset()
end

local function offsetImage(x, y)
	local img = table.deepclone(image)
	for cy = 1, img.sizeY do
		for cx = 1, img.sizeX do
			local line = img[cy + y]
			if line then
				local pixel = line[cx + x]
				if pixel then
					image[cy][cx] = pixel
				else
					image[cy][cx] = {0, 0, " "}
				end
			else
				image[cy][cx] = {0, 0, " "}
			end
		end
	end

	noSaved = true
end

local function save()
	noSaved = false
	if not image then return end
	raw_save(filepath)
end

if fs.exists(filepath) then
	load()
end

local function exitAllow()
	if not noSaved then return true end
	local clear = saveZone(screen)
	local ok = gui.yesno(screen, nil, nil, "image do not saved!\nare you sure you want to get out?")
	clear()
	return ok
end

local function resize(newx, newy)
	newx = math.floor(newx + 0.5)
	newy = math.floor(newy + 0.5)
	if newx <= 0 or newy <= 0 then
		local clear = saveZone(screen)
		gui.warn(screen, nil, nil, "incorrent input", colors.white)
		clear()
		return
	end

	if newy > image.sizeY then
		for i = 1, math.abs(image.sizeY - newy) do
			local tbl = {}
			for i = 1, image.sizeX do
				table.insert(tbl, {0, 0, " "})
			end
			table.insert(image, tbl)
		end
	end
	if newx > image.sizeX then
		for i, v in ipairs(image) do
			for i = 1, math.abs(image.sizeX - newx) do
				table.insert(v, {0, 0, " "})
			end
		end
	end
	
	if newy < image.sizeY then
		for i = 1, math.abs(image.sizeY - newy) do
			table.remove(image, #image)
		end
	end
	if newx < image.sizeX then
		for i, v in ipairs(image) do
			for i = 1, math.abs(image.sizeX - newx) do
				table.remove(v, #v)
			end
		end
	end

	image.sizeX = newx
	image.sizeY = newy

	reMathOffset()
	draw()
end

draw()

while true do
	local eventData = {computer.pullSignal()}
	local statusWindowEventData = statusWindow:uploadEvent(eventData)
	local paletteWindowEventData = paletteWindow:uploadEvent(eventData)
	local nullWindowEventData = nullWindow2:uploadEvent(eventData)
	local mainWindowEventData = mainWindow:uploadEvent(eventData)

	if statusWindowEventData[1] == "touch" then
		if statusWindowEventData[3] == 1 and statusWindowEventData[4] == 1 and exitAllow() then
			break
		end
		if statusWindowEventData[3] >= 3 and statusWindowEventData[3] <= 6 then
			local clear = calls.call("screenshot", screen, 4, 2, 20, 4)
			local str, num = calls.call("gui_context", screen, 4, 2, {"  close", true, "  save"},
			{true, false, true})
			clear()
			if num == 1 then
				if exitAllow() then
					break
				end
			elseif num == 3 then
				save()
			end
		elseif statusWindowEventData[3] >= 8 and statusWindowEventData[3] <= 11 then
			local gclear = calls.call("screenshot", screen, 9, 2, 20, 4)
			local str, num = gui.context(screen, 9, 2, {"  resize", "  color change", "  bg / fg invert"},
			{true, true, true})
			
			if num == 1 then
				gclear()
				local clear = saveZone(screen)
				local str = gui.input(screen, nil, nil, "newX newY", nil, colors.white, math.round(image.sizeX) .. " " .. math.round(image.sizeY))
				clear()
				if str then
					local x, y = table.unpack(calls.call("split", str, " "))
					x = tonumber(x)
					y = tonumber(y)
					if x and y then
						noSaved = true
						resize(x, y)
					else
						local clear = saveZone(screen)
						calls.call("gui_warn", screen, nil, nil, "incorrent input", colors.white)
						clear()
					end
				end
			elseif num == 2 then
				local str, num = gui.contextAuto(screen, 26, 3, {"  background", "  foreground", "  bg / fg"})
				if num then
					gclear()
					local from = gui.selectcolor(screen, nil, nil, "choose color to change")
					if from then
						local to = gui.selectcolor(screen, nil, nil, "choose new color")
						if to then
							noSaved = true
							for y, tbl in ipairs(image) do
								for x, pixel in ipairs(tbl) do
									if pixel[1] ~= pixel[2] or pixel[1] ~= 0 then
										if num == 1 or num == 3 then
											if pixel[1] == from then
												pixel[1] = to
											end
										end
										if num == 2 or num == 3 then
											if pixel[2] == from then
												pixel[2] = to
											end
										end
									end
								end
							end
						end
					end
				end

				draw()
			elseif num == 3 then
				noSaved = true
				for y, tbl in ipairs(image) do
					for x, pixel in ipairs(tbl) do
						pixel[1], pixel[2] = pixel[2], pixel[1]
						pixel[5], pixel[4] = pixel[4], pixel[5]
					end
				end
				draw()
			else
				gclear()
			end
		elseif statusWindowEventData[3] == 13 then
			imageOffsetX = imageOffsetX - 1
			draw()
		elseif statusWindowEventData[3] == 15 then
			imageOffsetX = imageOffsetX + 1
			draw()
		elseif statusWindowEventData[3] == 17 then
			imageOffsetY = imageOffsetY - 1
			draw()
		elseif statusWindowEventData[3] == 19 then
			imageOffsetY = imageOffsetY + 1
			draw()

		elseif statusWindowEventData[3] == 22 then
			offsetImage(1, 0)
			draw()
		elseif statusWindowEventData[3] == 24 then
			offsetImage(-1, 0)
			draw()
		elseif statusWindowEventData[3] == 26 then
			offsetImage(0, 1)
			draw()
		elseif statusWindowEventData[3] == 28 then
			offsetImage(0, -1)
			draw()
		end
	end

	if paletteWindowEventData[1] == "touch" or paletteWindowEventData[1] == "drag" then
		if paletteWindowEventData[4] >= 2 and paletteWindowEventData[4] <= paletteWindow.sizeY - 1 then
			local colorIndex = paletteWindowEventData[4] - 1
			if paletteWindowEventData[3] >= 2 and paletteWindowEventData[3] <= 3 then
				selectedColor1 = colorIndex
				drawSelectedColors()
			elseif paletteWindowEventData[3] >= 6 and paletteWindowEventData[3] <= 7 then
				selectedColor2 = colorIndex
				drawSelectedColors()
			end
		end
	end

	if eventData[1] == "key_down" then
		local ok
		for i, v in ipairs(lastinfo.keyboards[screen]) do
			if v == eventData[2] then
				ok = true
				break
			end
		end
		if ok then
			if eventData[3] == 19 and eventData[4] == 31 then
				save()
			elseif eventData[3] == 23 and eventData[4] == 17 then
				if exitAllow() then
					break
				end
			end
		end
	end

	if nullWindowEventData[1] == "touch" then
		if nullWindowEventData[3] >= 4 and nullWindowEventData[3] <= 5 and nullWindowEventData[4] == nullWindow2.sizeY - 1 then
			local clear = saveZone(screen)
			local entered = gui.input(screen, nil, nil, "char", nil, colors.white, selectedChar)
			clear()
			if entered then
				selectedChar = entered
				drawSelectedColors()
			end
		end
	end

	if (mainWindowEventData[1] == "touch" or mainWindowEventData[1] == "drag") and image then
		local px = mainWindowEventData[3] - imageOffsetX
		local py = mainWindowEventData[4] - imageOffsetY
		if px >= 1 and py >= 1 and px <= image.sizeX and
		py <= image.sizeY then
			if mainWindowEventData[5] == 0 then
				for i = 1, unicode.len(selectedChar) do
					local pixel = image[py][px + (i - 1)]
					if pixel then
						pixel[1] = selectedColor1 - 1
						pixel[2] = selectedColor2 - 1
						pixel[3] = unicode.sub(selectedChar, i, i)
						if pixel[1] == pixel[2] and pixel[1] == 0 then
							pixel[2] = 15
							pixel[3] = " "
						end
						pixel[4], pixel[5] = nil, nil
						drawPixel(px + (i - 1), py, pixel)
					end
				end
			else
				local pixel = image[py][px]
				pixel[1] = 0
				pixel[2] = 0
				pixel[3] = " "
				drawPixel(px, py, pixel)
			end
			noSaved = true
		end
	end
end