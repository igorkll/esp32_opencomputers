local graphic = require("graphic")
local gui_container = require("gui_container")
local uix = require("uix")
local fs = require("filesystem")
local gui = require("gui")
local component = require("component")
local liked = require("liked")
local bootloader = require("bootloader")
local programs = require("programs")
local system = require("system")
local eepromlib = require("eeprom")
local apps = require("apps")

local colors = gui_container.colors

------------------------------------

local screen, posX, posY = ...
local rx, ry = graphic.getResolution(screen)
local window = graphic.createWindow(screen, posX, posY, rx - (posX - 1), ry - (posY - 1))

local layout = uix.create(window)

local labelInput = layout:createInput(2, 2, 30, nil, nil, false, nil, nil, 24)

local codeSizeLabel = layout:createText(2, 4)
local dataSizeLabel = layout:createText(2, 5)
local maxCodeSizeLabel = layout:createText(18, 4)
local maxDataSizeLabel = layout:createText(18, 5)
local checksumLabel = layout:createText(2, 6)
local addrLabel = layout:createText(2, 7)
local writeLabel = layout:createText(2, 8)
local bootLabel = layout:createText(2, 9)

local flashButton = layout:createButton(2, 11, 16, 1, nil, nil, "Flash", true)
local dumpButton = layout:createButton(2, 13, 16, 1, nil, nil, "Dump", true)
local editButton = layout:createButton(2, 15, 16, 1, nil, nil, "Edit", true)
local flashDataButton = layout:createButton(20, 11, 16, 1, nil, nil, "Flash Data", true)
local dumpDataButton = layout:createButton(20, 13, 16, 1, nil, nil, "Dump Data", true)
local editDataButton = layout:createButton(20, 15, 16, 1, nil, nil, "Edit Data", true)
local wipeDataButton = layout:createButton(20 + 18, 13, 16, 1, nil, nil, "Wipe Data", true)
local makeReadOnlyButton = layout:createButton(20 + 18, 11, 16, 1, nil, nil, "Make R/O", true)
local flashFirmware = layout:createButton(20 + 18, 15, 16, 1, nil, nil, "Flash Firmware", true)

local eepromMissingString = "EEPROM IS MISSING"
local storageRo = "storage is readonly"
local storageRoState = false

function labelInput:onTextChanged(newlabel)
	if component.eeprom then
		local result = {component.eeprom.setLabel(newlabel)}
		if result[1] then
			if labelInput.read.getBuffer() ~= result[1] then
				labelInput.read.setBuffer(result[1])
				labelInput.oldText = result[1]
				self:draw()
			end
		else
			local label = component.eeprom.getLabel()
			labelInput.read.setBuffer(label)
			labelInput.oldText = label
			self:draw()

			gui.warn(screen, nil, nil, tostring(result[2]))
			redraw()
		end
	else
		if labelInput.read.getBuffer() ~= eepromMissingString then
			labelInput.read.setBuffer(eepromMissingString)
			labelInput.oldText = eepromMissingString
			self:draw()
		end
	end
end

local function flashCode(data)
	local maxSize = math.round(component.eeprom.getSize())
	local fsize = #data
	if fsize > maxSize then
		gui.warn(screen, nil, nil, "it is not possible to write a " .. fsize .. " bytes file to an EEPROM with a capacity of " .. maxSize .. " bytes")
		return true
	elseif gui.pleaseType(screen, "FLASH", "flash eeprom") then
		gui_status(screen, nil, nil, "flashing...")
		local result = {pcall(component.eeprom.set, data)}
		if not result[1] then
			gui.warn(screen, nil, nil, tostring(result[2] or "unknown error"))
			return true
		elseif result[3] then
			gui.warn(screen, nil, nil, tostring(result[3] or "unknown error"))
			return true
		end
	end
end

function flashButton:onClick()
	if component.eeprom then
		if storageRoState then
			gui.warn(screen, nil, nil, storageRo)
		elseif gui.pleaseCharge(screen, 20, "flash") then
			local path = gui_filepicker(screen, nil, nil, nil, "lua", false, false)
			if path then
				flashCode(assert(fs.readFile(path)))
			end
		end

		gRedraw()
		redraw()
	end
end

function flashFirmware:onClick()
	if component.eeprom then
		if storageRoState then
			gui.warn(screen, nil, nil, storageRo)
		elseif gui.pleaseCharge(screen, 20, "flash") then
			eepromlib.menu(screen)
		end

		gRedraw()
		redraw()
	end
end

function dumpButton:onClick()
	if component.eeprom then
		local path = gui_filepicker(screen, nil, nil, nil, "lua", true, false)
		if path then
			local data = component.eeprom.get()
			liked.assert(screen, fs.writeFile(path, data))
		end

		gRedraw()
		redraw()
	end
end

local function flashData(data)
	local maxSize = math.round(component.eeprom.getDataSize())
	
	local fsize = #data
	if fsize > maxSize then
		gui.warn(screen, nil, nil, "it is not possible to write a " .. fsize .. " bytes file to an EEPROM-Data with a capacity of " .. maxSize .. " bytes")
		return true
	elseif gui.pleaseType(screen, "FDATA", "flash data") then
		gui_status(screen, nil, nil, "flashing data...")
		local result = {pcall(component.eeprom.setData, data)}
		if not result[1] then
			gui.warn(screen, nil, nil, tostring(result[2] or "unknown error"))
			return true
		elseif result[3] then
			gui.warn(screen, nil, nil, tostring(result[3] or "unknown error"))
			return true
		end
	end
end

function flashDataButton:onClick()
	if component.eeprom then
		if gui.pleaseCharge(screen, 20, "flash data") then
			local path = gui_filepicker(screen, nil, nil, nil, "dat", false, false)
			if path then
				flashData(assert(fs.readFile(path)))
			end
		end

		gRedraw()
		redraw()
	end
end

function wipeDataButton:onClick()
	if component.eeprom then
		if gui.pleaseCharge(screen, 20, "wipe data") then
			if gui.pleaseType(screen, "WDATA", "wipe data") then
				gui_status(screen, nil, nil, "wiping data...")
				local result = {pcall(component.eeprom.setData, "")}
				if not result[1] then
					gui.warn(screen, nil, nil, tostring(result[2] or "unknown error"))
				elseif result[3] then
					gui.warn(screen, nil, nil, tostring(result[3] or "unknown error"))
				end
			end
		end

		gRedraw()
		redraw()
	end
end

function dumpDataButton:onClick()
	if component.eeprom then
		local path = gui_filepicker(screen, nil, nil, nil, "dat", true, false)
		if path then
			local data = component.eeprom.getData()
			liked.assert(screen, fs.writeFile(path, data))
		end

		gRedraw()
		redraw()
	end
end

function makeReadOnlyButton:onClick()
	if component.eeprom then
		if storageRoState then
			gui.warn(screen, nil, nil, storageRo)
		elseif gui.pleaseCharge(screen, 20, "readonly") and gui.pleaseType(screen, "WLOCK", "make readonly") then
			pcall(component.eeprom.makeReadonly, component.eeprom.getChecksum())
		end

		gRedraw()
		redraw()
	end
end

function editButton:onClick()
	if component.eeprom and gui.pleaseCharge(screen, 20, "flash") then
		local file = os.tmpname()
		local data = component.eeprom.get()
		fs.writeFile(file, data)

		while true do
			upTask:suspend()
			assert(apps.execute("edit", screen, nil, file, storageRoState))
			upTask:resume()
			local newdata = assert(fs.readFile(file))
			if data == newdata then
				break
			end
			gRedraw()
			redraw()
			if not flashCode(newdata) then
				break
			end
		end

		gRedraw()
		redraw()
		fs.remove(file)
	end
end

function editDataButton:onClick()
	if component.eeprom and gui.pleaseCharge(screen, 20, "flash data") then
		local file = os.tmpname()
		local data = component.eeprom.getData()
		fs.writeFile(file, data)

		while true do
			upTask:suspend()
			assert(apps.execute("edit", screen, nil, file))
			upTask:resume()
			local newdata = assert(fs.readFile(file))
			if data == newdata then
				break
			end
			gRedraw()
			redraw()
			if not flashData(newdata) then
				break
			end
		end

		gRedraw()
		redraw()
		fs.remove(file)
	end
end

------------------------------------

function redraw()
	window:clear(colors.black)
	if component.eeprom then
		codeSizeLabel.text = "code size: " .. math.round(#component.eeprom.get())
		dataSizeLabel.text = "data size: " .. math.round(#component.eeprom.getData())
		maxCodeSizeLabel.text = "/ " .. math.round(tonumber(component.eeprom.getSize()) or 0)
		maxDataSizeLabel.text = "/ " .. math.round(tonumber(component.eeprom.getDataSize()) or 0)
		checksumLabel.text = "checksum : " .. tostring(component.eeprom.getChecksum())
		addrLabel.text     = "address  : " .. component.eeprom.address
		local isBootable = component.eeprom.address == bootloader.firstEeprom
		if isBootable then
			bootLabel.text     = "bootable : true"
		else
			bootLabel.text     = "bootable : " .. bootloader.firstEeprom
		end
		
		local writeble = not not component.eeprom.setLabel(component.eeprom.getLabel())
		storageRoState = not writeble
		writeLabel.text    = "storage  : " .. (writeble and "R/W" or "R/O")

		local label = component.eeprom.getLabel()
		labelInput.read.setBuffer(label)
		labelInput.oldText = label
	else
		codeSizeLabel.text = "code size: none"
		dataSizeLabel.text = "data size: none"
		maxCodeSizeLabel.text = "/ none"
		maxDataSizeLabel.text = "/ none"
		checksumLabel.text = "checksum : none"
		addrLabel.text     = "address  : none"
		writeLabel.text     = "storage  : none"
		bootLabel.text     = "bootable : " .. bootloader.firstEeprom
		labelInput.read.setBuffer(eepromMissingString)
		labelInput.oldText = eepromMissingString
	end
	layout:draw()
end
redraw()

return function(eventData)
	local windowEventData = window:uploadEvent(eventData)
	layout:uploadEvent(windowEventData)

	if (eventData[1] == "component_added" or eventData[1] == "component_removed") and eventData[3] == "eeprom" then
		redraw()
	end
end