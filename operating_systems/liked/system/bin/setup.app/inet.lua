local uix = require("uix")
local fs = require("filesystem")
local graphic = require("graphic")
local colorlib = require("colors")
local computer = require("computer")
local registry = require("registry")
local internet = require("internet")
local image = require("image")
local gui = require("gui")
local account = require("account")
local event = require("event")

local screen, _, window, autoexit, noCaptcha, rsButtons = ...
local ui = uix.manager(screen)
ui.window = window
local rx, ry = ui:size()
local pwx, pwy
if window then
	rx, ry = window.sizeX, window.sizeY
	pwx, pwy = (window.sizeX / 2) - (gui.zoneX / 2), (window.sizeY / 2) - (gui.zoneY / 2)
end
local tier1 = graphic.getDepth(screen) == 1

local function addRSbuttons(layout)
	if rsButtons then
		local reboot = layout:createButton(rx - 17, 4, 16, 1, uix.colors.lightBlue, uix.colors.white, "reboot", true)
		function reboot:onClick()
			computer.shutdown(true, true)
		end

		local shutdown = layout:createButton(rx - 17, 2, 16, 1, uix.colors.lightBlue, uix.colors.white, "shutdown", true)
		function shutdown:onClick()
			computer.shutdown(nil, true)
		end
	end
end

--------------------------------

local inetLayout = ui:simpleCreate(uix.colors.cyan, uix.styles[2])
inetLayout.imagePath = uix.getSysImgPath("noInternet")
inetLayout:createLabel(2, 2, inetLayout.window.sizeX - 2, 1, uix.colors.cyan, uix.colors.white, "there is no internet connection")
if not tier1 then
	inetLayout:createImage((rx / 2) - (image.sizeX(inetLayout.imagePath) / 2), 4, inetLayout.imagePath)
end

addRSbuttons(inetLayout)

local recheckButton = inetLayout:createButton(rx - 17, ry - 1, 16, 1, uix.colors.lightBlue, uix.colors.white, "recheck", true)
function recheckButton:onClick()
	if internet.check() then
		ui:select(accountLayout)
	else
		gui.warn(screen, nil, nil, "there is still no internet connection")
		ui:draw()
	end
end

if not window then
	local backButton = inetLayout:createButton(3, ry - 1, 8, 1, uix.colors.lightBlue, uix.colors.white, " ← back", true)
	function backButton:onClick()
		os.exit()
	end

	local skipButton = inetLayout:createButton(rx - 17, ry - 3, 16, 1, uix.colors.lightBlue, uix.colors.white, "skip internet", true)
	function skipButton:onClick()
		doSetup("end")
		os.exit()
	end
end

--------------------------------

local loginInputPos = math.ceil((rx / 2) - 20) + 1
local bpos = math.ceil((rx / 2) - 8) + 1
local offset = 0
if tier1 then
	offset = 3
end

accountLayout = ui:simpleCreate(uix.colors.cyan, uix.styles[2])
loginZone = accountLayout:createInput(loginInputPos, ry - 8 - offset, 40, uix.colors.white, uix.colors.black, false, nil, nil, nil,    "login   : ")
passwordZone = accountLayout:createInput(loginInputPos, ry - 6 - offset, 40, uix.colors.white, uix.colors.black, true, nil, nil, nil,  "password: ")
passwordZone2 = accountLayout:createInput(loginInputPos, ry - 4 - offset, 40, uix.colors.white, uix.colors.black, true, nil, nil, nil, "password: ")

registerButton = accountLayout:createButton(bpos - 10, ry - 2 - offset, 16, 1, uix.colors.lightBlue, uix.colors.white, "register", true)
loginButton = accountLayout:createButton(bpos + 10, ry - 2 - offset, 16, 1, uix.colors.lightBlue, uix.colors.white, "login", true)

accountDelButton = accountLayout:createButton(bpos - 10, ry - 2 - offset, 16, 1, uix.colors.lightBlue, uix.colors.white, "delete account", true)
unloginButton = accountLayout:createButton(bpos + 10, ry - 2 - offset, 16, 1, uix.colors.lightBlue, uix.colors.white, "logout", true)

changePassword = accountLayout:createButton(3, 2, 17, 1, uix.colors.lightBlue, uix.colors.white, "change password", true)
devicesControl = accountLayout:createButton(3, 4, 17, 1, uix.colors.lightBlue, uix.colors.white, "devices control", true)

addRSbuttons(accountLayout)

if not window then
	next3 = accountLayout:createButton(rx - 7, ry - 1, 6, 1, uix.colors.lightBlue, uix.colors.white, "next", true)
	function next3:onClick()
		doSetup("end")
		os.exit()
	end
end

local function doLocked(locked)
	if locked then
		event.push("closeSettings", screen)
	end

	if not locked then
		locked = nil
	end

	if locked ~= registry.oldLocked then
		if locked then
			registry.old_disableRecovery = registry.disableRecovery
			registry.disableRecovery = true
		else
			registry.disableRecovery = registry.old_disableRecovery
			registry.old_disableRecovery = nil
		end
		registry.oldLocked = locked
	end
end

function accountLayout:onSelect()
	if not accountLayout.imagePath then
		gui.status(screen, nil, nil, "internet connection...")
		accountLayout.locked = account.getLocked()
		accountLayout.login = account.getLogin()
		accountLayout.tokenIsValid = account.checkToken()

		loginZone.read.setBuffer("")
		passwordZone.read.setBuffer("")
		passwordZone2.read.setBuffer("")
		loginZone.read.setLock(false)

		registerButton.disabledHidden = true
		loginButton.disabledHidden = true
		accountDelButton.disabledHidden = true
		unloginButton.disabledHidden = true
		changePassword.disabledHidden = true
		devicesControl.disabledHidden = true
		
		if next3 then
			next3.disabledHidden = false
		end

		if vtext1 then vtext1:destroy() end
		if vtext2 then vtext2:destroy() end
		if accountImage then accountImage:destroy() end

		local locked
		if accountLayout.login and accountLayout.tokenIsValid then
			accountLayout.imagePath = uix.getSysImgPath("accountLogin")
			if not tier1 then
				accountImage = accountLayout:createImage(((rx / 2) - (image.sizeX(accountLayout.imagePath) / 2)) + 1, 2, accountLayout.imagePath)
				accountImage.wallpaperMode = true
			end

			loginZone.read.setBuffer(accountLayout.login)
			loginZone.read.setLock(true)

			accountDelButton.disabledHidden = false
			unloginButton.disabledHidden = false
			changePassword.disabledHidden = false
			devicesControl.disabledHidden = false
		elseif accountLayout.locked then
			locked = true
			
			accountLayout.imagePath = uix.getSysImgPath("accountLock")
			if not tier1 then
				accountImage = accountLayout:createImage(((rx / 2) - (image.sizeX(accountLayout.imagePath) / 2)) + 1, 2, accountLayout.imagePath)
				accountImage.wallpaperMode = true
			end

			loginZone.read.setBuffer(accountLayout.locked)
			loginZone.read.setLock(true)

			vtext1 = accountLayout:createVText(rx / 2, ry - 11, uix.colors.orange, "your device is locked")
			vtext2 = accountLayout:createVText(rx / 2, ry - 10, uix.colors.orange, "enter account password to confirm that you are the owner")

			if next3 then
				next3.disabledHidden = true
			end
			loginButton.disabledHidden = false
		else
			accountLayout.imagePath = uix.getSysImgPath("account")
			if not tier1 then
				accountImage = accountLayout:createImage(((rx / 2) - (image.sizeX(accountLayout.imagePath) / 2)) + 1, 2, accountLayout.imagePath)
				accountImage.wallpaperMode = true
			end

			registerButton.disabledHidden = false
			loginButton.disabledHidden = false
		end
		doLocked(locked)
	end
end

local function pass()
	local pass1 = passwordZone.read.getBuffer()
	local pass2 = passwordZone2.read.getBuffer()
	if pass1 == pass2 then
		return pass1
	else
		gui.warn(screen, nil, nil, "passwords don't equals")
		ui:draw()
	end
end

local function pass2()
	local pass1 = gui.input(screen, nil, nil, "new password", true)
	if not pass1 then ui:draw() return end
	local pass2 = gui.input(screen, nil, nil, "confirm the password", true)
	if not pass2 then ui:draw() return end

	if pass1 == pass2 then
		ui:draw()
		return pass1
	else
		gui.warn(screen, nil, nil, "passwords don't equals")
		ui:draw()
	end
end

local function msg(ok, msg)
	gui.done(screen, nil, nil, tostring(msg) or "unknown error")
	ui:draw()

	return ok
end

local function refresh()
	accountLayout.imagePath = nil
	ui:select(accountLayout)
end

function registerButton:onClick()
	local pass = pass()
	if pass then
		local name = loginZone.read.getBuffer()
		local cid, ccode = account.captcha(screen)
		if cid then
			if msg(account.register(name, pass, cid, ccode)) then
				if noCaptcha then
					noCaptcha()
				end
				account.login(name, pass)
				refresh()
				return true
			end
		end
		
		if noCaptcha then
			noCaptcha()
		end
		ui:draw()
	end
end

function loginButton:onClick()
	local pass = pass()
	if pass then
		if msg(account.login(loginZone.read.getBuffer(), pass)) then
			if autoexit then
				doLocked(false)
				os.exit()
				return
			end
			
			refresh()
			return true
		end
	end
end

function changePassword:onClick()
	local pass = pass()
	if pass then
		local newPassword = pass2()
		if newPassword then
			if msg(account.changePassword(pass, newPassword)) then
				refresh()
				return true
			end
		end
	end
end

function accountDelButton:onClick()
	local pass = pass()
	if pass and gui.yesno(screen, nil, nil, "do you really want to delete your account :(") and gui.pleaseType(screen, "ACDEL", "delete account") then
		if msg(account.unregister(pass)) then
			refresh()
			return true
		end
	else
		ui:draw()
	end
end

function unloginButton:onClick()
	local pass = pass()
	if pass then
		if msg(account.unlogin(pass)) then
			refresh()
			return true
		end
	end
end

if not window then
	local backButton2 = accountLayout:createButton(3, ry - 1, 8, 1, uix.colors.lightBlue, uix.colors.white, " ← back", true)
	function backButton2:onClick()
		os.exit()
	end
end

--------------------------------

if internet.check() then
	ui:select(accountLayout)
else
	ui:select(inetLayout)
end
ui:loop()