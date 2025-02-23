local screen, nickname, path = ...

local graphic = require("graphic")
local gui_container = require("gui_container")
local colors = gui_container.colors
local event = require("event")
local fs = require("filesystem")
local paths = require("paths")
local gui = require("gui")
local uix = require("uix")
local registry = require("registry")

local window = gui.customWindow(screen)

local layout = uix.create(window, nil, uix.styles[2])
if not registry.disableHiddenFiles then
	local checkbox = layout:createCheckbox(2, 11, not not fs.getAttribute(path, "hidden"), colors.red, colors.gray, colors.black)
	layout:createText(5, 11, colors.black, "hidden")
	function checkbox:onSwitch()
		fs.setAttribute(path, "hidden", self.state)
	end
end

window:clear(colors.white)
window:fill(1, 1, window.sizeX, 1, colors.gray, 0, " ")
window:set(window.sizeX - 2, 1, colors.red, colors.white, " X ")
window:set(2, 1, colors.gray, colors.white, "file-info")

layout:draw()

local ctype = fs.isDirectory(path) and "directory" or "file"
local exp = paths.extension(path)
if exp then
	ctype = (gui_container.typenames[exp] or exp) .. "-" .. ctype
end

local addr = fs.get(path).address

window:set(2, 3, colors.white, colors.black, "type     : " .. ctype)
window:set(2, 4, colors.white, colors.black, "path     : " .. gui_container.short(path, #addr))
window:set(2, 5, colors.white, colors.black, "disk     : " .. addr)

window:set(2, 9, colors.white, colors.black, "f/d count: please wait...")

window:set(2, 6, colors.white, colors.black, "real size: please wait...")
window:set(2, 7, colors.white, colors.black, "disk size: please wait...")
window:set(2, 8, colors.white, colors.black, "sha256   : please wait...")
graphic.forceUpdate(screen)

local size, sizeWithBaseCost, filesCount, dirsCount = fs.size(path)
window:fill(2, 6, 49, 1, colors.white, 0, " ")
window:fill(2, 7, 49, 1, colors.white, 0, " ")
window:set(2, 6, colors.white, colors.black, "real size: " .. math.roundTo(size / 1024, 1) .. " KB")
window:set(2, 7, colors.white, colors.black, "disk size: " .. math.roundTo(sizeWithBaseCost / 1024, 1) .. " KB")
window:set(2, 9, colors.white, colors.black, "f/d count: " .. filesCount .. "-files / " .. dirsCount .. "-dirs")
graphic.forceUpdate(screen)

local sum = "-"
if not fs.isDirectory(path) and size <= (16 * 1024) then
	local content = fs.readFile(path)
	if content then
		sum = require("sha256").sha256hex(content)
		sum = sum:sub(1, #addr) .. gui_container.chars.threeDots
	end
end
window:fill(2, 8, 49, 1, colors.white, 0, " ")
window:set(2, 8, colors.white, colors.black, "sha256   : " .. sum)
graphic.forceUpdate(screen)

while true do
	local eventData = {event.pull()}
	local windowEventData = window:uploadEvent(eventData)
	layout:uploadEvent(windowEventData)

	if windowEventData[1] == "key_down" then
		if windowEventData[4] == 28 then
			break
		end
	elseif windowEventData[1] == "touch" then
		if windowEventData[3] >= window.sizeX - 2 and windowEventData[4] == 1 then
			break
		end
	end
end