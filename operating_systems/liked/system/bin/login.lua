local registry = require("registry")
if not registry.password then return end

local screen = ...

local liked = require("liked")
local gui = require("gui")

liked.drawUpBarTask(screen)
liked.drawWallpaper(screen)

repeat
	os.sleep()
until gui.checkPasswordLoop(screen, nil, nil, true, true)