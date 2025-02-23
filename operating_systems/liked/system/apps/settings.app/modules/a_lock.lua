local graphic = require("graphic")
local gui_container = require("gui_container")
local registry = require("registry")
local uuid = require("uuid")
local gui = require("gui")
local uix = require("uix")

local colors = gui_container.colors

------------------------------------

local screen, posX, posY = ...
local gpu = graphic.findGpu(screen)
local rx, ry = gpu.getResolution()

------------------------------------

local window = graphic.createWindow(screen, posX, posY, rx - (posX - 1), ry - (posY - 1))
local layout = uix.create(window, colors.black)

local encryptionTitle = layout:createText(2, 4, colors.white, "userdata encryption: ")
local encryptionSwitch = layout:createSwitch(encryptionTitle.x + #encryptionTitle.text, 4)
encryptionSwitch.state = not not registry.encrypt

function encryptionSwitch:onSwitch()
	if self.state then
		if registry.password then
			local ok, password = gui.checkPassword(screen)
			if ok then
				require("efs").encrypt(password)
			else
				self.state = false
			end
		else
			gui.warn(screen, nil, nil, "to use userdata encryption, you must set a password")
			self.state = false
		end
	else
		local ok, password = gui.checkPassword(screen)
		if ok then
			require("efs").decrypt(password)
		else
			self.state = true
		end
	end
	layout:draw()
end

local passwordTitle = layout:createText(2, 2, colors.white, "use password: ")
local passwordSwitch = layout:createSwitch(passwordTitle.x + #passwordTitle.text, 2)
passwordSwitch.state = not not registry.password

function passwordSwitch:onSwitch()
	if self.state then
		if not registry.password then
			local password = gui.comfurmPassword(screen)
			if password then
				local salt = uuid.next()
				registry.password = require("sha256").sha256hex(password .. salt)
				registry.passwordSalt = salt
			else
				self.state = false
			end
		end
	elseif registry.password then
		local ok, password = gui.checkPassword(screen)
		if ok then
			registry.password = nil
			registry.passwordSalt = nil
			if registry.encrypt then
				require("efs").decrypt(password)
				encryptionSwitch.state = false
			end
		else
			self.state = true
		end
	end
	layout:draw()
end

layout:draw()

------------------------------------

return function(eventData)
	layout:uploadEvent(eventData)
end