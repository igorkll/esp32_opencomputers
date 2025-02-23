local registry = require("registry")
local internet = require("internet")
local json = require("json")
local graphic = require("graphic")
local apps = require("apps")
local lastinfo = require("lastinfo")
local uuid = require("uuid")
local gui = require("gui")
local uix = require("uix")
local paths = require("paths")
local fs = require("filesystem")
local event = require("event")
local component = require("component")
local unicode = require("unicode")
local computer = require("computer")
local text = require("text")
local account = {}

--local host = "http://127.0.0.1"
local host = "http://176.53.161.98"

local regHost = host .. "/likeID/reg/"
local unregHost = host .. "/likeID/unreg/"
local changePasswordHost = host .. "/likeID/changePassword/"
local getTokenHost = host .. "/likeID/getToken/"
local checkTokenHost = host .. "/likeID/checkToken/"
local userExistsHost = host .. "/likeID/userExists/"
local getLockedHost = host .. "/likeID/getLocked/"
local detachHost = host .. "/likeID/detach/"
local brickHost = host .. "/likeID/brick/"
local captchaHost = host .. "/likeID/captcha/"
local lockUpdateHost = host .. "/likeID/lockUpdate/"
local isPasswordHost = host .. "/likeID/isPassword/"
local lfsHost = host .. "/likeID/lfs/"

local function post(lhost, data)
	if type(data) == "table" then
		data = json.encode(data)
	end

	local card = internet.cardProxy()
	if not card then
		return false, "there is no internet card"
	end
	local userdata = card.request(lhost, data)
	local ok, err = internet.wait(userdata)
	if not ok then
		return nil, tostring(err or "unknown error")
	end

	local code = userdata.response()
	return code == 200, tostring(internet.readAll(userdata) or "no response body")
end
account._raw_post = post

--------------------------------

function account.getCaptcha()
	local ok, data = post(captchaHost, {})
	if ok then
		return data:sub(1, #uuid.null), data:sub(#uuid.null + 1, #data)
	end
end

function account.captcha(screen)
	local lNoShadow
	while true do
		gui.status(screen, nil, nil, "loading a captcha...")

		local id, img = account.getCaptcha()
		if not id then
			break
		end

		local imagePath = paths.concat("/tmp", id)
		fs.writeFile(imagePath, img)
		
		if lNoShadow then
			lNoShadow()
			lNoShadow = nil
		end

		-- draw
		local window, noShadow = gui.smallWindow(screen, nil, nil, nil, nil, nil, 50, 16)
		local layout = uix.create(window, uix.colors.lightGray)
		layout:createPlane(1, 1, layout.sizeX, 1, uix.colors.gray)
		layout:createVText(window.sizeX / 2, 2, uix.colors.white, "enter the text from the image")
		layout:createImage(2, 4, imagePath)
		local input = layout:createInput(12, 15, layout.sizeX - 12 - 9 - 1, uix.colors.white, uix.colors.black, nil, nil, nil, 8)
		local refresh = layout:createButton(2, 15, 9, 1, uix.colors.blue, uix.colors.white, "refresh", true)
		local enter = layout:createButton(50 - 9, 15, 9, 1, uix.colors.blue, uix.colors.white, "enter", true)
		local exit = layout:createButton(window.sizeX - 2, 1, 3, 1, uix.colors.red, uix.colors.white, "X", true)
		exit.style = uix.styles[2]
		layout:draw()
		fs.remove(imagePath)

		-- action

		local enterFlag
		function enter:onClick()
			enterFlag = true
			event.stub()
		end

		local refreshFlag
		function refresh:onClick()
			refreshFlag = true
			event.stub()
		end

		local exitFlag
		function exit:onClick()
			exitFlag = true
			event.stub()
		end

		function input:onTextAccepted()
			enterFlag = true
		end

		while true do
			local eventData = {event.pull(1)}
			local windowEventData = window:uploadEvent(eventData)
			layout:uploadEvent(windowEventData)

			if exitFlag then
				noShadow()
				return
			elseif refreshFlag then
				lNoShadow = noShadow
				break
			elseif enterFlag then
				return id, input.read.getBuffer(), noShadow
			end
		end
	end
end

--------------------------------

function account.deviceId()
	for uuid, value in pairs(lastinfo.deviceinfo) do
		if value.class == "processor" then
			return uuid
		end
	end
end

function account.check()
	if registry.account then
		if not post(userExistsHost, {name = registry.account}) then
			registry.accountToken = nil
			registry.account = nil
		end

		if registry.account and registry.accountToken then
			post(lockUpdateHost, {name = registry.account, token = registry.accountToken, device = account.deviceId()})
		end
	end
end

function account.updateToken(name, password)
	local ok, tokenOrError = post(getTokenHost, {name = name, password = password, device = account.deviceId()})
	if ok then
		registry.accountToken = tokenOrError
		event.push("accountChanged")
		return true
	else
		return nil, tokenOrError
	end
end

function account.checkToken()
	return registry.account and registry.accountToken and (post(checkTokenHost, {name = registry.account, token = registry.accountToken}))
end

function account.isStorage()
	return (not not registry.account) and internet.check()
end

function account.getStorage()
	if not account.isStorage() then return end    

	local card = internet.cardProxy()
	if not card then return end

	local socket = card.connect(host, 8723)
	if not socket then return end
	if not internet.wait(socket) then
		return
	end

	local endproxy

	local function umount()
		fs.umount(endproxy)
	end

	local function request(name, args)
		if not registry.account then
			umount()
			return
		end
		
		local sendTbl = {name = registry.account, token = registry.accountToken, method = name}
		local addContent
		if type(args) == "string" then
			addContent = args
		elseif type(args) == "table" then
			sendTbl.args = args
		else
			sendTbl.args = {}
		end
		

		local data = json.encode(sendTbl)
		if addContent then
			data = data .. "\n" .. addContent
		end
		socket.write(data)

		local startTime = computer.uptime()
		local str = ""
		local contentLen
		local first = true
		while true do
			local readed = socket.read(math.huge)
			if readed then
				str = str .. readed

				local function check()
					local firstChar = str:sub(1, 1)
					local lastChar = str:sub(#str, #str)

					if contentLen then
						if #str >= contentLen then
							return {str}
						end
					elseif (firstChar == "{" and lastChar == "}") or (firstChar == "[" and lastChar == "]") then
						local result = {pcall(json.decode, str)}
						if result[1] then
							return result[2] or {}
						end
					end
				end

				local result
				if first and #str >= 1 then
					if str:sub(1, 1) == "1" then
						str = str:sub(2, #str)
					elseif str:sub(1, 1) == "0" then
						local sepPos = str:find(text.escapePattern(":"))
						local lenStr = str:sub(2, sepPos - 1)
						contentLen = tonumber(lenStr)
						str = str:sub(sepPos + 1, #str)
					end
					first = nil
					result = check()
				else
					result = check()
				end
				if result then
					return table.unpack(result)
				end
			end
			if computer.uptime() - startTime > 10 then
				umount()
				return
			end
		end
	end

	------------------------------------

	local proxy = {}

	function proxy.spaceUsed()
		return request("spaceUsed")
	end

	function proxy.spaceTotal()
		return request("spaceTotal")
	end

	function proxy.exists(path)
		return request("exists", {path})
	end

	function proxy.isDirectory(path)
		return request("isDirectory", {path})
	end

	function proxy.lastModified(path)
		return request("lastModified", {path})
	end

	function proxy.remove(path)
		return request("remove", {path})
	end

	function proxy.rename(path, path2)
		return request("rename", {path, path2})
	end

	function proxy.size(path)
		return request("size", {path})
	end

	function proxy.makeDirectory(path)
		return request("makeDirectory", {path})
	end

	function proxy.list(path)
		return request("list", {path})
	end



	function proxy.isReadOnly()
		return request("isReadOnly")
	end

	function proxy.getLabel()
		return "cloudStorage"
	end

	function proxy.setLabel()
		error("label is readonly", 2)
	end

	------------------------------------

	local function readFile(path)
		return request("readFile", {path})
	end

	local function writeFile(path, data)
		if request("pushPath", {path}) then
			return request("pushContent", data)
		end
	end


	function proxy.close(obj)
		if obj.writeMode then
			writeFile(obj.path, obj.content)
		end
	end

	function proxy.read(obj, size)
		size = math.min(size, 2048)
		if obj.readMode then
			local str = obj.tool.sub(obj.content, obj.cur, obj.cur + (size - 1))
			local strlen = obj.tool.len(str)
			obj.cur = obj.cur + strlen
			if strlen > 0 then
				return str
			end
		end
	end

	function proxy.seek(obj, mode, offset)
		if mode == "cur" then
			obj.cur = obj.cur + offset
		elseif mode == "set" then
			obj.cur = offset + 1
		end
		if obj.cur < 1 then obj.cur = 1 end
		return obj.cur - 1
	end

	function proxy.write(obj, str)
		if obj.writeMode then
			obj.content = obj.content .. str
			return true
		end
	end

	function proxy.open(path, mode)
		mode = (mode or "rb"):lower()
		local modeChar = mode:sub(1, 1)
		local byteMode = mode:sub(2, 2) == "b"

		local obj = {}
		obj.path = path
		obj.readMode = modeChar == "r"
		obj.writeMode = modeChar == "w" or modeChar == "a"
		obj.content = ""
		obj.tool = byteMode and string or unicode
		obj.cur = 1

		if obj.readMode or modeChar == "a" then
			obj.content, obj.err = readFile(path)
			if not obj.content then
				return nil, obj.err
			end
		end

		return obj
	end

	------------------------------------

	endproxy = fs.mask(proxy)
	endproxy.cloud = true
	return endproxy
end

function account.loginWindow(screen)
	account.check()
	account.loginWindowOpenFlag = true
	local window = graphic.createWindow(screen)
	assert(apps.execute("/system/bin/setup.app/inet.lua", screen, nil, window, true, nil, true))
	account.loginWindowOpenFlag = nil
end

function account.isLoginWindowNeed(screen)
	return component.isPrimary(screen) and (registry.oldLocked or (internet.check() and account.getLocked() and not account.checkToken()))
end

function account.smartLoginWindow(screen)
	if account.isLoginWindowNeed(screen) then
		account.loginWindow(screen)
	end
end

--------------------------------

local function getLocked()
	local ok, data = post(getLockedHost, {device = account.deviceId()})
	if ok then
		return data
	end
end

function account.getLocked() --получает с сервера, на какую учетную запись заблокировано устройтсво
	local data = getLocked()
	if data and data:sub(1, 1) == "0" then
		return data:sub(2, #data)
	end
end

function account.isBricked()
	local data = getLocked()
	return data and data:sub(1, 1) == "1"
end

function account.getLogin()
	return registry.account
end

function account.login(name, password)
	local ok, err = account.updateToken(name, password)

	if ok then
		registry.account = name
		return true, "you have successfully login to your account"
	end

	return false, err
end

function account.checkPassword(name, password)
	return (post(isPasswordHost, {name = name, password = password}))
end

function account.unlogin(password)
	if not registry.account then
		return false, "you are not logged in to account"
	end

	local ok, err = post(detachHost, {name = registry.account, password = password, device = account.deviceId()})
	if ok then
		registry.account = nil
		registry.accountPassword = nil
		event.push("accountChanged")
		return true, "you have successfully logout from your account"
	else
		return false, err
	end
end


function account.register(name, password, cid, ccode)
	return post(regHost, {name = name, password = password, cid = cid, ccode = ccode})
end

function account.unregister(password)
	if not registry.account then
		return false, "you are not logged in to account"
	end

	local ok, err = post(unregHost, {name = registry.account, password = password})
	if ok then
		account.unlogin(password)
	end
	return ok, err
end

function account.changePassword(password, newPassword)
	if not registry.account then
		return false, "you are not logged in to account"
	end

	local ok, err = post(changePasswordHost, {name = registry.account, password = password, newPassword = newPassword})
	if ok then
		account.login(registry.account, newPassword)
	end
	return ok, err
end

account.unloadable = true
return account