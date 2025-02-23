local computer = require("computer")
local gui = require("gui")
local fs = require("filesystem")
local liked = require("liked")
local warnings = {}

function warnings.list(screen)
	local list = {}

	if not liked.isRealKeyboards(screen) then
		table.insert(list, "there is no physical keyboard\nto use the virtual keyboard, tap the screen three times quickly")
	end

	if computer.totalMemory() / 1024 < 512 then
		table.insert(list, "small amount of RAM on the device\nthis can lead to problems")
	end

	local rootfs = fs.get("/")
	if (rootfs.spaceTotal() - rootfs.spaceUsed()) / 1024 < 128 then
		table.insert(list, "not enough free disk space\nthis can lead to problems")
	end

	local tmpfs = fs.get("/tmp")
	if (tmpfs.spaceTotal() - tmpfs.spaceUsed()) / 1024 < 16 then
		table.insert(list, "there is no space in the temporary filesystem\nthis can lead to problems")
	end

	if fs.exists("/data/errorlog.log") then
		table.insert(list, "there were errors in your system, please check the \"errorlog\"")
	end

	return list
end

warnings.unloadable = true
return warnings