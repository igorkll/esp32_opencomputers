local component = component or require("component")
local bootloader = bootloader or require("bootloader")
local computer = computer or require("computer")

local bootfs = bootloader.bootfs

local startupPath = "/likeOS_startup.lua"
local strs = {
	"Recovery From Internet",
	"Reset Settings (does not delete data)",
	"Start The System In Recovery Mode",
	"Run System Web Installer"
}
local funcs = {
	function (str)
		if component.list("internet")() then
			if recoveryApi.yesno(str) then
				local sysdata = {branch = "main", mode = "full"}
				for _, file in ipairs(bootfs.list("/system/sysdata") or {}) do
					sysdata[file] = bootloader.readFile(bootfs, "/system/sysdata/" .. file)
				end

				local sysdataStr = "{data={"
				for key, data in pairs(sysdata) do
					sysdataStr = sysdataStr .. key .. "=\"" .. data .. "\","
				end
				sysdataStr = sysdataStr .. "},self=\"" .. startupPath .. "\"}"

				local content = "local installdata = " .. sysdataStr .. "\n" .. bootloader.readFile(bootfs, "/system/likedlib/update/update.lua")
				if bootloader.writeFile(bootfs, startupPath, content) then
					local tmpfs = component.proxy(bootloader.tmpaddress)
                    tmpfs.makeDirectory("/bootloader")
					bootloader.writeFile(tmpfs, "/bootloader/bootaddr", bootfs.address)
					computer.shutdown("fast")
				end
			end
		else
			recoveryApi.info("An internet card is required")
		end
	end,
	function (str)
		if recoveryApi.yesno(str) then
			bootloader.dofile("/system/liked/reset.lua", _ENV, bootfs)
			recoveryApi.info("Settings Successfully Reset")
		end
	end,
	function ()
		if not require then
			recoveryApi.info({"Initializing The Kernel", "Please Wait"}, true)
			local ok, err = pcall(bootloader.bootstrap)
			if not ok then
				recoveryApi.info(tostring(err or "Unknown Error"))
			end
		end

		bootloader.recoveryMode = true
		bootloader.recoveryApi = recoveryApi
		bootloader.runShell(bootloader.defaultShellPath, recoveryApi.screen)
	end,
	function ()
		if component.list("internet")() then
			recoveryApi.info({"Downloading The Installer", "Please Wait"}, true)
			local branch = "main"
			local branchPath = "/system/sysdata/branch"
			if bootfs.exists(branchPath) then
				branch = bootloader.readFile(bootfs, branchPath)
			end
			local url = "https://raw.githubusercontent.com/igorkll/liked/" .. branch .. "/installer/webInstaller.lua"
			local installer, err = recoveryApi.wget(url)
			if not installer then
				recoveryApi.info(tostring(err))
				return
			end
			assert(load(installer, "=installer", nil, _G))()
		else
			recoveryApi.info("An internet card is required")
		end
	end
}

if bootfs.exists(startupPath) then
	strs[1] = "Cancel Scheduled Recover"
	funcs[1] = function ()
		bootfs.remove(startupPath)
		computer.shutdown("fast")
	end
end

recoveryApi.menu("Liked Recovery Tool", strs, funcs)