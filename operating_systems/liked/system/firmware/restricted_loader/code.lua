if not bootAddress then
	error("the address of the boot disk was not added to \"Restricted Loader\", it is incorrect to flash the EEPROM", 0)
end

_restrictedLoader = true
local eeprom = component.list("eeprom")()
local invoke = component.invoke
function component.invoke(address, method, ...)
	if address == eeprom then
		if method == "setData" or method == "getData" then
			return ""
		end
	end
	return invoke(address, method, ...)
end

computer.setBootAddress = function(address)
end

computer.getBootAddress = function()
	return bootAddress
end

do
	local screen = component.list("screen")()
	local gpu = component.list("gpu")()
	if gpu and screen then
		invoke(gpu, "bind", screen)
	end
end

local ignore = {
	["/system/sysdata/eeprom"] = 1
}
local function checkSystem(address)
	if not invoke(address, "exists", "/init.lua") then
		return false
	end
	local lastModTime = tonumber(invoke(eeprom, "getData"))
	local function checkFile(path)
		if ignore[path] then return false end
		return invoke(address, "lastModified", path) > lastModTime
	end
	local function process(dir)
		for _, name in ipairs(invoke(address, "list", dir) or {}) do
			local path = dir .. name
			if invoke(address, "isDirectory", path) then
				if process(path) then return true end
			elseif checkFile(path) then
				return true
			end
		end
	end
	if process("/system/") then return false end
	if checkFile("/init.lua") then return false end
	return true
end

local function readFile(address, path)
	local file = invoke(address, "open", path)
	local buffer = ""
	repeat
		local data = invoke(address, "read", file, math.maxinteger or math.huge)
		buffer = buffer .. (data or "")
	until not data
	invoke(address, "close", file)
	return buffer
end

local function writeFile(address, path, data)
	local file = invoke(address, "open", path, "wb")
	if file then
		invoke(address, "write", file, data)
		invoke(address, "close", file)
	end
end

if not component.proxy(bootAddress) then
	error("restricted loader: the boot disk is missing (" .. bootAddress:sub(1, 6) .. ")", 0)
end

local tmpAddress = computer.tmpAddress()
invoke(tmpAddress, "remove", "/bootloader") --disabling redirect to other operating systems
invoke(tmpAddress, "makeDirectory", "/bootloader") --blocks bootmanager startup
writeFile(tmpAddress, "/bootloader/noRecovery", "")

invoke(bootAddress, "makeDirectory", "/system/sysdata")
writeFile(bootAddress, "/system/sysdata/eeprom", eeprom) --link the system to the EEPROM

invoke(bootAddress, "remove", "/likeOS_startup.lua")
invoke(bootAddress, "remove", "/bootmanager") --attempt to remove bootmanager. restricted loader runs only the verified operating systems
invoke(bootAddress, "remove", "/vendor/apps/bootmanager.app")
invoke(bootAddress, "remove", "/system/core/recovery.lua")

if not checkSystem(bootAddress) then
	error("restricted loader: the system failed verification", 0)
end

computer.beep(1000, 0.2)
assert(load(readFile(bootAddress, "/init.lua"), "=init"))()