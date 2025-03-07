local rx, ry = 50, 16
local backgroundColor = 0x333333
local titleColor = 0xffffff
local pointColor = 0xffffff
local arrowColor = 0xff4444
local buttonColor = 0x30a1ff
local buttonTextColor = 0xffffff
local dotsColor = 0xffffff
local numberColor = 0xffffff

----------------------------------------------------------

local gpu = component.proxy(component.list("gpu")())
gpu.bind((component.list("screen")()))
gpu.setResolution(rx, ry)

local device = component.proxy(component.list("device")())
device.setTime(42222)

----------------------------------------------------------

local computer_shutdown = computer.shutdown
local bootDisk = device.getInternalDiskAddress()

local arrow = {
	"       ██       ",
	"     ██  ██     ",
	"   ██      ██   "
}

local small_arrow = {
	"  ██  ",
	"██  ██"
}
local small_arrow_sizeX = unicode.len(small_arrow[1])
local small_arrow_sizeY = #small_arrow[1]

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
	"  AB      W     ",
	"  CD       W    ",
	" AAAAAAAAAAAAD  ",
	" AAAAAAAAAAAAAA ",
	"  WW        WW  "
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

local image_time = {
	"      EEEE      ",
	"    EEELEEEE    ",
	"  EEEAELEEEEEE  ",
	"EEEEEEALEEEEEEEE",
	"EEEEEEEAEEEEEEEE",
	"  EEEEEEEEEEEE  ",
	"    EEEEEEEE    ",
	"      EEEE      "
}

local image_shutdown = {
	"       AA       ",
	"   AA  AA  AA   ",
	" AA    AA    AA ",
	"A      AA      A",
	"A      AA      A",
	" AA    AA    AA ",
	"   AA      AA   ",
	"     AAAAAA     "
}

local image_yes = {
	"             B  ",
	"            B   ",
	" B         B    ",
	"  B       B     ",
	"   B     B      ",
	"    B   B       ",
	"     B B        ",
	"      B         "
}

local image_no = {
	"AA            AA",
	"  AA        AA  ",
	"    AA    AA    ",
	"      AAAA      ",
	"      AAAA      ",
	"    AA    AA    ",
	"  AA        AA  ",
	"AA            AA"
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
	["C"] = 0x4444ff,
	["D"] = 0xffff44,
	["W"] = 0xffffff,
	["E"] = 0x999999,
	["L"] = 0x000000
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
	frameX = frameX and (frameX - 1) or 0
	frameSX = frameSX or rx
	gpu.set(frameX + math.floor(((frameSX / 2) - (unicode.len(text) / 2)) + 0.5) + 1, y, text)
end

local function boot()
	gpu.setBackground(0x000000)
	gpu.fill(1, 1, rx, ry, " ")
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
	computer_shutdown()
end

local function gui_menu(title, points, images, funcs)
	local current = 1

	local iconY = 5
	local icon1X, icon2X = 1 + 6, rx - 15 - 6

	local function redraw()
		gpu.setBackground(backgroundColor)
		gpu.setForeground(pointColor)
		gpu.fill(1, 1, rx, ry, " ")
		centerSet(ry - 1, points[current], icon1X, 16)
		centerSet(ry - 1, points[current+1], icon2X, 16)

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
	end
	redraw()

	while true do
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
						if funcs[current]() then
							break
						end
						redraw()
					end
				elseif eventData[3] >= icon2X and eventData[3] < icon2X + 16 then
					if funcs[current+1] then
						if funcs[current+1]() then
							break
						end
						redraw()
					end
				end 
			end
		end
	end
end

local function gui_list(points)
	local current = 1

	local iconY = ry - 1
	local iconBack = 1 + 2
	local icon1X, icon2X = iconBack + 10, rx - 7 - 2

	local function redraw()
		points[current].draw()

		gpu.setBackground(buttonColor)
		gpu.setForeground(buttonTextColor)
		gpu.set(iconBack, iconY, " < back ")
		if current > 1 then
			gpu.set(icon1X, iconY, " < prev ")
		end
		if current < #points then
			gpu.set(icon2X, iconY, " next > ")
		end
	end
	redraw()

	while true do
		local eventData = {computer.pullSignal()}

		if eventData[1] == "touch" then
			if eventData[4] == iconY then
				if eventData[3] >= icon1X and eventData[3] < icon1X + 8 then
					if current > 1 then
						current = current - 1
						redraw()
					end
				elseif eventData[3] >= icon2X and eventData[3] < icon2X + 8 then
					if current < #points then
						current = current + 1
						redraw()
					end
				elseif eventData[3] >= iconBack and eventData[3] < iconBack + 8 then
					break
				end
			else
				points[current]:event(eventData)
			end
		end
	end
end

local function gui_menu_wifi()
	
end

local function gui_menu_time()
	gui_list({
		{
			draw = function()
				local function drawArrow(x, y, revers)
					for i = revers and #small_arrow or 1, revers and 1 or #small_arrow, revers and -1 or 1 do
						gpu.set(x, y, small_arrow[i])
						y = y + 1
					end
				end
			
				local arrowsUp = 2
				local arrowsDown = ry - 4
				local arrow1 = 5
				local arrow2 = ((rx / 2) - (small_arrow_sizeX / 2)) + 1 + -7
				local arrow3 = ((rx / 2) - (small_arrow_sizeX / 2)) + 1 + 7
				local arrow4 = rx - (small_arrow_sizeX - 1) - 4
			
				gpu.setBackground(backgroundColor)
				gpu.setForeground(dotsColor)
				gpu.fill(1, 1, rx, ry, " ")
		
				gpu.fill(rx / 2, arrowsUp + 3, 2, 6, "█")
				gpu.fill(rx / 2, arrowsUp + 4, 2, 4, " ")
		
				gpu.setForeground(arrowColor)
				drawArrow(arrow1, arrowsUp, false)
				drawArrow(arrow2, arrowsUp, false)
				drawArrow(arrow3, arrowsUp, false)
				drawArrow(arrow4, arrowsUp, false)
				drawArrow(arrow1, arrowsDown, true)
				drawArrow(arrow2, arrowsDown, true)
				drawArrow(arrow3, arrowsDown, true)
				drawArrow(arrow4, arrowsDown, true)
			end,
			event = function(eventData)
				
			end
		},
		{
			draw = function()
				local function drawArrow(x, y, revers)
					for i = revers and #small_arrow or 1, revers and 1 or #small_arrow, revers and -1 or 1 do
						gpu.set(x, y, small_arrow[i])
						y = y + 1
					end
				end
			
				local arrowsUp = 2
				local arrowsDown = ry - 4
				local arrow1 = 5
				local arrow2 = ((rx / 2) - (small_arrow_sizeX / 2)) + 1 + -7
				local arrow3 = ((rx / 2) - (small_arrow_sizeX / 2)) + 1 + 7
				local arrow4 = rx - (small_arrow_sizeX - 1) - 4
			
				gpu.setBackground(backgroundColor)
				gpu.setForeground(pointColor)
				gpu.fill(1, 1, rx, ry, " ")
		
				gpu.fill(rx / 2, arrowsUp + 3, 2, 6, "█")
				gpu.fill(rx / 2, arrowsUp + 4, 2, 4, " ")
		
				drawArrow(arrow1, arrowsUp, false)
				drawArrow(arrow2, arrowsUp, false)
				drawArrow(arrow3, arrowsUp, false)
				drawArrow(arrow4, arrowsUp, false)
		
				drawArrow(arrow1, arrowsDown, true)
				drawArrow(arrow2, arrowsDown, true)
				drawArrow(arrow3, arrowsDown, true)
				drawArrow(arrow4, arrowsDown, true)
			end,
			event = function(eventData)
				
			end
		}
	})
end

if device.sdcardAvailable() and device.sdcardNeedFormat() then
	gui_menu("format sdcard?", {"NO (sdcard won't work)", "YES (data will be erased)"}, {image_no, image_yes}, function ()
		return true
	end, function ()
		device.sdcardFormat()
		return true
	end)
end

--gui_menu("MENU", {"boot", "wifi", "time", "shutdown"}, {image_boot, image_wifi, image_time, image_shutdown}, {boot, gui_menu_wifi, gui_menu_time, computer.shutdown})
gui_menu("MENU", {"boot", "shutdown"}, {image_boot, image_shutdown}, {boot, computer.shutdown})