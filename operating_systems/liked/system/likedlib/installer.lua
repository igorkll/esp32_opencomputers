local fs = require("filesystem")
local gui = require("gui")
local paths = require("paths")
local liked = require("liked")
local serialization = require("serialization")
local installer = {}

local targetsys = "/mnt/tmpmount"
local selfsys = "/mnt/selfsys"

local rootfs = fs.get("/")

----------------------------------------------------------------------

function installer.init(vfs)
	fs.umount(targetsys)
	fs.umount(selfsys)

	local success, err = fs.mount(vfs, targetsys)
	if not success then return nil, err end

	local success, err = fs.mount(rootfs, selfsys)
	if not success then return nil, err end

	return true
end

function installer.uinit(vfs, label, ...)
	liked.umountAll()
	pcall(vfs.setLabel, label)
	fs.umount(targetsys)
	fs.umount(selfsys)
	liked.mountAll()
	return ...
end

function installer.selfPath(path)
	return paths.concat(selfsys, path)
end

function installer.targetPath(path)
	return paths.concat(targetsys, path)
end

function installer.toTarget(path)
	return fs.copy(installer.selfPath(path), installer.targetPath(path))
end

function installer.rmTarget(path)
	return fs.remove(installer.targetPath(path))
end

----------------------------------------------------------------------

function installer.install_core(vfs)
	local success, err = installer.init(vfs)
	if not success then return nil, err end

	local success, err = installer.toTarget("init.lua")
	if not success then return nil, err end

	installer.rmTarget("system/core") --удаляю старое ядра чтобы не было канфликтов версий и не оставалось лишних файлов
	return installer.uinit(vfs, "likeOS", installer.toTarget("system/core"))
end

function installer.install_liked(vfs)
	local success, err = installer.init(vfs)
	if not success then return nil, err end

	local success, err = installer.toTarget("init.lua")
	if not success then return nil, err end

	installer.rmTarget("system") --удаляю старую систему чтобы не было канфликтов версий и не оставалось лишних файлов
	
	local success, err = installer.toTarget("system")
	if not success then return nil, err end

	installer.rmTarget("system/sysdata/eeprom") --the cloned system should not be linked to the EEPROM

	return installer.uinit(vfs, "liked", true)
end

function installer.install_likedbox(vfs)
	local success, err = installer.init(vfs)
	if not success then return nil, err end

	local success, err = installer.toTarget("init.lua")
	if not success then return nil, err end

	installer.rmTarget("system")

	local bl = assert(serialization.load("/system/liked/box.lst"))
	local systemFolder = installer.selfPath("system")
	local targetSystemFolder = installer.targetPath("system")
	local success, err = fs.copy(systemFolder, targetSystemFolder, function (from)
		for _, lpath in ipairs(bl) do
			if paths.equals(paths.concat(systemFolder, lpath), from) then
				return false
			end
		end
		
		return true
	end)
	if not success then return nil, err end

	return installer.uinit(vfs, "likedbox", fs.copy(installer.selfPath("system/likedbox"), targetSystemFolder))
end

function installer.install_installer(vfs)
	local success, err = installer.init(vfs)
	if not success then return nil, err end

	installer.rmTarget(".")
	return installer.uinit(vfs, "liked installer", fs.copy(installer.selfPath("system/installer"), installer.targetPath(".")))
end

function installer.install_selfsys(vfs)
	local success, err = installer.init(vfs)
	if not success then return nil, err end

	installer.rmTarget("system")
	return installer.uinit(vfs, rootfs.getLabel() or "self-sys", installer.toTarget("."))
end

function installer.install_boxfile(vfs, path, splashCallback)
	local success, err = installer.init(vfs)
	if not success then return nil, err end

	-- format
	if splashCallback then splashCallback("formatting...") end
	installer.rmTarget(".")
	
	-- installing likedbox or core
	local exp = paths.extension(path) 
	local ok, err
	if exp == "sbox" then
		if splashCallback then splashCallback("installing core...") end
		ok, err = installer.install_core(vfs)
	elseif exp == "vbox" then
		if splashCallback then splashCallback("installing liked...") end
		ok, err = installer.install_liked(vfs)
	elseif exp == "ebox" then
		-- nothing
		ok = true
	else
		if splashCallback then splashCallback("installing box...") end
		ok, err = installer.install_likedbox(vfs)
	end

	local inited = installer.init(vfs)
	if ok and inited then
		-- unpacking archive
		if splashCallback then splashCallback("unpacking archive...") end
		local aok, aerr = require("archiver").unpack(path, targetsys)

		-- set label
		liked.umountAll()
		if aok then
			pcall(vfs.setLabel, paths.hideExtension(paths.name(path)))
			liked.mountAll()
		else
			pcall(vfs.setLabel, "failed")
			liked.mountAll()
			return nil, aerr
		end
	end

	return ok, err
end

----------------------------------------------------------------------

function installer.ui_install_boxfile(screen, vfs, path)
	local clear
	return installer.install_boxfile(vfs, path, function (str)
		if clear then clear() end
		clear = gui.saveZone(screen)
		gui.status(screen, nil, nil, str)
	end)
end

function installer.context(screen, posX, posY, vfs)
	local label, num = gui.contextAuto(screen, posX, posY, {
		"liked installer",
		"liked",
		"likedbox",
		"likeOS (core only)",
		"full cloning of the system"
	})

	if not label then
		return
	end

	if num == 5 then
		label = "self-sys"
	end

	local installers = {
		installer.install_installer,
		installer.install_liked,
		installer.install_likedbox,
		installer.install_core,
		installer.install_selfsys,
	}

	local name = paths.name(require("hdd").genName(vfs))
	local clear = gui.saveZone(screen)
	if gui.yesno(screen, nil, nil, "install \"" .. label .. "\" to \"" .. name .. "\"?") then
		gui.status(screen, nil, nil, "installing \"" .. label .. "\" to \"" .. name .. "\"...")
		local result = {liked.assert(screen, installers[num](vfs))}
		clear()
		return table.unpack(result)
	end
	clear()
end

installer.unloadable = true
return installer