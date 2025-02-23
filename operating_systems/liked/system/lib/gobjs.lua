local uix = require("uix")
local parser = require("parser")
local unicode = require("unicode")
local graphic = require("graphic")
local gobjs = {}

local colors = uix.colors

-------------------------------- scroll text

gobjs.scrolltext = {}

function gobjs.scrolltext:onCreate(sizeX, sizeY, text)
	self.sizeX = sizeX
	self.sizeY = sizeY
	self.text = text or ""
	self.scroll = 0
	self.w = self.gui.window

	self.bg = colors.white
	self.fg = colors.gray
	self.padding = true
	self.scrollBar = false
end

function gobjs.scrolltext:onEvent(eventData)
	eventData = uix.objEvent(self, eventData)
	if eventData and eventData[1] == "scroll" then
		self:reLines()
		local max = #self.lines - self.sizeY
		if self.padding then
			max = max + 2
		end

		local oldScroll = self.scroll
		self.scroll = self.scroll - eventData[5]
		if self.scroll < 0 then self.scroll = 0 end
		if self.scroll > max then self.scroll = math.max(max, 0) end
		if self.scroll ~= oldScroll then
			self:draw()
		end
	end
end

function gobjs.scrolltext:onDraw()
	self:reLines()
	self.w:fill(self.x, self.y, self.sizeX, self.sizeY, self.bg, 0, " ")
	for i, str in ipairs(self.lines) do
		local linePos = (self.y + (i - 1)) - self.scroll
		local minLinePos = self.y
		local maxLinePos = self.y + self.sizeY
		if self.padding then
			maxLinePos = maxLinePos - 1
			minLinePos = minLinePos + 1
			linePos = linePos + 1
		end
		if linePos >= minLinePos and linePos < maxLinePos then
			local maxSize = self.sizeX
			if self.padding then
				maxSize = maxSize - 2
			end
			str = unicode.sub(str, 1, maxSize)
			
			local linePosX = self.x
			if self.padding then
				linePosX = linePosX + 1
			end
			self.w:set(linePosX, linePos, self.bg, self.fg, str)
		end
	end
end



function gobjs.scrolltext:reLines()
	self.lines = self.lines or parser.split(unicode, self.text, "\n")
end

function gobjs.scrolltext:setText(text)
	self.scroll = 0
	self.text = text
	self.lines = nil
end

-------------------------------- checkbox group

gobjs.checkboxgroup = {}

function gobjs.checkboxgroup:onCreate(sizeX, sizeY, enableScrollbar)
	self.sizeX = sizeX
	self.sizeY = sizeY

	self.bg = colors.white
	self.fg = colors.gray

	self.list = {}
	self.scroll = 0

	self.w = uix.regDrawZone(self, sizeX, sizeY)
	self.enableScrollbar = enableScrollbar
end

function gobjs.checkboxgroup:onDraw()
	self.w:clear(self.bg)
	self.itemsPos = {}
	for i, item in ipairs(self.list) do
		local linePos = i - self.scroll
		if linePos >= 1 and linePos <= self.sizeY then
			self.itemsPos[linePos] = {i, item}
			self:redrawPoint(linePos, item)
		end
	end
end

function gobjs.checkboxgroup:onEvent(eventData)
	eventData = uix.objEvent(self, eventData)
	if eventData then
		if eventData[1] == "scroll" then
			local max = #self.list - self.sizeY
			local oldScroll = self.scroll
			self.scroll = self.scroll - eventData[5]
			if self.scroll < 0 then self.scroll = 0 end
			if self.scroll > max then self.scroll = math.max(max, 0) end
			if self.scroll ~= oldScroll then
				self:draw()
			end
		elseif eventData[1] == "touch" then
			if self.itemsPos then
				local item = self.itemsPos[eventData[4]]
				if item then
					if eventData[3] <= 2 then
						if self.oneSelect and not item[2][2] then
							for i, lstobj in ipairs(self.list) do
								if lstobj[2] then
									lstobj[2] = false
									local linePos = i - self.scroll
									if linePos >= 1 and linePos <= self.sizeY then
										self:redrawPoint(linePos, lstobj)
									end
									if self.onSwitch then
										self:onSwitch(i, lstobj[1], lstobj[2], lstobj, eventData) --index, title, state, usertbl, event
									end
								end
							end
						end
						item[2][2] = not item[2][2]
						self:redrawPoint(eventData[4], item[2])
						if self.onSwitch then
							self:onSwitch(item[1], item[2][1], item[2][2], item[2], eventData) --index, title, state, usertbl, event
						end
						self.lastInteraction = item[2]
					elseif self.onTextClick then
						self:onTextClick(item[1], item[2][1], item[2][2], item[2], eventData)
					end
				end
			end
		end
	end
end

function gobjs.checkboxgroup:redrawPoint(linePos, item)
	local color
	if item[2] then
		color = colors.lime
		if color == self.bg then
			color = colors.green
		end
	else
		color = colors.black
		if color == self.bg then
			color = colors.gray
		end
	end

	self.w:set(1, linePos, self.bg, color, "⠰⠆")
	self.w:set(3, linePos, self.bg, self.fg, item[1])
end

-------------------------------- layout manager

gobjs.manager = {}

function gobjs.manager:onCreate(sizeX, sizeY)
	self.sizeX = sizeX
	self.sizeY = sizeY
	self.screen = self.gui.window.screen
	self.current = nil
end

function gobjs.manager:onDraw()
	if self.current then
		self.current:draw()
	end
end

function gobjs.manager:onEvent(eventData)
	if self.current then
		self.current:uploadEvent(eventData)
	end
end



function gobjs.manager:fullStop()
	if self.current then
		self.current:fullStop()
	end
end

function gobjs.manager:fullStart()
	if self.current then
		self.current:fullStart()
	end
end

function gobjs.manager:select(layout)
	if self.current then
		self.current:fullStop()
	end

	self.current = layout
	if self.current then
		self.current.smartGuiManager = self
		self.current.allowAutoActive = nil
		self.current:fullStart()
		if self.current.onSelect then
			self.current:onSelect()
		end
		self.current:draw()
	end
end

function gobjs.manager:create(bgcolor, style)
	local window = graphic.create(self.screen, self.x, self.y, self.sizeX, self.sizeY)
	local layout = uix.createSimpleLayout(window, bgcolor, style)
	layout.bgWork = false
	layout.allowAutoActive = nil
	if not self.current then
		self:select(layout)
	end
	return layout
end

function gobjs.manager:size()
	return self.sizeX, self.sizeY
end

--------------------------------

gobjs.unloadable = true
return gobjs