local registry = require("registry")
local gui = require("gui")

local screen, nickname = ...

if registry.disableMarketForceMode then
	gui.warn(screen, nil, nil, "market force-mode is not available on your liked edition")
else
	assert(require("apps").execute("market", screen, nickname, nil, true))
end