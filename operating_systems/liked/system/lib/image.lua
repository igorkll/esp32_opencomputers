local fs = require("filesystem")
local graphic = require("graphic")
local calls = require("calls")
local gui_container = require("gui_container")
local cache = require("cache")
local paths = require("paths")
local unicode = require("unicode")
local colorslib = require("colors")
local computer = require("computer")
local liked = require("liked")
local registry = require("registry")
local format = require("format")
local component = require("component")
local gui = require("gui")

local image = {}
local t3colors = {0x000000, 0x000040, 0x000080, 0x0000BF, 0x0000FF, 0x002400, 0x002440, 0x002480, 0x0024BF, 0x0024FF, 0x004900, 0x004940, 0x004980, 0x0049BF, 0x0049FF, 0x006D00, 0x006D40, 0x006D80, 0x006DBF, 0x006DFF, 0x009200, 0x009240, 0x009280, 0x0092BF, 0x0092FF, 0x00B600, 0x00B640, 0x00B680, 0x00B6BF, 0x00B6FF, 0x00DB00, 0x00DB40, 0x00DB80, 0x00DBBF, 0x00DBFF, 0x00FF00, 0x00FF40, 0x00FF80, 0x00FFBF, 0x00FFFF, 0x0F0F0F, 0x1E1E1E, 0x2D2D2D, 0x330000, 0x330040, 0x330080, 0x3300BF, 0x3300FF, 0x332400, 0x332440, 0x332480, 0x3324BF, 0x3324FF, 0x334900, 0x334940, 0x334980, 0x3349BF, 0x3349FF, 0x336D00, 0x336D40, 0x336D80, 0x336DBF, 0x336DFF, 0x339200, 0x339240, 0x339280, 0x3392BF, 0x3392FF, 0x33B600, 0x33B640, 0x33B680, 0x33B6BF, 0x33B6FF, 0x33DB00, 0x33DB40, 0x33DB80, 0x33DBBF, 0x33DBFF, 0x33FF00, 0x33FF40, 0x33FF80, 0x33FFBF, 0x33FFFF, 0x3C3C3C, 0x4B4B4B, 0x5A5A5A, 0x660000, 0x660040, 0x660080, 0x6600BF, 0x6600FF, 0x662400, 0x662440, 0x662480, 0x6624BF, 0x6624FF, 0x664900, 0x664940, 0x664980, 0x6649BF, 0x6649FF, 0x666D00, 0x666D40, 0x666D80, 0x666DBF, 0x666DFF, 0x669200, 0x669240, 0x669280, 0x6692BF, 0x6692FF, 0x66B600, 0x66B640, 0x66B680, 0x66B6BF, 0x66B6FF, 0x66DB00, 0x66DB40, 0x66DB80, 0x66DBBF, 0x66DBFF, 0x66FF00, 0x66FF40, 0x66FF80, 0x66FFBF, 0x66FFFF, 0x696969, 0x787878, 0x878787, 0x969696, 0x990000, 0x990040, 0x990080, 0x9900BF, 0x9900FF, 0x992400, 0x992440, 0x992480, 0x9924BF, 0x9924FF, 0x994900, 0x994940, 0x994980, 0x9949BF, 0x9949FF, 0x996D00, 0x996D40, 0x996D80, 0x996DBF, 0x996DFF, 0x999200, 0x999240, 0x999280, 0x9992BF, 0x9992FF, 0x99B600, 0x99B640, 0x99B680, 0x99B6BF, 0x99B6FF, 0x99DB00, 0x99DB40, 0x99DB80, 0x99DBBF, 0x99DBFF, 0x99FF00, 0x99FF40, 0x99FF80, 0x99FFBF, 0x99FFFF, 0xA5A5A5, 0xB4B4B4, 0xC3C3C3, 0xCC0000, 0xCC0040, 0xCC0080, 0xCC00BF, 0xCC00FF, 0xCC2400, 0xCC2440, 0xCC2480, 0xCC24BF, 0xCC24FF, 0xCC4900, 0xCC4940, 0xCC4980, 0xCC49BF, 0xCC49FF, 0xCC6D00, 0xCC6D40, 0xCC6D80, 0xCC6DBF, 0xCC6DFF, 0xCC9200, 0xCC9240, 0xCC9280, 0xCC92BF, 0xCC92FF, 0xCCB600, 0xCCB640, 0xCCB680, 0xCCB6BF, 0xCCB6FF, 0xCCDB00, 0xCCDB40, 0xCCDB80, 0xCCDBBF, 0xCCDBFF, 0xCCFF00, 0xCCFF40, 0xCCFF80, 0xCCFFBF, 0xCCFFFF, 0xD2D2D2, 0xE1E1E1, 0xF0F0F0, 0xFF0000, 0xFF0040, 0xFF0080, 0xFF00BF, 0xFF00FF, 0xFF2400, 0xFF2440, 0xFF2480, 0xFF24BF, 0xFF24FF, 0xFF4900, 0xFF4940, 0xFF4980, 0xFF49BF, 0xFF49FF, 0xFF6D00, 0xFF6D40, 0xFF6D80, 0xFF6DBF, 0xFF6DFF, 0xFF9200, 0xFF9240, 0xFF9280, 0xFF92BF, 0xFF92FF, 0xFFB600, 0xFFB640, 0xFFB680, 0xFFB6BF, 0xFFB6FF, 0xFFDB00, 0xFFDB40, 0xFFDB80, 0xFFDBBF, 0xFFDBFF, 0xFFFF00, 0xFFFF40, 0xFFFF80, 0xFFFFBF, 0xFFFFFF}
local colors = gui_container.indexsColors
local readbit = bit32.readbit

local function otherCheck(path, exp)
	path = paths.changeExtension(path, exp)
	return fs.exists(path) and path
end

local function imageReColor(color, blackListedColor, cols)
	cols = cols or gui.smartShadowsColors
	if blackListedColor and color == blackListedColor then
		for i, lcolor in ipairs(gui_container.indexsColors) do
			if lcolor == blackListedColor then
				return gui_container.indexsColors[(cols[i] or gui.smartShadowsColors[i]) + 1]
			end
		end
	end
	return color
end

local function repath(screen, path)
	local depth = graphic.getDepth(screen or component.list("screen")())
	if depth == 8 then
		path = otherCheck(path, "t3p") or path
	elseif depth == 4 then
		path = otherCheck(path, "t2p") or path
	elseif depth == 1 then
		path = otherCheck(path, "t1p") or path
	end
	return paths.canonical(path)
end

--wallpaperMode заставляет считать цвет lightBlue как прозрачность
function image.draw(screen, path, x, y, wallpaperMode, forceFullColor, lightMul, imagePaletteUsed, blackListedColor, newColors)
	if liked.recoveryMode then
		return
	end

	local llcolors = colors
	if imagePaletteUsed then
		llcolors = image.readPalette(path, false, screen) or colors
	end

	x = math.floor(x + 0.5)
	y = math.floor(y + 0.5)
	
	lightMul = lightMul or 1
	path = repath(screen, path)

	local gpu = graphic.findGpu(screen)

	cache.cache.images = cache.cache.images or {}
	local buffer
	local lcache = cache.cache.images[path]
	if lcache and fs.lastModified(path) == lcache[2] then
		buffer = lcache[1]
	else
		buffer = assert(fs.readFile(path))
		if computer.freeMemory() > #buffer * 3 then
			cache.cache.images[path] = {buffer, fs.lastModified(path)}
		end
	end

	local function read(bytecount)
		local str = buffer:sub(1, bytecount)
		buffer = buffer:sub(bytecount + 1, #buffer)
		return str
	end

	------------------------------------

	local sx = string.byte(read(1))
	local sy = string.byte(read(1))
	local t3paletteSupport = read(1) == "3"
	if read(1) == "f" then
		forceFullColor = true
	end
	local skipPalette
	if read(1) == "p" then
		skipPalette = true
	end
	read(5)

	if skipPalette then
		read(16 * 3)
	end

	local function norm(x, y, text)
		if x <= 0 then
			return 1, y, unicode.sub(text, 2 - x, unicode.len(text))
		end
		return x, y, text
	end

	local background, foreground
	local fullBack, fullFore
	local char
	local col, col2
	local _, c, f, b
	if gpu.getSoftwareBuffers then
		local updateZone = gpu.updateZone or function () end
		local chars, fores, backs = gpu.getSoftwareBuffers()
		local rx = graphic.getResolution(screen)
		local colorByte, countCharBytes
		local isEmptyBuff = true
		local index

		gpu.updateFlag()

		for cy = 1, sy do
			for cx = 1, sx do
				colorByte = string.byte(read(1))
				fullBack, fullFore = nil, nil
				if t3paletteSupport then
					if forceFullColor or graphic.getDepth(screen) == 8 then
						fullBack = t3colors[string.byte(read(1)) + 1]
						fullFore = t3colors[string.byte(read(1)) + 1]
						if registry.visionProtection then
							fullBack = format.visionProtectionConvert(fullBack)
							fullFore = format.visionProtectionConvert(fullFore)
						end
					else
						read(2)
					end
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
				isEmptyBuff = char == " "
				index = (x - 1) + cx + (((cy + y) - 2) * rx)

				if background ~= 0 or foreground ~= 0 then
					if (background == foreground or isEmptyBuff) and not fullBack then
						backs[index] = imageReColor(colorslib.colorMul(llcolors[background + 1], lightMul), blackListedColor, newColors)
						chars[index] = " "
						updateZone(index)
					else
						col, col2 = nil, nil
						if wallpaperMode then
							if background == colorslib.lightBlue then col = backs[index] end
							if foreground == colorslib.lightBlue then col2 = backs[index] end
						end
						if col then
							backs[index] = col
						else
							backs[index] = imageReColor(colorslib.colorMul(fullBack or llcolors[background + 1], lightMul), blackListedColor, newColors)
						end
						if col2 then
							fores[index] = col2
						else
							fores[index] = imageReColor(colorslib.colorMul(fullFore or llcolors[foreground + 1], lightMul), blackListedColor, newColors)
						end
						chars[index] = char
						updateZone(index)
					end
				end
			end
		end
	else
		local colorByte, countCharBytes
		local oldX, oldY = 1, 1
		local oldFore, oldBack, oldForeFull, oldBackFull
		local buff = ""
		local isEmptyBuff = true
		for cy = 1, sy do
			for cx = 1, sx do
				colorByte = string.byte(read(1))
				fullBack, fullFore = nil, nil
				if t3paletteSupport then
					if forceFullColor or graphic.getDepth(screen) == 8 then
						fullBack = t3colors[string.byte(read(1)) + 1]
						fullFore = t3colors[string.byte(read(1)) + 1]
						if registry.visionProtection then
							fullBack = format.visionProtectionConvert(fullBack)
							fullFore = format.visionProtectionConvert(fullFore)
						end
					else
						read(2)
					end
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

				if not oldFore then oldFore = foreground end
				if not oldBack then oldBack = background end
				if not oldForeFull then oldForeFull = fullFore end
				if not oldBackFull then oldBackFull = fullBack end

				char = read(countCharBytes)

				if foreground ~= oldFore or background ~= oldBack or fullBack ~= oldBackFull or fullFore ~= oldForeFull or oldY ~= cy then
					if oldBack ~= 0 or oldFore ~= 0 then --прозрачность, в реальной картинке такого не будет потому что если paint замечает оба нуля то он меняет одной значения чтобы пиксель не мог просто так стать прозрачным
						if (oldBack == oldFore or isEmptyBuff) and not oldBackFull then --по избежании визуальных артефактов при отображении unicode символов от лица сматряшего на монитор со стороны
							gpu.setBackground(imageReColor(colorslib.colorMul(llcolors[oldBack + 1], lightMul), blackListedColor, newColors))
							gpu.set(norm(oldX + (x - 1), oldY + (y - 1), string.rep(" ", unicode.len(buff))))
						else
							col, col2 = nil, nil
							if wallpaperMode then
								_, c, f, b = pcall(gpu.get, oldX + (x - 1), oldY + (y - 1))
								if oldBack == colorslib.lightBlue then col = b end
								if oldFore == colorslib.lightBlue then col2 = b end
							end
							if col then
								gpu.setBackground(col)
							else
								gpu.setBackground(imageReColor(colorslib.colorMul(oldBackFull or llcolors[oldBack + 1], lightMul), blackListedColor, newColors))
							end
							if col2 then
								gpu.setForeground(col2)
							else
								gpu.setForeground(imageReColor(colorslib.colorMul(oldForeFull or llcolors[oldFore + 1], lightMul), blackListedColor, newColors))
							end
							gpu.set(norm(oldX + (x - 1), oldY + (y - 1), buff))
						end
					end

					oldFore = foreground
					oldBack = background
					oldForeFull = fullFore
					oldBackFull = fullBack
					oldX = cx
					oldY = cy
					buff = char
					isEmptyBuff = char == " "
				else
					buff = buff .. char
					if char ~= " " then
						isEmptyBuff = false
					end
				end
			end
		end

		if oldBack ~= 0 or oldFore ~= 0 then --прозрачность, в реальной картинке такого не будет потому что если paint замечает оба нуля то он меняет одной значения чтобы пиксель не мог просто так стать прозрачным
			if (oldBack == oldFore or isEmptyBuff) and not oldBackFull then --по избежании визуальных артефактов при отображении unicode символов от лица сматряшего на монитор со стороны
				gpu.setBackground(imageReColor(colorslib.colorMul(llcolors[oldBack + 1], lightMul), blackListedColor, newColors))
				gpu.set(norm(oldX + (x - 1), oldY + (y - 1), string.rep(" ", unicode.len(buff))))
			else
				col, col2 = nil, nil
				if wallpaperMode then
					_, c, f, b = pcall(gpu.get, oldX + (x - 1), oldY + (y - 1))
					if oldBack == colorslib.lightBlue then col = b end
					if oldFore == colorslib.lightBlue then col2 = b end
				end
				if col then
					gpu.setBackground(col)
				else
					gpu.setBackground(imageReColor(colorslib.colorMul(oldBackFull or llcolors[oldBack + 1], lightMul), blackListedColor, newColors))
				end
				if col2 then
					gpu.setForeground(col2)
				else
					gpu.setForeground(imageReColor(colorslib.colorMul(oldForeFull or llcolors[oldFore + 1], lightMul), blackListedColor, newColors))
				end
				gpu.set(norm(oldX + (x - 1), oldY + (y - 1), buff))
			end
		end
	end

	graphic.updateFlag(screen)
end

function image.readPalette(path, fromZero, screen)
	path = repath(screen, path)

	local file = fs.open(path, "rb", true)
	file.read(4)
	local isPal = file.read(1) == "p"
	file.read(5)

	if isPal then
		local palette = {}
		for i = 0, 15 do
			local color = colorslib.blend(string.byte(file.read(1)), string.byte(file.read(1)), string.byte(file.read(1)))
			if fromZero then
				palette[i] = color
			else
				table.insert(palette, color)
			end
		end
		return palette
	end
end

function image.applyPalette(screen, path)
	path = repath(screen, path)

	local pal = image.readPalette(path, false, screen)
	if pal then
		graphic.setPalette(screen, pal)
		return true
	end
end

function image.size(path, screen)
	path = repath(screen, path)

	local file = fs.open(path, "rb", 4)
	local sx = string.byte(file.read(1))
	local sy = string.byte(file.read(1))
	file.close()

	return sx, sy
end

function image.sizeX(path, screen)
	return (image.size(path, screen))
end

function image.sizeY(path, screen)
	return (select(2, image.size(path, screen)))
end

image.unloadable = true
return image