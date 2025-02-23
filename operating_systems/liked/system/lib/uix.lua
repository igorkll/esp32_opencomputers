local unicode = require("unicode")
local gui_container = require("gui_container")
local gui = require("gui")
local graphic = require("graphic")
local liked = require("liked")
local thread = require("thread")
local event = require("event")
local image = require("image")
local system = require("system")
local colorslib = require("colors")
local paths = require("paths")
local apps = require("apps")
local lastinfo = require("lastinfo")
local privateReg = require("lregs").private

local colors = gui_container.colors
local uix = {colors = colors}
uix.styles = {
	"round",
	"square"
}

---------------------------------- canvas

local canvasClass = {}

function canvasClass:onCreate(sx, sy, back, fore, char)
	self.back = back or colors.black
	self.fore = fore or colors.white
	self.char = char or " "
	self.sx = sx
	self.sy = sy
end

function canvasClass:onEvent(eventData)
	if self.userEvent then
		eventData = uix.objEvent(self, eventData)
		if eventData then
			self:userEvent(eventData)
		end
	end
end

function canvasClass:onDraw()
	self.drawed = true
	if self.screenshot then
		self.screenshot()
		self.screenshot = nil
	else
		self.gui.window:fill(self.x, self.y, self.sx, self.sy, self.back, self.fore, self.char)
	end
end



function canvasClass:set(x, y, back, fore, text, vertical)
	if vertical then
		if x < 1 or x > self.sx then return end
		while y < 1 do
			y = y + 1
			text = unicode.sub(text, 2, unicode.len(text))
		end
		while y + (unicode.len(text) - 1) > self.sy do
			y = y - 1
			text = unicode.sub(text, 1, unicode.len(text) - 1)
		end
	else
		if y < 1 or y > self.sy then return end
		while x < 1 do
			x = x + 1
			text = unicode.sub(text, 2, unicode.len(text))
		end
		while x + (unicode.len(text) - 1) > self.sx do
			x = x - 1
			text = unicode.sub(text, 1, unicode.len(text) - 1)
		end
	end
	self.gui.window:set(self.x + (x - 1), self.y + (y - 1), back or self.back, fore or self.fore, text, vertical)
end

function canvasClass:fill(x, y, sx, sy, back, fore, text)
	self.gui.window:fill(self.x + (x - 1), self.y + (y - 1), sx, sy, back or self.back, fore or self.fore, text)
end

function canvasClass:centerText(x, y, back, fore, text, vertical)
	local offset = math.round(unicode.len(text) / 2) - 1
	if offset < 0 then offset = 0 end
	local offsetX, offsetY = offset, 0
	if vertical then
		offsetX, offsetY = offsetY, offsetX
	end
	self:set(x - offsetX, y - offsetY, back, fore, text, vertical)
end

function canvasClass:clear(color)
	self:fill(1, 1, self.sx, self.sy, color, 0, " ")
end

function canvasClass:stop()
	if self.drawed then
		local x, y = self.gui.window:toRealPos(self.x, self.y)
		self.screenshot = graphic.screenshot(self.gui.screen, x, y, self.sx, self.sy)
		self.drawed = nil
	end
end

function canvasClass:beforeRedraw()
	if self.drawed then
		local x, y = self.gui.window:toRealPos(self.x, self.y)
		self.screenshot = graphic.screenshot(self.gui.screen, x, y, self.sx, self.sy)
	end
end

---------------------------------- obj class

local objclass = {}

function objclass:destroy()
	if self.onDestroy then
		self:onDestroy()
	end
	
	for i = #self.gui.objs, 1, -1 do
		if self.gui.objs[i] == self then
			table.remove(self.gui.objs, i)
		end
	end
end

function objclass:stop()
	if self.type == "context" then
		self.state = false
		if self.th then
			self.th:kill()
			self.th = nil
		end
	elseif self.type == "button" then
		if not self.toggle then
			if self.state then
				self.state = false
				if self.onDrop then
					self:onDrop()
				end
			end
		end
	elseif self.type == "input" then
		self.read.setDrawLock(true)
	end
end

local function checkZone(self, eventData)
	return eventData[3] >= self.x and eventData[4] >= self.y and eventData[3] < self.x + self.sx and eventData[4] < self.y + self.sy
end

function objclass:uploadEvent(eventData)
	if self.disabled or self.disabledHidden then return end
	local retval
	if self.type == "button" or self.type == "context" then
		if self.toggle then
			if eventData[1] == "touch" and checkZone(self, eventData) then
				self.state = not self.state
				self:draw()
				if self.onSwitch then
					self:onSwitch(eventData[5], eventData[6], eventData)
				end
			end
		else
			if self.state and eventData[1] == "drop" then
				if self.type ~= "context" and not self.autoRelease then
					self.state = false
					self:draw()

					if self.onDropInZone and checkZone(self, eventData) then
						retval = self:onDropInZone(eventData[5], eventData[6], eventData)
					elseif self.onDrop then
						retval = self:onDrop(eventData[5], eventData[6], eventData)
					end
				end
			elseif not self.state and eventData[1] == "touch" and checkZone(self, eventData) then
				if self.type == "context" then
					self.state = true
					self:draw()

					if not self.th then
						self.th = thread.create(function ()
							local x, y = self.gui.window:toRealPos(self.x + 1, self.y + 1)
							local px, py, sx, sy = gui.contextPos(self.gui.window.screen, x, y, gui.contextStrs(self.strs))
							local clear = graphic.screenshot(self.gui.window.screen, px, py, sx + 2, sy + 1)
							local oldControlLock = self.gui.controlLock
							self.gui.controlLock = true
							local _, num = gui.context(self.gui.window.screen, px, py, self.strs, self.actives)
							self.gui.controlLock = oldControlLock
							clear()
							if num and self.funcs[num] then
								self.funcs[num]()
							end

							self.state = false
							self:draw()

							self.th:suspend()
							self.th = nil
						end)
						self.th:resume()
					end
				else
					self.state = true
					self:draw()
					graphic.forceUpdate(self.gui.window.screen)
					if self.autoRelease then
						if self.noDropDraw then
							self.state = false
						else
							os.sleep(0.1)
							self.state = false
							self:draw()
							graphic.forceUpdate(self.gui.window.screen)
						end
					end
					
					if self.onClick then
						retval = self:onClick(eventData[5], eventData[6], eventData)
					end
				end
			end
		end
	elseif self.type == "big_switch" then
		if eventData[1] == "touch" and eventData[3] >= self.x and eventData[3] < self.x + self.sizeX and eventData[4] >= self.y and eventData[4] < self.y + self.sizeY then
			self.state = not self.state
			self:draw()

			if self.onSwitch then
				self:onSwitch(eventData[5], eventData[6], eventData)
			end
		end
	elseif self.type == "switch" then
		local size = self.checkbox and 2 or 6
		if eventData[1] == "touch" and eventData[3] >= self.x and eventData[3] < self.x + size and eventData[4] == self.y then
			self.state = not self.state
			self:draw()

			if self.onSwitch then
				self:onSwitch(eventData[5], eventData[6], eventData)
			end
		end
	elseif self.type == "input" then
		local str = self.read.uploadEvent(eventData)
		if str then
			if self.onTextAccepted then
				self:onTextAccepted(str)
			end

			if str == true and self.onTextCancel then
				self:onTextCancel()
			end

			if type(str) == "string" and self.onTextAcceptedCheck then
				self:onTextAcceptedCheck()
			end
		end

		local text = self.read.getBuffer()
		if text ~= self.oldText then
			self.oldText = text
			if self.registrySave then
				if not privateReg.data.inputs then
					privateReg.data.inputs = {}
				end
				privateReg.data.inputs[self.registrySave] = text
				privateReg.save()
			end
			if self.onTextChanged then
				self:onTextChanged(text)
			end
		end
	elseif self.type == "up" then
		if self.gui.returnLayout then
			local _, py = self.gui.window:toFakePos(1, 1)
			if eventData[1] == "touch" and eventData[3] >= 1 and eventData[3] <= #self.gui.returnTitle and eventData[4] == py then
				if type(self.gui.returnLayout) == "function" then
					self.gui.returnLayout()
				else
					self.gui.returnLayout:select()
				end
			end
		end
	elseif self.type == "seek" then
		local function doSeek(oldValue, isTouch)
			if self.value < 0 then self.value = 0 end
			if self.value > 1 then self.value = 1 end
			if self.onSeek then
				self:onSeek(self.value, oldValue, isTouch)
			end
			self:draw()
		end

		if eventData[1] == "scroll" then
			if self.vertical then
				if self.globalScroll or (eventData[3] == self.x and eventData[4] >= self.y and eventData[4] < self.y + self.size) then
					local oldValue = self.value
					self.value = self.value - (eventData[5] / self.size)
					doSeek(oldValue)
				end
			else
				if self.globalScroll or (eventData[4] == self.y and eventData[3] >= self.x and eventData[3] < self.x + self.size) then
					local oldValue = self.value
					self.value = self.value + (eventData[5] / self.size)
					doSeek(oldValue)
				end
			end
		else
			if self.focus == nil then
				self.focus = false
			end
			if self._focus == nil then
				self._focus = false
			end
			if self.vertical then
				if eventData[1] == "touch" and eventData[3] == self.x and eventData[4] >= self.y and eventData[4] < self.y + self.size then
					self.focus = true
				elseif eventData[1] == "drop" or eventData[1] == "touch" then
					self.focus = false
				end
			else
				if eventData[1] == "touch" and eventData[4] == self.y and eventData[3] >= self.x and eventData[3] < self.x + self.size then
					self.focus = true
				elseif eventData[1] == "drop" or eventData[1] == "touch" then
					self.focus = false
				end
			end
			if (eventData[1] == "touch" or eventData[1] == "drag") and self.focus then
				local oldValue = self.value
				if self.vertical then
					self.value = (eventData[4] - self.y) / (self.size - 1)
				else
					self.value = (eventData[3] - self.x) / (self.size - 1)
				end
				doSeek(oldValue, true)
			end
			if self.focus ~= self._focus then
				if self.onTouch then
					self:onTouch(self.focus)
				end
				self._focus = self.focus
			end
		end
	end
	return retval
end

function objclass:draw()
	if self.hidden or self.disabledHidden then return end
	if self.gui.smartGuiManager and self.gui ~= self.gui.smartGuiManager.current then
		return
	end

	local style = self.style or self.gui.style
	if self.type == "label" or self.type == "button" or self.type == "context" then
		local back, fore = self.back, self.fore
		if self.state then
			back, fore = self.back2 or back, self.fore2 or fore
		end

		local x, y, sx, sy = self.x, self.y, self.sx, self.sy
		
		local maxtextsize = self.sx
		local isRound = self.sy == 1 and style == "round"
		if isRound then
			maxtextsize = maxtextsize - 2
			local _, _, bg = self.gui.window:get(x, y)
			self.gui.window:fill(x + 1, y, sx - 2, sy, back, 0, " ")
			self.gui.window:set(x, y, bg, back, "◖")
			self.gui.window:set(x + (sx - 1), y, bg, back, "◗")
		else
			self.gui.window:fill(x, y, sx, sy, back, 0, " ")
		end

		if self.text then
			local dtext = self.text
			local dlen = unicode.len(self.text)
			if self.alignment == "right" then
				if dlen > maxtextsize then
					dtext = unicode.sub(dtext, 1 + (dlen - maxtextsize), dlen)
				end
			else
				if dlen > maxtextsize then
					dtext = unicode.sub(dtext, 1, maxtextsize)
				end
			end
			dlen = unicode.len(dtext)

			local tx
			local ty = y + (math.round(sy / 2) - 1)
			if self.alignment == "left" then
				tx = x
				if isRound then
					tx = tx + 1
				end
			elseif self.alignment == "right" then
				tx = (x + sx) - dlen
				if isRound then
					tx = tx - 1
				end
			else
				tx = (x + math.round(sx / 2)) - math.round(dlen / 2)
			end

			self.gui.window:set(tx, ty, back, fore, dtext)
		end
	elseif self.type == "switch" then
		local bg = self.state and self.enableColor or self.disableColor
		local _, _, fg = self.gui.window:get(self.x, self.y)

		if self.checkbox then
			if style == "round" then
				self.gui.window:set(self.x, self.y, self.pointerColor, bg, "◖◗")
			else
				self.gui.window:set(self.x, self.y, self.pointerColor, bg, "⠰⠆")
			end
		else
			if style == "round" then
				self.gui.window:set(self.x, self.y, fg, bg, "◖████◗")
				if self.state then
					self.gui.window:set(self.x + 3, self.y, bg, self.pointerColor, "◖█")
					self.gui.window:set(self.x + 5, self.y, fg, self.pointerColor, "◗")
				else
					self.gui.window:set(self.x, self.y, fg, self.pointerColor, "◖")
					self.gui.window:set(self.x + 1, self.y, bg, self.pointerColor, "█◗")
				end
			else
				self.gui.window:set(self.x, self.y, fg, bg, "██████")
				if self.state then
					self.gui.window:set(self.x + 3, self.y, bg, self.pointerColor, "███")
				else
					self.gui.window:set(self.x, self.y, fg, self.pointerColor, "███")
				end
			end
		end
	elseif self.type == "big_switch" then
		self.gui.window:fill(self.x, self.y, self.sizeX, self.sizeY, self.color, 0, " ")
		local x, y = self.gui.window:toRealPos(self.x, self.y)
		image.draw(self.gui.window.screen, self.state and "/system/images/switch_on.t2p" or "/system/images/switch_off.t2p", x, y, true)
	elseif self.type == "text" then
		if self.text then
			local _, _, bg = self.gui.window:get(self.x, self.y)
			if self.autoLn then
				local maxPart
				if self.autoLn == true then
					maxPart = self.gui.window.sizeX - self.gui.window.x
				else
					maxPart = self.autoLn
				end
				for i, textpart in ipairs(require("parser").toLinesLn(self.text, maxPart)) do
					self.gui.window:set(self.x, self.y + (i - 1), bg, self.color, textpart)
				end
			else
				self.gui.window:set(self.x, self.y, bg, self.color, self.text)
			end
		end
	elseif self.type == "input" then
		local _, _, bg = self.gui.window:get(self.x, self.y)
		if style == "round" then
			self.gui.window:set(self.x, self.y, bg, self.back, "◖")
			self.gui.window:set(self.x + (self.sx - 1), self.y, bg, self.back, "◗")
		end
		
		self.read.setDrawLock(false)
		self.read.redraw()
	elseif self.type == "seek" then
		local _, _, bg = self.gui.window:get(self.x, self.y)
		local dotpos = math.round((self.size - 1) * self.value)

		if self.vertical then
			self.gui.window:fill(self.x, self.y, 1, dotpos, bg, self.fillColor, "┃")
			self.gui.window:fill(self.x, self.y + dotpos, 1, self.size - dotpos, bg, self.color, "┃")
			if style == "round" then
				self.gui.window:set(self.x, self.y + dotpos, bg, self.dotcolor, "●")
			else
				self.gui.window:set(self.x, self.y + dotpos, bg, self.dotcolor, "█")
			end
		else
			self.gui.window:fill(self.x, self.y, dotpos, 1, bg, self.fillColor, gui_container.chars.wideSplitLine)
			self.gui.window:fill(self.x + dotpos, self.y, self.size - dotpos, 1, bg, self.color, gui_container.chars.wideSplitLine)
			if style == "round" then
				if dotpos >= self.size - 1 then dotpos = dotpos - 1 end
				self.gui.window:set(self.x + dotpos, self.y, bg, self.dotcolor, "◖◗")
			else
				self.gui.window:set(self.x + dotpos, self.y, bg, self.dotcolor, "█")
			end
		end
	elseif self.type == "up" then
		liked.drawFullUpBar(self.gui.window.screen, (self.gui.returnLayout and string.rep(" ", #self.gui.returnTitle) or "") .. self.title, self.withoutFill, self.bgcolor, self.wide, true)
		if self.gui.returnLayout then
			local px, py = self.gui.window:toFakePos(1, 1)
			self.gui.window:set(px, py, self.gui.returnColor, colors.white, self.gui.returnTitle)
		end
		liked.upBarShadow(self.gui.window.screen)
	elseif self.type == "plane" then
		self.gui.window:fill(self.x, self.y, self.sx, self.sy, self.color, 0, " ")
	elseif self.type == "image" then
		local x, y = self.gui.window:toRealPos(self.x, self.y)
		image.draw(self.gui.window.screen, self.path, x, y, self.wallpaperMode, self.forceFullColor, self.lightMul, self.imagePaletteUsed, self.blackListedColor, self.newColors)
	elseif self.type == "drawer" then
		self:func(self.gui.window:toRealPos(self.x, self.y))
	elseif self.type == "progress" then
		local _, _, bg = self.gui.window:get(self.x, self.y)
		local pos = math.round(math.map(math.clamp(self.value, 0, 1), 0, 1, 0, self.sx))
		self.gui.window:fill(self.x + pos, self.y, self.sx - pos, 1, bg, self.back, gui_container.chars.splitLine)
		self.gui.window:fill(self.x, self.y, pos, 1, bg, self.fore, gui_container.chars.wideSplitLine)
	end

	if self.postDraw then
		self:postDraw()
	end
end

---------------------------------- base custom class

local baseCustom = {}
baseCustom.destroy = objclass.destroy

function baseCustom:uploadEvent(eventData)
	if self.disabled or self.disabledHidden then return end
	if self.onEvent then
		self:onEvent(eventData)
	end
end

function baseCustom:draw()
	if self.hidden or self.disabledHidden then return end
	if self.onDraw then
		self:onDraw()
	end
end

function baseCustom:stop()
	if self.onStop then
		self:onStop()
	end
end

---------------------------------- layout objects

function uix:createUpBar(title, withoutFill, bgcolor) --working only in fullscreen ui
	local obj = setmetatable({gui = self, type = "up"}, {__index = objclass})
	obj.title = title
	obj.withoutFill = withoutFill
	obj.bgcolor = bgcolor
	obj.wide = true

	local px, py = self.window:toFakePos(self.window.sizeX, 1)
	obj.close = self:createButton(px - 2, py, 3, 1)
	obj.close.hidden = true

	obj.timer = thread.timer(10, function ()
		if self.active then
			obj:draw()
		end
	end, math.huge)

	local destroy = obj.destroy
	function obj:destroy()
		event.cancel(obj.timer)
		destroy(obj)
		obj.close:destroy()
	end

	table.insert(self.objs, obj)
	return obj
end

function uix:createUp(title, withoutFill, bgcolor)
	local upbar = self:createUpBar(title, withoutFill, bgcolor)

	local function onExit()
		if self.smartGuiManager and self.smartGuiManager.onExit then
			self.smartGuiManager:onExit()
		else
			if self.smartGuiManager then
				self.smartGuiManager.exitFlag = true
			else
				os.exit()
			end
			event.stub()
		end
	end

	--liked.regExit(self.window.screen, onExit)
	upbar.close.onClick = onExit
	return upbar
end
uix.createAutoUpBar = uix.createUp --legacy

function uix:createLabel(x, y, sx, sy, back, fore, text)
	local obj = setmetatable({gui = self, type = "label"}, {__index = objclass})
	obj.x = x
	obj.y = y
	obj.sx = sx
	obj.sy = sy
	obj.text = text
	uix.doColor(obj, back, fore)
	obj.alignment = "center"
	obj.clamp = true

	table.insert(self.objs, obj)
	return obj
end

function uix:createButton(x, y, sx, sy, back, fore, text, autoRelease)
	local obj = setmetatable({gui = self, type = "button"}, {__index = objclass})
	obj.x = x
	obj.y = y
	obj.sx = sx or (unicode.len(text) + 2)
	obj.sy = sy
	obj.text = text
	obj.state = false
	obj.autoRelease = not not autoRelease
	uix.doColor(obj, back, fore)
	obj.back2 = obj.fore
	obj.fore2 = obj.back
	obj.alignment = "center"
	obj.clamp = true
	obj.toggle = false

	table.insert(self.objs, obj)
	return obj
end

function uix:createSwitch(x, y, state, enableColor, disableColor, pointerColor)
	local obj = setmetatable({gui = self, type = "switch"}, {__index = objclass})
	obj.x = x
	obj.y = y
	obj.state = not not state
	obj.enableColor = enableColor or colors.lime
	obj.disableColor = disableColor or colors.gray
	obj.pointerColor = pointerColor or colors.white

	table.insert(self.objs, obj)
	return obj
end

function uix:createCheckbox(...)
	local obj = self:createSwitch(...)
	obj.checkbox = true
	return obj
end

function uix:createBigSwitch(x, y, state, color)
	local obj = setmetatable({gui = self, type = "big_switch"}, {__index = objclass})
	obj.x = x
	obj.y = y
	obj.sizeX = 16
	obj.sizeY = 16
	obj.color = color or colors.gray
	obj.state = not not state

	table.insert(self.objs, obj)
	return obj
end

function uix:createText(x, y, color, text, autoLn)
	local obj = setmetatable({gui = self, type = "text"}, {__index = objclass})
	obj.x = x
	obj.y = y
	obj.color = color or colors.white
	obj.text = text
	if type(autoLn) == "number" then
		obj.autoLn = autoLn
	else
		obj.autoLn = not not autoLn
	end

	table.insert(self.objs, obj)
	return obj
end

function uix:createVText(x, y, color, text)
	return self:createText(x - (unicode.len(text) // 2), y, color, text)
end

function uix:createInput(x, y, sx, back, fore, testHidden, default, syntax, maxlen, preStr, titleColor, title, registrySave)
	local obj = setmetatable({gui = self, type = "input"}, {__index = objclass})
	obj.x = x
	obj.y = y
	obj.sx = sx
	obj.testHidden = testHidden
	obj.default = default
	obj.syntax = syntax
	obj.titleColor = titleColor or colors.lightGray
	obj.title = title
	obj.registrySave = registrySave
	uix.doColor(obj, back, fore)

	if self.style == "round" then
		obj.read = self.window:readNoDraw(x + 1, y, sx - 2, obj.back, obj.fore, preStr, testHidden, default, true, syntax)
	else
		obj.read = self.window:readNoDraw(x, y, sx, obj.back, obj.fore, preStr, testHidden, default, true, syntax)
	end

	if registrySave and privateReg.data.inputs then
		obj.read.setBuffer(privateReg.data.inputs[registrySave] or "")
	end
	
	obj.oldText = obj.read.getBuffer()
	if maxlen then
		obj.read.setMaxStringLen(maxlen)
	end

	if obj.title then
		obj.read.setTitle(obj.title, obj.titleColor)
	end

	table.insert(self.objs, obj)
	return obj
end

function uix:createSeek(x, y, size, color, fillColor, dotcolor, value, vertical, globalScroll)
	local obj = setmetatable({gui = self, type = "seek"}, {__index = objclass})
	obj.x = x
	obj.y = y
	obj.size = size
	obj.color = color or colors.lightGray
	obj.fillColor = fillColor or colors.lime
	obj.dotcolor = dotcolor or colors.white
	obj.value = value or 0
	obj.vertical = not not vertical
	obj.globalScroll = not not globalScroll

	table.insert(self.objs, obj)
	return obj
end

function uix:createPlane(x, y, sx, sy, color)
	local obj = setmetatable({gui = self, type = "plane"}, {__index = objclass})
	obj.x = x
	obj.y = y
	obj.sx = sx
	obj.sy = sy
	obj.color = color or colors.gray

	table.insert(self.objs, obj)
	return obj
end

function uix:createContext(x, y, sx, sy, back, fore, text, strs, funcs, actives)
	local obj = setmetatable({gui = self, type = "context"}, {__index = objclass})
	obj.x = x
	obj.y = y
	obj.sx = sx
	obj.sy = sy
	obj.back = back or colors.white
	obj.fore = fore or colors.gray
	obj.back2 = obj.fore
	obj.fore2 = obj.back
	obj.text = text
	obj.state = false
	obj.alignment = "center"
	obj.clamp = true

	obj.strs = strs or {}
	obj.funcs = funcs or {}
	obj.actives = actives

	if not obj.actives then
		obj.actives = {}
		for i in ipairs(obj.strs) do
			obj.actives[i] = true
		end
	end

	table.insert(self.objs, obj)
	return obj
end

function uix:createImage(x, y, path, wallpaperMode, forceFullColor)
	local obj = setmetatable({gui = self, type = "image"}, {__index = objclass})
	obj.x = x
	obj.y = y
	obj.path = system.getResourcePath(path)
	obj.wallpaperMode = not not wallpaperMode
	obj.forceFullColor = not not forceFullColor
	obj.blackListedColor = nil
	obj.newColors = nil
	obj.lightMul = nil
	obj.imagePaletteUsed = nil

	table.insert(self.objs, obj)
	return obj
end

function uix:createDrawer(x, y, func)
	local obj = setmetatable({gui = self, type = "drawer"}, {__index = objclass})
	obj.x = x
	obj.y = y
	obj.func = func

	table.insert(self.objs, obj)
	return obj
end

function uix:createProgress(x, y, sx, fore, back, value)
	local obj = setmetatable({gui = self, type = "progress"}, {__index = objclass})
	obj.x = x
	obj.y = y
	obj.sx = sx
	obj.fore = fore or colors.lime
	obj.back = back or colors.blue
	obj.value = value or 0

	table.insert(self.objs, obj)
	return obj
end

local function makeMT(cls)
	local mt = getmetatable(cls)
	if mt then
		mt.__index = baseCustom
	else
		setmetatable(cls, {__index = baseCustom})
	end
	return cls
end

function uix:createCustom(x, y, cls, ...)
	local obj = setmetatable({}, {__index = makeMT(cls)})
	obj.destroy = objclass.destroy
	obj.gui = self
	obj.window = self.window
	obj.x = x
	obj.y = y
	obj.args = {...}

	if obj.onCreate then
		obj:onCreate(...)
	end

	table.insert(self.objs, obj)
	return obj
end

function uix:createCanvas(x, y, sx, sy, back, fore, char)
	return self:createCustom(x, y, canvasClass, sx, sy, back, fore, char)
end

function uix:createColorpic(x, y, sx, sy, text, color, full)
	local button = self:createButton(x, y, sx, sy, nil, nil, text, true)

	local function updateColor()
		if color == colors.black then
			color = colors.gray
		end
		
		button.back = color
		button.fore = color == colors.white and colors.black or colors.white
		button.back2 = button.fore
		button.fore2 = button.back
	end
	updateColor()

	function button:setColor(newcolor)
		color = newcolor
		updateColor()
	end

	function button:getColor()
		return color
	end

	local screen = self.screen
	function button:onClick()
		self.gui:fullStop()
		local fcolor, fout
		local clear = gui.saveBigZone(screen)

		if full then
			fout = gui.selectfullcolor(screen, nil, nil, text)
			fcolor = fout
		else
			fout = gui.selectcolor(screen, nil, nil, text)
			if fout and colorslib[fout] and colors[colorslib[fout]] then
				fcolor = colors[colorslib[fout]]
			end
		end
		clear()
		self.gui:fullStart()

		if fcolor then
			self:setColor(fcolor)
			button:draw()
		end

		if fout and self.onColor then
			self:onColor(fout, fcolor)
		end
	end

	return button
end

function uix:center(offsetX, offsetY, sizeX, sizeY, ...)
	local x, y = math.round((self.window.sizeX / 2) - (sizeX / 2)) + offsetX + 1, math.round((self.window.sizeY / 2) - (sizeY / 2)) + offsetY + 1
	return x, y, sizeX, sizeY, ...
end

function uix:centerOneSize(offsetX, offsetY, sizeX, ...)
	local x, y = math.round((self.window.sizeX / 2) - (sizeX / 2)) + offsetX + 1, math.round(self.window.sizeY / 2) + offsetY + 1
	return x, y, sizeX, ...
end

function uix:customCenter(offsetX, offsetY, cls, sizeX, sizeY, ...)
	local x, y = math.round((self.window.sizeX / 2) - (sizeX / 2)) + offsetX + 1, math.round((self.window.sizeY / 2) - (sizeY / 2)) + offsetY + 1
	return x, y, cls, sizeX, sizeY, ...
end

------------------------------------ layout api

function uix:setReturnLayout(returnLayout, color, char)
	self.returnLayout = returnLayout
	self.returnColor = color or colors.red
	self.returnTitle = char or " < "
end

function uix:timer(time, callback, count)
	return thread.timer(time, function (...)
		if not self.bgWork then return end
		return callback(...)
	end, count)
end

function uix:listen(eventType, callback)
	return thread.listen(eventType, function (...)
		if not self.bgWork then return end
		return callback(...)
	end)
end

function uix:thread(func, ...)
	local th = thread.create(func, ...)
	if th then
		table.insert(self.threads, th)
		return th
	end
end

function uix:uploadEvent(eventData)
	if self.controlLock or not self.active then return end

	if not eventData.windowEventData then
		eventData = self.window:uploadEvent(eventData)
	end

	if eventData and table.len(eventData) > 0 then
		if self.onEvent then
			self:onEvent(eventData)
		end

		for _, obj in ipairs(self.objs) do
			if obj.uploadEvent and obj:uploadEvent(eventData) then
				break
			end
		end
	end

	return eventData
end

function uix:forceDraw()
	for _, obj in ipairs(self.objs) do
		if obj.draw and obj.type == "up" then
			obj:draw()
		end
	end

	for _, obj in ipairs(self.objs) do
		if obj.beforeRedraw then
			obj:beforeRedraw()
		end
	end

	if self.bgcolor then
		self.window:clear(self.bgcolor)
	end

	if self.onRedraw then
		self:onRedraw()
	end

	for _, obj in ipairs(self.objs) do
		if obj.draw then
			obj:draw()
		end
	end
end

function uix:draw()
	if self.allowAutoActive then
		self.allowAutoActive = nil
		self.active = true
	end

	if not self.active then
		return
	end

	self:forceDraw()
end

function uix:stop()
	for _, obj in ipairs(self.objs) do
		if obj.stop then
			obj:stop()
		end
	end
end

function uix:fullStop()
	self.active = false
	self.bgWork = false
	self:stop()
	for _, th in ipairs(self.threads) do
		th:suspend()
	end
end

function uix:fullStart()
	self.active = true
	self.bgWork = true
	for _, th in ipairs(self.threads) do
		th:resume()
	end
	for _, obj in ipairs(self.objs) do
		if obj.type == "input" then
			obj.read.setDrawLock(false)
		end
	end
	if self.onFullStart then
		self.onFullStart()
	end
end

function uix:select(...)
	if self.smartGuiManager then
		self.smartGuiManager:select(self, ...)
	end
end

---------------------------------- uix methods

function uix.getSysImgPath(name)
	return paths.concat("/system/images", name .. ".t2p")
end

function uix.objEvent(self, eventData)
	if eventData and (eventData[1] == "touch" or eventData[1] == "drop" or eventData[1] == "drag" or eventData[1] == "scroll") then
		if eventData[3] >= self.x and eventData[4] >= self.y and eventData[3] < self.x + (self.sizeX or self.sx) and eventData[4] < self.y + (self.sizeY or self.sy) then
			eventData[3] = (eventData[3] - self.x) + 1
			eventData[4] = (eventData[4] - self.y) + 1

			return eventData
		end
	end
end

function uix.regDrawZone(self, sizeX, sizeY)
	return graphic.createWindow(self.gui.screen, self.gui.window.x + (self.x - 1), self.gui.window.y + (self.y - 1), sizeX, sizeY)
end

function uix.updateDrawZone(self)
	self.w.x = self.gui.window.x + (self.x - 1)
	self.w.y = self.gui.window.y + (self.y - 1)
end

function uix.doColor(obj, back, fore)
	obj.back = back or colors.white
	obj.fore = fore
	if not obj.fore then
		if back then
			if back == colors.white then
				obj.fore = colors.black
			else
				obj.fore = colors.white
			end
		else
			obj.fore = colors.gray
		end
	end
end

function uix.create(window, bgcolor, style)
	local guiobj = setmetatable({}, {__index = uix})
	guiobj.window = window
	guiobj.screen = window.screen
	guiobj.style = style or "round"
	guiobj.objs = {}
	guiobj.selected = false
	guiobj.bgcolor = bgcolor
	guiobj.controlLock = false
	guiobj.active = false
	guiobj.bgWork = true
	guiobj.allowAutoActive = true
	guiobj.sizeX = window.sizeX
	guiobj.sizeY = window.sizeY
	guiobj.threads = {}

	return guiobj
end

function uix.createLayout(screen, title, bgcolor, style)
	local window = screen
	if type(screen) == "string" then
		local rx, ry = graphic.getResolution(screen)
		window = graphic.createWindow(screen, 1, 2, rx, ry - 1)
	else
		window.y = window.y + 1
		window.sizeY = window.sizeY - 1
	end
	window.outsideEvents = true

	local layout = uix.create(window, bgcolor or colors.black, style)
	layout:createUp(title or liked.selfApplicationName())
	return layout
end

function uix.createSimpleLayout(screen, bgcolor, style)
	local window = screen
	if type(screen) == "string" then
		local rx, ry = graphic.getResolution(screen)
		window = graphic.createWindow(screen, 1, 1, rx, ry)
	end
	return uix.create(window, bgcolor or colors.black, style)
end

---------------------------------- legacy manager

function uix.createAuto(screen, title, bgcolor, style) --legacy
	local rx, ry = graphic.getResolution(screen)
	local window = graphic.createWindow(screen, 1, 1, rx, ry)

	local layout = uix.create(window, bgcolor or colors.black, style)
	layout:createUp(title)
	return layout
end

function uix.loop(guimanager, layout, func) --legacy manager
	function guimanager.select(newLayout)
		if layout then
			layout.active = false
			layout:stop()
		end
		layout = newLayout
		if layout then
			layout.active = true
		end
		layout:draw()
	end

	layout:draw()
	while true do
		local eventData = {event.pull()}
		layout:uploadEvent(eventData)
		if func then
			func(eventData)
		end
	end
end

---------------------------------- manager

local manager = {}

function manager:fullStop()
	if self.current then
		self.current:fullStop()
	end
end

function manager:fullStart()
	if self.current then
		self.current:fullStart()
	end
end

function manager:execute(...)
	self:fullStop()
	local result = {apps.execute(...)}
	self:fullStart()
	self:draw()
	return table.unpack(result)
end

function manager:func(func, ...)
	self:fullStop()
	local result = {func(...)}
	self:fullStart()
	self:draw()
	return table.unpack(result)
end

function manager:mwindow(screen, func, ...)
	local clear = gui.saveZone(screen)
	self:fullStop()
	local result = {func(...)}
	self:fullStart()
	clear()
	return table.unpack(result)
end

function manager:select(layout, ...)
	if self.current then
		self.current.selected = false
		if self.current.onUnselect then
			self.current:onUnselect()
		end
		self.current:fullStop()
	end

	self.current = layout
	if self.current then
		self.current.selected = true
		self.current.smartGuiManager = self
		self.current.allowAutoActive = nil
		self.current:fullStart()
		if self.current.onSelect then
			if not self.current:onSelect(...) then
				self.current:draw()
			end
		else
			self.current:draw()
		end
	end
end

function manager:setExit_ctrlW()
	self.exit_ctrlW = true
end

function manager:setExit_enter()
	self.exit_enter = true
end

local function keyboardCheck(self, eventData)
	return table.exists(lastinfo.keyboards[self.screen], eventData[2])
end

function manager:loop(timeout)
	if self.firstLayout and not self.current then
		self:select(self.firstLayout)
	end

	while true do
		local eventData = {event.pull(timeout)}
		local windowEventData
		if self.current and not self.stopUpload then
			windowEventData = self.current:uploadEvent(eventData)
		end

		if self.onEvent then
			self:onEvent(eventData, windowEventData)
		end

		local keybinds = self.current.keybinds
		if self.exit_ctrlW and eventData[1] == "close" then
			break
		elseif self.exit_enter and eventData[1] == "key_down" and keyboardCheck(self, eventData) and eventData[3] == 13 and eventData[4] == 28 then
			break
		elseif self.exitFlag then
			break
		elseif self.current and keybinds and (eventData[1] == "key_down" or eventData[1] == "key_up") and keyboardCheck(self, eventData) then
			local inputFromLine = false
			for i, obj in ipairs(self.current.objs) do
				if obj.type == "input" and obj.read.getAllowUse() then
					inputFromLine = true
					break
				end
			end

			if not inputFromLine then
				local binds = keybinds[eventData[4]]
				if binds then
					for i, bind in ipairs(binds) do
						local obj = bind[1]
						local l = bind[2] or {}
						obj:uploadEvent({eventData[1] == "key_down" and "touch" or "drop",
							obj.gui.screen,
							obj.x + (l[1] or 0),
							obj.y + (l[2] or 0),
							l[3] or 0,
							l[4] or eventData[5]
						})
					end
				end
			end
		end
	end
end

function manager:bind(key, ...)
	for _, obj in ipairs({...}) do
		local layout = obj.gui
		if not layout.keybinds then
			layout.keybinds = {}
		end
		if not layout.keybinds[key] then
			layout.keybinds[key] = {}
		end
		table.insert(layout.keybinds[key], {obj})
	end
end

local function doLayout(self, layout)
	layout.bgWork = false
	layout.allowAutoActive = nil
	layout.smartGuiManager = self
	if not self.firstLayout then self.firstLayout = layout end
	return layout
end

function manager:create(title, bgcolor, style)
	return doLayout(self, uix.createLayout(self.window or self.screen, title, bgcolor, style))
end

function manager:simpleCreate(bgcolor, style)
	return doLayout(self, uix.createSimpleLayout(self.window or self.screen, bgcolor, style))
end

function manager:createCustom(window, bgcolor, style)
	return doLayout(self, uix.createSimpleLayout(window, bgcolor, style))
end

function manager:size()
	return graphic.getResolution(self.screen)
end

function manager:zoneSize()
	if self.current then
		return self.current.window.sizeX, self.current.window.sizeY
	else
		local x, y = graphic.getResolution(self.screen)
		return x, y - 1
	end
end

function manager:draw()
	if self.current then
		self.current:draw()
	end
end

function manager:forceDraw()
	if self.current then
		self.current:forceDraw()
	end
end

function uix.manager(screen)
	return setmetatable({screen = screen}, {__index = manager})
end

----------------------------------

uix.unloadable = true
return uix