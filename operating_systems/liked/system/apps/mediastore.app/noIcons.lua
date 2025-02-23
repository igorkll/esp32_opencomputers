local registry = require("registry")
local gui = require("gui")

local screen, nickname = ...
assert(require("apps").execute("market", screen, nickname, nil, nil, true, true))