--local installdata = {data={branch="main",mode="full"},filesBlackList={},self=selfpath} --пристыковываеться к скрипту на этапе обновления

local component = component or require("component")
local computer = computer or require("computer")
local unicode = unicode or require("unicode")

local function initScreen(gpu, screen)
	if gpu.getScreen() ~= screen then
		gpu.bind(screen, false)
	end

	local mrx, mry = gpu.maxResolution()
	if mrx > 80 then
		mrx = 80
		mry = 25
	end

	gpu.setDepth(1)
	gpu.setDepth(gpu.maxDepth())
	gpu.setResolution(mrx, mry)
	gpu.setBackground(0)
	gpu.setForeground(0xffffff)
	gpu.fill(1, 1, mrx, mry, " ")
end

local function centerPrint(gpu, text, y)
	local rx, ry = gpu.getResolution()
	gpu.set((math.floor(rx / 2) - (#text / 2)) + 1, y, text)
end

local screensInited
local function printState(num)
	local str = "working with updates: " .. tostring(math.floor((num * 100) + 0.5)) .. "%"
	local gpu = component.proxy(component.list("gpu")() or "")
	local printed = false
	if gpu then
		for screen in component.list("screen") do
			-- init
			if not screensInited then
				initScreen(gpu, screen)

				if gpu.getDepth() > 1 then
					gpu.setPaletteColor(0, 0x5bb9f0)
					gpu.setPaletteColor(1, 0xffffff)
					gpu.setPaletteColor(2, 0x818181)
				else
					gpu.setBackground(0xffffff)
					gpu.setForeground(0x000000)
				end
			elseif gpu.getScreen() ~= screen then
				gpu.bind(screen, false)
			end

			-- draw
			local rx, ry = gpu.getResolution()
			local depth = gpu.getDepth()

			if depth > 1 then
				gpu.setBackground(0, true)
				gpu.setForeground(1, true)
			end

			local textPos = math.floor(ry / 2)

			gpu.fill(1, 1, rx, ry, " ")
			centerPrint(gpu, str, textPos)
			centerPrint(gpu, "please do not turn off the device!", ry - 1)
			if depth > 1 then
				gpu.setForeground(2, true)
			end
			gpu.fill(2, textPos + 1, rx - 2, 1, "⎯")
			if depth > 1 then
				gpu.setForeground(1, true)
			end
			gpu.fill(2, textPos + 1, math.floor(((rx - 2) * num) + 0.5), 1, "⠶")
			printed = true
		end
		screensInited = true
	end
	return printed
end

printState(0)

--------------------------------

local internet = component.proxy(component.list("internet")() or error("no internet card found", 0))
local proxy = component.proxy((...) or computer.getBootAddress())

local oldInterruptTime = 0
local function antiTLWY()
	local uptime = computer.uptime()
	if uptime - oldInterruptTime > 2 then
		computer.pullSignal(0.1)
		oldInterruptTime = uptime
	end
end

local function getInternetFile(url)
	local handle, data, result, reason = internet.request(url), ""
	if handle then
		while true do
			result, reason = handle.read(math.huge) 
			if result then
				data = data .. result
			else
				handle.close()
				
				if reason then
					return nil, reason
				else
					return data
				end
			end
		end
	else
		return nil, "unvalid address"
	end
end

local function split(str, sep)
	local parts, count, i = {}, 1, 1
	while 1 do
		if i > #str then break end
		local char = str:sub(i, #sep + (i - 1))
		if not parts[count] then parts[count] = "" end
		if char == sep then
			count = count + 1
			i = i + #sep
		else
			parts[count] = parts[count] .. str:sub(i, i)
			i = i + 1
		end
	end
	if str:sub(#str - (#sep - 1), #str) == sep then table.insert(parts, "") end
	return parts
end

local function segments(path)
	local parts = {}
	for part in path:gmatch("[^\\/]+") do
		local current, up = part:find("^%.?%.$")
		if current then
			if up == 2 then
				table.remove(parts)
			end
		else
			table.insert(parts, part)
		end
	end
	return parts
end

local function canonical(path)
	local result = table.concat(segments(path), "/")
	if unicode.sub(path, 1, 1) == "/" then
		return "/" .. result
	else
		return result
	end
end

local function fs_path(path)
	local parts = segments(path)
	local result = table.concat(parts, "/", 1, #parts - 1) .. "/"
	if unicode.sub(path, 1, 1) == "/" and unicode.sub(result, 1, 1) ~= "/" then
		return canonical("/" .. result)
	else
		return canonical(result)
	end
end

local function saveFile(path, data)
	proxy.makeDirectory(fs_path(path))
	local file = proxy.open(path, "wb")
	proxy.write(file, data)
	proxy.close(file)
end

local function inBlackList(path)
	path = canonical(path)
	if installdata.filesBlackList then
		for i, blackpath in ipairs(installdata.filesBlackList) do
			if canonical(blackpath) == path then
				return true
			end
		end
	end
end

local function installUrl(urlPart, state2)
	local filelist = split(assert(getInternetFile(urlPart .. "/installer/filelist.txt")), "\n")
	local count = 0
	for i, filepath in ipairs(filelist) do
		antiTLWY()
		if filepath ~= "" and not inBlackList(filepath) then
			local filedata = assert(getInternetFile(urlPart .. filepath))

			if count % 5 == 0 then
				printState((((i - 1) / (#filelist - 1)) / 2) + (state2 and 0.5 or 0))
			end

			saveFile(filepath, filedata)
			count = count + 1
		end
	end
end

local function sleep(time)
	local startTime = computer.uptime()
	repeat
		computer.pullSignal(time - (computer.uptime() - startTime))
	until computer.uptime() - startTime >= time
end

--------------------------------

--удаляем старую систему во избежании конфликта версий
proxy.remove("/system")

--сначала ставим liked а только потом ядро, чтобы не перезаписывать init.lua раньше времени. чтобы если обновления оборветься то система не окирпичилась
installUrl("https://raw.githubusercontent.com/igorkll/liked/" .. installdata.data.branch)
installUrl("https://raw.githubusercontent.com/igorkll/likeOS/" .. installdata.data.branch, true)

--востанавливаем содержимое sysdata
for name, content in pairs(installdata.data) do
	saveFile("/system/sysdata/" .. name, content)
end

--устанавливаем label диска при необходимости
if installdata.label then
	pcall(proxy.setLabel, installdata.label)
end

--удаляем свой же файл, чтобы после перезагрузки обновления не началось заного
if installdata.self then
	proxy.remove(installdata.self)
end

--отображаем 100% в течении секунды
local setBootAddr = not installdata.noSetBootaddress and computer.getBootAddress and computer.setBootAddress and computer.getBootAddress() ~= proxy.address
if printState(1) then
	if setBootAddr then
		computer.setBootAddress(proxy.address)
	elseif not installdata.noWait then
		sleep(1)
	end
elseif setBootAddr then
	computer.setBootAddress(proxy.address)
end

--перезагружаем устройтсво
if not installdata.noReboot then
	computer.shutdown("fast")
end