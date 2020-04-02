--[[

uosc 1.0.5 | https://github.com/darsain/uosc

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
seekbar_chapters=
# seekbar chapters indicator opacity
seekbar_chapters_opacity=0.3

# progressbar size in pixels, 0 to disable
progressbar_size=1
# same as ^ but when in fullscreen
progressbar_size_fullscreen=0
# progressbar opacity
progressbar_opacity=0.8
# progressbar chapters indicator style: lines, lines-top, lines-bottom
progressbar_chapters=
# progressbar chapters indicator opacity
progressbar_chapters_opacity=0.2

# proximity below which opacity equals 1
min_proximity=40
# proximity above which opacity equals 0
max_proximity=120
# BBGGRR - BLUE GREEN RED hex code
color_foreground=FFFFFF
# BBGGRR - BLUE GREEN RED hex code
color_background=000000
```

Available keybindings (place into `input.conf`):

```
Key  script-binding uosc/toggleprogressbar
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
	title = false, -- display window title (filename) in no-border mode

	seekbar_size = 40,              -- seekbar size in pixels, 0 to disable
	seekbar_size_fullscreen = 60,   -- same as ^ but when in fullscreen
	seekbar_opacity = 0.8,          -- seekbar opacity when fully visible
	seekbar_chapters = "",          -- seekbar chapters indicator style: dots, lines, lines-top, lines-bottom
	seekbar_chapters_opacity = 0.3, -- seekbar chapters indicator opacity

	progressbar_size = 1,               -- progressbar size in pixels, 0 to disable
	progressbar_size_fullscreen = 0,    -- same as ^ but when in fullscreen
	progressbar_opacity = 0.8,          -- progressbar opacity
	progressbar_chapters = "",          -- progressbar chapters indicator style: lines, lines-top, lines-bottom
	progressbar_chapters_opacity = 0.2, -- progressbar chapters indicator opacity

	min_proximity = 40,              -- proximity below which opacity equals 1
	max_proximity = 120,             -- proximity above which opacity equals 0
	color_foreground = "FFFFFF", -- BBGGRR - BLUE GREEN RED hex code
	color_background = "000000", -- BBGGRR - BLUE GREEN RED hex code
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
local state = {
	filename = "",
	border = mp.get_property_native("border"),
	duration = nil,
	position = nil,
	paused = false,
	fullscreen = mp.get_property_native("fullscreen"),
	maximized = mp.get_property_native("window-maximized"),
	render_timer = nil,
	render_last_time = 0,
	mouse_bindings_enabled = false
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
		render = function(ass) render_progressbar(ass) end,
	},
	seekbar = {
		interactive = true, -- listen for mouse events and disable window dragging
		size = 0, -- consolidation of `seekbar_size` and `seekbar_size_fullscreen` options, set in `on_display_resize` lsitener below
		ax = 0, ay = 0, bx = 0, by = 0, -- rectangle coordinates calculated in `on_display_resize` lsitener
		proximity = infinity, opacity = 0,  -- calculated on mouse movement
		on_mouse_move = function(element) update_element_cursor_proximity(element) end,
		on_display_resize = function(element)
			if state.fullscreen or state.maximized then
				element.size = options.seekbar_size_fullscreen
			else
				element.size = options.seekbar_size
			end
			element.interactive = element.size > 0
			element.ax = 0
			element.ay = display.height - element.size
			element.bx = display.width
			element.by = display.height
		end,
		on_mbtn_left_down = function()
			mp.commandv("seek", ((cursor.x / display.width) * 100), "absolute-percent+exact")
		end,
		render = function(ass) render_seekbar(ass) end,
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
		render = function(ass) render_window_controls(ass) end,
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

function get_point_to_rectangle_proximity(point, rect)
	local dx = math.max(rect.ax - point.x, 0, point.x - rect.bx + 1)
	local dy = math.max(rect.ay - point.y, 0, point.y - rect.by + 1)
	return math.sqrt(dx*dx + dy*dy);
end

function to_alpha(opacity, fraction)
	fraction = fraction ~= nil and fraction or 1
	return 255 - math.ceil(255 * opacity * fraction)
end

function ass_append_opacity(ass, opacity, fraction)
	if type(opacity) == "number" then
		ass:append(string.format("{\\alpha&H%X&}", to_alpha(opacity, fraction)))
	else
		ass:append(string.format(
			"{\\1a&H%X&\\2a&H%X&\\3a&H%X&\\4a&H%X&}",
			to_alpha(opacity[1] or 0, fraction),
			to_alpha(opacity[2] or 0, fraction),
			to_alpha(opacity[3] or 0, fraction),
			to_alpha(opacity[4] or 0, fraction)
		))
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

function draw_chapters(ass, style, chapter_y, size, foreground_cutoff, opacity)
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
			ass_append_opacity(ass, opacity)
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
end

--  ELEMENT RENDERERS

function render_progressbar(ass)
	local bar = elements.progressbar

	if not bar.enabled
		or bar.size == 0
		or state.duration == nil
		or state.position == nil then
		return
	end

	local progress = state.position / state.duration
	-- Progressbar opacity is inversely proportional to seekbar opacity
	local master_opacity = elements.seekbar.size > 0
		and (1 - math.min(elements.seekbar.opacity / 0.4, 1))
		or 1

	if master_opacity == 0 then
		return
	end

	local ax = 0
	local ay = display.height - bar.size
	local bx = display.width * progress
	local by = display.height

	-- Background
	ass:new_event()
	ass:append("{\\blur0\\bord0\\1c&H"..options.color_background.."\\iclip("..ax..","..ay..","..bx..","..by..")}")
	ass_append_opacity(ass, math.max(options.progressbar_opacity - 0.1, 0), master_opacity)
	ass:pos(0, 0)
	ass:draw_start()
	ass:rect_cw(ax, ay - 1, display.width, by)
	ass:draw_stop()

	-- Progress
	ass:new_event()
	ass:append("{\\blur0\\bord0\\1c&H"..options.color_foreground.."}")
	ass_append_opacity(ass, options.progressbar_opacity, master_opacity)
	ass:pos(0, 0)
	ass:draw_start()
	ass:rect_cw(ax, ay, bx, by)
	ass:draw_stop()

	-- Chapters
	if options.progressbar_chapters == "lines" then
		draw_chapters(ass, "lines", ay, bar.size, bx, options.progressbar_chapters_opacity * master_opacity)
	elseif options.progressbar_chapters == "lines-top" then
		draw_chapters(ass, "lines", ay, bar.size / 2, bx, options.progressbar_chapters_opacity * master_opacity)
	elseif options.progressbar_chapters == "lines-bottom" then
		draw_chapters(ass, "lines", ay + bar.size - (bar.size / 2), bar.size / 2, bx, options.progressbar_chapters_opacity * master_opacity)
	end
end

function render_seekbar(ass)
	local bar = elements.seekbar

	if cursor.hidden
		or bar.size == 0
		or bar.opacity == 0
		or state.duration == nil
		or state.position == nil then
		return
	end

	local progress = state.position / state.duration
	local spacing = math.ceil(bar.size * 0.27)
	local fontsize = math.floor(bar.size - (spacing * 2))

	local ax = 0
	local ay = display.height - bar.size
	local bx = display.width * progress
	local by = display.height
	local elapsed_bar_coordinates = ax..","..ay..","..bx..","..by

	-- Background
	ass:new_event()
	ass:append("{\\blur0\\bord0\\1c&H"..options.color_background.."\\iclip("..elapsed_bar_coordinates..")}")
	ass_append_opacity(ass, math.max(options.seekbar_opacity - 0.1, 0), bar.opacity)
	ass:pos(0, 0)
	ass:draw_start()
	ass:rect_cw(0, ay - 1, display.width, by)
	ass:draw_stop()

	-- Progress
	ass:new_event()
	ass:append("{\\blur0\\bord0\\1c&H"..options.color_foreground.."}")
	ass_append_opacity(ass, options.seekbar_opacity, bar.opacity)
	ass:pos(0, 0)
	ass:draw_start()
	ass:rect_cw(ax, ay, bx, by)
	ass:draw_stop()

	-- Chapters
	if options.seekbar_chapters == "dots" then
		draw_chapters(ass, "dots", ay + 6, 6, bx, options.seekbar_chapters_opacity * bar.opacity)
	elseif options.seekbar_chapters == "lines" then
		draw_chapters(ass, "lines", ay, bar.size, bx, options.seekbar_chapters_opacity * bar.opacity)
	elseif options.seekbar_chapters == "lines-top" then
		draw_chapters(ass, "lines", ay, bar.size / 4, bx, options.seekbar_chapters_opacity * bar.opacity)
	elseif options.seekbar_chapters == "lines-bottom" then
		draw_chapters(ass, "lines", ay + bar.size - (bar.size / 4), bar.size / 4, bx, options.seekbar_chapters_opacity * bar.opacity)
	end

	-- Elapsed time
	local elapsed_seconds = mp.get_property_native("time-pos")
	ass:new_event()
	ass:append("{\\blur0\\bord0\\shad0\\1c&H"..options.color_background.."\\fn"..config.font.."\\fs"..fontsize.."\\clip("..elapsed_bar_coordinates..")")
	ass_append_opacity(ass, math.min(options.seekbar_opacity + 0.1, 1), bar.opacity)
	ass:pos(spacing, ay + (bar.size / 2))
	ass:an(4)
	ass:append(mp.format_time(elapsed_seconds))
	ass:new_event()
	ass:append("{\\blur0\\bord0\\shad1\\1c&H"..options.color_foreground.."\\4c&H"..options.color_background.."\\fn"..config.font.."\\fs"..fontsize.."\\iclip("..elapsed_bar_coordinates..")")
	ass_append_opacity(ass, math.min(options.seekbar_opacity + 0.1, 1), bar.opacity)
	ass:pos(spacing, ay + (bar.size / 2))
	ass:an(4)
	ass:append(mp.format_time(elapsed_seconds))

	-- Remaining time
	local remaining_seconds = mp.get_property_native("playtime-remaining")
	ass:new_event()
	ass:append("{\\blur0\\bord0\\shad0\\1c&H"..options.color_background.."\\fn"..config.font.."\\fs"..fontsize.."\\clip("..elapsed_bar_coordinates..")")
	ass_append_opacity(ass, math.min(options.seekbar_opacity + 0.1, 1), bar.opacity)
	ass:pos(display.width - spacing, ay + (bar.size / 2))
	ass:an(6)
	ass:append("-"..mp.format_time(remaining_seconds))
	ass:new_event()
	ass:append("{\\blur0\\bord0\\shad1\\1c&H"..options.color_foreground.."\\4c&H"..options.color_background.."\\fn"..config.font.."\\fs"..fontsize.."\\iclip("..elapsed_bar_coordinates..")")
	ass_append_opacity(ass, math.min(options.seekbar_opacity + 0.1, 1), bar.opacity)
	ass:pos(display.width - spacing, ay + (bar.size / 2))
	ass:an(6)
	ass:append("-"..mp.format_time(remaining_seconds))

	if bar.proximity == 0 then
		-- Hovered time
		local hovered_seconds = mp.get_property_native("duration") * (cursor.x / display.width)
		local box_half_width_guesstimate = (fontsize * 4.2) / 2
		ass:new_event()
		ass:append("{\\blur0\\bord0\\shad1\\1c&H"..options.color_foreground.."\\4c&H"..options.color_background.."\\fn"..config.font.."\\fs"..fontsize.."")
		ass_append_opacity(ass, math.min(options.seekbar_opacity + 0.1, 1))
		ass:pos(math.min(math.max(cursor.x, box_half_width_guesstimate), display.width - box_half_width_guesstimate), ay)
		ass:an(2)
		ass:append(mp.format_time(hovered_seconds))

		-- Cursor line
		ass:new_event()
		ass:append("{\\blur0\\bord0\\xshad-1\\yshad0\\1c&H"..options.color_foreground.."\\4c&H"..options.color_background.."}")
		ass_append_opacity(ass, 0.2)
		ass:pos(0, 0)
		ass:draw_start()
		ass:rect_cw(cursor.x, ay, cursor.x + 1, by)
		ass:draw_stop()
	end
end

function render_window_controls(ass)
	if cursor.hidden
		or state.border
		or state.duration == nil
		or state.position == nil then
		return
	end

	local master_opacity = elements.window_controls.opacity

	if master_opacity == 0 then return end

	-- Close button
	local close = elements.window_controls_close
	if close.proximity == 0 then
		-- Background on hover
		ass:new_event()
		ass:append("{\\blur0\\bord0\\1c&H2311e8}")
		ass_append_opacity(ass, config.window_controls.background_opacity, master_opacity)
		ass:pos(0, 0)
		ass:draw_start()
		ass:rect_cw(close.ax, close.ay, close.bx, close.by)
		ass:draw_stop()
	end
	ass:new_event()
	ass:append("{\\blur0\\bord1\\shad1\\3c&HFFFFFF\\4c&H000000}")
	ass_append_opacity(ass, config.window_controls.icon_opacity, master_opacity)
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
		ass_append_opacity(ass, config.window_controls.background_opacity, master_opacity)
		ass:pos(0, 0)
		ass:draw_start()
		ass:rect_cw(maximize.ax, maximize.ay, maximize.bx, maximize.by)
		ass:draw_stop()
	end
	ass:new_event()
	ass:append("{\\blur0\\bord2\\shad0\\1c\\3c&H000000}")
	ass_append_opacity(ass, {[3] = config.window_controls.icon_opacity}, master_opacity)
	ass:pos(maximize.ax + (config.window_controls.button_width / 2), (config.window_controls.height / 2))
	ass:draw_start()
	ass:rect_cw(-4, -4, 6, 6)
	ass:draw_stop()
	ass:new_event()
	ass:append("{\\blur0\\bord2\\shad0\\1c\\3c&HFFFFFF}")
	ass_append_opacity(ass, {[3] = config.window_controls.icon_opacity}, master_opacity)
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
		ass_append_opacity(ass, config.window_controls.background_opacity, master_opacity)
		ass:pos(0, 0)
		ass:draw_start()
		ass:rect_cw(minimize.ax, minimize.ay, minimize.bx, minimize.by)
		ass:draw_stop()
	end
	ass:new_event()
	ass:append("{\\blur0\\bord1\\shad1\\3c&HFFFFFF\\4c&H000000}")
	ass_append_opacity(ass, config.window_controls.icon_opacity, master_opacity)
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
		local clip_coordinates = "0,0,"..(minimize.ax - 10)..","..config.window_controls.height

		ass:new_event()
		ass:append("{\\q2\\blur0\\bord0\\shad1\\1c&HFFFFFF\\4c&H000000\\fn"..config.font.."\\fs"..fontsize.."\\clip("..clip_coordinates..")")
		ass_append_opacity(ass, 1, master_opacity)
		ass:pos(0 + spacing, config.window_controls.height / 2)
		ass:an(4)
		ass:append(state.filename)
	end
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
	ass.scale = 1

	for _, element in pairs(elements) do
		if element.render ~= nil then
			element.render(ass)
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
			if handler ~= nil and element.proximity == 0 then
				handler(value)
				break
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
end

function handle_toggle_progress()
	elements.progressbar.enabled = not elements.progressbar.enabled
end

function event_handler(source, what)
	return function() handle_event(source, what) end
end

function state_setter(name)
	return function(_, value) state[name] = value end
end

-- HOOKS

mp.register_event("file-loaded", handle_file_load)

mp.observe_property("chapter-list", "native", state_setter("chapters"))
mp.observe_property("fullscreen", "bool", state_setter("fullscreen"))
mp.observe_property("border", "bool", state_setter("border"))
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

-- User defined keybindings
mp.add_key_binding(nil, 'toggleprogressbar', handle_toggle_progress)
