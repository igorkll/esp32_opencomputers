local graphic = require("graphic")
local colors = require("gui_container").colors
local term = require("term")
local thread = require("thread")

local screen = ...
local rx, ry = graphic.getResolution(screen)
local window = graphic.createWindow(screen, 1, 1, rx, ry)
window:clear(colors.gray)

local term1 = term.create(screen, 2, 2, rx // 3, ry - 2)
term1:clear(colors.black)

local term2 = term.create(screen, rx - (rx // 3), 2, rx // 3, ry - 2)
term2:clear(colors.black)

term1:writeLn("TEST INPUT.")
term2:writeLn("TEST LOG.")

local t = thread.create(function()
while true do
	term1:write("> ")
	term1:writeLn("input: " .. (term1:readLn() or "nil"))
end
end)
t:resume()

while true do
term2:write("an likedbox example. " .. math.round(math.random(0, 9)))
os.sleep(1)
term2:newLine()
end