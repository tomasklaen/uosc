--[[

uosc 1.3.0 | https://github.com/darsain/uosc

Minimalistic proximity based UI for MPV player.

uosc replaces the default osc UI, so that has to be disabled first.
Place these options into your `mpv.conf` file:

```
osc=no     # required so that the 2 UIs don't fight each other
border=no  # if you disable window border, uosc will draw
           # its own proximity based window controls
```

Options go in `script-opts/uosc.conf`. Defaults:

```
# display window title (filename) in no-border mode
title=no

# seekbar size in pixels, 0 to disable
seekbar_size=40
# same as ^ but when in fullscreen
seekbar_size_fullscreen=60
# seekbar opacity when fully visible
seekbar_opacity=0.8
# seekbar chapters indicator style: dots, lines, lines-top, lines-bottom
# set to empty to disable
seekbar_chapters=dots
# seekbar chapters indicator opacity
seekbar_chapters_opacity=0.3

# progressbar size in pixels, 0 to disable
progressbar_size=1
# same as ^ but when in fullscreen
progressbar_size_fullscreen=0
# progressbar opacity
progressbar_opacity=0.8
# progressbar chapters indicator style: dots, lines, lines-top, lines-bottom
# set to empty to disable
progressbar_chapters=dots
# progressbar chapters indicator opacity
progressbar_chapters_opacity=0.3

# proximity below which opacity equals 1
min_proximity=40
# proximity above which opacity equals 0
max_proximity=120
# BBGGRR - BLUE GREEN RED hex code
color_foreground=FFFFFF
# BBGGRR - BLUE GREEN RED hex code
color_background=000000
# hide proximity based elements when mpv autohides the cursor
autohide=no

# `chapter_ranges` lets you define custom range indicators that will be parsed out from
# chapters, identified by chapter titles, and displayed in progressbar and seekbar.
# This requires that someone or something makes chapters that identify these ranges in their titles.
#
# Syntax 1: "<start-str>-<end-str>:<color>:<opacity>"
# Syntax 2: "<range-str>:<color>:<opacity>"
#
# Multiple chapter ranges can be defined by separating them with comma:
#
# chapter_ranges=<range1>,<range2>,<range3>
#
# `<start-str>`, `<end-str>`, and `<range-str>` only have to occur in a title, they don't have to match it completely.
# If only one `<range-str>` is specified, ranges will be created from consecutive pairs of this type of chapters.
#
# Example:
#
# Display skippable youtube video sponsor blocks from https://github.com/po5/mpv_sponsorblock
#
# chapter_ranges=Sponsor start-Sponsor end:968638:0.5
#
chapter_ranges=
```

Available keybindings (place into `input.conf`):

```
Key  script-binding uosc/toggleprogressbar
Key  script-binding uosc/toggleseekbar
```

]]

if mp.get_property('osc') == 'yes' then
	mp.msg.info("Disabled because original osc is enabled!")
	return
end

local assdraw = require 'mp.assdraw'
local opt = require 'mp.options'
local osd = mp.create_osd_overlay("ass-events")

local options = {
	title = false,

	seekbar_size = 40,
	seekbar_size_fullscreen = 60,
	seekbar_opacity = 0.8,
	seekbar_chapters = "dots",
	seekbar_chapters_opacity = 0.3,

	progressbar_size = 1,
	progressbar_size_fullscreen = 0,
	progressbar_opacity = 0.8,
	progressbar_chapters = "dots",
	progressbar_chapters_opacity = 0.3,

	min_proximity = 40,
	max_proximity = 120,
	color_foreground = "FFFFFF",
	color_background = "000000",
	autohide = false,
	chapter_ranges = ""
}
opt.read_options(options, "uosc")
local config = {
	render_delay = 0.03, -- sets max rendering frequency
	font = mp.get_property("options/osd-font"),
	bar_top_border = 1,
	bar_bottom_border = 0, -- set dynamically to 1 in no-border mode
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
	cursor_autohide_timer = mp.add_timeout(mp.get_property_native("cursor-autohide") / 1000, function()
		if not options.autohide then return end
		cursor.hidden = true
		update_proximities()
		request_render()
	end),
	mouse_bindings_enabled = false
}
local infinity = 1e309
local elements = {
	progressbar = {
		enabled = true, -- flag set manually through runtime keybinds
		size = 0, -- consolidation of `progressbar_size` and `progressbar_size_fullscreen` options
		on_display_resize = function(element)
			if state.fullscreen or state.maximized then
				element.size = options.progressbar_size_fullscreen
			else
				element.size = options.progressbar_size
			end
		end,
		render = function(element) return render_progressbar(element) end,
	},
	seekbar = {
		interactive = true, -- listen for mouse events and disable window dragging
		size = 0, -- consolidation of `seekbar_size` and `seekbar_size_fullscreen` options, set in `on_display_resize` handler below
		font_size = 0, -- calculated in `on_display_resize` handler below based on seekbar size
		spacing = 0, -- calculated in `on_display_resize` handler below based on size and font size
		ax = 0, ay = 0, bx = 0, by = 0, -- rectangle coordinates calculated in `on_display_resize` handler below
		proximity = infinity, opacity = 0,  -- calculated on mouse movement
		on_mouse_move = function(element) update_element_cursor_proximity(element) end,
		on_display_resize = function(element)
			if state.fullscreen or state.maximized then
				element.size = options.seekbar_size_fullscreen
			else
				element.size = options.seekbar_size
			end
			element.interactive = element.size > 0
			element.font_size = math.floor(math.min((element.size + 15) * 0.4, element.size * 0.96))
			element.spacing = math.floor((element.size - element.font_size) / 2)
			element.ax = 0
			element.ay = display.height - element.size - config.bar_top_border - config.bar_bottom_border
			element.bx = display.width
			element.by = display.height
		end,
		on_mbtn_left_down = function()
			mp.commandv("seek", ((cursor.x / display.width) * 100), "absolute-percent+exact")
		end,
		render = function(element) return render_seekbar(element) end,
	},
	window_controls = {
		ax = 0, ay = 0, bx = 0, by = 0, -- calculated by on_display_resize
		proximity = infinity, opacity = 0,   -- calculated on mouse movement
		on_mouse_move = function(element) update_element_cursor_proximity(element) end,
		on_display_resize = function(element)
			local ax = display.width - (config.window_controls.button_width * 3)
			element.ax = options.title and 0 or ax
			element.ay = 0
			element.bx = display.width
			element.by = config.window_controls.height
		end,
		render = function(element) return render_window_controls(element) end,
	},
	window_controls_minimize = {
		interactive = true, -- listen for mouse events and disable window dragging
		ax = 0, ay = 0, bx = 0, by = 0, -- calculated by on_display_resize
		proximity = infinity, opacity = 0,  -- calculated on mouse movement
		on_mouse_move = function(element) update_element_cursor_proximity(element) end,
		on_display_resize = function(element)
			element.ax = display.width - (config.window_controls.button_width * 3)
			element.ay = 0
			element.bx = element.ax + config.window_controls.button_width
			element.by = config.window_controls.height
		end,
		on_mbtn_left_down = function() mp.commandv("cycle", "window-minimized") end
	},
	window_controls_maximize = {
		interactive = true, -- listen for mouse events and disable window dragging
		ax = 0, ay = 0, bx = 0, by = 0, -- calculated by on_display_resize
		proximity = infinity, opacity = 0,  -- calculated on mouse movement
		on_mouse_move = function(element) update_element_cursor_proximity(element) end,
		on_display_resize = function(element)
			element.ax = display.width - (config.window_controls.button_width * 2)
			element.ay = 0
			element.bx = element.ax + config.window_controls.button_width
			element.by = config.window_controls.height
		end,
		on_mbtn_left_down = function() mp.commandv("cycle", "window-maximized") end
	},
	window_controls_close = {
		interactive = true, -- listen for mouse events and disable window dragging
		ax = 0, ay = 0, bx = 0, by = 0, -- calculated by on_display_resize
		proximity = infinity, opacity = 0,  -- calculated on mouse movement
		on_mouse_move = function(element) update_element_cursor_proximity(element) end,
		on_display_resize = function(element)
			element.ax = display.width - config.window_controls.button_width
			element.ay = 0
			element.bx = element.ax + config.window_controls.button_width
			element.by = config.window_controls.height
		end,
		on_mbtn_left_down = function() mp.commandv("quit") end
	}
}

-- HELPER FUNCTIONS

function split(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	local t={}
	for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
		table.insert(t, str)
	end
	return t
end

function get_point_to_rectangle_proximity(point, rect)
	local dx = math.max(rect.ax - point.x, 0, point.x - rect.bx + 1)
	local dy = math.max(rect.ay - point.y, 0, point.y - rect.by + 1)
	return math.sqrt(dx*dx + dy*dy);
end

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

-- STATE UPDATES

function update_display_dimensions()
	local o = mp.get_property_native("osd-dimensions")
	display.width = o.w
	display.height = o.h
	display.aspect = o.aspect

	-- Tell elements to update their area rectangles
	for _, element in pairs(elements) do
		if element.on_display_resize ~= nil then
			element.on_display_resize(element)
		end
	end
end

function update_cursor_position()
	local x, y = mp.get_mouse_pos()
	cursor.x = x
	cursor.y = y
	update_proximities()
end

function update_element_cursor_proximity(element)
	if cursor.hidden then
		element.proximity = infinity
		element.opacity = 0
	else
		local range = options.max_proximity - options.min_proximity
		element.proximity = get_point_to_rectangle_proximity(cursor, element)
		element.opacity = 1 - math.min(math.max(element.proximity - options.min_proximity, 0), range) / range
	end
end

function update_proximities()
	local should_enable_mouse_bindings = false

	-- Calculates proximities and opacities for defined elements
	for _, element in pairs(elements) do
		-- Only update proximity and opacity for elements that care about it
		if element.proximity ~= nil and element.on_mouse_move ~= nil then
			element.on_mouse_move(element)
			should_enable_mouse_bindings = should_enable_mouse_bindings or (element.interactive and element.proximity == 0)
		end
	end

	-- Disable cursor input interception when cursor is not over any controls
	if not state.mouse_bindings_enabled and should_enable_mouse_bindings then
		state.mouse_bindings_enabled = true
		mp.enable_key_bindings("mouse_buttons")
	elseif state.mouse_bindings_enabled and not should_enable_mouse_bindings then
		state.mouse_bindings_enabled = false
		mp.disable_key_bindings("mouse_buttons")
	end
end

-- Drawing helpers

function new_ass()
	local ass = assdraw.ass_new()
	-- Not 100% sure what scale does, but as far as I understand it multiplies
	-- the resolution of final render by the number this value is set for?
	-- Since uosc is rendered to be pixel perfect, and not relatively stretched
	-- I see no reason to go above 1 and increase CPU/GPU/memory load.
	-- Open an issue if I'm mistaken and this should be higher.
	ass.scale = 1
	-- Doing ass:new_event() on an empty ass object does nothing on purpose for
	-- some reason, so we have to do it manually here so that all ass objects
	-- can be merged safely without having to call new_event() before every damn
	-- merge.
	ass.text = "\n"
	return ass
end

function draw_chapters(style, chapter_y, size, foreground_cutoff, opacity)
	local ass = new_ass()
	if state.chapters ~= nil then
		local half_size = size / 2
		local bezier_stretch = size * 0.67
		for i, chapter in ipairs(state.chapters) do
			local chapter_x = display.width * (chapter.time / state.duration)

			ass:new_event()
			if chapter_x > foreground_cutoff then
				ass:append("{\\blur0\\bord0\\1c&H"..options.color_foreground.."}")
			else
				ass:append("{\\blur0\\bord0\\1c&H"..options.color_background.."}")
			end
			ass:append(ass_opacity(opacity))
			ass:pos(0, 0)
			ass:draw_start()

			if style == "dots" then
				ass:move_to(chapter_x - half_size, chapter_y)
				ass:bezier_curve(
					chapter_x - half_size, chapter_y - bezier_stretch,
					chapter_x + half_size, chapter_y - bezier_stretch,
					chapter_x + half_size, chapter_y
				)
				ass:bezier_curve(
					chapter_x + half_size, chapter_y + bezier_stretch,
					chapter_x - half_size, chapter_y + bezier_stretch,
					chapter_x - half_size, chapter_y
				)
			elseif style == "lines" then
				ass:rect_cw(chapter_x, chapter_y, chapter_x + 1, chapter_y + size)
			end

			ass:draw_stop()
		end
	end
	return ass
end

function draw_chapter_ranges(top, size, opacity)
	local ass = new_ass()
	if state.chapter_ranges == nil then return ass end

	for i, chapter_range in ipairs(state.chapter_ranges) do
		for i, range in ipairs(chapter_range.ranges) do
			local ax = display.width * (range["start"] / state.duration)
			local ay = top
			local bx = display.width * (range["end"] / state.duration)
			local by = top + size
			ass:new_event()
			ass:append("{\\blur0\\bord0\\1c&H"..chapter_range.color.."}")
			ass:append(ass_opacity(chapter_range.opacity, opacity))
			ass:pos(0, 0)
			ass:draw_start()
			ass:rect_cw(ax, ay, bx, by)
			ass:draw_stop()
		end
	end

	return ass
end

--  ELEMENT RENDERERS

function render_progressbar(progressbar)
	local ass = new_ass()

	if not progressbar.enabled
		or progressbar.size == 0
		or state.duration == nil
		or state.position == nil then
		return ass
	end

	-- Progressbar opacity is inversely proportional to seekbar opacity
	local opacity = elements.seekbar.size > 0
		and (1 - math.min(elements.seekbar.opacity / 0.4, 1))
		or 1

	if opacity == 0 then
		return ass
	end

	local progress = state.position / state.duration

	-- Background bar coordinates
	local bax = 0
	local bay = display.height - progressbar.size - config.bar_bottom_border - config.bar_top_border
	local bbx = display.width
	local bby = display.height

	-- Foreground bar coordinates
	local fax = bax
	local fay = bay + config.bar_top_border
	local fbx = bbx * progress
	local fby = bby - config.bar_bottom_border

	-- Background
	ass:new_event()
	ass:append("{\\blur0\\bord0\\1c&H"..options.color_background.."\\iclip("..fax..","..fay..","..fbx..","..fby..")}")
	ass:append(ass_opacity(math.max(options.progressbar_opacity - 0.1, 0), opacity))
	ass:pos(0, 0)
	ass:draw_start()
	ass:rect_cw(bax, bay, bbx, bby)
	ass:draw_stop()

	-- Foreground
	ass:new_event()
	ass:append("{\\blur0\\bord0\\1c&H"..options.color_foreground.."}")
	ass:append(ass_opacity(options.progressbar_opacity, opacity))
	ass:pos(0, 0)
	ass:draw_start()
	ass:rect_cw(fax, fay, fbx, fby)
	ass:draw_stop()

	-- Custom ranges
	if state.chapter_ranges ~= nil then
		ass:merge(draw_chapter_ranges(fay, progressbar.size, opacity))
	end

	-- Chapters
	if options.progressbar_chapters == "dots" then
		ass:merge(draw_chapters("dots", math.ceil(fay + (progressbar.size / 2)), 4, fbx, options.progressbar_chapters_opacity * opacity))
	elseif options.progressbar_chapters == "lines" then
		ass:merge(draw_chapters("lines", fay, progressbar.size, fbx, options.progressbar_chapters_opacity * opacity))
	elseif options.progressbar_chapters == "lines-top" then
		ass:merge(draw_chapters("lines", fay, progressbar.size / 2, fbx, options.progressbar_chapters_opacity * opacity))
	elseif options.progressbar_chapters == "lines-bottom" then
		ass:merge(draw_chapters("lines", fay + progressbar.size - (progressbar.size / 2), progressbar.size / 2, fbx, options.progressbar_chapters_opacity * opacity))
	end

	return ass
end

function render_seekbar(seekbar)
	local ass = new_ass()

	if cursor.hidden
		or seekbar.size == 0
		or seekbar.opacity == 0
		or state.duration == nil
		or state.position == nil then
		return ass
	end

	local progress = state.position / state.duration

	-- Background bar coordinates
	local bax = 0
	local bay = display.height - seekbar.size - config.bar_bottom_border - config.bar_top_border
	local bbx = display.width
	local bby = display.height

	-- Foreground bar coordinates
	local fax = bax
	local fay = bay + config.bar_top_border
	local fbx = bbx * progress
	local fby = bby - config.bar_bottom_border
	local foreground_coordinates = fax..","..fay..","..fbx..","..fby -- for clipping

	-- Background
	ass:new_event()
	ass:append("{\\blur0\\bord0\\1c&H"..options.color_background.."\\iclip("..foreground_coordinates..")}")
	ass:append(ass_opacity(math.max(options.seekbar_opacity - 0.1, 0), seekbar.opacity))
	ass:pos(0, 0)
	ass:draw_start()
	ass:rect_cw(bax, bay, bbx, bby)
	ass:draw_stop()

	-- Foreground
	ass:new_event()
	ass:append("{\\blur0\\bord0\\1c&H"..options.color_foreground.."}")
	ass:append(ass_opacity(options.seekbar_opacity, seekbar.opacity))
	ass:pos(0, 0)
	ass:draw_start()
	ass:rect_cw(fax, fay, fbx, fby)
	ass:draw_stop()

	-- Custom ranges
	if state.chapter_ranges ~= nil then
		ass:merge(draw_chapter_ranges(fay, seekbar.size, seekbar.opacity))
	end

	-- Chapters
	if options.seekbar_chapters == "dots" then
		ass:merge(draw_chapters("dots", fay + 6, 6, fbx, options.seekbar_chapters_opacity * seekbar.opacity))
	elseif options.seekbar_chapters == "lines" then
		ass:merge(draw_chapters("lines", fay, seekbar.size, fbx, options.seekbar_chapters_opacity * seekbar.opacity))
	elseif options.seekbar_chapters == "lines-top" then
		ass:merge(draw_chapters("lines", fay, seekbar.size / 4, fbx, options.seekbar_chapters_opacity * seekbar.opacity))
	elseif options.seekbar_chapters == "lines-bottom" then
		ass:merge(draw_chapters("lines", fay + seekbar.size - (seekbar.size / 4), seekbar.size / 4, fbx, options.seekbar_chapters_opacity * seekbar.opacity))
	end

	-- Elapsed time
	local elapsed_seconds = mp.get_property_native("time-pos")
	ass:new_event()
	ass:append("{\\blur0\\bord0\\shad0\\1c&H"..options.color_background.."\\fn"..config.font.."\\fs"..seekbar.font_size.."\\clip("..foreground_coordinates..")")
	ass:append(ass_opacity(math.min(options.seekbar_opacity + 0.1, 1), seekbar.opacity))
	ass:pos(seekbar.spacing, fay + (seekbar.size / 2))
	ass:an(4)
	ass:append(mp.format_time(elapsed_seconds))
	ass:new_event()
	ass:append("{\\blur0\\bord0\\shad1\\1c&H"..options.color_foreground.."\\4c&H"..options.color_background.."\\fn"..config.font.."\\fs"..seekbar.font_size.."\\iclip("..foreground_coordinates..")")
	ass:append(ass_opacity(math.min(options.seekbar_opacity + 0.1, 1), seekbar.opacity))
	ass:pos(seekbar.spacing, fay + (seekbar.size / 2))
	ass:an(4)
	ass:append(mp.format_time(elapsed_seconds))

	-- Remaining time
	local remaining_seconds = mp.get_property_native("playtime-remaining")
	ass:new_event()
	ass:append("{\\blur0\\bord0\\shad0\\1c&H"..options.color_background.."\\fn"..config.font.."\\fs"..seekbar.font_size.."\\clip("..foreground_coordinates..")")
	ass:append(ass_opacity(math.min(options.seekbar_opacity + 0.1, 1), seekbar.opacity))
	ass:pos(display.width - seekbar.spacing, fay + (seekbar.size / 2))
	ass:an(6)
	ass:append("-"..mp.format_time(remaining_seconds))
	ass:new_event()
	ass:append("{\\blur0\\bord0\\shad1\\1c&H"..options.color_foreground.."\\4c&H"..options.color_background.."\\fn"..config.font.."\\fs"..seekbar.font_size.."\\iclip("..foreground_coordinates..")")
	ass:append(ass_opacity(math.min(options.seekbar_opacity + 0.1, 1), seekbar.opacity))
	ass:pos(display.width - seekbar.spacing, fay + (seekbar.size / 2))
	ass:an(6)
	ass:append("-"..mp.format_time(remaining_seconds))

	if seekbar.proximity == 0 then
		-- Hovered time
		local hovered_seconds = mp.get_property_native("duration") * (cursor.x / display.width)
		local box_half_width_guesstimate = (seekbar.font_size * 4.2) / 2
		ass:new_event()
		ass:append("{\\blur0\\bord0\\shad1\\1c&H"..options.color_foreground.."\\4c&H"..options.color_background.."\\fn"..config.font.."\\fs"..seekbar.font_size.."")
		ass:append(ass_opacity(math.min(options.seekbar_opacity + 0.1, 1)))
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
	local ass = new_ass()

	if cursor.hidden
		or state.border
		or state.duration == nil
		or state.position == nil then
		return ass
	end

	local master_opacity = window_controls.opacity

	if master_opacity == 0 then return ass end

	-- Close button
	local close = elements.window_controls_close
	if close.proximity == 0 then
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
	if maximize.proximity == 0 then
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
	if minimize.proximity == 0 then
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
	local ass = new_ass()

	for _, element in pairs(elements) do
		if element.render ~= nil then
			ass:merge(element.render(element))
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

-- EVENT HANDLERS

function dispatch_event_to_element_below_mouse_button(name, value)
	for _, element in pairs(elements) do
		if element.proximity == 0 then
			local handler = element["on_"..name]
			if handler then handler(element, value) break
			end
		end
	end
end

function handle_file_load()
	state.duration = mp.get_property_number("duration", nil)
	state.filename = mp.get_property_native("filename", "")
end

function handle_event(source, what)
	if source == "mbtn_left" then
		if what == "down" or what == "press" then
			dispatch_event_to_element_below_mouse_button("mbtn_left_down")
		elseif what == "up" then
			dispatch_event_to_element_below_mouse_button("mbtn_left_up")
		end
	elseif source == "mbtn_right" then
		if what == "down" or what == "press" then
			dispatch_event_to_element_below_mouse_button("mbtn_right_down")
		elseif what == "up" then
			dispatch_event_to_element_below_mouse_button("mbtn_right_up")
		end
	elseif source == "mouse_leave" then
		cursor.hidden = true
		update_proximities()
	end

	request_render()
end

function handle_mouse_move()
	cursor.hidden = false
	update_cursor_position()
	request_render()

	-- Restart timer that hides UI when mouse is autohidden
	if options.autohide then
		state.cursor_autohide_timer:kill()
		state.cursor_autohide_timer:resume()
	end
end

function handle_border_change(_, border)
	state.border = border
	-- Sets 1px bottom border for bars in no-border mode
	config.bar_bottom_border = (not border and 1) or 0

	request_render()
end

function event_handler(source, what)
	return function() handle_event(source, what) end
end

function state_setter(name)
	return function(_, value) state[name] = value end
end

-- CHAPTERS

-- Parse `chapter_ranges` option into workable data structure

for _, chapter_range_definition in ipairs(split(options.chapter_ranges, ",")) do
	local definition_parts = split(chapter_range_definition, ":")
	local start_end_pair = split(definition_parts[1], '-')
	local chapter_range = {
		start_str = start_end_pair[1],
		end_str = start_end_pair[2] or start_end_pair[1],
		color = definition_parts[2],
		opacity = tonumber(definition_parts[3]),
	}
	chapter_range["serialize"] = function (chapter, last_range)
		if not chapter.title then return end
		if chapter.title:find(chapter_range.end_str) then
			if last_range then
				last_range["end"] = chapter.time
				return last_range
			else
				return {
					["start"] = 0,
					["end"] = chapter.time
				}
			end
		elseif chapter.title:find(chapter_range.start_str) then
			return {
				["start"] = chapter.time,
				["end"] = chapter.time + 0.1
			}
		end
	end

	state.chapter_ranges = state.chapter_ranges or {}
	state.chapter_ranges[#state.chapter_ranges + 1] = chapter_range
end

function parse_chapters(name, chapters)
	if not chapters then return end

	-- Reset custom ranges
	for _, chapter_range in ipairs(state.chapter_ranges or {}) do
		chapter_range.ranges = {}
	end

	local basic_chapters = {}

	for _, chapter in ipairs(chapters) do
		local is_chapter_range = false

		for _, chapter_range in ipairs(state.chapter_ranges or {}) do
			local last_range = chapter_range.ranges[#chapter_range.ranges]
			local new_range = chapter_range.serialize(chapter, last_range)
			if new_range then
				is_chapter_range = true
				if new_range ~= last_range then
					chapter_range.ranges[#chapter_range.ranges + 1] = new_range
				end
			end
		end

		if not is_chapter_range then
			basic_chapters[#basic_chapters + 1] = chapter
		end
	end

	state.chapters = basic_chapters
end

-- HOOKS

mp.register_event("file-loaded", handle_file_load)

mp.observe_property("chapter-list", "native", parse_chapters)
mp.observe_property("fullscreen", "bool", state_setter("fullscreen"))
mp.observe_property("border", "bool", handle_border_change)
mp.observe_property("window-maximized", "bool", state_setter("maximized"))
mp.observe_property("idle-active", "bool", state_setter("idle"))
mp.observe_property("pause", "bool", state_setter("paused"))
mp.observe_property("playback-time", "number", function(name, val)
	state.position = val
	request_render()
end)
mp.observe_property("osd-dimensions", "native", function(name, val)
	update_display_dimensions()
	request_render()
end)

-- CONTROLS

-- mouse movement bindings
mp.set_key_bindings({
	{"mouse_move", handle_mouse_move},
	{"mouse_leave", event_handler("mouse_leave", nil)},
}, "mouse_movement", "force")
mp.enable_key_bindings("mouse_movement", "allow-vo-dragging+allow-hide-cursor")

-- mouse button bindings
mp.set_key_bindings({
	{"mbtn_left", event_handler("mbtn_left", "up"), event_handler("mbtn_left", "down")},
	{"mbtn_right", event_handler("mbtn_right", "up"), event_handler("mbtn_right", "down")},
	{"mbtn_left_dbl", "ignore"},
	{"mbtn_right_dbl", "ignore"},
}, "mouse_buttons", "force")

-- User bindable functions
mp.add_key_binding(nil, 'toggleprogressbar', function()
	elements.progressbar.enabled = not elements.progressbar.enabled
	request_render()
end)
mp.add_key_binding(nil, 'toggleseekbar', function()
	if elements.seekbar.opacity < 0.5 then
		cursor.hidden = false
		elements.seekbar.opacity = 1
	else
		cursor.hidden = true
		elements.seekbar.opacity = 0
	end
	request_render()
end)
