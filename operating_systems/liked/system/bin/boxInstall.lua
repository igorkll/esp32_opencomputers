local installer = require("installer")
local gui = require("gui")

local screen, nickname, path = ...
local clear = gui.saveBigZone(screen)
local vfs = gui.selectExternalFs(screen)
if not vfs then return end
clear()
if gui.yesno(screen, nil, nil, "are you sure you want to flash this file to the \"" .. require("paths").name(require("hdd").genName(vfs)) .. "\" disk? THE DISK WILL BE CLEARED") then
	local ok, err = installer.ui_install_boxfile(screen, vfs, path)
	if not ok then
		gui.bigWarn(screen, nil, nil, err)
	end
end