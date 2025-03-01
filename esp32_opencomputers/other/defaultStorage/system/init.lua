local rx, ry = 50, 16
local gpu = component.proxy(component.list("gpu")())
gpu.bind((component.list("screen")()))
gpu.setResolution(rx, ry)

gpu.setBackground(0x30a1ff)
gpu.setForeground(0xffffff)
gpu.fill(1, 1, 50, 16, " ")

local function centerSet(y, text)
	gpu.set(math.floor(((rx / 2) - (unicode.len(text) / 2)) + 0.5) + 1, math.floor((ry / 2) + 0.5) + y, text)
end

centerSet(-1, ("operating system stub"):upper())
centerSet(1, "the operating system is not installed")

while true do
	computer.pullSignal()
end