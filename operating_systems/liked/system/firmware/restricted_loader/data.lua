local gui = require("gui")
local fs = require("filesystem")
local component = require("component")
local time = require("time")
local computer = require("computer")
local registry = require("registry")
local bootloader = require("bootloader")
local serialization = require("serialization")

local screen, _, hidden, otherDevice = ...
local appendData = "local bootAddress = \"" .. fs.bootaddress .. "\"\n"

local selectedDisk
if otherDevice then
	local clear = gui.saveBigZone(screen)
	selectedDisk = gui.selectExternalFs(screen)
	clear()
	if not selectedDisk then
		return true
	end
	appendData = "local bootAddress = \"" .. selectedDisk.address .. "\"\n"
end

local function applyRestrictions(disk)
	local eeprom = component.list("eeprom")()

	local registryData = bootloader.readFile(disk, "/data/registry.dat")
	if registryData then
		local registryTable = serialization.unserialize(registryData)
		if type(registryTable) == "table" then
			registryTable.disableRecovery = true
			bootloader.writeFile(disk, "/data/registry.dat", serialization.serialize(registryTable))
		end
	end

	disk.makeDirectory("/system/sysdata")
	bootloader.writeFile(disk, "/system/sysdata/eeprom", eeprom) --link the system to the EEPROM

	disk.remove("/likeOS_startup.lua")
	disk.remove("/bootmanager") --attempt to remove bootmanager. restricted loader runs only the verified operating systems
	disk.remove("/vendor/apps/bootmanager.app")
	disk.remove("/system/core/recovery.lua")
end

local function apply()
	local eeprom = component.list("eeprom")()
	applyRestrictions(selectedDisk or bootloader.bootfs)
	component.invoke(eeprom, "makeReadonly", component.invoke(eeprom, "getChecksum"))
	component.invoke(eeprom, "setData", tostring(time.getRealTime()))
	if not otherDevice then
		computer.shutdown("fast")
	end
end

if hidden then
	return nil, appendData, apply
end

local clear = gui.saveBigZone(screen)

if not otherDevice then
	if not gui.nextOrCancel(screen, nil, nil, "Attention!!! after installation, you will not be able to boot into other operating systems") then
		return true
	end
end

if not gui.nextOrCancel(screen, nil, nil, "Attention!!! this loader verifies the authenticity of your OS for changes, it will not load the OS if changes are made to it") then
	return true
end

if not gui.nextOrCancel(screen, nil, nil, "Attention!!! with this loader, you will not be able to use bootmanager. bootmanager will simply be deleted from the computer if it has been installed") then
	return true
end

if not gui.nextOrCancel(screen, nil, nil, "Attention!!! this loader will not allow you to boot from other disks except from where it was installed") then
	return true
end

if not gui.nextOrCancel(screen, nil, nil, "Attention!!! you will not be able to use the system recovery menu after installation") then
	return true
end

if not gui.nextOrCancel(screen, nil, nil, "Attention!!! your operating system will no longer be able to boot using another EEPROM") then
	return true
end

if not gui.nextOrCancel(screen, nil, nil, "Attention!!! after installation, the EEPROM will automatically become readonly, it will be possible to remove \"Restricted Loader\" only by replacing the EEPROM and manually reinstalling the system from recovery(after replacing the EEPROM, the system cannot be started, but you will be able to open recovery)") then
	return true
end

if not gui.nextOrCancel(screen, nil, nil, "this thing is needed for extremely specific tasks, DO NOT INSTALL IT IF YOU DO NOT KNOW WHY YOU NEED IT") then
	return true
end

clear()
return nil, appendData, apply