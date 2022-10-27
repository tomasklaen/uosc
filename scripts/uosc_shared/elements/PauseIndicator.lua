local Element = require('uosc_shared/elements/Element')

---@class PauseIndicator : Element
local PauseIndicator = class(Element)

function PauseIndicator:new() return Class.new(self) --[[@as PauseIndicator]] end
function PauseIndicator:init()
	Element.init(self, 'pause_indicator')
	self.ignores_menu = true
	self.base_icon_opacity = options.pause_indicator == 'flash' and 1 or 0.8
	self.paused = state.pause
	self.type = options.pause_indicator
	self.is_manual = options.pause_indicator == 'manual'
	self.fadeout_requested = false
	self.opacity = 0

	mp.observe_property('pause', 'bool', function(_, paused)
		if Elements.timeline.pressed then return end
		if options.pause_indicator == 'flash' then
			if self.paused == paused then return end
			self:flash()
		elseif options.pause_indicator == 'static' then
			self:decide()
		end
	end)
end

function PauseIndicator:flash()
	if not self.is_manual and self.type ~= 'flash' then return end
	-- can't wait for pause property event listener to set this, because when this is used inside a binding like:
	-- cycle pause; script-binding uosc/flash-pause-indicator
	-- the pause event is not fired fast enough, and indicator starts rendering with old icon
	self.paused = mp.get_property_native('pause')
	if self.is_manual then self.type = 'flash' end
	self.opacity = 1
	self:tween_property('opacity', 1, 0, 0.15)
end

-- decides whether static indicator should be visible or not
function PauseIndicator:decide()
	if not self.is_manual and self.type ~= 'static' then return end
	self.paused = mp.get_property_native('pause') -- see flash() for why this line is necessary
	if self.is_manual then self.type = 'static' end
	self.opacity = self.paused and 1 or 0
	request_render()

	-- Workaround for an mpv race condition bug during pause on windows builds, which causes osd updates to be ignored.
	-- .03 was still loosing renders, .04 was fine, but to be safe I added 10ms more
	mp.add_timeout(.05, function() osd:update() end)
end

function PauseIndicator:render()
	if self.opacity == 0 then return end

	local ass = assdraw.ass_new()
	local is_static = self.type == 'static'

	-- Background fadeout
	if is_static then
		ass:rect(0, 0, display.width, display.height, {color = bg, opacity = self.opacity * 0.3})
	end

	-- Icon
	local size = round(math.min(display.width, display.height) * (is_static and 0.20 or 0.15))
	size = size + size * (1 - self.opacity)

	if self.paused then
		ass:icon(display.width / 2, display.height / 2, size, 'pause',
			{border = 1, opacity = self.base_icon_opacity * self.opacity}
		)
	else
		ass:icon(display.width / 2, display.height / 2, size * 1.2, 'play_arrow',
			{border = 1, opacity = self.base_icon_opacity * self.opacity}
		)
	end

	return ass
end

return PauseIndicator
