local uix = require("uix")
local gobjs = require("gobjs")
local fs = require("filesystem")
local graphic = require("graphic")
local colorlib = require("colors")
local computer = require("computer")
local registry = require("registry")
local apps = require("apps")
local system = require("system")
local event = require("event")
local sysinit = require("sysinit")
local viewer = require("viewer")

--------------------------------

local screen = ...

function _G.doSetup(name)
	assert(apps.execute(system.getResourcePath(name .. ".lua"), screen))
end

local ui = uix.manager(screen)
local rx, ry = ui:size()

-------------------------------- blincked hi

local blinckedHi = {}

function blinckedHi:onDraw()
	local line = self.y
	local gpu = graphic.findGpu(screen)
	if gpu then
		gpu.setBackground(uix.colors.cyan)
		gpu.setForeground(colorlib.red, true)
	end

	local function add(str)
		gpu.set(self.x, line, str)
		line = line + 1
	end

	add("███                 ███")
	add("███                 ███")
	add("███                    ")
	add("█████████           ███")
	add("██████████          ███")
	add("███      ██         ███")
	add("███      ███        ███")
	add("███      ███        ███")
	add("███      ███        ███")
	add("███      ███        ███")
	add("███      ███        ███")
	add("███      ███        ███")
end

--------------------------------

helloLayout = ui:simpleCreate(uix.colors.cyan, uix.styles[2])

local hiPos
local tier1 = graphic.getDepth(screen) == 1
if tier1 then
	hiPos = 3
else
	hiPos = (rx / 2) - 11
end
hiObj = helloLayout:createCustom(hiPos, (ry / 2) - 6, blinckedHi)

if not tier1 then
	local function blink()
		hiObj:draw()
		graphic.forceUpdate(screen)

		local tick = 90
		helloLayout:timer(0.1, function ()
			local value = math.abs(math.sin(math.rad(tick)))
			graphic.setPaletteColor(screen, colorlib.red, colorlib.blend(value * 255, value * 255, value * 255))
			tick = (tick + 12) % 360

			if tick > 180 + 90 then
				return false
			end
		end, math.huge)
	end

	helloLayout:timer(4, blink, math.huge)

	function helloLayout:onSelect()
		blink()
	end
end

local next1 = helloLayout:createButton((rx / 2) - 7, ry - 1, 16, 1, uix.colors.lightBlue, uix.colors.white, "next", true)
function next1:onClick()
	ui:select(licenseLayout)
end

local reboot = helloLayout:createButton(rx - 17, 4, 16, 1, uix.colors.lightBlue, uix.colors.white, "reboot", true)
function reboot:onClick()
	computer.shutdown(true, true)
end

local shutdown = helloLayout:createButton(rx - 17, 2, 16, 1, uix.colors.lightBlue, uix.colors.white, "shutdown", true)
function shutdown:onClick()
	computer.shutdown(nil, true)
end

--------------------------------

licenseLayout = ui:simpleCreate(uix.colors.cyan, uix.styles[2])

function licenseLayout:onSelect()
	sysinit.initScreen(screen)
	while true do
		if viewer.license(screen, "/system/LICENSE") then
			doSetup("inet")
			if registry.systemConfigured then
				os.exit()
			end
		else
			break
		end
	end
	ui:select(helloLayout)
end

--------------------------------

ui:loop()