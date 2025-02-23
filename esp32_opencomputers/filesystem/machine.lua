local computerAddress = "93a30c10-fc50-4ba4-8527-a0f924d6547a"
local tmpAddress = "15eb5b81-406e-45c5-8a43-60869fcb4f5b"
local eepromAddress = "04cbdf2d-701b-4f66-b216-c593d3bc5c62"
local diskAddress = "b7e450d0-8c8b-43a1-89d5-41216256d45a"

local maxEepromCodeLen = 4096
local maxEepromDataLen = 256

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

local function spcall(...)
	local result = table.pack(pcall(...))
	if not result[1] then
		error(tostring(result[2]), 0)
	else
		return table.unpack(result, 2, result.n)
	end
end

local function epcall(...)
	local result = {pcall(...)}
	if result[1] then
		return table.unpack(result, 2)
	else
		error(result[2], 2)
	end
end

local function escapePattern(str)
	return str:gsub("([^%w])", "%%%1")
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

local eventList = {}

local function computer_pushSignal(eventName, ...)
	if #eventList < 256 then
		table.insert(eventList, table.pack(eventName, ...))
		return true
	end
	return false
end

----------------------------------------------------

local bootUptime = hal_uptime()

local function computer_uptime()
	return math.floor((hal_uptime() - bootUptime) * 10) / 10;
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
		api = base.api
	}

	if addComponentEventEnabled then
		computer_pushSignal("component_added", address, ctype)
	end
end

local function delComponent(address)
	computer_pushSignal("component_removed", address, componentList[address].type)
	componentList[address] = nil
end

---------------------------------------------------- computer library

libcomputer = {
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
		eventName = stringCheckArg(1, eventName)
		return computer_pushSignal(eventName, ...)
	end,
	pullSignal = function(timeout)
		local deadline = computer_uptime() + (type(timeout) == "number" and timeout or math.huge)
		repeat
			local signal = coroutine.yield(deadline - computer_uptime())
			if signal then
				return table.unpack(signal, 1, signal.n)
			end
		until computer_uptime() >= deadline
	end,

	beep = function(freq, delay)
		if type(freq) == "string" then
			checkArg(1, freq, "string")
			sound_computer_beepString(freq, #freq)
		else
			checkArg(1, freq, "number")
			checkArg(2, delay, "number")
			sound_computer_beep(freq, delay)
		end
	end,
	getDeviceInfo = function()
		return {}
	end,
	getProgramLocations = function()
		return {}
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

libunicode = {
	char = function(...)
		return spcall(unicode.char, ...)
	end,
	len = function(s)
		return spcall(unicode.len, s)
	end,
	lower = function(s)
		return spcall(unicode.lower, s)
	end,
	reverse = function(s)
		return spcall(unicode.reverse, s)
	end,
	sub = function(s, i, j)
		if j then
			return spcall(unicode.sub, s, i, j)
		end
		return spcall(unicode.sub, s, i)
	end,
	upper = function(s)
		return spcall(unicode.upper, s)
	end,
	isWide = function(s)
		return spcall(unicode.isWide, s)
	end,
	charWidth = function(s)
		return spcall(unicode.charWidth, s)
	end,
	wlen = function(s)
		return spcall(unicode.wlen, s)
	end,
	wtrunc = function(s, n)
		return spcall(unicode.wtrunc, s, n)
	end
}
sandbox.unicode = libunicode

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

		return epcall(comp.api[method].callback, comp.self, ...)
    end,
    list = function(filter, exact)
        checkArg(1, filter, "string", "nil")
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
		local comp = componentList[address]
		if not comp then
			return nil, "no such component"
		end
        return {}
    end,
    proxy = function(address)
		checkArg(1, address, "string")
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
        local comp = componentList[address]
		if not comp then
			return nil, "no such component"
		end
		return comp.type
    end,
    slot = function(address)
		checkArg(1, address, "string")
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
				local file = io.open("/storage/eeprom.lua", "rb")
				if file then
					local data = file:read("*a")
					file:close()
					return data
				end
				return ""
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
				local file = io.open("/storage/eeprom.lua", "wb")
				if file then
					file:write(code)
					file:close()
				end
			end,
			direct = false,
			doc = "function():string -- Overwrite the currently stored byte array."
		},

		getData = {
			callback = function(self)
				local file = io.open("/storage/eeprom.dat", "rb")
				if file then
					local data = file:read("*a")
					file:close()
					return data
				end
				return ""
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
				local file = io.open("/storage/eeprom.dat", "wb")
				if file then
					file:write(data)
					file:close()
				end
			end,
			direct = false,
			doc = "function():string -- Overwrites currently stored byte-array with specified string."
		},

		getLabel = {
			callback = function(self)
				local file = io.open("/storage/eeprom.lbl", "rb")
				if file then
					local data = file:read("*a")
					file:close()
					return data
				end
				return "EEPROM"
			end,
			direct = true,
			doc = "function():string -- Get the label of the EEPROM."
		},
		setLabel = {
			callback = function(self, label)
				label = label or "EEPROM"
				checkArg(1, label, "string")
				label = label:sub(1, 24)
				local file = io.open("/storage/eeprom.lbl", "wb")
				if file then
					file:write(label)
					file:close()
				end
				return label
			end,
			direct = false,
			doc = "function():string -- Set the label of the EEPROM."
		},

		getSize = {
			callback = function(self)
				return maxEepromCodeLen
			end,
			direct = true,
			doc = "function():string -- Gets the maximum storage capacity of the EEPROM."
		},
		getDataSize = {
			callback = function(self)
				return maxEepromDataLen
			end,
			direct = true,
			doc = "function():string -- Gets the maximum data storage capacity of the EEPROM."
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
			doc = "function():string -- Makes the EEPROM Read-only if it isn't. This process cannot be reversed."
		}
	}
})

addComponent({}, "eeprom", eepromAddress)

----------------------------------------------------

local function pullEvent(vm)
	if #eventList > 0 then
		return table.remove(eventList, 1)
	end
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
		else
			args = table.pack(pullEvent())
		end
	end
end