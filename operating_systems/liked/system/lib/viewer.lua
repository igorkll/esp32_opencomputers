local uix = require("uix")
local fs = require("filesystem")
local gobjs = require("gobjs")
local parser = require("parser")
local unicode = require("unicode")
local viewer = {}

function viewer.license(screen, path, isText, window, backTitle, nextTitle)
	local ui = uix.manager(screen)
	local ret

	local text
	if isText then
		text = path
	else
		text = assert(fs.readFile(path))
	end
	text = parser.fastChange(text, {["\r"] = "", ["\t"] = "  "})

	local licenseLayout = ui:createCustom(window or ui.screen, uix.colors.cyan, uix.styles[2])
	local rx, ry = licenseLayout.sizeX, licenseLayout.sizeY
	licenseLayout:createCustom(3, 2, gobjs.scrolltext, rx - 4, ry - 4, table.concat(parser.toLinesLn(text, rx - 6), "\n"))

	if backTitle ~= true then
		local back1 = licenseLayout:createButton(3, ry - 1, 8, 1, uix.colors.lightBlue, uix.colors.white, backTitle or " ← back", true)
		back1.alignment = "left"
		function back1:onClick()
			ret = false
			ui.exitFlag = true
		end
	end

	if nextTitle ~= true then
		local next2 = licenseLayout:createButton(rx - 17, ry - 1, 16, 1, uix.colors.lightBlue, uix.colors.white, nextTitle or "accept & next", true)
		function next2:onClick()
			ret = true
			ui.exitFlag = true
		end
	end

	ui:loop()
	return ret
end

viewer.unloadable = true
return viewer