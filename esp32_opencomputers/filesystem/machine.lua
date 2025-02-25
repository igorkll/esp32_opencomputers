local resolutionX = 80
local resolutionY = 25
local maxEepromCodeLen = 4096
local maxEepromDataLen = 256
local seconderyTouchTime = 1


local debugMode = true
local pixelPerfect = false

local computerAddress = "93a30c10-fc50-4ba4-8527-a0f924d6547a"
local tmpAddress = "15eb5b81-406e-45c5-8a43-60869fcb4f5b"
local eepromAddress = "04cbdf2d-701b-4f66-b216-c593d3bc5c62"
local diskAddress = "b7e450d0-8c8b-43a1-89d5-41216256d45a"
local screenAddress = "037ba5c4-6a28-4312-9b92-5f3685b6b320"
local gpuAddress = "1cf41ca0-ce70-4ed7-ad62-7f9eb89f34a9"
local keyboardAddress = "1dee9ef9-15b0-4b3c-a70d-f3645069530d"

local screenSelf, gpuSelf

math.randomseed(_defaultRandom)
package.path = "/storage/?.lua"

local filesys = require("filesys")

local function debugPrint(...)
	if debugMode then
		print(...)
	end
end

local function getRealTime()
	return os.time() * 1000
end

local bootUptime = hal_uptime()

local function uptime()
	return hal_uptime() - bootUptime;
end

local function computer_uptime()
	return math.floor(uptime() * 10) / 10;
end

local function checkArg(n, have, ...)
	have = type(have)
	local function check(want, ...)
		if not want then
			return false
		else
			return have == want or check(...)
		end
	end
	if not check(...) then
		local msg = string.format("bad argument #%d (%s expected, got %s)", n, table.concat({...}, " or "), have)
		error(msg, 3)
	end
end

local function stringCheckArg(n, have)
	if type(have) == "number" then
		have = tostring(have)
	end
	checkArg(1, have, "string")
	return have
end

local function numberCheckArg(n, have)
	checkArg(1, have, "number")
	if have == math.huge or have == -math.huge or have ~= have then
		return 0
	end
	return math.floor(have + 0.5)
end

local function spcall(...)
	local result = table.pack(pcall(...))
	if not result[1] then
		error(tostring(result[2]), 3)
	else
		return table.unpack(result, 2, result.n)
	end
end

local function escapePattern(str)
	return str:gsub("([^%w])", "%%%1")
end

local function simplifyFraction(numerator, denominator)
	local function gcd(a, b)
		while b ~= 0 do
			a, b = b, a % b
		end
		return a
	end

    if denominator == 0 then
		error("can't divide by zero", 2)
    end

    local divisor = gcd(math.abs(numerator), math.abs(denominator))
    return numerator / divisor, denominator / divisor
end

local sandbox, libcomputer, libunicode, libcomponent
sandbox = {
	_VERSION = _VERSION,

	assert = assert,
	error = error,
	getmetatable = function(t)
		if type(t) == "string" then -- don't allow messing with the string mt
			return nil
		end
		return getmetatable(t)
	end,
	setmetatable = function(t, mt)
		return setmetatable(t, mt)
	end,
	ipairs = ipairs,
	load = function(code, chunkname, mode, env)
		return load(code, chunkname, mode, env or sandbox)
	end,
	next = next,
	pairs = pairs,
	pcall = pcall,
	xpcall = xpcall,
	rawequal = rawequal,
	rawget = rawget,
	rawlen = rawlen,
	rawset = rawset,
	select = select,
	tonumber = tonumber,
	tostring = tostring,
	type = type,

	coroutine = {
		create = coroutine.create,
		resume = function(co, ...) -- custom resume part for bubbling sysyields
			checkArg(1, co, "thread")
			local args = table.pack(...)
			while true do -- for consecutive sysyields
				local result = table.pack(coroutine.resume(co, table.unpack(args, 1, args.n)))
				if result[1] then -- success: (true, sysval?, ...?)
					if coroutine.status(co) == "dead" then -- return: (true, ...)
						return true, table.unpack(result, 2, result.n)
					elseif result[2] ~= nil then -- yield: (true, sysval)
						args = table.pack(coroutine.yield(result[2]))
					else -- yield: (true, nil, ...)
						return true, table.unpack(result, 3, result.n)
					end
				else -- error: result = (false, string)
					return false, result[2]
				end
			end
		end,
		running = coroutine.running,
		status = coroutine.status,
		wrap = function(f) -- for bubbling coroutine.resume
			local co = coroutine.create(f)
			return function(...)
				local result = table.pack(sandbox.coroutine.resume(co, ...))
				if result[1] then
					return table.unpack(result, 2, result.n)
				else
					error(result[2], 0)
				end
			end
		end,
		yield = function(...) -- custom yield part for bubbling sysyields
			return coroutine.yield(nil, ...)
		end,
		-- Lua 5.3.
		isyieldable = coroutine.isyieldable
	},
	
	string = {
		byte = string.byte,
		char = string.char,
		dump = string.dump,
		find = string.find,
		format = string.format,
		gmatch = string.gmatch,
		gsub = string.gsub,
		len = string.len,
		lower = string.lower,
		match = string.match,
		rep = string.rep,
		reverse = string.reverse,
		sub = string.sub,
		upper = string.upper,
		-- Lua 5.3.
		pack = string.pack,
		unpack = string.unpack,
		packsize = string.packsize
	},
	
	table = {
		concat = table.concat,
		insert = table.insert,
		pack = table.pack,
		remove = table.remove,
		sort = table.sort,
		unpack = table.unpack,
		-- Lua 5.3.
		move = table.move
	},
	
	math = {
		abs = math.abs,
		acos = math.acos,
		asin = math.asin,
		atan = math.atan,
		atan2 = math.atan2 or math.atan, -- Deprecated in Lua 5.3
		ceil = math.ceil,
		cos = math.cos,
		cosh = math.cosh, -- Deprecated in Lua 5.3
		deg = math.deg,
		exp = math.exp,
		floor = math.floor,
		fmod = math.fmod,
		frexp = math.frexp, -- Deprecated in Lua 5.3
		huge = math.huge,
		ldexp = math.ldexp or function(a, e) -- Deprecated in Lua 5.3
			return a*(2.0^e)
		end,
		log = math.log,
		max = math.max,
		min = math.min,
		modf = math.modf,
		pi = math.pi,
		pow = math.pow or function(a, b) -- Deprecated in Lua 5.3
		  	return a^b
		end,
		rad = math.rad,
		random = function(...)
		  	return spcall(math.random, ...)
		end,
		randomseed = function(seed)
			-- math.floor(seed) emulates pre-OC 1.8.0 behaviour
			spcall(math.randomseed, math.floor(seed))
		end,
		sin = math.sin,
		sinh = math.sinh, -- Deprecated in Lua 5.3
		sqrt = math.sqrt,
		tan = math.tan,
		tanh = math.tanh, -- Deprecated in Lua 5.3
		-- Lua 5.3.
		maxinteger = math.maxinteger,
		mininteger = math.mininteger,
		tointeger = math.tointeger,
		type = math.type,
		ult = math.ult
	},
	
	-- Deprecated in Lua 5.3.
	bit32 = bit32 and {
		arshift = bit32.arshift,
		band = bit32.band,
		bnot = bit32.bnot,
		bor = bit32.bor,
		btest = bit32.btest,
		bxor = bit32.bxor,
		extract = bit32.extract,
		replace = bit32.replace,
		lrotate = bit32.lrotate,
		lshift = bit32.lshift,
		rrotate = bit32.rrotate,
		rshift = bit32.rshift
	},

	os = {
		clock = os.clock,
		date = function(format, time)
			checkArg(1, format, "string")
			time = numberCheckArg(2, time)
			return spcall(os.date, format, time)
		end,
		difftime = function(t2, t1)
			return t2 - t1
		end,
		time = function(table)
			checkArg(1, table, "table", "nil")
			return os.time(table)
		end
	},

	debug = {
		getinfo = function(...)
			local result = debug.getinfo(...)
			if result then
				-- Only make primitive information available in the sandbox.
				return {
					source = result.source,
					short_src = result.short_src,
					linedefined = result.linedefined,
					lastlinedefined = result.lastlinedefined,
					what = result.what,
					currentline = result.currentline,
					nups = result.nups,
					nparams = result.nparams,
					isvararg = result.isvararg,
					name = result.name,
					namewhat = result.namewhat,
					istailcall = result.istailcall
				}
			end
		end,
		traceback = debug.traceback,
		-- using () to wrap the return of debug methods because in Lua doing this
		-- causes only the first return value to be selected
		-- e.g. (1, 2) is only (1), the 2 is not returned
		-- this is critically important here because the 2nd return value from these
		-- debug methods is the value itself, which opens a door to exploit the sandbox
		getlocal = function(...) return (debug.getlocal(...)) end,
		getupvalue = function(...) return (debug.getupvalue(...)) end,
	},
	
	-- Lua 5.3.
	utf8 = utf8 and {
		char = utf8.char,
		charpattern = utf8.charpattern,
		codes = utf8.codes,
		codepoint = utf8.codepoint,
		len = utf8.len,
		offset = utf8.offset
	},

	checkArg = checkArg
}
sandbox._G = sandbox

----------------------------------------------------

local imageStartX, imageStartY, imageCharSizeX, imageCharSizeY = hal_display_sendBuffer(canvas, pixelPerfect)
local displayFlag = false

local function flushDisplay()
	if displayFlag then
		imageStartX, imageStartY, imageCharSizeX, imageCharSizeY = hal_display_sendBuffer(canvas, pixelPerfect)
		displayFlag = false
	end
end

local function updateDisplay()
	displayFlag = true
end

----------------------------------------------------

local eventList = {}

local function computer_pushSignal(eventName, ...)
	if #eventList < 256 then
		table.insert(eventList, table.pack(eventName, ...))
		return true
	end
	return false
end

----------------------------------------------------

local baseComponentList = {}
local componentList = {}
local addComponentEventEnabled = false

local function regComponent(base)
	base.slot = base.slot or -1
	baseComponentList[base.type] = base
end

local function addComponent(self, ctype, address)
	local base = baseComponentList[ctype]
	componentList[address] = {
		type = ctype,
		self = self,
		base = base,
		api = base.api,
		deviceinfo = base.deviceinfo
	}

	if addComponentEventEnabled then
		computer_pushSignal("component_added", address, ctype)
	end
end

local function delComponent(address)
	computer_pushSignal("component_removed", address, componentList[address].type)
	componentList[address] = nil
end

----------------------------------------------------

local maxTouchCount = 0
local oldTouchscreenStates = {}

local function convertPos(x, y)
	local sx, sy = (x - imageStartX) / imageCharSizeX, (y - imageStartY) / imageCharSizeY
	if not screenSelf.precise then
		sx, sy = math.ceil(sx), math.ceil(sy)
	end
	if sx < 1 then
		sx = 1
	elseif sx > gpuSelf.resX then
		sx = gpuSelf.resX
	end
	if sy < 1 then
		sy = 1
	elseif sy > gpuSelf.resY then
		sy = gpuSelf.resY
	end
	return sx, sy
end

local function pushTouchscreenEvent(eventName, x, y, button, touchindex)
	debugPrint(eventName .. " " .. touchindex .. ": " .. x .. ", " .. y .. ", " .. button)
	computer_pushSignal(eventName, screenAddress, x, y, button, "touch" .. touchindex)
end

local function updateHardware()
	local touchCount = hal_touchscreen_touchCount()
	if touchCount > maxTouchCount then
		maxTouchCount = touchCount
	end
	for i = 1, maxTouchCount do
		local tsState = oldTouchscreenStates[i]
		if i <= touchCount then
			local x, y = hal_touchscreen_getPoint(i - 1)
			x, y = convertPos(x, y)
			if tsState and not tsState.f and uptime() - tsState.t >= seconderyTouchTime then
				tsState.b = 1
				pushTouchscreenEvent("touch", tsState.x, tsState.y, tsState.b, i)
				tsState.f = true
				sound_computer_beep(700, 0.05)
			end
			if not tsState then
				oldTouchscreenStates[i] = {x = x, y = y, b = 0, t = uptime(), f = false}
			elseif tsState.x ~= x or tsState.y ~= y then
				if not tsState.f then
					pushTouchscreenEvent("touch", tsState.x, tsState.y, tsState.b, i)
					tsState.f = true
				end
				tsState.x = x
				tsState.y = y
				pushTouchscreenEvent("drag", x, y, tsState.b, i)
			end
		elseif tsState then
			if not tsState.f then
				pushTouchscreenEvent("touch", tsState.x, tsState.y, tsState.b, i)
				tsState.f = true
			end
			pushTouchscreenEvent("drop", tsState.x, tsState.y, tsState.b, i)
			oldTouchscreenStates[i] = nil
		end
	end
end

---------------------------------------------------- computer library

local defaultDeviceInfo = {
	class = "unknown",
	description = "unknown",
	product = "unknown",
	vendor = "igorkll"
}

local additionalDeviceInfo = {}

local function computer_beep(freq, delay)
	if type(freq) == "string" then
		checkArg(1, freq, "string")
		sound_computer_beepString(freq, #freq)
	else
		if freq then checkArg(1, freq, "number") end
		if delay then checkArg(2, delay, "number") end
		sound_computer_beep(freq or 440, delay or 0.1)
	end
end

local function computer_getDeviceInfo()
	local infolist = {}
	for address, info in pairs(additionalDeviceInfo) do
		infolist[address] = info
	end
	for address, comp in pairs(componentList) do
		local info = {}
		for k, v in pairs(defaultDeviceInfo) do
			info[k] = v
		end
		if comp.deviceinfo then
			for k, v in pairs(comp.deviceinfo) do
				info[k] = v
			end
		end
		infolist[address] = info
	end
	return infolist
end

local function computer_getProgramLocations()
	return {}
end

libcomputer = {
	print = print,

	uptime = computer_uptime,
	address = function()
		return computerAddress
	end,
	tmpAddress = function()
		return tmpAddress
	end,
	freeMemory = function()
		return hal_freeMemory()
	end,
	totalMemory = function()
		return hal_totalMemory()
	end,
	energy = function()
		return 10000
	end,
	maxEnergy = function()
		return 10000
	end,

	users = function()
	end,
	addUser = function(nickname)
		nickname = stringCheckArg(1, nickname)
		return nil, "player must be online"
	end,
	removeUser = function(nickname)
		nickname = stringCheckArg(1, nickname)
		return false
	end,

	shutdown = function(reboot)
		coroutine.yield(not not reboot)
	end,
	pushSignal = function(eventName, ...)
		flushDisplay()
		eventName = stringCheckArg(1, eventName)
		return computer_pushSignal(eventName, ...)
	end,
	pullSignal = function(timeout)
		flushDisplay()
		local signal = table.pack(coroutine.yield(type(timeout) == "number" and timeout or math.huge))
		if signal.n > 0 then
			return table.unpack(signal, 1, signal.n)
		end
	end,

	beep = function(freq, delay)
		flushDisplay()
		return spcall(computer_beep, freq, delay)
	end,
	getDeviceInfo = function()
		return spcall(computer_getDeviceInfo)
	end,
	getProgramLocations = function()
		return spcall(computer_getProgramLocations)
	end,

	getArchitectures = function(...)
		return {_VERSION}
	end,
	getArchitecture = function(...)
		return _VERSION
	end,
	setArchitecture = function(architecture)
		if architecture ~= _VERSION then
			return nil, "unknown architecture"
		end
	end
}
sandbox.computer = libcomputer

---------------------------------------------------- unicode library

local lower_map = {
    ["А"] = "а", ["Б"] = "б", ["В"] = "в", ["Г"] = "г", ["Д"] = "д",
    ["Е"] = "е", ["Ё"] = "ё", ["Ж"] = "ж", ["З"] = "з", ["И"] = "и",
    ["Й"] = "й", ["К"] = "к", ["Л"] = "л", ["М"] = "м", ["Н"] = "н",
    ["О"] = "о", ["П"] = "п", ["Р"] = "р", ["С"] = "с", ["Т"] = "т",
    ["У"] = "у", ["Ф"] = "ф", ["Х"] = "х", ["Ц"] = "ц", ["Ч"] = "ч",
    ["Ш"] = "ш", ["Щ"] = "щ", ["Ъ"] = "ъ", ["Ы"] = "ы", ["Ь"] = "ь",
    ["Э"] = "э", ["Ю"] = "ю", ["Я"] = "я"
}

local upper_map = {}
for k, v in pairs(lower_map) do
    upper_map[v] = k
end

libunicode = {
	char = function(value)
		return utf8.char(value)
	end,
	len = function(text)
		return utf8.len(text)
	end,
	lower = function(text)
		local result = {}
		for i = 1, libunicode.len(text) do
			local char = libunicode.sub(text, i, i)
			result[i] = lower_map[char] or char
		end
		return table.concat(result)
	end,
	reverse = function(text)
		local reversed = {}
		local len = libunicode.len(text)
		for i = len, 1, -1 do
			local char = libunicode.sub(text, i, i)
			table.insert(reversed, char)
		end
		return table.concat(reversed)
	end,
	sub = function(text, i, j)
		local start_index = utf8.offset(text, i) or 1
		local stop_index = j and utf8.offset(text, j + 1) or #text + 1
		return string.sub(text, start_index, stop_index - 1)
	end,
	upper = function(text)
		local result = {}
		for i = 1, libunicode.len(text) do
			local char = libunicode.sub(text, i, i)
			result[i] = upper_map[char] or char
		end
		return table.concat(result)
	end,
	isWide = function(char)
		return font_isWide(font_findOffset(font_toUChar(char, #char)))
	end,
	charWidth = function(char)
		return libunicode.isWide(char) and 2 or 1
	end,
	wlen = function(text)
		local wlen = 0
		for i = 1, libunicode.len(text) do
			wlen = wlen + libunicode.charWidth(libunicode.sub(text, i, i))
		end
		return wlen
	end,
	wtrunc = function(text, len)
		local strlen = libunicode.len(text)
		if len > strlen then
			error("Index " .. (len - 1) .. " out of bounds for lenght " .. strlen)
		end
		return libunicode.sub(text, 1, len - 1)
	end
}

sandbox.unicode = {}
for k, v in pairs(libunicode) do
	sandbox.unicode[k] = v
end

---------------------------------------------------- component library

-- Caching proxy objects for lower memory use.
local proxyCache = setmetatable({}, {__mode = "v"})

local componentProxy = {
    __index = function(self, key)
        if self.fields[key] and self.fields[key].getter then
            return libcomponent.invoke(self.address, key)
        else
            rawget(self, key)
        end
    end,
    __newindex = function(self, key, value)
        if self.fields[key] and self.fields[key].setter then
            return libcomponent.invoke(self.address, key, value)
        elseif self.fields[key] and self.fields[key].getter then
            error("field is read-only")
        else
            rawset(self, key, value)
        end
    end,
    __pairs = function(self)
        local keyProxy, keyField, value
        return function()
            if not keyField then
                repeat
                    keyProxy, value = next(self, keyProxy)
                until not keyProxy or keyProxy ~= "fields"
            end
            if not keyProxy then
                keyField, value = next(self.fields, keyField)
            end
            return keyProxy or keyField, value
        end
    end
}

local componentCallback = {
    __call = function(self, ...)
        return libcomponent.invoke(self.address, self.name, ...)
    end,
    __tostring = function(self)
        return libcomponent.doc(self.address, self.name) or "function"
    end
}

libcomponent = {
    doc = function(address, method)
        checkArg(1, address, "string")
        checkArg(2, method, "string")
        local comp = componentList[address]
		if not comp then
			return nil, "no such component"
		end

		if not comp.api[method] then
			return nil
		end

		return comp.api[method].doc
    end,
    invoke = function(address, method, ...)
        checkArg(1, address, "string")
        checkArg(2, method, "string")
        local comp = componentList[address]
		if not comp then
			error("no such component", 2)
		end

		if not comp.api[method] then
			error("no such method", 2)
		end

		if comp.type ~= "gpu" then
			flushDisplay()
		end

		if debugMode then
			local argstbl = {...}
			local args = {}
			for i = 1, #argstbl do
				local val = argstbl[i]
				local valt = type(val)
				if valt == "string" then
					table.insert(args, "\"" .. val .. "\"")
				else
					table.insert(args, tostring(val))
				end
			end
			debugPrint("component.invoke: " .. comp.type .. " | " .. address:sub(1, 3) .. " | " .. method .. "(" .. table.concat(args, ", ") .. ")")
		end

		return spcall(comp.api[method].callback, comp.self, ...)
    end,
    list = function(filter, exact)
        checkArg(1, filter, "string", "nil")
		flushDisplay()

        local list = {}
		for address, comp in pairs(componentList) do
			if filter then
				if exact then
					if comp.type == filter then
						list[address] = comp.type
					end
				elseif comp.type:find(escapePattern(filter)) then
					list[address] = comp.type
				end
			else
				list[address] = comp.type
			end
		end

        local key = nil
        return setmetatable(
            list,
            {
                __call = function()
                    key = next(list, key)
                    if key then
                        return key, list[key]
                    end
                end
            }
        )
    end,
    methods = function(address)
		checkArg(1, address, "string")
		flushDisplay()

        local comp = componentList[address]
		if not comp then
			return nil, "no such component"
		end

        local methods = {}
		for name, method in pairs(comp.api) do
			methods[name] = not not method.direct
		end
		return methods
    end,
    fields = function(address)
		checkArg(1, address, "string")
		flushDisplay()

		local comp = componentList[address]
		if not comp then
			return nil, "no such component"
		end
        return {}
    end,
    proxy = function(address)
		checkArg(1, address, "string")
		flushDisplay()

        local comp = componentList[address]
		if not comp then
			return nil, "no such component"
		end
        if proxyCache[address] then
            return proxyCache[address]
        end
        local proxy = {address = address, type = comp.type, slot = comp.base.slot, fields = {}}
        for name in pairs(comp.api) do
			proxy[name] = setmetatable({address = address, name = name}, componentCallback)
        end
        setmetatable(proxy, componentProxy)
        proxyCache[address] = proxy
        return proxy
    end,
    type = function(address)
		checkArg(1, address, "string")
		flushDisplay()

        local comp = componentList[address]
		if not comp then
			return nil, "no such component"
		end
		return comp.type
    end,
    slot = function(address)
		checkArg(1, address, "string")
		flushDisplay()

        local comp = componentList[address]
		if not comp then
			return nil, "no such component"
		end
		return comp.base.slot
    end
}
sandbox.component = libcomponent

---------------------------------------------------- eeprom component

regComponent({
	type = "eeprom",
	slot = -1,
	api = {
		get = {
			callback = function(self)
				return filesys.readFile("/storage/eeprom.lua") or ""
			end,
			direct = true,
			doc = "function():string -- Get the currently stored byte array."
		},
		set = {
			callback = function(self, code)
				code = code or ""
				checkArg(1, code, "string")
				if #code > maxEepromCodeLen then
					return nil, "not enough space"
				end
				filesys.writeFile("/storage/eeprom.lua", code)
			end,
			direct = false,
			doc = "function(string) -- Overwrite the currently stored byte array."
		},

		getData = {
			callback = function(self)
				return filesys.readFile("/storage/eeprom.dat") or ""
			end,
			direct = true,
			doc = "function():string -- Gets currently stored byte-array (usually the component address of the main boot device)."
		},
		setData = {
			callback = function(self, data)
				data = data or ""
				checkArg(1, data, "string")
				if #data > maxEepromDataLen then
					return nil, "not enough space"
				end
				filesys.writeFile("/storage/eeprom.dat", data)
			end,
			direct = false,
			doc = "function(string) -- Overwrites currently stored byte-array with specified string."
		},

		getLabel = {
			callback = function(self)
				return filesys.readFile("/storage/eeprom.lbl") or "EEPROM"
			end,
			direct = true,
			doc = "function():string -- Get the label of the EEPROM."
		},
		setLabel = {
			callback = function(self, label)
				label = label or "EEPROM"
				checkArg(1, label, "string")
				label = label:sub(1, 24)
				filesys.writeFile("/storage/eeprom.lbl", label)
				return label
			end,
			direct = false,
			doc = "function(string) -- Set the label of the EEPROM."
		},

		getSize = {
			callback = function(self)
				return maxEepromCodeLen
			end,
			direct = true,
			doc = "function():number -- Gets the maximum storage capacity of the EEPROM."
		},
		getDataSize = {
			callback = function(self)
				return maxEepromDataLen
			end,
			direct = true,
			doc = "function():number -- Gets the maximum data storage capacity of the EEPROM."
		},

		getChecksum = {
			callback = function(self)
				return "00000000"
			end,
			direct = true,
			doc = "function():string -- Gets Checksum of data on EEPROM."
		},
		makeReadonly = {
			callback = function(self, checksum)
				checkArg(1, checksum, "string")
				return nil, "incorrect checksum"
			end,
			direct = false,
			doc = "function(string) -- Makes the EEPROM Read-only if it isn't. This process cannot be reversed."
		}
	},
	deviceinfo = {
		capacity = "4096",
		class = "memory",
		description = "EEPROM",
		product = "EEPROM",
		size = "4096"
	}
})

addComponent({}, "eeprom", eepromAddress)

---------------------------------------------------- keyboard component

regComponent({
	type = "keyboard",
	slot = -1,
	api = {},
	deviceinfo = {
		class = "input",
		description = "Keyboard",
		product = "Keyboard"
	}
})

addComponent({}, "keyboard", keyboardAddress)

---------------------------------------------------- computer component

regComponent({
	type = "computer",
	slot = -1,
	api = {
		isRunning = {
			callback = function(self)
				return true
			end,
			direct = true,
			doc = "function():boolean -- Returns whether the computer is currently running."
		},
		start = {
			callback = function(self)
				return false
			end,
			direct = false,
			doc = "function():boolean -- Tries to start the computer. Returns true on success, false otherwise. Note that this will also return false if the computer was already running. If the computer is currently shutting down, this will cause the computer to reboot instead."
		},
		stop = {
			callback = function(self)
				coroutine.yield(false)
			end,
			direct = false,
			doc = "function():boolean -- Tries to stop the computer. Returns true on success, false otherwise. Also returns false if the computer is already stopped."
		},
		beep = {
			callback = function(self, freq, delay)
				return spcall(computer_beep, freq, delay)
			end,
			direct = false,
			doc = "function([frequency:number[, duration:number]]) -- Plays a tone, useful to alert users via audible feedback. Supports frequencies from 20 to 2000Hz, with a duration of up to 5 seconds."
		},
		getDeviceInfo = {
			callback = function(self)
				return spcall(computer_getDeviceInfo)
			end,
			direct = false,
			doc = "function():table -- Returns a table of device information. Note that this is architecture-specific and some may not implement it at all."
		},
		getProgramLocations = {
			callback = function(self)
				return spcall(computer_getProgramLocations)
			end,
			direct = false,
			doc = "function():table"
		}
	},
	deviceinfo = {
		capacity = "2147483647",
		class = "system",
		description = "Computer",
		product = "Computer"
	}
})

addComponent({}, "computer", computerAddress)

---------------------------------------------------- screen component

local aspectRatioX, aspectRatioY = simplifyFraction(DISPLAY_WIDTH, DISPLAY_HEIGHT)

regComponent({
	type = "screen",
	slot = -1,
	api = {
		isOn = {
			callback = function(self)
				return self.state
			end,
			direct = true,
			doc = "function():boolean -- Returns whether the screen is currently on."
		},
		turnOn = {
			callback = function(self)
				local state = self.state
				self.state = true
				hal_display_backlight(self.state)
				return state, self.state
			end,
			direct = true,
			doc = "function() -- Turns the screen on. Returns whether it was off and the new power state."
		},
		turnOff = {
			callback = function(self)
				local state = self.state
				self.state = false
				hal_display_backlight(self.state)
				return state, self.state
			end,
			direct = true,
			doc = "function() -- Turns off the screen. Returns whether it was on and the new power state."
		},
		getAspectRatio = {
			callback = function(self)
				return aspectRatioX, aspectRatioY
			end,
			direct = true,
			doc = "function():number, number -- The aspect ratio of the screen. For multi-block screens this is the number of blocks, horizontal and vertical."
		},
		getKeyboards = {
			callback = function(self)
				return {keyboardAddress}
			end,
			direct = false,
			doc = "function():table -- The list of keyboards attached to the screen."
		},
		setPrecise = {
			callback = function(self, precise)
				checkArg(1, precise, "boolean")
				local state = self.state
				self.precise = precise
				return state
			end,
			direct = true,
			doc = "function(boolean):boolean -- Set whether to use high-precision mode (sub-pixel mouse event position)."
		},
		isPrecise = {
			callback = function(self)
				return self.precise
			end,
			direct = true,
			doc = "function():boolean -- Check whether high-precision mode is enabled (sub-pixel mouse event position)."
		},
		setTouchModeInverted = {
			callback = function(self, touchModeInverted)
				checkArg(1, touchModeInverted, "boolean")
				local state = self.state
				self.touchModeInverted = touchModeInverted
				return state
			end,
			direct = true,
			doc = "function(boolean):boolean -- Sets Inverted Touch mode (Sneak-activate opens GUI if set to true)."
		},
		isTouchModeInverted = {
			callback = function(self)
				return self.touchModeInverted
			end,
			direct = true,
			doc = "function():boolean -- Check to see if Inverted Touch mode is enabled (Sneak-activate opens GUI is set to true)."
		}
	},
	deviceinfo = {
		capacity = "8000",
		width = "8",
		class = "display",
		description = "Text buffer",
		product = "display"
	}
})

screenSelf = {state = true, precise = false, touchModeInverted = false}
addComponent(screenSelf, "screen", screenAddress)

---------------------------------------------------- filesystem component

local baseFileCost = 512
local maxReadPart = 32 * 1024
local fileHandles = {}

local function readonlyCheck(self)
	if self.readonly then
		error("filesystem is read only", 3)
	end
end

local function formatPath(self, path)
	return filesys.sconcat(self.path, path) or self.path
end

local function spaceUsed(self)
	if self.ram then
		return self.ram.used
	end
	
	local size, files, dirs = filesys.size(self.path)
	return size + ((files + dirs) * baseFileCost)
end

local function spaceAvailable(self, need)
	local used = spaceUsed(self)
	local total = self.size
	local free = total - used
	return free >= need + baseFileCost, free
end

local function delUsed(self, obj)
	if obj.isFile then
		self.ram.used = self.ram.used - #obj.content - baseFileCost
	else
		delUsed(self, obj)
		self.ram.used = self.ram.used - baseFileCost
	end
end

local function ramFsRead(self, path, getLast)
	local segments = filesys.segments(path)
	local last
	if getLast then
		last = table.remove(segments, #segments)
	end
	local obj = self.ram.fs
	for _, part in ipairs(segments) do
		if not obj or obj.isFile then
			return
		end
		obj = obj[part]
	end
	return obj, last
end

local function seekFunction(self, mode, val)
	checkArg(1, mode, "string")
	checkArg(2, val, "number")
	if mode == "set" then
		self.cursor = val
	elseif mode == "cur" then
		self.cursor = self.cursor + val
	else
		error("invalid mode", 2)
	end
	self.cursor = math.floor(self.cursor)
	if self.cursor < 0 then self.cursor = 0 end
	return self.cursor
end

local ramFsMethods = {
	seek = seekFunction,
	read = function(self, bytes)
		local str = self.strtool.sub(self.file.content, self.cursor + 1, self.cursor + bytes)
		self.cursor = self.cursor + bytes
		return str
	end,
	write = function(self, str)
		self.self.ram.used = self.self.ram.used + #str
		self.cursor = self.cursor + self.strtool.len(str)
		self.file.content = self.file.content .. str
		return true
	end,
	close = function(self)
	end
}

local function createRamFile(self, file, unicode)
	return setmetatable({cursor = 0, file = file, strtool = unicode and libunicode or string, self = self}, {__index = ramFsMethods})
end

local cacheFsMethods = {
	seek = seekFunction,
	read = function(self, bytes)
		local str = self.strtool.sub(self.content, self.cursor + 1, self.cursor + bytes)
		self.cursor = self.cursor + bytes
		return str
	end,
	write = function(self, str)
		self.cursor = self.cursor + self.strtool.len(str)
		self.content = self.content .. str
		return true
	end,
	close = function(self)
		if self.writeMode then
			self.file:write(self.content)
			self.file:close()
		end
	end
}

local function createCacheFile(self, path, unicode, writeMode, appendMode)
	local obj = setmetatable({cursor = 0, path = path, strtool = unicode and libunicode or string, self = self, writeMode = writeMode, appendMode = appendMode}, {__index = cacheFsMethods})
	local err
	if writeMode then
		obj.file, err = filesys.open(path, appendMode and (unicode and "a" or "ab") or (unicode and "w" or "wb"))
		if not obj.file then
			return nil, err
		end

		obj.content = ""
	else
		obj.content, err = filesys.readFile(path)
		if not obj.content then
			return nil, err
		end
	end
	return obj
end

regComponent({
	type = "filesystem",
	slot = -1,
	api = {
		isReadOnly = {
			callback = function(self)
				return not not self.readonly
			end,
			direct = true,
			doc = "function():boolean -- Returns whether the file system is read-only."
		},
		spaceTotal = {
			callback = function(self)
				return self.size
			end,
			direct = true,
			doc = "function():number -- The overall capacity of the file system, in bytes."
		},
		spaceUsed = {
			callback = function(self)
				if self.ram then
					return self.ram.used or 0
				else
					return spaceUsed(self)
				end
			end,
			direct = true,
			doc = "function():number -- The currently used capacity of the file system, in bytes."
		},

		setLabel = {
			callback = function(self, label)
				checkArg(1, label, "string")
				if self.labelReadonly then
					error("label is read only", 2)
				end
				label = label:sub(1, 24)
				if self.ram then
					self.ram.label = label
				else
					filesys.writeFile(self.path .. ".lbl", label)
				end
				return label
			end,
			direct = false,
			doc = "function(string):string -- Sets the label of the file system. Returns the new value, which may be truncated."
		},
		getLabel = {
			callback = function(self)
				if self.ram then
					return self.ram.label or self.label
				else
					return filesys.readFile(self.path .. ".lbl") or self.label
				end
			end,
			direct = true,
			doc = "function():string -- Get the current label of the file system."
		},

		size = {
			callback = function(self, path)
				checkArg(1, path, "string")
				if self.ram then
					local file = ramFsRead(self, path)
					if file and file.isFile then
						return #file.content
					end
					return 0
				else
					path = formatPath(self, path)
					if filesys.isFile(path) then
						return (filesys.size(path))
					end
				end
			end,
			direct = false,
			doc = "function():number -- Returns the size of the object at the specified absolute path in the file system."
		},
		remove = {
			callback = function(self, path)
				checkArg(1, path, "string")
				if self.readonly then
					return false
				end
				if self.ram then
					if #filesys.segments(path) == 0 then
						self.ram.used = 0
						self.ram.fs = {}
						return true
					else
						local dir, objectName = ramFsRead(self, path, true)
						if not dir or dir.isFile then
							return false
						end
						local delObj = dir[objectName]
						if delObj then
							delUsed(self, delObj)
							dir[objectName] = nil
							return true
						end
						return false
					end
				else
					path = formatPath(self, path)
					local oldState = filesys.exists(path)
					filesys.remove(path)
					local newState = filesys.exists(path)
					filesys.makeDirectory(self.path)
					return oldState and not newState
				end
			end,
			direct = false,
			doc = "function(string) -- Removes the object at the specified absolute path in the file system."
		},
		rename = {
			callback = function(self, path, path2)
				checkArg(1, path, "string")
				checkArg(2, path2, "string")
				if self.readonly then
					return false
				end
				if self.ram then
					local dir, objectName = ramFsRead(self, path, true)
					if not dir or dir.isFile then
						return false
					end

					local object = dir[objectName]
					if not object then
						return false
					end

					local dir2, targetObjectName = ramFsRead(self, path2, true)
					if not dir2 or dir2.isFile then
						return false
					end

					dir[objectName] = nil
					dir2[targetObjectName] = object
					return true
				else
					return filesys.rename(formatPath(self, path), formatPath(self, path2))
				end
			end,
			direct = false,
			doc = "function(string, string) -- Renames/moves an object from the first specified absolute path in the file system to the second."
		},
		lastModified = {
			callback = function(self, path)
				checkArg(1, path, "string")
				if self.ram then
					local file = ramFsRead(self, path)
					if file and file.isFile then
						return file.lastModified or 0
					end
					return 0
				else
					return filesys.lastModified(formatPath(self, path))
				end
			end,
			direct = false,
			doc = "function():number -- Returns the (real world) timestamp of when the object at the specified absolute path in the file system was modified."
		},
		makeDirectory = {
			callback = function(self, path)
				checkArg(1, path, "string")
				if self.readonly then
					return false
				end
				if self.ram then
					local dir, name = ramFsRead(self, path, true)
					if dir and not dir.isFile then
						if not dir[name] then
							self.ram.used = self.ram.used + baseFileCost
							dir[name] = {}
							return true
						end
					end
					return false
				else
					return filesys.makeDirectory(formatPath(self, path))
				end
			end,
			direct = false,
			doc = "function(string):boolean -- Creates a directory at the specified absolute path in the file system. Creates parent directories, if necessary."
		},
		exists = {
			callback = function(self, path)
				checkArg(1, path, "string")
				if self.ram then
					return not not ramFsRead(self, path)
				else
					return filesys.exists(formatPath(self, path))
				end
			end,
			direct = false,
			doc = "function(string):boolean -- Returns whether an object exists at the specified absolute path in the file system."
		},
		isDirectory = {
			callback = function(self, path)
				checkArg(1, path, "string")
				if self.ram then
					local files = ramFsRead(self, path)
					return files and not files.isFile
				else
					return filesys.isDirectory(formatPath(self, path))
				end
			end,
			direct = false,
			doc = "function(string):boolean -- Returns whether an object exists at the specified absolute path in the file system."
		},
		list = {
			callback = function(self, path)
				checkArg(1, path, "string")
				if self.ram then
					local files = ramFsRead(self, path)
					if not files.isFile then
						local list = {}
						for name, obj in pairs(files) do
							if not obj.isFile then
								table.insert(list, name .. "/")
							else
								table.insert(list, name)
							end
						end
						return list
					end
				else
					return filesys.list(formatPath(self, path))
				end
			end,
			direct = false,
			doc = "function(string):boolean -- Returns a list of names of objects in the directory at the specified absolute path in the file system."
		},
		open = {
			callback = function(self, path, mode)
				checkArg(1, path, "string")
				if mode ~= nil then
					checkArg(2, mode, "string")
				end
				mode = (mode or "r"):lower()
				local binMode = mode:sub(2, 2) == "b"
				local appendMode = mode:sub(1, 1) == "a"
				local writeMode = appendMode or mode:sub(1, 1) == "w"

				local handleBackend = {writeMode = writeMode}

				if writeMode then
					if self.readonly then
						return nil, path
					else
						local enough, free = spaceAvailable(self, 0)
						handleBackend.allowWrite = free
						if not enough then
							return nil, "not enough space"
						end
					end
				end

				if self.ram then
					local dir, filename = ramFsRead(self, path, true)
					if not dir or dir.isFile or (dir[filename] and not dir[filename].isFile) then
						return nil, path
					end

					if writeMode then
						if not appendMode or not dir[filename] then
							if dir[filename] then
								self.ram.used = self.ram.used - #dir[filename].content - baseFileCost
							end
							dir[filename] = {isFile = true, content = ""}
							self.ram.used = self.ram.used + baseFileCost
						end
						dir[filename].lastModified = math.floor(getRealTime() + 0.5)
						handleBackend.file = createRamFile(self, dir[filename], not binMode)
					elseif dir[filename] then
						handleBackend.file = createRamFile(self, dir[filename], not binMode)
					else
						return nil, path
					end
				else
					local file, err = filesys.open(formatPath(self, path), mode)
					if not file then
						return nil, tostring(err)
					end

					handleBackend.file = file

					--[[
					handleBackend.file = createCacheFile(self, formatPath(self, path), not binMode, writeMode, appendMode)
					]]
				end

				local handle = {}
				fileHandles[handle] = handleBackend
				return handle
			end,
			direct = false,
			doc = "function(string, string):handle -- Opens a new file descriptor and returns its handle."
		},
		close = {
			callback = function(self, handle)
				if fileHandles[handle] then
					fileHandles[handle].file:close()
					fileHandles[handle] = nil
					return true
				end
				return false
			end,
			direct = false,
			doc = "function(handle) -- Closes an open file descriptor with the specified handle."
		},
		read = {
			callback = function(self, handle, count)
				checkArg(2, count, "number")
				if fileHandles[handle] then
					local handleBackend = fileHandles[handle]
					if handleBackend.writeMode then
						return nil, "bad file descriptor"
					end
					if count > maxReadPart then
						count = maxReadPart
					end
					local str = handleBackend.file:read(count)
					if str and #str > 0 then
						return str
					end
				end
				return nil
			end,
			direct = false,
			doc = "function(handle):string -- Reads up to the specified amount of data from an open file descriptor with the specified handle. Returns nil when EOF is reached."
		},
		write = {
			callback = function(self, handle, content)
				checkArg(2, content, "string")
				if fileHandles[handle] then
					local handleBackend = fileHandles[handle]
					if not handleBackend.writeMode then
						return nil, "bad file descriptor"
					end
					handleBackend.allowWrite = handleBackend.allowWrite - #content
					if handleBackend.allowWrite < 0 then
						return nil, "not enough space"
					end
					handleBackend.file:write(content)
					return true
				end
				return false
			end,
			direct = false,
			doc = "function(handle, string):boolean -- Writes the specified data to an open file descriptor with the specified handle."
		},
		seek = {
			callback = function(self, handle, whence, offset)
				checkArg(2, whence, "string")
				checkArg(3, offset, "number")
				if fileHandles[handle] then
					return fileHandles[handle].file:seek(whence, offset)
				end
			end,
			direct = false,
			doc = "function(handle, string):boolean -- Writes the specified data to an open file descriptor with the specified handle."
		}
	},
	deviceinfo = {
		capacity = "4294967",
		size = "4194304",
		clock = "200/200/80",
		class = "volume",
		description = "Filesystem",
		product = "Filesystem"
	}
})

filesys.makeDirectory("/storage/tmpfs")
addComponent({path = "/storage/system", readonly = false, labelReadonly = false, label = "system", size = 1 * 1024 * 1024}, "filesystem", diskAddress)
addComponent({ram = {used = 0, fs = {}}, readonly = false, labelReadonly = true, label = "tmpfs", size = 64 * 1024}, "filesystem", tmpAddress)

---------------------------------------------------- gpu component

regComponent({
	type = "gpu",
	slot = -1,
	api = {
		bind = {
			callback = function(self, address, reset)
				if not componentList[address] then
					return nil, "invalid address"
				end
				if componentList[address].type ~= "screen" then
					return nil, "not a screen"
				end

				if reset == nil then
					reset = true
				end
				checkArg(1, reset, "boolean")

				if reset then
					self.resX, self.resY = self.maxX, self.maxY
					self.viewX, self.viewY = self.maxX, self.maxY
					self.depth = 8
					canvas_setResolution(canvas, self.resX, self.resY)
					canvas_setDepth(canvas, self.depth)
					canvas_setBackground(canvas, 0x000000, false)
					canvas_setForeground(canvas, 0xffffff, false)
				end

				self.address = address
				return true
			end,
			direct = false,
			doc = "function(address: string[, reset: boolean=true]):boolean[, string] -- Tries to bind the GPU to a screen with the specified address. Returns true on success, false and an error message on failure. Resets the screen's settings if reset is 'true'. A GPU can only be bound to one screen at a time. All operations on it will work on the bound screen. If you wish to control multiple screens at once, you'll need to put more than one graphics card into your computer."
		},
		getScreen = {
			callback = function(self)
				return self.address
			end,
			direct = true,
			doc = "function():string -- Get the address of the screen the GPU is bound to."
		},
		maxDepth = {
			callback = function(self)
				return 8
			end,
			direct = true,
			doc = "function():number -- Gets the maximum supported color depth supported by the GPU and the screen it is bound to (minimum of the two)."
		},
		getDepth = {
			callback = function(self)
				return self.depth
			end,
			direct = true,
			doc = "function():number -- The currently set color depth of the GPU/screen, in bits. Can be 1, 4 or 8."
		},
		setDepth = {
			callback = function(self, depth)
				checkArg(1, depth, "number")
				if depth == 1 then
					updateDisplay()
					self.depth = depth
					canvas_setDepth(canvas, self.depth)
					return "OneBit"
				elseif depth == 4 then
					updateDisplay()
					self.depth = depth
					canvas_setDepth(canvas, self.depth)
					return "FourBit"
				elseif depth == 8 then
					updateDisplay()
					self.depth = depth
					canvas_setDepth(canvas, self.depth)
					return "EightBit"
				else
					error("unsupported depth", 2)
				end
			end,
			direct = false,
			doc = "function():string -- Sets the color depth to use. Can be up to the maximum supported color depth. If a larger or invalid value is provided it will throw an error. Returns the old depth as one of the strings OneBit, FourBit, or EightBit."
		},
		maxResolution = {
			callback = function(self)
				return self.maxX, self.maxY
			end,
			direct = true,
			doc = "function():number, number -- Gets the maximum resolution supported by the GPU and the screen it is bound to (minimum of the two)."
		},
		getResolution = {
			callback = function(self)
				return self.resX, self.resY
			end,
			direct = true,
			doc = "function():number, number -- Gets the currently set resolution."
		},
		getViewport = {
			callback = function(self)
				return self.viewX, self.viewY
			end,
			direct = true,
			doc = "function():number, number -- Get the current viewport resolution."
		},
		get = {
			callback = function(self, x, y)
				x = numberCheckArg(1, x)
				y = numberCheckArg(2, y)
				local char, fg, bg, fgi, bgi, fga, bga = canvas_get(canvas, x, y)
				if not fga then fgi = nil end
				if not bga then bgi = nil end
				return libunicode.char(char), fg, bg, fgi, bgi
			end,
			direct = false,
			doc = "function(number, number): string, number, number, number or nil, number or nil -- Gets the character currently being displayed at the specified coordinates. The second and third returned values are the fore- and background color, as hexvalues. If the colors are from the palette, the fourth and fifth values specify the palette index of the color, otherwise they are nil."
		},
		set = {
			callback = function(self, x, y, text, vertical)
				x = numberCheckArg(1, x)
				y = numberCheckArg(2, y)
				checkArg(3, text, "string")
				if vertical ~= nil then
					checkArg(4, vertical, "boolean")
				end
				canvas_set(canvas, x, y, text, #text)
				updateDisplay()
				return true
			end,
			direct = false,
			doc = "function(x: number, y: number, value: string[, vertical:boolean]):boolean -- Writes a string to the screen, starting at the specified coordinates. The string will be copied to the screen's buffer directly, in a single row. This means even if the specified string contains line breaks, these will just be printed as special characters, the string will not be displayed over multiple lines. Returns true if the string was set to the buffer, false otherwise."
		},
		fill = {
			callback = function(self, x, y, sizeX, sizeY, char)
				x = numberCheckArg(1, x)
				y = numberCheckArg(2, y)
				sizeX = numberCheckArg(3, sizeX)
				sizeY = numberCheckArg(4, sizeY)
				checkArg(5, char, "string")
				if libunicode.len(char) ~= 1 then
					return nil, "invalid fill value"
				end
				canvas_fill(canvas, x, y, sizeX, sizeY, font_toUChar(char, #char))
				updateDisplay()
				return true
			end,
			direct = false,
			doc = "function(x: number, y: number, width: number, height: number, char: string): boolean -- Fills a rectangle in the screen buffer with the specified character. The target rectangle is specified by the x and y coordinates and the rectangle's width and height. The fill character char must be a string of length one, i.e. a single character. Returns true on success, false otherwise."
		},
		copy = {
			callback = function(self, x, y, sizeX, sizeY, offsetX, offsetY)
				x = numberCheckArg(1, x)
				y = numberCheckArg(2, y)
				sizeX = numberCheckArg(3, sizeX)
				sizeY = numberCheckArg(4, sizeY)
				offsetX = numberCheckArg(5, offsetX)
				offsetY = numberCheckArg(6, offsetY)
				canvas_copy(canvas, x, y, sizeX, sizeY, offsetX, offsetY)
				updateDisplay()
				return true
			end,
			direct = false,
			doc = "function(x: number, y: number, width: number, height: number, tx: number, ty: number): boolean -- Copies a portion of the screens buffer to another location. The source rectangle is specified by the x, y, width and height parameters. The target rectangle is defined by x + tx, y + ty, width and height. Returns true on success, false otherwise."
		},
		setBackground = {
			callback = function(self, color, isPal)
				checkArg(1, color, "number")
				if isPal ~= nil then
					checkArg(2, isPal, "boolean")
				end
				if isPal then
					if self.depth == 1 then
						error("color palette not supported", 2)
					end
					if color < 0 or color > 15 then
						error("invalid palette index", 2)
					end
				end
				local oldBg = self.bg or 0x000000
				local oldBgPal = self.bg_pal
				self.bg = color
				self.bg_pal = not not isPal
				canvas_setBackground(canvas, color, self.bg_pal)
				if oldBgPal then
					return canvas_getPaletteColor(canvas, oldBg), oldBg
				else
					return oldBg, nil			
				end
			end,
			direct = false,
			doc = "function(color: number[, isPaletteIndex: boolean]): number[, index] -- Sets the background color to apply to “pixels” modified by other operations from now on. The returned value is the old background color, as the actual value it was set to (i.e. not compressed to the color space currently set). The first value is the previous color as an RGB value. If the color was from the palette, the second value will be the index in the palette. Otherwise it will be nil. Note that the color is expected to be specified in hexadecimal RGB format, i.e. 0xRRGGBB. This is to allow uniform color operations regardless of the color depth supported by the screen and GPU."
		},
		setForeground = {
			callback = function(self, color, isPal)
				checkArg(1, color, "number")
				if isPal ~= nil then
					checkArg(2, isPal, "boolean")
				end
				if isPal then
					if self.depth == 1 then
						error("color palette not supported", 2)
					end
					if color < 0 or color > 15 then
						error("invalid palette index", 2)
					end
				end
				local oldFg = self.fg or 0xffffff
				local oldFgPal = self.fg_pal
				self.fg = color
				self.fg_pal = not not isPal
				canvas_setForeground(canvas, color, self.fg_pal)
				if oldFgPal then
					return canvas_getPaletteColor(canvas, oldFg), oldFg
				else
					return oldFg, nil			
				end
			end,
			direct = false,
			doc = "function(color: number[, isPaletteIndex: boolean]): number[, index] -- Like setBackground, but for the foreground color."
		},
		setResolution = {
			callback = function(self, sizeX, sizeY)
				sizeX = numberCheckArg(1, sizeX)
				sizeY = numberCheckArg(2, sizeY)
				if sizeX * sizeY > (self.maxX * self.maxY) or sizeX > self.maxX or sizeY > self.maxY then
					error("unsupported resolution", 2)
				end
				canvas_setResolution(canvas, sizeX, sizeY)
				local oldX, oldY = self.resX, self.resY
				self.resX = sizeX
				self.resY = sizeY
				updateDisplay()
				flushDisplay()
				return sizeX ~= oldX or sizeY ~= oldY
			end,
			direct = false,
			doc = "function(width: number, height: number): boolean -- Sets the specified resolution. Can be up to the maximum supported resolution. If a larger or invalid resolution is provided it will throw an error. Returns true if the resolution was changed (may return false if an attempt was made to set it to the same value it was set before), false otherwise."
		},
		setViewport = {
			callback = function(self, sizeX, sizeY)
				sizeX = numberCheckArg(1, sizeX)
				sizeY = numberCheckArg(2, sizeY)
				if sizeX * sizeY > (self.maxX * self.maxY) or sizeX > self.maxX or sizeY > self.maxY then
					error("unsupported viewport size", 2)
				end
				local oldX, oldY = self.viewX, self.viewY
				self.viewX = sizeX
				self.viewY = sizeY
				updateDisplay()
				flushDisplay()
				return sizeX ~= oldX or sizeY ~= oldY
			end,
			direct = false,
			doc = "function(width: number, height: number): boolean -- Set the current viewport resolution. Returns true if it was changed (may return false if an attempt was made to set it to the same value it was set before), false otherwise. This makes it look like screen resolution is lower, but the actual resolution stays the same. Characters outside top-left corner of specified size are just hidden, and are intended for rendering or storing things off-screen and copying them to the visible area when needed. Changing resolution will change viewport to whole screen."
		},
		getBackground = {
			callback = function(self)
				if self.bg_pal then
					return self.bg, true
				end
				return canvas_getBackground(canvas), false
			end,
			direct = true,
			doc = "function(): number, boolean -- Gets the current background color. This background color is applied to all “pixels” that get changed by other operations."
		},
		getForeground = {
			callback = function(self)
				if self.fg_pal then
					return self.fg, true
				end
				return canvas_getForeground(canvas), false
			end,
			direct = true,
			doc = "function(): number, boolean -- Like getBackground, but for the foreground color."
		},
		getPaletteColor = {
			callback = function(self, index)
				if self.depth == 1 then
					error("color palette not supported", 2)
				end
				if index < 0 or index > 15 then
					error("invalid palette index", 2)
				end
				return canvas_getPaletteColor(canvas, index)
			end,
			direct = false,
			doc = "function(index: number): number -- Gets the RGB value of the color in the palette at the specified index."
		},
		setPaletteColor = {
			callback = function(self, index, color)
				if self.depth == 1 then
					error("color palette not supported", 2)
				end
				if index < 0 or index > 15 then
					error("invalid palette index", 2)
				end
				local oldColor = canvas_getPaletteColor(canvas, index)
				if color == oldColor then
					return oldColor
				end
				canvas_setPaletteColor(canvas, index, color)
				updateDisplay()
				return oldColor
			end,
			direct = false,
			doc = "function(index: number): number -- Sets the RGB value of the color in the palette at the specified index."
		}
	},
	deviceinfo = {
		capacity = "8000",
		class = "display",
		clock = "2560/2560/320/5120/1280/2560",
		description = "Filesystem",
		product = "Filesystem",
		width = "8"
	}
})

gpuSelf = {
	maxX = resolutionX, maxY = resolutionY,
	
	viewX = 50, viewY = 16,
	resX = 50, resY = 16,
	depth = 1
}

addComponent(gpuSelf, "gpu", gpuAddress)

----------------------------------------------------

local function pullEvent(wait)
	local deadline = computer_uptime() + wait
	repeat
		updateHardware()
		if #eventList > 0 then
			return table.remove(eventList, 1)
		end
	until computer_uptime() >= deadline
	return {}
end

local function bootstrap()
	local eeprom = libcomponent.list("eeprom")()
	if eeprom then
		local code = libcomponent.invoke(eeprom, "get")
		if code and #code > 0 then
			local bios, reason = load(code, "=bios", nil, sandbox)
			if bios then
				addComponentEventEnabled = true
				return coroutine.create(bios), {n=0}
			end
			error("failed loading bios: " .. reason, 0)
		end
	end
	error("no bios found; install a configured EEPROM", 0)
end

local thread, args = bootstrap()
while true do
	local result = table.pack(coroutine.resume(thread, table.unpack(args, 1, args.n)))
	args = nil
	if not result[1] then
		error(tostring(result[2]), 0)
	elseif coroutine.status(thread) == "dead" then
		error("computer halted", 0)
	else
		local returnType = type(result[2])
		if returnType == "boolean" then
			if result[2] then
				return true
			else
				return false
			end
		end
	end
	args = pullEvent(result[2])
end