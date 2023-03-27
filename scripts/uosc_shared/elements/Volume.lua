local Element = require('uosc_shared/elements/Element')

--[[ MuteButton ]]

---@class MuteButton : Element
local MuteButton = class(Element)
---@param props? ElementProps
function MuteButton:new(props) return Class.new(self, 'volume_mute', props) --[[@as MuteButton]] end
function MuteButton:get_visibility() return Elements.volume:get_visibility(self) end
function MuteButton:render()
	local visibility = self:get_visibility()
	if visibility <= 0 then return end
	if self.proximity_raw == 0 then
		cursor.on_primary_down = function() mp.commandv('cycle', 'mute') end
	end
	local ass = assdraw.ass_new()
	local icon_name = state.mute and 'volume_off' or 'volume_up'
	local width = self.bx - self.ax
	ass:icon(self.ax + (width / 2), self.by, width * 0.7, icon_name,
		{border = options.text_border, opacity = options.volume_opacity * visibility, align = 2}
	)
	return ass
end

--[[ VolumeSlider ]]

---@class VolumeSlider : Element
local VolumeSlider = class(Element)
---@param props? ElementProps
function VolumeSlider:new(props) return Class.new(self, props) --[[@as VolumeSlider]] end
function VolumeSlider:init(props)
	Element.init(self, 'volume_slider', props)
	self.pressed = false
	self.nudge_y = 0 -- vertical position where volume overflows 100
	self.nudge_size = 0
	self.draw_nudge = false
	self.spacing = 0
	self.radius = 1
end

function VolumeSlider:get_visibility() return Elements.volume:get_visibility(self) end

function VolumeSlider:set_volume(volume)
	volume = round(volume / options.volume_step) * options.volume_step
	if state.volume == volume then return end
	mp.commandv('set', 'volume', clamp(0, volume, state.volume_max))
end

function VolumeSlider:set_from_cursor()
	local volume_fraction = (self.by - cursor.y - options.volume_border) / (self.by - self.ay - options.volume_border)
	self:set_volume(volume_fraction * state.volume_max)
end

function VolumeSlider:on_coordinates()
	if type(state.volume_max) ~= 'number' or state.volume_max <= 0 then return end
	local width = self.bx - self.ax
	self.nudge_y = self.by - round((self.by - self.ay) * (100 / state.volume_max))
	self.nudge_size = round(width * 0.18)
	self.draw_nudge = self.ay < self.nudge_y
	self.spacing = round(width * 0.2)
	self.radius = math.max(2, (self.bx - self.ax) / 10)
end
function VolumeSlider:on_global_mouse_move()
	if self.pressed then self:set_from_cursor() end
end
function VolumeSlider:handle_wheel_up() self:set_volume(state.volume + options.volume_step) end
function VolumeSlider:handle_wheel_down() self:set_volume(state.volume - options.volume_step) end

function VolumeSlider:render()
	local visibility = self:get_visibility()
	local ax, ay, bx, by = self.ax, self.ay, self.bx, self.by
	local width, height = bx - ax, by - ay

	if width <= 0 or height <= 0 or visibility <= 0 then return end

	if self.proximity_raw == 0 then
		cursor.on_primary_down = function()
			self.pressed = true
			self:set_from_cursor()
			cursor.on_primary_up = function() self.pressed = false end
		end
		cursor.on_wheel_down = function() self:handle_wheel_down() end
		cursor.on_wheel_up = function() self:handle_wheel_up() end
	end
	if self.pressed then cursor.on_primary_up = function()
		self.pressed = false end
	end

	local ass = assdraw.ass_new()
	local nudge_y, nudge_size = self.draw_nudge and self.nudge_y or -INFINITY, self.nudge_size
	local volume_y = self.ay + options.volume_border +
		((height - (options.volume_border * 2)) * (1 - math.min(state.volume / state.volume_max, 1)))

	-- Draws a rectangle with nudge at requested position
	---@param p number Padding from slider edges.
	---@param cy? number A y coordinate where to clip the path from the bottom.
	function create_nudged_path(p, cy)
		cy = cy or ay + p
		local ax, bx, by = ax + p, bx - p, by - p
		local r = math.max(1, self.radius - p)
		local d, rh = r * 2, r / 2
		local nudge_size = ((QUARTER_PI_SIN * (nudge_size - p)) + p) / QUARTER_PI_SIN
		local path = assdraw.ass_new()
		path:move_to(bx - r, by)
		path:line_to(ax + r, by)
		if cy > by - d then
			local subtracted_radius = (d - (cy - (by - d))) / 2
			local xbd = (r - subtracted_radius * 1.35) -- x bezier delta
			path:bezier_curve(ax + xbd, by, ax + xbd, cy, ax + r, cy)
			path:line_to(bx - r, cy)
			path:bezier_curve(bx - xbd, cy, bx - xbd, by, bx - r, by)
		else
			path:bezier_curve(ax + rh, by, ax, by - rh, ax, by - r)
			local nudge_bottom_y = nudge_y + nudge_size

			if cy + rh <= nudge_bottom_y then
				path:line_to(ax, nudge_bottom_y)
				if cy <= nudge_y then
					path:line_to((ax + nudge_size), nudge_y)
					local nudge_top_y = nudge_y - nudge_size
					if cy <= nudge_top_y then
						local r, rh = r, rh
						if cy > nudge_top_y - r then
							r = nudge_top_y - cy
							rh = r / 2
						end
						path:line_to(ax, nudge_top_y)
						path:line_to(ax, cy + r)
						path:bezier_curve(ax, cy + rh, ax + rh, cy, ax + r, cy)
						path:line_to(bx - r, cy)
						path:bezier_curve(bx - rh, cy, bx, cy + rh, bx, cy + r)
						path:line_to(bx, nudge_top_y)
					else
						local triangle_side = cy - nudge_top_y
						path:line_to((ax + triangle_side), cy)
						path:line_to((bx - triangle_side), cy)
					end
					path:line_to((bx - nudge_size), nudge_y)
				else
					local triangle_side = nudge_bottom_y - cy
					path:line_to((ax + triangle_side), cy)
					path:line_to((bx - triangle_side), cy)
				end
				path:line_to(bx, nudge_bottom_y)
			else
				path:line_to(ax, cy + r)
				path:bezier_curve(ax, cy + rh, ax + rh, cy, ax + r, cy)
				path:line_to(bx - r, cy)
				path:bezier_curve(bx - rh, cy, bx, cy + rh, bx, cy + r)
			end
			path:line_to(bx, by - r)
			path:bezier_curve(bx, by - rh, bx - rh, by, bx - r, by)
		end
		return path
	end

	-- BG & FG paths
	local bg_path = create_nudged_path(0)
	local fg_path = create_nudged_path(options.volume_border, volume_y)

	-- Background
	ass:new_event()
	ass:append('{\\rDefault\\an7\\blur0\\bord0\\1c&H' .. bg ..
		'\\iclip(' .. fg_path.scale .. ', ' .. fg_path.text .. ')}')
	ass:opacity(options.volume_opacity, visibility)
	ass:pos(0, 0)
	ass:draw_start()
	ass:append(bg_path.text)
	ass:draw_stop()

	-- Foreground
	ass:new_event()
	ass:append('{\\rDefault\\an7\\blur0\\bord0\\1c&H' .. fg .. '}')
	ass:opacity(options.volume_opacity, visibility)
	ass:pos(0, 0)
	ass:draw_start()
	ass:append(fg_path.text)
	ass:draw_stop()

	-- Current volume value
	local volume_string = tostring(round(state.volume * 10) / 10)
	local font_size = round(((width * 0.6) - (#volume_string * (width / 20))) * options.font_scale)
	if volume_y < self.by - self.spacing then
		ass:txt(self.ax + (width / 2), self.by - self.spacing, 2, volume_string, {
			size = font_size, color = fgt, opacity = visibility,
			clip = '\\clip(' .. fg_path.scale .. ', ' .. fg_path.text .. ')',
		})
	end
	if volume_y > self.by - self.spacing - font_size then
		ass:txt(self.ax + (width / 2), self.by - self.spacing, 2, volume_string, {
			size = font_size, color = bgt, opacity = visibility,
			clip = '\\iclip(' .. fg_path.scale .. ', ' .. fg_path.text .. ')',
		})
	end

	-- Disabled stripes for no audio
	if not state.has_audio then
		local fg_100_path = create_nudged_path(options.volume_border)
		local texture_opts = {
			size = 200, color = 'ffffff', opacity = visibility * 0.1, anchor_x = ax,
			clip = '\\clip(' .. fg_100_path.scale .. ',' .. fg_100_path.text .. ')',
		}
		ass:texture(ax, ay, bx, by, 'a', texture_opts)
		texture_opts.color = '000000'
		texture_opts.anchor_x = ax + texture_opts.size / 28
		ass:texture(ax, ay, bx, by, 'a', texture_opts)
	end

	return ass
end

--[[ Volume ]]

---@class Volume : Element
local Volume = class(Element)

function Volume:new() return Class.new(self) --[[@as Volume]] end
function Volume:init()
	Element.init(self, 'volume')
	self.mute = MuteButton:new({anchor_id = 'volume'})
	self.slider = VolumeSlider:new({anchor_id = 'volume'})
end

function Volume:get_visibility()
	return self.slider.pressed and 1 or Elements.timeline:get_is_hovered() and -1 or Element.get_visibility(self)
end

function Volume:update_dimensions()
	local width = state.fullormaxed and options.volume_size_fullscreen or options.volume_size
	local controls, timeline, top_bar = Elements.controls, Elements.timeline, Elements.top_bar
	local min_y = top_bar.enabled and top_bar.by or 0
	local max_y = (controls and controls.enabled and controls.ay) or (timeline.enabled and timeline.ay)
		or display.height - top_bar.size
	local available_height = max_y - min_y
	local max_height = available_height * 0.8
	local height = round(math.min(width * 8, max_height))
	self.enabled = height > width * 2 -- don't render if too small
	local margin = (width / 2) + Elements.window_border.size
	self.ax = round(options.volume == 'left' and margin or display.width - margin - width)
	self.ay = min_y + round((available_height - height) / 2)
	self.bx = round(self.ax + width)
	self.by = round(self.ay + height)
	self.mute.enabled, self.slider.enabled = self.enabled, self.enabled
	self.mute:set_coordinates(self.ax, self.by - round(width * 0.8), self.bx, self.by)
	self.slider:set_coordinates(self.ax, self.ay, self.bx, self.mute.ay)
end

function Volume:on_display() self:update_dimensions() end
function Volume:on_prop_border() self:update_dimensions() end
function Volume:on_controls_reflow() self:update_dimensions() end

return Volume
