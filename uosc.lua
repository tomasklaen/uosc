--[[

uosc 1.4.0 | https://github.com/darsain/uosc

Minimalistic proximity based UI for MPV player.

uosc replaces the default osc UI, so that has to be disabled first.
Place these options into your `mpv.conf` file:

```
osc=no     # required so that the 2 UIs don't fight each other
border=no  # if you disable window border, uosc will draw
           # its own pretty window controls (minimize, maximize, close)
```

Options go in `script-opts/uosc.conf`. Defaults:

```
# timeline size when fully retracted, 0 will hide it completely
timeline_size_min=1
# timeline size when fully expanded, in pixels, 0 to disable
timeline_size_max=40
# same as ^ but when in fullscreen
timeline_size_min_fullscreen=0
timeline_size_max_fullscreen=60
# timeline opacity
timeline_opacity=0.8
# adds a top border of background color to help visually separate elapsed bar
# from video of similar color
# in no border windowed mode bottom border is added as well to separate from
# whatever is behind the current window
# this might be unwanted if you are using unique/rare colors with low overlap
# chance, so you can disable it by setting to 0
timeline_border=1

# where to display volume controls, set to empty to disable
volume=right
# volume control horizontal size
volume_size=40
# same as ^ but when in fullscreen
volume_size_fullscreen=40
# volume controls opacity
volume_opacity=0.8
# thin border around volume slider
volume_border=1
# when clicking or dragging volume slider, volume will snap only to increments
# of this value
volume_snap_to=1

# timeline chapters indicator style: dots, lines, lines-top, lines-bottom
# set to empty to disable
chapters=dots
# timeline chapters indicator opacity
chapters_opacity=0.3

# proximity below which elements are fully faded in/expanded
proximity_min=40
# proximity above which elements are fully faded out/retracted
proximity_max=120
# BBGGRR - BLUE GREEN RED hex codes
color_foreground=ffffff
color_foreground_text=000000
color_background=000000
color_background_text=ffffff
# hide proximity based elements when mpv autohides the cursor
autohide=no
# when properties like volume or video position are changed externally
# (e.g. hotkeys) this will flash the appropriate element for this amount of
# time, set to 0 to disable
flash_duration=300
# display window title (filename) in top window controls bar in no-border mode
title=no

# `chapter_ranges` lets you transform chapter indicators into range indicators
# with custom color and opacity by creating a chapter range definition that
# matches chapter titles.
#
# Chapter range definition syntax:
# ```
# start_pattern<color:opacity>end_pattern
# ```
#
# Multiple start and end patterns can be defined by separating them with `|`:
# ```
# p1|pN<color:opacity>p1|pN
# ```
#
# Multiple chapter ranges can be defined by separating them with comma:
#
# chapter_ranges=range1,rangeN
#
# One of `start_pattern`s can be a custom keyword `{bof}` that will match
# beginning of file when it makes sense.
#
# One of `end_pattern`s can be a custom keyword `{eof}` that will match end of
# file when it makes sense.
#
# Patterns are lua patterns (http://lua-users.org/wiki/PatternsTutorial).
# They only need to occur in a title, not match it completely.
# Matching is case insensitive.
#
# `color` is a `bbggrr` hexadecimal color code.
# `opacity` is a float number from 0 to 1.
#
# Examples:
#
# Display skippable youtube video sponsor blocks from https://github.com/po5/mpv_sponsorblock
# ```
# chapter_ranges=sponsor start<968638:0.5>sponsor end
# ```
#
# Display anime openings and endings as ranges:
# ```
# chapter_ranges=op<968638:0.5>.*,ed|ending<968638:0.5>.*|{eof}
# ```
chapter_ranges=
```

Available keybindings (place into `input.conf`):

```
Key  script-binding uosc/toggletimeline
```
]]

if mp.get_property('osc') == 'yes' then
	mp.msg.info("Disabled because original osc is enabled!")
	return
end

local assdraw = require 'mp.assdraw'
local opt = require 'mp.options'
local osd = mp.create_osd_overlay("ass-events")
local infinity = 1e309

local options = {
	timeline_size_min = 1,
	timeline_size_max = 40,
	timeline_size_min_fullscreen = 0,
	timeline_size_max_fullscreen = 60,
	timeline_opacity = 0.8,
	timeline_border = 1,

	volume = "right",
	volume_size = 40,
	volume_size_fullscreen = 60,
	volume_opacity = 0.8,
	volume_border = 1,
	volume_snap_to = 1,

	chapters = "dots",
	chapters_opacity = 0.3,

	proximity_min = 40,
	proximity_max = 120,
	color_foreground = "ffffff",
	color_foreground_text = "000000",
	color_background = "000000",
	color_background_text = "ffffff",
	autohide = false,
	flash_duration = 300,
	title = false,
	chapter_ranges = ""
}
opt.read_options(options, "uosc")
local config = {
	render_delay = 0.03, -- sets max rendering frequency
	font = mp.get_property("options/osd-font"),
	window_controls = {
		button_width = 46,
		height = 40,
		icon_opacity = 0.8,
		background_opacity = 0.8,
	}
}
local display = {
	width = 1280,
	height = 720,
	aspect = 1.77778,
}
local cursor = {
	hidden = true, -- true when autohidden or outside of the player window
	x = nil,
	y = nil,
}
local state = {
	filename = "",
	border = mp.get_property_native("border"),
	duration = nil,
	position = nil,
	paused = false,
	chapters = nil,
	chapter_ranges = nil, -- structure: [{color: "BBGGRR", opacity: 0-1, serialize: (chapter, last_range_with_no_end?) => range, ranges: [{start: seconds, end: seconds}, ...]}]
	fullscreen = mp.get_property_native("fullscreen"),
	maximized = mp.get_property_native("window-maximized"),
	render_timer = nil,
	render_last_time = 0,
	volume = nil,
	volume_max = nil,
	mute = nil,
	interactive_proximity = 0, -- highest relative proximity to any interactive element
	timeline_top_padding = options.timeline_border,
	timeline_bottom_padding = 0, -- set dynamically to `options.timeline_border` in no-border mode
	cursor_autohide_timer = mp.add_timeout(mp.get_property_native("cursor-autohide") / 1000, function()
		if not options.autohide then return end
		handle_mouse_leave()
	end),
	mouse_bindings_enabled = false
}

--[[
Element object signature:
{
	-- listen for mouse events and disable window dragging
	interactive = true,
	-- element rectangle coordinates
	ax = 0, ay = 0, bx = 0, by = 0,
	-- cursor<>element effective proximity as a 0-1 floating number
	-- where 0 = completely away, and 1 = touching/hovering
	-- so it's easy to work with and throw into equations
	proximity = 0,
	-- raw cursor<>element proximity in pixels
	proximity_raw = infinity,
	-- triggered every time mouse moves over a display, not just the element
	on_mouse_move = function(this_element),
	on_display_resize = function(this_element),
	-- trigered on left mouse button down over this element rectangle
	on_mbtn_left_down = function(this_element),
	-- trigered on right mouse button down over this element rectangle
	on_mbtn_right_down = function(this_element),
	-- whether to render this element, has to return nil or assdraw.ass_new()
	-- object
	render = function(this_element),
}
]]
local elements_mt = {itable = {}}
elements_mt.__index = elements_mt
local elements = setmetatable({}, elements_mt)

function elements_mt.add(elements, name, props)
	elements[name] = {
		id = name,
		interactive = false,
		ax = 0, ay = 0, bx = 0, by = 0,
		proximity = 0, proximity_raw = infinity,
	}
	for key, value in pairs(props) do elements[name][key] = value end
	table.insert(elements_mt.itable, elements[name])
end
function elements_mt.ipairs()
	return ipairs(elements_mt.itable)
end
function elements_mt.pairs(elements)
	return pairs(elements)
end

-- HELPERS
-- how are most of these not part of a standard library :(

function round(number)
	local floored = math.floor(number)
	return number - floored < 0.5 and floored or floored + 1
end

function call_me_maybe(fn, value1, value2, value3)
	if fn then fn(value1, value2, value3) end
end

function split(str, pattern)
	local list = {}
	local full_pattern = "(.-)" .. pattern
	local last_end = 1
	local start_index, end_index, capture = str:find(full_pattern, 1)
	while start_index do
		if start_index ~= 1 or capture ~= "" then
			table.insert(list, capture)
		end
		last_end = end_index + 1
		start_index, end_index, capture = str:find(full_pattern, last_end)
	end
	if last_end <= #str then
		capture = str:sub(last_end)
		table.insert(list, capture)
	end
	return list
end

function itable_find(tab, el)
	for index, value in ipairs(tab) do
		if value == el then return index end
	end
end

function itable_remove(tab, el)
	local should_remove = type(el) == "function" and el or function(value)
		return value == el
	end
	local new_table = {}
	for _, value in ipairs(tab) do
		if not should_remove(value) then
			table.insert(new_table, value)
		end
	end
	return new_table
end

function tween(current, to, setter, on_end)
	local timeout
	local cutoff = math.abs(to - current) * 0.01
	function tick()
		current = current + ((to - current) * 0.3)
		local is_end = math.abs(to - current) <= cutoff
		setter(is_end and to or current)
		request_render()
		if is_end then
			call_me_maybe(on_end)
		else
			timeout:resume()
		end
	end
	timeout = mp.add_timeout(0.016, tick)
	tick()
	return function() timeout:kill() end
end

-- Facilitates killing ongoing animation if one is already happening
-- on this element. Killed animation will not get it's on_end called.
function tween_element(element, from, to, setter, on_end)
	if element.stop_current_animation then
		call_me_maybe(element.stop_current_animation)
	end

	element.stop_current_animation = tween(
		from, to,
		function(value) setter(element, value) end,
		function()
			element.stop_current_animation = nil
			call_me_maybe(on_end, element)
		end
	)
end

function tween_element_stop(element)
	call_me_maybe(element.stop_current_animation)
end

function tween_element_property(element, prop, to, on_end)
	tween_element(element, element[prop], to, function(_, value) element[prop] = value end, on_end)
end

function get_point_to_rectangle_proximity(point, rect)
	local dx = math.max(rect.ax - point.x, 0, point.x - rect.bx + 1)
	local dy = math.max(rect.ay - point.y, 0, point.y - rect.by + 1)
	return math.sqrt(dx*dx + dy*dy);
end

-- STATE UPDATES

function update_display_dimensions()
	local o = mp.get_property_native("osd-dimensions")
	display.width = o.w
	display.height = o.h
	display.aspect = o.aspect

	-- Tell elements about this
	for _, element in elements:ipairs() do
		if element.on_display_resize ~= nil then
			element.on_display_resize(element)
		end
	end
end

function update_element_cursor_proximity(element)
	if cursor.hidden then
		element.proximity_raw = infinity
		element.proximity = 0
	else
		local range = options.proximity_max - options.proximity_min
		element.proximity_raw = get_point_to_rectangle_proximity(cursor, element)
		element.proximity = 1 - (math.min(math.max(element.proximity_raw - options.proximity_min, 0), range) / range)
	end
end

function update_proximities()
	local intercept_mouse_buttons = false
	local highest_proximity = 0

	-- Calculates proximities and opacities for defined elements
	for _, element in elements:ipairs() do
		update_element_cursor_proximity(element)

		if element.proximity > highest_proximity then
			highest_proximity = element.proximity
		end

		-- cursor is over interactive element
		if element.interactive and element.proximity_raw == 0 then
			intercept_mouse_buttons = true
		end
	end

	state.interactive_proximity = highest_proximity

	-- Enable cursor input interception when cursor is over interactive controls
	if not state.mouse_buttons_intercepted and intercept_mouse_buttons then
		state.mouse_buttons_intercepted = true
		mp.enable_key_bindings("mouse_buttons")
	elseif state.mouse_buttons_intercepted and not intercept_mouse_buttons then
		state.mouse_buttons_intercepted = false
		mp.disable_key_bindings("mouse_buttons")
	end
end

-- DRAWING HELPERS

function opacity_to_alpha(opacity)
	return 255 - math.ceil(255 * opacity)
end

function ass_opacity(opacity, fraction)
	fraction = fraction ~= nil and fraction or 1
	if type(opacity) == "number" then
		return string.format("{\\alpha&H%X&}", opacity_to_alpha(opacity * fraction))
	else
		return string.format(
			"{\\1a&H%X&\\2a&H%X&\\3a&H%X&\\4a&H%X&}",
			opacity_to_alpha((opacity[1] or 0) * fraction),
			opacity_to_alpha((opacity[2] or 0) * fraction),
			opacity_to_alpha((opacity[3] or 0) * fraction),
			opacity_to_alpha((opacity[4] or 0) * fraction)
		)
	end
end

--  ELEMENT RENDERERS

function render_timeline(timeline)

	if timeline.size_max == 0
		or state.duration == nil
		or state.position == nil then
		return
	end

	local proximity = math.max(state.interactive_proximity, timeline.proximity)
	local size = timeline.size_min + math.ceil((timeline.size_max - timeline.size_min) * proximity)

	if size < 1 then return end

	local ass = assdraw.ass_new()

	-- text opacity rapidly drops to 0 just before it starts overflowing, or before it reaches timeline.size_min
	local hide_text_below = math.max(timeline.font_size * 0.7, timeline.size_min * 2)
	local hide_text_ramp = hide_text_below / 2
	local text_opacity = math.max(math.min(size - hide_text_below, hide_text_ramp), 0) / hide_text_ramp

	local spacing = math.max(math.floor((timeline.size_max - timeline.font_size) / 2.5), 4)
	local progress = state.position / state.duration

	-- Background bar coordinates
	local bax = 0
	local bay = display.height - size - state.timeline_bottom_padding - state.timeline_top_padding
	local bbx = display.width
	local bby = display.height

	-- Foreground bar coordinates
	local fax = bax
	local fay = bay + state.timeline_top_padding
	local fbx = bbx * progress
	local fby = bby - state.timeline_bottom_padding
	local foreground_coordinates = fax..","..fay..","..fbx..","..fby -- for clipping

	-- Background
	ass:new_event()
	ass:append("{\\blur0\\bord0\\1c&H"..options.color_background.."\\iclip("..foreground_coordinates..")}")
	ass:append(ass_opacity(math.max(options.timeline_opacity - 0.1, 0)))
	ass:pos(0, 0)
	ass:draw_start()
	ass:rect_cw(bax, bay, bbx, bby)
	ass:draw_stop()

	-- Foreground
	ass:new_event()
	ass:append("{\\blur0\\bord0\\1c&H"..options.color_foreground.."}")
	ass:append(ass_opacity(options.timeline_opacity))
	ass:pos(0, 0)
	ass:draw_start()
	ass:rect_cw(fax, fay, fbx, fby)
	ass:draw_stop()

	-- Custom ranges
	if state.chapter_ranges ~= nil then
		for i, chapter_range in ipairs(state.chapter_ranges) do
			for i, range in ipairs(chapter_range.ranges) do
				local rax = display.width * (range["start"].time / state.duration)
				local rbx = display.width * (range["end"].time / state.duration)
				ass:new_event()
				ass:append("{\\blur0\\bord0\\1c&H"..chapter_range.color.."}")
				ass:append(ass_opacity(chapter_range.opacity))
				ass:pos(0, 0)
				ass:draw_start()
				-- for 1px chapter size, use the whole size of the bar including padding
				if size <= 1 then
					ass:rect_cw(rax, bay, rbx, bby)
				else
					ass:rect_cw(rax, fay, rbx, fby)
				end
				ass:draw_stop()
			end
		end
	end

	-- Chapters
	if options.chapters ~= "" and state.chapters ~= nil and #state.chapters > 0 then
		local half_size = size / 2
		local size_padded = bby - bay
		local dots = false
		local chapter_size, chapter_y
		if options.chapters == "dots" then
			dots = true
			chapter_size = math.min(6, (size_padded / 2) + 2)
			chapter_y = math.min(fay + chapter_size, fay + half_size)
		elseif options.chapters == "lines" then
			chapter_size = size
			chapter_y = fay + (chapter_size / 2)
		elseif options.chapters == "lines-top" then
			chapter_size = math.min(timeline.size_max / 3.5, size)
			chapter_y = fay + (chapter_size / 2)
		elseif options.chapters == "lines-bottom" then
			chapter_size = math.min(timeline.size_max / 3.5, size)
			chapter_y = fay + size - (chapter_size / 2)
		end

		if chapter_size ~= nil then
			-- for 1px chapter size, use the whole size of the bar including padding
			chapter_size = size <= 1 and size_padded or chapter_size
			local chapter_half_size = chapter_size / 2

			for i, chapter in ipairs(state.chapters) do
				local chapter_x = display.width * (chapter.time / state.duration)
				local color = chapter_x > fbx and options.color_foreground or options.color_background

				ass:new_event()
				ass:append("{\\blur0\\bord0\\1c&H"..color.."}")
				ass:append(ass_opacity(options.chapters_opacity))
				ass:pos(0, 0)
				ass:draw_start()

				if dots then
					local bezier_stretch = chapter_size * 0.67
					ass:move_to(chapter_x - chapter_half_size, chapter_y)
					ass:bezier_curve(
						chapter_x - chapter_half_size, chapter_y - bezier_stretch,
						chapter_x + chapter_half_size, chapter_y - bezier_stretch,
						chapter_x + chapter_half_size, chapter_y
					)
					ass:bezier_curve(
						chapter_x + chapter_half_size, chapter_y + bezier_stretch,
						chapter_x - chapter_half_size, chapter_y + bezier_stretch,
						chapter_x - chapter_half_size, chapter_y
					)
				else
					ass:rect_cw(chapter_x, chapter_y - chapter_half_size, chapter_x + 1, chapter_y + chapter_half_size)
				end

				ass:draw_stop()
			end
		end
	end

	if text_opacity > 0 then
		-- Elapsed time
		if state.elapsed_seconds then
			ass:new_event()
			ass:append("{\\blur0\\bord0\\shad0\\1c&H"..options.color_foreground_text.."\\fn"..config.font.."\\fs"..timeline.font_size.."\\clip("..foreground_coordinates..")")
			ass:append(ass_opacity(math.min(options.timeline_opacity + 0.1, 1), text_opacity))
			ass:pos(spacing, fay + (size / 2))
			ass:an(4)
			ass:append(state.elapsed_time)
			ass:new_event()
			ass:append("{\\blur0\\bord0\\shad1\\1c&H"..options.color_background_text.."\\4c&H"..options.color_background.."\\fn"..config.font.."\\fs"..timeline.font_size.."\\iclip("..foreground_coordinates..")")
			ass:append(ass_opacity(math.min(options.timeline_opacity + 0.1, 1), text_opacity))
			ass:pos(spacing, fay + (size / 2))
			ass:an(4)
			ass:append(state.elapsed_time)
		end

		-- Remaining time
		if state.remaining_seconds then
			ass:new_event()
			ass:append("{\\blur0\\bord0\\shad0\\1c&H"..options.color_foreground_text.."\\fn"..config.font.."\\fs"..timeline.font_size.."\\clip("..foreground_coordinates..")")
			ass:append(ass_opacity(math.min(options.timeline_opacity + 0.1, 1), text_opacity))
			ass:pos(display.width - spacing, fay + (size / 2))
			ass:an(6)
			ass:append(state.remaining_time)
			ass:new_event()
			ass:append("{\\blur0\\bord0\\shad1\\1c&H"..options.color_background_text.."\\4c&H"..options.color_background.."\\fn"..config.font.."\\fs"..timeline.font_size.."\\iclip("..foreground_coordinates..")")
			ass:append(ass_opacity(math.min(options.timeline_opacity + 0.1, 1), text_opacity))
			ass:pos(display.width - spacing, fay + (size / 2))
			ass:an(6)
			ass:append(state.remaining_time)
		end
	end

	if timeline.proximity_raw == 0 then
		-- Hovered time
		local hovered_seconds = mp.get_property_native("duration") * (cursor.x / display.width)
		local box_half_width_guesstimate = (timeline.font_size * 4.2) / 2
		ass:new_event()
		ass:append("{\\blur0\\bord0\\shad1\\1c&H"..options.color_background_text.."\\4c&H"..options.color_background.."\\fn"..config.font.."\\fs"..timeline.font_size.."")
		ass:append(ass_opacity(math.min(options.timeline_opacity + 0.1, 1)))
		ass:pos(math.min(math.max(cursor.x, box_half_width_guesstimate), display.width - box_half_width_guesstimate), fay)
		ass:an(2)
		ass:append(mp.format_time(hovered_seconds))

		-- Cursor line
		ass:new_event()
		ass:append("{\\blur0\\bord0\\xshad-1\\yshad0\\1c&H"..options.color_foreground.."\\4c&H"..options.color_background.."}")
		ass:append(ass_opacity(0.2))
		ass:pos(0, 0)
		ass:draw_start()
		ass:rect_cw(cursor.x, fay, cursor.x + 1, fby)
		ass:draw_stop()
	end

	return ass
end

function render_window_controls(window_controls)
	local proximity = math.max(state.interactive_proximity, window_controls.proximity)

	if state.border or proximity == 0 then return end

	local ass = assdraw.ass_new()
	local master_opacity = proximity

	-- Close button
	local close = elements.window_controls_close
	if close.proximity_raw == 0 then
		-- Background on hover
		ass:new_event()
		ass:append("{\\blur0\\bord0\\1c&H2311e8}")
		ass:append(ass_opacity(config.window_controls.background_opacity, master_opacity))
		ass:pos(0, 0)
		ass:draw_start()
		ass:rect_cw(close.ax, close.ay, close.bx, close.by)
		ass:draw_stop()
	end
	ass:new_event()
	ass:append("{\\blur0\\bord1\\shad1\\3c&HFFFFFF\\4c&H000000}")
	ass:append(ass_opacity(config.window_controls.icon_opacity, master_opacity))
	ass:pos(close.ax + (config.window_controls.button_width / 2), (config.window_controls.height / 2))
	ass:draw_start()
	ass:move_to(-5, 5)
	ass:line_to(5, -5)
	ass:move_to(-5, -5)
	ass:line_to(5, 5)
	ass:draw_stop()

	-- Maximize button
	local maximize = elements.window_controls_maximize
	if maximize.proximity_raw == 0 then
		-- Background on hover
		ass:new_event()
		ass:append("{\\blur0\\bord0\\1c&H222222}")
		ass:append(ass_opacity(config.window_controls.background_opacity, master_opacity))
		ass:pos(0, 0)
		ass:draw_start()
		ass:rect_cw(maximize.ax, maximize.ay, maximize.bx, maximize.by)
		ass:draw_stop()
	end
	ass:new_event()
	ass:append("{\\blur0\\bord2\\shad0\\1c\\3c&H000000}")
	ass:append(ass_opacity({[3] = config.window_controls.icon_opacity}, master_opacity))
	ass:pos(maximize.ax + (config.window_controls.button_width / 2), (config.window_controls.height / 2))
	ass:draw_start()
	ass:rect_cw(-4, -4, 6, 6)
	ass:draw_stop()
	ass:new_event()
	ass:append("{\\blur0\\bord2\\shad0\\1c\\3c&HFFFFFF}")
	ass:append(ass_opacity({[3] = config.window_controls.icon_opacity}, master_opacity))
	ass:pos(maximize.ax + (config.window_controls.button_width / 2), (config.window_controls.height / 2))
	ass:draw_start()
	ass:rect_cw(-5, -5, 5, 5)
	ass:draw_stop()

	-- Minimize button
	local minimize = elements.window_controls_minimize
	if minimize.proximity_raw == 0 then
		-- Background on hover
		ass:new_event()
		ass:append("{\\blur0\\bord0\\1c&H222222}")
		ass:append(ass_opacity(config.window_controls.background_opacity, master_opacity))
		ass:pos(0, 0)
		ass:draw_start()
		ass:rect_cw(minimize.ax, minimize.ay, minimize.bx, minimize.by)
		ass:draw_stop()
	end
	ass:new_event()
	ass:append("{\\blur0\\bord1\\shad1\\3c&HFFFFFF\\4c&H000000}")
	ass:append(ass_opacity(config.window_controls.icon_opacity, master_opacity))
	ass:append("{\\1a&HFF&}")
	ass:pos(minimize.ax + (config.window_controls.button_width / 2), (config.window_controls.height / 2))
	ass:draw_start()
	ass:move_to(-5, 0)
	ass:line_to(5, 0)
	ass:draw_stop()

	-- Window title
	if options.title then
		local spacing = math.ceil(config.window_controls.height * 0.25)
		local fontsize = math.floor(config.window_controls.height - (spacing * 2))
		local clip_coordinates = "0,0,"..(minimize.ax - spacing)..","..config.window_controls.height

		ass:new_event()
		ass:append("{\\q2\\blur0\\bord0\\shad1\\1c&HFFFFFF\\4c&H000000\\fn"..config.font.."\\fs"..fontsize.."\\clip("..clip_coordinates..")")
		ass:append(ass_opacity(1, master_opacity))
		ass:pos(0 + spacing, config.window_controls.height / 2)
		ass:an(4)
		ass:append(state.filename)
	end

	return ass
end

function render_volume(volume)
	local slider = elements.volume_slider
	local proximity = math.max(state.interactive_proximity, volume.proximity)

	if not slider.pressed and (proximity == 0 or volume.height == 0) then return end

	local ass = assdraw.ass_new()
	local opacity = slider.pressed and 1 or proximity

	-- Background bar coordinates
	local bax = slider.ax - options.volume_border
	local bay = slider.ay - options.volume_border
	local bbx = slider.bx + options.volume_border
	local bby = slider.by + options.volume_border

	-- Foreground bar coordinates
	local fax = slider.ax
	local fay = slider.ay + (slider.height * (1 - (state.volume / state.volume_max)))
	local fbx = slider.bx
	local fby = slider.by

	-- Path to draw a foreground bar with a 100% volume indicator, already
	-- clipped by volume level. Can't just clip it with rectangle, as it itself
	-- also needs to be used as a path to clip the background bar and volume
	-- number.
	local fpath = assdraw.ass_new()
	fpath:move_to(fbx, fby)
	fpath:line_to(fax, fby)
	local nudge_bottom_y = slider.volume_100_y + slider.nudge_size
	if fay <= nudge_bottom_y then
		fpath:line_to(fax, nudge_bottom_y)
		if fay <= slider.volume_100_y then
			fpath:line_to((fax + slider.nudge_size), slider.volume_100_y)
			local nudge_top_y = slider.volume_100_y - slider.nudge_size
			if fay <= nudge_top_y then
				fpath:line_to(fax, nudge_top_y)
				fpath:line_to(fax, fay)
				fpath:line_to(fbx, fay)
				fpath:line_to(fbx, nudge_top_y)
			else
				local triangle_side = fay - nudge_top_y
				fpath:line_to((fax + triangle_side), fay)
				fpath:line_to((fbx - triangle_side), fay)
			end
			fpath:line_to((fbx - slider.nudge_size), slider.volume_100_y)
		else
			local triangle_side = nudge_bottom_y - fay
			fpath:line_to((fax + triangle_side), fay)
			fpath:line_to((fbx - triangle_side), fay)
		end
		fpath:line_to(fbx, nudge_bottom_y)
	else
		fpath:line_to(fax, fay)
		fpath:line_to(fbx, fay)
	end
	fpath:line_to(fbx, fby)

	-- Background
	ass:new_event()
	ass:append("{\\blur0\\bord0\\1c&H"..options.color_background.."\\iclip("..fpath.scale..", "..fpath.text..")}")
	ass:append(ass_opacity(math.max(options.volume_opacity - 0.1, 0), opacity))
	ass:pos(0, 0)
	ass:draw_start()
	ass:move_to(bax, bay)
	ass:line_to(bbx, bay)
	local half_border = options.volume_border / 2
	ass:line_to(bbx, slider.volume_100_y - slider.nudge_size + half_border)
	ass:line_to(bbx - slider.nudge_size + half_border, slider.volume_100_y)
	ass:line_to(bbx, slider.volume_100_y + slider.nudge_size - half_border)
	ass:line_to(bbx, bby)
	ass:line_to(bax, bby)
	ass:line_to(bax, slider.volume_100_y + slider.nudge_size - half_border)
	ass:line_to(bax + slider.nudge_size - half_border, slider.volume_100_y)
	ass:line_to(bax, slider.volume_100_y - slider.nudge_size + half_border)
	ass:line_to(bax, bay)
	ass:draw_stop()

	-- Foreground
	ass:new_event()
	ass:append("{\\blur0\\bord0\\1c&H"..options.color_foreground.."}")
	ass:append(ass_opacity(options.volume_opacity, opacity))
	ass:pos(0, 0)
	ass:draw_start()
	ass:append(fpath.text)
	ass:draw_stop()

	-- Current volume value
	ass:new_event()
	ass:append("{\\blur0\\bord0\\shad0\\1c&H"..options.color_foreground_text.."\\fn"..config.font.."\\fs"..slider.font_size.."\\clip("..fpath.scale..", "..fpath.text..")")
	ass:append(ass_opacity(math.min(options.volume_opacity + 0.1, 1), opacity))
	ass:pos(slider.ax + (slider.width / 2), bay + slider.spacing)
	ass:an(8)
	ass:append(state.volume)
	ass:new_event()
	ass:append("{\\blur0\\bord0\\shad1\\1c&H"..options.color_background_text.."\\4c&H"..options.color_background.."\\fn"..config.font.."\\fs"..slider.font_size.."\\iclip("..fpath.scale..", "..fpath.text..")")
	ass:append(ass_opacity(math.min(options.volume_opacity + 0.1, 1), opacity))
	ass:pos(slider.ax + (slider.width / 2), bay + slider.spacing)
	ass:an(8)
	ass:append(state.volume)

	-- Mute button
	local mute = elements.volume_mute
	ass:new_event()
	ass:append("{\\blur0\\bord1\\shad1\\1c&HFFFFFF\\3c&HFFFFFF\\4c&H000000}")
	ass:append(ass_opacity(options.volume_opacity, opacity))
	ass:pos(mute.ax + (mute.width / 2), mute.ay + (mute.height / 2))
	ass:draw_start()
	ass:merge(mute.icon)
	ass:draw_stop()

	return ass
end

-- MAIN RENDERING

-- Request that render() is called.
-- The render is then either executed immediately, or rate-limited if it was
-- called a small time ago.
function request_render()
	if state.render_timer == nil then
		state.render_timer = mp.add_timeout(0, render)
	end

	if not state.render_timer:is_enabled() then
		local now = mp.get_time()
		local timeout = config.render_delay - (now - state.render_last_time)
		if timeout < 0 then
			timeout = 0
		end
		state.render_timer.timeout = timeout
		state.render_timer:resume()
	end
end

function render()
	state.render_last_time = mp.get_time()

	-- Actual rendering
	local ass = assdraw.ass_new()

	for _, element in elements.ipairs() do
		if element.render ~= nil then
			local result = element.render(element)
			if result then
				ass:new_event()
				ass:merge(result)
			end
		end
	end

	-- submit
	if osd.res_x == display.width and osd.res_y == display.height and osd.data == ass.text then
		return
	end

	osd.res_x = display.width
	osd.res_y = display.height
	osd.data = ass.text
	osd.z = 2000
	osd:update()
end

-- STATIC ELEMENTS

function create_flash_function_for(element_name)
	if not options.flash_duration or options.flash_duration < 1 then
		return function() end
	end

	local flash_timer = nil
	flash_timer = mp.add_timeout(options.flash_duration / 1000, function()
		tween_element_property(elements[element_name], "proximity", 0)
	end)
	flash_timer:kill()

	return function()
		if flash_timer and (elements[element_name].proximity < 1 or flash_timer:is_enabled()) then
			tween_element_stop(elements[element_name])
			elements[element_name].proximity = 1
			flash_timer:kill()
			flash_timer:resume()
		end
	end
end

elements:add("timeline", {
	interactive = true,
	size_max = 0, size_min = 0, -- set in `on_display_resize` handler based on `state.fullscreen`
	font_size = 0, -- calculated in on_display_resize
	flash = create_flash_function_for("timeline"),
	on_display_resize = function(element)
		if state.fullscreen or state.maximized then
			element.size_min = options.timeline_size_min_fullscreen
			element.size_max = options.timeline_size_max_fullscreen
		else
			element.size_min = options.timeline_size_min
			element.size_max = options.timeline_size_max
		end
		element.interactive = element.size_max > 0
		element.font_size = math.floor(math.min((element.size_max + 60) * 0.2, element.size_max * 0.96))
		element.ax = 0
		element.ay = display.height - element.size_max - state.timeline_top_padding - state.timeline_bottom_padding
		element.bx = display.width
		element.by = display.height
	end,
	on_mbtn_left_down = function()
		mp.commandv("seek", ((cursor.x / display.width) * 100), "absolute-percent+exact")
	end,
	render = render_timeline,
})
elements:add("window_controls", {
	on_display_resize = function(element)
		local ax = display.width - (config.window_controls.button_width * 3)
		element.ax = options.title and 0 or ax
		element.ay = 0
		element.bx = display.width
		element.by = config.window_controls.height
	end,
	render = render_window_controls,
})
elements:add("window_controls_minimize", {
	interactive = true,
	on_display_resize = function(element)
		element.ax = display.width - (config.window_controls.button_width * 3)
		element.ay = 0
		element.bx = element.ax + config.window_controls.button_width
		element.by = config.window_controls.height
	end,
	on_mbtn_left_down = function() mp.commandv("cycle", "window-minimized") end
})
elements:add("window_controls_maximize", {
	interactive = true,
	on_display_resize = function(element)
		element.ax = display.width - (config.window_controls.button_width * 2)
		element.ay = 0
		element.bx = element.ax + config.window_controls.button_width
		element.by = config.window_controls.height
	end,
	on_mbtn_left_down = function() mp.commandv("cycle", "window-maximized") end
})
elements:add("window_controls_close", {
	interactive = true,
	on_display_resize = function(element)
		element.ax = display.width - config.window_controls.button_width
		element.ay = 0
		element.bx = element.ax + config.window_controls.button_width
		element.by = config.window_controls.height
	end,
	on_mbtn_left_down = function() mp.commandv("quit") end
})
if itable_find({"left", "right"}, options.volume) then
	function update_volume_icon()
		local element = elements.volume_mute
		element.icon = assdraw.ass_new()
		if elements.volume.width == nil then return end
		element.icon.scale = elements.volume.width / 40
		element.icon:move_to(-80, -30)
		element.icon:line_to(-40, -30)
		element.icon:line_to(-5, -60)
		element.icon:line_to(-5, 60)
		element.icon:line_to(-40, 30)
		element.icon:line_to(-80, 30)
		if state.mute then
			element.icon:move_to(30, -30)
			element.icon:line_to(90, 30)
			element.icon:move_to(30, 30)
			element.icon:line_to(90, -30)
		else
			element.icon:move_to(40, -30)
			element.icon:line_to(40, 30)
			element.icon:move_to(80, -60)
			element.icon:line_to(80, 60)
		end
	end

	elements:add("volume", {
		width = nil, -- set in `on_display_resize` handler based on `state.fullscreen`
		height = nil, -- set in `on_display_resize` handler based on `state.fullscreen`
		font_size = nil, -- calculated in on_display_resize
		flash = create_flash_function_for("volume"),
		on_display_resize = function(element)
			local left = options.volume == "left"
			element.width = (state.fullscreen or state.maximized) and options.volume_size_fullscreen or options.volume_size
			element.height = round(math.min(element.width * 6, (elements.timeline.ay - elements.window_controls.by) * 0.8))
			-- Don't bother rendering this if too small
			if element.height < (element.width * 2) then
				element.height = 0
			end
			element.font_size = math.floor(element.width * 0.2)
			local spacing = element.width / 2
			element.ax = round(options.volume == "left" and spacing or display.width - spacing - element.width)
			element.ay = round((display.height / 2) - (element.height / 2))
			element.bx = round(element.ax + element.width)
			element.by = round(element.ay + element.height)
		end,
		render = render_volume,
	})
	elements:add("volume_mute", {
		interactive = true,
		width = 0,
		height = 0,
		on_display_resize = function(element)
			element.width = elements.volume.width
			element.height = element.width
			element.ax = elements.volume.ax
			element.ay = elements.volume.by - element.height
			element.bx = elements.volume.bx
			element.by = elements.volume.by
			update_volume_icon()
		end,
		on_mbtn_left_down = function(element) mp.commandv("cycle", "mute") end,
		on_global_prop_mute = update_volume_icon
	})
	elements:add("volume_slider", {
		interactive = true,
		pressed = false,
		width = 0,
		height = 0,
		volume_100_y = 0, -- vertical position where volume overflows 100
		nudge_size = nil, -- set on resize
		font_size = nil,
		spacing = nil,
		on_display_resize = function(element)
			-- Coordinates of the interactive portion of the bar
			element.ax = elements.volume.ax + options.volume_border
			element.ay = elements.volume.ay + options.volume_border
			element.bx = elements.volume.bx - options.volume_border
			element.by = elements.volume_mute.ay - options.volume_border
			element.width = element.bx - element.ax
			element.height = element.by - element.ay
			element.volume_100_y = element.by - round(element.height * (100 / state.volume_max))
			element.nudge_size = round(elements.volume.width * 0.18)
			element.font_size = round(element.width * 0.5)
			element.spacing = round(element.width * 0.2)
		end,
		set_from_cursor = function()
			local slider = elements.volume_slider
			local new_volume = math.min(math.max((slider.by - cursor.y) / slider.height, 0), 1) * state.volume_max
			new_volume = round(new_volume / options.volume_snap_to) * options.volume_snap_to
			if state.volume ~= new_volume then mp.commandv("set", "volume", new_volume) end
		end,
		on_mbtn_left_down = function(element)
			element.pressed = true
			element.set_from_cursor()
		end,
		on_global_mbtn_left_up = function(element) element.pressed = false end,
		on_global_mouse_leave = function(element) element.pressed = false end,
		on_global_mouse_move = function(element)
			if element.pressed then element.set_from_cursor() end
		end,
	})
end

-- CHAPTERS

-- Parse `chapter_ranges` option into workable data structure
for _, definition in ipairs(split(options.chapter_ranges, " *,+ *")) do
	local start_patterns, color, opacity, end_patterns = string.match(definition, "([^<]+)<(%x%x%x%x%x%x):(%d?%.?%d*)>([^>]+)")

	-- Invalid definition
	if start_patterns == nil then goto continue end

	start_patterns = start_patterns:lower()
	end_patterns = end_patterns:lower()
	local uses_bof = start_patterns:find("{bof}") ~= nil
	local uses_eof = end_patterns:find("{eof}") ~= nil
	local chapter_range = {
		start_patterns = split(start_patterns, "|"),
		end_patterns = split(end_patterns, "|"),
		color = color,
		opacity = tonumber(opacity),
		ranges = {}
	}

	-- Filter out special keywords so we don't use them when matching titles
	if uses_bof then
		chapter_range.start_patterns = itable_remove(chapter_range.start_patterns, "{bof}")
	end
	if uses_eof and chapter_range.end_patterns then
		chapter_range.end_patterns = itable_remove(chapter_range.end_patterns, "{eof}")
	end

	chapter_range["serialize"] = function (chapters)
		chapter_range.ranges = {}
		local current_range = nil
		-- bof and eof should be used only once per timeline
		-- eof is only used when last range is missing end
		local bof_used = false

		function start_range(chapter)
			-- If there is already a range started, should we append or overwrite?
			-- I chose overwrite here.
			current_range = {["start"] = chapter}
		end

		function end_range(chapter)
			current_range["end"] = chapter
			table.insert(chapter_range.ranges, current_range)
			-- Mark both chapter objects
			current_range["start"]._uosc_used_as_range_point = true
			current_range["end"]._uosc_used_as_range_point = true
			-- Clear for next range
			current_range = nil
		end

		for _, chapter in ipairs(chapters) do
			if type(chapter.title) == "string" then
				local lowercase_title = chapter.title:lower()
				local is_end = false
				local is_start = false

				-- Is ending check and handling
				if chapter_range.end_patterns then
					for _, end_pattern in ipairs(chapter_range.end_patterns) do
						is_end = is_end or lowercase_title:find(end_pattern) ~= nil
					end

					if is_end then
						if current_range == nil and uses_bof and not bof_used then
							bof_used = true
							start_range({time = 0})
						end
						if current_range ~= nil then
							end_range(chapter)
						else
							is_end = false
						end
					end
				end

				-- Is start check and handling
				for _, start_pattern in ipairs(chapter_range.start_patterns) do
					is_start = is_start or lowercase_title:find(start_pattern) ~= nil
				end

				if is_start then start_range(chapter) end
			end
		end

		-- If there is an unfinished range and range type accepts eof, use it
		if current_range ~= nil and uses_eof then
			end_range({time = state.duration or infinity})
		end
	end

	state.chapter_ranges = state.chapter_ranges or {}
	table.insert(state.chapter_ranges, chapter_range)

	::continue::
end

function parse_chapters(name, chapters)
	if not chapters then return end

	-- Reset custom ranges
	for _, chapter_range in ipairs(state.chapter_ranges or {}) do
		chapter_range.serialize(chapters)
	end

	-- Filter out chapters that were used as ranges
	state.chapters = itable_remove(chapters, function(chapter)
		return chapter._uosc_used_as_range_point == true
	end)

	request_render()
end

-- EVENT HANDLERS

function dispatch_event_to_elements(name, value)
	for _, element in pairs(elements) do
		if element.proximity_raw == 0 then
			call_me_maybe(element["on_"..name], element, value)
		end
		call_me_maybe(element["on_global_"..name], element, value)
	end
end

function handle_mouse_leave()
	local interactive_proximity_on_leave = state.interactive_proximity
	cursor.hidden = true
	update_proximities()
	dispatch_event_to_elements("mouse_leave")
	if interactive_proximity_on_leave > 0 then
		tween_element(state, interactive_proximity_on_leave, 0, function(state, value)
			state.interactive_proximity = value
			request_render()
		end)
	end
end

function create_mouse_event_handler(source)
	if source == "mouse_move" then
		return function()
			if cursor.hidden then
				tween_element_stop(state)
			end
			cursor.hidden = false
			cursor.x, cursor.y = mp.get_mouse_pos()
			update_proximities()
			dispatch_event_to_elements(source)
			request_render()

			-- Restart timer that hides UI when mouse is autohidden
			if options.autohide then
				state.cursor_autohide_timer:kill()
				state.cursor_autohide_timer:resume()
			end
		end
	elseif source == "mouse_leave" then
		return handle_mouse_leave
	else
		return function()
			dispatch_event_to_elements(source)
		end
	end
end

function state_setter(name)
	return function(_, value)
		state[name] = value
		dispatch_event_to_elements("prop_"..name, value)
		request_render()
	end
end

-- HOOKS

mp.register_event("file-loaded", function()
	state.duration = mp.get_property_number("duration", nil)
	state.filename = mp.get_property_osd("filename", "")
end)

mp.observe_property("chapter-list", "native", parse_chapters)
mp.observe_property("fullscreen", "bool", state_setter("fullscreen"))
mp.observe_property("window-maximized", "bool", state_setter("maximized"))
mp.observe_property("idle-active", "bool", state_setter("idle"))
mp.observe_property("pause", "bool", state_setter("paused"))
mp.observe_property("volume", "number", function(_, value)
	local is_initial_call = state.volume == nil
	state.volume = value
	if not is_initial_call then elements.volume.flash() end
	request_render()
end)
mp.observe_property("volume-max", "number", state_setter("volume_max"))
mp.observe_property("mute", "bool", state_setter("mute"))
mp.observe_property("border", "bool", function (_, border)
	state.border = border
	-- Sets 1px bottom border for bars in no-border mode
	state.timeline_bottom_padding = (not border and state.timeline_top_padding) or 0

	request_render()
end)
mp.observe_property("playback-time", "number", function(name, val)
	state.position = val
	state.elapsed_seconds = mp.get_property_native("playback-time")
	state.elapsed_time = state.elapsed_seconds and mp.format_time(state.elapsed_seconds) or nil
	state.remaining_seconds = mp.get_property_native("playtime-remaining")
	state.remaining_time = state.remaining_seconds and mp.format_time(state.remaining_seconds) or nil
	request_render()
end)
mp.observe_property("osd-dimensions", "native", function(name, val)
	update_display_dimensions()
	request_render()
end)
mp.register_event("seek", function()
	elements.timeline.flash()
end)

-- CONTROLS

-- mouse movement bindings
mp.set_key_bindings({
	{"mouse_move", create_mouse_event_handler("mouse_move")},
	{"mouse_leave", create_mouse_event_handler("mouse_leave")},
}, "mouse_movement", "force")
mp.enable_key_bindings("mouse_movement", "allow-vo-dragging+allow-hide-cursor")

-- mouse button bindings
mp.set_key_bindings({
	{"mbtn_left", create_mouse_event_handler("mbtn_left_up"), create_mouse_event_handler("mbtn_left_down")},
	{"mbtn_right", create_mouse_event_handler("mbtn_right_up"), create_mouse_event_handler("mbtn_right_down")},
	{"mbtn_left_dbl", "ignore"},
	{"mbtn_right_dbl", "ignore"},
}, "mouse_buttons", "force")

-- User bindable functions
mp.add_key_binding(nil, 'toggletimeline', function()
	if elements.timeline.proximity > 0.5 then
		tween_element_property(elements.timeline, "proximity", 0)
	else
		tween_element_property(elements.timeline, "proximity", 1)
	end
end)
