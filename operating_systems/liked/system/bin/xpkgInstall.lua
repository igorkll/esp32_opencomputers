local apps = require("apps")
local registry = require("registry")
local liked = require("liked")
local gui = require("gui")

local screen, nickname, path = ...
if registry.disableCustomPackages then
	gui.warn(screen, nil, nil, "installing third-party packages is not possible on your edition of liked")
else
	local ok, err = apps.install(screen, nickname, path)
	if err == "cancel" then return end
	liked.assertNoClear(screen, ok, err)
end