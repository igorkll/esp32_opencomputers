local rx, ry = 50, 16
local backgroundColor = 0x333333
local titleColor = 0x00ff00
local pointColor = 0xacacac
local arrowColor = 0xff4444

----------------------------------------------------------

local gpu = component.proxy(component.list("gpu")())
gpu.bind((component.list("screen")()))
gpu.setResolution(rx, ry)

----------------------------------------------------------

local arrow = {
	"       ██       ",
	"     ██  ██     ",
	"   ██      ██   "
}

----------------------------------------------------------

local function invert()
	gpu.setForeground(gpu.setBackground(gpu.getForeground()))
end

local function centerSet(y, text)
	gpu.set(math.floor(((rx / 2) - (unicode.len(text) / 2)) + 0.5) + 1, y, text)
end

local function gui_menu(title, points, funcs)
	gpu.setBackground(backgroundColor)
	gpu.fill(1, 1, rx, ry, " ")

	gpu.setForeground(titleColor)
	centerSet(2, title)
	
	gpu.setForeground(arrowColor)
	for i, str in ipairs(arrow) do
		gpu.set(1 + i, 1, str, true)
		gpu.set(rx - i, 1, str, true)
	end

	local current = 1
	while true do
		local eventData = {computer.pullSignal()}

		if eventData[1] == "touch" then
			if eventData[3] <= 5 then
				computer.beep(500)
			elseif eventData[3] > rx - 5 then
				computer.beep(700)
			end
		end
	end
end

gui_menu("MENU", {"wifi", "boot"}, {function ()
	
end})