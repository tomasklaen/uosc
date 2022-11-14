local Element = require('uosc_shared/elements/Element')

---@class Timeline : Element
local Timeline = class(Element)

function Timeline:new() return Class.new(self) --[[@as Timeline]] end
function Timeline:init()
	Element.init(self, 'timeline')
	self.pressed = false
	self.obstructed = false
	self.size_max = 0
	self.size_min = 0
	self.size_min_override = options.timeline_start_hidden and 0 or nil
	self.font_size = 0
	self.top_border = options.timeline_border

	-- Release any dragging when file gets unloaded
	mp.register_event('end-file', function() self.pressed = false end)
end

function Timeline:get_visibility()
	return Elements.controls and math.max(Elements.controls.proximity, Element.get_visibility(self))
		or Element.get_visibility(self)
end

function Timeline:decide_enabled()
	local previous = self.enabled
	self.enabled = not self.obstructed and state.duration ~= nil and state.duration > 0 and state.time ~= nil
	if self.enabled ~= previous then Elements:trigger('timeline_enabled', self.enabled) end
end

function Timeline:get_effective_size_min()
	return self.size_min_override or self.size_min
end

function Timeline:get_effective_size()
	if Elements.speed and Elements.speed.dragging then return self.size_max end
	local size_min = self:get_effective_size_min()
	return size_min + math.ceil((self.size_max - size_min) * self:get_visibility())
end

function Timeline:get_effective_line_width()
	return state.fullormaxed and options.timeline_line_width_fullscreen or options.timeline_line_width
end

function Timeline:update_dimensions()
	if state.fullormaxed then
		self.size_min = options.timeline_size_min_fullscreen
		self.size_max = options.timeline_size_max_fullscreen
	else
		self.size_min = options.timeline_size_min
		self.size_max = options.timeline_size_max
	end
	self.font_size = math.floor(math.min((self.size_max + 60) * 0.2, self.size_max * 0.96) * options.font_scale)
	self.ax = Elements.window_border.size
	self.ay = display.height - Elements.window_border.size - self.size_max - self.top_border
	self.bx = display.width - Elements.window_border.size
	self.by = display.height - Elements.window_border.size
	self.width = self.bx - self.ax

	-- Disable if not enough space
	local available_space = display.height - Elements.window_border.size * 2
	if Elements.top_bar.enabled then available_space = available_space - Elements.top_bar.size end
	self.obstructed = available_space < self.size_max + 10
	self:decide_enabled()
end

function Timeline:get_time_at_x(x)
	local line_width = (options.timeline_style == 'line' and self:get_effective_line_width() - 1 or 0)
	local time_width = self.width - line_width - 1
	local fax = (time_width) * state.time / state.duration
	local fbx = fax + line_width
	-- time starts 0.5 pixels in
	x = x - self.ax - 0.5
	if x > fbx then x = x - line_width
	elseif x > fax then x = fax end
	local progress = clamp(0, x / time_width, 1)
	return state.duration * progress
end

---@param fast? boolean
function Timeline:set_from_cursor(fast)
	if state.time and state.duration then
		mp.commandv('seek', self:get_time_at_x(cursor.x), fast and 'absolute+keyframes' or 'absolute+exact')
	end
end

function Timeline:on_mbtn_left_down()
	self.pressed = true
	self.pressed_pause = state.pause
	mp.set_property_native('pause', true)
	self:set_from_cursor()
end
function Timeline:on_prop_duration() self:decide_enabled() end
function Timeline:on_prop_time() self:decide_enabled() end
function Timeline:on_prop_border() self:update_dimensions() end
function Timeline:on_prop_fullormaxed() self:update_dimensions() end
function Timeline:on_display() self:update_dimensions() end
function Timeline:on_global_mbtn_left_up()
	if self.pressed then
		mp.set_property_native('pause', self.pressed_pause)
		self.pressed = false
	end
end
function Timeline:on_global_mouse_leave()
	self.pressed = false
end

Timeline.seek_timer = mp.add_timeout(0.05, function() Elements.timeline:set_from_cursor() end)
Timeline.seek_timer:kill()
function Timeline:on_global_mouse_move()
	if self.pressed then
		if self.width / state.duration < 10 then
			self:set_from_cursor(true)
			self.seek_timer:kill()
			self.seek_timer:resume()
		else self:set_from_cursor() end
	end
end
function Timeline:on_wheel_up() mp.commandv('seek', options.timeline_step) end
function Timeline:on_wheel_down() mp.commandv('seek', -options.timeline_step) end

function Timeline:render()
	if self.size_max == 0 then return end

	local size_min = self:get_effective_size_min()
	local size = self:get_effective_size()
	local visibility = self:get_visibility()

	if size < 1 then
		clear_thumbnail()
		return
	end

	local ass = assdraw.ass_new()

	-- Text opacity rapidly drops to 0 just before it starts overflowing, or before it reaches timeline.size_min
	local hide_text_below = math.max(self.font_size * 0.8, size_min * 2)
	local hide_text_ramp = hide_text_below / 2
	local text_opacity = clamp(0, size - hide_text_below, hide_text_ramp) / hide_text_ramp

	local spacing = math.max(math.floor((self.size_max - self.font_size) / 2.5), 4)
	local progress = state.time / state.duration
	local is_line = options.timeline_style == 'line'

	-- Foreground & Background bar coordinates
	local bax, bay, bbx, bby = self.ax, self.by - size - self.top_border, self.bx, self.by
	local fax, fay, fbx, fby = 0, bay + self.top_border, 0, bby
	local fcy = fay + (size / 2)

	local line_width = 0

	if is_line then
		local minimized_fraction = 1 - math.min((size - size_min) / ((self.size_max - size_min) / 8), 1)
		local line_width_max = self:get_effective_line_width()
		local max_min_width_delta = size_min > 0
			and line_width_max - line_width_max * options.timeline_line_width_minimized_scale
			or 0
		line_width = line_width_max - (max_min_width_delta * minimized_fraction)
		fax = bax + (self.width - line_width) * progress
		fbx = fax + line_width
		line_width = line_width - 1
	else
		fax, fbx = bax, bax + self.width * progress
	end

	local foreground_size = fby - fay
	local foreground_coordinates = round(fax) .. ',' .. fay .. ',' .. round(fbx) .. ',' .. fby -- for clipping

	-- time starts 0.5 pixels in
	local time_ax = bax + 0.5
	local time_width = self.width - line_width - 1

	-- time to x: calculates x coordinate so that it never lies inside of the line
	local function t2x(time)
		local x = time_ax + time_width * time / state.duration
		return time <= state.time and x or x + line_width
	end

	-- Background
	ass:new_event()
	ass:pos(0, 0)
	ass:append('{\\rDefault\\an7\\blur0\\bord0\\1c&H' .. bg .. '}')
	ass:opacity(options.timeline_opacity)
	ass:draw_start()
	ass:rect_cw(bax, bay, fax, bby) --left of progress
	ass:rect_cw(fbx, bay, bbx, bby) --right of progress
	ass:rect_cw(fax, bay, fbx, fay) --above progress
	ass:draw_stop()

	-- Progress
	ass:rect(fax, fay, fbx, fby, {opacity = options.timeline_opacity})

	-- Uncached ranges
	local buffered_time = nil
	if state.uncached_ranges then
		local opts = {size = 80, anchor_y = fby}
		local texture_char = visibility > 0 and 'b' or 'a'
		local offset = opts.size / (visibility > 0 and 24 or 28)
		for _, range in ipairs(state.uncached_ranges) do
			if not buffered_time and (range[1] > state.time or range[2] > state.time) then
				buffered_time = range[1] - state.time
			end
			if options.timeline_cache then
				local ax = range[1] < 0.5 and bax or math.floor(t2x(range[1]))
				local bx = range[2] > state.duration - 0.5 and bbx or math.ceil(t2x(range[2]))
				opts.color, opts.opacity, opts.anchor_x = 'ffffff', 0.4 - (0.2 * visibility), bax
				ass:texture(ax, fay, bx, fby, texture_char, opts)
				opts.color, opts.opacity, opts.anchor_x = '000000', 0.6 - (0.2 * visibility), bax + offset
				ass:texture(ax, fay, bx, fby, texture_char, opts)
			end
		end
	end

	-- Custom ranges
	for _, chapter_range in ipairs(state.chapter_ranges) do
		local rax = chapter_range.start < 0.1 and bax or t2x(chapter_range.start)
		local rbx = chapter_range['end'] > state.duration - 0.1 and bbx
			or t2x(math.min(chapter_range['end'], state.duration))
		ass:rect(rax, fay, rbx, fby, {color = chapter_range.color, opacity = chapter_range.opacity})
	end

	-- Chapters
	if (options.timeline_chapters_opacity > 0
		and (#state.chapters > 0 or state.ab_loop_a or state.ab_loop_b)
		) then
		local diamond_radius = foreground_size < 3 and foreground_size or math.max(foreground_size / 10, 3)
		local diamond_border = options.timeline_border and math.max(options.timeline_border, 1) or 1

		if diamond_radius > 0 then
			local function draw_chapter(time)
				local chapter_x = t2x(time)
				local chapter_y = fay - 1
				ass:new_event()
				ass:append(string.format(
					'{\\pos(0,0)\\rDefault\\an7\\blur0\\yshad0.01\\bord%f\\1c&H%s\\3c&H%s\\4c&H%s\\1a&H%X&\\3a&H00&\\4a&H00&}',
					diamond_border, fg, bg, bg, opacity_to_alpha(options.timeline_opacity * options.timeline_chapters_opacity)
				))
				ass:draw_start()
				ass:move_to(chapter_x - diamond_radius, chapter_y)
				ass:line_to(chapter_x, chapter_y - diamond_radius)
				ass:line_to(chapter_x + diamond_radius, chapter_y)
				ass:line_to(chapter_x, chapter_y + diamond_radius)
				ass:draw_stop()
			end

			if state.chapters ~= nil then
				for i, chapter in ipairs(state.chapters) do
					draw_chapter(chapter.time)
				end
			end

			if state.ab_loop_a and state.ab_loop_a > 0 then draw_chapter(state.ab_loop_a) end
			if state.ab_loop_b and state.ab_loop_b > 0 then draw_chapter(state.ab_loop_b) end
		end
	end

	local function draw_timeline_text(x, y, align, text, opts)
		opts.color, opts.border_color = fgt, fg
		opts.clip = '\\clip(' .. foreground_coordinates .. ')'
		ass:txt(x, y, align, text, opts)
		opts.color, opts.border_color = bgt, bg
		opts.clip = '\\iclip(' .. foreground_coordinates .. ')'
		ass:txt(x, y, align, text, opts)
	end

	-- Time values
	if text_opacity > 0 then
		local time_opts = {size = self.font_size, opacity = text_opacity, border = 2}
		-- Upcoming cache time
		if buffered_time and options.buffered_time_threshold > 0 and buffered_time < options.buffered_time_threshold then
			local x, align = fbx + 5, 4
			local cache_opts = {size = self.font_size * 0.8, opacity = text_opacity * 0.6, border = 1}
			local human = round(math.max(buffered_time, 0)) .. 's'
			local width = text_width(human, cache_opts)
			local time_width = text_width('00:00:00', time_opts)
			local min_x, max_x = bax + spacing + 5 + time_width, bbx - spacing - 5 - time_width
			if x < min_x then x = min_x elseif x + width > max_x then x, align = max_x, 6 end
			draw_timeline_text(x, fcy, align, human, cache_opts)
		end

		-- Elapsed time
		if state.time_human then
			draw_timeline_text(bax + spacing, fcy, 4, state.time_human, time_opts)
		end

		-- End time
		if state.duration_or_remaining_time_human then
			draw_timeline_text(bbx - spacing, fcy, 6, state.duration_or_remaining_time_human, time_opts)
		end
	end

	-- Hovered time and chapter
	if (self.proximity_raw == 0 or self.pressed) and not (Elements.speed and Elements.speed.dragging) then
		local hovered_seconds = self:get_time_at_x(cursor.x)

		-- Cursor line
		-- 0.5 to switch when the pixel is half filled in
		local color = ((fax - 0.5) < cursor.x and cursor.x < (fbx + 0.5)) and bg or fg
		local ax, ay, bx, by = cursor.x - 0.5, fay, cursor.x + 0.5, fby
		ass:rect(ax, ay, bx, by, {color = color, opacity = 0.2})
		local tooltip_anchor = {ax = ax, ay = ay, bx = bx, by = by}

		-- Timestamp
		local opts = {size = self.font_size, offset = 4}
		opts.width_overwrite = text_width('00:00:00', opts)
		ass:tooltip(tooltip_anchor, format_time(hovered_seconds), opts)
		tooltip_anchor.ay = tooltip_anchor.ay - self.font_size - 4

		-- Thumbnail
		if not thumbnail.disabled and thumbnail.width ~= 0 and thumbnail.height ~= 0 then
			local scale_x, scale_y = display.scale_x, display.scale_y
			local border, margin_x, margin_y = math.ceil(2 * scale_x), round(10 * scale_x), round(5 * scale_y)
			local thumb_x_margin, thumb_y_margin = border + margin_x, border + margin_y
			local thumb_width, thumb_height = thumbnail.width, thumbnail.height
			local thumb_x = round(clamp(
				thumb_x_margin, cursor.x * scale_x - thumb_width / 2,
				display.width * scale_x - thumb_width - thumb_x_margin
			))
			local thumb_y = round(tooltip_anchor.ay * scale_y - thumb_y_margin - thumb_height)
			local ax, ay = (thumb_x - border) / scale_x, (thumb_y - border) / scale_y
			local bx, by = (thumb_x + thumb_width + border) / scale_x, (thumb_y + thumb_height + border) / scale_y
			thumbnail_state = {updated = true, show=true, x = thumb_x, y = thumb_y, ax = ax, ay = ay, bx = bx, by = by, color = bg, border_color = fg, render = thumbnail_state.render}
			mp.commandv('script-message-to', 'thumbfast', 'thumb', hovered_seconds, "", "", script_name)
			tooltip_anchor.ax, tooltip_anchor.bx, tooltip_anchor.ay = ax, bx, ay
		end

		-- Chapter title
		if #state.chapters > 0 then
			local _, chapter = itable_find(state.chapters, function(c) return hovered_seconds >= c.time end, true)
			if chapter and not chapter.is_end_only then
				ass:tooltip(tooltip_anchor, chapter.title_wrapped, {
					size = self.font_size, offset = 10, responsive = false, bold = true,
					width_overwrite = chapter.title_wrapped_width * self.font_size,
				})
			end
		end
	else
		clear_thumbnail()
	end

	return ass
end

return Timeline
