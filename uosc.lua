--[[

uosc 1.0.0 https://github.com/darsain/uosc

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
title=no                      # display window title (filename) in no-border mode
progressbar=yes               # show thin discrete progress at the bottom
progressbar_fullscreen=       # defaults to `progressbar`
progressbar_size=4            # progressbar size in pixels
progressbar_size_fullscreen=  # defaults to `progressbar_size`
seekbar_size=40               # seekbar size in pixels
seekbar_size_fullscreen=0     # defaults to `seekbar_size`
min_proximity=60              # element<>cursor proximity below which opacity equals 1
max_proximity=120             # element<>cursor proximity above which opacity equals 0
bar_opacity=0.8               # max opacity of progress and seek bars
bar_color_foreground=FFFFFF   # BBGGRR - BLUE GREEN RED hex code
bar_color_background=000000   # BBGGRR - BLUE GREEN RED hex code
```

Available keybindings (place into `input.conf`):

```
Key  script-binding uosc/toggleprogressbar
```

]]

local assdraw = require 'mp.assdraw'
local opt = require 'mp.options'
local osd = mp.create_osd_overlay("ass-events")

local options = {
	title = false,                   -- display window title (filename) in no-border mode
	progressbar = true,              -- show thin discrete progress at the bottom
	progressbar_fullscreen = "",     -- defaults to `progressbar`
	progressbar_size = 4,            -- progressbar size in pixels
	progressbar_size_fullscreen = 0, -- defaults to `progressbar_size` when 0
	seekbar_size = 40,               -- seekbar size in pixels
	seekbar_size_fullscreen = 0,     -- defaults to `seekbar_size` when 0
	min_proximity = 60,              -- proximity below which opacity equals 1
	max_proximity = 120,             -- proximity above which opacity equals 0
	bar_opacity = 0.8,               -- max opacity of progress and seek bars
	bar_color_foreground = "FFFFFF", -- BBGGRR - BLUE GREEN RED hex code
	bar_color_background = "000000", -- BBGGRR - BLUE GREEN RED hex code
}
opt.read_options(options, "uosc")
local config = {
	render_delay = 0.03,        -- sets rendering frequency
	font = mp.get_property("options/osd-font"),
}
local state = {
	filename = "",
	border = mp.get_property("border"),
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
local window_controls = {
	button_width = 46,
	button_height = 40,
	icon_opacity = 0.8,
	background_opacity = 0.8,
}
local infinity = 1e309
local elements = {
	progressbar = {
		enabled = true, -- flag set manually through runtime keybinds
		show = true,    -- consolidation of `progressbar` and `progressbar_fullscreen`
		size = 0, -- dynamic consolidation of `seekbar_size` and `seekbar_size_fullscreen`
		ax = 0, ay = 0, bx = 0, by = 0, -- calculated on screen dimensions init/update
		render = function(ass) render_progressbar(ass) end,
	},
	seekbar = {
		interactive = true, -- listen for mouse events and don't disable window dragging
		size = 0, -- dynamic consolidation of `seekbar_size` and `seekbar_size_fullscreen`
		ax = 0, ay = 0, bx = 0, by = 0, -- calculated on screen dimensions init/update
		proximity = infinity, opacity = 0,  -- calculated on mouse movement
		render = function(ass) render_seekbar(ass) end,
		on_mbtn_left_down = function()
			mp.commandv("seek", ((cursor.x / display.width) * 100), "absolute-percent+exact")
		end
	},
	window_controls = {
		ax = 0, ay = 0, bx = 0, by = 0, -- calculated on screen dimensions init/update
		proximity = infinity, opacity = 0,   -- calculated on mouse movement
		render = function(ass) render_window_controls(ass) end,
	},
	window_controls_minimize = {
		interactive = true, -- listen for mouse events and don't disable window dragging
		ax = 0, ay = 0, bx = 0, by = 0, -- calculated on screen dimensions init/update
		proximity = infinity, opacity = 0,  -- calculated on mouse movement
		on_mbtn_left_down = function() mp.commandv("cycle", "window-minimized") end
	},
	window_controls_maximize = {
		interactive = true, -- listen for mouse events and don't disable window dragging
		ax = 0, ay = 0, bx = 0, by = 0, -- calculated on screen dimensions init/update
		proximity = infinity, opacity = 0,  -- calculated on mouse movement
		on_mbtn_left_down = function() mp.commandv("cycle", "window-maximized") end
	},
	window_controls_close = {
		interactive = true, -- listen for mouse events and don't disable window dragging
		ax = 0, ay = 0, bx = 0, by = 0, -- calculated on screen dimensions init/update
		proximity = infinity, opacity = 0,  -- calculated on mouse movement
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

	-- Update element rectangles

	-- Seekbar
	elements.seekbar.size = (state.fullscreen or state.maximized) and (options.seekbar_size_fullscreen ~= 0)
		and options.seekbar_size_fullscreen
		or options.seekbar_size
	elements.seekbar.ax = 0
	elements.seekbar.ay = display.height - elements.seekbar.size
	elements.seekbar.bx = display.width
	elements.seekbar.by = display.height

	local window_control_buttons_ax = display.width - (window_controls.button_width * 3)

	-- Window controls
	elements.window_controls.ax = options.title and 0 or window_control_buttons_ax
	elements.window_controls.ay = 0
	elements.window_controls.bx = display.width
	elements.window_controls.by = window_controls.button_height

	-- Window controls minimize button
	elements.window_controls_minimize.ax = window_control_buttons_ax
	elements.window_controls_minimize.ay = 0
	elements.window_controls_minimize.bx = elements.window_controls_minimize.ax + window_controls.button_width
	elements.window_controls_minimize.by = window_controls.button_height

	-- Window controls maximize button
	elements.window_controls_maximize.ax = elements.window_controls_minimize.bx
	elements.window_controls_maximize.ay = 0
	elements.window_controls_maximize.bx = elements.window_controls_maximize.ax + window_controls.button_width
	elements.window_controls_maximize.by = window_controls.button_height

	-- Window controls close button
	elements.window_controls_close.ax = elements.window_controls_maximize.bx
	elements.window_controls_close.ay = 0
	elements.window_controls_close.bx = elements.window_controls_close.ax + window_controls.button_width
	elements.window_controls_close.by = window_controls.button_height

	-- Update progressbar rendering config
	elements.progressbar.size = (state.fullscreen or state.maximized) and (options.progressbar_size_fullscreen ~= 0)
		and options.progressbar_size_fullscreen
		or options.progressbar_size

	elements.progressbar.show = state.fullscreen and options.progressbar_fullscreen ~= ""
		and options.progressbar_fullscreen
		or options.progressbar
end

function update_cursor_position()
	local x, y = mp.get_mouse_pos()
	cursor.x = x
	cursor.y = y
	update_proximities()
end

function update_proximities()
	local max = options.max_proximity
	local min = options.min_proximity
	local range = max - min
	local should_enable_mouse_bindings = false

	-- Calculates proximities and opacities for defined elements
	for _, element in pairs(elements) do
		-- Only update proximity and opacity for elements that care about it
		if element.proximity ~= nil then
			if cursor.hidden then
				element.proximity = infinity
				element.opacity = 0
			else
				element.proximity = get_point_to_rectangle_proximity(cursor, element)
				element.opacity = 1 - math.min(math.max(element.proximity - min, 0), range) / range
				should_enable_mouse_bindings = should_enable_mouse_bindings or (element.interactive and element.proximity == 0)
			end
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

--  ELEMENT RENDERERS

function render_progressbar(ass)
	local bar = elements.progressbar

	if not bar.enabled
		or not bar.show
		or state.duration == nil
		or state.position == nil then
		return
	end

	local progress = state.position / state.duration
	local master_opacity = 1 - math.min(elements.seekbar.opacity + elements.seekbar.opacity * 0.6, 1)

	-- Top border
	ass:new_event()
	ass:append("{\\blur0\\bord0\\1c&H"..options.bar_color_background.."}")
	ass_append_opacity(ass, math.max(options.bar_opacity - 0.1, 0), master_opacity)
	ass:pos(0, 0)
	ass:draw_start()
	ass:rect_cw(0, display.height - bar.size - 1, display.width, display.height - bar.size)
	ass:draw_stop()

	-- Background
	ass:new_event()
	ass:append("{\\blur0\\bord0\\1c&H"..options.bar_color_background.."}")
	ass_append_opacity(ass, math.max(options.bar_opacity - 0.1, 0), master_opacity)
	ass:pos(0, 0)
	ass:draw_start()
	ass:rect_cw(display.width * progress, display.height - bar.size, display.width, display.height)
	ass:draw_stop()

	-- Progress
	ass:new_event()
	ass:append("{\\blur0\\bord0\\1c&H"..options.bar_color_foreground.."}")
	ass_append_opacity(ass, options.bar_opacity, master_opacity)
	ass:pos(0, 0)
	ass:draw_start()
	ass:rect_cw(0, display.height - bar.size, display.width * progress, display.height)
	ass:draw_stop()
end

function render_seekbar(ass)
	local bar = elements.seekbar

	if cursor.hidden
		or bar.opacity == 0
		or state.duration == nil
		or state.position == nil then
		return
	end

	local progress = state.position / state.duration
	local spacing = math.ceil(bar.size * 0.27)
	local fontsize = math.floor(bar.size - (spacing * 2))

	-- Top border
	ass:new_event()
	ass:append("{\\blur0\\bord0\\1c&H"..options.bar_color_background.."}")
	ass_append_opacity(ass, math.max(options.bar_opacity - 0.1, 0), bar.opacity)
	ass:pos(0, 0)
	ass:draw_start()
	ass:rect_cw(0, display.height - bar.size - 1, display.width, display.height - bar.size)
	ass:draw_stop()

	-- Background
	ass:new_event()
	ass:append("{\\blur0\\bord0\\1c&H"..options.bar_color_background.."}")
	ass_append_opacity(ass, math.max(options.bar_opacity - 0.1, 0), bar.opacity)
	ass:pos(0, 0)
	ass:draw_start()
	ass:rect_cw(display.width * progress, display.height - bar.size, display.width, display.height)
	ass:draw_stop()

	-- Progress
	ass:new_event()
	ass:append("{\\blur0\\bord0\\1c&H"..options.bar_color_foreground.."}")
	ass_append_opacity(ass, options.bar_opacity, bar.opacity)
	ass:pos(0, 0)
	ass:draw_start()
	ass:rect_cw(0, display.height - bar.size, display.width * progress, display.height)
	ass:draw_stop()

	-- Elapsed time
	local elapsed = mp.get_property_native("time-pos")
	local elapsed_clip_coordinates = "0,"..(display.height - bar.size)..","..(display.width * progress)..","..display.height
	ass:new_event()
	ass:append("{\\blur0\\bord0\\shad0\\1c&H"..options.bar_color_background.."\\fn"..config.font.."\\fs"..fontsize.."\\clip("..elapsed_clip_coordinates..")")
	ass_append_opacity(ass, math.min(options.bar_opacity + 0.1, 1), bar.opacity)
	ass:pos(spacing, display.height - (bar.size / 2))
	ass:an(4)
	ass:append(mp.format_time(elapsed))
	ass:new_event()
	ass:append("{\\blur0\\bord0\\shad1\\1c&H"..options.bar_color_foreground.."\\4c&H"..options.bar_color_background.."\\fn"..config.font.."\\fs"..fontsize.."\\iclip("..elapsed_clip_coordinates..")")
	ass_append_opacity(ass, math.min(options.bar_opacity + 0.1, 1), bar.opacity)
	ass:pos(spacing, display.height - (bar.size / 2))
	ass:an(4)
	ass:append(mp.format_time(elapsed))

	-- Remaining time
	local remaining = mp.get_property_native("playtime-remaining")
	local remaining_clip_coordinates = display.width * progress..","..(display.height - bar.size)..","..display.width..","..display.height
	ass:new_event()
	ass:append("{\\blur0\\bord0\\shad0\\1c&H"..options.bar_color_background.."\\fn"..config.font.."\\fs"..fontsize.."\\iclip("..remaining_clip_coordinates..")")
	ass_append_opacity(ass, math.min(options.bar_opacity + 0.1, 1), bar.opacity)
	ass:pos(display.width - spacing, display.height - (bar.size / 2))
	ass:an(6)
	ass:append("-"..mp.format_time(remaining))
	ass:new_event()
	ass:append("{\\blur0\\bord0\\shad1\\1c&H"..options.bar_color_foreground.."\\4c&H"..options.bar_color_background.."\\fn"..config.font.."\\fs"..fontsize.."\\clip("..remaining_clip_coordinates..")")
	ass_append_opacity(ass, math.min(options.bar_opacity + 0.1, 1), bar.opacity)
	ass:pos(display.width - spacing, display.height - (bar.size / 2))
	ass:an(6)
	ass:append("-"..mp.format_time(remaining))

	if bar.proximity == 0 then
		-- Hovered time
		local hovered = mp.get_property_native("duration") * (cursor.x / display.width)
		ass:new_event()
		ass:append("{\\blur0\\bord0\\shad1\\1c&H"..options.bar_color_foreground.."\\4c&H"..options.bar_color_background.."\\fn"..config.font.."\\fs"..fontsize.."")
		ass_append_opacity(ass, math.min(options.bar_opacity + 0.1, 1))
		ass:pos(cursor.x, display.height - bar.size)
		ass:an(2)
		ass:append(mp.format_time(hovered))

		-- Cursor line
		ass:new_event()
		ass:append("{\\blur0\\bord0\\xshad-1\\yshad0\\1c&H"..options.bar_color_foreground.."\\4c&H"..options.bar_color_background.."}")
		ass_append_opacity(ass, 0.2)
		ass:pos(0, 0)
		ass:draw_start()
		ass:rect_cw(cursor.x, display.height - bar.size, cursor.x + 1, display.height)
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
		ass_append_opacity(ass, window_controls.background_opacity, master_opacity)
		ass:pos(0, 0)
		ass:draw_start()
		ass:rect_cw(close.ax, close.ay, close.bx, close.by)
		ass:draw_stop()
	end
	ass:new_event()
	ass:append("{\\blur0\\bord1\\shad1\\3c&HFFFFFF\\4c&H000000}")
	ass_append_opacity(ass, window_controls.icon_opacity, master_opacity)
	ass:pos(close.ax + (window_controls.button_width / 2), (window_controls.button_height / 2))
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
		ass:append("{\\blur0\\bord0\\1c&H000000}")
		ass_append_opacity(ass, window_controls.background_opacity, master_opacity)
		ass:pos(0, 0)
		ass:draw_start()
		ass:rect_cw(maximize.ax, maximize.ay, maximize.bx, maximize.by)
		ass:draw_stop()
	end
	ass:new_event()
	ass:append("{\\blur0\\bord2\\shad0\\1c\\3c&H000000}")
	ass_append_opacity(ass, {[3] = window_controls.icon_opacity}, master_opacity)
	ass:pos(maximize.ax + (window_controls.button_width / 2), (window_controls.button_height / 2))
	ass:draw_start()
	ass:rect_cw(-4, -4, 6, 6)
	ass:draw_stop()
	ass:new_event()
	ass:append("{\\blur0\\bord2\\shad0\\1c\\3c&HFFFFFF}")
	ass_append_opacity(ass, {[3] = window_controls.icon_opacity}, master_opacity)
	ass:pos(maximize.ax + (window_controls.button_width / 2), (window_controls.button_height / 2))
	ass:draw_start()
	ass:rect_cw(-5, -5, 5, 5)
	ass:draw_stop()

	-- Minimize button
	local minimize = elements.window_controls_minimize
	if minimize.proximity == 0 then
		-- Background on hover
		ass:new_event()
		ass:append("{\\blur0\\bord0\\1c&H000000}")
		ass_append_opacity(ass, window_controls.background_opacity, master_opacity)
		ass:pos(0, 0)
		ass:draw_start()
		ass:rect_cw(minimize.ax, minimize.ay, minimize.bx, minimize.by)
		ass:draw_stop()
	end
	ass:new_event()
	ass:append("{\\blur0\\bord1\\shad1\\3c&HFFFFFF\\4c&H000000}")
	ass_append_opacity(ass, window_controls.icon_opacity, master_opacity)
	ass:append("{\\1a&HFF&}")
	ass:pos(minimize.ax + (window_controls.button_width / 2), (window_controls.button_height / 2))
	ass:draw_start()
	ass:move_to(-5, 0)
	ass:line_to(5, 0)
	ass:draw_stop()

	-- Window title
	if options.title then
		local spacing = math.ceil(window_controls.button_height * 0.25)
		local fontsize = math.floor(window_controls.button_height - (spacing * 2))
		local clip_coordinates = "0,0,"..(minimize.ax - 10)..","..window_controls.button_height

		ass:new_event()
		ass:append("{\\blur0\\bord0\\shad1\\1c&HFFFFFF\\4c&H000000\\fn"..config.font.."\\fs"..fontsize.."\\clip("..clip_coordinates..")")
		ass_append_opacity(ass, 1, master_opacity)
		ass:pos(0 + spacing, window_controls.button_height / 2)
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

function dispatch_mouse_button_event_to_elements(name, value)
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
			dispatch_mouse_button_event_to_elements("mbtn_left_down")
		elseif what == "up" then
			dispatch_mouse_button_event_to_elements("mbtn_left_up")
		end
	elseif source == "mbtn_right" then
		if what == "down" or what == "press" then
			dispatch_mouse_button_event_to_elements("mbtn_right_down")
		elseif what == "up" then
			dispatch_mouse_button_event_to_elements("mbtn_right_up")
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