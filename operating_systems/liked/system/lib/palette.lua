local fs = require("filesystem")
local graphic = require("graphic")
local serialization = require("serialization")
local sysinit = require("sysinit")
local registry = require("registry")
local palette = {}

function palette.save(screen)
	return graphic.getPalette(screen, true)
end

function palette.set(screen, pal)
	graphic.setPalette(screen, pal, true)
end

function palette.fromFile(screen, path, noReg)
	if noReg then
		local pal = assert(serialization.load(path))
		graphic.setPalette(screen, pal)
	else
		pcall(sysinit.applyPalette, path, screen)
	end
end

function palette.system(screen, noReg)
	palette.fromFile(screen, sysinit.initPalPath, noReg)
end

function palette.blackWhite(screen, noReg)
	palette.fromFile(screen, "/system/t3default.plt", noReg)
end

function palette.setDefaultPalette(screen, noReg)
	local depth = graphic.getDepth(screen)
	if depth == 8 then
		palette.fromFile(screen, "/system/t3default.plt", noReg)
	elseif depth == 4 then
		palette.fromFile(screen, "/system/palettes/original.plt", noReg)
	end
end

function palette.setSystemPalette(path, regOnly, doNotOffScreen)
	if pcall(sysinit.applyPalette, path, regOnly, doNotOffScreen) then
		if sysinit.savePalPath then
			pcall(fs.copy, path, sysinit.savePalPath)
		end
	else
		if sysinit.savePalPath then
			pcall(fs.copy, sysinit.defaultPalettePath, sysinit.savePalPath)
		end
		sysinit.applyPalette(sysinit.defaultPalettePath, regOnly, doNotOffScreen)
	end
end

function palette.reBaseColor(palPath)
	if registry.wallpaperBaseColor then
		local oldPal = require("gui_container").indexsColors
		local newPal = serialization.load(palPath)

		if newPal then
			local index = table.find(oldPal, registry.wallpaperBaseColor)
			if index then
				local newColor = newPal[index]
				if newColor then
					registry.wallpaperBaseColor = newColor
				end
			end
		end
	end
end

palette.unloadable = true
return palette