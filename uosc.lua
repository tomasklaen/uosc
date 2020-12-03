--[[

uosc 2.12.0 - 2020-Dec-03 | https://github.com/darsain/uosc

Minimalist cursor proximity based UI for MPV player.

uosc replaces the default osc UI, so that has to be disabled first.
Place these options into your `mpv.conf` file:

```
# required so that the 2 UIs don't fight each other
osc=no
# uosc provides its own seeking/volume indicators, so you also don't need this
osd-bar=no
# uosc will draw its own window controls if you disable window border
border=no
```

Options go in `script-opts/uosc.conf`. Defaults:

```
# timeline size when fully retracted, 0 will hide it completely
timeline_size_min=2
# timeline size when fully expanded, in pixels, 0 to disable
timeline_size_max=40
# same as ^ but when in fullscreen
timeline_size_min_fullscreen=0
timeline_size_max_fullscreen=60
# same thing as calling toggle-progress command once on startup
timeline_start_hidden=no
# comma separated states when timeline should always be visible. available: paused, audio
timeline_persistency=
# timeline opacity
timeline_opacity=0.8
# top border of background color to help visually separate timeline from video
timeline_border=1
# when scrolling above timeline, wheel will seek by this amount of seconds
timeline_step=5
# display seekable buffered ranges for streaming videos, syntax `color:opacity`,
# color is an BBGGRR hex code, set to `none` to disable
timeline_cached_ranges=345433:0.5
# floating number font scale adjustment
timeline_font_scale=1

# timeline chapters style: none, dots, lines, lines-top, lines-bottom
chapters=dots
chapters_opacity=0.3

# where to display volume controls: none, left, right
volume=right
volume_size=40
volume_size_fullscreen=60
volume_persistency=
volume_opacity=0.8
volume_border=1
volume_step=1
volume_font_scale=1

# playback speed widget: mouse drag or wheel to change, click to reset
speed=no
speed_size=46
speed_size_fullscreen=68
speed_persistency=
speed_opacity=1
speed_step=0.1
speed_font_scale=1

# controls all menus, such as context menu, subtitle loader/selector, etc
menu_item_height=36
menu_item_height_fullscreen=50
menu_wasd_navigation=no
menu_hjkl_navigation=no
menu_opacity=0.8
menu_font_scale=1

# top bar with window controls and media title shown only in no-border mode
top_bar_size=40
top_bar_size_fullscreen=46
top_bar_persistency=
top_bar_controls=yes
top_bar_title=yes

# window border drawn in no-border mode
window_border_size=1
window_border_opacity=0.8

# pause video on clicks shorter than this number of milliseconds, 0 to disable
pause_on_click_shorter_than=0
# flash duration in milliseconds used by `flash-{element}` commands
flash_duration=1000
# distances in pixels below which elements are fully faded in/out
proximity_in=40
proximity_out=120
# BBGGRR - BLUE GREEN RED hex color codes
color_foreground=ffffff
color_foreground_text=000000
color_background=000000
color_background_text=ffffff
# use bold font weight throughout the whole UI
font_bold=no
# show total time instead of time remaining
total_time=no
# hide UI when mpv autohides the cursor
autohide=no
# can be: none, flash, static, manual (controlled by flash-pause-indicator and decide-pause-indicator commands)
pause_indicator=flash
# sizes to list in stream quality menu
stream_quality_options=4320,2160,1440,1080,720,480,360,240,144
# load first file when calling next on a last file in a directory and vice versa
directory_navigation_loops=no
# file types to look for when navigating media files
media_types=3gp,avi,bmp,flac,flv,gif,h264,h265,jpeg,jpg,m4a,m4v,mid,midi,mkv,mov,mp3,mp4,mp4a,mp4v,mpeg,mpg,oga,ogg,ogm,ogv,opus,png,rmvb,svg,tif,tiff,wav,weba,webm,webp,wma,wmv
# file types to look for when loading external subtitles
subtitle_types=aqt,gsub,jss,sub,ttxt,pjs,psb,rt,smi,slt,ssf,srt,ssa,ass,usf,idx,vt
# used to approximate text width
# if you are using some wide font and see a lot of right side clipping in menus,
# try bumping this up
font_height_to_letter_width_ratio=0.5

# `chapter_ranges` lets you transform chapter indicators into range indicators.
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
# Display anime openings and endings as ranges:
# ```
# chapter_ranges=^op| op$|opening<968638:0.5>.*, ^ed| ed$|^end|ending$<968638:0.5>.*|{eof}
# ```
#
# Display skippable youtube video sponsor blocks from https://github.com/po5/mpv_sponsorblock
# ```
# chapter_ranges=sponsor start<3535a5:.5>sponsor end, segment start<3535a5:0.5>segment end
# ```
chapter_ranges=^op| op$|opening<968638:0.5>.*, ^ed| ed$|^end|ending$<968638:0.5>.*|{eof}, sponsor start<3535a5:.5>sponsor end, segment start<3535a5:0.5>segment end
```

Available keybindings (place into `input.conf`):

```
Key  script-binding uosc/peek-timeline
Key  script-binding uosc/toggle-progress
Key  script-binding uosc/flash-timeline
Key  script-binding uosc/flash-volume
Key  script-binding uosc/flash-speed
Key  script-binding uosc/flash-pause-indicator
Key  script-binding uosc/decide-pause-indicator
Key  script-binding uosc/menu
Key  script-binding uosc/load-subtitles
Key  script-binding uosc/subtitles
Key  script-binding uosc/audio
Key  script-binding uosc/video
Key  script-binding uosc/playlist
Key  script-binding uosc/chapters
Key  script-binding uosc/stream-quality
Key  script-binding uosc/open-file
Key  script-binding uosc/next
Key  script-binding uosc/prev
Key  script-binding uosc/first
Key  script-binding uosc/last
Key  script-binding uosc/next-file
Key  script-binding uosc/prev-file
Key  script-binding uosc/first-file
Key  script-binding uosc/last-file
Key  script-binding uosc/delete-file-next
Key  script-binding uosc/delete-file-quit
Key  script-binding uosc/show-in-directory
Key  script-binding uosc/open-config-directory
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
	timeline_start_hidden = false,
	timeline_persistency = '',
	timeline_opacity = 0.8,
	timeline_border = 1,
	timeline_step = 5,
	timeline_cached_ranges = '345433:0.5',
	timeline_font_scale = 1,

	chapters = 'dots',
	chapters_opacity = 0.3,

	volume = 'right',
	volume_size = 40,
	volume_size_fullscreen = 60,
	volume_persistency = '',
	volume_opacity = 0.8,
	volume_border = 1,
	volume_step = 1,
	volume_font_scale = 1,

	speed = false,
	speed_size = 46,
	speed_size_fullscreen = 68,
	speed_persistency = '',
	speed_opacity = 1,
	speed_step = 0.1,
	speed_font_scale = 1,

	menu_item_height = 36,
	menu_item_height_fullscreen = 50,
	menu_wasd_navigation = false,
	menu_hjkl_navigation = false,
	menu_opacity = 0.8,
	menu_font_scale = 1,

	top_bar_size = 40,
	top_bar_size_fullscreen = 46,
	top_bar_persistency = '',
	top_bar_controls = true,
	top_bar_title = true,

	window_border_size = 1,
	window_border_opacity = 0.8,
	pause_on_click_shorter_than = 0,
	flash_duration = 1000,
	proximity_in = 40,
	proximity_out = 120,
	color_foreground = 'ffffff',
	color_foreground_text = '000000',
	color_background = '000000',
	color_background_text = 'ffffff',
	total_time = false,
	font_bold = false,
	autohide = false,
	pause_indicator = 'flash',
	stream_quality_options = '4320,2160,1440,1080,720,480,360,240,144',
	directory_navigation_loops = false,
	media_types = '3gp,asf,avi,bmp,flac,flv,gif,h264,h265,jpeg,jpg,m4a,m4v,mid,midi,mkv,mov,mp3,mp4,mp4a,mp4v,mpeg,mpg,oga,ogg,ogm,ogv,opus,png,rmvb,svg,tif,tiff,wav,weba,webm,webp,wma,wmv',
	subtitle_types = 'aqt,gsub,jss,sub,ttxt,pjs,psb,rt,smi,slt,ssf,srt,ssa,ass,usf,idx,vt',
	font_height_to_letter_width_ratio = 0.5,
	chapter_ranges = '^op| op$|opening<968638:0.5>.*, ^ed| ed$|^end|ending$<968638:0.5>.*|{eof}, sponsor start<3535a5:.5>sponsor end, segment start<3535a5:0.5>segment end',
}
opt.read_options(options, 'uosc')
local config = {
	render_delay = 0.03, -- sets max rendering frequency
	font = mp.get_property('options/osd-font'),
	menu_parent_opacity = 0.4,
	menu_min_width = 260
}
local bold_tag = options.font_bold and '\\b1' or ''
local display = {
	width = 1280,
	height = 720,
	aspect = 1.77778,
}
local cursor = {
	hidden = true, -- true when autohidden or outside of the player window
	x = 0,
	y = 0,
}
local state = {
	os = (function()
		if os.getenv('windir') ~= nil then return 'windows' end
		local homedir = os.getenv('HOME')
		if homedir ~= nil and string.sub(homedir,1,6) == '/Users' then return 'macos' end
		return 'linux'
	end)(),
	cwd = mp.get_property('working-directory'),
	media_title = '',
	duration = nil,
	position = nil,
	pause = false,
	chapters = nil,
	chapter_ranges = nil,
	border = mp.get_property_native('border'),
	fullscreen = mp.get_property_native('fullscreen'),
	maximized = mp.get_property_native('window-maximized'),
	fullormaxed = mp.get_property_native('fullscreen') or mp.get_property_native('window-maximized'),
	render_timer = nil,
	render_last_time = 0,
	volume = nil,
	volume_max = nil,
	mute = nil,
	is_audio = nil, -- true if file is audio only (mp3, etc)
	cursor_autohide_timer = mp.add_timeout(mp.get_property_native('cursor-autohide') / 1000, function()
		if not options.autohide then return end
		handle_mouse_leave()
	end),
	mouse_bindings_enabled = false,
	cached_ranges = nil,
}
local forced_key_bindings -- defined at the bottom next to events

-- HELPERS

function round(number)
	local modulus = number % 1
	return modulus < 0.5 and math.floor(number) or math.ceil(number)
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
		list[#list +1] = capture
		last_end = end_index + 1
		start_index, end_index, capture = str:find(full_pattern, last_end)
	end
	if last_end <= (#str + 1) then
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

-- Sorting comparator close to (but not exactly) how file explorers sort files
local word_order_comparator = (function()
	local symbol_order
	local default_order

	if state.os == 'win' then
		symbol_order = {
			['!'] = 1, ['#'] = 2, ['$'] = 3, ['%'] = 4, ['&'] = 5, ['('] = 6, [')'] = 6, [','] = 7,
			['.'] = 8, ["'"] = 9, ['-'] = 10, [';'] = 11, ['@'] = 12, ['['] = 13, [']'] = 13, ['^'] = 14,
			['_'] = 15, ['`'] = 16, ['{'] = 17, ['}'] = 17, ['~'] = 18, ['+'] = 19, ['='] = 20,
		}
		default_order = 21
	else
		symbol_order = {
			['`'] = 1, ['^'] = 2, ['~'] = 3, ['='] = 4, ['_'] = 5, ['-'] = 6, [','] = 7, [';'] = 8,
			['!'] = 9, ["'"] = 10, ['('] = 11, [')'] = 11, ['['] = 12, [']'] = 12, ['{'] = 13, ['}'] = 14,
			['@'] = 15, ['$'] = 16, ['*'] = 17, ['&'] = 18, ['%'] = 19, ['+'] = 20, ['.'] = 22, ['#'] = 23,
		}
		default_order = 21
	end

	return function (a, b)
		a = a:lower()
		b = b:lower()
		for i = 1, math.max(#a, #b) do
			local ai = a:sub(i, i)
			local bi = b:sub(i, i)
			if ai == nil and bi then return true end
			if bi == nil and ai then return false end
			local a_order = symbol_order[ai] or default_order
			local b_order = symbol_order[bi] or default_order
			if a_order == b_order then
				return a < b
			else
				return a_order < b_order
			end
		end
	end
end)()

-- Creates in-between frames to animate value from `from` to `to` numbers.
-- Returns function that terminates animation.
-- `to` can be a function that returns target value, useful for movable targets.
-- `speed` is an optional float between 1-instant and 0-infinite duration
-- `callback` is called either on animation end, or when animation is canceled
function tween(from, to, setter, speed, callback)
	if type(speed) ~= 'number' then
		callback = speed
		speed = 0.3
	end
	local timeout
	local getTo = type(to) == 'function' and to or function() return to end
	local cutoff = math.abs(getTo() - from) * 0.01
	function tick()
		from = from + ((getTo() - from) * speed)
		local is_end = math.abs(getTo() - from) <= cutoff
		setter(is_end and getTo() or from)
		request_render()
		if is_end then
			call_me_maybe(callback)
		else
			timeout:resume()
		end
	end
	timeout = mp.add_timeout(0.016, tick)
	tick()
	return function()
		timeout:kill()
		call_me_maybe(callback)
	end
end

-- Kills ongoing animation if one is already running on this element.
-- Killed animation will not get its `on_end` called.
function tween_element(element, from, to, setter, speed, callback)
	if type(speed) ~= 'number' then
		callback = speed
		speed = 0.3
	end

	tween_element_stop(element)

	element.stop_current_animation = tween(
		from, to,
		function(value) setter(element, value) end,
		speed,
		function()
			element.stop_current_animation = nil
			call_me_maybe(callback, element)
		end
	)
end

-- Stopped animation will not get its on_end called.
function tween_element_is_tweening(element)
	return element and element.stop_current_animation
end

-- Stopped animation will not get its on_end called.
function tween_element_stop(element)
	call_me_maybe(element and element.stop_current_animation)
end

-- Helper to automatically use an element property setter
function tween_element_property(element, prop, from, to, speed, callback)
	tween_element(element, from, to, function(_, value) element[prop] = value end, speed, callback)
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

-- Ensures path is absolute and normalizes slashes to the current platform
function normalize_path(path)
	if not path or is_protocol(path) then return path end

	-- Ensure path is absolute
	if not (path:match('^/') or path:match('^%a+:') or path:match('^\\\\')) then
		path = utils.join_path(state.cwd, path)
	end

	-- Use proper slashes
	if state.os == 'windows' then
		return path:gsub('/', '\\')
	else
		return path:gsub('\\', '/')
	end
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
	if not path or is_protocol(path) then return end
	path = normalize_path(path)
	local parts = split(path, '[\\/]+')
	if parts[#parts] == '' then table.remove(parts, #parts) end -- remove trailing separator
	local basename = parts and parts[#parts] or path
	local dirname = #parts > 1 and table.concat(itable_slice(parts, 1, #parts - 1), state.os == 'windows' and '\\' or '/') or nil
	local dot_split = split(basename, '%.')
	return {
		path = path:sub(-1) == ':' and state.os == 'windows' and path..'\\' or path,
		is_root = dirname == nil,
		dirname = dirname,
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

	table.sort(files, word_order_comparator)

	return files
end

function get_adjacent_file(file_path, direction, allowed_types)
	local current_file = serialize_path(file_path)
	local files = get_files_in_directory(current_file.dirname, allowed_types)

	if not files then return end

	for index, file in ipairs(files) do
		if current_file.basename == file then
			if direction == 'forward' then
				if files[index + 1] then return utils.join_path(current_file.dirname, files[index + 1]) end
				if options.directory_navigation_loops and files[1] then return utils.join_path(current_file.dirname, files[1]) end
			else
				if files[index - 1] then return utils.join_path(current_file.dirname, files[index - 1]) end
				if options.directory_navigation_loops and files[#files] then return utils.join_path(current_file.dirname, files[#files]) end
			end

			-- This is the only file in directory
			return nil
		end
	end
end

-- Can't use `os.remove()` as it fails on paths with unicode characters.
-- Returns `result, error`, result is table of `status:number(<0=error), stdout, stderr, error_string, killed_by_us:boolean`
function delete_file(file_path)
	local args = state.os == 'windows' and {'cmd', '/C', 'del', file_path} or {'rm', file_path}
	return mp.command_native({name = 'subprocess', args = args, playback_only = false, capture_stdout = true, capture_stderr = true})
end

-- Ensures chapters are in chronological order
function get_normalized_chapters()
	local chapters = mp.get_property_native('chapter-list')

	if not chapters then return end

	-- Copy table
	chapters = itable_slice(chapters)

	-- Ensure chronological order of chapters
	table.sort(chapters, function(a, b) return a.time < b.time end)

	return chapters
end

function is_element_persistent(name)
	local option_name = name..'_persistency';
	return (options[option_name].audio and state.is_audio) or (options[option_name].paused and state.pause)
end

-- Element
--[[
Signature:
{
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
	ax = 0, ay = 0, bx = 0, by = 0,
	proximity = 0, proximity_raw = infinity,
}
Element.__index = Element

function Element.new(props)
	local element = setmetatable(props, Element)
	element._eventListeners = {}

	-- Flash timer
	element._flash_out_timer = mp.add_timeout(options.flash_duration / 1000, function()
		local getTo = function() return element.proximity end
		element:tween_property('forced_proximity', 1, getTo, function()
			element.forced_proximity = nil
		end)
	end)
	element._flash_out_timer:kill()

	element:init()

	return element
end

function Element:init() end
function Element:destroy() end

-- Call method if it exists
function Element:maybe(name, ...)
	if self[name] then return self[name](self, ...) end
end

-- Tween helpers
function Element:tween(...) tween_element(self, ...) end
function Element:tween_property(...) tween_element_property(self, ...) end
function Element:tween_stop() tween_element_stop(self) end
function Element:is_tweening() tween_element_is_tweening(self) end

-- Event listeners
function Element:on(name, handler)
	if self._eventListeners[name] == nil then self._eventListeners[name] = {} end
	local preexistingIndex = itable_find(self._eventListeners[name], handler)
	if preexistingIndex then
		return
	else
		self._eventListeners[name][#self._eventListeners[name] + 1] = handler
	end
end
function Element:off(name, handler)
	if self._eventListeners[name] == nil then return end
	local index = itable_find(self._eventListeners, handler)
	if index then table.remove(self._eventListeners, index) end
end
function Element:trigger(name, ...)
	self:maybe('on_'..name, ...)
	if self._eventListeners[name] == nil then return end
	for _, handler in ipairs(self._eventListeners[name]) do handler(...) end
	request_render()
end

-- Briefly flashes the element for `options.flash_duration` milliseconds.
-- Useful to visualize changes of volume and timeline when changed via hotkeys.
-- Implemented by briefly adding animated `forced_proximity` property to the element.
function Element:flash()
	if options.flash_duration > 0 and (self.proximity < 1 or self._flash_out_timer:is_enabled()) then
		self:tween_stop()
		self.forced_proximity = 1
		self._flash_out_timer:kill()
		self._flash_out_timer:resume()
	end
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

function Elements:trigger(name, ...)
	for _, element in self:ipairs() do element:trigger(name, ...) end
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
local menu = setmetatable({key_bindings = {}, is_closing = false}, Menu)

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
		elements.curtain:fadein()
	end

	elements:add('menu', Element.new({
		type = nil, -- menu type such as `menu`, `chapters`, ...
		title = nil,
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
		active_item = nil,
		selected_item = nil,
		open_item = open_item,
		parent_menu = nil,
		init = function(this)
			-- Already initialized
			if this.width ~= nil then return end

			-- Apply options
			for key, value in pairs(opts) do this[key] = value end

			if not this.selected_item then
				this.selected_item = this.active_item
			end

			-- Set initial dimensions
			this:on_display_change()

			-- Scroll to active item
			this:scroll_to_item(this.active_item)

			-- Transition in animation
			menu.transition = {to = 'child', target = this}
			local start_offset = this.parent_menu and (this.parent_menu.width + this.width) / 2 or 0

			tween_element(menu.transition.target, 0, 1, function(_, pos)
				this:set_offset_x(round(start_offset * (1 - pos)))
				this.opacity = pos
				this:set_parent_opacity(1 - ((1 - config.menu_parent_opacity) * pos))
			end, function()
				menu.transition = nil
				update_proximities()
			end)
		end,
		destroy = function(this)
			request_render()
		end,
		on_display_change = function(this)
			this.item_height = state.fullormaxed and options.menu_item_height_fullscreen or options.menu_item_height
			this.font_size = round(this.item_height * 0.48 * options.menu_font_scale)
			this.item_content_spacing = round((this.item_height - this.font_size) * 0.6)
			this.scroll_step = this.item_height + this.item_spacing

			-- Estimate width of a widest item
			local estimated_max_width = 0
			for _, item in ipairs(this.items) do
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

			-- Coordinates and sizes are of the scrollable area to make
			-- consuming values in rendering easier. Title drawn above this, so
			-- we need to account for that in max_height and ay position.
			this.width = round(math.min(math.max(estimated_max_width, config.menu_min_width), display.width * 0.9))
			local title_height = this.title and this.scroll_step or 0
			local max_height = round(display.height * 0.9) - title_height
			this.height = math.min(round(this.scroll_step * #this.items) - this.item_spacing, max_height)
			this.scroll_height = math.max((this.scroll_step * #this.items) - this.height - this.item_spacing, 0)
			this.ax = round((display.width - this.width) / 2) + this.offset_x
			this.ay = round((display.height - this.height) / 2 + (title_height / 2))
			this.bx = round(this.ax + this.width)
			this.by = round(this.ay + this.height)

			if this.parent_menu then
				this.parent_menu:on_display_change()
			end
		end,
		update = function(this, props)
			if props then
				for key, value in pairs(props) do this[key] = value end
			end

			-- Reset indexes and scroll
			this:select_index(this.selected_item)
			this:activate_index(this.active_item)
			this:scroll_to(this.scroll_y)

			-- Trigger changes and re-render
			this:on_display_change()
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
			this:tween(1, 0, function(this, pos)
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
		get_item_index_below_cursor = function(this)
			return math.ceil((cursor.y - this.ay + this.scroll_y) / this.scroll_step)
		end,
		get_first_visible_index = function(this)
			return round(this.scroll_y / this.scroll_step) + 1
		end,
		get_last_visible_index = function(this)
			return round((this.scroll_y + this.height) / this.scroll_step)
		end,
		get_centermost_visible_index = function(this)
			return round((this.scroll_y + (this.height / 2)) / this.scroll_step)
		end,
		scroll_to = function(this, pos)
			this.scroll_y = math.max(math.min(pos, this.scroll_height), 0)
			request_render()
		end,
		scroll_to_item = function(this, index)
			if (index and index >= 1 and index <= #this.items) then
				this:scroll_to(round((this.scroll_step * (index - 1)) - ((this.height - this.scroll_step) / 2)))
			end
		end,
		select_index = function(this, index)
			this.selected_item = (index and index >= 1 and index <= #this.items) and index or nil
			request_render()
		end,
		select_value = function(this, value)
			this:select_index(itable_find(this.items, function(_, item) return item.value == value end))
		end,
		activate_index = function(this, index)
			this.active_item = (index and index >= 1 and index <= #this.items) and index or nil
			request_render()
		end,
		activate_value = function(this, value)
			this:activate_index(itable_find(this.items, function(_, item) return item.value == value end))
		end,
		delete_index = function(this, index)
			if (index and index >= 1 and index <= #this.items) then
				local previous_active_value = this.active_index and this.items[this.active_index].value or nil
				table.remove(this.items, index)
				this:on_display_change()
				if previous_active_value then this:activate_value(previous_active_value) end
				this:scroll_to_item(this.selected_item)
			end
		end,
		delete_value = function(this, value)
			this:delete_index(itable_find(this.items, function(_, item) return item.value == value end))
		end,
		prev = function(this)
			local default_anchor = this.scroll_height > this.scroll_step and this:get_centermost_visible_index() or this:get_last_visible_index()
			local current_index = this.selected_item or default_anchor + 1
			this.selected_item = math.max(current_index - 1, 1)
			this:scroll_to_item(this.selected_item)
		end,
		next = function(this)
			local default_anchor = this.scroll_height > this.scroll_step and this:get_centermost_visible_index() or this:get_first_visible_index()
			local current_index = this.selected_item or default_anchor - 1
			this.selected_item = math.min(current_index + 1, #this.items)
			this:scroll_to_item(this.selected_item)
		end,
		back = function(this)
			if menu.transition then
				local transition_target = menu.transition.target
				local transition_target_type = menu.transition.target
				tween_element_stop(transition_target)
				if transition_target_type == 'parent' then
					elements:add('menu', transition_target)
				end
				menu.transition = nil
				transition_target:back()
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
		close = function(this)
			menu:close()
		end,
		on_global_mbtn_left_down = function(this)
			if this.proximity_raw == 0 then
				this.selected_item = this:get_item_index_below_cursor()
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
			if this.proximity_raw == 0 then
				this.selected_item = this:get_item_index_below_cursor()
			else
				if this.selected_item then this.selected_item = nil end
			end
			request_render()
		end,
		on_wheel_up = function(this)
			this.selected_item = nil
			this:scroll_to(this.scroll_y - this.scroll_step)
			-- Selects item below cursor
			this:on_global_mouse_move()
			request_render()
		end,
		on_wheel_down = function(this)
			this.selected_item = nil
			this:scroll_to(this.scroll_y + this.scroll_step)
			-- Selects item below cursor
			this:on_global_mouse_move()
			request_render()
		end,
		on_pgup = function(this)
			this.selected_item = nil
			this:scroll_to(this.scroll_y - this.height)
		end,
		on_pgdwn = function(this)
			this.selected_item = nil
			this:scroll_to(this.scroll_y + this.height)
		end,
		on_home = function(this)
			this.selected_item = nil
			this:scroll_to(0)
		end,
		on_end = function(this)
			this.selected_item = nil
			this:scroll_to(this.scroll_height)
		end,
		render = render_menu,
	}))

	elements.menu:maybe('on_open')
end

function Menu:add_key_binding(key, name, fn, flags)
	menu.key_bindings[#menu.key_bindings + 1] = name
	mp.add_forced_key_binding(key, name, fn, flags)
end

function Menu:enable_key_bindings()
	menu.key_bindings = {}
	-- The `mp.set_key_bindings()` method would be easier here, but that
	-- doesn't support 'repeatable' flag, so we are stuck with this monster.
	menu:add_key_binding('up',         'menu-prev',        self:create_action('prev'), 'repeatable')
	menu:add_key_binding('down',       'menu-next',        self:create_action('next'), 'repeatable')
	menu:add_key_binding('left',       'menu-back',        self:create_action('back'))
	menu:add_key_binding('right',      'menu-select',      self:create_action('open_selected_item'))

	if options.menu_wasd_navigation then
		menu:add_key_binding('w', 'menu-prev-alt',   self:create_action('prev'), 'repeatable')
		menu:add_key_binding('a', 'menu-back-alt',   self:create_action('back'))
		menu:add_key_binding('s', 'menu-next-alt',   self:create_action('next'), 'repeatable')
		menu:add_key_binding('d', 'menu-select-alt', self:create_action('open_selected_item'))
	end

	if options.menu_hjkl_navigation then
		menu:add_key_binding('h', 'menu-back-alt2',   self:create_action('back'))
		menu:add_key_binding('j', 'menu-next-alt2',   self:create_action('next'), 'repeatable')
		menu:add_key_binding('k', 'menu-prev-alt2',   self:create_action('prev'), 'repeatable')
		menu:add_key_binding('l', 'menu-select-alt2', self:create_action('open_selected_item'))
	end

	menu:add_key_binding('mbtn_back',  'menu-back-alt3',   self:create_action('back'))
	menu:add_key_binding('bs',         'menu-back-alt4',   self:create_action('back'))
	menu:add_key_binding('enter',      'menu-select-alt3', self:create_action('open_selected_item'))
	menu:add_key_binding('kp_enter',   'menu-select-alt4', self:create_action('open_selected_item'))
	menu:add_key_binding('esc',        'menu-close',       self:create_action('close'))
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

	if elements:has('menu') and not menu.is_closing then
		function close()
			elements.menu:maybe('on_close')
			elements.menu:destroy()
			elements:remove('menu')
			menu.is_closing = false
			update_proximities()
			menu:disable_key_bindings()
			call_me_maybe(callback)
		end

		menu.is_closing = true
		elements.curtain:fadeout()

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

function icons.arrow_right(pos_x, pos_y, size)
	local ass = assdraw.ass_new()
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
	elements:trigger('display_change')

	-- Some elements probably changed their rectangles as a reaction to `display_change`
	update_proximities()
	request_render()
end

function update_element_cursor_proximity(element)
	if cursor.hidden then
		element.proximity_raw = infinity
		element.proximity = 0
	else
		local range = options.proximity_out - options.proximity_in
		element.proximity_raw = get_point_to_rectangle_proximity(cursor, element)
		element.proximity = menu:is_open() and 0 or 1 - (math.min(math.max(element.proximity_raw - options.proximity_in, 0), range) / range)
	end
end

function update_proximities()
	local capture_mbtn_left = false
	local capture_wheel = false
	local menu_only = menu:is_open()
	local mouse_leave_elements = {}
	local mouse_enter_elements = {}

	-- Calculates proximities and opacities for defined elements
	for _, element in elements:ipairs() do
		local previous_proximity_raw = element.proximity_raw

		-- If menu is open, all other elements have to be disabled
		if menu_only then
			if element.name == 'menu' then
				capture_mbtn_left = true
				capture_wheel = true
				update_element_cursor_proximity(element)
			else
				element.proximity_raw = infinity
				element.proximity = 0
			end
		else
			update_element_cursor_proximity(element)
		end

		-- Element has global forced key listeners
		if element.on_global_mbtn_left_down then capture_mbtn_left = true end
		if element.on_global_wheel_up or element.on_global_wheel_down then capture_wheel = true end

		if element.proximity_raw == 0 then
			-- Element has local forced key listeners
			if element.on_mbtn_left_down then capture_mbtn_left = true end
			if element.on_wheel_up or element.on_wheel_up then capture_wheel = true end

			-- Mouse entered element area
			if previous_proximity_raw ~= 0 then
				mouse_enter_elements[#mouse_enter_elements + 1] = element
			end
		else
			-- Mouse left element area
			if previous_proximity_raw == 0 then
				mouse_leave_elements[#mouse_leave_elements + 1] = element
			end
		end
	end

	-- Enable key group captures elements request.
	if capture_mbtn_left then
		forced_key_bindings.mbtn_left:enable()
	else
		forced_key_bindings.mbtn_left:disable()
	end
	if capture_wheel then
		forced_key_bindings.wheel:enable()
	else
		forced_key_bindings.wheel:disable()
	end

	-- Trigger `mouse_leave` and `mouse_enter` events
	for _, element in ipairs(mouse_leave_elements) do element:trigger('mouse_leave') end
	for _, element in ipairs(mouse_enter_elements) do element:trigger('mouse_enter') end
end

-- ELEMENT RENDERERS

function render_timeline(this)
	if this.size_max == 0 or state.duration == nil or state.duration == 0 or state.position == nil then return end

	local size_min = this:get_effective_size_min()
	local size = this:get_effective_size()

	if size < 1 then return end

	local ass = assdraw.ass_new()

	-- Text opacity rapidly drops to 0 just before it starts overflowing, or before it reaches timeline.size_min
	local hide_text_below = math.max(this.font_size * 0.7, size_min * 2)
	local hide_text_ramp = hide_text_below / 2
	local text_opacity = math.max(math.min(size - hide_text_below, hide_text_ramp), 0) / hide_text_ramp

	local spacing = math.max(math.floor((this.size_max - this.font_size) / 2.5), 4)
	local progress = state.position / state.duration

	-- Background bar coordinates
	local bax = this.ax
	local bay = this.by - size
	local bbx = this.bx
	local bby = this.by

	-- Foreground bar coordinates
	local fax = bax
	local fay = bay + this.top_border
	local fbx = fax + this.width * progress
	local fby = bby
	local foreground_size = bby - bay
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

	-- Seekable ranges
	if options.timeline_cached_ranges and state.cached_ranges then
		local range_height = math.max(foreground_size / 8, size_min)
		local range_ay = fby - range_height
		for _, range in ipairs(state.cached_ranges) do
			ass:new_event()
			ass:append('{\\blur0\\bord0\\1c&H'..options.timeline_cached_ranges.color..'}')
			ass:append(ass_opacity(options.timeline_cached_ranges.opacity))
			ass:pos(0, 0)
			ass:draw_start()
			local range_start = math.max(type(range['start']) == 'number' and range['start'] or 0.000001, 0.000001)
			local range_end = math.min(type(range['end']) and range['end'] or state.duration, state.duration)
			ass:rect_cw(
				bax + this.width * (range_start / state.duration), range_ay,
				bax + this.width * (range_end / state.duration), range_ay + range_height
			)
			ass:draw_stop()
		end
	end

	-- Custom ranges
	if state.chapter_ranges ~= nil then
		for i, chapter_range in ipairs(state.chapter_ranges) do
			for i, range in ipairs(chapter_range.ranges) do
				local rax = bax + this.width * (range['start'].time / state.duration)
				local rbx = bax + this.width * (range['end'].time / state.duration)
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
	if (
		options.chapters ~= 'none'
		and (
			state.chapters ~= nil and #state.chapters > 0
			or state.ab_loop_a and state.ab_loop_a > 0
			or state.ab_loop_b and state.ab_loop_b > 0
		)
	) then
		local half_size = size / 2
		local dots = false
		local chapter_size, chapter_y
		if options.chapters == 'dots' then
			dots = true
			chapter_size = math.min(6, (foreground_size / 2) + 2)
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
			chapter_size = size <= 1 and foreground_size or chapter_size
			local chapter_half_size = chapter_size / 2
			local draw_chapter = function (time)
				local chapter_x = bax + this.width * (time / state.duration)
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

			for i, chapter in ipairs(state.chapters) do
				draw_chapter(chapter.time)
			end

			if state.ab_loop_a and state.ab_loop_a > 0 then
				draw_chapter(state.ab_loop_a)
			end

			if state.ab_loop_b and state.ab_loop_b > 0 then
				draw_chapter(state.ab_loop_b)
			end
		end
	end

	if text_opacity > 0 then
		-- Elapsed time
		if state.elapsed_seconds then
			local elapsed_x = bax + spacing
			local elapsed_y = fay + (size / 2)
			ass:new_event()
			ass:append('{\\blur0\\bord0\\shad0\\1c&H'..options.color_foreground_text..'\\fn'..config.font..'\\fs'..this.font_size..bold_tag..'\\clip('..foreground_coordinates..')')
			ass:append(ass_opacity(math.min(options.timeline_opacity + 0.1, 1), text_opacity))
			ass:pos(elapsed_x, elapsed_y)
			ass:an(4)
			ass:append(state.elapsed_time)
			ass:new_event()
			ass:append('{\\blur0\\bord0\\shad1\\1c&H'..options.color_background_text..'\\4c&H'..options.color_background..'\\fn'..config.font..'\\fs'..this.font_size..bold_tag..'\\iclip('..foreground_coordinates..')')
			ass:append(ass_opacity(math.min(options.timeline_opacity + 0.1, 1), text_opacity))
			ass:pos(elapsed_x, elapsed_y)
			ass:an(4)
			ass:append(state.elapsed_time)
		end

		-- End time
		local end_time
		if options.total_time then
			end_time = this.total_time
		else
			end_time = state.remaining_time and '-'..state.remaining_time
		end
		if end_time then
			local end_x = bbx - spacing
			local end_y = fay + (size / 2)
			ass:new_event()
			ass:append('{\\blur0\\bord0\\shad0\\1c&H'..options.color_foreground_text..'\\fn'..config.font..'\\fs'..this.font_size..bold_tag..'\\clip('..foreground_coordinates..')')
			ass:append(ass_opacity(math.min(options.timeline_opacity + 0.1, 1), text_opacity))
			ass:pos(end_x, end_y)
			ass:an(6)
			ass:append(end_time)
			ass:new_event()
			ass:append('{\\blur0\\bord0\\shad1\\1c&H'..options.color_background_text..'\\4c&H'..options.color_background..'\\fn'..config.font..'\\fs'..this.font_size..bold_tag..'\\iclip('..foreground_coordinates..')')
			ass:append(ass_opacity(math.min(options.timeline_opacity + 0.1, 1), text_opacity))
			ass:pos(end_x, end_y)
			ass:an(6)
			ass:append(end_time)
		end
	end

	if (this.proximity_raw == 0 or this.pressed) and not (elements.speed and elements.speed.dragging) then
		-- Hovered time
		local hovered_seconds = state.duration * (cursor.x / display.width)
		local box_half_width_guesstimate = (this.font_size * 4.2) / 2
		ass:new_event()
		ass:append('{\\blur0\\bord1\\shad0\\1c&H'..options.color_background_text..'\\3c&H'..options.color_background..'\\fn'..config.font..'\\fs'..this.font_size..bold_tag..'')
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

function render_top_bar(this)
	local opacity = this:get_effective_proximity()

	if not this.enabled or opacity == 0 then return end

	local ass = assdraw.ass_new()

	if options.top_bar_controls then
		-- Close button
		local close = elements.window_controls_close
		if close.proximity_raw == 0 then
			-- Background on hover
			ass:new_event()
			ass:append('{\\blur0\\bord0\\1c&H2311e8}')
			ass:append(ass_opacity(this.button_opacity, opacity))
			ass:pos(0, 0)
			ass:draw_start()
			ass:rect_cw(close.ax, close.ay, close.bx, close.by)
			ass:draw_stop()
		end
		ass:new_event()
		ass:append('{\\blur0\\bord1\\shad1\\3c&HFFFFFF\\4c&H000000}')
		ass:append(ass_opacity(this.button_opacity, opacity))
		ass:pos(close.ax + (this.button_width / 2), close.ay + (this.size / 2))
		ass:draw_start()
		ass:move_to(-this.icon_size, this.icon_size)
		ass:line_to(this.icon_size, -this.icon_size)
		ass:move_to(-this.icon_size, -this.icon_size)
		ass:line_to(this.icon_size, this.icon_size)
		ass:draw_stop()

		-- Maximize button
		local maximize = elements.window_controls_maximize
		if maximize.proximity_raw == 0 then
			-- Background on hover
			ass:new_event()
			ass:append('{\\blur0\\bord0\\1c&H222222}')
			ass:append(ass_opacity(this.button_opacity, opacity))
			ass:pos(0, 0)
			ass:draw_start()
			ass:rect_cw(maximize.ax, maximize.ay, maximize.bx, maximize.by)
			ass:draw_stop()
		end
		ass:new_event()
		ass:append('{\\blur0\\bord2\\shad0\\1c\\3c&H000000}')
		ass:append(ass_opacity({[3] = this.button_opacity}, opacity))
		ass:pos(maximize.ax + (this.button_width / 2), maximize.ay + (this.size / 2))
		ass:draw_start()
		ass:rect_cw(-this.icon_size + 1, -this.icon_size + 1, this.icon_size + 1, this.icon_size + 1)
		ass:draw_stop()
		ass:new_event()
		ass:append('{\\blur0\\bord2\\shad0\\1c\\3c&HFFFFFF}')
		ass:append(ass_opacity({[3] = this.button_opacity}, opacity))
		ass:pos(maximize.ax + (this.button_width / 2), maximize.ay + (this.size / 2))
		ass:draw_start()
		ass:rect_cw(-this.icon_size, -this.icon_size, this.icon_size, this.icon_size)
		ass:draw_stop()

		-- Minimize button
		local minimize = elements.window_controls_minimize
		if minimize.proximity_raw == 0 then
			-- Background on hover
			ass:new_event()
			ass:append('{\\blur0\\bord0\\1c&H222222}')
			ass:append(ass_opacity(this.button_opacity, opacity))
			ass:pos(0, 0)
			ass:draw_start()
			ass:rect_cw(minimize.ax, minimize.ay, minimize.bx, minimize.by)
			ass:draw_stop()
		end
		ass:new_event()
		ass:append('{\\blur0\\bord1\\shad1\\3c&HFFFFFF\\4c&H000000}')
		ass:append(ass_opacity(this.button_opacity, opacity))
		ass:append('{\\1a&HFF&}')
		ass:pos(minimize.ax + (this.button_width / 2), minimize.ay + (this.size / 2))
		ass:draw_start()
		ass:move_to(-this.icon_size, 0)
		ass:line_to(this.icon_size, 0)
		ass:draw_stop()
	end

	-- Window title
	if options.top_bar_title and state.media_title then
		local clip_coordinates = this.ax..','..this.ay..','..(this.title_bx - this.spacing)..','..this.by

		ass:new_event()
		ass:append('{\\q2\\blur0\\bord1\\shad0\\1c&HFFFFFF\\3c&H000000\\fn'..config.font..'\\fs'..this.font_size..bold_tag..'\\clip('..clip_coordinates..')')
		ass:append(ass_opacity(1, opacity))
		ass:pos(this.ax + this.spacing, this.ay + (this.size / 2))
		ass:an(4)
		ass:append(state.media_title)
	end

	return ass
end

function render_volume(this)
	local slider = elements.volume_slider
	local opacity = this:get_effective_proximity()

	if this.width == 0 or opacity == 0 then return end

	local ass = assdraw.ass_new()

	if slider.height > 0 then
		-- Background bar coordinates
		local bax = slider.ax
		local bay = slider.ay
		local bbx = slider.bx
		local bby = slider.by

		-- Foreground bar coordinates
		local height_without_border = slider.height - (options.volume_border * 2)
		local fax = slider.ax + options.volume_border
		local fay = slider.ay + (height_without_border * (1 - math.min(state.volume / state.volume_max, 1))) + options.volume_border
		local fbx = slider.bx - options.volume_border
		local fby = slider.by - options.volume_border

		-- Path to draw a foreground bar with a 100% volume indicator, already
		-- clipped by volume level. Can't just clip it with rectangle, as it itself
		-- also needs to be used as a path to clip the background bar and volume
		-- number.
		local fpath = assdraw.ass_new()
		fpath:move_to(fbx, fby)
		fpath:line_to(fax, fby)
		local nudge_bottom_y = slider.nudge_y + slider.nudge_size
		if fay <= nudge_bottom_y and slider.draw_nudge then
			fpath:line_to(fax, math.min(nudge_bottom_y))
			if fay <= slider.nudge_y then
				fpath:line_to((fax + slider.nudge_size), slider.nudge_y)
				local nudge_top_y = slider.nudge_y - slider.nudge_size
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
				fpath:line_to((fbx - slider.nudge_size), slider.nudge_y)
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
		if slider.draw_nudge then
			ass:line_to(bbx, math.max(slider.nudge_y - slider.nudge_size + half_border, bay))
			ass:line_to(bbx - slider.nudge_size + half_border, slider.nudge_y)
			ass:line_to(bbx, slider.nudge_y + slider.nudge_size - half_border)
		end
		ass:line_to(bbx, bby)
		ass:line_to(bax, bby)
		if slider.draw_nudge then
			ass:line_to(bax, slider.nudge_y + slider.nudge_size - half_border)
			ass:line_to(bax + slider.nudge_size - half_border, slider.nudge_y)
			ass:line_to(bax, math.max(slider.nudge_y - slider.nudge_size + half_border, bay))
		end
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
		local volume_string = tostring(round(state.volume * 10) / 10)
		local font_size = round(((this.width * 0.6) - (#volume_string * (this.width / 20))) * options.volume_font_scale)
		if fay < slider.by - slider.spacing then
			ass:new_event()
			ass:append('{\\blur0\\bord0\\shad0\\1c&H'..options.color_foreground_text..'\\fn'..config.font..'\\fs'..font_size..bold_tag..'\\clip('..fpath.scale..', '..fpath.text..')}')
			ass:append(ass_opacity(math.min(options.volume_opacity + 0.1, 1), opacity))
			ass:pos(slider.ax + (slider.width / 2), slider.by - slider.spacing)
			ass:an(2)
			ass:append(volume_string)
		end
		if fay > slider.by - slider.spacing - font_size then
			ass:new_event()
			ass:append('{\\blur0\\bord0\\shad1\\1c&H'..options.color_background_text..'\\4c&H'..options.color_background..'\\fn'..config.font..'\\fs'..font_size..bold_tag..'\\iclip('..fpath.scale..', '..fpath.text..')}')
			ass:append(ass_opacity(math.min(options.volume_opacity + 0.1, 1), opacity))
			ass:pos(slider.ax + (slider.width / 2), slider.by - slider.spacing)
			ass:an(2)
			ass:append(volume_string)
		end
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

function render_speed(this)
	if not this.dragging and (elements.curtain.opacity > 0) then return end

	local proximity = this:get_effective_proximity()
	local opacity = this.dragging and 1 or proximity

	if opacity == 0 then return end

	local ass = assdraw.ass_new()

	-- Coordinates
	local ax = this.ax
	-- local ay = this.ay + timeline.size_max - timeline:get_effective_size()
	local ay = this.ay
	local bx = this.bx
	local by = ay + this.height
	local half_width = (this.width / 2)
	local half_x = ax + half_width

	-- Notches
	local speed_at_center = state.speed
	if this.dragging then
		speed_at_center = this.dragging.start_speed + ((-this.dragging.distance / this.step_distance) * options.speed_step)
		speed_at_center = math.min(math.max(speed_at_center, 0.01), 100)
	end
	local nearest_notch_speed = round(speed_at_center / this.notch_every) * this.notch_every
	local nearest_notch_x = half_x + (((nearest_notch_speed - speed_at_center) / this.notch_every) * this.notch_spacing)
	local guide_size = math.floor(this.height / 7.5)
	local notch_by = by - guide_size
	local notch_ay_big = ay + round(this.font_size * 1.1)
	local notch_ay_medium = notch_ay_big + ((notch_by - notch_ay_big) * 0.2)
	local notch_ay_small = notch_ay_big + ((notch_by - notch_ay_big) * 0.4)
	local from_to_index = math.floor(this.notches / 2)

	for i = -from_to_index, from_to_index do
		local notch_speed = nearest_notch_speed + (i * this.notch_every)

		if notch_speed < 0 or notch_speed > 100 then goto continue end

		local notch_x = nearest_notch_x + (i * this.notch_spacing)
		local notch_thickness = 1
		local notch_ay = notch_ay_small
		if (notch_speed % (this.notch_every * 10)) < 0.00000001 then
			notch_ay = notch_ay_big
			notch_thickness = 1
		elseif (notch_speed % (this.notch_every * 5)) < 0.00000001 then
			notch_ay = notch_ay_medium
		end

		ass:new_event()
		ass:append('{\\blur0\\bord1\\shad0\\1c&HFFFFFF\\3c&H000000}')
		ass:append(ass_opacity(math.min(1.2 - (math.abs((notch_x - ax - half_width) / half_width)), 1), opacity))
		ass:pos(0, 0)
		ass:draw_start()
		ass:move_to(notch_x - notch_thickness, notch_ay)
		ass:line_to(notch_x + notch_thickness, notch_ay)
		ass:line_to(notch_x + notch_thickness, notch_by)
		ass:line_to(notch_x - notch_thickness, notch_by)
		ass:draw_stop()

		::continue::
	end

	-- Center guide
	ass:new_event()
	ass:append('{\\blur0\\bord1\\shad0\\1c&HFFFFFF\\3c&H000000}')
	ass:append(ass_opacity(options.speed_opacity, opacity))
	ass:pos(0, 0)
	ass:draw_start()
	ass:move_to(half_x, by - 2 - guide_size)
	ass:line_to(half_x + guide_size, by - 2)
	ass:line_to(half_x - guide_size, by - 2)
	ass:draw_stop()

	-- Speed value
	local speed_text = (round(state.speed * 100) / 100)..'x'
	ass:new_event()
	ass:append('{\\blur0\\bord1\\shad0\\1c&H'..options.color_background_text..'\\3c&H'..options.color_background..'\\fn'..config.font..'\\fs'..this.font_size..bold_tag..'}')
	ass:append(ass_opacity(options.speed_opacity, opacity))
	ass:pos(half_x, ay)
	ass:an(8)
	ass:append(speed_text)

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
		ass:append(ass_opacity(options.menu_opacity, this.opacity))
		ass:pos(0, 0)
		ass:draw_start()
		ass:rect_cw(this.ax, this.ay - this.item_height, this.bx, this.ay - 1)
		ass:draw_stop()

		-- Title
		ass:new_event()
		ass:append('{\\blur0\\bord0\\shad1\\b1\\1c&H'..options.color_background_text..'\\4c&H'..options.color_background..'\\fn'..config.font..'\\fs'..this.font_size..'\\q2\\clip('..this.ax..','..this.ay - this.item_height..','..this.bx..','..this.ay..')}')
		ass:append(ass_opacity(options.menu_opacity, this.opacity))
		ass:pos(display.width / 2, this.ay - (this.item_height * 0.5))
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

		local is_active = this.active_item == index
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

		-- Selected highlight
		if this.selected_item == index then
			ass:new_event()
			ass:append('{\\blur0\\bord0\\1c&H'..options.color_foreground..item_clip..'}')
			ass:append(ass_opacity(0.1, this.opacity))
			ass:pos(0, 0)
			ass:draw_start()
			ass:rect_cw(this.ax, item_ay, this.bx, item_by)
			ass:draw_stop()
		end

		-- Title
		if item.title then
			item.ass_save_title = item.ass_save_title or item.title:gsub("([{}])","\\%1")
			local title_clip_x = (this.bx - hint_width - this.item_content_spacing)
			local title_clip = '\\clip('..this.ax..','..math.max(item_ay, this.ay)..','..title_clip_x..','..math.min(item_by, this.by)..')'
			ass:new_event()
			ass:append('{\\blur0\\bord0\\shad1\\1c&H'..font_color..'\\4c&H'..background_color..'\\fn'..config.font..'\\fs'..this.font_size..bold_tag..title_clip..'\\q2}')
			ass:append(ass_opacity(options.menu_opacity, this.opacity))
			ass:pos(this.ax + this.item_content_spacing, item_ay + (this.item_height / 2))
			ass:an(4)
			ass:append(item.ass_save_title)
		end

		-- Hint
		if item.hint then
			item.ass_save_hint = item.ass_save_hint or item.hint:gsub("([{}])","\\%1")
			ass:new_event()
			ass:append('{\\blur0\\bord0'..ass_shadow..'\\1c&H'..font_color..''..ass_shadow_color..'\\fn'..config.font..'\\fs'..(this.font_size - 1)..bold_tag..item_clip..'}')
			ass:append(ass_opacity(options.menu_opacity * (has_submenu and 1 or 0.5), this.opacity))
			ass:pos(this.bx - this.item_content_spacing, item_ay + (this.item_height / 2))
			ass:an(6)
			ass:append(item.ass_save_hint)
		elseif has_submenu then
			ass:new_event()
			ass:append(icon(
				'arrow_right',
				this.bx - this.item_content_spacing - (icon_size / 2), -- x
				item_ay + (this.item_height / 2), -- y
				icon_size, -- size
				0, 0, 1, -- shadow_x, shadow_y, shadow_size
				is_active and 'foreground' or 'background', this.opacity, -- backdrop, opacity
				item_clip
			))
		end

		::continue::
	end

	-- Scrollbar
	if this.scroll_height > 0 then
		local groove_height = this.height - 2
		local thumb_height = math.max((this.height / (this.scroll_height + this.height)) * groove_height, 40)
		local thumb_y = this.ay + 1 + ((this.scroll_y / this.scroll_height) * (groove_height - thumb_height))
		ass:new_event()
		ass:append('{\\blur0\\bord0\\1c&H'..options.color_foreground..'}')
		ass:append(ass_opacity(options.menu_opacity, this.opacity * 0.8))
		ass:pos(0, 0)
		ass:draw_start()
		ass:rect_cw(this.bx - 3, thumb_y, this.bx - 1, thumb_y + thumb_height)
		ass:draw_stop()
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

elements:add('window_border', Element.new({
	size = nil, -- set in init
	init = function(this)
		this:update_size();
	end,
	update_size = function(this)
		this.size = options.window_border_size > 0 and not state.fullormaxed and not state.border and options.window_border_size or 0
	end,
	on_prop_border = function(this) this:update_size() end,
	on_prop_fullormaxed = function(this) this:update_size() end,
	render = function(this)
		if this.size > 0 then
			local ass = assdraw.ass_new()
			local clip_coordinates = this.size..','..this.size..','..(display.width - this.size)..','..(display.height - this.size)
			ass:new_event()
			ass:append('{\\blur0\\bord0\\1c&H'..options.color_background..'\\iclip('..clip_coordinates..')}')
			ass:append(ass_opacity(options.window_border_opacity))
			ass:pos(0, 0)
			ass:draw_start()
			ass:rect_cw(0, 0, display.width, display.height)
			ass:draw_stop()
			return ass
		end
	end
}))
elements:add('pause_indicator', Element.new({
	base_icon_opacity = options.pause_indicator == 'flash' and 1 or 0.8,
	paused = false,
	type = options.pause_indicator,
	is_manual = options.pause_indicator == 'manual',
	fadeout_requested = false,
	opacity = 0,
	init = function(this)
		local initial_call = true
		mp.observe_property('pause', 'bool', function(_, paused)
			if initial_call then
				initial_call = false
				return
			end

			this.paused = paused

			if options.pause_indicator == 'flash' then
				this:flash()
			elseif options.pause_indicator == 'static' then
				this:decide()
			end
		end)
	end,
	flash = function(this)
		if not this.is_manual and this.type ~= 'flash' then return end
		-- can't wait for pause property event listener to set this, because when this is used inside a binding like:
		-- cycle pause; script-binding uosc/flash-pause-indicator
		-- the pause event is not fired fast enough, and indicator starts rendering with old icon
		this.paused = mp.get_property_native('pause')
		if this.is_manual then this.type = 'flash' end
		this.opacity = 1
		this:tween_property('opacity', 1, 0, 0.15)
	end,
	-- decides whether static indicator should be visible or not
	decide = function(this)
		if not this.is_manual and this.type ~= 'static' then return end
		this.paused = mp.get_property_native('pause') -- see flash() for why this line is necessary
		if this.is_manual then this.type = 'static' end
		this.opacity = this.paused and 1 or 0
		request_render()

		-- works around an mpv race condition bug during pause on windows builds, which cause osd updates to be ignored
		-- .03 was still loosing renders, .04 was fine, but to be safe I added 10ms more
		mp.add_timeout(.05, function() osd:update() end)
	end,
	render = function(this)
		if this.opacity == 0 then return end

		local ass = assdraw.ass_new()
		local is_static = this.type == 'static'

		-- Background fadeout
		if is_static then
			ass:new_event()
			ass:append('{\\blur0\\bord0\\1c&H'..options.color_background..'}')
			ass:append(ass_opacity(0.3, this.opacity))
			ass:pos(0, 0)
			ass:draw_start()
			ass:rect_cw(0, 0, display.width, display.height)
			ass:draw_stop()
		end

		-- Icon
		local size = round((math.min(display.width, display.height) * (is_static and 0.20 or 0.15)) / 2)

		size = size + size * (1 - this.opacity)

		if this.paused then
			ass:new_event()
			ass:append('{\\blur0\\bord1\\1c&H'..options.color_foreground..'\\3c&H'..options.color_background..'}')
			ass:append(ass_opacity(this.base_icon_opacity, this.opacity))
			ass:pos(display.width / 2, display.height / 2)
			ass:draw_start()
			ass:rect_cw(-size, -size, -size / 3, size)
			ass:draw_stop()

			ass:new_event()
			ass:append('{\\blur0\\bord1\\1c&H'..options.color_foreground..'\\3c&H'..options.color_background..'}')
			ass:append(ass_opacity(this.base_icon_opacity, this.opacity))
			ass:pos(display.width / 2, display.height / 2)
			ass:draw_start()
			ass:rect_cw(size / 3, -size, size, size)
			ass:draw_stop()
		else
			ass:new_event()
			ass:append('{\\blur0\\bord1\\1c&H'..options.color_foreground..'\\3c&H'..options.color_background..'}')
			ass:append(ass_opacity(this.base_icon_opacity, this.opacity))
			ass:pos(display.width / 2, display.height / 2)
			ass:draw_start()
			ass:move_to(-size * 0.6, -size)
			ass:line_to(size, 0)
			ass:line_to(-size * 0.6, size)
			ass:draw_stop()
		end

		return ass
	end
}))
elements:add('timeline', Element.new({
	pressed = false,
	size_max = 0, size_min = 0, -- set in `on_display_change` handler based on `state.fullormaxed`
	size_min_override = options.timeline_start_hidden and 0 or nil, -- used for toggle-progress command
	font_size = 0, -- calculated in on_display_change
	total_time = nil, -- set in op_prop_duration listener
	top_border = options.timeline_border,
	get_effective_proximity = function(this)
		if this.pressed or is_element_persistent('timeline') then return 1 end
		if this.forced_proximity then return this.forced_proximity end
		return (elements.volume_slider and elements.volume_slider.pressed) and 0 or this.proximity
	end,
	get_effective_size_min = function(this)
		return this.size_min_override or this.size_min
	end,
	get_effective_size = function(this)
		if elements.speed and elements.speed.dragging then return this.size_max end
		local size_min = this:get_effective_size_min()
		return size_min + math.ceil((this.size_max - size_min) * this:get_effective_proximity())
	end,
	update_dimensions = function(this)
		if state.fullormaxed then
			this.size_min = options.timeline_size_min_fullscreen
			this.size_max = options.timeline_size_max_fullscreen
		else
			this.size_min = options.timeline_size_min
			this.size_max = options.timeline_size_max
		end
		this.font_size = math.floor(math.min((this.size_max + 60) * 0.2, this.size_max * 0.96) * options.timeline_font_scale)
		this.ax = elements.window_border.size
		this.ay = display.height - elements.window_border.size - this.size_max - this.top_border
		this.bx = display.width - elements.window_border.size
		this.by = display.height - elements.window_border.size
		this.width = this.bx - this.ax
	end,
	on_prop_border = function(this) this:update_dimensions() end,
	on_prop_fullormaxed = function(this) this:update_dimensions() end,
	on_display_change = function(this) this:update_dimensions() end,
	on_prop_duration = function(this, value)
		this.total_time = value and mp.format_time(value) or nil
	end,
	set_from_cursor = function(this)
		mp.commandv('seek', (((cursor.x - this.ax) / this.width) * 100), 'absolute-percent+exact')
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
	on_wheel_up = function(this)
		if options.timeline_step > 0 then mp.commandv('seek', -options.timeline_step) end
	end,
	on_wheel_down = function(this)
		if options.timeline_step > 0 then mp.commandv('seek', options.timeline_step) end
	end,
	render = render_timeline,
}))
elements:add('top_bar', Element.new({
	button_opacity = 0.8,
	enabled = false,
	get_effective_proximity = function(this)
		if is_element_persistent('top_bar') then return 1 end
		if this.forced_proximity then return this.forced_proximity end
		return (elements.volume_slider and elements.volume_slider.pressed) and 0 or this.proximity
	end,
	update_dimensions = function(this)
		this.size = state.fullormaxed and options.top_bar_size_fullscreen or options.top_bar_size
		this.icon_size = round(this.size / 8)
		this.spacing = math.ceil(this.size * 0.25)
		this.font_size = math.floor(this.size - (this.spacing * 2))
		this.button_width = round(this.size * 1.15)
		this.ay = elements.window_border.size
		this.bx = display.width - elements.window_border.size
		this.by = this.size + elements.window_border.size
		this.title_bx = this.bx - (options.top_bar_controls and (this.button_width * 3) or 0)
		this.ax = options.top_bar_title and elements.window_border.size or this.title_bx
	end,
	on_prop_border = function(this, value)
		this.enabled = not value and (options.top_bar_controls or options.top_bar_title)
		this:update_dimensions()
	end,
	on_display_change = function(this) this:update_dimensions() end,
	render = render_top_bar,
}))
if options.top_bar_controls then
	elements:add('window_controls_minimize', Element.new({
		update_dimensions = function(this)
			this.ax = elements.top_bar.bx - (elements.top_bar.button_width * 3)
			this.ay = elements.top_bar.ay
			this.bx = this.ax + elements.top_bar.button_width
			this.by = this.ay + elements.top_bar.size
		end,
		on_prop_border = function(this) this:update_dimensions() end,
		on_display_change = function(this) this:update_dimensions() end,
		on_mbtn_left_down = function() mp.commandv('cycle', 'window-minimized') end
	}))
	elements:add('window_controls_maximize', Element.new({
		update_dimensions = function(this)
			this.ax = elements.top_bar.bx - (elements.top_bar.button_width * 2)
			this.ay = elements.top_bar.ay
			this.bx = this.ax + elements.top_bar.button_width
			this.by = this.ay + elements.top_bar.size
		end,
		on_prop_border = function(this) this:update_dimensions() end,
		on_display_change = function(this) this:update_dimensions() end,
		on_mbtn_left_down = function() mp.commandv('cycle', 'window-maximized') end
	}))
	elements:add('window_controls_close', Element.new({
		update_dimensions = function(this)
			this.ax = elements.top_bar.bx - elements.top_bar.button_width
			this.ay = elements.top_bar.ay
			this.bx = this.ax + elements.top_bar.button_width
			this.by = this.ay + elements.top_bar.size
		end,
		on_prop_border = function(this) this:update_dimensions() end,
		on_display_change = function(this) this:update_dimensions() end,
		on_mbtn_left_down = function() mp.commandv('quit') end
	}))
end
if itable_find({'left', 'right'}, options.volume) then
	elements:add('volume', Element.new({
		width = nil, -- set in `on_display_change` handler based on `state.fullormaxed`
		height = nil, -- set in `on_display_change` handler based on `state.fullormaxed`
		margin = nil, -- set in `on_display_change` handler based on `state.fullormaxed`
		get_effective_proximity = function(this)
			if is_element_persistent('volume') or elements.volume_slider.pressed then return 1 end
			if this.forced_proximity then return this.forced_proximity end
			return elements.timeline.proximity_raw == 0 and 0 or this.proximity
		end,
		update_dimensions = function(this)
			this.width = state.fullormaxed and options.volume_size_fullscreen or options.volume_size
			this.height = round(math.min(this.width * 8, (elements.timeline.ay - elements.top_bar.size) * 0.8))
			-- Don't bother rendering this if too small
			if this.height < (this.width * 2) then
				this.height = 0
			end
			this.margin = (this.width / 2) + elements.window_border.size
			this.ax = round(options.volume == 'left' and this.margin or display.width - this.margin - this.width)
			this.ay = round((display.height - this.height) / 2)
			this.bx = round(this.ax + this.width)
			this.by = round(this.ay + this.height)
		end,
		on_display_change = function(this) this:update_dimensions() end,
		on_prop_border = function(this) this:update_dimensions() end,
		render = render_volume,
	}))
	elements:add('volume_mute', Element.new({
		width = 0,
		height = 0,
		on_display_change = function(this)
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
		pressed = false,
		width = 0,
		height = 0,
		nudge_y = 0, -- vertical position where volume overflows 100
		nudge_size = nil, -- set on resize
		font_size = nil,
		spacing = nil,
		on_display_change = function(this)
			if state.volume_max == nil or state.volume_max == 0 then return end
			this.ax = elements.volume.ax
			this.ay = elements.volume.ay
			this.bx = elements.volume.bx
			this.by = elements.volume_mute.ay
			this.width = this.bx - this.ax
			this.height = this.by - this.ay
			this.nudge_y = this.by - round(this.height * (100 / state.volume_max))
			this.nudge_size = round(elements.volume.width * 0.18)
			this.draw_nudge = this.ay < this.nudge_y
			this.spacing = round(this.width * 0.2)
		end,
		set_from_cursor = function(this)
			local volume_fraction = (this.by - cursor.y - options.volume_border) / (this.height - options.volume_border)
			local new_volume = math.min(math.max(volume_fraction, 0), 1) * state.volume_max
			new_volume = round(new_volume / options.volume_step) * options.volume_step
			if state.volume ~= new_volume then mp.commandv('set', 'volume', math.min(new_volume, state.volume_max)) end
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
		on_wheel_up = function(this)
			local current_rounded_volume = round(state.volume / options.volume_step) * options.volume_step
			mp.commandv('set', 'volume', math.min(current_rounded_volume + options.volume_step, state.volume_max))
		end,
		on_wheel_down = function(this)
			local current_rounded_volume = round(state.volume / options.volume_step) * options.volume_step
			mp.commandv('set', 'volume', math.min(current_rounded_volume - options.volume_step, state.volume_max))
		end,
	}))
end
if options.speed then
	elements:add('speed', Element.new({
		dragging = nil,
		width = 0,
		height = 0,
		notches = 10,
		notch_every = 0.1,
		step_distance = nil,
		font_size = nil,
		get_effective_proximity = function(this)
			if elements.timeline.proximity_raw == 0 then return 0 end
			if is_element_persistent('speed') then return 1 end
			if this.forced_proximity then return this.forced_proximity end
			local timeline_proximity = elements.timeline.forced_proximity or elements.timeline.proximity
			return this.forced_proximity or math[cursor.hidden and 'min' or 'max'](this.proximity, timeline_proximity)
		end,
		update_dimensions = function(this)
			this.height = state.fullormaxed and options.speed_size_fullscreen or options.speed_size
			this.width = round(this.height * 3.6)
			this.notch_spacing = this.width / this.notches
			this.step_distance = this.notch_spacing * (options.speed_step / this.notch_every)
			this.ax = (display.width - this.width) / 2
			this.by = display.height - elements.window_border.size - elements.timeline.size_max - elements.timeline.top_border
			this.ay = this.by - this.height
			this.bx = this.ax + this.width
			this.font_size = round(this.height * 0.48 * options.speed_font_scale)
		end,
		set_from_cursor = function(this)
			local volume_fraction = (this.by - cursor.y - options.volume_border) / (this.height - options.volume_border)
			local new_volume = math.min(math.max(volume_fraction, 0), 1) * state.volume_max
			new_volume = round(new_volume / options.volume_step) * options.volume_step
			if state.volume ~= new_volume then mp.commandv('set', 'volume', new_volume) end
		end,
		on_prop_border = function(this) this:update_dimensions() end,
		on_display_change = function(this) this:update_dimensions() end,
		on_mbtn_left_down = function(this)
			this:tween_stop() -- Stop and cleanup possible ongoing animations
			this.dragging = {
				start_time = mp.get_time(),
				start_x = cursor.x,
				distance = 0,
				start_speed = state.speed
			}
		end,
		on_global_mouse_move = function(this)
			if not this.dragging then return end

			this.dragging.distance = cursor.x - this.dragging.start_x
			local steps_dragged = round(-this.dragging.distance / this.step_distance)
			local new_speed = this.dragging.start_speed + (steps_dragged * options.speed_step)
			mp.set_property_native('speed', round(new_speed * 100) / 100)
		end,
		on_mbtn_left_up = function(this)
			-- Reset speed on short clicks
			if this.dragging and math.abs(this.dragging.distance) < 6 and mp.get_time() - this.dragging.start_time < 0.15 then
				mp.set_property_native('speed', 1)
			end
		end,
		on_global_mbtn_left_up = function(this)
			if this.dragging and elements.timeline.proximity_raw == 0 then
				this:fadeout()
			end
			this.dragging = nil
			request_render()
		end,
		on_global_mouse_leave = function(this)
			this.dragging = nil
			request_render()
		end,
		on_wheel_up = function(this)
			mp.set_property_native('speed', state.speed - options.speed_step)
		end,
		on_wheel_down = function(this)
			mp.set_property_native('speed', state.speed + options.speed_step)
		end,
		render = render_speed,
	}))
end
elements:add('curtain', Element.new({
	opacity = 0,
	fadeout = function(this)
		this:tween_property('opacity', this.opacity, 0);
	end,
	fadein = function(this)
		this:tween_property('opacity', this.opacity, 1);
	end,
	render = function(this)
		if this.opacity > 0 then
			local ass = assdraw.ass_new()
			ass:new_event()
			ass:append('{\\blur0\\bord0\\1c&H'..options.color_background..'}')
			ass:append(ass_opacity(0.4, this.opacity))
			ass:pos(0, 0)
			ass:draw_start()
			ass:rect_cw(0, 0, display.width, display.height)
			ass:draw_stop()
			return ass
		end
	end
}))

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

function parse_chapters()
	-- Sometimes state.duration is not initialized yet for some reason
	state.duration = mp.get_property_native('duration')

	local chapters = get_normalized_chapters()

	if not chapters or not state.duration then return end

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
		elements:trigger('prop_'..name, value)
		request_render()
	end
end

function update_cursor_position()
	cursor.x, cursor.y = mp.get_mouse_pos()
	update_proximities()
	request_render()
end

function handle_mouse_leave()
	-- Slowly fadeout elements that are currently visible
	for _, element_name in ipairs({'timeline', 'volume', 'top_bar'}) do
		local element = elements[element_name]
		if element and element.proximity > 0 then
			element:tween_property('forced_proximity', element:get_effective_proximity(), 0, function()
				element.forced_proximity = nil
			end)
		end
	end

	cursor.hidden = true
	update_proximities()
	elements:trigger('global_mouse_leave')
end

function handle_mouse_enter()
	cursor.hidden = false
	update_cursor_position()
	tween_element_stop(state)
	elements:trigger('global_mouse_enter')
end

function handle_mouse_move()
	-- Handle case when we are in cursor hidden state but not left the actual
	-- window (i.e. when autohide simulates mouse_leave).
	if cursor.hidden then
		handle_mouse_enter()
		return
	end

	update_cursor_position()
	elements:trigger('global_mouse_move')
	request_render()

	-- Restart timer that hides UI when mouse is autohidden
	if options.autohide then
		state.cursor_autohide_timer:kill()
		state.cursor_autohide_timer:resume()
	end
end

function navigate_directory(direction)
	local path = mp.get_property_native("path")

	if not path or is_protocol(path) then return end

	local next_file = get_adjacent_file(path, direction, options.media_types)

	if next_file then
		mp.commandv("loadfile", utils.join_path(serialize_path(path).dirname, next_file))
	end
end

function load_file_in_current_directory(index)
	local path = mp.get_property_native("path")

	if not path or is_protocol(path) then return end

	local dirname = serialize_path(path).dirname
	local files = get_files_in_directory(dirname, options.media_types)

	if not files then return end
	if index < 0 then index = #files + index + 1 end

	if files[index] then
		mp.commandv("loadfile", utils.join_path(dirname, files[index]))
	end
end

-- MENUS

function create_select_tracklist_type_menu_opener(menu_title, track_type, track_prop)
	return function()
		if menu:is_open(track_type) then menu:close() return end

		local items = {}
		local active_item = nil

		for index, track in ipairs(mp.get_property_native('track-list')) do
			if track.type == track_type then
				if track.selected then active_item = track.id end

				items[#items + 1] = {
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
			active_item = active_item and active_item + 1 or 1
			table.insert(items, 1, {hint = 'disabled', value = nil})
		end

		menu:open(items, function(id)
			mp.commandv('set', track_prop, id and id or 'no')

			-- If subtitle track was selected, assume user also wants to see it
			if id and track_type == 'sub' then
				mp.commandv('set', 'sub-visibility', 'yes')
			end

			menu:close()
		end, {type = track_type, title = menu_title, active_item = active_item})
	end
end

-- `menu_options`:
-- **allowed_types** - table with file extensions to display
-- **active_path** - full path of a file to preselect
-- Rest of the options are passed to `menu:open()`
function open_file_navigation_menu(directory, handle_select, menu_options)
	directory = serialize_path(directory)
	local directories, error = utils.readdir(directory.path, 'dirs')
	local files, error = get_files_in_directory(directory.path, menu_options.allowed_types)
	local is_root = not directory.dirname

	if not files or not directories then
		msg.error('Retrieving files from '..directory..' failed: '..(error or ''))
		return
	end

	-- Files are already sorted
	table.sort(directories, word_order_comparator)

	-- Pre-populate items with parent directory selector if not at root
	local items = is_root and {} or {
		{title = '..', hint = 'parent dir', value = directory.dirname}
	}

	for _, dir in ipairs(directories) do
		local serialized = serialize_path(utils.join_path(directory.path, dir))
		items[#items + 1] = {title = serialized.basename, value = serialized.path, hint = '/'}
	end

	menu_options.active_item = nil

	for _, file in ipairs(files) do
		local serialized = serialize_path(utils.join_path(directory.path, file))
		local item_index = #items + 1

		items[item_index] = {
			title = serialized.basename,
			value = serialized.path,
		}

		if menu_options.active_path == serialized.path then
			menu_options.active_item = item_index
		end
	end

	menu_options.selected_item = menu_options.active_item or ((is_root == false and #files > 1) and 2 or 1)
	menu_options.title = directory.basename..'/'

	menu:open(items, function(path)
		local meta, error = utils.file_info(path)

		if not meta then
			msg.error('Retrieving file info for '..path..' failed: '..(error or ''))
			return
		end

		if meta.is_dir then
			open_file_navigation_menu(path, handle_select, menu_options)
		else
			handle_select(path)
			menu:close()
		end
	end, menu_options)
end

-- VALUE SERIALIZATION/NORMALIZATION

options.proximity_out = math.max(options.proximity_out, options.proximity_in + 1)
options.chapters = itable_find({'dots', 'lines', 'lines-top', 'lines-bottom'}, options.chapters) and options.chapters or 'none'
options.media_types = split(options.media_types, ' *, *')
options.subtitle_types = split(options.subtitle_types, ' *, *')
options.stream_quality_options = split(options.stream_quality_options, ' *, *')
options.timeline_cached_ranges = (function()
	if options.timeline_cached_ranges == '' or options.timeline_cached_ranges == 'no' then return nil end
	local parts = split(options.timeline_cached_ranges, ':')
	return parts[1] and {color = parts[1], opacity = tonumber(parts[2])} or nil
end)()
for _, name in ipairs({'timeline', 'volume', 'top_bar', 'speed'}) do
	local option_name = name..'_persistency'
	local flags = {}
	for _, state in ipairs(split(options[option_name], ' *, *')) do
		flags[state] = true
	end
	options[option_name] = flags
end

-- HOOKS
mp.register_event('file-loaded', parse_chapters)
mp.observe_property('track-list', 'native', function(name, value)
	-- checks if the file is audio only (mp3, etc)
	local has_audio = false
	local has_video = false
	for _, track in ipairs(value) do
		if track.type == 'audio' then has_audio = true end
		if track.type == 'video' and not track.albumart then has_video = true end
	end
	state.is_audio = not has_video and has_audio
end)
mp.observe_property('chapter-list', 'native', parse_chapters)
mp.observe_property('border', 'bool', create_state_setter('border'))
mp.observe_property('ab-loop-a', 'number', create_state_setter('ab_loop_a'))
mp.observe_property('ab-loop-b', 'number', create_state_setter('ab_loop_b'))
mp.observe_property('duration', 'number', create_state_setter('duration'))
mp.observe_property('media-title', 'string', create_state_setter('media_title'))
mp.observe_property('fullscreen', 'bool', function(_, value)
	state.fullscreen = value
	state.fullormaxed = state.fullscreen or state.maximized
	update_display_dimensions()
	elements:trigger('prop_fullscreen', value)
	elements:trigger('prop_fullormaxed', state.fullormaxed)
end)
mp.observe_property('window-maximized', 'bool', function(_, value)
	state.maximized = value
	state.fullormaxed = state.fullscreen or state.maximized
	update_display_dimensions()
	elements:trigger('prop_maximized', value)
	elements:trigger('prop_fullormaxed', state.fullormaxed)
end)
mp.observe_property('idle-active', 'bool', create_state_setter('idle'))
mp.observe_property('speed', 'number', create_state_setter('speed'))
mp.observe_property('pause', 'bool', create_state_setter('pause'))
mp.observe_property('volume', 'number', create_state_setter('volume'))
mp.observe_property('volume-max', 'number', create_state_setter('volume_max'))
mp.observe_property('mute', 'bool', create_state_setter('mute'))
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
mp.observe_property('demuxer-cache-state', 'native', function(prop, cache_state)
	if cache_state == nil then
		state.cached_ranges = nil
		return
	end
	local cache_ranges = cache_state['seekable-ranges']
	state.cached_ranges = #cache_ranges > 0 and cache_ranges or nil
end)

-- CONTROLS

-- Mouse movement key binds
local base_keybinds = {
	{'mouse_move', handle_mouse_move},
	{'mouse_leave', handle_mouse_leave},
	{'mouse_enter', handle_mouse_enter},
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

-- Context based key bind groups

forced_key_bindings = (function()
	function create_mouse_event_dispatcher(name)
		return function(...)
			for _, element in pairs(elements) do
				if element.proximity_raw == 0 then
					element:trigger(name, ...)
				end
				element:trigger('global_'..name, ...)
			end
		end
	end

	mp.set_key_bindings({
		{'mbtn_left', create_mouse_event_dispatcher('mbtn_left_up'), create_mouse_event_dispatcher('mbtn_left_down')},
		{'mbtn_left_dbl', 'ignore'},
	}, 'mbtn_left', 'force')
	mp.set_key_bindings({
		{'wheel_up', create_mouse_event_dispatcher('wheel_up')},
		{'wheel_down', create_mouse_event_dispatcher('wheel_down')},
	}, 'wheel', 'force')

	local groups = {}
	for _, group in ipairs({'mbtn_left', 'wheel'}) do
		groups[group] = {
			is_enabled = false,
			enable = function(this)
				if this.is_enabled then return end
				this.is_enabled = true
				mp.enable_key_bindings(group)
			end,
			disable = function(this)
				if not this.is_enabled then return end
				this.is_enabled = false
				mp.disable_key_bindings(group)
			end,
		}
	end
	return groups
end)()

-- KEY BINDABLE FEATURES

mp.add_key_binding(nil, 'peek-timeline', function()
	if elements.timeline.proximity > 0.5 then
		elements.timeline:tween_property('proximity', elements.timeline.proximity, 0)
	else
		elements.timeline:tween_property('proximity', elements.timeline.proximity, 1)
	end
end)
mp.add_key_binding(nil, 'toggle-progress', function()
	local timeline = elements.timeline
	if timeline.size_min_override then
		timeline:tween_property('size_min_override', timeline.size_min_override, timeline.size_min, function()
			timeline.size_min_override = nil
		end)
	else
		timeline:tween_property('size_min_override', timeline.size_min, 0)
	end
end)
mp.add_key_binding(nil, 'flash-timeline', function()
	elements.timeline:flash()
end)
mp.add_key_binding(nil, 'flash-volume', function()
	if elements.volume then elements.volume:flash() end
end)
mp.add_key_binding(nil, 'flash-speed', function()
	if elements.speed then elements.speed:flash() end
end)
mp.add_key_binding(nil, 'flash-pause-indicator', function()
	elements.pause_indicator:flash()
end)
mp.add_key_binding(nil, 'decide-pause-indicator', function()
	elements.pause_indicator:decide()
end)
mp.add_key_binding(nil, 'menu', function()
	if menu:is_open('menu') then
		menu:close()
	elseif state.context_menu_items then
		menu:open(state.context_menu_items, function(command)
			mp.command(command)
		end, {type = 'menu'})
	end
end)
mp.add_key_binding(nil, 'load-subtitles', function()
	if menu:is_open('load-subtitles') then menu:close() return end

	local path = mp.get_property_native('path')
	if path and not is_protocol(path) then
		open_file_navigation_menu(
			serialize_path(path).dirname,
			function(path) mp.commandv('sub-add', path) end,
			{
				type = 'load-subtitles',
				allowed_types = options.subtitle_types
			}
		)
	end
end)
mp.add_key_binding(nil, 'subtitles', create_select_tracklist_type_menu_opener('Subtitles', 'sub', 'sid'))
mp.add_key_binding(nil, 'audio', create_select_tracklist_type_menu_opener('Audio', 'audio', 'aid'))
mp.add_key_binding(nil, 'video', create_select_tracklist_type_menu_opener('Video', 'video', 'vid'))
mp.add_key_binding(nil, 'playlist', function()
	if menu:is_open('playlist') then menu:close() return end

	function serialize_playlist()
		local pos = mp.get_property_number('playlist-pos-1', 0)
		local items = {}
		local active_item
		for index, item in ipairs(mp.get_property_native('playlist')) do
			local is_url = item.filename:find('://')
			items[index] = {
				title = is_url and item.filename or serialize_path(item.filename).basename,
				hint = tostring(index),
				value = index
			}

			if index == pos then active_item = index end
		end
		return items, active_item
	end

	-- Update active index and playlist content on playlist changes
	function handle_playlist_change()
		if menu:is_open('playlist') then
			local items, active_item = serialize_playlist()
			elements.menu:update({
				items = items,
				active_item = active_item
			})
		end
	end

	-- Items and active_item are set in the handle_playlist_change callback, since adding
	-- a property observer triggers its handler immediately, we just let that initialize the items.
	menu:open({}, function(index)
		mp.commandv('set', 'playlist-pos-1', tostring(index))
	end, {
		type = 'playlist',
		title = 'Playlist',
		on_open = function()
			mp.observe_property('playlist', 'native', handle_playlist_change)
			mp.observe_property('playlist-pos-1', 'native', handle_playlist_change)
		end,
		on_close = function()
			mp.unobserve_property(handle_playlist_change)
		end,
	})
end)
mp.add_key_binding(nil, 'chapters', function()
	if menu:is_open('chapters') then menu:close() return end

	local items = {}
	local chapters = get_normalized_chapters()

	for index, chapter in ipairs(chapters) do
		items[#items + 1] = {
			title = chapter.title or '',
			hint = mp.format_time(chapter.time),
			value = chapter.time
		}
	end

	-- Select first chapter from the end with time lower
	-- than current playing position (with 100ms leeway).
	function get_selected_chapter_index()
		local position = mp.get_property_native('playback-time')
		if not position then return nil end
		for index = #items, 1, -1 do
			if position - 0.1 > items[index].value then return index end
		end
	end

	-- Update selected chapter in chapter navigation menu
	function seek_handler()
		if menu:is_open('chapters') then
			elements.menu:activate_index(get_selected_chapter_index())
		end
	end

	menu:open(items, function(time)
		mp.commandv('seek', tostring(time), 'absolute')
	end, {
		type = 'chapters',
		title = 'Chapters',
		active_item = get_selected_chapter_index(),
		on_open = function() mp.register_event('seek', seek_handler) end,
		on_close = function() mp.unregister_event(seek_handler) end
	})
end)
mp.add_key_binding(nil, 'show-in-directory', function()
	local path = mp.get_property_native('path')

	-- Ignore URLs
	if not path or is_protocol(path) then return end

	path = normalize_path(path)

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
mp.add_key_binding(nil, 'stream-quality', function()
	if menu:is_open('stream-quality') then menu:close() return end

	local ytdl_format = mp.get_property_native('ytdl-format')
	local active_item = nil
	local formats = {}

	for index, height in ipairs(options.stream_quality_options) do
		local format = 'bestvideo[height<=?'..height..']+bestaudio/best[height<=?'..height..']'
		formats[#formats + 1] = {
			title = height..'p',
			value = format
		}
		if format == ytdl_format then active_item = index end
	end

	menu:open(formats, function(format)
		mp.set_property('ytdl-format', format)

		-- Reload the video to apply new format
		-- This is taken from https://github.com/jgreco/mpv-youtube-quality
		-- which is in turn taken from https://github.com/4e6/mpv-reload/
		-- Dunno if playlist_pos shenanigans below are necessary.
		local playlist_pos = mp.get_property_number('playlist-pos')
		local duration = mp.get_property_native('duration')
		local time_pos = mp.get_property('time-pos')

		mp.set_property_number('playlist-pos', playlist_pos)

		-- Tries to determine live stream vs. pre-recordered VOD. VOD has non-zero
		-- duration property. When reloading VOD, to keep the current time position
		-- we should provide offset from the start. Stream doesn't have fixed start.
		-- Decent choice would be to reload stream from it's current 'live' positon.
		-- That's the reason we don't pass the offset when reloading streams.
		if duration and duration > 0 then
			local function seeker()
				mp.commandv('seek', time_pos, 'absolute')
				mp.unregister_event(seeker)
			end
			mp.register_event('file-loaded', seeker)
		end
	end, {
		type = 'stream-quality',
		title = 'Stream quality',
		active_item = active_item,
	})
end)
mp.add_key_binding(nil, 'open-file', function()
	if menu:is_open('open-file') then menu:close() return end

	local path = mp.get_property_native('path')
	local directory
	local active_file

	if path == nil or is_protocol(path) then
		local path = serialize_path(mp.command_native({'expand-path', '~/'}))
		directory = path.path
		active_file = nil
	else
		local path = serialize_path(path)
		directory = path.dirname
		active_file = path.path
	end

	-- Update selected file in directory navigation menu
	function handle_file_loaded()
		if menu:is_open('open-file') then
			local path = normalize_path(mp.get_property_native('path'))
			elements.menu:activate_value(path)
			elements.menu:select_value(path)
		end
	end

	open_file_navigation_menu(
		directory,
		function(path) mp.commandv('loadfile', path) end,
		{
			type = 'open-file',
			allowed_types = options.media_types,
			active_path = active_file,
			on_open = function() mp.register_event('file-loaded', handle_file_loaded) end,
			on_close = function() mp.unregister_event(handle_file_loaded) end,
		}
	)
end)
mp.add_key_binding(nil, 'next', function()
	if mp.get_property_native('playlist-count') > 1 then
		mp.command('playlist-next')
	else
		navigate_directory('forward')
	end
end)
mp.add_key_binding(nil, 'prev', function()
	if mp.get_property_native('playlist-count') > 1 then
		mp.command('playlist-prev')
	else
		navigate_directory('backward')
	end
end)
mp.add_key_binding(nil, 'next-file', function() navigate_directory('forward') end)
mp.add_key_binding(nil, 'prev-file', function() navigate_directory('backward') end)
mp.add_key_binding(nil, 'first', function()
	if mp.get_property_native('playlist-count') > 1 then
		mp.commandv('set', 'playlist-pos-1', '1')
	else
		load_file_in_current_directory(1)
	end
end)
mp.add_key_binding(nil, 'last', function()
	local playlist_count = mp.get_property_native('playlist-count')
	if playlist_count > 1 then
		mp.commandv('set', 'playlist-pos-1', tostring(playlist_count))
	else
		load_file_in_current_directory(-1)
	end
end)
mp.add_key_binding(nil, 'first-file', function() load_file_in_current_directory(1) end)
mp.add_key_binding(nil, 'last-file', function() load_file_in_current_directory(-1) end)
mp.add_key_binding(nil, 'delete-file-next', function()
	local path = mp.get_property_native('path')

	if not path or is_protocol(path) then return end

	path = normalize_path(path)
	local playlist_count = mp.get_property_native('playlist-count')

	if playlist_count > 1 then
		mp.commandv('playlist-remove', 'current')
	else
		local next_file = get_adjacent_file(path, 'forward', options.media_types)

		if menu:is_open('open-file') then
			elements.menu:delete_value(path)
		end

		if next_file then
			mp.commandv('loadfile', next_file)
		else
			mp.commandv('stop')
		end
	end

	delete_file(path)
end)
mp.add_key_binding(nil, 'delete-file-quit', function()
	local path = mp.get_property_native('path')
	if not path or is_protocol(path) then return end
	mp.command('stop')
	delete_file(normalize_path(path))
	mp.command('quit')
end)
mp.add_key_binding(nil, 'open-config-directory', function()
	local config = serialize_path(mp.command_native({'expand-path', '~~/mpv.conf'}))
	local args

	if state.os == 'windows' then
		args = {'explorer', '/select,', config.path}
	elseif state.os == 'macos' then
		args = {'open', '-R', config.path}
	elseif state.os == 'linux' then
		args = {'xdg-open', config.dirname}
	end

	utils.subprocess_detached({args = args, cancellable = false})
end)
