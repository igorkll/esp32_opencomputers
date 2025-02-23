local parser = require("parser")
local unicode = require("unicode")
local function lineMod(str)
return parser.fastChange(str, {["\r"] = "", ["\t"] = "  "})
end

--[[
local fs = require("filesystem")
local unicode = require("unicode")
local calls = require("calls")
local graphic = require("graphic")
local calls = require("calls")
local computer = require("computer")
local gui_container = require("gui_container")
local component = require("component")

local screen, path = ...

local colors = gui_container.colors
local rx, ry
do
	local gpu = graphic.findGpu(screen)
	rx, ry = gpu.getResolution()
end

------------------------------------

local lines = {}

local function saveFile()
	local file = assert(fs.open(path, "w"))
	for i, v in ipairs(lines) do
		file.write(v .. "\n")
	end
	file.close()
end

local function loadFile()
	local file = assert(fs.open(path, "r"))
	local data = file.readAll()
	file.close()
	lines = calls.call("split", data, "\n")
end
loadFile()

------------------------------------

local offsetX = 0
local offsetY = 0
local cursorX = 1
local cursorY = 1

local function redraw()
	local gpu = graphic.findGpu(screen)
	gpu.setForeground(colors.black)
	gpu.setBackground(colors.white)
	gpu.fill(1, 1, rx, ry, " ")
	for cy = 1, ry do
		local line = lines[cy + offsetY]
		if line then
			gpu.set(offsetX + 1, cy, line)
		end
	end
	local char, fore, back = gpu.get(cursorX, cursorY)
	gpu.setForeground(back)
	gpu.setBackground(fore)
	gpu.set(cursorX, cursorY, char)
end
redraw()

------------------------------------

local function mathLinePos()
	return cursorX - offsetX, cursorY - offsetY
end

local function getLine()
	local px, py = mathLinePos()
	return lines[py], px
end

local function checkPos()
	local line = getLine()

	if cursorX > rx then
		offsetX = offsetX - 1
		cursorX = rx
	elseif cursorX < 1 then
		offsetX = offsetX + 1
		cursorX = 1
	end

	if cursorY > ry then
		offsetY = offsetY + 1
		cursorY = ry
	elseif cursorY < 1 then
		offsetY = offsetY - 1
		cursorY = 1
	end

	if offsetX > 0 then
		offsetX = 0
		cursorY = cursorY - 1
		if line then
			--cursorX = unicode.len(line)
		end
		checkPos()
	end
	if offsetY < 0 then
		offsetY = 0
	end

	if not line then return end
	local px, py = mathLinePos()
	if px > unicode.len(line) then
		cursorX = 1
		cursorY = cursorY + 1
		checkPos()
		redraw()
	end
end

------------------------------------

while true do
	local eventData = {computer.pullSignal()}
	if eventData[1] == "key_down" then
		local ok
		for i, v in ipairs(component.invoke(screen, "getKeyboards")) do
			if v == eventData[2] then
				ok = true
				break
			end
		end
		if ok then
			if eventData[4] == 208 then
				cursorY = cursorY + 1
				checkPos()
				redraw()
			elseif eventData[4] == 200 then
				cursorY = cursorY - 1
				checkPos()
				redraw()
			elseif eventData[4] == 203 then
				cursorX = cursorX - 1
				checkPos()
				redraw()
			elseif eventData[4] == 205 then
				cursorX = cursorX + 1
				checkPos()
				redraw()
			elseif eventData[3] == 23 and eventData[4] == 17 then --exit
				break
			elseif eventData[3] == 19 and eventData[4] == 31 then --save
				saveFile()
			end
		end
	end
end
]]












local keyboard = {pressedChars = {}, pressedCodes = {}}

-- these key definitions are only a subset of all the defined keys
-- __index loads all key data from /lib/tools/keyboard_full.lua (only once)
-- new key metadata should be added here if required for boot
keyboard.keys = {
c               = 0x2E,
d               = 0x20,
q               = 0x10,
w               = 0x11,
back            = 0x0E, -- backspace
delete          = 0xD3,
down            = 0xD0,
enter           = 0x1C,
home            = 0xC7,
lcontrol        = 0x1D,
left            = 0xCB,
lmenu           = 0x38, -- left Alt
lshift          = 0x2A,
pageDown        = 0xD1,
rcontrol        = 0x9D,
right           = 0xCD,
rmenu           = 0xB8, -- right Alt
rshift          = 0x36,
space           = 0x39,
tab             = 0x0F,
up              = 0xC8,
["end"]         = 0xCF,
enter           = 0x1C,
tab             = 0x0F,
numpadenter     = 0x9C,
}

-------------------------------------------------------------------------------

function keyboard.isAltDown()
return keyboard.pressedCodes[keyboard.keys.lmenu] or keyboard.pressedCodes[keyboard.keys.rmenu]
end

function keyboard.isControl(char)
return type(char) == "number" and (char < 0x20 or (char >= 0x7F and char <= 0x9F))
end

function keyboard.isControlDown()
return keyboard.pressedCodes[keyboard.keys.lcontrol] or keyboard.pressedCodes[keyboard.keys.rcontrol]
end

function keyboard.isKeyDown(charOrCode)
checkArg(1, charOrCode, "string", "number")
if type(charOrCode) == "string" then
	return keyboard.pressedChars[utf8 and utf8.codepoint(charOrCode) or charOrCode:byte()]
elseif type(charOrCode) == "number" then
	return keyboard.pressedCodes[charOrCode]
end
end

function keyboard.isShiftDown()
return keyboard.pressedCodes[keyboard.keys.lshift] or keyboard.pressedCodes[keyboard.keys.rshift]
end

-------------------------------------------------------------------------------

keyboard.keys["1"]           = 0x02
keyboard.keys["2"]           = 0x03
keyboard.keys["3"]           = 0x04
keyboard.keys["4"]           = 0x05
keyboard.keys["5"]           = 0x06
keyboard.keys["6"]           = 0x07
keyboard.keys["7"]           = 0x08
keyboard.keys["8"]           = 0x09
keyboard.keys["9"]           = 0x0A
keyboard.keys["0"]           = 0x0B
keyboard.keys.a               = 0x1E
keyboard.keys.b               = 0x30
keyboard.keys.c               = 0x2E
keyboard.keys.d               = 0x20
keyboard.keys.e               = 0x12
keyboard.keys.f               = 0x21
keyboard.keys.g               = 0x22
keyboard.keys.h               = 0x23
keyboard.keys.i               = 0x17
keyboard.keys.j               = 0x24
keyboard.keys.k               = 0x25
keyboard.keys.l               = 0x26
keyboard.keys.m               = 0x32
keyboard.keys.n               = 0x31
keyboard.keys.o               = 0x18
keyboard.keys.p               = 0x19
keyboard.keys.q               = 0x10
keyboard.keys.r               = 0x13
keyboard.keys.s               = 0x1F
keyboard.keys.t               = 0x14
keyboard.keys.u               = 0x16
keyboard.keys.v               = 0x2F
keyboard.keys.w               = 0x11
keyboard.keys.x               = 0x2D
keyboard.keys.y               = 0x15
keyboard.keys.z               = 0x2C

keyboard.keys.apostrophe      = 0x28
keyboard.keys.at              = 0x91
keyboard.keys.back            = 0x0E -- backspace
keyboard.keys.backslash       = 0x2B
keyboard.keys.capital         = 0x3A -- capslock
keyboard.keys.colon           = 0x92
keyboard.keys.comma           = 0x33
keyboard.keys.enter           = 0x1C
keyboard.keys.equals          = 0x0D
keyboard.keys.grave           = 0x29 -- accent grave
keyboard.keys.lbracket        = 0x1A
keyboard.keys.lcontrol        = 0x1D
keyboard.keys.lmenu           = 0x38 -- left Alt
keyboard.keys.lshift          = 0x2A
keyboard.keys.minus           = 0x0C
keyboard.keys.numlock         = 0x45
keyboard.keys.pause           = 0xC5
keyboard.keys.period          = 0x34
keyboard.keys.rbracket        = 0x1B
keyboard.keys.rcontrol        = 0x9D
keyboard.keys.rmenu           = 0xB8 -- right Alt
keyboard.keys.rshift          = 0x36
keyboard.keys.scroll          = 0x46 -- Scroll Lock
keyboard.keys.semicolon       = 0x27
keyboard.keys.slash           = 0x35 -- / on main keyboard
keyboard.keys.space           = 0x39
keyboard.keys.stop            = 0x95
keyboard.keys.tab             = 0x0F
keyboard.keys.underline       = 0x93

-- Keypad (and numpad with numlock off)
keyboard.keys.up              = 0xC8
keyboard.keys.down            = 0xD0
keyboard.keys.left            = 0xCB
keyboard.keys.right           = 0xCD
keyboard.keys.home            = 0xC7
keyboard.keys["end"]         = 0xCF
keyboard.keys.pageUp          = 0xC9
keyboard.keys.pageDown        = 0xD1
keyboard.keys.insert          = 0xD2
keyboard.keys.delete          = 0xD3

-- Function keys
keyboard.keys.f1              = 0x3B
keyboard.keys.f2              = 0x3C
keyboard.keys.f3              = 0x3D
keyboard.keys.f4              = 0x3E
keyboard.keys.f5              = 0x3F
keyboard.keys.f6              = 0x40
keyboard.keys.f7              = 0x41
keyboard.keys.f8              = 0x42
keyboard.keys.f9              = 0x43
keyboard.keys.f10             = 0x44
keyboard.keys.f11             = 0x57
keyboard.keys.f12             = 0x58
keyboard.keys.f13             = 0x64
keyboard.keys.f14             = 0x65
keyboard.keys.f15             = 0x66
keyboard.keys.f16             = 0x67
keyboard.keys.f17             = 0x68
keyboard.keys.f18             = 0x69
keyboard.keys.f19             = 0x71

-- Japanese keyboards
keyboard.keys.kana            = 0x70
keyboard.keys.kanji           = 0x94
keyboard.keys.convert         = 0x79
keyboard.keys.noconvert       = 0x7B
keyboard.keys.yen             = 0x7D
keyboard.keys.circumflex      = 0x90
keyboard.keys.ax              = 0x96

-- Numpad
keyboard.keys.numpad0         = 0x52
keyboard.keys.numpad1         = 0x4F
keyboard.keys.numpad2         = 0x50
keyboard.keys.numpad3         = 0x51
keyboard.keys.numpad4         = 0x4B
keyboard.keys.numpad5         = 0x4C
keyboard.keys.numpad6         = 0x4D
keyboard.keys.numpad7         = 0x47
keyboard.keys.numpad8         = 0x48
keyboard.keys.numpad9         = 0x49
keyboard.keys.numpadmul       = 0x37
keyboard.keys.numpaddiv       = 0xB5
keyboard.keys.numpadsub       = 0x4A
keyboard.keys.numpadadd       = 0x4E
keyboard.keys.numpaddecimal   = 0x53
keyboard.keys.numpadcomma     = 0xB3
keyboard.keys.numpadenter     = 0x9C
keyboard.keys.numpadequals    = 0x8D

-- Create inverse mapping for name lookup.
setmetatable(keyboard.keys,
{
__index = function(tbl, k)
	if type(k) ~= "number" then return end
	for name,value in pairs(tbl) do
	if value == k then
		return name
	end
	end
end
})




local term





local function onKeyChangeFoKeyboard(ev, uuid, char, code)
-- nil might be slightly more mem friendly during runtime
-- and `or nil` appears to only cost 30 bytes
if term.keyboard() == uuid then
	keyboard.pressedChars[char] = ev == "key_down" or nil
	keyboard.pressedCodes[code] = ev == "key_down" or nil
end
end


















local lib={}
lib.internal={}
function lib.internal.range_adjust(f,l,s)
checkArg(1,f,'number','nil')
checkArg(2,l,'number','nil')
checkArg(3,s,'number')
if f==nil then f=1 elseif f<0 then f=s+f+1 end
if l==nil then l=s elseif l<0 then l=s+l+1 end
return f,l
end
function lib.internal.table_view(tbl,f,l)
return setmetatable({},
{
	__index = function(_, key)
	return (type(key) ~= 'number' or (key >= f and key <= l)) and tbl[key] or nil
	end,
	__len = function(_)
	return l
	end,
})
end
local adjust=lib.internal.range_adjust
local view=lib.internal.table_view

-- first(p1,p2) searches for the first range in p1 that satisfies p2
function lib.first(tbl,pred,f,l)
checkArg(1,tbl,'table')
checkArg(2,pred,'function','table')
if type(pred)=='table'then
	local set;set,pred=pred,function(e,fi,tbl)
	for vi=1,#set do
		local v=set[vi]
		if lib.begins(tbl,v,fi) then return true,#v end
	end
	end
end
local s=#tbl
f,l=adjust(f,l,s)
tbl=view(tbl,f,l)
for i=f,l do
	local si,ei=pred(tbl[i],i,tbl)
	if si then
	return i,i+(ei or 1)-1
	end
end
end

-- returns true if p1 at first p3 equals element for element p2
function lib.begins(tbl,v,f,l)
checkArg(1,tbl,'table')
checkArg(2,v,'table')
local vs=#v
f,l=adjust(f,l,#tbl)
if vs>(l-f+1)then return end
for i=1,vs do
	if tbl[f+i-1]~=v[i] then return end
end
return true
end

function lib.concat(...)
local r,rn,k={},0
for _,tbl in ipairs({...})do
	if type(tbl)~='table'then
	return nil,'parameter '..tostring(_)..' to concat is not a table'
	end
	local n=tbl.n or #tbl
	k=k or tbl.n
	for i=1,n do
	rn=rn+1;r[rn]=tbl[i]
	end
end
r.n=k and rn or nil
return r
end




local adjust=lib.internal.range_adjust
local view=lib.internal.table_view

-- works like string.sub but on elements of an indexed table
function lib.sub(tbl,f,l)
checkArg(1,tbl,'table')
local r,s={},#tbl
f,l=adjust(f,l,s)
l=math.min(l,s)
for i=math.max(f,1),l do
	r[#r+1]=tbl[i]
end
return r
end 

-- Returns a list of subsets of tbl where partitioner acts as a delimiter.
function lib.partition(tbl,partitioner,dropEnds,f,l)
checkArg(1,tbl,'table')
checkArg(2,partitioner,'function','table')
checkArg(3,dropEnds,'boolean','nil')
if type(partitioner)=='table'then
	return lib.partition(tbl,function(e,i,tbl)
	return lib.first(tbl,partitioner,i)
	end,dropEnds,f,l)
end
local s=#tbl
f,l=adjust(f,l,s)
local cut=view(tbl,f,l)
local result={}
local need=true
local exp=function()if need then result[#result+1]={}need=false end end
local i=f
while i<=l do
	local e=cut[i]
	local ds,de=partitioner(e,i,cut)
	-- true==partition here
	if ds==true then ds,de=i,i
	elseif ds==false then ds,de=nil,nil end
	if ds~=nil then
	ds,de=adjust(ds,de,l)
	ds=ds>=i and ds--no more
	end
	if not ds then -- false or nil
	exp()
	table.insert(result[#result],e)
	else
	local sub=lib.sub(cut,i,not dropEnds and de or (ds-1))
	if #sub>0 then
		exp()
		result[#result+math.min(#result[#result],1)]=sub
	end
	-- ensure i moves forward
	local ensured=math.max(math.max(de or ds,ds),i)
	if de and ds and de<ds and ensured==i then
		if #result==0 then result[1]={} end
		table.insert(result[#result],e)
	end
	i=ensured
	need=true
	end
	i=i+1
end

return result
end 

-- calls callback(e,i,tbl) for each ith element e in table tbl from first
function lib.foreach(tbl,c,f,l)
checkArg(1,tbl,'table')
checkArg(2,c,'function','string')
local ck=c
c=type(c)=="string" and function(e) return e[ck] end or c
local s=#tbl
f,l=adjust(f,l,s)
tbl=view(tbl,f,l)
local r={}
for i=f,l do
	local n,k=c(tbl[i],i,tbl)
	if n~=nil then
	if k then r[k]=n
	else r[#r+1]=n end
	end
end
return r
end

function lib.where(tbl,p,f,l)
return lib.foreach(tbl,
	function(e,i,tbl)
	return p(e,i,tbl)and e or nil
	end,f,l)
end

-- works with pairs on tables
-- returns the kv pair, or nil and the number of pairs iterated
function lib.at(tbl, index)
checkArg(1, tbl, "table")
checkArg(2, index, "number", "nil")
local current_index = 1
for k,v in pairs(tbl) do
	if current_index == index then
	return k,v
	end
	current_index = current_index + 1
end
return nil, current_index - 1 -- went one too far
end 
















local fs = require("filesystem")
--local keyboard = require("keyboard")
--local shell = require("shell")
--local term = require("term") -- TODO use tty and cursor position instead of global area and gpu

local unicode = require("unicode")

local text = {}
text.internal = {}

text.syntax = {"^%d?>>?&%d+","^%d?>>?",">>?","<%&%d+","<",";","&&","||?"}

function text.trim(value) -- from http://lua-users.org/wiki/StringTrim
local from = string.match(value, "^%s*()")
return from > #value and "" or string.match(value, ".*%S", from)
end

-- used by lib/sh
function text.escapeMagic(txt)
return txt:gsub('[%(%)%.%%%+%-%*%?%[%^%$]', '%%%1')
end

function text.removeEscapes(txt)
return txt:gsub("%%([%(%)%.%%%+%-%*%?%[%^%$])","%1")
end

function text.internal.tokenize(value, options)
checkArg(1, value, "string")
checkArg(2, options, "table", "nil")
options = options or {}
local delimiters = options.delimiters
local custom = not not options.delimiters
delimiters = delimiters or text.syntax

local words, reason = text.internal.words(value, options)

local splitter = text.escapeMagic(custom and table.concat(delimiters) or "<>|;&")
if type(words) ~= "table" or 
	#splitter == 0 or
	not value:find("["..splitter.."]") then
	return words, reason
end

return text.internal.splitWords(words, delimiters)
end

-- tokenize input by quotes and whitespace
function text.internal.words(input, options)
checkArg(1, input, "string")
checkArg(2, options, "table", "nil")
options = options or {}
local quotes = options.quotes
local show_escapes = options.show_escapes
local qr = nil
quotes = quotes or {{"'","'",true},{'"','"'},{'`','`'}}
local function append(dst, txt, _qr)
	local size = #dst
	if size == 0 or dst[size].qr ~= _qr then
	dst[size+1] = {txt=txt, qr=_qr}
	else
	dst[size].txt = dst[size].txt..txt
	end
end
-- token meta is {string,quote rule}
local tokens, token = {}, {}
local escaped, start = false, -1
for i = 1, unicode.len(input) do
	local char = unicode.sub(input, i, i)
	if escaped then -- escaped character
	escaped = false
	-- include escape char if show_escapes
	-- or the followwing are all true
	-- 1. qr active
	-- 2. the char escaped is NOT the qr closure
	-- 3. qr is not literal
	if show_escapes or (qr and not qr[3] and qr[2] ~= char) then
		append(token, '\\', qr)
	end
	append(token, char, qr)
	elseif char == "\\" and (not qr or not qr[3]) then
		escaped = true
	elseif qr and qr[2] == char then -- end of quoted string
	-- if string is empty, we can still capture a quoted empty arg
	if #token == 0 or #token[#token] == 0 then
		append(token, '', qr)
	end
	qr = nil
	elseif not qr and tx.first(quotes,function(Q)
	qr=Q[1]==char and Q or nil return qr end) then
	start = i
	elseif not qr and string.find(char, "%s") then
	if #token > 0 then
		table.insert(tokens, token)
	end
	token = {}
	else -- normal char
	append(token, char, qr)
	end
end
if qr then
	return nil, "unclosed quote at index " .. start
end

if #token > 0 then
	table.insert(tokens, token)
end

return tokens
end

-- separate string value into an array of words delimited by whitespace
-- groups by quotes
-- options is a table used for internal undocumented purposes
function text.tokenize(value, options)
checkArg(1, value, "string")
checkArg(2, options, "table", "nil")
options = options or {}

local tokens, reason = text.internal.tokenize(value, options)

if type(tokens) ~= "table" then
	return nil, reason
end

if options.doNotNormalize then
	return tokens
end

return text.internal.normalize(tokens)
end

-------------------------------------------------------------------------------
-- like tokenize, but does not drop any text such as whitespace
-- splits input into an array for sub strings delimited by delimiters
-- delimiters are included in the result if not dropDelims
function text.split(input, delimiters, dropDelims, di)
checkArg(1, input, "string")
checkArg(2, delimiters, "table")
checkArg(3, dropDelims, "boolean", "nil")
checkArg(4, di, "number", "nil")

if #input == 0 then return {} end
di = di or 1
local result = {input}
if di > #delimiters then return result end

local function add(part, index, r, s, e)
	local sub = part:sub(s,e)
	if #sub == 0 then return index end
	local subs = r and text.split(sub,delimiters,dropDelims,r) or {sub}
	for i=1,#subs do
	table.insert(result, index+i-1, subs[i])
	end
	return index+#subs
end

local i,d=1,delimiters[di]
while true do
	local next = table.remove(result,i)
	if not next then break end
	local si,ei = next:find(d)
	if si and ei and ei~=0 then -- delim found
	i=add(next, i, di+1, 1, si-1)
	i=dropDelims and i or add(next, i, false, si, ei)
	i=add(next, i, di, ei+1)
	else
	i=add(next, i, di+1, 1, #next)
	end
end

return result
end

-----------------------------------------------------------------------------

-- splits each word into words at delimiters
-- delimiters are kept as their own words
-- quoted word parts are not split
function text.internal.splitWords(words, delimiters)
checkArg(1,words,"table")
checkArg(2,delimiters,"table")

local split_words = {}
local next_word
local function add_part(part)
	if next_word then
	split_words[#split_words+1] = {}
	end
	table.insert(split_words[#split_words], part)
	next_word = false
end
for wi=1,#words do local word = words[wi]
	next_word = true
	for pi=1,#word do local part = word[pi]
	local qr = part.qr
	if qr then
		add_part(part)
	else
		local part_text_splits = text.split(part.txt, delimiters)
		tx.foreach(part_text_splits, function(sub_txt)
		local delim = #text.split(sub_txt, delimiters, true) == 0
		next_word = next_word or delim
		add_part({txt=sub_txt,qr=qr})
		next_word = delim
		end)
	end
	end
end

return split_words
end

function text.internal.normalize(words, omitQuotes)
checkArg(1, words, "table")
checkArg(2, omitQuotes, "boolean", "nil")
local norms = {}
for _,word in ipairs(words) do
	local norm = {}
	for _,part in ipairs(word) do
	norm = tx.concat(norm, not omitQuotes and part.qr and {part.qr[1], part.txt, part.qr[2]} or {part.txt})
	end
	norms[#norms+1]=table.concat(norm)
end
return norms
end

function text.internal.stream_base(binary)
return
{
	binary = binary,
	plen = binary and string.len or unicode.len,
	psub = binary and string.sub or unicode.sub,
	seek = function (handle, whence, to)
	if not handle.txt then
		return nil, "bad file descriptor"
	end
	to = to or 0
	local offset = handle:indexbytes()
	if whence == "cur" then
		offset = offset + to
	elseif whence == "set" then
		offset = to
	elseif whence == "end" then
		offset = handle.len + to
	end
	offset = math.max(0, math.min(offset, handle.len))
	handle:byteindex(offset)
	return offset
	end,
	indexbytes = function (handle)
	return handle.psub(handle.txt, 1, handle.index):len()
	end,
	byteindex = function (handle, offset)
	local sub = string.sub(handle.txt, 1, offset)
	handle.index = handle.plen(sub)
	end,
}
end

function text.internal.reader(txt, mode)
checkArg(1, txt, "string")
local reader = setmetatable(
{
	txt = txt,
	len = string.len(txt),
	index = 0,
	read = function(_, n)
	checkArg(1, n, "number")
	if not _.txt then
		return nil, "bad file descriptor"
	end
	if _.index >= _.plen(_.txt) then
		return nil
	end
	local next = _.psub(_.txt, _.index + 1, _.index + n)
	_.index = _.index + _.plen(next)
	return next
	end,
	close = function(_)
	if not _.txt then
		return nil, "bad file descriptor"
	end
	_.txt = nil
	return true
	end,
}, {__index=text.internal.stream_base((mode or ""):match("b"))})

return require("buffer").new("r", reader)
end

function text.internal.writer(ostream, mode, append_txt)
if type(ostream) == "table" then
	local mt = getmetatable(ostream) or {}
	checkArg(1, mt.__call, "function")
end
checkArg(1, ostream, "function", "table")
checkArg(2, append_txt, "string", "nil")
local writer = setmetatable(
{
	txt = "",
	index = 0, -- last location of write
	len = 0,
	write = function(_, ...)
	if not _.txt then
		return nil, "bad file descriptor"
	end
	local pre = _.psub(_.txt, 1, _.index)
	local vs = {}
	local pos = _.psub(_.txt, _.index + 1)
	for _,v in ipairs({...}) do
		table.insert(vs, v)
	end
	vs = table.concat(vs)
	_.index = _.index + _.plen(vs)
	_.txt = pre .. vs .. pos
	_.len = string.len(_.txt)
	return true
	end,
	close = function(_)
	if not _.txt then
		return nil, "bad file descriptor"
	end
	ostream((append_txt or "") .. _.txt)
	_.txt = nil
	return true
	end,
}, {__index=text.internal.stream_base((mode or ""):match("b"))})

return require("buffer").new("w", writer)
end

function text.detab(value, tabWidth)
checkArg(1, value, "string")
checkArg(2, tabWidth, "number", "nil")
tabWidth = tabWidth or 8
local function rep(match)
	local spaces = tabWidth - match:len() % tabWidth
	return match .. string.rep(" ", spaces)
end
local result = value:gsub("([^\n]-)\t", rep) -- truncate results
return result
end

function text.padLeft(value, length)
checkArg(1, value, "string", "nil")
checkArg(2, length, "number")
if not value or unicode.wlen(value) == 0 then
	return string.rep(" ", length)
else
	return string.rep(" ", length - unicode.wlen(value)) .. value
end
end

function text.padRight(value, length)
checkArg(1, value, "string", "nil")
checkArg(2, length, "number")
if not value or unicode.wlen(value) == 0 then
	return string.rep(" ", length)
else
	return value .. string.rep(" ", length - unicode.wlen(value))
end
end

function text.wrap(value, width, maxWidth)
checkArg(1, value, "string")
checkArg(2, width, "number")
checkArg(3, maxWidth, "number")
local line, nl = value:match("([^\r\n]*)(\r?\n?)") -- read until newline
if unicode.wlen(line) > width then -- do we even need to wrap?
	local partial = unicode.wtrunc(line, width)
	local wrapped = partial:match("(.*[^a-zA-Z0-9._()'`=])")
	if wrapped or unicode.wlen(line) > maxWidth then
	partial = wrapped or partial
	return partial, unicode.sub(value, unicode.len(partial) + 1), true
	else
	return "", value, true -- write in new line.
	end
end
local start = unicode.len(line) + unicode.len(nl) + 1
return line, start <= unicode.len(value) and unicode.sub(value, start) or nil, unicode.len(nl) > 0
end

function text.wrappedLines(value, width, maxWidth)
local line
return function()
	if value then
	line, value = text.wrap(value, width, maxWidth)
	return line
	end
end
end


local graphic = require("graphic")
local event = require("event")
local colors = require("gui_container").colors
local component = require("component")
local paths = require("paths")

local screen, nickname, filename, readonly = ...
local file_parentpath = paths.path(filename)

local gpu = graphic.findGpu(screen)
if graphic.getDepth(screen) == 1 then
gpu.setBackground(0)
else
gpu.setBackground(colors.gray)
end
gpu.setForeground(colors.white)

local keyaddr = component.invoke(screen, "getKeyboards")[1]

local blinkingTerm = true
local cx, cy = 1, 1
term = {clear = function()
	local gpu = graphic.findGpu(screen)
	local rx, ry = gpu.getResolution()
	gpu.fill(1, 1, rx, ry, " ")
end, pull = function(...)
	graphic.updateFlag(screen)

	if blinkingTerm then
		local gpu = graphic.findGpu(screen)
		local char, fore, back = gpu.get(cx, cy)
		gpu.setBackground(fore)
		gpu.setForeground(back)
		gpu.set(cx, cy, char)
	end
	local eventData = {event.pull(...)}
	if eventData[1] == "key_down" or eventData[1] == "key_up" then
	onKeyChangeFoKeyboard(table.unpack(eventData))
	end
	if blinkingTerm then
	local gpu = graphic.findGpu(screen)
	local char, fore, back = gpu.get(cx, cy)
	gpu.setBackground(fore)
	gpu.setForeground(back)
	gpu.set(cx, cy, char)
	end

	graphic.updateFlag(screen)

	return table.unpack(eventData)
end, setCursor = function(x, y)
	cx, cy = x, y
end, getCursor = function()
	return cx, cy
end, setCursorBlink = function(state)
	blinkingTerm = state
end, getCursorBlink = function()
	return blinkingTerm
end, screen = function()
	return screen
end, keyboard = function()
	return keyaddr
end, getGlobalArea = function()
	local sx, sy = graphic.findGpu(screen).getResolution()
	return 1, 1, sx, sy
end}

local readonly = readonly or fs.get(filename).isReadOnly()

local function loadConfig()
	local env = {}
	env.keybinds =
		env.keybinds or
		{
			left = {{"left"}},
			right = {{"right"}},
			up = {{"up"}},
			down = {{"down"}},
			home = {{"home"}},
			eol = {{"end"}},
			pageUp = {{"pageUp"}},
			pageDown = {{"pageDown"}},
			backspace = {{"back"}, {"shift", "back"}},
			delete = {{"delete"}},
			deleteLine = {{"control", "delete"}, {"shift", "delete"}},
			newline = {{"enter"}},
			save = {{"control", "s"}},
			close = {{"control", "w"}},
			find = {{"control", "f"}},
			findnext = {{"control", "g"}, {"control", "n"}, {"f3"}},
			cut = {{"control", "k"}},
			uncut = {{"control", "u"}}
		}
	return env
end

term.clear()

local running = true
local buffer = {}
local scrollX, scrollY = 0, 0
local config = loadConfig()

local cutBuffer = {}
-- cutting is true while we're in a cutting operation and set to false when cursor changes lines
-- basically, whenever you change lines, the cutting operation ends, so the next time you cut a new buffer will be created
local cutting = false

local getKeyBindHandler  -- forward declaration for refind()

local function helpStatusText()
	local function prettifyKeybind(label, command)
		local keybind = type(config.keybinds) == "table" and config.keybinds[command]
		if type(keybind) ~= "table" or type(keybind[1]) ~= "table" then
			return ""
		end
		local alt, control, shift, key
		for _, value in ipairs(keybind[1]) do
			if value == "alt" then
				alt = true
			elseif value == "control" then
				control = true
			elseif value == "shift" then
				shift = true
			else
				key = value
			end
		end
		if not key then
			return ""
		end
		return label ..
			": [" ..
				(control and "Ctrl+" or "") ..
					(alt and "Alt+" or "") .. (shift and "Shift+" or "") .. unicode.upper(key) .. "] "
	end
	return prettifyKeybind("Save", "save") ..
		prettifyKeybind("Close", "close") ..
			prettifyKeybind("Find", "find") .. prettifyKeybind("Cut", "cut") .. prettifyKeybind("Uncut", "uncut")
end

-------------------------------------------------------------------------------

local function setStatus(value)
	local x, y, w, h = term.getGlobalArea()
	value = unicode.wlen(value) > w - 10 and unicode.wtrunc(value, w - 9) or value
	value = text.padRight(value, w - 10)
	local gpu = graphic.findGpu(screen)
	gpu.set(x, y + h - 1, value)
end

local function getArea()
	local gpu = graphic.findGpu(screen)
	local x, y, w, h = term.getGlobalArea()
	return x, y, w, h - 1
end

local function removePrefix(line, length)
	if length >= unicode.wlen(line) then
		return ""
	else
		local prefix = unicode.wtrunc(line, length + 1)
		local suffix = unicode.sub(line, unicode.len(prefix) + 1)
		length = length - unicode.wlen(prefix)
		if length > 0 then
			suffix = (" "):rep(unicode.charWidth(suffix) - length) .. unicode.sub(suffix, 2)
		end
		return suffix
	end
end

local function lengthToChars(line, length)
	if length > unicode.wlen(line) then
		return unicode.len(line) + 1
	else
		local prefix = unicode.wtrunc(line, length)
		return unicode.len(prefix) + 1
	end
end

local function isWideAtPosition(line, x)
	local index = lengthToChars(line, x)
	if index > unicode.len(line) then
		return false, false
	end
	local prefix = unicode.sub(line, 1, index)
	local char = unicode.sub(line, index, index)
	--isWide, isRight
	return unicode.isWide(char), unicode.wlen(prefix) == x
end

local function drawLine(x, y, w, h, lineNr)
	local gpu = graphic.findGpu(screen)
	local yLocal = lineNr - scrollY
	if yLocal > 0 and yLocal <= h then
		local str = removePrefix(buffer[lineNr] or "", scrollX)
		str = unicode.wlen(str) > w and unicode.wtrunc(str, w + 1) or str
		str = text.padRight(str, w)
		gpu.set(x, y - 1 + lineNr - scrollY, str)
	end
end

local function getCursor()
	local cx, cy = term.getCursor()
	return cx + scrollX, cy + scrollY
end

local function line()
	local _, cby = getCursor()
	return buffer[cby] or ""
end

local function getNormalizedCursor()
	local cbx, cby = getCursor()
	local wide, right = isWideAtPosition(buffer[cby], cbx)
	if wide and right then
		cbx = cbx - 1
	end
	return cbx, cby
end

local function setCursor(nbx, nby)
	local gpu = graphic.findGpu(screen)

	local x, y, w, h = getArea()
	nbx, nby = nbx // 1, nby // 1
	nby = math.max(1, math.min(#buffer, nby))

	local ncy = nby - scrollY
	if ncy > h then
		term.setCursorBlink(false)
		local sy = nby - h
		local dy = math.abs(scrollY - sy)
		scrollY = sy
		if h > dy then
			gpu.copy(x, y + dy, w, h - dy, 0, -dy)
		end
		for lineNr = nby - (math.min(dy, h) - 1), nby do
			drawLine(x, y, w, h, lineNr)
		end
	elseif ncy < 1 then
		term.setCursorBlink(false)
		local sy = nby - 1
		local dy = math.abs(scrollY - sy)
		scrollY = sy
		if h > dy then
			gpu.copy(x, y, w, h - dy, 0, dy)
		end
		for lineNr = nby, nby + (math.min(dy, h) - 1) do
			drawLine(x, y, w, h, lineNr)
		end
	end
	term.setCursor(term.getCursor(), nby - scrollY)

	nbx = math.max(1, math.min(unicode.wlen(line()) + 1, nbx))
	local wide, right = isWideAtPosition(line(), nbx)
	local ncx = nbx - scrollX
	if ncx > w or (ncx + 1 > w and wide and not right) then
		term.setCursorBlink(false)
		scrollX = nbx - w + ((wide and not right) and 1 or 0)
		for lineNr = 1 + scrollY, math.min(h + scrollY, #buffer) do
			drawLine(x, y, w, h, lineNr)
		end
	elseif ncx < 1 or (ncx - 1 < 1 and wide and right) then
		term.setCursorBlink(false)
		scrollX = nbx - 1 - ((wide and right) and 1 or 0)
		for lineNr = 1 + scrollY, math.min(h + scrollY, #buffer) do
			drawLine(x, y, w, h, lineNr)
		end
	end
	term.setCursor(nbx - scrollX, nby - scrollY)
	--update with term lib
	nbx, nby = getCursor()
	local locstring = string.format("%d,%d", nby, nbx)
	if #cutBuffer > 0 then
		locstring = string.format("(#%d) %s", #cutBuffer, locstring)
	end
	locstring = text.padLeft(locstring, 10)
	gpu.set(x + w - #locstring, y + h, locstring)
end

local function highlight(bx, by, length, enabled)
	local gpu = graphic.findGpu(screen)

	local x, y, w, h = getArea()
	local cx, cy = bx - scrollX, by - scrollY
	cx = math.max(1, math.min(w, cx))
	cy = math.max(1, math.min(h, cy))
	length = math.max(1, math.min(w - cx, length))

	local fg, fgp = gpu.getForeground()
	local bg, bgp = gpu.getBackground()
	if enabled then
		gpu.setForeground(bg, bgp)
		gpu.setBackground(fg, fgp)
	end
	local indexFrom = lengthToChars(buffer[by], bx)
	local value = unicode.sub(buffer[by], indexFrom)
	if unicode.wlen(value) > length then
		value = unicode.wtrunc(value, length + 1)
	end
	gpu.set(x - 1 + cx, y - 1 + cy, value)
	if enabled then
		gpu.setForeground(fg, fgp)
		gpu.setBackground(bg, bgp)
	end
end

local function home()
	local _, cby = getCursor()
	setCursor(1, cby)
end

local function ende()
	local _, cby = getCursor()
	setCursor(unicode.wlen(line()) + 1, cby)
end

local function left()
	local cbx, cby = getNormalizedCursor()
	if cbx > 1 then
		local wideTarget, rightTarget = isWideAtPosition(line(), cbx - 1)
		if wideTarget and rightTarget then
			setCursor(cbx - 2, cby)
		else
			setCursor(cbx - 1, cby)
		end
		return true -- for backspace
	elseif cby > 1 then
		setCursor(cbx, cby - 1)
		ende()
		return true -- again, for backspace
	end
end

local function right(n)
	n = n or 1
	local cbx, cby = getNormalizedCursor()
	local be = unicode.wlen(line()) + 1
	local wide, isRight = isWideAtPosition(line(), cbx + n)
	if wide and isRight then
		n = n + 1
	end
	if cbx + n <= be then
		setCursor(cbx + n, cby)
	elseif cby < #buffer then
		setCursor(1, cby + 1)
	end
end

local function up(n)
	n = n or 1
	local cbx, cby = getCursor()
	if cby > 1 then
		setCursor(cbx, cby - n)
	end
	cutting = false
end

local function down(n)
	n = n or 1
	local cbx, cby = getCursor()
	if cby < #buffer then
		setCursor(cbx, cby + n)
	end
	cutting = false
end

local function delete(fullRow)
	local gpu = graphic.findGpu(screen)

	local _, cy = term.getCursor()
	local cbx, cby = getCursor()
	local x, y, w, h = getArea()
	local function deleteRow(row)
		local content = table.remove(buffer, row)
		local rcy = cy + (row - cby)
		if rcy <= h then
			gpu.copy(x, y + rcy, w, h - rcy, 0, -1)
			drawLine(x, y, w, h, row + (h - rcy))
		end
		return content
	end
	if fullRow then
		term.setCursorBlink(false)
		if #buffer > 1 then
			deleteRow(cby)
		else
			buffer[cby] = ""
			gpu.fill(x, y - 1 + cy, w, 1, " ")
		end
		setCursor(1, cby)
	elseif cbx <= unicode.wlen(line()) then
		term.setCursorBlink(false)
		local index = lengthToChars(line(), cbx)
		buffer[cby] = unicode.sub(line(), 1, index - 1) .. unicode.sub(line(), index + 1)
		drawLine(x, y, w, h, cby)
	elseif cby < #buffer then
		term.setCursorBlink(false)
		local append = deleteRow(cby + 1)
		buffer[cby] = buffer[cby] .. append
		drawLine(x, y, w, h, cby)
	else
		return
	end
	setStatus(helpStatusText())
end

local function insert(value)
	if not value or unicode.len(value) < 1 then
		return
	end
	term.setCursorBlink(false)
	local cbx, cby = getCursor()
	local x, y, w, h = getArea()
	local index = lengthToChars(line(), cbx)
	buffer[cby] = unicode.sub(line(), 1, index - 1) .. value .. unicode.sub(line(), index)
	drawLine(x, y, w, h, cby)
	right(unicode.wlen(value))
	setStatus(helpStatusText())
end

local function enter()
	local gpu = graphic.findGpu(screen)

	term.setCursorBlink(false)
	local _, cy = term.getCursor()
	local cbx, cby = getCursor()
	local x, y, w, h = getArea()
	local index = lengthToChars(line(), cbx)
	table.insert(buffer, cby + 1, unicode.sub(buffer[cby], index))
	buffer[cby] = unicode.sub(buffer[cby], 1, index - 1)
	drawLine(x, y, w, h, cby)
	if cy < h then
		if cy < h - 1 then
			gpu.copy(x, y + cy, w, h - (cy + 1), 0, 1)
		end
		drawLine(x, y, w, h, cby + 1)
	end
	setCursor(1, cby + 1)
	setStatus(helpStatusText())
	cutting = false
end

local findText = ""

local function find()
	local _, _, _, h = getArea()
	local cbx, cby = getCursor()
	local ibx, iby = cbx, cby
	while running do
		if unicode.len(findText) > 0 then
			local sx, sy
			for syo = 1, #buffer do -- iterate lines with wraparound
				sy = (iby + syo - 1 + #buffer - 1) % #buffer + 1
				sx = string.find(buffer[sy], findText, syo == 1 and ibx or 1, true)
				if sx and (sx >= ibx or syo > 1) then
					break
				end
			end
			if not sx then -- special case for single matches
				sy = iby
				sx = string.find(buffer[sy], findText, nil, true)
			end
			if sx then
				sx = unicode.wlen(string.sub(buffer[sy], 1, sx - 1)) + 1
				cbx, cby = sx, sy
				setCursor(cbx, cby)
				highlight(cbx, cby, unicode.wlen(findText), true)
			end
		end
		term.setCursor(7 + unicode.wlen(findText), h + 1)
		setStatus("Find: " .. findText)

		local eventt, address, char, code = term.pull() 
		if eventt == "key_down" then
		if address == term.keyboard() then
			local handler, name = getKeyBindHandler(code)
			highlight(cbx, cby, unicode.wlen(findText), false)
			if name == "newline" then
				break
			elseif name == "close" then
				handler()
			elseif name == "backspace" then
				findText = unicode.sub(findText, 1, -2)
			elseif name == "find" or name == "findnext" then
				ibx = cbx + 1
				iby = cby
			elseif not keyboard.isControl(char) then
				findText = findText .. unicode.char(char)
			end
		end
		end
	end
	setCursor(cbx, cby)
	setStatus(helpStatusText())
end

local function cut()
	if not cutting then
		cutBuffer = {}
	end
	local cbx, cby = getCursor()
	table.insert(cutBuffer, buffer[cby])
	delete(true)
	cutting = true
	home()
end

local function uncut()
	home()
	for _, line in ipairs(cutBuffer) do
		insert(line)
		enter()
	end
end

-------------------------------------------------------------------------------

local keyBindHandlers = {
	left = left,
	right = right,
	up = up,
	down = down,
	home = home,
	eol = ende,
	pageUp = function()
		local _, _, _, h = getArea()
		up(h - 1)
	end,
	pageDown = function()
		local _, _, _, h = getArea()
		down(h - 1)
	end,
	backspace = function()
		if not readonly and left() then
			delete()
		end
	end,
	delete = function()
		if not readonly then
			delete()
		end
	end,
	deleteLine = function()
		if not readonly then
			delete(true)
		end
	end,
	newline = function()
		if not readonly then
			enter()
		end
	end,
	save = function()
		if readonly then
			return
		end
		local new = not fs.exists(filename)
		if not fs.exists(file_parentpath) then
			fs.makeDirectory(file_parentpath)
		end
		local f, reason = fs.open(filename, "w")
		if f then
			local chars, firstLine = 0, true
			local filedata = ""
			for _, bline in ipairs(buffer) do
				if not firstLine then
					bline = "\n" .. bline
				end
				firstLine = false
				filedata = filedata .. bline
				chars = chars + unicode.len(bline)
			end
			f.write(filedata)
			f.close()
			local format
			if new then
				format = [["%s" [New] %dL,%dC written]]
			else
				format = [["%s" %dL,%dC written]]
			end
			setStatus(string.format(format, paths.name(filename), #buffer, chars))
		else
			setStatus(reason)
		end
	end,
	close = function()
		-- TODO ask to save if changed
		running = false
	end,
	find = function()
		findText = ""
		find()
	end,
	findnext = find,
	cut = cut,
	uncut = uncut
}

getKeyBindHandler = function(code)
	if type(config.keybinds) ~= "table" then
		return
	end
	-- Look for matches, prefer more 'precise' keybinds, e.g. prefer
	-- ctrl+del over del.
	local result, resultName, resultWeight = nil, nil, 0
	for command, keybinds in pairs(config.keybinds) do
		if type(keybinds) == "table" and keyBindHandlers[command] then
			for _, keybind in ipairs(keybinds) do
				if type(keybind) == "table" then
					local alt, control, shift, key = false, false, false
					for _, value in ipairs(keybind) do
						if value == "alt" then
							alt = true
						elseif value == "control" then
							control = true
						elseif value == "shift" then
							shift = true
						else
							key = value
						end
					end
					local keyboardAddress = term.keyboard()
					if
						(alt == not (not keyboard.isAltDown(keyboardAddress))) and
							(control == not (not keyboard.isControlDown(keyboardAddress))) and
							(shift == not (not keyboard.isShiftDown(keyboardAddress))) and
							code == keyboard.keys[key] and
							#keybind > resultWeight
					then
						resultWeight = #keybind
						resultName = command
						result = keyBindHandlers[command]
					end
				end
			end
		end
	end
	return result, resultName
end

-------------------------------------------------------------------------------

local function onKeyDown(char, code)
	local handler = getKeyBindHandler(code)
	if handler then
		handler()
	elseif readonly and code == keyboard.keys.q then
		running = false
	elseif not readonly then
		if not keyboard.isControl(char) then
			insert(unicode.char(char))
		elseif unicode.char(char) == "\t" then
			insert("  ")
		end
	end
end

local function onClipboard(value)
	value = value:gsub("\r\n", "\n")
	local start = 1
	local l = value:find("\n", 1, true)
	if l then
		repeat
			local next_line = string.sub(value, start, l - 1)
			insert(next_line)
			enter()
			start = l + 1
			l = value:find("\n", start, true)
		until not l
	end
	insert(string.sub(value, start))
end

local function onClick(x, y)
	setCursor(x + scrollX, y + scrollY)
end

local function onScroll(direction)
	local cbx, cby = getCursor()
	setCursor(cbx, cby - direction * 12)
end

-------------------------------------------------------------------------------

do
	local f = fs.open(filename, "r")
	if f then
		local data = require("calls").call("split", lineMod(f.readAll()), "\n")
		f.close()

		local x, y, w, h = getArea()
		local chars = 0
		for _, fline in ipairs(data) do
			table.insert(buffer, fline)
			chars = chars + unicode.len(fline)
			if #buffer <= h then
				drawLine(x, y, w, h, #buffer)
			end
		end
		f.close()
		if #buffer == 0 then
			table.insert(buffer, "")
		end
		local format
		if readonly then
			format = [["%s" [readonly] %dL,%dC]]
		else
			format = [["%s" %dL,%dC]]
		end
		setStatus(string.format(format, paths.name(filename), #buffer, chars))
	else
		table.insert(buffer, "")
		setStatus(string.format([["%s" [New File] ]], paths.name(filename)))
	end
	setCursor(1, 1)
end

while running do
	local event, address, arg1, arg2, arg3 = term.pull()
	if address == term.keyboard() or address == term.screen() then
		if event == "key_down" then
			if arg1 == 19 and arg2 == 31 then
				keyBindHandlers["save"]()
			elseif arg1 == 23 and arg2 == 17 then
				keyBindHandlers["close"]()
			end
		end
		local blink = true
		if event == "key_down" then
			onKeyDown(arg1, arg2)
		elseif event == "clipboard" and not readonly then
			onClipboard(arg1)
		elseif event == "touch" or event == "drag" then
			local x, y, w, h = getArea()
			arg1 = arg1 - x + 1
			arg2 = arg2 - y + 1
			if arg1 >= 1 and arg2 >= 1 and arg1 <= w and arg2 <= h then
				onClick(arg1, arg2)
			end
		elseif event == "scroll" then
			onScroll(arg3)
		else
			blink = false
		end
		if blink then
			term.setCursorBlink(true)
		end
	end
end