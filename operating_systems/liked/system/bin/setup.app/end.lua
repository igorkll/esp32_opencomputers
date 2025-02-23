local registry = require("registry")
local cache = require("cache")

if registry.enableRecoveryAfterSetup then
	registry.enableRecoveryAfterSetup = nil
	registry.disableRecovery = false
end

registry.systemConfigured = true
_G.doSetup = nil