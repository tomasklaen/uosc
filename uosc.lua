--[[

uosc 2.1.0 - 2020-Apr-13 | https://github.com/darsain/uosc

Minimalistic cursor proximity based UI for MPV player.

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
# when video position is changed externally (e.g. hotkeys), flash the timeline
# for this amount of time, set to 0 to disable
timeline_flash_duration=300

# timeline chapters indicator style: dots, lines, lines-top, lines-bottom
# set to empty to disable
chapters=dots
# timeline chapters indicator opacity
chapters_opacity=0.3

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
# when volume is changed externally (e.g. hotkeys), flash the volume controls
# for this amount of time, set to 0 to disable
volume_flash_duration=300

# menu
menu_item_height=40
menu_item_height_fullscreen=50
menu_opacity=0.9

# pause video on clicks shorter than this number of milliseconds
# enables you to use left mouse button for both dragging and pausing the video
# I recommend a duration of 120, leave at 0 to disable
pause_on_click_shorter_than=0
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
# display window title (filename) in top window controls bar in no-border mode
title=no
# load first file when calling next on last file in a directory and vice versa
directory_navigation_loops=no
# file types to display in file explorer when navigating media files
media_types=3gp,avi,bmp,flac,flv,gif,h264,h265,jpeg,jpg,m4a,m4v,mid,midi,mkv,mov,mp3,mp4,mp4a,mp4v,mpeg,mpg,oga,ogg,ogm,ogv,opus,png,rmvb,svg,tif,tiff,wav,weba,webm,webp,wma,wmv
# file types to display in file explorer when loading external subtitles
subtitle_types=aqt,gsub,jss,sub,ttxt,pjs,psb,rt,smi,slt,ssf,srt,ssa,ass,usf,idx,vt
# used to approximate text width
# if you are using some wide font and see a lot of right side clipping in menus,
# try bumping this up
font_height_to_letter_width_ratio = 0.5

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
# chapter_ranges=sponsor start<0000ff:0.5>sponsor end
# ```
#
# Display anime openings and endings as ranges:
# ```
# chapter_ranges=op<ffc500:0.5>.*,ed|ending<ffc500:0.5>.*|{eof}
# ```
chapter_ranges=op<ffc500:.5>.*,ed|ending<ffc500:.5>.*|{eof},sponsor start<0000ff:.5>sponsor end
```

Available keybindings (place into `input.conf`):

```
Key  script-binding uosc/flash-timeline
Key  script-binding uosc/toggle-progress
Key  script-binding uosc/context-menu
Key  script-binding uosc/load-subtitles
Key  script-binding uosc/select-subtitles
Key  script-binding uosc/select-audio
Key  script-binding uosc/select-video
Key  script-binding uosc/navigate-playlist
Key  script-binding uosc/navigate-chapters
Key  script-binding uosc/navigate-directory
Key  script-binding uosc/next-file
Key  script-binding uosc/prev-file
Key  script-binding uosc/first-file
Key  script-binding uosc/last-file
Key  script-binding uosc/delete-file-next
Key  script-binding uosc/delete-file-quit
Key  script-binding uosc/show-in-directory
```
]]

if mp.get_property('osc') == 'yes' then
	mp.msg.info('Disabled because original osc is enabled!')
	return
end

local assdraw = require('mp.assdraw')
local opt = require('mp.options')
local utils = require('mp.utils')
local msg = require('mp.msg')
local osd = mp.create_osd_overlay('ass-events')
local infinity = 1e309

-- OPTIONS/CONFIG/STATE
local options = {
	timeline_size_min = 2,
	timeline_size_max = 40,
	timeline_size_min_fullscreen = 0,
	timeline_size_max_fullscreen = 60,
	timeline_opacity = 0.8,
	timeline_border = 1,
	timeline_flash_duration = 400,

	chapters = 'dots',
	chapters_opacity = 0.3,

	volume = 'right',
	volume_size = 40,
	volume_size_fullscreen = 60,
	volume_opacity = 0.8,
	volume_border = 1,
	volume_snap_to = 1,
	volume_flash_duration = 400,

	menu_item_height = 36,
	menu_item_height_fullscreen = 50,
	menu_opacity = 0.9,

	pause_on_click_shorter_than = 0,
	click_duration = 110,
	proximity_min = 40,
	proximity_max = 120,
	color_foreground = 'ffffff',
	color_foreground_text = '000000',
	color_background = '000000',
	color_background_text = 'ffffff',
	autohide = false,
	title = false,
	directory_navigation_loops = false,
	media_types = '3gp,avi,bmp,flac,flv,gif,h264,h265,jpeg,jpg,m4a,m4v,mid,midi,mkv,mov,mp3,mp4,mp4a,mp4v,mpeg,mpg,oga,ogg,ogm,ogv,opus,png,rmvb,svg,tif,tiff,wav,weba,webm,webp,wma,wmv',
	subtitle_types = 'aqt,gsub,jss,sub,ttxt,pjs,psb,rt,smi,slt,ssf,srt,ssa,ass,usf,idx,vt',
	font_height_to_letter_width_ratio = 0.5,
	chapter_ranges = 'op<ffc500:.5>.*,ed|ending<ffc500:.5>.*|{eof},sponsor start<0000ff:.5>sponsor end',
}
opt.read_options(options, 'uosc')
local config = {
	render_delay = 0.03, -- sets max rendering frequency
	font = mp.get_property('options/osd-font'),
	menu_parent_opacity = 0.4,
	menu_min_width = 260,
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
	os = (function()
		if os.getenv('windir') ~= nil then return 'windows' end
		local homedir = os.getenv('HOME')
		if homedir ~= nil and string.sub(homedir,1,6) == '/Users' then return 'macos' end
		return 'linux'
	end)(),
	cwd = mp.get_property('working-directory'),
	filename = '',
	border = mp.get_property_native('border'),
	duration = nil,
	position = nil,
	paused = false,
	chapters = nil,
	chapter_ranges = nil,
	fullscreen = mp.get_property_native('fullscreen'),
	maximized = mp.get_property_native('window-maximized'),
	render_timer = nil,
	render_last_time = 0,
	volume = nil,
	volume_max = nil,
	mute = nil,
	interactive_proximity = 0, -- highest relative proximity to any interactive element
	timeline_top_padding = options.timeline_border,
	timeline_bottom_padding = 0, -- set dynamically to `options.timeline_border` in no-border mode
	cursor_autohide_timer = mp.add_timeout(mp.get_property_native('cursor-autohide') / 1000, function()
		if not options.autohide then return end
		handle_mouse_leave()
	end),
	mouse_bindings_enabled = false
}

-- HELPERS

function round(number)
	local floored = math.floor(number)
	return number - floored < 0.5 and floored or floored + 1
end

function call_me_maybe(fn, value1, value2, value3)
	if fn then fn(value1, value2, value3) end
end

function split(str, pattern)
	local list = {}
	local full_pattern = '(.-)' .. pattern
	local last_end = 1
	local start_index, end_index, capture = str:find(full_pattern, 1)
	while start_index do
		if start_index ~= 1 or capture ~= '' then
			list[#list +1] = capture
		end
		last_end = end_index + 1
		start_index, end_index, capture = str:find(full_pattern, last_end)
	end
	if last_end <= #str then
		capture = str:sub(last_end)
		list[#list +1] = capture
	end
	return list
end

function itable_find(haystack, needle)
	local is_needle = type(needle) == 'function' and needle or function(index, value)
		return value == needle
	end
	for index, value in ipairs(haystack) do
		if is_needle(index, value) then return index, value end
	end
end

function itable_filter(haystack, needle)
	local is_needle = type(needle) == 'function' and needle or function(index, value)
		return value == needle
	end
	local filtered = {}
	for index, value in ipairs(haystack) do
		if is_needle(index, value) then filtered[#filtered + 1] = value end
	end
	return filtered
end

function itable_remove(haystack, needle)
	local should_remove = type(needle) == 'function' and needle or function(value)
		return value == needle
	end
	local new_table = {}
	for _, value in ipairs(haystack) do
		if not should_remove(value) then
			new_table[#new_table + 1] = value
		end
	end
	return new_table
end

function itable_slice(haystack, start_pos, end_pos)
	start_pos = start_pos and start_pos or 1
	end_pos = end_pos and end_pos or #haystack

	if end_pos < 0 then end_pos = #haystack + end_pos + 1 end
	if start_pos < 0 then start_pos = #haystack + start_pos + 1 end

	local new_table = {}
	for index, value in ipairs(haystack) do
		if index >= start_pos and index <= end_pos then
			new_table[#new_table + 1] = value
		end
	end
	return new_table
end

function table_copy(table)
	local new_table = {}
	for key, value in pairs(table) do new_table[key] = value end
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

-- Kills ongoing animation if one is already running
-- on this element. Killed animation will not get its on_end called.
function tween_element(element, from, to, setter, on_end)
	tween_element_stop(element)

	element.stop_current_animation = tween(
		from, to,
		function(value) setter(element, value) end,
		function()
			element.stop_current_animation = nil
			call_me_maybe(on_end, element)
		end
	)
end

-- Stopped animation will not get its on_end called.
function tween_element_stop(element)
	call_me_maybe(element.stop_current_animation)
end

-- `from` is optional and defaults to `element[prop]`
function tween_element_property(element, prop, from, to, on_end)
	if type(to) ~= 'number' then
		on_end = to
		to = from
		from = element[prop]
	end
	tween_element(element, from, to, function(_, value) element[prop] = value end, on_end)
end

function get_point_to_rectangle_proximity(point, rect)
	local dx = math.max(rect.ax - point.x, 0, point.x - rect.bx + 1)
	local dy = math.max(rect.ay - point.y, 0, point.y - rect.by + 1)
	return math.sqrt(dx*dx + dy*dy);
end

function text_width_estimate(letters, font_size)
	return letters and letters * font_size * options.font_height_to_letter_width_ratio or 0
end

function opacity_to_alpha(opacity)
	return 255 - math.ceil(255 * opacity)
end

function ass_opacity(opacity, fraction)
	fraction = fraction ~= nil and fraction or 1
	if type(opacity) == 'number' then
		return string.format('{\\alpha&H%X&}', opacity_to_alpha(opacity * fraction))
	else
		return string.format(
			'{\\1a&H%X&\\2a&H%X&\\3a&H%X&\\4a&H%X&}',
			opacity_to_alpha((opacity[1] or 0) * fraction),
			opacity_to_alpha((opacity[2] or 0) * fraction),
			opacity_to_alpha((opacity[3] or 0) * fraction),
			opacity_to_alpha((opacity[4] or 0) * fraction)
		)
	end
end

-- Prepends current working directory to relative paths
function ensure_absolute_path(path)
	-- Naive check for absolute paths
	if path:match('^/') or path:match('^%a+:[/\\]') or path:match('^\\\\') then
		return normalize_path(path)
	else
		return normalize_path(utils.join_path(state.cwd, path))
	end
end

-- Normalizes slashes to the current platform
function normalize_path(path)
	if state.os == 'windows' then
		return path:gsub('/', '\\')
	else
		return path:gsub('\\', '/')
	end
end

-- Naive check for absolute paths
function is_absolute_path(path)
	return path:match('^/') or path:match('^%a+:[/\\]') or path:match('^\\\\')
end

-- Check if path is a protocol, such as `http://...`
function is_protocol(path)
	return path:match('^%a[%a%d-_]+://')
end

function get_extension(path)
	local parts = split(path, '%.')
	return parts and #parts > 1 and parts[#parts] or nil
end

-- Serializes path into its semantic parts
function serialize_path(path)
	path = ensure_absolute_path(path)
	local parts = split(path, '[\\/]+')
	local basename = parts and parts[#parts] or path
	local dirname = #parts > 1 and table.concat(itable_slice(parts, 1, #parts - 1), '/') or nil
	local dot_split = split(basename, '%.')
	return {
		path = path:sub(-1) == ':' and state.os == 'windows' and path..'\\' or path,
		dirname = dirname and state.os == 'windows' and dirname:sub(-1) == ':' and dirname..'\\' or dirname,
		basename = basename,
		filename = #dot_split > 1 and table.concat(itable_slice(dot_split, 1, #dot_split - 1), '.') or basename,
		extension = #dot_split > 1 and dot_split[#dot_split] or nil,
	}
end

function get_files_in_directory(directory, allowed_types)
	local files, error = utils.readdir(directory, 'files')

	if not files then
		msg.error('Retrieving files failed: '..(error or ''))
		return
	end

	-- Filter only requested file types
	if allowed_types then
		files = itable_filter(files, function(_, file)
			local extension = get_extension(file)
			return extension and itable_find(allowed_types, extension:lower())
		end)
	end

	table.sort(files)

	return files
end

function get_adjacent_media_file(file_path, direction)
	local current_file = serialize_path(file_path)

	local files = get_files_in_directory(current_file.dirname, options.media_types)

	if not files then return end

	for index, file in ipairs(files) do
		if current_file.basename == file then
			if direction == 'forward' then
				if files[index + 1] then return files[index + 1] end
				if options.directory_navigation_loops and files[1] then return files[1] end
			else
				if files[index - 1] then return files[index - 1] end
				if options.directory_navigation_loops and files[#files] then return files[#files] end
			end

			-- This is the only file in directory
			return nil
		end
	end
end

-- Element
--[[
Signature:
{
	-- disables window dragging when initiated above this element
	interactive = true,
	-- element rectangle coordinates
	ax = 0, ay = 0, bx = 0, by = 0,
	-- cursor<>element relative proximity as a 0-1 floating number
	-- where 0 = completely away, and 1 = touching/hovering
	-- so it's easy to work with and throw into equations
	proximity = 0,
	-- raw cursor<>element proximity in pixels
	proximity_raw = infinity,
	-- called when element is created
	?init = function(this),
	-- called manually when disposing of element
	?destroy = function(this),
	-- triggered when event happens and cursor is above element
	?on_{event_name} = function(this),
	-- triggered when any event happens anywhere on a page
	?on_global_{event_name} = function(this),
	-- object
	?render = function(this_element),
}
]]
local Element = {
	interactive = false,
	belongs_to_interactive_proximity = true,
	ax = 0, ay = 0, bx = 0, by = 0,
	proximity = 0, proximity_raw = infinity,
}
Element.__index = Element

function Element.new(props)
	local element = setmetatable(props, Element)
	element:init()
	return element
end

function Element:init() end
function Element:destroy() end

-- Call method if it exists
function Element:maybe(name, ...)
	if self[name] then return self[name](self, ...) end
end

-- ELEMENTS

local Elements = {itable = {}}
Elements.__index = Elements
local elements = setmetatable({}, Elements)

function Elements:add(name, element)
	local insert_index = #Elements.itable + 1

	-- Replace if element already exists
	if self:has(name) then
		insert_index = itable_find(Elements.itable, function(_, element)
			return element.name == name
		end)
	end

	element.name = name
	Elements.itable[insert_index] = element
	self[name] = element

	request_render()
end

function Elements:remove(name, props)
	Elements.itable = itable_remove(Elements.itable, self[name])
	self[name] = nil
	request_render()
end

function Elements:has(name) return self[name] ~= nil end
function Elements:ipairs() return ipairs(Elements.itable) end
function Elements:pairs(elements) return pairs(self) end

-- MENU
--[[
Usage:
```
local items = {
	{title = 'Foo title', hint = 'Ctrl+F', value = 'foo'},
	{title = 'Bar title', hint = 'Ctrl+B', value = 'bar'},
	{
		title = 'Submenu',
		items = {
			{title = 'Sub item 1', value = 'sub1'},
			{title = 'Sub item 2', value = 'sub2'}
		}
	}
}

function open_item(value)
	value -- value from `item.value`
end

menu:open(items, open_item)
```
]]
local Menu = {}
Menu.__index = Menu
local menu = setmetatable({key_bindings = {}}, Menu)

function Menu:is_open(menu_type)
	return elements.menu ~= nil and (not menu_type or elements.menu.type == menu_type)
end

function Menu:open(items, open_item, opts)
	opts = opts or {}

	if menu:is_open() then
		if not opts.parent_menu then
			menu:close(true, function()
				menu:open(items, open_item, opts)
			end)
			return
		end
	else
		menu:enable_key_bindings()
	end

	elements:add('menu', Element.new({
		interactive = true,
		belongs_to_interactive_proximity = false,
		title = nil,
		title_height = 40,
		width = nil,
		height = nil,
		offset_x = 0, -- used to animated from/to left when submenu
		item_height = nil,
		item_spacing = 1,
		item_content_spacing = nil,
		font_size = nil,
		scroll_step = nil,
		scroll_height = nil,
		scroll_y = 0,
		opacity = 0,
		relative_parent_opacity = 0.4,
		items = items,
		selected_item = nil,
		select_on_hover = true,
		previous_selected_item = nil,
		open_item = open_item,
		parent_menu = nil,
		init = function(this)
			-- Already initialized
			if this.width ~= nil then return end

			-- Preselect first 'item.selected == true' item
			if not opts.selected_item then
				local preselected_item = itable_find(items, function(_, item) return not not item.selected end)
				if preselected_item then
					this.selected_item = preselected_item
				end
			end

			-- Apply options
			for key, value in pairs(opts) do this[key] = value end

			-- Set initial dimensions
			this:on_display_resize()

			-- Scroll to selected item
			this:center_selected_item()

			-- Transition in animation
			menu.transition = {to = 'child', target = this}
			local start_offset = this.parent_menu and (this.parent_menu.width + this.width) / 2 or 0

			tween_element(menu.transition.target, 0, 1, function(_, pos)
				this:set_offset_x(round(start_offset * (1 - pos)))
				this.opacity = pos
				this:set_parent_opacity(1 - ((1 - config.menu_parent_opacity) * pos))
			end, function()
				menu.transition = nil
				-- Helps select an item below cursor when appropriate
				update_proximities()
				this:on_global_mouse_move()
			end)
		end,
		destroy = function(this)
			request_render()
		end,
		set_offset_x = function(this, offset)
			local delta = offset - this.offset_x
			this.offset_x = offset
			this.ax = this.ax + delta
			this.bx = this.bx + delta
			if this.parent_menu then
				this.parent_menu:set_offset_x(offset - ((this.width + this.parent_menu.width) / 2) - this.item_spacing)
			else
				update_proximities()
			end
		end,
		fadeout = function(this, callback)
			tween_element(this, 1, 0, function(this, pos)
				this.opacity = pos
				this:set_parent_opacity(pos * config.menu_parent_opacity)
			end, callback)
		end,
		set_parent_opacity = function(this, opacity)
			if this.parent_menu then
				this.parent_menu.opacity = opacity
				this.parent_menu:set_parent_opacity(opacity * config.menu_parent_opacity)
			end
		end,
		get_item_below_cursor = function(this)
			return math.ceil((cursor.y - this.ay + this.scroll_y) / this.scroll_step)
		end,
		scroll_to = function(this, pos)
			this.scroll_y = math.max(math.min(pos, this.scroll_height), 0)
			request_render()
		end,
		center_selected_item = function(this)
			if this.selected_item then
				this:scroll_to(round((this.scroll_step * (this.selected_item - 1)) - ((this.height - this.scroll_step) / 2)))
			end
		end,
		prev = function(this)
			local current_index = this.selected_item or this.previous_selected_item
			this.selected_item = current_index and math.max(current_index - 1, 1) or #this.items
			this:center_selected_item()
		end,
		next = function(this)
			local current_index = this.selected_item or this.previous_selected_item
			this.selected_item = current_index and math.min(current_index + 1, #this.items) or 1
			this:center_selected_item()
		end,
		back = function(this)
			if menu.transition then
				local target = menu.transition.target
				tween_element_stop(target)
				if menu.transition.to == 'parent' then
					elements:add('menu', target)
				end
				menu.transition = nil
				target:back()
				return
			else
				menu.transition = {to = 'parent', target = this.parent_menu}
			end

			if menu.transition.target == nil then
				menu:close()
				return
			end

			local target = menu.transition.target
			local to_offset = -target.offset_x + this.offset_x

			tween_element(target, 0, 1, function(_, pos)
				this:set_offset_x(round(to_offset * pos))
				this.opacity = 1 - pos
				this:set_parent_opacity(config.menu_parent_opacity + ((1 - config.menu_parent_opacity) * pos))
			end, function()
				menu.transition = nil
				elements:add('menu', target)
				update_proximities()
			end)
		end,
		open_selected_item = function(this)
			-- If there is a transition active and this method got called, it
			-- means we are animating from this menu to parent menu, and all
			-- calls to this method should be relayed to the parent menu.
			if menu.transition and menu.transition.to == 'parent' then
				local target = menu.transition.target
				tween_element_stop(target)
				menu.transition = nil
				target:open_selected_item()
				return
			end

			if this.selected_item then
				local item = this.items[this.selected_item]
				-- Is submenu
				if item.items then
					local opts = table_copy(opts)
					opts.parent_menu = this
					menu:open(item.items, this.open_item, opts)
				else
					menu:close(true)
					this.open_item(item.value)
				end
			end
		end,
		on_display_resize = function(this)
			this.item_height = (state.fullscreen or state.maximized) and options.menu_item_height_fullscreen or options.menu_item_height
			this.font_size = round(this.item_height * 0.5)
			this.title_font_size = round(this.title_height * 0.5)
			this.item_content_spacing = round((this.item_height - this.font_size) * 0.666)
			this.scroll_step = this.item_height + this.item_spacing

			-- Estimate width of a widest item
			local estimated_max_width = 0
			for _, item in ipairs(items) do
				local item_text_length = ((item.title and item.title:len() or 0) + (item.hint and item.hint:len() or 0))
				local spacings_in_item = item.hint and 3 or 2
				local estimated_width = text_width_estimate(item_text_length, this.font_size) + (this.item_content_spacing * spacings_in_item)
				if estimated_width > estimated_max_width then
					estimated_max_width = estimated_width
				end
			end

			-- Also check menu title
			local menu_title_length = this.title and this.title:len() or 0
			local estimated_menu_title_width = text_width_estimate(menu_title_length, this.font_size)
			if estimated_menu_title_width > estimated_max_width then
				estimated_max_width = estimated_menu_title_width
			end

			local side_elements_width = elements.volume and (elements.volume.width + elements.volume.margin) * 2 or 0
			this.width = math.min(
				math.max(estimated_max_width, config.menu_min_width),
				(display.width * 0.9) - side_elements_width
			)
			local title_size = this.title and this.title_size or 0
			local max_height = round((display.height - elements.timeline.size_min) * 0.8) - title_size
			this.height = math.min(round(this.scroll_step * #items) - this.item_spacing, max_height)
			this.scroll_height = math.max((this.scroll_step * #this.items) - this.height - this.item_spacing, 0)
			this.ax = round((display.width - this.width) / 2) + this.offset_x
			this.ay = round((display.height - this.height) / 2 + title_size)
			this.bx = round(this.ax + this.width)
			this.by = round(this.ay + this.height)

			if this.parent_menu then
				this.parent_menu:on_display_resize()
			end
		end,
		on_global_mbtn_left_down = function(this)
			if this.proximity_raw == 0 then
				this.selected_item = this:get_item_below_cursor()
				this:open_selected_item()
			else
				-- check if this is clicking on any parent menus
				local parent_menu = this.parent_menu
				repeat
					if parent_menu then
						if get_point_to_rectangle_proximity(cursor, parent_menu) == 0 then
							this:back()
							return
						end
						parent_menu = parent_menu.parent_menu
					end
				until parent_menu == nil

				menu:close()
			end
		end,
		on_global_mouse_move = function(this)
			if this.select_on_hover then
				if this.proximity_raw == 0 then
					this.selected_item = this:get_item_below_cursor()
				else
					if this.selected_item then
						this.previous_selected_item = this.selected_item
						this.selected_item = nil
					end
				end
			end
		end,
		on_wheel_up = function(this)
			this:scroll_to(this.scroll_y - this.scroll_step)
			-- Selects item below cursor
			this:on_global_mouse_move()
			request_render()
		end,
		on_wheel_down = function(this)
			this:scroll_to(this.scroll_y + this.scroll_step)
			-- Selects item below cursor
			this:on_global_mouse_move()
			request_render()
		end,
		on_pgup = function(this) this:scroll_to(this.scroll_y - this.height) end,
		on_pgdwn = function(this) this:scroll_to(this.scroll_y + this.height) end,
		on_home = function(this) this:scroll_to(0) end,
		on_end = function(this) this:scroll_to(this.scroll_height) end,
		render = render_menu,
	}))
end

function Menu:add_key_binding(key, name, fn, flags)
	menu.key_bindings[#menu.key_bindings + 1] = name
	mp.add_forced_key_binding(key, name, fn, flags)
end

function Menu:enable_key_bindings()
	menu.key_bindings = {}
	-- The `mp.set_key_bindings()` method would be easier here, but that
	-- doesn't support 'repeatable' flag, so we are stuck with this monster.
	menu:add_key_binding('mbtn_left',  'menu-click',       create_mouse_event_handler('mbtn_left_down'))
	menu:add_key_binding('up',         'menu-prev',        self:create_action('prev'), 'repeatable')
	menu:add_key_binding('w',          'menu-prev-alt',    self:create_action('prev'), 'repeatable')
	menu:add_key_binding('k',          'menu-prev-alt2',   self:create_action('prev'), 'repeatable')
	menu:add_key_binding('down',       'menu-next',        self:create_action('next'), 'repeatable')
	menu:add_key_binding('s',          'menu-next-alt',    self:create_action('next'), 'repeatable')
	menu:add_key_binding('j',          'menu-next-alt2',   self:create_action('next'), 'repeatable')
	menu:add_key_binding('left',       'menu-back',        self:create_action('back'))
	menu:add_key_binding('a',          'menu-back-alt',    self:create_action('back'))
	menu:add_key_binding('h',          'menu-back-alt2',   self:create_action('back'))
	menu:add_key_binding('mbtn_back',  'menu-back-alt3',   self:create_action('back'))
	menu:add_key_binding('bs',         'menu-back-alt4',   self:create_action('back'))
	menu:add_key_binding('right',      'menu-select',      self:create_action('open_selected_item'))
	menu:add_key_binding('d',          'menu-select-alt',  self:create_action('open_selected_item'))
	menu:add_key_binding('l',          'menu-select-alt2', self:create_action('open_selected_item'))
	menu:add_key_binding('enter',      'menu-select-alt3', self:create_action('open_selected_item'))
	menu:add_key_binding('kp_enter',   'menu-select-alt4', self:create_action('open_selected_item'))
	menu:add_key_binding('esc',        'menu-close',       self:create_action('close'))
	menu:add_key_binding('wheel_up',   'menu-scroll-up',   self:create_action('on_wheel_up'))
	menu:add_key_binding('wheel_down', 'menu-scroll-down', self:create_action('on_wheel_down'))
	menu:add_key_binding('pgup',       'menu-page-up',     self:create_action('on_pgup'))
	menu:add_key_binding('pgdwn',      'menu-page-down',   self:create_action('on_pgdwn'))
	menu:add_key_binding('home',       'menu-home',        self:create_action('on_home'))
	menu:add_key_binding('end',        'menu-end',         self:create_action('on_end'))
end

function Menu:disable_key_bindings()
	for _, name in ipairs(menu.key_bindings) do mp.remove_key_binding(name) end
	menu.key_bindings = {}
end

function Menu:create_action(name)
	return function(...)
		if elements.menu then elements.menu:maybe(name, ...) end
	end
end

function Menu:close(immediate, callback)
	if type(immediate) ~= 'boolean' then callback = immediate end

	if elements:has('menu') then
		function close()
			elements.menu:destroy()
			elements:remove('menu')
			update_proximities()
			menu:disable_key_bindings()
			call_me_maybe(callback)
		end

		if immediate then
			close()
		else
			elements.menu:fadeout(close)
		end
	end
end

-- ICONS
--[[
ASS \shadN shadows are drawn also below the element, which when there is an
opacity in play, blends icon colors into ugly greys. The mess below is an
attempt to fix it by rendering shadows for icons with clipping.

Add icons by adding functions to render them to `icons` table.

Signature: function(pos_x, pos_y, size) => string

Function has to return ass path coordinates to draw the icon centered at pox_x
and pos_y of passed size.
]]
local icons = {}
function icon(name, icon_x, icon_y, icon_size, shad_x, shad_y, shad_size, backdrop, opacity, clip)
	local ass = assdraw.ass_new()
	local icon_path = icons[name](icon_x, icon_y, icon_size)
	local icon_color = options['color_'..backdrop..'_text']
	local shad_color = options['color_'..backdrop]
	local use_border = (shad_x + shad_y) == 0
	local icon_border = use_border and shad_size or 0

	-- clip can't clip out shadows, a very annoying limitation I can't work
	-- around without going back to ugly default ass shadows, but atm I actually
	-- don't need clipping of icons with shadows, so I'm choosing to ignore this
	if not clip then
		clip = ''
	end

	if not use_border then
		ass:new_event()
		ass:append('{\\blur0\\bord0\\shad0\\1c&H'..shad_color..'\\iclip('..ass.scale..', '..icon_path..')}')
		ass:append(ass_opacity(opacity))
		ass:pos(shad_x + shad_size, shad_y + shad_size)
		ass:draw_start()
		ass:append(icon_path)
		ass:draw_stop()
	end

	ass:new_event()
	ass:append('{\\blur0\\bord'..icon_border..'\\shad0\\1c&H'..icon_color..'\\3c&H'..shad_color..clip..'}')
	ass:append(ass_opacity(opacity))
	ass:pos(0, 0)
	ass:draw_start()
	ass:append(icon_path)
	ass:draw_stop()

	return ass.text
end

function icons._volume(muted, pos_x, pos_y, size)
	local ass = assdraw.ass_new()
	if elements.volume.width == nil then return '' end
	local scale = size / 200
	function x(number) return pos_x + (number * scale) end
	function y(number) return pos_y + (number * scale) end
	ass:move_to(x(-85), y(-35))
	ass:line_to(x(-50), y(-35))
	ass:line_to(x(-5), y(-75))
	ass:line_to(x(-5), y(75))
	ass:line_to(x(-50), y(35))
	ass:line_to(x(-85), y(35))
	if muted then
		ass:move_to(x(76), y(-35)) ass:line_to(x(50), y(-9)) ass:line_to(x(24), y(-35))
		ass:line_to(x(15), y(-26)) ass:line_to(x(41), y(0)) ass:line_to(x(15), y(26))
		ass:line_to(x(24), y(35)) ass:line_to(x(50), y(9)) ass:line_to(x(76), y(35))
		ass:line_to(x(85), y(26)) ass:line_to(x(59), y(0)) ass:line_to(x(85), y(-26))
	else
		ass:move_to(x(20), y(-30)) ass:line_to(x(20), y(30))
		ass:line_to(x(35), y(30)) ass:line_to(x(35), y(-30))

		ass:move_to(x(55), y(-60)) ass:line_to(x(55), y(60))
		ass:line_to(x(70), y(60)) ass:line_to(x(70), y(-60))
	end
	return ass.text
end
function icons.volume(pos_x, pos_y, size) return icons._volume(false, pos_x, pos_y, size) end
function icons.volume_muted(pos_x, pos_y, size) return icons._volume(true, pos_x, pos_y, size) end

function icons.right(pos_x, pos_y, size)
	local ass = assdraw.ass_new()
	if elements.volume.width == nil then return '' end
	local scale = size / 200
	function x(number) return pos_x + (number * scale) end
	function y(number) return pos_y + (number * scale) end
	ass:move_to(x(-22), y(-80))
	ass:line_to(x(-45), y(-57))
	ass:line_to(x(12), y(0))
	ass:line_to(x(-45), y(57))
	ass:line_to(x(-22), y(80))
	ass:line_to(x(58), y(0))
	return ass.text
end

-- STATE UPDATES

function update_display_dimensions()
	local o = mp.get_property_native('osd-dimensions')
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
		element.proximity = menu:is_open() and 0 or 1 - (math.min(math.max(element.proximity_raw - options.proximity_min, 0), range) / range)
	end
end

function update_proximities()
	local intercept_mouse_buttons = false
	local highest_proximity = 0
	local menu_only = menu:is_open()

	-- Calculates proximities and opacities for defined elements
	for _, element in elements:ipairs() do
		-- If menu is open, all other elements have to be disabled
		if menu_only then
			if element.name == 'menu' then
				update_element_cursor_proximity(element)
			else
				element.proximity_raw = infinity
				element.proximity = 0
			end
		else
			update_element_cursor_proximity(element)
		end

		if element.belongs_to_interactive_proximity and element.proximity > highest_proximity then
			highest_proximity = element.proximity
		end

		-- cursor is over interactive element
		if element.interactive and element.proximity_raw == 0 then
			intercept_mouse_buttons = true
		end
	end

	state.interactive_proximity = highest_proximity

	-- Enable cursor input interception only when cursor is over interactive
	-- controls. Facilitates dragging stuff lime volume slider without breaking
	-- users ability to drag the window.
	if not state.mouse_buttons_intercepted and intercept_mouse_buttons then
		state.mouse_buttons_intercepted = true
		mp.enable_key_bindings('mouse_buttons')
	elseif state.mouse_buttons_intercepted and not intercept_mouse_buttons then
		state.mouse_buttons_intercepted = false
		mp.disable_key_bindings('mouse_buttons')
	end
end

-- ELEMENT RENDERERS

function render_timeline(this)
	if this.size_max == 0 or state.duration == nil or state.position == nil then return end

	local proximity = this.forced_proximity and this.forced_proximity or math.max(state.interactive_proximity, this.proximity)

	if this.pressed then proximity = 1 end

	local size_min = this.size_min_override or this.size_min
	local size = size_min + math.ceil((this.size_max - size_min) * proximity)

	if size < 1 then return end

	local ass = assdraw.ass_new()

	-- text opacity rapidly drops to 0 just before it starts overflowing, or before it reaches timeline.size_min
	local hide_text_below = math.max(this.font_size * 0.7, size_min * 2)
	local hide_text_ramp = hide_text_below / 2
	local text_opacity = math.max(math.min(size - hide_text_below, hide_text_ramp), 0) / hide_text_ramp

	local spacing = math.max(math.floor((this.size_max - this.font_size) / 2.5), 4)
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
	local foreground_coordinates = fax..','..fay..','..fbx..','..fby -- for clipping

	-- Background
	ass:new_event()
	ass:append('{\\blur0\\bord0\\1c&H'..options.color_background..'\\iclip('..foreground_coordinates..')}')
	ass:append(ass_opacity(math.max(options.timeline_opacity - 0.1, 0)))
	ass:pos(0, 0)
	ass:draw_start()
	ass:rect_cw(bax, bay, bbx, bby)
	ass:draw_stop()

	-- Foreground
	ass:new_event()
	ass:append('{\\blur0\\bord0\\1c&H'..options.color_foreground..'}')
	ass:append(ass_opacity(options.timeline_opacity))
	ass:pos(0, 0)
	ass:draw_start()
	ass:rect_cw(fax, fay, fbx, fby)
	ass:draw_stop()

	-- Custom ranges
	if state.chapter_ranges ~= nil then
		for i, chapter_range in ipairs(state.chapter_ranges) do
			for i, range in ipairs(chapter_range.ranges) do
				local rax = display.width * (range['start'].time / state.duration)
				local rbx = display.width * (range['end'].time / state.duration)
				ass:new_event()
				ass:append('{\\blur0\\bord0\\1c&H'..chapter_range.color..'}')
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
	if options.chapters ~= '' and state.chapters ~= nil and #state.chapters > 0 then
		local half_size = size / 2
		local size_padded = bby - bay
		local dots = false
		local chapter_size, chapter_y
		if options.chapters == 'dots' then
			dots = true
			chapter_size = math.min(6, (size_padded / 2) + 2)
			chapter_y = math.min(fay + chapter_size, fay + half_size)
		elseif options.chapters == 'lines' then
			chapter_size = size
			chapter_y = fay + (chapter_size / 2)
		elseif options.chapters == 'lines-top' then
			chapter_size = math.min(this.size_max / 3.5, size)
			chapter_y = fay + (chapter_size / 2)
		elseif options.chapters == 'lines-bottom' then
			chapter_size = math.min(this.size_max / 3.5, size)
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
				ass:append('{\\blur0\\bord0\\1c&H'..color..'}')
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
			ass:append('{\\blur0\\bord0\\shad0\\1c&H'..options.color_foreground_text..'\\fn'..config.font..'\\fs'..this.font_size..'\\clip('..foreground_coordinates..')')
			ass:append(ass_opacity(math.min(options.timeline_opacity + 0.1, 1), text_opacity))
			ass:pos(spacing, fay + (size / 2))
			ass:an(4)
			ass:append(state.elapsed_time)
			ass:new_event()
			ass:append('{\\blur0\\bord0\\shad1\\1c&H'..options.color_background_text..'\\4c&H'..options.color_background..'\\fn'..config.font..'\\fs'..this.font_size..'\\iclip('..foreground_coordinates..')')
			ass:append(ass_opacity(math.min(options.timeline_opacity + 0.1, 1), text_opacity))
			ass:pos(spacing, fay + (size / 2))
			ass:an(4)
			ass:append(state.elapsed_time)
		end

		-- Remaining time
		if state.remaining_seconds then
			ass:new_event()
			ass:append('{\\blur0\\bord0\\shad0\\1c&H'..options.color_foreground_text..'\\fn'..config.font..'\\fs'..this.font_size..'\\clip('..foreground_coordinates..')')
			ass:append(ass_opacity(math.min(options.timeline_opacity + 0.1, 1), text_opacity))
			ass:pos(display.width - spacing, fay + (size / 2))
			ass:an(6)
			ass:append(state.remaining_time)
			ass:new_event()
			ass:append('{\\blur0\\bord0\\shad1\\1c&H'..options.color_background_text..'\\4c&H'..options.color_background..'\\fn'..config.font..'\\fs'..this.font_size..'\\iclip('..foreground_coordinates..')')
			ass:append(ass_opacity(math.min(options.timeline_opacity + 0.1, 1), text_opacity))
			ass:pos(display.width - spacing, fay + (size / 2))
			ass:an(6)
			ass:append(state.remaining_time)
		end
	end

	if this.proximity_raw == 0 or this.pressed then
		-- Hovered time
		local hovered_seconds = mp.get_property_native('duration') * (cursor.x / display.width)
		local box_half_width_guesstimate = (this.font_size * 4.2) / 2
		ass:new_event()
		ass:append('{\\blur0\\bord0\\shad1\\1c&H'..options.color_background_text..'\\4c&H'..options.color_background..'\\fn'..config.font..'\\fs'..this.font_size..'')
		ass:append(ass_opacity(math.min(options.timeline_opacity + 0.1, 1)))
		ass:pos(math.min(math.max(cursor.x, box_half_width_guesstimate), display.width - box_half_width_guesstimate), fay)
		ass:an(2)
		ass:append(mp.format_time(hovered_seconds))

		-- Cursor line
		ass:new_event()
		ass:append('{\\blur0\\bord0\\xshad-1\\yshad0\\1c&H'..options.color_foreground..'\\4c&H'..options.color_background..'}')
		ass:append(ass_opacity(0.2))
		ass:pos(0, 0)
		ass:draw_start()
		ass:rect_cw(cursor.x, fay, cursor.x + 1, fby)
		ass:draw_stop()
	end

	return ass
end

function render_window_controls(this)
	local opacity = math.max(state.interactive_proximity, this.proximity)

	if state.border or opacity == 0 then return end

	local ass = assdraw.ass_new()

	-- Close button
	local close = elements.window_controls_close
	if close.proximity_raw == 0 then
		-- Background on hover
		ass:new_event()
		ass:append('{\\blur0\\bord0\\1c&H2311e8}')
		ass:append(ass_opacity(config.window_controls.background_opacity, opacity))
		ass:pos(0, 0)
		ass:draw_start()
		ass:rect_cw(close.ax, close.ay, close.bx, close.by)
		ass:draw_stop()
	end
	ass:new_event()
	ass:append('{\\blur0\\bord1\\shad1\\3c&HFFFFFF\\4c&H000000}')
	ass:append(ass_opacity(config.window_controls.icon_opacity, opacity))
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
		ass:append('{\\blur0\\bord0\\1c&H222222}')
		ass:append(ass_opacity(config.window_controls.background_opacity, opacity))
		ass:pos(0, 0)
		ass:draw_start()
		ass:rect_cw(maximize.ax, maximize.ay, maximize.bx, maximize.by)
		ass:draw_stop()
	end
	ass:new_event()
	ass:append('{\\blur0\\bord2\\shad0\\1c\\3c&H000000}')
	ass:append(ass_opacity({[3] = config.window_controls.icon_opacity}, opacity))
	ass:pos(maximize.ax + (config.window_controls.button_width / 2), (config.window_controls.height / 2))
	ass:draw_start()
	ass:rect_cw(-4, -4, 6, 6)
	ass:draw_stop()
	ass:new_event()
	ass:append('{\\blur0\\bord2\\shad0\\1c\\3c&HFFFFFF}')
	ass:append(ass_opacity({[3] = config.window_controls.icon_opacity}, opacity))
	ass:pos(maximize.ax + (config.window_controls.button_width / 2), (config.window_controls.height / 2))
	ass:draw_start()
	ass:rect_cw(-5, -5, 5, 5)
	ass:draw_stop()

	-- Minimize button
	local minimize = elements.window_controls_minimize
	if minimize.proximity_raw == 0 then
		-- Background on hover
		ass:new_event()
		ass:append('{\\blur0\\bord0\\1c&H222222}')
		ass:append(ass_opacity(config.window_controls.background_opacity, opacity))
		ass:pos(0, 0)
		ass:draw_start()
		ass:rect_cw(minimize.ax, minimize.ay, minimize.bx, minimize.by)
		ass:draw_stop()
	end
	ass:new_event()
	ass:append('{\\blur0\\bord1\\shad1\\3c&HFFFFFF\\4c&H000000}')
	ass:append(ass_opacity(config.window_controls.icon_opacity, opacity))
	ass:append('{\\1a&HFF&}')
	ass:pos(minimize.ax + (config.window_controls.button_width / 2), (config.window_controls.height / 2))
	ass:draw_start()
	ass:move_to(-5, 0)
	ass:line_to(5, 0)
	ass:draw_stop()

	-- Window title
	if options.title then
		local spacing = math.ceil(config.window_controls.height * 0.25)
		local fontsize = math.floor(config.window_controls.height - (spacing * 2))
		local clip_coordinates = '0,0,'..(minimize.ax - spacing)..','..config.window_controls.height

		ass:new_event()
		ass:append('{\\q2\\blur0\\bord0\\shad1\\1c&HFFFFFF\\4c&H000000\\fn'..config.font..'\\fs'..fontsize..'\\clip('..clip_coordinates..')')
		ass:append(ass_opacity(1, opacity))
		ass:pos(0 + spacing, config.window_controls.height / 2)
		ass:an(4)
		ass:append(state.filename)
	end

	return ass
end

function render_volume(this)
	local slider = elements.volume_slider
	local proximity = math.max(state.interactive_proximity, this.proximity)
	local opacity = this.forced_proximity and this.forced_proximity or (slider.pressed and 1 or proximity)

	if this.width == 0 or opacity == 0 then return end

	local ass = assdraw.ass_new()

	-- Background bar coordinates
	local bax = slider.ax
	local bay = slider.ay
	local bbx = slider.bx
	local bby = slider.by

	-- Foreground bar coordinates
	local height_without_border = slider.height - (options.volume_border * 2)
	local fax = slider.ax + options.volume_border
	local fay = slider.ay + (height_without_border * (1 - (state.volume / state.volume_max))) + options.volume_border
	local fbx = slider.bx - options.volume_border
	local fby = slider.by - options.volume_border

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
	ass:append('{\\blur0\\bord0\\1c&H'..options.color_background..'\\iclip('..fpath.scale..', '..fpath.text..')}')
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
	ass:append('{\\blur0\\bord0\\1c&H'..options.color_foreground..'}')
	ass:append(ass_opacity(options.volume_opacity, opacity))
	ass:pos(0, 0)
	ass:draw_start()
	ass:append(fpath.text)
	ass:draw_stop()

	-- Current volume value
	if fay < slider.by - slider.spacing then
		ass:new_event()
		ass:append('{\\blur0\\bord0\\shad0\\1c&H'..options.color_foreground_text..'\\fn'..config.font..'\\fs'..slider.font_size..'\\clip('..fpath.scale..', '..fpath.text..')')
		ass:append(ass_opacity(math.min(options.volume_opacity + 0.1, 1), opacity))
		ass:pos(slider.ax + (slider.width / 2), slider.by - slider.spacing)
		ass:an(2)
		ass:append(state.volume)
	end
	if fay > slider.by - slider.spacing - slider.font_size then
		ass:new_event()
		ass:append('{\\blur0\\bord0\\shad1\\1c&H'..options.color_background_text..'\\4c&H'..options.color_background..'\\fn'..config.font..'\\fs'..slider.font_size..'\\iclip('..fpath.scale..', '..fpath.text..')')
		ass:append(ass_opacity(math.min(options.volume_opacity + 0.1, 1), opacity))
		ass:pos(slider.ax + (slider.width / 2), slider.by - slider.spacing)
		ass:an(2)
		ass:append(state.volume)
	end

	-- Mute button
	local mute = elements.volume_mute
	local icon_name = state.mute and 'volume_muted' or 'volume'
	ass:new_event()
	ass:append(icon(
		icon_name,
		mute.ax + (mute.width / 2), mute.ay + (mute.height / 2), mute.width * 0.7, -- x, y, size
		0, 0, options.volume_border, -- shadow_x, shadow_y, shadow_size
		'background', options.volume_opacity * opacity -- backdrop, opacity
	))
	return ass
end

function render_menu(this)
	local ass = assdraw.ass_new()

	if this.parent_menu then
		ass:merge(this.parent_menu:render())
	end

	-- Menu title
	if this.title then
		-- Background
		ass:new_event()
		ass:append('{\\blur0\\bord0\\1c&H'..options.color_background..'}')
		ass:append(ass_opacity(options.menu_opacity, this.opacity * 0.5))
		ass:pos(0, 0)
		ass:draw_start()
		ass:rect_cw(this.ax, this.ay - this.title_height, this.bx, this.ay)
		ass:draw_stop()

		-- Title
		ass:new_event()
		ass:append('{\\blur0\\bord0\\shad1\\b1\\1c&H'..options.color_background_text..'\\4c&H'..options.color_background..'\\fn'..config.font..'\\fs'..this.title_font_size..'\\q2\\clip('..this.ax..','..this.ay - this.title_height..','..this.bx..','..this.ay..')}')
		ass:append(ass_opacity(options.menu_opacity, this.opacity))
		ass:pos(display.width / 2, this.ay - (this.title_height * 0.5))
		ass:an(5)
		ass:append(this.title)
	end

	local scroll_area_clip = '\\clip('..this.ax..','..this.ay..','..this.bx..','..this.by..')'

	for index, item in ipairs(this.items) do
		local item_ay = this.ay - this.scroll_y + (this.item_height * (index - 1) + this.item_spacing * (index - 1))
		local item_by = item_ay + this.item_height
		local item_clip = ''

		-- Clip items overflowing scroll area
		if item_ay <= this.ay or item_by >= this.by then
			item_clip = scroll_area_clip
		end

		if item_by < this.ay or item_ay > this.by then goto continue end

		local is_active = this.selected_item == index
		local font_color, background_color, ass_shadow, ass_shadow_color
		local icon_size = this.font_size

		if is_active then
			font_color, background_color = options.color_foreground_text, options.color_foreground
			ass_shadow, ass_shadow_color = '\\shad0', ''
		else
			font_color, background_color = options.color_background_text, options.color_background
			ass_shadow, ass_shadow_color = '\\shad1', '\\4c&H'..background_color
		end

		local has_submenu = item.items ~= nil
		local hint_width = 0
		if item.hint then
			hint_width = text_width_estimate(item.hint:len(), this.font_size) + this.item_content_spacing
		elseif has_submenu then
			hint_width = icon_size + this.item_content_spacing
		end

		-- Background
		ass:new_event()
		ass:append('{\\blur0\\bord0\\1c&H'..background_color..item_clip..'}')
		ass:append(ass_opacity(options.menu_opacity, this.opacity))
		ass:pos(0, 0)
		ass:draw_start()
		ass:rect_cw(this.ax, item_ay, this.bx, item_by)
		ass:draw_stop()

		-- Title
		if item.title then
			local title_clip_x = (this.bx - hint_width - this.item_content_spacing)
			local title_clip = '\\clip('..this.ax..','..math.max(item_ay, this.ay)..','..title_clip_x..','..math.min(item_by, this.by)..')'
			ass:new_event()
			ass:append('{\\blur0\\bord0\\shad1\\1c&H'..font_color..'\\4c&H'..background_color..'\\fn'..config.font..'\\fs'..this.font_size..title_clip..'\\q2}')
			ass:append(ass_opacity(options.menu_opacity, this.opacity))
			ass:pos(this.ax + this.item_content_spacing, item_ay + (this.item_height / 2))
			ass:an(4)
			ass:append(item.title)
		end

		-- Hint
		if item.hint then
			ass:new_event()
			ass:append('{\\blur0\\bord0'..ass_shadow..'\\1c&H'..font_color..''..ass_shadow_color..'\\fn'..config.font..'\\fs'..(this.font_size - 2)..item_clip..'}')
			ass:append(ass_opacity(options.menu_opacity * (has_submenu and 1 or 0.5), this.opacity))
			ass:pos(this.bx - this.item_content_spacing, item_ay + (this.item_height / 2))
			ass:an(6)
			ass:append(item.hint)
		elseif has_submenu then
			ass:new_event()
			ass:append(icon(
				'right',
				this.bx - this.item_content_spacing - (icon_size / 2), -- x
				item_ay + (this.item_height / 2), -- y
				icon_size, -- size
				0, 0, 1, -- shadow_x, shadow_y, shadow_size
				is_active and 'foreground' or 'background', this.opacity, -- backdrop, opacity
				item_clip
			))
		end

		-- Scrollbar
		if this.scroll_height > 0 then
			local scrollbar_grove = this.height - 4
			local scrollbar_size = math.max((this.height / (this.scroll_height + this.height)) * scrollbar_grove, 40)
			local scrollbar_y = this.ay + 2 + ((this.scroll_y / this.scroll_height) * (scrollbar_grove - scrollbar_size))
			ass:new_event()
			ass:append('{\\blur0\\bord1\\1c&H'..options.color_foreground..'\\3c&H'..options.color_background..'}')
			ass:append(ass_opacity(options.menu_opacity, this.opacity * 0.5))
			ass:pos(0, 0)
			ass:draw_start()
			ass:rect_cw(this.bx - 2, scrollbar_y, this.bx, scrollbar_y + scrollbar_size)
			ass:draw_stop()
		end

		::continue::
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
	local ass = assdraw.ass_new()

	for _, element in elements.ipairs() do
		local result = element:maybe('render')
		if result then
			ass:new_event()
			ass:merge(result)
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

-- Creates a function that, when called, briefly flashes passed element name.
-- Useful to visualize changes of volume and timeline when changed via hotkeys.
function create_flash_function_for(element_name)
	local duration = options[element_name..'_flash_duration']
	if not duration or duration < 1 then
		return function() end
	end

	local flash_timer
	flash_timer = mp.add_timeout(duration / 1000, function()
		tween_element_property(elements[element_name], 'forced_proximity', 1, 0, function()
			elements[element_name].forced_proximity = nil
		end)
	end)
	flash_timer:kill()

	return function()
		if elements[element_name].proximity < 1 or flash_timer:is_enabled() then
			tween_element_stop(elements[element_name])
			elements[element_name].forced_proximity = 1
			flash_timer:kill()
			flash_timer:resume()
		end
	end, flash_timer
end

elements:add('timeline', Element.new({
	interactive = true,
	pressed = false,
	size_max = 0, size_min = 0, -- set in `on_display_resize` handler based on `state.fullscreen`
	size_min_override = nil, -- used for toggle-progress command
	font_size = 0, -- calculated in on_display_resize
	flash = create_flash_function_for('timeline'),
	on_display_resize = function(this)
		if state.fullscreen or state.maximized then
			this.size_min = options.timeline_size_min_fullscreen
			this.size_max = options.timeline_size_max_fullscreen
		else
			this.size_min = options.timeline_size_min
			this.size_max = options.timeline_size_max
		end
		this.interactive = this.size_max > 0
		this.font_size = math.floor(math.min((this.size_max + 60) * 0.2, this.size_max * 0.96))
		this.ax = 0
		this.ay = display.height - this.size_max - state.timeline_top_padding - state.timeline_bottom_padding
		this.bx = display.width
		this.by = display.height
	end,
	set_from_cursor = function(this)
		mp.commandv('seek', ((cursor.x / display.width) * 100), 'absolute-percent+exact')
	end,
	on_mbtn_left_down = function(this)
		this.pressed = true
		this:set_from_cursor()
	end,
	on_global_mbtn_left_up = function(this) this.pressed = false end,
	on_global_mouse_leave = function(this) this.pressed = false end,
	on_global_mouse_move = function(this)
		if this.pressed then this:set_from_cursor() end
	end,
	render = render_timeline,
}))
elements:add('window_controls', Element.new({
	on_display_resize = function(this)
		local ax = display.width - (config.window_controls.button_width * 3)
		this.ax = options.title and 0 or ax
		this.ay = 0
		this.bx = display.width
		this.by = config.window_controls.height
	end,
	render = render_window_controls,
}))
elements:add('window_controls_minimize', Element.new({
	interactive = true,
	on_display_resize = function(this)
		this.ax = display.width - (config.window_controls.button_width * 3)
		this.ay = 0
		this.bx = this.ax + config.window_controls.button_width
		this.by = config.window_controls.height
	end,
	on_mbtn_left_down = function() mp.commandv('cycle', 'window-minimized') end
}))
elements:add('window_controls_maximize', Element.new({
	interactive = true,
	on_display_resize = function(this)
		this.ax = display.width - (config.window_controls.button_width * 2)
		this.ay = 0
		this.bx = this.ax + config.window_controls.button_width
		this.by = config.window_controls.height
	end,
	on_mbtn_left_down = function() mp.commandv('cycle', 'window-maximized') end
}))
elements:add('window_controls_close', Element.new({
	interactive = true,
	on_display_resize = function(this)
		this.ax = display.width - config.window_controls.button_width
		this.ay = 0
		this.bx = this.ax + config.window_controls.button_width
		this.by = config.window_controls.height
	end,
	on_mbtn_left_down = function() mp.commandv('quit') end
}))
if itable_find({'left', 'right'}, options.volume) then
	elements:add('volume', Element.new({
		width = nil, -- set in `on_display_resize` handler based on `state.fullscreen`
		height = nil, -- set in `on_display_resize` handler based on `state.fullscreen`
		margin = nil, -- set in `on_display_resize` handler based on `state.fullscreen`
		font_size = nil, -- calculated in on_display_resize
		flash = create_flash_function_for('volume'),
		on_display_resize = function(this)
			local left = options.volume == 'left'
			this.width = (state.fullscreen or state.maximized) and options.volume_size_fullscreen or options.volume_size
			this.height = round(math.min(this.width * 10, (elements.timeline.ay - elements.window_controls.by) * 0.8))
			-- Don't bother rendering this if too small
			if this.height < (this.width * 2) then
				this.height = 0
			end
			this.font_size = math.floor(this.width * 0.2)
			this.margin = this.width / 2
			this.ax = round(options.volume == 'left' and this.margin or display.width - this.margin - this.width)
			this.ay = round((display.height - this.height) / 2)
			this.bx = round(this.ax + this.width)
			this.by = round(this.ay + this.height)
		end,
		render = render_volume,
	}))
	elements:add('volume_mute', Element.new({
		interactive = true,
		width = 0,
		height = 0,
		on_display_resize = function(this)
			this.width = elements.volume.width
			this.height = this.width
			this.ax = elements.volume.ax
			this.ay = elements.volume.by - this.height
			this.bx = elements.volume.bx
			this.by = elements.volume.by
		end,
		on_mbtn_left_down = function(this) mp.commandv('cycle', 'mute') end
	}))
	elements:add('volume_slider', Element.new({
		interactive = true,
		pressed = false,
		width = 0,
		height = 0,
		volume_100_y = 0, -- vertical position where volume overflows 100
		nudge_size = nil, -- set on resize
		font_size = nil,
		spacing = nil,
		on_display_resize = function(this)
			this.ax = elements.volume.ax
			this.ay = elements.volume.ay
			this.bx = elements.volume.bx
			this.by = elements.volume_mute.ay
			this.width = this.bx - this.ax
			this.height = this.by - this.ay
			this.volume_100_y = this.by - round(this.height * (100 / state.volume_max))
			this.nudge_size = round(elements.volume.width * 0.18)
			this.font_size = round(this.width * 0.5)
			this.spacing = round(this.width * 0.2)
		end,
		set_from_cursor = function(this)
			local volume_fraction = (this.by - cursor.y - options.volume_border) / (this.height - options.volume_border)
			local new_volume = math.min(math.max(volume_fraction, 0), 1) * state.volume_max
			new_volume = round(new_volume / options.volume_snap_to) * options.volume_snap_to
			if state.volume ~= new_volume then mp.commandv('set', 'volume', new_volume) end
		end,
		on_mbtn_left_down = function(this)
			this.pressed = true
			this:set_from_cursor()
		end,
		on_global_mbtn_left_up = function(this) this.pressed = false end,
		on_global_mouse_leave = function(this) this.pressed = false end,
		on_global_mouse_move = function(this)
			if this.pressed then this:set_from_cursor() end
		end,
	}))
end

-- CHAPTERS SERIALIZATION

-- Parse `chapter_ranges` option into workable data structure
for _, definition in ipairs(split(options.chapter_ranges, ' *,+ *')) do
	local start_patterns, color, opacity, end_patterns = string.match(definition, '([^<]+)<(%x%x%x%x%x%x):(%d?%.?%d*)>([^>]+)')

	-- Invalid definition
	if start_patterns == nil then goto continue end

	start_patterns = start_patterns:lower()
	end_patterns = end_patterns:lower()
	local uses_bof = start_patterns:find('{bof}') ~= nil
	local uses_eof = end_patterns:find('{eof}') ~= nil
	local chapter_range = {
		start_patterns = split(start_patterns, '|'),
		end_patterns = split(end_patterns, '|'),
		color = color,
		opacity = tonumber(opacity),
		ranges = {}
	}

	-- Filter out special keywords so we don't use them when matching titles
	if uses_bof then
		chapter_range.start_patterns = itable_remove(chapter_range.start_patterns, '{bof}')
	end
	if uses_eof and chapter_range.end_patterns then
		chapter_range.end_patterns = itable_remove(chapter_range.end_patterns, '{eof}')
	end

	chapter_range['serialize'] = function (chapters)
		chapter_range.ranges = {}
		local current_range = nil
		-- bof and eof should be used only once per timeline
		-- eof is only used when last range is missing end
		local bof_used = false

		function start_range(chapter)
			-- If there is already a range started, should we append or overwrite?
			-- I chose overwrite here.
			current_range = {['start'] = chapter}
		end

		function end_range(chapter)
			current_range['end'] = chapter
			chapter_range.ranges[#chapter_range.ranges + 1] = current_range
			-- Mark both chapter objects
			current_range['start']._uosc_used_as_range_point = true
			current_range['end']._uosc_used_as_range_point = true
			-- Clear for next range
			current_range = nil
		end

		for _, chapter in ipairs(chapters) do
			if type(chapter.title) == 'string' then
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
	state.chapter_ranges[#state.chapter_ranges + 1] = chapter_range

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

-- CONTEXT MENU SERIALIZATION

state.context_menu_items = (function()
	local input_conf_path = mp.command_native({'expand-path', '~~/input.conf'})
	local input_conf_meta, meta_error = utils.file_info(input_conf_path)

	-- File doesn't exist
	if not input_conf_meta or not input_conf_meta.is_file then return end

	local items = {}
	local items_by_command = {}
	local submenus_by_id = {}

	for line in io.lines(input_conf_path) do
		local key, command, title = string.match(line, ' *([%S]+) +(.*) #! *(.*)')
		if key then
			local is_dummy = key:sub(1, 1) == '#'
			local submenu_id = ''
			local target_menu = items
			local title_parts = split(title or '', ' *> *')

			for index, title_part in ipairs(#title_parts > 0 and title_parts or {''}) do
				if index < #title_parts then
					submenu_id = submenu_id .. title_part

					if not submenus_by_id[submenu_id] then
						submenus_by_id[submenu_id] = {title = title_part, items = {}}
						target_menu[#target_menu + 1] = submenus_by_id[submenu_id]
					end

					target_menu = submenus_by_id[submenu_id].items
				else
					-- If command is already in menu, just append the key to it
					if items_by_command[command] then
						items_by_command[command].hint = items_by_command[command].hint..', '..key
					else
						items_by_command[command] = {
							title = title_part,
							hint = not is_dummy and key or nil,
							value = command
						}
						target_menu[#target_menu + 1] = items_by_command[command]
					end
				end
			end
		end
	end

	if #items > 0 then return items end
end)()

-- EVENT HANDLERS

function create_state_setter(name)
	return function(_, value)
		state[name] = value
		dispatch_event_to_elements('prop_'..name, value)
		request_render()
	end
end

function dispatch_event_to_elements(name, ...)
	for _, element in pairs(elements) do
		if element.proximity_raw == 0 then
			element:maybe('on_'..name, ...)
		end
		element:maybe('on_global_'..name, ...)
	end
end

function handle_mouse_leave()
	local interactive_proximity_on_leave = state.interactive_proximity
	cursor.hidden = true
	update_proximities()
	dispatch_event_to_elements('mouse_leave')
	if interactive_proximity_on_leave > 0 then
		tween_element(state, interactive_proximity_on_leave, 0, function(state, value)
			state.interactive_proximity = value
			request_render()
		end)
	end
end

function create_mouse_event_handler(source)
	if source == 'mouse_move' then
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
	elseif source == 'mouse_leave' then
		return handle_mouse_leave
	else
		return function()
			dispatch_event_to_elements(source)
		end
	end
end

function create_navigate_directory(direction)
	return function()
		local path = mp.get_property_native("path")

		if is_protocol(path) then return end

		local next_file = get_adjacent_media_file(path, direction)

		if next_file then
			mp.commandv("loadfile", utils.join_path(serialize_path(path).dirname, next_file))
		end
	end
end

function create_select_adjacent_media_file_index(index)
	return function()
		local path = mp.get_property_native("path")

		if is_protocol(path) then return end

		local dirname = serialize_path(path).dirname
		local files = get_files_in_directory(dirname, options.media_types)

		if not files then return end
		if index < 0 then index = #files + index + 1 end

		if files[index] then
			mp.commandv("loadfile", utils.join_path(dirname, files[index]))
		end
	end
end

-- MENUS

function create_select_tracklist_type_menu_opener(menu_title, track_type, track_prop)
	return function()
		local items = {}
		local selected_id = nil

		for index, track in ipairs(mp.get_property_native('track-list')) do
			if track.type == track_type then
				if track.selected then
					selected_id = track.id
				end

				items[#items + 1] = {
					selected = track.selected,
					title = (track.title and track.title or 'Track '..track.id),
					hint = track.lang and track.lang:upper() or nil,
					value = track.id
				}
			end
		end

		-- Add option to disable a subtitle track. This works for all tracks,
		-- but why would anyone want to disable audio or video? Better to not
		-- let people mistakenly select what is unwanted 99.999% of the time.
		-- If I'm mistaken and there is an active need for this, feel free to
		-- open an issue.
		if track_type == 'sub' then
			table.insert(items, 1, {hint = 'disabled', value = nil, selected = not selected_id})
		end

		menu:open(items, function(id)
			if id ~= selected_id then
				mp.commandv('set', track_prop, id and id or 'no')
			end

			-- If subtitle track was selected, assume user also wants to see it
			if id and track_type == 'sub' then
				mp.commandv('set', 'sub-visibility', 'yes')
			end

			menu:close()
		end, {title = menu_title, select_on_hover = false})
	end
end

function open_file_navigation_menu(directory, handle_select, allowed_types, selected_file)
	directory = serialize_path(directory)
	local directories, error = utils.readdir(directory.path, 'dirs')
	local files, error = get_files_in_directory(directory.path, allowed_types)

	if not files or not directories then
		msg.error('Retrieving files from '..directory..' failed: '..(error or ''))
		return
	end

	-- Files are already sorted
	table.sort(directories)

	-- Pre-populate items with parent directory selector if not at root
	local items = not directory.dirname and {} or {
		{title = '..', hint = 'parent dir', value = directory.dirname}
	}

	for _, dir in ipairs(directories) do
		local serialized = serialize_path(utils.join_path(directory.path, dir))
		items[#items + 1] = {title = serialized.basename, value = serialized.path, hint = '/'}
	end

	for _, file in ipairs(files) do
		local serialized = serialize_path(utils.join_path(directory.path, file))
		items[#items + 1] = {
			title = serialized.basename,
			value = serialized.path,
			selected = selected_file == file
		}
	end

	menu:open(items, function(path)
		local meta, error = utils.file_info(path)

		if not meta then
			msg.error('Retrieving file info for '..path..' failed: '..(error or ''))
			return
		end

		if meta.is_dir then
			open_file_navigation_menu(path, handle_select, allowed_types)
		else
			handle_select(path)
			menu:close()
		end
	end, {title = directory.basename..'/', title_height = 36, select_on_hover = false})
end

-- VALUE SERIALIZATION/NORMALIZATION

options.media_types = split(options.media_types, ' *, *')
options.subtitle_types = split(options.subtitle_types, ' *, *')

-- HOOKS

mp.register_event('file-loaded', function()
	state.duration = mp.get_property_number('duration', nil)
	state.filename = mp.get_property_osd('filename', '')
end)

mp.observe_property('chapter-list', 'native', parse_chapters)
mp.observe_property('fullscreen', 'bool', create_state_setter('fullscreen'))
mp.observe_property('window-maximized', 'bool', create_state_setter('maximized'))
mp.observe_property('idle-active', 'bool', create_state_setter('idle'))
mp.observe_property('pause', 'bool', create_state_setter('paused'))
mp.observe_property('volume', 'number', function(_, value)
	local is_initial_call = state.volume == nil
	state.volume = value
	if not is_initial_call then elements.volume.flash() end
	request_render()
end)
mp.observe_property('volume-max', 'number', create_state_setter('volume_max'))
mp.observe_property('mute', 'bool', create_state_setter('mute'))
mp.observe_property('border', 'bool', function (_, border)
	state.border = border
	-- Sets 1px bottom border for bars in no-border mode
	state.timeline_bottom_padding = (not border and state.timeline_top_padding) or 0

	request_render()
end)
mp.observe_property('playback-time', 'number', function(name, val)
	-- Ignore the initial call with nil value
	if val == nil then return end

	state.position = val
	state.elapsed_seconds = val
	state.elapsed_time = state.elapsed_seconds and mp.format_time(state.elapsed_seconds) or nil
	state.remaining_seconds = mp.get_property_native('playtime-remaining')
	state.remaining_time = state.remaining_seconds and mp.format_time(state.remaining_seconds) or nil

	request_render()
end)
mp.observe_property('osd-dimensions', 'native', function(name, val)
	update_display_dimensions()
	request_render()
end)
mp.register_event('seek', function()
	local position = mp.get_property_native('playback-time')
	if position and state.position then
		local seek_length = math.abs(position - state.position)

		-- Don't flash on video looping (seek to 0) or tiny seeks (frame-step)
		if position > 0.5 and seek_length > 0.5 then
			elements.timeline.flash()
		end
	end
end)

-- CONTROLS

-- base keybinds
local base_keybinds = {
	{'mouse_move', create_mouse_event_handler('mouse_move')},
	{'mouse_leave', create_mouse_event_handler('mouse_leave')},
}
if options.pause_on_click_shorter_than > 0 then
	-- Cycles pause when click is shorter than `options.pause_on_click_shorter_than`
	-- while filtering out double clicks.
	local duration_seconds = options.pause_on_click_shorter_than / 1000
	local last_down_event;
	local click_timer = mp.add_timeout(duration_seconds, function()
		mp.command('cycle pause')
	end);
	click_timer:kill()
	base_keybinds[#base_keybinds + 1] = {'mbtn_left', function()
			if mp.get_time() - last_down_event < duration_seconds then
				click_timer:resume()
			end
		end, function()
			if click_timer:is_enabled() then
				click_timer:kill()
				last_down_event = 0
			else
				last_down_event = mp.get_time()
			end
		end
	}
end
mp.set_key_bindings(base_keybinds, 'mouse_movement', 'force')
mp.enable_key_bindings('mouse_movement', 'allow-vo-dragging+allow-hide-cursor')

-- mouse buttons
mp.set_key_bindings({
	{'mbtn_left', create_mouse_event_handler('mbtn_left_up'), create_mouse_event_handler('mbtn_left_down')},
	{'mbtn_right', create_mouse_event_handler('mbtn_right_up'), create_mouse_event_handler('mbtn_right_down')},
	{'mbtn_left_dbl', 'ignore'},
	{'mbtn_right_dbl', 'ignore'},
}, 'mouse_buttons', 'force')

-- KEY BINDABLE FEATURES

mp.add_key_binding(nil, 'flash-timeline', function()
	if elements.timeline.proximity > 0.5 then
		tween_element_property(elements.timeline, 'proximity', 0)
	else
		tween_element_property(elements.timeline, 'proximity', 1)
	end
end)
mp.add_key_binding(nil, 'toggle-progress', function()
	local timeline = elements.timeline
	if timeline.size_min_override then
		tween_element_property(timeline, 'size_min_override', timeline.size_min_override, timeline.size_min, function()
			timeline.size_min_override = nil
		end)
	else
		tween_element_property(timeline, 'size_min_override', timeline.size_min, 0)
	end
end)
mp.add_key_binding(nil, 'context-menu', function()
	if menu:is_open('context-menu') then
		menu:close()
	elseif state.context_menu_items then
		menu:open(state.context_menu_items, function(command)
			mp.command(command)
		end, {type = 'context-menu'})
	end
end)
mp.add_key_binding(nil, 'load-subtitles', function()
	local path = mp.get_property_native('path')
	if not is_protocol(path) then
		open_file_navigation_menu(
			serialize_path(path).dirname,
			function(path) mp.commandv('sub-add', path) end,
			options.subtitle_types
		)
	end
end)
mp.add_key_binding(nil, 'select-subtitles', create_select_tracklist_type_menu_opener('Subtitles', 'sub', 'sid'))
mp.add_key_binding(nil, 'select-audio', create_select_tracklist_type_menu_opener('Audio', 'audio', 'aid'))
mp.add_key_binding(nil, 'select-video', create_select_tracklist_type_menu_opener('Video', 'video', 'vid'))
mp.add_key_binding(nil, 'navigate-playlist', function()
	local items = {}
	local pos = mp.get_property_number('playlist-pos-1', 0)

	for index, item in ipairs(mp.get_property_native('playlist')) do
		local is_url = item.filename:find('://')
		items[#items + 1] = {
			selected = index == pos,
			title = is_url and item.filename or serialize_path(item.filename).basename,
			hint = tostring(index),
			value = index
		}
	end

	menu:open(items, function(index)
		mp.commandv('set', 'playlist-pos-1', tostring(index))
	end, {title = 'Playlist', select_on_hover = false})
end)
mp.add_key_binding(nil, 'navigate-chapters', function()
	local items = {}
	local chapters = mp.get_property_native('chapter-list')
	local selected_item = nil

	for index, chapter in ipairs(chapters) do
		-- Set as selected chapter if this is the first chapter with time lower
		-- than current playing position (with 100ms leeway), or if this
		-- chapters' time is the same as previously selected chapter (later
		-- defined chapters are prioritized).
		if state.position and (state.position + 0.1 > chapter.time or (selected_item and chapters[selected_item].time == chapter.time)) then
			selected_item = index
		end

		items[#items + 1] = {
			title = chapter.title or '',
			hint = mp.format_time(chapter.time),
			value = chapter.time
		}
	end

	menu:open(items, function(time)
		mp.commandv('seek', tostring(time), 'absolute')
	end, {title = 'Chapters', select_on_hover = false, selected_item = selected_item})
end)
mp.add_key_binding(nil, 'show-in-directory', function()
	local path = mp.get_property_native('path')

	-- Ignore URLs
	if is_protocol(path) then return end

	path = ensure_absolute_path(path)

	if state.os == 'windows' then
		utils.subprocess_detached({args = {'explorer', '/select,', path}, cancellable = false})
	elseif state.os == 'macos' then
		utils.subprocess_detached({args = {'open', '-R', path}, cancellable = false})
	elseif state.os == 'linux' then
		local result = utils.subprocess({args = {'nautilus', path}, cancellable = false})

		-- Fallback opens the folder with xdg-open instead
		if result.status ~= 0 then
			utils.subprocess({args = {'xdg-open', serialize_path(path).dirname}, cancellable = false})
		end
	end
end)
mp.add_key_binding(nil, 'navigate-directory', function()
	local path = mp.get_property_native('path')
	if not is_protocol(path) then
		path = serialize_path(path)
		open_file_navigation_menu(
			path.dirname,
			function(path) mp.commandv('loadfile', path) end,
			options.media_types,
			path.basename
		)
	end
end)
mp.add_key_binding(nil, 'next-file', create_navigate_directory('forward'))
mp.add_key_binding(nil, 'prev-file', create_navigate_directory('backward'))
mp.add_key_binding(nil, 'first-file', create_select_adjacent_media_file_index(1))
mp.add_key_binding(nil, 'last-file', create_select_adjacent_media_file_index(-1))
mp.add_key_binding(nil, 'delete-file-next', function()
	local path = mp.get_property_native('path')

	if is_protocol(path) then return end

	local playlist_count = mp.get_property_native('playlist-count')

	if playlist_count > 1 then
		mp.commandv('playlist-next', 'force')
	else
		local next_file = get_adjacent_media_file(path, 'forward')
		if next_file then
			mp.commandv('loadfile', next_file)
		else
			mp.commandv('stop')
		end
	end

	os.remove(ensure_absolute_path(path))
end)
mp.add_key_binding(nil, 'delete-file-quit', function()
	local path = mp.get_property_native('path')
	if is_protocol(path) then return end
	os.remove(ensure_absolute_path(path))
	mp.command('quit')
end)
