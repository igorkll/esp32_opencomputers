local account = require("account")
local fs = require("filesystem")
local event = require("event")
local programs = require("programs")
local internet = require("internet")
local thread = require("thread")
local liked = require("liked")
local apps = require("apps")
local registry = require("registry")
local computer = require("computer")

if not liked.recoveryMode then
	local storagePath = "/data/userdata/cloudStorage"
	local publicStoragePath = "/data/userdata/publicStorage"

	assert(apps.execute("/system/liked/links.lua"))

	local function realCheck()
		apps.check()
		
		if internet.check() then
			account.check()
			
			if account.isStorage() then
				if not fs.exists(storagePath) then
					local storage = account.getStorage()
					if storage then
						fs.mount(storage, storagePath)
					end
				end
			elseif fs.exists(storagePath) then
				fs.umount(storagePath)
			end

			if account.isBricked() then
				assert(programs.execute("/system/liked/brick.lua"))
			end
		end
	end

	local function check()
		thread.createBackground(realCheck):resume()
	end

	realCheck()
	event.timer(60, check, math.huge)
	event.listen("accountChanged", check)
end

if registry.forceRestrictedLoader and not _restrictedLoader then
	local eepromlib = require("eeprom")
	local firmware = eepromlib.find("Restricted Loader")
	local errTitle = "the system configuration requires the \"Restricted Loader\" firmware. "
	if firmware then
		if not eepromlib.isFirmware(firmware) then
			if not eepromlib.hiddenFlash(firmware) then
				error(errTitle .. "failed to flash the EEPROM")
			end
			computer.shutdown("fast") --after flashing, you need to restart the computer, since there is no guarantee that spyware has not been installed in a third-party EEPROM
		end
	else
		error(errTitle .. "the firmware image could not be found")
	end
end