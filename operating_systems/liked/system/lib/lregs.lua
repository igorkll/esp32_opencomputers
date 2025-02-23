local registry = require("registry")
local lregs = {}
lregs.private = registry.new("/data/registry_private.dat")

return lregs