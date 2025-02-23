local gui_container = require("gui_container")
local colors = gui_container.colors

local score = ...

if score >= 10 then
	return colors.cyan
elseif score >= 7 then
	return colors.green
elseif score >= 5 then
	return colors.orange
else
	return colors.red
end