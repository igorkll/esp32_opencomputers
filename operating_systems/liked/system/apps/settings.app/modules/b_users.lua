local graphic = require("graphic")
local gui_container = require("gui_container")
local computer = require("computer")
local gui = require("gui")

local colors = gui_container.colors

------------------------------------

local screen, posX, posY = ...
local gpu = graphic.findGpu(screen)
local rx, ry = gpu.getResolution()

------------------------------------

local selectWindow = graphic.createWindow(screen, posX, posY, rx - (posX - 1), ry - (posY - 1))

------------------------------------

local users = {}

local function draw()
	users = {}

	selectWindow:clear(colors.black)
	selectWindow:set(1, 1, colors.lightGray, colors.black, "     user add     ")
	selectWindow:set(1, 2, colors.lightGray, colors.black, "     auto add     ")
	selectWindow:set(1, 3, colors.black, colors.lightGray, "------------------")
	selectWindow:setCursor(1, 4)
	for i, user in ipairs({computer.users()}) do
		selectWindow:write(user .. "\n", colors.black, colors.green)
		table.insert(users, user)
	end
end

draw()

------------------------------------

return function(eventData)
	local selectWindowEventData = selectWindow:uploadEvent(eventData)

	if selectWindowEventData[1] == "touch" then
		local posY = selectWindowEventData[4] - 3

		if users[posY] then
			if gui.yesno(screen, nil, nil, "remove user \"" .. users[posY] .. "\"?") and selectWindowEventData[3] >= 1 and selectWindowEventData[3] <= 18 then
				computer.removeUser(users[posY])
			end
			draw()
		elseif selectWindowEventData[4] == 1 and selectWindowEventData[3] >= 1 and selectWindowEventData[3] <= 18 then
			local name = gui.input(screen, nil, nil, "user name")
			if name then
				local ok, err = computer.addUser(name)
				if not ok then
					gui.warn(screen, nil, nil, err or "unknown")
				end
			end
			draw()
		elseif selectWindowEventData[4] == 2 and selectWindowEventData[3] >= 1 and selectWindowEventData[3] <= 18 then
			if gui.yesno(screen, nil, nil, "add user \"" .. selectWindowEventData[6] .. "\"?") then
				local ok, err = computer.addUser(selectWindowEventData[6])
				if not ok then
					gui.warn(screen, nil, nil, err or "unknown")
				end
			end
			draw()
		end
	end
end