local fs = require("filesystem")
local paths = require("paths")
local event = require("event")
local component = require("component")
local computer = require("computer")
local registry = require("registry")
local bootloader = require("bootloader")

if not registry.doNotMoundDisks then
	local function allowMount(address)
		return address ~= computer.tmpAddress() and address ~= fs.bootaddress
	end

	local mountlist = {}

	local function tryMount(uuid)
		if bootloader.runlevel ~= "init" then
			if registry.diskSound then
				computer.beep(2000, 0.1)
			end
			event.push("redrawDesktop")
		end
		local mountpoint = require("hdd").genName(uuid)
		if not fs.exists(mountpoint) then
			fs.mount(uuid, mountpoint)
		end
		mountlist[uuid] = mountpoint
	end

	event.listen("component_added", function(_, uuid, name)
		if name == "filesystem" and allowMount(uuid) then
			tryMount(uuid)
		end
	end)

	event.listen("component_removed", function(_, uuid, name)
		if name == "filesystem" and allowMount(uuid) then
			if mountlist[uuid] then
				if bootloader.runlevel ~= "init" then
					if registry.diskSound then
						computer.beep(1000, 0.1)
					end
					event.push("redrawDesktop")
				end
				fs.umount(mountlist[uuid])
				mountlist[uuid] = nil
			end
		end
	end)

	for address in component.list("filesystem", true) do
		if allowMount(address) then
			tryMount(address)
		end
	end
end