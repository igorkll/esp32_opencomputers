local unicode = require("unicode")
local graphic = require("graphic")
local colorlib = require("colors")
local text = require("text")
local format = {}

function format.smartConcat()
	local smart = {}
	smart.buff = {}
	smart.idx = 0

	function smart.add(x, text, reverse)
		if reverse then
			x = x - (unicode.len(text) - 1)
		end

		local len = unicode.len(text)
		local last = x + (len - 1)
		local index = 1
		for i = x, last do
			smart.buff[i] = unicode.sub(text, index, index)
			index = index + 1
		end
		if last > smart.idx then
			smart.idx = last
		end
	end

	function smart.makeSize(size)
		smart.idx = size
	end

	function smart.get()
		for i = 1, smart.idx do
			if not smart.buff[i] then
				smart.buff[i] = " "
			end
		end
		return table.concat(smart.buff)
	end

	return smart
end

function format.visionProtectionConvert(color)
	local r, g, b = colorlib.unBlend(color)
	return colorlib.blend(r * 0.8, g * 0.7, b * 0.3)
end

------ legacy

format.escape_pattern = text.escapePattern

function format.raw_objectPos(rx, ry, sx, sy, offsetX, offsetY)
	local cx, cy = math.round(rx / 2), math.round(ry / 2)
	local px, py = cx - math.round(sx / 2), cy - math.round(sy / 2)
	return math.round(px + offsetX) + 1, math.round(py + offsetY) + 1
end

function format.objectPos(screen, sx, sy, offsetX, offsetY)
	local rx, ry = graphic.getResolution(screen)
	return format.raw_objectPos(rx, ry, sx, sy, offsetX, offsetY)
end

format.unloadable = true
return format