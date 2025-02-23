local fs = require("filesystem")
local archiver = require("archiver")
local liked = require("liked")
local gui = require("gui")
local iowindows = require("iowindows")
local screen, _, path = ...

local clear = gui.saveBigZone(screen)
local unpackFolder = iowindows.savefolder(screen)
clear()
if unpackFolder then
	gui.status(screen, nil, nil, "unpacking \"" .. gui.fpath(screen, path) .. "\" to \"" .. gui.fpath(screen, unpackFolder) .. "\"")
	fs.makeDirectory(unpackFolder)
	liked.assert(screen, archiver.unpack(path, unpackFolder))
end