local graphic = require("graphic")
local gui_container = require("gui_container")
local screen = ...

graphic.clear(screen, gui_container.colors.cyan)
graphic.set(screen, 2, 2, gui_container.colors.cyan, gui_container.colors.white, "configuration expectations...")
graphic.forceUpdate(screen)