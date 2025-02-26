local rx, ry = 50, 16
local backgroundColor = 0x333333
local titleColor = 0xffffff
local pointColor = 0xffffff
local arrowColor = 0xff4444

----------------------------------------------------------

local gpu = component.proxy(component.list("gpu")())
gpu.bind((component.list("screen")()))
gpu.setResolution(rx, ry)

----------------------------------------------------------

local bootDisk = "b7e450d0-8c8b-43a1-89d5-41216256d45a"
local iconY = 5
local offset = 6
local icon1X, icon2X = 1 + offset, rx - 15 - offset

local arrow = {
	"       ██       ",
	"     ██  ██     ",
	"   ██      ██   "
}

local image_empty = {
	"                ",
	"                ",
	"                ",
	"                ",
	"                ",
	"                ",
	"                ",
	"                "
}

local image_boot = {
	"                ",
	"                ",
	"                ",
	"      A         ",
	"       A        ",
	"        A       ",
	"                ",
	"                "
}

local image_wifi = {
	"   CCCCCCCCCC   ",
	"  C          C  ",
	" C  CCCCCCCC  C ",
	"C  C        C  C",
	"  C   CCCC   C  ",
	" C   C    C   C ",
	" C  C  CC  C  C ",
	"       CC       "
}

computer.setBootAddress = function()
end

computer.getBootAddress = function()
	return bootDisk
end

----------------------------------------------------------

local imageColors = {
	["A"] = 0xff4444,
	["B"] = 0x44ff44,
	["C"] = 0x4444ff
}

local function drawImage(x, y, img)
	if not img then
		return
	end

	for ly, line in ipairs(img) do
		for lx = 1, #line do
			local color = imageColors[line:sub(lx, lx)]
			if color then
				gpu.setBackground(color)
				gpu.set(x + (lx - 1), y + (ly - 1), " ")
			end
		end
	end
end

local function invert()
	gpu.setForeground(gpu.setBackground(gpu.getForeground()))
end

local function centerSet(y, text, frameX, frameSX)
	if not text then return end
	frameX = frameX and (frameX + 1) or 0
	frameSX = frameSX or rx
	gpu.set(frameX + math.floor(((frameSX / 2) - (unicode.len(text) / 2)) + 0.5) + 1, y, text)
end

local function boot()
	local file = component.invoke(bootDisk, "open", "/init.lua")
	local data = ""
	while true do
		local ldata = component.invoke(bootDisk, "read", file, math.huge)
		if not ldata then
			break
		end
		data = data .. ldata
	end
	component.invoke(bootDisk, "close", file)
	assert(load(data, "=init", nil, _G))()
end

local function gui_menu(title, points, images, funcs)
	local current = 1

	local function redraw()
		gpu.setBackground(backgroundColor)
		gpu.fill(1, 1, rx, ry, " ")

		gpu.setForeground(titleColor)
		centerSet(2, title)

		gpu.setForeground(arrowColor)
		for i, str in ipairs(arrow) do
			if current > 1 then
				gpu.set(1 + i, 1, str, true)
			end
			if current < #points - 1 then
				gpu.set(rx - i, 1, str, true)
			end
		end

		drawImage(icon1X, iconY, images[current])
		drawImage(icon2X, iconY, images[current+1])

		gpu.setForeground(pointColor)
		centerSet(ry - 1, points[current], icon1X, 16)
		centerSet(ry - 1, points[current+1], icon2X, 16)
	end
	redraw()

	local current = 1
	while true do
		gpu.setForeground(math.random(0, 0xffffff))
		gpu.set(5, 5, " ")
		local eventData = {computer.pullSignal()}

		if eventData[1] == "touch" then
			if eventData[3] <= 5 then
				if current > 1 then
					current = current - 1
					redraw()
				end
			elseif eventData[3] > rx - 5 then
				if current < #points - 1 then
					current = current + 1
					redraw()
				end
			elseif eventData[4] >= iconY and eventData[4] < iconY + 8 then
				if eventData[3] >= icon1X and eventData[3] < icon1X + 16 then
					if funcs[current] then
						funcs[current]()
					elseif funcs[current] == true then
						return
					end
				elseif eventData[3] >= icon2X and eventData[3] < icon2X + 16 then
					if funcs[current+1] then
						funcs[current+1]()
					elseif funcs[current+1] == true then
						return
					end
				end 
			end
		end
	end
end

gui_menu("MENU", {"boot", "wifi", "modem"}, {image_boot, image_wifi, nil}, {boot})