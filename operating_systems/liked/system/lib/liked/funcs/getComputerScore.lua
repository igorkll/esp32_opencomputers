local cpuLevel = require("system").getCpuLevel()
local ram = require("computer").totalMemory() / 1024
local score = 0

if cpuLevel >= 3 then
	score = score + 5
elseif cpuLevel == 2 then
	score = score + 3
else
	score = score + 1
end

if ram >= 2048 then
	score = score + 5
elseif ram >= 1024 + 512 then
	score = score + 4
elseif ram >= 1024 then
	score = score + 3
elseif ram >= 768 then
	score = score + 2
else
	score = score + 1
end

return score