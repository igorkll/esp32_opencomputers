local fs = require("filesystem")
local component = require("component")
local registry = require("registry")
local paths = require("paths")
local hdd = {}

function hdd.get(proxy)
	if type(proxy) == "string" then
		proxy = component.proxy(proxy)
	end

	if proxy.type == "filesystem" then
		return proxy
	end
end

function hdd.move(from, to)
	from = hdd.get(from)
	to = hdd.get(to)
	fs.umount("/mnt/from")
	fs.umount("/mnt/to")
	fs.mount(from, "/mnt/from")
	fs.mount(to, "/mnt/to")
	local result = {fs.copy("/mnt/from", "/mnt/to")}
	fs.umount("/mnt/from")
	fs.umount("/mnt/to")
	return table.unpack(result)
end

function hdd.genName(uuid)
	local label
	if type(uuid) == "table" then
		label = uuid.getLabel()
		uuid = uuid.address
	else
		label = component.invoke(uuid, "getLabel")
	end
	if label and #label == 0 then
		label = nil
	end
	return paths.concat("/data/userdata", (label or "disk"):sub(1, 8) .. "-" .. uuid:sub(1, 5))
end

function hdd.clone(screen, proxy, selectFrom)
	local gui = require("gui")

	local from, to
	local blacklist = {proxy.address, fs.tmpaddress}
	if registry.disableRootAccess then
		table.insert(blacklist, fs.bootaddress)
	end

	local clear = saveBigZone(screen)

	if selectFrom then
		to = proxy
		from = gui.selectcomponentProxy(screen, nil, nil, {"filesystem"}, false, nil, nil, blacklist)
	else
		for addr in component.list("filesystem", true) do
			if component.invoke(addr, "isReadOnly") then
				table.insert(blacklist, addr)
			end
		end

		to = gui.selectcomponentProxy(screen, nil, nil, {"filesystem"}, false, nil, nil, blacklist)
		from = proxy
	end

	if not to or not from then
		return
	end

	clear()

	local isRoot = to.address == fs.bootaddress
	if isRoot and registry.disableRootAccess then
		gui.warn(screen, nil, nil, "it is not possible to clone a disk to a system disk")
		return
	end

	local fromname = paths.name(hdd.genName(from))
	local toname = paths.name(hdd.genName(to))

	if (not isRoot or gui.pleaseType(screen, "TOROOT", "clone to root")) and gui.yesno(screen, nil, nil, "are you sure you want to clone an \"" .. fromname .. "\" drive to a \"" .. toname .. "\" drive?") then
		gui.status(screen, nil, nil, "cloning the \"" .. fromname .. "\" disk to \"" .. toname .. "\"")
		local liked = require("liked")
		liked.umountAll()
		local ok, err = hdd.move(from, to)
		if ok then
			local fromlabel = from.getLabel()
			if fromlabel then
				pcall(to.setLabel, fromlabel)
			end
		end
		liked.mountAll()
		return liked.assertNoClear(screen, ok, err)
	end
end

hdd.unloadable = true
return hdd