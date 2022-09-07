--[[ uosc 3.1.2 - 2022-Aug-25 | https://github.com/tomasklaen/uosc ]]
local uosc_version = '3.1.2'

function lock_osc(name, value)
	if value == true then
		mp.set_property('osc', 'no')
	end
end
mp.observe_property('osc', 'bool', lock_osc)

local assdraw = require('mp.assdraw')
local opt = require('mp.options')
local utils = require('mp.utils')
local msg = require('mp.msg')
local osd = mp.create_osd_overlay('ass-events')
local infinity = 1e309

-- OPTIONS/CONFIG/STATE
local options = {
	timeline_style = 'line',
	timeline_line_width = 2,
	timeline_line_width_fullscreen = 3,
	timeline_line_width_minimized_scale = 10,
	timeline_size_min = 2,
	timeline_size_max = 40,
	timeline_size_min_fullscreen = 0,
	timeline_size_max_fullscreen = 60,
	timeline_start_hidden = false,
	timeline_persistency = 'paused',
	timeline_opacity = 0.9,
	timeline_border = 1,
	timeline_step = 5,
	timeline_cached_ranges = '4e845c:0.5',
	timeline_font_scale = 1,
	timeline_chapters = 'dots',
	timeline_chapters_opacity = 0.2,
	timeline_chapters_width = 6,

	controls = 'menu,gap,subtitles,<has_audio,!audio>audio,<stream>stream-quality,gap,space,speed,space,shuffle,loop-playlist,loop-file,gap,prev,items,next,gap,fullscreen',
	controls_size = 32,
	controls_size_fullscreen = 40,
	controls_margin = 8,
	controls_spacing = 2,
	controls_persistency = '',

	volume = 'right',
	volume_size = 40,
	volume_size_fullscreen = 60,
	volume_persistency = '',
	volume_opacity = 0.8,
	volume_border = 1,
	volume_step = 1,
	volume_font_scale = 1,

	speed_persistency = '',
	speed_opacity = 1,
	speed_step = 0.1,
	speed_step_is_factor = false,
	speed_font_scale = 1,

	menu_item_height = 36,
	menu_item_height_fullscreen = 50,
	menu_min_width = 260,
	menu_min_width_fullscreen = 360,
	menu_wasd_navigation = false,
	menu_hjkl_navigation = false,
	menu_opacity = 0.8,
	menu_parent_opacity = 0.4,
	menu_font_scale = 1,

	top_bar = 'no-border',
	top_bar_size = 40,
	top_bar_size_fullscreen = 46,
	top_bar_persistency = '',
	top_bar_controls = true,
	top_bar_title = true,

	window_border_size = 1,
	window_border_opacity = 0.8,

	ui_scale = 1,
	pause_on_click_shorter_than = 0,
	flash_duration = 1000,
	proximity_in = 40,
	proximity_out = 120,
	color_foreground = 'ffffff',
	color_foreground_text = '000000',
	color_background = '000000',
	color_background_text = 'ffffff',
	total_time = false,
	time_precision = 0,
	font_bold = false,
	autohide = false,
	pause_indicator = 'flash',
	curtain_opacity = 0.5,
	stream_quality_options = '4320,2160,1440,1080,720,480,360,240,144',
	directory_navigation_loops = false,
	media_types = '3gp,asf,avi,avif,bmp,flac,flv,gif,h264,h265,jpeg,jpg,jxl,m4a,m4v,mid,midi,mkv,mov,mp3,mp4,mp4a,mp4v,mpeg,mpg,oga,ogg,ogm,ogv,opus,png,rmvb,svg,tif,tiff,wav,weba,webm,webp,wma,wmv',
	subtitle_types = 'aqt,gsub,jss,sub,ttxt,pjs,psb,rt,smi,slt,ssf,srt,ssa,ass,usf,idx,vt',
	font_height_to_letter_width_ratio = 0.5,
	default_directory = '~/',
	chapter_ranges = '^op| op$|opening<968638:0.5>.*, ^ed| ed$|^end|ending$<968638:0.5>.*|{eof}, sponsor start<3535a5:.5>sponsor end, segment start<3535a5:0.5>segment end',
}
opt.read_options(options, 'uosc')
local config = {
	-- sets max rendering frequency in case the
	-- native rendering frequency could not be detected
	render_delay = 1 / 60,
	font = mp.get_property('options/osd-font'),
}
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
	version = uosc_version,
	os = (function()
		if os.getenv('windir') ~= nil then return 'windows' end
		local homedir = os.getenv('HOME')
		if homedir ~= nil and string.sub(homedir, 1, 6) == '/Users' then return 'macos' end
		return 'linux'
	end)(),
	cwd = mp.get_property('working-directory'),
	path = nil, -- current file path or URL
	media_title = '',
	time = nil, -- current media playback time
	speed = 1,
	duration = nil, -- current media duration
	time_human = nil, -- current playback time in human format
	duration_or_remaining_time_human = nil, -- depends on options.total_time
	pause = mp.get_property_native('pause'),
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
	is_video = nil,
	is_audio = nil, -- true if file is audio only (mp3, etc)
	is_image = nil,
	is_stream = nil,
	has_audio = nil,
	cursor_autohide_timer = mp.add_timeout(mp.get_property_native('cursor-autohide') / 1000, function()
		if not options.autohide then return end
		handle_mouse_leave()
	end),
	mouse_bindings_enabled = false,
	cached_ranges = nil,
	render_delay = config.render_delay,
	first_real_mouse_move_received = false,
	playlist_count = 0,
	playlist_pos = 0,
	margin_top = 0,
	margin_bottom = 0,
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
		list[#list + 1] = capture
		last_end = end_index + 1
		start_index, end_index, capture = str:find(full_pattern, last_end)
	end
	if last_end <= (#str + 1) then
		capture = str:sub(last_end)
		list[#list + 1] = capture
	end
	return list
end

---@param itable table
---@param value any
---@return integer|nil
function itable_index_of(itable, value)
	for index, item in ipairs(itable) do
		if item == value then return index end
	end
end

---@param itable table
---@param compare fun(value: any, index: number)
---@return number|nil index
---@return any|nil value
function itable_find(itable, compare)
	for index, value in ipairs(itable) do
		if compare(value, index) then return index, value end
	end
end

---@param itable table
---@param decider fun(value: any, index: number)
function itable_filter(itable, decider)
	local filtered = {}
	for index, value in ipairs(itable) do
		if decider(value, index) then filtered[#filtered + 1] = value end
	end
	return filtered
end

---@param itable table
---@param value any
function itable_remove(itable, value)
	return itable_filter(itable, function(item) return item ~= value end)
end

---@param itable table
---@param start_pos? integer
---@param end_pos? integer
function itable_slice(itable, start_pos, end_pos)
	start_pos = start_pos and start_pos or 1
	end_pos = end_pos and end_pos or #itable

	if end_pos < 0 then end_pos = #itable + end_pos + 1 end
	if start_pos < 0 then start_pos = #itable + start_pos + 1 end

	local new_table = {}
	for index, value in ipairs(itable) do
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

	return function(a, b)
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

	local function tick()
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
	return math.sqrt(dx * dx + dy * dy);
end

function text_width_estimate(text, font_size)
	if not text or text == '' then return 0 end
	local text_length = 0
	for _, _, length in utf8_iter(text) do
		text_length = text_length + length
	end
	return text_length * font_size * options.font_height_to_letter_width_ratio
end

function utf8_iter(string)
	local byte_start, byte_count = 1, 1

	return function()
		if #string < byte_start then return nil end

		local char_byte = string.byte(string, byte_start)

		byte_count = 1;
		if char_byte < 192 then byte_count = 1
		elseif char_byte < 224 then byte_count = 2
		elseif char_byte < 240 then byte_count = 3
		elseif char_byte < 248 then byte_count = 4
		elseif char_byte < 252 then byte_count = 5
		elseif char_byte < 254 then byte_count = 6
		end

		local start = byte_start
		byte_start = byte_start + byte_count

		return start, byte_count, (byte_count > 2 and 2 or 1)
	end
end

function wrap_text(text, target_line_length)
	local line_length = 0
	local wrap_at_chars = {' ', '　', '-', '–'}
	local remove_when_wrap = {' ', '　'}
	local lines = {}
	local line_start = 1
	local before_end = nil
	local before_length = 0
	local before_line_start = 0
	local before_removed_length = 0
	local max_length = 0
	for char_start, count, char_length in utf8_iter(text) do
		local char_end = char_start + count - 1
		local char = text.sub(text, char_start, char_end)
		local can_wrap = false
		for _, c in ipairs(wrap_at_chars) do
			if char == c then
				can_wrap = true
				break
			end
		end
		line_length = line_length + char_length
		if can_wrap or (char_end == #text) then
			local remove = false
			for _, c in ipairs(remove_when_wrap) do
				if char == c then
					remove = true
					break
				end
			end
			local line_length_after_remove = line_length - (remove and char_length or 0)
			if line_length_after_remove < target_line_length then
				before_end = remove and char_start - 1 or char_end
				before_length = line_length_after_remove
				before_line_start = char_end + 1
				before_removed_length = remove and char_length or 0
			else
				if (target_line_length - before_length) <
					(line_length_after_remove - target_line_length) then
					lines[#lines + 1] = text.sub(text, line_start, before_end)
					line_start = before_line_start
					line_length = line_length - before_length - before_removed_length
					if before_length > max_length then max_length = before_length end
				else
					lines[#lines + 1] = text.sub(text, line_start, remove and char_start - 1 or char_end)
					line_start = char_end + 1
					line_length = remove and line_length - char_length or line_length
					if line_length > max_length then max_length = line_length end
					line_length = 0
				end
				before_end = line_start
				before_length = 0
			end
		end
	end
	if #text >= line_start then
		lines[#lines + 1] = string.sub(text, line_start)
		if line_length > max_length then max_length = line_length end
	end
	return table.concat(lines, '\n'), max_length
end

-- Escape a string for verbatim display on the OSD
function ass_escape(str)
	-- There is no escape for '\' in ASS (I think?) but '\' is used verbatim if
	-- it isn't followed by a recognized character, so add a zero-width
	-- non-breaking space
	str = str:gsub('\\', '\\\239\187\191')
	str = str:gsub('{', '\\{')
	str = str:gsub('}', '\\}')
	-- Precede newlines with a ZWNBSP to prevent ASS's weird collapsing of
	-- consecutive newlines
	str = str:gsub('\n', '\239\187\191\\N')
	-- Turn leading spaces into hard spaces to prevent ASS from stripping them
	str = str:gsub('\\N ', '\\N\\h')
	str = str:gsub('^ ', '\\h')
	return str
end

---@param seconds number
---@return string
function format_time(seconds)
	local human = mp.format_time(seconds)
	if options.time_precision > 0 then
		local formatted = string.format('%.' .. options.time_precision .. 'f', math.abs(seconds) % 1)
		human = human .. '.' .. string.sub(formatted, 3)
	end
	return human
end

function opacity_to_alpha(opacity)
	return 255 - math.ceil(255 * opacity)
end

-- Ensures path is absolute and normalizes slashes to the current platform
function normalize_path(path)
	if not path or is_protocol(path) then return path end

	-- Ensure path is absolute
	if not (path:match('^/') or path:match('^%a+:') or path:match('^\\\\')) then
		path = utils.join_path(state.cwd, path)
	end

	-- Remove trailing slashes
	if #path > 1 then
		path = path:gsub('[\\/]+$', '')
		path = #path == 0 and '/' or path
	end

	-- Use proper slashes
	if state.os == 'windows' then
		-- Drive letters on windows need trailing backslash
		if path:sub(#path) == ':' then
			path = path .. '\\'
		end

		return path:gsub('/', '\\')
	else
		return path:gsub('\\', '/')
	end
end

-- Check if path is a protocol, such as `http://...`
function is_protocol(path)
	return type(path) == 'string' and path:match('^%a[%a%d-_]+://')
end

function get_extension(path)
	local parts = split(path, '%.')
	return parts and #parts > 1 and parts[#parts] or nil
end

function get_default_directory()
	return mp.command_native({'expand-path', options.default_directory})
end

-- Serializes path into its semantic parts
function serialize_path(path)
	if not path or is_protocol(path) then return end

	local normal_path = normalize_path(path)
	-- normalize_path() already strips slashes, but leaves trailing backslash
	-- for windows drive letters, but we don't need it here.
	local working_path = normal_path:sub(#normal_path) == '\\' and normal_path:sub(1, #normal_path - 1) or normal_path
	local parts = split(working_path, '[\\/]+')
	local basename = parts and parts[#parts] or working_path
	local dirname = #parts > 1
		and table.concat(itable_slice(parts, 1, #parts - 1), state.os == 'windows' and '\\' or '/')
		or nil
	local dot_split = split(basename, '%.')

	return {
		path = normal_path,
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
		msg.error('Retrieving files failed: ' .. (error or ''))
		return
	end

	-- Filter only requested file types
	if allowed_types then
		files = itable_filter(files, function(file)
			local extension = get_extension(file)
			return extension and itable_index_of(allowed_types, extension:lower())
		end)
	end

	table.sort(files, word_order_comparator)

	return files
end

function get_adjacent_file(file_path, direction, allowed_types)
	local current_file = serialize_path(file_path)
	if not current_file then return end
	local files = get_files_in_directory(current_file.dirname, allowed_types)
	if not files then return end

	for index, file in ipairs(files) do
		if current_file.basename == file then
			if direction == 'forward' then
				if files[index + 1] then return utils.join_path(current_file.dirname, files[index + 1]) end
				if options.directory_navigation_loops and files[1] then
					return utils.join_path(current_file.dirname, files[1])
				end
			else
				if files[index - 1] then return utils.join_path(current_file.dirname, files[index - 1]) end
				if options.directory_navigation_loops and files[#files] then
					return utils.join_path(current_file.dirname, files[#files])
				end
			end

			-- This is the only file in directory
			return nil
		end
	end
end

-- Can't use `os.remove()` as it fails on paths with unicode characters.
-- Returns `result, error`, result is table of:
-- `status:number(<0=error), stdout, stderr, error_string, killed_by_us:boolean`
function delete_file(file_path)
	local args = state.os == 'windows' and {'cmd', '/C', 'del', file_path} or {'rm', file_path}
	return mp.command_native({
		name = 'subprocess',
		args = args,
		playback_only = false,
		capture_stdout = true,
		capture_stderr = true,
	})
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

-- ASSDRAW EXTENSIONS

local ass_mt = getmetatable(assdraw.ass_new())

-- Opacity
---@param opacity number|number[] Opacity of all elements, or an array of [primary, secondary, border, shadow] opacities.
---@param fraction? number Optionally adjust the above opacity by this fraction.
function ass_mt:opacity(opacity, fraction)
	fraction = fraction ~= nil and fraction or 1
	if type(opacity) == 'number' then
		self.text = self.text .. string.format('{\\alpha&H%X&}', opacity_to_alpha(opacity * fraction))
	else
		self.text = self.text .. string.format(
			'{\\1a&H%X&\\2a&H%X&\\3a&H%X&\\4a&H%X&}',
			opacity_to_alpha((opacity[1] or 0) * fraction),
			opacity_to_alpha((opacity[2] or 0) * fraction),
			opacity_to_alpha((opacity[3] or 0) * fraction),
			opacity_to_alpha((opacity[4] or 0) * fraction)
		)
	end
end

-- Icon
---@param x number
---@param y number
---@param size number
---@param name string
---@param opts? {color?: string; border?: number; border_color?: string; opacity?: number; clip?: string; align?: number}
function ass_mt:icon(x, y, size, name, opts)
	opts = opts or {}
	opts.size = size
	opts.font = 'MaterialIconsSharp-Regular'
	self:txt(x, y, opts.align or 5, name, opts)
end

-- String
-- Named `txt` because `ass.text` is a value.
---@param x number
---@param y number
---@param align number
---@param value string|number
---@param opts {size: number; font?: string; color?: string; bold?: boolean; italic?: boolean; border?: number; border_color?: string; shadow?: number; shadow_color?: string; wrap?: number; opacity?: number; clip?: string}
function ass_mt:txt(x, y, align, value, opts)
	local border_size = opts.border or 0
	local shadow_size = opts.shadow or 0
	local tags = '\\pos(' .. x .. ',' .. y .. ')\\an' .. align .. '\\blur0'
	-- font
	tags = tags .. '\\fn' .. (opts.font or config.font)
	-- font size
	tags = tags .. '\\fs' .. opts.size
	-- bold
	if opts.bold then tags = tags .. '\\b1' end
	-- italic
	if opts.italic then tags = tags .. '\\i1' end
	-- wrap
	if opts.wrap then tags = tags .. '\\q' .. opts.wrap end
	-- border
	tags = tags .. '\\bord' .. border_size
	-- shadow
	tags = tags .. '\\shad' .. shadow_size
	-- colors
	tags = tags .. '\\1c&H' .. (opts.color or options.color_foreground)
	if border_size > 0 then
		tags = tags .. '\\3c&H' .. (opts.border_color or options.color_background)
	end
	if shadow_size > 0 then
		tags = tags .. '\\4c&H' .. (opts.shadow_color or options.color_background)
	end
	-- opacity
	if opts.opacity then
		tags = tags .. string.format('\\alpha&H%X&', opacity_to_alpha(opts.opacity))
	end
	-- clip
	if opts.clip then
		tags = tags .. opts.clip
	end
	-- render
	self:new_event()
	self.text = self.text .. '{' .. tags .. '}' .. value
end

-- Tooltip
---@param element {ax: number; ay: number; bx: number; by: number}
---@param value string|number
---@param opts? {size?: number; offset?: number; align?: number; bold?: boolean; italic?: boolean; text_length_override?: number}
function ass_mt:tooltip(element, value, opts)
	opts = opts or {}
	opts.size = opts.size or 16
	opts.border = 1
	opts.border_color = options.color_background
	local offset = opts.offset or opts.size / 2
	local align_top = element.ay - offset > opts.size * 5
	local x = element.ax + (element.bx - element.ax) / 2
	local y = align_top and element.ay - offset or element.by + offset
	local text_width = opts.text_length_override
		and opts.text_length_override * opts.size * options.font_height_to_letter_width_ratio
		or text_width_estimate(value, opts.size)
	local margin = text_width / 2
	self:txt(math.max(margin, math.min(x, display.width - margin)), y, align_top and 2 or 8, value, opts)
end

-- Rectangle
---@param ax number
---@param ay number
---@param bx number
---@param by number
---@param opts? {color?: string; border?: number; border_color?: string; opacity?: number; clip?: string, radius?: number}
function ass_mt:rect(ax, ay, bx, by, opts)
	opts = opts or {}
	local border_size = opts.border or 0
	local tags = '\\pos(0,0)\\blur0'
	-- border
	tags = tags .. '\\bord' .. border_size
	-- colors
	tags = tags .. '\\1c&H' .. (opts.color or options.color_foreground)
	if border_size > 0 then
		tags = tags .. '\\3c&H' .. (opts.border_color or options.color_background)
	end
	-- opacity
	if opts.opacity then
		tags = tags .. string.format('\\alpha&H%X&', opacity_to_alpha(opts.opacity))
	end
	-- clip
	if opts.clip then
		tags = tags .. opts.clip
	end
	-- draw
	self:new_event()
	self.text = self.text .. '{' .. tags .. '}'
	self:draw_start()
	if opts.radius then
		self:round_rect_cw(ax, ay, bx, by, opts.radius)
	else
		self:rect_cw(ax, ay, bx, by)
	end
	self:draw_stop()
end

-- Circle
---@param x number
---@param y number
---@param radius number
---@param opts? {color?: string; border?: number; border_color?: string; opacity?: number; clip?: string}
function ass_mt:circle(x, y, radius, opts)
	opts = opts or {}
	opts.radius = radius
	self:rect(x - radius, y - radius, x + radius, y + radius, opts)
end

-- ELEMENTS

local Elements = {itable = {}}

function Elements:add(element)
	if not element.id then
		msg.error('attempt to add element without "id" property')
		return
	end

	if self:has(element.id) then Elements:remove(element.id) end

	self.itable[#self.itable + 1] = element
	self[element.id] = element
	request_render()
end

function Elements:remove(idOrElement)
	if not idOrElement then return end
	local id = type(idOrElement) == 'table' and idOrElement.id or idOrElement
	local element = Elements[id]
	if element then
		element:destroy()
		self.itable = itable_remove(self.itable, self[id])
		self[id] = nil
		request_render()
	end
end

function Elements:trigger(name, ...)
	for _, element in self:ipairs() do element:trigger(name, ...) end
end

function Elements:has(id) return self[id] ~= nil end

function Elements:ipairs() return ipairs(self.itable) end

-- Element
--[[
Signature:
{
	-- element rectangle coordinates
	ax = 0, ay = 0, bx = 0, by = 0,
	-- cursor<->element relative proximity as a 0-1 floating number
	-- where 0 = completely away, and 1 = touching/hovering
	-- so it's easy to work with and throw into equations
	proximity = 0,
	-- raw cursor<->element proximity in pixels
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

-- Element object props used by proximity, events, renderer, or other parts ot the system:
-- `id`: `string` REQUIRED - every element has to have a unique ID
-- `enabled`: `boolean` - determines element's visibility and interactivity (mouse, keyboard). element still receives
--                        `on_prop_{name}` and other environment events
-- `ignores_menu` - don't hide when menu is open
-- `ax,ay,bx,by`: `number` - element's coordinates used to determine proximity, element is responsible for setting these
-- `proximity`: `number` - element's proximity to the cursor. set by system before mouse_move is fired
--                         fraction between `0` = away, `1` = touching/above
-- `proximity_raw`: `number` - element's raw proximity to the cursor in pixels. set by system before mouse_move event
-- `anchor_id` - id of an element from which this one should inherit proximity via max(this.proximity, anchor.proximity)
-- `on_{event_name}`: `function` (optional) - binds a listener to `{event_name}` when defined. Example events:
--                                            `on_mbt_left_down`, `on_prop_has_audio`
---@param id string
---@param props {enabled: boolean}
function Element.new(id, props)
	props.id = id
	local element = setmetatable(props, Element)
	element._eventListeners = {}

	-- Flash timer
	element._flash_out_timer = mp.add_timeout(options.flash_duration / 1000, function()
		local getTo = function() return element.proximity end
		element:tween_property('forced_visibility', 1, getTo, function()
			element.forced_visibility = nil
		end)
	end)
	element._flash_out_timer:kill()

	element:init()

	return element
end

function Element:init() end

function Element:destroy() end

-- Decide elements visibility based on proximity and various other factors
function Element:get_visibility()
	-- Hide when menu is open, unless this is a menu
	---@diagnostic disable-next-line: undefined-global
	if not self.ignores_menu and menu and menu:is_open() then return 0 end

	-- Persistency
	local persist = options[self.id .. '_persistency'];
	if persist and (
		(persist.audio and state.is_audio)
			or (persist.paused and state.pause)
			or (persist.video and state.is_video)
			or (persist.image and state.is_image)
		) then return 1 end

	-- Forced proximity
	if self.forced_visibility then return self.forced_visibility end

	-- Anchor inheritance
	-- If anchor returns -1, it means all attached elements should force hide.
	local anchor = self.anchor_id and Elements[self.anchor_id]
	local anchor_visibility = anchor and anchor:get_visibility() or 0

	return self.forced_visibility or (anchor_visibility == -1 and 0 or math.max(self.proximity, anchor_visibility))
end

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
	local preexistingIndex = itable_index_of(self._eventListeners[name], handler)
	if preexistingIndex then
		return
	else
		self._eventListeners[name][#self._eventListeners[name] + 1] = handler
	end
end

function Element:off(name, handler)
	if self._eventListeners[name] == nil then return end
	local index = itable_index_of(self._eventListeners, handler)
	if index then table.remove(self._eventListeners, index) end
end

function Element:trigger(name, ...)
	self:maybe('on_' .. name, ...)
	if self._eventListeners[name] == nil then return end
	for _, handler in ipairs(self._eventListeners[name]) do handler(...) end
	request_render()
end

-- Briefly flashes the element for `options.flash_duration` milliseconds.
-- Useful to visualize changes of volume and timeline when changed via hotkeys.
-- Implemented by briefly adding animated `forced_visibility` property to the element.
function Element:flash()
	if options.flash_duration > 0 and (self.proximity < 1 or self._flash_out_timer:is_enabled()) then
		self:tween_stop()
		self.forced_visibility = 1
		self._flash_out_timer:kill()
		self._flash_out_timer:resume()
	end
end

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
	return Elements.menu ~= nil and (not menu_type or Elements.menu.type == menu_type)
end

---@alias MenuItem {title?: string, hint?: string, value: any}
---@alias MenuOptions {type?: string; title?: string, active_index?: number, selected_index?: number, on_open?: fun(), on_close?: fun(), parent_menu?: any}

---@param items MenuItem[]
---@param open_item fun(value: any)
---@param opts? MenuOptions
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
		Elements.curtain:fadein()
	end

	Elements:add(Element.new('menu', {
		enabled = true,
		ignores_menu = true,
		type = nil, -- menu type such as `menu`, `chapters`, ...
		title = nil,
		estimated_max_width = nil,
		width = nil,
		height = nil,
		offset_x = 0, -- used to animated from/to left when submenu
		item_height = nil,
		item_spacing = 1,
		item_content_spacing = nil,
		font_size = nil,
		font_size_hint = nil,
		scroll_step = nil, -- item height + item spacing
		scroll_height = nil, -- items + spacings - container height
		scroll_y = 0,
		opacity = 0,
		relative_parent_opacity = 0.4,
		items = items,
		active_index = nil,
		selected_index = nil,
		open_item = open_item,
		parent_menu = nil,
		init = function(this)
			-- Already initialized
			if this.width ~= nil then return end

			-- Apply options
			for key, value in pairs(opts) do this[key] = value end

			if not this.selected_index then
				this.selected_index = this.active_index
			end

			-- Set initial dimensions
			this:update_content_dimensions()
			this:on_display_change()

			-- Scroll to selected item
			this:scroll_to_item(this.selected_index)

			-- Transition in animation
			menu.transition = {to = 'child', target = this}
			local start_offset = this.parent_menu and (this.parent_menu.width + this.width) / 2 or 0

			tween_element(menu.transition.target, 0, 1, function(_, pos)
				this:set_offset_x(round(start_offset * (1 - pos)))
				this.opacity = pos
				this:set_parent_opacity(1 - ((1 - options.menu_parent_opacity) * pos))
			end, function()
				menu.transition = nil
				update_proximities()
			end)
		end,
		update_content_dimensions = function(this)
			this.item_height = state.fullormaxed and options.menu_item_height_fullscreen or options.menu_item_height
			this.font_size = round(this.item_height * 0.48 * options.menu_font_scale)
			this.font_size_hint = this.font_size - 1
			this.item_content_spacing = round((this.item_height - this.font_size) * 0.6)
			this.scroll_step = this.item_height + this.item_spacing

			-- Estimate width of a widest item
			local estimated_max_width = 0
			for _, item in ipairs(this.items) do
				local spacings_in_item = item.hint and 3 or 2
				local has_submenu = item.items ~= nil
				-- M as a stand in for icon
				local hint_icon = item.hint or (has_submenu and 'M' or nil)
				local hint_icon_size = item.hint and this.font_size_hint or this.font_size
				item.title_width = text_width_estimate(item.title, this.font_size)
				item.hint_width = text_width_estimate(hint_icon, hint_icon_size)
				local estimated_width = item.title_width + item.hint_width
					+ (this.item_content_spacing * spacings_in_item)
				if estimated_width > estimated_max_width then
					estimated_max_width = estimated_width
				end
			end

			-- Also check menu title
			local menu_title = this.title and this.title or ''
			local estimated_menu_title_width = text_width_estimate(menu_title, this.font_size)
			if estimated_menu_title_width > estimated_max_width then
				estimated_max_width = estimated_menu_title_width
			end

			this.estimated_max_width = estimated_max_width

			if this.parent_menu then
				this.parent_menu:update_content_dimensions()
			end
		end,
		update_dimensions = function(this)
			-- Coordinates and sizes are of the scrollable area to make
			-- consuming values in rendering easier. Title drawn above this, so
			-- we need to account for that in max_height and ay position.
			local min_width = state.fullormaxed and options.menu_min_width_fullscreen or options.menu_min_width
			this.width = round(math.min(math.max(this.estimated_max_width, min_width), display.width * 0.9))
			local title_height = this.title and this.scroll_step or 0
			local max_height = round(display.height * 0.9) - title_height
			this.height = math.min(round(this.scroll_step * #this.items) - this.item_spacing, max_height)
			this.scroll_height = math.max((this.scroll_step * #this.items) - this.height - this.item_spacing, 0)
			this:scroll_to(this.scroll_y) -- re-applies scroll limits
		end,
		on_display_change = function(this)
			this:update_dimensions()

			local title_height = this.title and this.scroll_step or 0
			this.ax = round((display.width - this.width) / 2) + this.offset_x
			this.ay = round((display.height - this.height) / 2 + (title_height / 2))
			this.bx = round(this.ax + this.width)
			this.by = round(this.ay + this.height)

			if this.parent_menu then
				this.parent_menu:on_display_change()
			end

			-- Update offsets for new sizes
			-- needs to be called after the widths of the parents has been updated
			this:set_offset_x(this.offset_x)
		end,
		on_prop_fullormaxed = function(this)
			this:update_content_dimensions()
			this:on_display_change()
		end,
		update = function(this, props)
			if props then
				for key, value in pairs(props) do this[key] = value end
			end

			-- Trigger changes and re-render
			this:update_content_dimensions()
			this:on_display_change()

			-- Reset indexes and scroll
			this:select_index(this.selected_index or this.active_index or (this.items and #this.items > 0 and 1 or nil))
			this:activate_index(this.active_index)
			this:scroll_to(this.scroll_y)
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
				this:set_parent_opacity(pos * options.menu_parent_opacity)
			end, callback)
		end,
		set_parent_opacity = function(this, opacity)
			if this.parent_menu then
				this.parent_menu.opacity = opacity
				this.parent_menu:set_parent_opacity(opacity * options.menu_parent_opacity)
			end
		end,
		get_item_index_below_cursor = function(this)
			if #this.items < 1 then return nil end
			return math.max(1, math.min(math.ceil((cursor.y - this.ay + this.scroll_y) / this.scroll_step), #this.items))
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
			this.selected_index = (index and index >= 1 and index <= #this.items) and index or nil
			request_render()
		end,
		select_value = function(this, value)
			this:select_index(itable_find(this.items, function(_, item) return item.value == value end))
		end,
		activate_index = function(this, index)
			this.active_index = (index and index >= 1 and index <= #this.items) and index or nil
			if not this.selected_index then
				this.selected_index = this.active_index
				this:scroll_to_item(this.selected_index)
			end
			request_render()
		end,
		activate_value = function(this, value)
			this:activate_index(itable_find(this.items, function(_, item) return item.value == value end))
		end,
		delete_index = function(this, index)
			if (index and index >= 1 and index <= #this.items) then
				local previous_active_value = this.active_index and this.items[this.active_index].value or nil
				table.remove(this.items, index)
				this:update_content_dimensions()
				this:on_display_change()
				if previous_active_value then this:activate_value(previous_active_value) end
				this:scroll_to_item(this.selected_index)
			end
		end,
		delete_value = function(this, value)
			this:delete_index(itable_find(this.items, function(_, item) return item.value == value end))
		end,
		prev = function(this)
			this.selected_index = math.max(this.selected_index and this.selected_index - 1 or #this.items, 1)
			this:scroll_to_item(this.selected_index)
		end,
		next = function(this)
			this.selected_index = math.min(this.selected_index and this.selected_index + 1 or 1, #this.items)
			this:scroll_to_item(this.selected_index)
		end,
		back = function(this)
			if menu.transition then
				local transition_target = menu.transition.target
				local transition_target_type = menu.transition.target
				tween_element_stop(transition_target)
				if transition_target_type == 'parent' then
					Elements:add(transition_target)
				end
				menu.transition = nil
				if transition_target then transition_target:back() end
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
				this:set_parent_opacity(options.menu_parent_opacity + ((1 - options.menu_parent_opacity) * pos))
			end, function()
				menu.transition = nil
				Elements:add(target)
				update_proximities()
			end)
		end,
		open_selected_item = function(this, soft)
			-- If there is a transition active and this method got called, it
			-- means we are animating from this menu to parent menu, and all
			-- calls to this method should be relayed to the parent menu.
			if menu.transition and menu.transition.to == 'parent' then
				local target = menu.transition.target
				tween_element_stop(target)
				menu.transition = nil
				if target then target:open_selected_item(soft) end
				return
			end

			if this.selected_index then
				local item = this.items[this.selected_index]
				-- Is submenu
				if item.items then
					menu:open(item.items, this.open_item, {
						type = this.type,
						parent_menu = this,
						selected_index = #item.items > 0 and 1 or nil,
					})
				else
					if soft ~= true then menu:close(true) end
					this.open_item(item.value)
				end
			end
		end,
		open_selected_item_soft = function(this) this:open_selected_item(true) end,
		close = function(this) menu:close() end,
		on_global_mbtn_left_down = function(this)
			if this.proximity_raw == 0 then
				this.selected_index = this:get_item_index_below_cursor()
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
				this.selected_index = this:get_item_index_below_cursor()
			else
				if this.selected_index then this.selected_index = nil end
			end
			request_render()
		end,
		on_wheel_up = function(this)
			this.selected_index = nil
			this:scroll_to(this.scroll_y - this.scroll_step)
			this:on_global_mouse_move() -- selects item below cursor
			request_render()
		end,
		on_wheel_down = function(this)
			this.selected_index = nil
			this:scroll_to(this.scroll_y + this.scroll_step)
			this:on_global_mouse_move() -- selects item below cursor
			request_render()
		end,
		on_pgup = function(this)
			local items_per_page = round((this.height / this.scroll_step) * 0.4)
			local paged_index = (this.selected_index and this.selected_index or #this.items) - items_per_page
			this.selected_index = math.min(math.max(1, paged_index), #this.items)
			if this.selected_index > 0 then this:scroll_to_item(this.selected_index) end
		end,
		on_pgdwn = function(this)
			local items_per_page = round((this.height / this.scroll_step) * 0.4)
			local paged_index = (this.selected_index and this.selected_index or 1) + items_per_page
			this.selected_index = math.min(math.max(1, paged_index), #this.items)
			if this.selected_index > 0 then this:scroll_to_item(this.selected_index) end
		end,
		on_home = function(this)
			this.selected_index = math.min(1, #this.items)
			if this.selected_index > 0 then this:scroll_to_item(this.selected_index) end
		end,
		on_end = function(this)
			this.selected_index = #this.items
			if this.selected_index > 0 then this:scroll_to_item(this.selected_index) end
		end,
		render = render_menu,
	}))

	Elements.menu:maybe('on_open')
end

function Menu:add_key_binding(key, name, fn, flags)
	menu.key_bindings[#menu.key_bindings + 1] = name
	mp.add_forced_key_binding(key, name, fn, flags)
end

function Menu:enable_key_bindings()
	menu.key_bindings = {}
	-- The `mp.set_key_bindings()` method would be easier here, but that
	-- doesn't support 'repeatable' flag, so we are stuck with this monster.
	menu:add_key_binding('up', 'menu-prev1', self:create_action('prev'), 'repeatable')
	menu:add_key_binding('down', 'menu-next1', self:create_action('next'), 'repeatable')
	menu:add_key_binding('left', 'menu-back1', self:create_action('back'))
	menu:add_key_binding('right', 'menu-select1', self:create_action('open_selected_item'))
	menu:add_key_binding('shift+right', 'menu-select-soft1', self:create_action('open_selected_item_soft'))
	menu:add_key_binding('shift+mbtn_left', 'menu-select-soft', self:create_action('open_selected_item_soft'))

	if options.menu_wasd_navigation then
		menu:add_key_binding('w', 'menu-prev2', self:create_action('prev'), 'repeatable')
		menu:add_key_binding('a', 'menu-back2', self:create_action('back'))
		menu:add_key_binding('s', 'menu-next2', self:create_action('next'), 'repeatable')
		menu:add_key_binding('d', 'menu-select2', self:create_action('open_selected_item'))
		menu:add_key_binding('shift+d', 'menu-select-soft2', self:create_action('open_selected_item_soft'))
	end

	if options.menu_hjkl_navigation then
		menu:add_key_binding('h', 'menu-back3', self:create_action('back'))
		menu:add_key_binding('j', 'menu-next3', self:create_action('next'), 'repeatable')
		menu:add_key_binding('k', 'menu-prev3', self:create_action('prev'), 'repeatable')
		menu:add_key_binding('l', 'menu-select3', self:create_action('open_selected_item'))
		menu:add_key_binding('shift+l', 'menu-select-soft3', self:create_action('open_selected_item_soft'))
	end

	menu:add_key_binding('mbtn_back', 'menu-back-alt3', self:create_action('back'))
	menu:add_key_binding('bs', 'menu-back-alt4', self:create_action('back'))
	menu:add_key_binding('enter', 'menu-select-alt3', self:create_action('open_selected_item'))
	menu:add_key_binding('kp_enter', 'menu-select-alt4', self:create_action('open_selected_item'))
	menu:add_key_binding('esc', 'menu-close', self:create_action('close'))
	menu:add_key_binding('pgup', 'menu-page-up', self:create_action('on_pgup'))
	menu:add_key_binding('pgdwn', 'menu-page-down', self:create_action('on_pgdwn'))
	menu:add_key_binding('home', 'menu-home', self:create_action('on_home'))
	menu:add_key_binding('end', 'menu-end', self:create_action('on_end'))
end

function Menu:disable_key_bindings()
	for _, name in ipairs(menu.key_bindings) do mp.remove_key_binding(name) end
	menu.key_bindings = {}
end

function Menu:create_action(name)
	return function(...)
		if Elements.menu then Elements.menu:maybe(name, ...) end
	end
end

function Menu:close(immediate, callback)
	if type(immediate) ~= 'boolean' then callback = immediate end

	if Elements:has('menu') and not menu.is_closing then
		local function close()
			local current_menu = Elements.menu
			while current_menu do
				current_menu:maybe('on_close')
				current_menu = current_menu.parent_menu
			end
			Elements:remove('menu')
			menu.is_closing = false
			update_proximities()
			menu:disable_key_bindings()
			call_me_maybe(callback)
			request_render()
		end

		menu.is_closing = true
		Elements.curtain:fadeout()

		if immediate then
			close()
		else
			Elements.menu:fadeout(close)
		end
	end
end

-- STATE UPDATES

function update_display_dimensions()
	local dpi_scale = mp.get_property_native('display-hidpi-scale', 1.0)
	dpi_scale = dpi_scale * options.ui_scale

	local width, height, aspect = mp.get_osd_size()
	display.width = width / dpi_scale
	display.height = height / dpi_scale
	display.aspect = aspect

	-- Tell elements about this
	Elements:trigger('display_change')

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
		element.proximity = 1 - (math.min(math.max(element.proximity_raw - options.proximity_in, 0), range) / range)
	end
end

function update_proximities()
	local capture_mbtn_left = false
	local capture_wheel = false
	local menu_only = menu:is_open()
	local mouse_leave_elements = {}
	local mouse_enter_elements = {}

	-- Calculates proximities and opacities for defined elements
	for _, element in Elements:ipairs() do
		if element.enabled then
			local previous_proximity_raw = element.proximity_raw

			-- If menu is open, all other elements have to be disabled
			if menu_only then
				if element.ignores_menu then
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

function update_fullormaxed()
	state.fullormaxed = state.fullscreen or state.maximized
	update_display_dimensions()
	Elements:trigger('prop_fullormaxed', state.fullormaxed)
end

function update_human_times()
	if state.time then
		state.time_human = format_time(state.time)
		if state.duration then
			local speed = state.speed or 1
			state.duration_or_remaining_time_human = format_time(
				options.total_time and state.duration or ((state.time - state.duration) / speed)
			)
		else
			state.duration_or_remaining_time_human = nil
		end
	else
		state.time_human = nil
	end
end

function update_margins()
	-- margins are normalized to window size
	local top, bottom = 0, 0
	local timeline, top_bar, controls = Elements.timeline, Elements.top_bar, Elements.controls

	local bottom_y = controls and controls.enabled and controls.ay or timeline.ay
	bottom = (display.height - bottom_y) / display.height

	if top_bar.enabled and top_bar:get_visibility() ~= 0 then
		top = (top_bar.size or 0) / display.height
	end

	if top == state.margin_top and bottom == state.margin_bottom then return end

	state.margin_top = top
	state.margin_bottom = bottom

	utils.shared_script_property_set('osc-margins', string.format('%f,%f,%f,%f', 0, 0, top, bottom))
end

-- ELEMENT RENDERERS

function render_timeline(this)
	if this.size_max == 0 then return end

	local size_min = this:get_effective_size_min()
	local size = this:get_effective_size()

	if size < 1 then return end

	local ass = assdraw.ass_new()

	-- Text opacity rapidly drops to 0 just before it starts overflowing, or before it reaches timeline.size_min
	local hide_text_below = math.max(this.font_size * 0.7, size_min * 2)
	local hide_text_ramp = hide_text_below / 2
	local text_opacity = math.max(math.min(size - hide_text_below, hide_text_ramp), 0) / hide_text_ramp

	local spacing = math.max(math.floor((this.size_max - this.font_size) / 2.5), 4)
	local progress = state.time / state.duration
	local is_line = options.timeline_style == 'line'

	-- Foreground & Background bar coordinates
	local bax, bay, bbx, bby = this.ax, this.by - size - this.top_border, this.bx, this.by
	local fax, fay, fbx, fby = 0, bay + this.top_border, 0, bby

	-- Controls the padding of time on the timeline due to line width.
	-- It's a distance from the center of the line to its edge when at the
	-- start or end of the timeline. Effectively half of the line width.
	local time_padding = 0

	if is_line then
		local minimized_fraction = 1 - (size - size_min) / (this.size_max - size_min)
		local width_normal = this:get_effective_line_width()
		local max_min_width_delta = size_min > 0
			and width_normal - width_normal * options.timeline_line_width_minimized_scale
			or 0
		local line_width = width_normal - (max_min_width_delta * minimized_fraction)
		local current_time_x = (bbx - bax - line_width) * progress
		fax = current_time_x + bax
		fbx = fax + line_width
		if line_width > 2 then time_padding = round(line_width / 2) end
	else
		fax = bax
		fbx = bax + this.width * progress
	end

	local time_x = bax + time_padding
	local time_width = this.width - time_padding * 2
	local foreground_size = fby - fay
	local foreground_coordinates = round(fax) .. ',' .. fay .. ',' .. round(fbx) .. ',' .. fby -- for clipping

	-- Background
	ass:new_event()
	ass:pos(0, 0)
	ass:append('{\\blur0\\bord0\\1c&H' .. options.color_background .. '}')
	ass:opacity(math.max(options.timeline_opacity - 0.1, 0))
	ass:draw_start()
	ass:rect_cw(bax, bay, fax, bby) --left of progress
	ass:rect_cw(fbx, bay, bbx, bby) --right of progress
	ass:rect_cw(fax, bay, fbx, fay) --above progress
	ass:draw_stop()

	-- Progress
	local function render_progress()
		ass:rect(fax, fay, fbx, fby, {opacity = options.timeline_opacity})
	end

	-- Custom ranges
	local function render_ranges()
		if state.chapter_ranges ~= nil then
			for i, chapter_range in ipairs(state.chapter_ranges) do
				for i, range in ipairs(chapter_range.ranges) do
					local rax = time_x + time_width * (range['start'].time / state.duration)
					local rbx = time_x + time_width * (range['end'].time / state.duration)
					-- for 1px chapter size, use the whole size of the bar including padding
					local ray = size <= 1 and bay or fay
					local rby = size <= 1 and bby or fby
					ass:rect(rax, ray, rbx, rby, {color = chapter_range.color, opacity = chapter_range.opacity})
				end
			end
		end
	end

	-- Chapters
	local function render_chapters()
		if (
			options.timeline_chapters == 'never'
				or (
				(state.chapters == nil or #state.chapters == 0)
					and state.ab_loop_a == nil
					and state.ab_loop_b == nil
				)
			) then return end

		local dots = false
		-- Defaults are for `lines`
		local chapter_width = options.timeline_chapters_width
		local chapter_height, chapter_y
		if options.timeline_chapters == 'dots' then
			dots = true
			chapter_height = math.min(chapter_width, (foreground_size / 2) + 1)
			chapter_y = fay + chapter_height / 2
		elseif options.timeline_chapters == 'lines' then
			chapter_height = size
			chapter_y = fay + (chapter_height / 2)
		elseif options.timeline_chapters == 'lines-top' then
			chapter_height = math.min(this.size_max / 3, size)
			chapter_y = fay + (chapter_height / 2)
		elseif options.timeline_chapters == 'lines-bottom' then
			chapter_height = math.min(this.size_max / 3, size)
			chapter_y = fay + size - (chapter_height / 2)
		end

		if chapter_height ~= nil then
			-- for 1px chapter size, use the whole size of the bar including padding
			chapter_height = size <= 1 and foreground_size or chapter_height
			local chapter_half_width = chapter_width / 2
			local chapter_half_height = chapter_height / 2
			local function draw_chapter(time)
				local chapter_x = time_x + time_width * (time / state.duration)
				local ax, bx = chapter_x - chapter_half_width, chapter_x + chapter_half_width
				local cx, dx = math.max(ax, fax), math.min(bx, fbx)
				local opts = {
					color = options.color_foreground,
					clip = dots and '\\iclip(' .. foreground_coordinates .. ')' or nil,
					opacity = options.timeline_chapters_opacity,
				}

				if dots then
					-- 0.5 because clipping coordinates are rounded
					if (ax - 0.5) < fax or (bx + 0.5) > fbx then
						ass:circle(chapter_x, chapter_y, chapter_half_height, opts)
					end
					if (dx - cx) > 0 then -- intersection
						opts.color = options.color_background
						opts.clip = '\\clip(' .. foreground_coordinates .. ')'
						ass:circle(chapter_x, chapter_y, chapter_half_height, opts)
					end
				else
					ax, bx = round(ax), round(bx)
					local ay, by = chapter_y - chapter_half_height, chapter_y + chapter_half_height
					if ax < fax then --left of progress
						ass:rect(ax, ay, math.min(bx, fax), by, opts)
					end
					if bx > fbx then --right of progress
						ass:rect(math.max(ax, fbx), ay, bx, by, opts)
					end
					if (dx - cx) > 0 then --intersection
						opts.color = options.color_background
						ass:rect(cx, ay, dx, by, opts)
					end
				end
			end

			if state.chapters ~= nil then
				for i, chapter in ipairs(state.chapters) do
					if not chapter._uosc_used_as_range_point then
						draw_chapter(chapter.time)
					end
				end
			end

			if state.ab_loop_a and state.ab_loop_a > 0 then
				draw_chapter(state.ab_loop_a)
			end

			if state.ab_loop_b and state.ab_loop_b > 0 then
				draw_chapter(state.ab_loop_b)
			end
		end
	end

	-- Seekable ranges
	local function render_cache()
		if options.timeline_cached_ranges and state.cached_ranges then
			local range_height = math.max(math.floor(math.min(this.size_max / 8, foreground_size / 2)), 1)
			local range_ay = fby - range_height

			for _, range in ipairs(state.cached_ranges) do
				local range_start = math.max(type(range['start']) == 'number' and range['start'] or 0.000001, 0.000001)
				local range_end = math.min(type(range['end']) and range['end'] or state.duration, state.duration)
				ass:rect(
					time_x + time_width * (range_start / state.duration), range_ay,
					time_x + time_width * (range_end / state.duration), range_ay + range_height,
					{color = options.timeline_cached_ranges.color, opacity = options.timeline_cached_ranges.opacity}
				)
			end

			-- Visualize padded time area limits
			if time_padding > 0 then
				local notch_ay = math.max(range_ay - 2, fay)
				local opts = {color = options.timeline_cached_ranges.color, opacity = options.timeline_opacity}
				ass:rect(time_x, notch_ay, time_x + 1, bby, opts)
				ass:rect(time_x + time_width - 1, notch_ay, time_x + time_width, bby, opts)
			end
		end
	end

	-- Time values
	local function render_time()
		if text_opacity > 0 then
			local opts = {size = this.font_size, opacity = math.min(options.timeline_opacity + 0.1, 1) * text_opacity}

			-- Elapsed time
			if state.time_human then
				local elapsed_x = bax + spacing
				local elapsed_y = fay + (size / 2)
				opts.color = options.color_foreground_text
				opts.clip = '\\clip(' .. foreground_coordinates .. ')'
				ass:txt(elapsed_x, elapsed_y, 4, state.time_human, opts)
				opts.color = options.color_background_text
				opts.clip = '\\iclip(' .. foreground_coordinates .. ')'
				ass:txt(elapsed_x, elapsed_y, 4, state.time_human, opts)
			end

			-- End time
			if state.duration_or_remaining_time_human then
				local end_x = bbx - spacing
				local end_y = fay + (size / 2)
				opts.color = options.color_foreground_text
				opts.clip = '\\clip(' .. foreground_coordinates .. ')'
				ass:txt(end_x, end_y, 6, state.duration_or_remaining_time_human, opts)
				opts.color = options.color_background_text
				opts.clip = '\\iclip(' .. foreground_coordinates .. ')'
				ass:txt(end_x, end_y, 6, state.duration_or_remaining_time_human, opts)
			end
		end
	end

	-- Render elements in the optimal order:
	-- When line is minimized, it turns into a bar (timeline_line_width_minimized_scale),
	-- so it should be below ranges and chapters.
	-- But un-minimized it's a thin line that should be above everything.
	if is_line and size > size_min then
		render_ranges()
		render_chapters()
		render_progress()
		render_cache()
		render_time()
	else
		render_progress()
		render_ranges()
		render_chapters()
		render_cache()
		render_time()
	end

	-- Hovered time and chapter
	if (this.proximity_raw == 0 or this.pressed) and not (Elements.speed and Elements.speed.dragging) then
		-- add 0.5 to be in the middle of the pixel
		local hovered_seconds = this:get_time_at_x(cursor.x + 0.5)
		local chapter_title, chapter_title_width = nil, nil

		if (options.timeline_chapters ~= 'never' and state.chapters) then
			for i = #state.chapters, 1, -1 do
				local chapter = state.chapters[i]
				if hovered_seconds >= chapter.time then
					if not chapter.is_end_only then
						chapter_title = chapter.title_wrapped
						chapter_title_width = chapter.title_wrapped_width
					end
					break
				end
			end
		end

		-- Cursor line
		-- 0.5 to switch when the pixel is half filled in
		local color = ((fax - 0.5) < cursor.x and cursor.x < (fbx + 0.5)) and
			options.color_background or options.color_foreground
		local line = {ax = cursor.x, ay = fay, bx = cursor.x + 1, by = fby}
		ass:rect(line.ax, line.ay, line.bx, line.by, {color = color, opacity = 0.2})

		-- Timestamp
		ass:tooltip(line, format_time(hovered_seconds), {size = this.font_size, offset = 2})

		-- Chapter title
		if chapter_title then
			ass:tooltip(line, chapter_title, {
				offset = 2 + this.font_size * 1.4, size = this.font_size, bold = true,
				text_length_override = chapter_title_width,
			})
		end
	end

	return ass
end

function render_top_bar(this)
	local visibility = this:get_visibility()

	if not this.enabled or visibility == 0 then return end

	local ass = assdraw.ass_new()

	if options.top_bar_controls then
		-- Close button
		local close = Elements.window_controls_close
		if close.proximity_raw == 0 then
			-- Background on hover
			ass:rect(close.ax, close.ay, close.bx, close.by, {color = '2311e8', opacity = visibility})
		end
		ass:icon(
			close.ax + (this.button_width / 2), close.ay + (this.size / 2), this.icon_size, 'close',
			{opacity = visibility, border = 1}
		)

		-- Maximize button
		local maximize = Elements.window_controls_maximize
		if maximize.proximity_raw == 0 then
			-- Background on hover
			ass:rect(maximize.ax, maximize.ay, maximize.bx, maximize.by, {
				color = '222222', opacity = visibility,
			})
		end
		ass:icon(
			maximize.ax + (this.button_width / 2), maximize.ay + (this.size / 2), this.icon_size,
			'crop_square', {opacity = visibility, border = 1}
		)

		-- Minimize button
		local minimize = Elements.window_controls_minimize
		if minimize.proximity_raw == 0 then
			-- Background on hover
			ass:rect(minimize.ax, minimize.ay, minimize.bx, minimize.by, {
				color = '222222', opacity = visibility,
			})
		end
		ass:icon(
			minimize.ax + (this.button_width / 2), minimize.ay + (this.size / 2), this.icon_size, 'minimize',
			{opacity = visibility, border = 1}
		)
	end

	-- Window title
	if options.top_bar_title and (state.media_title or state.playlist_count > 1) then
		local max_bx = this.title_bx - this.spacing
		local text = state.media_title or 'n/a'
		if state.playlist_count > 1 then
			text = string.format('%d/%d - ', state.playlist_pos, state.playlist_count) .. text
		end

		-- Background
		local padding = this.font_size / 2
		local bg_margin = math.floor((this.size - this.font_size) / 4)
		local bg_ax = this.ax + bg_margin
		local bg_bx = math.min(max_bx, this.ax + text_width_estimate(text, this.font_size) + padding * 2)
		ass:rect(bg_ax, this.ay + bg_margin, bg_bx, this.by - bg_margin, {
			color = options.color_background, opacity = visibility * 0.8, radius = 2,
		})

		-- Text
		ass:txt(bg_ax + padding, this.ay + (this.size / 2), 4, text, {
			size = this.font_size, wrap = 2, color = 'FFFFFF', border = 1, border_color = '000000', opacity = visibility,
			clip = string.format('\\clip(%d, %d, %d, %d)', this.ax, this.ay, max_bx, this.by),
		})
	end

	return ass
end

function render_volume(this)
	local slider = Elements.volume_slider
	local visibility = this:get_visibility()

	if this.width == 0 or visibility == 0 then return end

	local ass = assdraw.ass_new()

	if slider.height > 0 then
		local nudge_y, nudge_size = slider.draw_nudge and slider.nudge_y or -infinity, slider.nudge_size

		-- Background bar coordinates
		local bax, bay, bbx, bby = slider.ax, slider.ay, slider.bx, slider.by

		-- Foreground bar coordinates
		local height_without_border = slider.height - (options.volume_border * 2)
		local fax = slider.ax + options.volume_border
		local fay = slider.ay + (height_without_border * (1 - math.min(state.volume / state.volume_max, 1))) +
			options.volume_border
		local fbx = slider.bx - options.volume_border
		local fby = slider.by - options.volume_border

		-- Draws a rectangle with nudge at requested position
		---@param ax number
		---@param ay number
		---@param bx number
		---@param by number
		function make_nudged_path(ax, ay, bx, by)
			local fg_path = assdraw.ass_new()
			fg_path:move_to(bx, by)
			fg_path:line_to(ax, by)
			local nudge_bottom_y = nudge_y + nudge_size
			if ay <= nudge_bottom_y then
				fg_path:line_to(ax, math.min(nudge_bottom_y))
				if ay <= nudge_y then
					fg_path:line_to((ax + nudge_size), nudge_y)
					local nudge_top_y = nudge_y - nudge_size
					if ay <= nudge_top_y then
						fg_path:line_to(ax, nudge_top_y)
						fg_path:line_to(ax, ay)
						fg_path:line_to(bx, ay)
						fg_path:line_to(bx, nudge_top_y)
					else
						local triangle_side = ay - nudge_top_y
						fg_path:line_to((ax + triangle_side), ay)
						fg_path:line_to((bx - triangle_side), ay)
					end
					fg_path:line_to((bx - nudge_size), nudge_y)
				else
					local triangle_side = nudge_bottom_y - ay
					fg_path:line_to((ax + triangle_side), ay)
					fg_path:line_to((bx - triangle_side), ay)
				end
				fg_path:line_to(bx, nudge_bottom_y)
			else
				fg_path:line_to(ax, ay)
				fg_path:line_to(bx, ay)
			end
			fg_path:line_to(bx, by)
			return fg_path
		end

		-- FG & BG paths
		local fg_path = make_nudged_path(fax, fay, fbx, fby)
		local bg_path = make_nudged_path(bax, bay, bbx, bby)

		-- Background
		ass:new_event()
		ass:append('{\\blur0\\bord0\\1c&H' .. options.color_background ..
			'\\iclip(' .. fg_path.scale .. ', ' .. fg_path.text .. ')}')
		ass:opacity(math.max(options.volume_opacity - 0.1, 0), visibility)
		ass:pos(0, 0)
		ass:draw_start()
		ass:append(bg_path.text)
		ass:draw_stop()

		-- Foreground
		ass:new_event()
		ass:append('{\\blur0\\bord0\\1c&H' .. options.color_foreground .. '}')
		ass:opacity(options.volume_opacity, visibility)
		ass:pos(0, 0)
		ass:draw_start()
		ass:append(fg_path.text)
		ass:draw_stop()

		-- Current volume value
		local volume_string = tostring(round(state.volume * 10) / 10)
		local font_size = round(((this.width * 0.6) - (#volume_string * (this.width / 20))) * options.volume_font_scale)
		local opacity = math.min(options.volume_opacity + 0.1, 1) * visibility
		if fay < slider.by - slider.spacing then
			ass:txt(slider.ax + (slider.width / 2), slider.by - slider.spacing, 2, volume_string, {
				size = font_size, color = options.color_foreground_text, opacity = opacity,
				clip = '\\clip(' .. fg_path.scale .. ', ' .. fg_path.text .. ')',
			})
		end
		if fay > slider.by - slider.spacing - font_size then
			ass:txt(slider.ax + (slider.width / 2), slider.by - slider.spacing, 2, volume_string, {
				size = font_size, color = options.color_background_text, opacity = opacity,
				clip = '\\iclip(' .. fg_path.scale .. ', ' .. fg_path.text .. ')',
			})
		end

		-- Disabled stripes for no audio
		if not state.has_audio then
			-- Create 100 foreground clip path
			local f100ax, f100ay = slider.ax + options.volume_border, slider.ay + options.volume_border
			local f100bx, f100by = slider.bx - options.volume_border, slider.by - options.volume_border
			local fg_100_path = make_nudged_path(f100ax, f100ay, f100bx, f100by)

			-- Render stripes
			local stripe_height = 12
			local skew_height = stripe_height
			local colors = {'000000', 'ffffff'}

			for c, color in ipairs(colors) do
				local stripe_y = slider.ay + stripe_height * (c - 1)

				ass:new_event()
				ass:append('{\\blur0\\bord0\\shad0\\1c&H' .. color ..
					'\\clip(' .. fg_100_path.scale .. ',' .. fg_100_path.text .. ')}')
				ass:opacity(0.15 * opacity)
				ass:pos(0, 0)
				ass:draw_start()

				while stripe_y - skew_height < slider.by do
					ass:move_to(slider.ax, stripe_y)
					ass:line_to(slider.bx, stripe_y - skew_height)
					ass:line_to(slider.bx, stripe_y - skew_height + stripe_height)
					ass:line_to(slider.ax, stripe_y + stripe_height)
					stripe_y = stripe_y + stripe_height * #colors
				end

				ass:draw_stop()
			end
		end
	end

	-- Mute button
	local mute = Elements.volume_mute
	local icon_name = state.mute and 'volume_off' or 'volume_up'
	ass:icon(
		mute.ax + (mute.width / 2), mute.by, mute.width * 0.7, icon_name,
		{border = options.volume_border, opacity = options.volume_opacity * visibility, align = 2}
	)
	return ass
end

function render_speed(this)
	if not this.dragging and (Elements.curtain.opacity > 0) then return end

	local visibility = this:get_visibility()
	local opacity = this.dragging and 1 or visibility

	if opacity == 0 then return end

	local ass = assdraw.ass_new()
	ass:rect(this.ax, this.ay, this.bx, this.by, {
		color = options.color_background, radius = 2, opacity = opacity * 0.3,
	})

	-- Coordinates
	local ax, ay = this.ax, this.ay
	local bx, by = this.bx, ay + this.height
	local half_width = (this.width / 2)
	local half_x = ax + half_width

	-- Notches
	local speed_at_center = state.speed
	if this.dragging then
		speed_at_center = this.dragging.start_speed + this.dragging.speed_distance
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

		if notch_speed >= 0 and notch_speed <= 100 then
			local notch_x = nearest_notch_x + (i * this.notch_spacing)
			local notch_thickness = 1
			local notch_ay = notch_ay_small
			if (notch_speed % (this.notch_every * 10)) < 0.00000001 then
				notch_ay = notch_ay_big
				notch_thickness = 1.5
			elseif (notch_speed % (this.notch_every * 5)) < 0.00000001 then
				notch_ay = notch_ay_medium
			end

			ass:rect(notch_x - notch_thickness, notch_ay, notch_x + notch_thickness, notch_by, {
				color = options.color_foreground, border = 1, border_color = options.color_background,
				opacity = math.min(1.2 - (math.abs((notch_x - ax - half_width) / half_width)), 1) * opacity,
			})
		end
	end

	-- Center guide
	ass:new_event()
	ass:append('{\\blur0\\bord1\\shad0\\1c&H' .. options.color_foreground .. '\\3c&H' .. options.color_background .. '}')
	ass:opacity(options.speed_opacity, opacity)
	ass:pos(0, 0)
	ass:draw_start()
	ass:move_to(half_x, by - 2 - guide_size)
	ass:line_to(half_x + guide_size, by - 2)
	ass:line_to(half_x - guide_size, by - 2)
	ass:draw_stop()

	-- Speed value
	local speed_text = (round(state.speed * 100) / 100) .. 'x'
	ass:txt(half_x, ay, 8, speed_text, {
		size = this.font_size, color = options.color_background_text,
		border = 1, border_color = options.color_background, opacity = opacity,
	})

	return ass
end

function render_menu(this)
	local ass = assdraw.ass_new()

	if this.parent_menu then
		ass:merge(this.parent_menu:render())
	end

	local opacity = options.menu_opacity * this.opacity
	local spacing = this.item_content_spacing

	-- Menu title
	if this.title then
		-- Background
		ass:rect(this.ax, this.ay - this.item_height, this.bx, this.ay - 1, {
			color = options.color_foreground, opacity = opacity, radius = 2,
		})

		-- Title
		ass:txt(this.ax + this.width / 2, this.ay - (this.item_height * 0.5), 5, this.title, {
			size = this.font_size, bold = true, color = options.color_foreground_text,
			shadow = 1, shadow_color = options.color_foreground, wrap = 2, opacity = opacity,
			clip = '\\clip(' .. this.ax .. ',' .. this.ay - this.item_height .. ',' .. this.bx .. ',' .. this.ay .. ')',
		})
	end

	local scroll_area_clip = '\\clip(' .. this.ax .. ',' .. this.ay .. ',' .. this.bx .. ',' .. this.by .. ')'

	for index, item in ipairs(this.items) do
		local item_ay = this.ay - this.scroll_y + (this.item_height * (index - 1) + this.item_spacing * (index - 1))
		local item_by = item_ay + this.item_height
		local item_clip = nil

		if item_by >= this.ay and item_ay <= this.by then
			-- Clip items overflowing scroll area
			if item_ay <= this.ay or item_by >= this.by then
				item_clip = scroll_area_clip
			end

			local is_active = this.active_index == index
			local font_color, background_color, shadow, shadow_color
			local icon_size = this.font_size
			local item_center_y = item_ay + (this.item_height / 2)

			if is_active then
				font_color, background_color = options.color_foreground_text, options.color_foreground
				shadow, shadow_color = 0, ''
			else
				font_color, background_color = options.color_background_text, options.color_background
				shadow, shadow_color = 1, '\\4c&H' .. background_color
			end

			local has_submenu = item.items ~= nil
			-- controls title & hint clipping proportional to the ratio of their widths
			local title_hint_ratio = 1
			if item.hint then
				title_hint_ratio = item.title_width / (item.title_width + item.hint_width)
			elseif has_submenu then
				title_hint_ratio = item.title_width / (item.title_width + icon_size)
			end
			local title_hint_spacing = (title_hint_ratio == 1 or title_hint_ratio == 0) and 0 or spacing / 2

			-- Background
			ass:rect(this.ax, item_ay, this.bx, item_by, {
				color = background_color, clip = item_clip, opacity = opacity, radius = 2,
			})

			-- Selected highlight
			if this.selected_index == index then
				ass:rect(this.ax + 1, item_ay + 1, this.bx - 1, item_by - 1, {
					color = options.color_foreground, clip = item_clip, opacity = 0.1 * this.opacity, radius = 1,
				})
			end

			-- Title
			local title_x = this.ax + spacing
			local title_hint_cut_x = title_x + (this.width - spacing * 2) * title_hint_ratio
			if item.title then
				item.ass_save_title = item.ass_save_title or item.title:gsub('([{}])', '\\%1')
				local clip = '\\clip(' .. this.ax .. ',' .. math.max(item_ay, this.ay) .. ','
					.. round(title_hint_cut_x - title_hint_spacing / 2) .. ',' .. math.min(item_by, this.by) .. ')'
				ass:txt(title_x, item_center_y, 4, item.ass_save_title, {
					size = this.font_size, color = font_color, italic = item.italic, bold = item.bold, wrap = 2,
					shadow = 1, shadow_color = background_color, opacity = this.opacity * (item.muted and 0.5 or 1),
					clip = clip,
				})
			end

			-- Hint
			local hint_x = this.bx - spacing
			if item.hint then
				item.ass_save_hint = item.ass_save_hint or item.hint:gsub('([{}])', '\\%1')
				local clip = '\\clip(' .. round(title_hint_cut_x + title_hint_spacing / 2) .. ',' ..
					math.max(item_ay, this.ay) .. ',' .. this.bx .. ',' .. math.min(item_by, this.by) .. ')'
				ass:txt(hint_x, item_center_y, 6, item.ass_save_hint, {
					size = this.font_size_hint, color = font_color, shadow = shadow, shadow_color = shadow_color,
					wrap = 2, opacity = (has_submenu and 1 or 0.5) * this.opacity, clip = clip,
				})
			elseif has_submenu then
				ass:icon(hint_x - (icon_size / 2), item_center_y, icon_size * 1.5, 'chevron_right', {
					color = is_active and options.color_background or options.color_foreground,
					border = 0, opacity = this.opacity, clip = item_clip,
				})
			end
		end
	end

	-- Scrollbar
	if this.scroll_height > 0 then
		local groove_height = this.height - 2
		local thumb_height = math.max((this.height / (this.scroll_height + this.height)) * groove_height, 40)
		local thumb_y = this.ay + 1 + ((this.scroll_y / this.scroll_height) * (groove_height - thumb_height))
		ass:rect(this.bx - 3, thumb_y, this.bx - 1, thumb_y + thumb_height, {
			color = options.color_foreground, opacity = options.menu_opacity * this.opacity * 0.8,
		})
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
		local timeout = state.render_delay - (now - state.render_last_time)
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

	for _, element in Elements:ipairs() do
		if element.enabled then
			local result = element:maybe('render')
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

	update_margins()
end

-- Element creators

-- Speed
---@param props {anchor_id: string}
function create_speed_slider(props)
	return Element.new('speed', {
		enabled = true,
		anchor_id = props.anchor_id,
		dragging = nil,
		width = 0,
		height = 0,
		notches = 10,
		notch_every = 0.1,
		font_size = nil,
		get_visibility = function(this)
			-- We force inherit, because I want to see speed value when peeking timeline
			local this_visibility = Element.get_visibility(this)
			return Elements.timeline.proximity_raw ~= 0
				and math.max(Elements.timeline.proximity, this_visibility) or this_visibility
		end,
		set_coordinates = function(this, ax, ay, bx, by)
			this.ax, this.ay, this.bx, this.by = ax, ay, bx, by
			this.height, this.width = this.by - this.ay, this.bx - this.ax
			this.notch_spacing = this.width / (this.notches + 1)
			this.font_size = round(this.height * 0.48 * options.speed_font_scale)
		end,
		speed_step = function(this, speed, up)
			if options.speed_step_is_factor then
				if up then
					return speed * options.speed_step
				else
					return speed * 1 / options.speed_step
				end
			else
				if up then
					return speed + options.speed_step
				else
					return speed - options.speed_step
				end
			end
		end,
		on_mbtn_left_down = function(this)
			this:tween_stop() -- Stop and cleanup possible ongoing animations
			this.dragging = {
				start_time = mp.get_time(),
				start_x = cursor.x,
				distance = 0,
				speed_distance = 0,
				start_speed = state.speed,
			}
		end,
		on_global_mouse_move = function(this)
			if not this.dragging then return end

			this.dragging.distance = cursor.x - this.dragging.start_x
			this.dragging.speed_distance = (-this.dragging.distance / this.notch_spacing * this.notch_every)

			local speed_current = state.speed
			local speed_drag_current = this.dragging.start_speed + this.dragging.speed_distance
			speed_drag_current = math.min(math.max(speed_drag_current, 0.01), 100)
			local drag_dir_up = speed_drag_current > speed_current

			local speed_step_next = speed_current
			local speed_drag_diff = math.abs(speed_drag_current - speed_current)
			while math.abs(speed_step_next - speed_current) < speed_drag_diff do
				speed_step_next = this:speed_step(speed_step_next, drag_dir_up)
			end
			local speed_step_prev = this:speed_step(speed_step_next, not drag_dir_up)

			local speed_new = speed_step_prev
			local speed_next_diff = math.abs(speed_drag_current - speed_step_next)
			local speed_prev_diff = math.abs(speed_drag_current - speed_step_prev)
			if speed_next_diff < speed_prev_diff then
				speed_new = speed_step_next
			end

			if speed_new ~= speed_current then
				mp.set_property_native('speed', speed_new)
			end
		end,
		on_mbtn_left_up = function(this)
			-- Reset speed on short clicks
			if this.dragging and math.abs(this.dragging.distance) < 6 and mp.get_time() - this.dragging.start_time < 0.15 then
				mp.set_property_native('speed', 1)
			end
		end,
		on_global_mbtn_left_up = function(this)
			this.dragging = nil
			request_render()
		end,
		on_global_mouse_leave = function(this)
			this.dragging = nil
			request_render()
		end,
		on_wheel_up = function(this)
			mp.set_property_native('speed', this:speed_step(state.speed, true))
		end,
		on_wheel_down = function(this)
			mp.set_property_native('speed', this:speed_step(state.speed, false))
		end,
		render = render_speed,
	})
end

-- Button
---@param id string
---@param props {icon: string; on_click: function; anchor_id?: string; active?: boolean; foreground?: string; background?: string; tooltip?: string}
function create_button(id, props)
	return Element.new(id, {
		enabled = true,
		anchor_id = props.anchor_id,
		icon = props.icon,
		active = props.active,
		tooltip = props.tooltip,
		foreground = props.foreground or options.color_foreground,
		background = props.background or options.color_background,
		set_coordinates = function(this, ax, ay, bx, by)
			this.ax, this.ay, this.bx, this.by = ax, ay, bx, by
			this.font_size = round((this.by - this.ay) * 0.7)
		end,
		on_mbtn_left_down = function(this)
			-- We delay the callback to next tick, otherwise we are risking race
			-- conditions as we are in the middle of event dispatching.
			-- For example, handler might add a menu to the end of the element stack, and that
			-- than picks up this click even we are in right now, and instantly closes itself.
			mp.add_timeout(0.01, props.on_click)
		end,
		render = function(this)
			local visibility = this:get_visibility()
			if visibility == 0 then return end

			local ass = assdraw.ass_new()
			local is_hover = this.proximity_raw == 0
			local is_hover_or_active = is_hover or this.active
			local foreground = this.active and this.background or this.foreground
			local background = this.active and this.foreground or this.background

			-- Background
			if is_hover_or_active then
				ass:rect(this.ax, this.ay, this.bx, this.by, {
					color = this.active and background or foreground, radius = 2,
					opacity = visibility * (this.active and 0.8 or 0.2),
				})
			end

			-- Tooltip on hover
			if is_hover and this.tooltip then ass:tooltip(this, this.tooltip) end

			-- Icon
			local x, y = round(this.ax + (this.bx - this.ax) / 2), round(this.ay + (this.by - this.ay) / 2)
			ass:icon(x, y, this.font_size, this.icon, {
				color = foreground, border = this.active and 0 or 1, border_color = background, opacity = visibility,
			})

			return ass
		end,
	})
end

-- Cycle prop button
---@alias CycleState {value: any; icon: string; active?: boolean}
---@param id string
---@param props {prop: string; states: CycleState[]; anchor_id?: string; tooltip?: string}
function create_cycle_button(id, props)
	local prop = props.prop
	local states = props.states
	local current_state_index = 1
	local button = create_button(id, {
		anchor_id = props.anchor_id, icon = states[1].icon, active = states[1].active, tooltip = props.tooltip,
		on_click = function()
			local new_state = states[current_state_index + 1] or states[1]
			mp.set_property(prop, new_state.value)
		end,
	})

	local function handle_change(name, value)
		local index = itable_find(states, function(state) return state.value == value end)
		current_state_index = index or 1
		button.icon = states[current_state_index].icon
		button.active = states[current_state_index].active
		request_render()
	end

	mp.observe_property(prop, 'string', handle_change)
	function button:destroy() mp.unobserve_property(handle_change) end

	return button
end

-- STATIC ELEMENTS

Elements:add(Element.new('window_border', {
	enabled = false,
	size = 0, -- set in decide_enabled
	decide_enabled = function(this)
		this.enabled = options.window_border_size > 0 and not state.fullormaxed and not state.border
		this.size = this.enabled and options.window_border_size or 0
	end,
	on_prop_border = function(this) this:decide_enabled() end,
	on_prop_fullormaxed = function(this) this:decide_enabled() end,
	render = function(this)
		if this.size > 0 then
			local ass = assdraw.ass_new()
			local clip = '\\iclip(' .. this.size .. ',' .. this.size .. ',' ..
				(display.width - this.size) .. ',' .. (display.height - this.size) .. ')'
			ass:rect(0, 0, display.width, display.height, {
				color = options.color_background, clip = clip, opacity = options.window_border_opacity,
			})
			return ass
		end
	end,
}))
Elements:add(Element.new('pause_indicator', {
	enabled = true,
	ignores_menu = true,
	base_icon_opacity = options.pause_indicator == 'flash' and 1 or 0.8,
	paused = state.pause,
	type = options.pause_indicator,
	is_manual = options.pause_indicator == 'manual',
	fadeout_requested = false,
	opacity = 0,
	init = function(this)
		mp.observe_property('pause', 'bool', function(_, paused)
			if options.pause_indicator == 'flash' then
				if this.paused == paused then return end
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
			ass:rect(0, 0, display.width, display.height, {
				color = options.color_background, opacity = this.opacity * 0.3,
			})
		end

		-- Icon
		local size = round(math.min(display.width, display.height) * (is_static and 0.20 or 0.15))

		size = size + size * (1 - this.opacity)

		if this.paused then
			ass:icon(
				display.width / 2, display.height / 2, size, 'pause',
				{border = 1, opacity = this.base_icon_opacity * this.opacity}
			)
		else
			ass:icon(
				display.width / 2, display.height / 2, size * 1.2, 'play_arrow',
				{border = 1, opacity = this.base_icon_opacity * this.opacity}
			)
		end

		return ass
	end,
}))
Elements:add(Element.new('timeline', {
	enabled = true,
	pressed = false,
	size_max = 0, size_min = 0, -- set in `on_display_change` handler based on `state.fullormaxed`
	size_min_override = options.timeline_start_hidden and 0 or nil, -- used for toggle-progress command
	font_size = 0, -- calculated in on_display_change
	top_border = options.timeline_border,
	get_visibility = function(this)
		return Elements.controls
			and math.max(Elements.controls.proximity, Element.get_visibility(this)) or Element.get_visibility(this)
	end,
	decide_enabled = function(this)
		this.enabled = state.duration and state.duration > 0 and state.time
	end,
	get_effective_size_min = function(this)
		return this.size_min_override or this.size_min
	end,
	get_effective_size = function(this)
		if Elements.speed and Elements.speed.dragging then return this.size_max end
		local size_min = this:get_effective_size_min()
		return size_min + math.ceil((this.size_max - size_min) * this:get_visibility())
	end,
	get_effective_line_width = function(this)
		return state.fullormaxed and options.timeline_line_width_fullscreen or options.timeline_line_width
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
		this.ax = Elements.window_border.size
		this.ay = display.height - Elements.window_border.size - this.size_max - this.top_border
		this.bx = display.width - Elements.window_border.size
		this.by = display.height - Elements.window_border.size
		this.width = this.bx - this.ax
	end,
	on_prop_duration = function(this) this:decide_enabled() end,
	on_prop_time = function(this) this:decide_enabled() end,
	on_prop_border = function(this) this:update_dimensions() end,
	on_prop_fullormaxed = function(this) this:update_dimensions() end,
	on_display_change = function(this) this:update_dimensions() end,
	get_time_at_x = function(this, x)
		-- padding serves the purpose of matching cursor to timeline_style=line exactly
		local padding = (options.timeline_style == 'line' and this:get_effective_line_width() or 0) / 2
		local progress = math.max(0, math.min((x - this.ax - padding) / (this.width - padding * 2), 1))
		return state.duration * progress
	end,
	set_from_cursor = function(this)
		-- add 0.5 to be in the middle of the pixel
		mp.commandv('seek', this:get_time_at_x(cursor.x + 0.5), 'absolute+exact')
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
		mp.commandv('seek', options.timeline_step)
	end,
	on_wheel_down = function(this)
		mp.commandv('seek', -options.timeline_step)
	end,
	render = render_timeline,
}))
Elements:add(Element.new('top_bar', {
	enabled = false,
	decide_enabled = function(this)
		if options.top_bar == 'no-border' then
			this.enabled = not state.border or state.fullscreen
		elseif options.top_bar == 'always' then
			this.enabled = true
		else
			this.enabled = false
		end
		this.enabled = this.enabled and (options.top_bar_controls or options.top_bar_title)

		-- Propagate enabled flag to child elements
		local children = {
			Elements.window_controls_minimize,
			Elements.window_controls_maximize,
			Elements.window_controls_close,
		}
		for _, element in ipairs(children) do
			element.enabled = this.enabled
		end
	end,
	update_dimensions = function(this)
		this.size = state.fullormaxed and options.top_bar_size_fullscreen or options.top_bar_size
		this.icon_size = round(this.size * 0.5)
		this.spacing = math.ceil(this.size * 0.25)
		this.font_size = math.floor(this.size - (this.spacing * 2))
		this.button_width = round(this.size * 1.15)
		this.ay = Elements.window_border.size
		this.bx = display.width - Elements.window_border.size
		this.by = this.size + Elements.window_border.size
		this.title_bx = this.bx - (options.top_bar_controls and (this.button_width * 3) or 0)
		this.ax = options.top_bar_title and Elements.window_border.size or this.title_bx
	end,
	on_prop_border = function(this)
		this:decide_enabled()
		this:update_dimensions()
	end,
	on_prop_fullscreen = function(this)
		this:decide_enabled()
		this:update_dimensions()
	end,
	on_prop_maximized = function(this)
		this:decide_enabled()
		this:update_dimensions()
	end,
	on_display_change = function(this) this:update_dimensions() end,
	render = render_top_bar,
}))
if options.top_bar_controls then
	Elements:add(Element.new('window_controls_minimize', {
		update_dimensions = function(this)
			this.ax = Elements.top_bar.bx - (Elements.top_bar.button_width * 3)
			this.ay = Elements.top_bar.ay
			this.bx = this.ax + Elements.top_bar.button_width
			this.by = this.ay + Elements.top_bar.size
		end,
		on_prop_border = function(this) this:update_dimensions() end,
		on_display_change = function(this) this:update_dimensions() end,
		on_mbtn_left_down = function(this)
			if this.enabled then mp.commandv('cycle', 'window-minimized') end
		end,
	}))
	Elements:add(Element.new('window_controls_maximize', {
		update_dimensions = function(this)
			this.ax = Elements.top_bar.bx - (Elements.top_bar.button_width * 2)
			this.ay = Elements.top_bar.ay
			this.bx = this.ax + Elements.top_bar.button_width
			this.by = this.ay + Elements.top_bar.size
		end,
		on_prop_border = function(this) this:update_dimensions() end,
		on_display_change = function(this) this:update_dimensions() end,
		on_mbtn_left_down = function(this)
			if this.enabled then mp.commandv('cycle', 'window-maximized') end
		end,
	}))
	Elements:add(Element.new('window_controls_close', {
		update_dimensions = function(this)
			this.ax = Elements.top_bar.bx - Elements.top_bar.button_width
			this.ay = Elements.top_bar.ay
			this.bx = this.ax + Elements.top_bar.button_width
			this.by = this.ay + Elements.top_bar.size
		end,
		on_prop_border = function(this) this:update_dimensions() end,
		on_display_change = function(this) this:update_dimensions() end,
		on_mbtn_left_down = function(this)
			if this.enabled then mp.commandv('quit') end
		end,
	}))
end
if options.controls and options.controls ~= 'never' then
	Elements:add(Element.new('controls', {
		enabled = true,
		-- Table of controls, each with these props:
		-- element?: Element;
		-- sizing: 'space' | 'static' | 'dynamic';
		-- scale: number; - options.controls_size scale factor
		-- ratio?: number; - width/height ratio of a static or dynamic element
		-- ratio_min?: number; min ratio for 'dynamic' sized element
		-- skip: boolean; - whether it should be skipped, determined during layout phase
		controls = {},
		init = function(this) this:serialize() end,
		serialize = function(this)
			local shorthands = {
				menu = 'command:menu:script-binding uosc/menu?Menu',
				subtitles = 'command:subtitles:script-binding uosc/subtitles?Subtitles',
				audio = 'command:audiotrack:script-binding uosc/audio?Audio',
				['audio-device'] = 'command:speaker:script-binding uosc/audio-device?Audio device',
				video = 'command:theaters:script-binding uosc/video?Video',
				playlist = 'command:list_alt:script-binding uosc/playlist?Playlist',
				chapters = 'command:bookmarks:script-binding uosc/chapters?Chapters',
				['stream-quality'] = 'command:deblur:script-binding uosc/stream-quality?Stream quality',
				['open-file'] = 'command:file_open:script-binding uosc/open-file?Open file',
				['items'] = 'command:list_alt:script-binding uosc/items?Playlist/Files',
				prev = 'command:arrow_back_ios:script-binding uosc/prev?Previous',
				next = 'command:arrow_forward_ios:script-binding uosc/next?Next',
				first = 'command:first_page:script-binding uosc/first?First',
				last = 'command:last_page:script-binding uosc/last?Last',
				['loop-playlist'] = 'cycle:repeat:loop-playlist:no/inf!?Loop playlist',
				['loop-file'] = 'cycle:repeat_one:loop-file:no/inf!?Loop file',
				shuffle = 'toggle:shuffle:shuffle?Shuffle',
				fullscreen = 'cycle:crop_free:fullscreen:no/yes=fullscreen_exit!?Fullscreen',
			}

			-- Parse configs
			local items = {}
			local in_disposition = false
			local current_item = nil
			for c in options.controls:gmatch('.') do
				if not current_item then current_item = {disposition = '', config = ''} end
				if c == '<' then in_disposition = true
				elseif c == '>' then in_disposition = false
				elseif c == ',' and not in_disposition then
					items[#items + 1] = current_item
					current_item = nil
				else
					local prop = in_disposition and 'disposition' or 'config'
					current_item[prop] = current_item[prop] .. c
				end
			end
			items[#items + 1] = current_item

			-- Filter out based on disposition
			items = itable_filter(items, function(item)
				if item.disposition == '' then return true end
				local dispositions = split(item.disposition, ' *, *')
				for _, disposition in ipairs(dispositions) do
					local value = disposition:sub(1, 1) ~= '!'
					local name = not value and disposition:sub(2) or disposition
					local prop = name == 'has_audio' and name or 'is_' .. name
					if state[prop] ~= value then return false end
				end
				return true
			end)

			-- Create controls
			this.controls = {}
			for i, item in ipairs(items) do
				local config = shorthands[item.config] and shorthands[item.config] or item.config
				local config_tooltip = split(config, ' *%? *')
				config = config_tooltip[1]
				local tooltip = config_tooltip[2]
				local parts = split(config, ' *: *')
				local kind, params = parts[1], itable_slice(parts, 2)

				-- Convert toggles into cycles
				if kind == 'toggle' then
					kind = 'cycle'
					params[#params + 1] = 'no/yes!'
				end

				if kind == 'space' then
					this.controls[#this.controls + 1] = {kind = kind, sizing = 'space'}
				elseif kind == 'gap' then
					this.controls[#this.controls + 1] = {
						kind = kind, sizing = 'dynamic', scale = 1, ratio = params[1] or 0.3, ratio_min = 0,
					}
				elseif kind == 'command' then
					if #params ~= 2 then
						mp.error(string.format(
							'command button needs 2 parameters, %d received: %s',
							#params, table.concat(params, '/')
						))
					else
						local element = create_button('control_' .. i, {
							icon = params[1],
							anchor_id = 'controls',
							on_click = function() mp.command(params[2]) end,
							tooltip = tooltip,
						})
						this.controls[#this.controls + 1] = {
							kind = kind, element = element, sizing = 'static', scale = 1, ratio = 1,
						}
						Elements:add(element)
					end
				elseif kind == 'cycle' then
					if #params ~= 3 then
						mp.error(string.format(
							'cycle button needs 3 parameters, %d received: %s',
							#params, table.concat(params, '/')
						))
					else
						local state_configs = split(params[3], ' */ *')
						local states = {}

						for _, state_config in ipairs(state_configs) do
							local active = false
							if state_config:sub(-1) == '!' then
								active = true
								state_config = state_config:sub(1, -2)
							end
							local state_params = split(state_config, ' *= *')
							local value, icon = state_params[1], state_params[2] or params[1]
							states[#states + 1] = {value = value, icon = icon, active = active}
						end

						local element = create_cycle_button('control_' .. i, {
							prop = params[2], anchor_id = 'controls', states = states, tooltip = tooltip,
						})
						this.controls[#this.controls + 1] = {
							kind = kind, element = element, sizing = 'static', scale = 1, ratio = 1,
						}
						Elements:add(element)
					end
				elseif kind == 'speed' then
					if not Elements.speed then
						local element = create_speed_slider({anchor_id = 'controls'})
						this.controls[#this.controls + 1] = {
							kind = kind, element = element,
							sizing = 'dynamic', scale = params[1] or 1.3, ratio = 3.5, ratio_min = 2,
						}
						Elements:add(element)
					else
						msg.error('there can only be 1 speed slider')
					end
				end
			end

			this:update_dimensions()
		end,
		clean_controls = function(this)
			for _, control in ipairs(this.controls) do
				if control.element then Elements:remove(control.element) end
			end
			this.controls = {}
			request_render()
		end,
		get_visibility = function(this)
			return (Elements.speed and Elements.speed.dragging) and 1 or
				Elements.timeline.proximity_raw == 0 and -1 or Element.get_visibility(this)
		end,
		update_dimensions = function(this)
			local window_border = Elements.window_border.size
			local size = state.fullormaxed and options.controls_size_fullscreen or options.controls_size
			local spacing = options.controls_spacing
			local margin = options.controls_margin

			-- Container
			this.bx = display.width - window_border - margin
			this.by = (Elements.timeline.enabled and Elements.timeline.ay or display.height - window_border) - margin
			this.ax, this.ay = window_border + margin, this.by - size

			-- Re-enable all elements
			for c, control in ipairs(this.controls) do
				control.hide = false
				if control.element then control.element.enabled = true end
			end

			-- Controls
			local available_width = this.bx - this.ax
			local statics_width = (#this.controls - 1) * spacing
			local min_content_width = statics_width
			local max_dynamics_width, dynamic_units, spaces = 0, 0, 0

			-- Calculate statics_width, min_content_width, and count spaces
			for c, control in ipairs(this.controls) do
				if control.sizing == 'space' then
					spaces = spaces + 1
				elseif control.sizing == 'static' then
					local width = size * control.scale * control.ratio
					statics_width = statics_width + width
					min_content_width = min_content_width + width
				elseif control.sizing == 'dynamic' then
					min_content_width = min_content_width + size * control.scale * control.ratio_min
					max_dynamics_width = max_dynamics_width + size * control.scale * control.ratio
					dynamic_units = dynamic_units + control.scale * control.ratio
				end
			end

			-- Hide & disable elements in the middle until we fit into available width
			if min_content_width > available_width then
				local i = math.ceil(#this.controls / 2 + 0.1)
				for a = 0, #this.controls - 1, 1 do
					i = i + (a * (a % 2 == 0 and 1 or -1))
					local control = this.controls[i]

					if control.kind ~= 'gap' and control.kind ~= 'space' then
						control.hide = true
						if control.element then control.element.enabled = false end
						if control.sizing == 'static' then
							local width = size * control.scale * control.ratio
							min_content_width = min_content_width - width - spacing
							statics_width = statics_width - width - spacing
						elseif control.sizing == 'dynamic' then
							min_content_width = min_content_width - size * control.scale * control.ratio_min - spacing
							max_dynamics_width = max_dynamics_width - size * control.scale * control.ratio
							dynamic_units = dynamic_units - control.scale * control.ratio
						end

						if min_content_width < available_width then break end
					end
				end
			end

			-- Lay out the elements
			local current_x = this.ax
			local width_for_dynamics = available_width - statics_width
			local space_width = (width_for_dynamics - max_dynamics_width) / spaces

			for c, control in ipairs(this.controls) do
				if not control.hide then
					local sizing, element, scale, ratio = control.sizing, control.element, control.scale, control.ratio
					local width, height = 0, 0

					if sizing == 'space' then
						if space_width > 0 then width = space_width end
					elseif sizing == 'static' then
						height = size * scale
						width = height * ratio
					elseif sizing == 'dynamic' then
						height = size * scale
						width = max_dynamics_width < width_for_dynamics
							and height * ratio or width_for_dynamics * ((scale * ratio) / dynamic_units)
					end

					local bx = current_x + width
					if element then element:set_coordinates(round(current_x), round(this.by - height), bx, this.by) end
					current_x = bx + spacing
				end
			end

			request_render()
		end,
		on_dispositions = function(this)
			this:clean_controls()
			this:serialize()
		end,
		on_display_change = function(this) this:update_dimensions() end,
		on_prop_border = function(this) this:update_dimensions() end,
		on_prop_fullormaxed = function(this) this:update_dimensions() end,
	}))
end
if itable_index_of({'left', 'right'}, options.volume) then
	Elements:add(Element.new('volume', {
		enabled = true,
		width = nil, -- set in `update_dimensions`
		height = nil, -- set in `update_dimensions`
		margin = nil, -- set in `update_dimensions`
		update_dimensions = function(this)
			this.width = state.fullormaxed and options.volume_size_fullscreen or options.volume_size
			local controls, timeline, top_bar = Elements.controls, Elements.timeline, Elements.top_bar
			local padding_top = top_bar.enabled and top_bar.size or 0
			local padding_bottom = (timeline.enabled and timeline.size_max or 0) +
				(controls and controls.enabled and controls.by - controls.ay or 0)
			local available_height = display.height - padding_top - padding_bottom
			local max_height = available_height * 0.8
			this.height = round(math.min(this.width * 8, max_height))
			this.enabled = this.height > this.width * 2 -- don't render if too small
			this.margin = (this.width / 2) + Elements.window_border.size
			this.ax = round(options.volume == 'left' and this.margin or display.width - this.margin - this.width)
			this.ay = padding_top + round((available_height - this.height) / 2)
			this.bx = round(this.ax + this.width)
			this.by = round(this.ay + this.height)
		end,
		on_display_change = function(this) this:update_dimensions() end,
		on_prop_border = function(this) this:update_dimensions() end,
		render = render_volume,
	}))
	Elements:add(Element.new('volume_mute', {
		enabled = true,
		width = 0,
		height = 0,
		on_display_change = function(this)
			this.width = Elements.volume.width
			this.height = round(this.width * 0.8)
			this.ax, this.ay = Elements.volume.ax, Elements.volume.by - this.height
			this.bx, this.by = Elements.volume.bx, Elements.volume.by
		end,
		on_mbtn_left_down = function(this) mp.commandv('cycle', 'mute') end,
	}))
	Elements:add(Element.new('volume_slider', {
		enabled = true,
		pressed = false,
		width = 0,
		height = 0,
		nudge_y = 0, -- vertical position where volume overflows 100
		nudge_size = nil, -- set on resize
		font_size = nil,
		spacing = nil,
		on_display_change = function(this)
			if state.volume_max == nil or state.volume_max == 0 then return end
			this.ax, this.ay = Elements.volume.ax, Elements.volume.ay
			this.bx, this.by = Elements.volume.bx, Elements.volume_mute.ay
			this.width, this.height = this.bx - this.ax, this.by - this.ay
			this.nudge_y = this.by - round(this.height * (100 / state.volume_max))
			this.nudge_size = round(Elements.volume.width * 0.18)
			this.draw_nudge = this.ay < this.nudge_y
			this.spacing = round(this.width * 0.2)
		end,
		set_volume = function(this, volume)
			volume = round(volume / options.volume_step) * options.volume_step
			if state.volume == volume then return end
			mp.commandv('set', 'volume', math.max(math.min(volume, state.volume_max), 0))
		end,
		set_from_cursor = function(this)
			local volume_fraction = (this.by - cursor.y - options.volume_border) / (this.height - options.volume_border)
			this:set_volume(volume_fraction * state.volume_max)
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
		on_wheel_up = function(this) this:set_volume(state.volume + options.volume_step) end,
		on_wheel_down = function(this) this:set_volume(state.volume - options.volume_step) end,
	}))
end
Elements:add(Element.new('curtain', {
	enabled = true,
	ignores_menu = true,
	opacity = 0,
	fadeout = function(this)
		this:tween_property('opacity', this.opacity, 0);
	end,
	fadein = function(this)
		this:tween_property('opacity', this.opacity, 1);
	end,
	render = function(this)
		if this.opacity > 0 and options.curtain_opacity > 0 then
			local ass = assdraw.ass_new()
			ass:rect(0, 0, display.width, display.height, {
				color = options.color_background, opacity = options.curtain_opacity * this.opacity,
			})
			return ass
		end
	end,
}))

-- CHAPTERS SERIALIZATION

-- Parse `chapter_ranges` option into workable data structure
for _, definition in ipairs(split(options.chapter_ranges, ' *,+ *')) do
	local start_patterns, color, opacity, end_patterns = string.match(
		definition,
		'([^<]+)<(%x%x%x%x%x%x):(%d?%.?%d*)>([^>]+)'
	)

	-- Valid definition
	if start_patterns then
		start_patterns = start_patterns:lower()
		end_patterns = end_patterns:lower()
		local uses_bof = start_patterns:find('{bof}') ~= nil
		local uses_eof = end_patterns:find('{eof}') ~= nil
		local chapter_range = {
			start_patterns = split(start_patterns, '|'),
			end_patterns = split(end_patterns, '|'),
			color = color,
			opacity = tonumber(opacity),
			ranges = {},
		}

		-- Filter out special keywords so we don't use them when matching titles
		if uses_bof then
			chapter_range.start_patterns = itable_remove(chapter_range.start_patterns, '{bof}')
		end
		if uses_eof and chapter_range.end_patterns then
			chapter_range.end_patterns = itable_remove(chapter_range.end_patterns, '{eof}')
		end

		chapter_range['serialize'] = function(chapters)
			chapter_range.ranges = {}
			local current_range = nil
			-- bof and eof should be used only once per timeline
			-- eof is only used when last range is missing end
			local bof_used = false

			local function start_range(chapter)
				-- If there is already a range started, should we append or overwrite?
				-- I chose overwrite here.
				current_range = {['start'] = chapter}
			end

			local function end_range(chapter)
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

					-- Is ending check and handling
					if chapter_range.end_patterns then
						chapter.is_end_only = false
						for _, end_pattern in ipairs(chapter_range.end_patterns) do
							if lowercase_title:find(end_pattern) then
								if current_range == nil and uses_bof and not bof_used then
									bof_used = true
									start_range({time = 0})
								end
								if current_range ~= nil then
									end_range(chapter)
								end
								chapter.is_end_only = end_pattern ~= '.*'
								break
							end
						end
					end

					-- Is start check and handling
					for _, start_pattern in ipairs(chapter_range.start_patterns) do
						if lowercase_title:find(start_pattern) then
							start_range(chapter)
							chapter.is_end_only = false
							break
						end
					end
				end
			end

			-- If there is an unfinished range and range type accepts eof, use it
			if current_range ~= nil and uses_eof then
				end_range({time = state.duration or infinity})
			end
		end

		state.chapter_ranges = state.chapter_ranges or {}
		state.chapter_ranges[#state.chapter_ranges + 1] = chapter_range
	end
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

	for _, chapter in ipairs(chapters) do
		chapter.title_wrapped, chapter.title_wrapped_width = wrap_text(chapter.title, 25)
		chapter.title_wrapped = ass_escape(chapter.title_wrapped)
	end

	state.chapters = chapters

	request_render()
end

-- CONTEXT MENU SERIALIZATION

state.context_menu_items = (function()
	local input_conf_path = mp.command_native({'expand-path', '~~/input.conf'})
	local input_conf_meta, meta_error = utils.file_info(input_conf_path)

	-- File doesn't exist
	if not input_conf_meta or not input_conf_meta.is_file then return end

	local main_menu = {items = {}, items_by_command = {}}
	local submenus_by_id = {}

	for line in io.lines(input_conf_path) do
		local key, command, title = string.match(line, '%s*([%S]+)%s+(.-)%s+#!%s*(.-)%s*$')
		if not key then
			key, command, title = string.match(line, '%s*([%S]+)%s+(.-)%s+#menu:%s*(.-)%s*$')
		end
		if key then
			local is_dummy = key:sub(1, 1) == '#'
			local submenu_id = ''
			local target_menu = main_menu
			local title_parts = split(title or '', ' *> *')

			for index, title_part in ipairs(#title_parts > 0 and title_parts or {''}) do
				if index < #title_parts then
					submenu_id = submenu_id .. title_part

					if not submenus_by_id[submenu_id] then
						local items = {}
						submenus_by_id[submenu_id] = {items = items, items_by_command = {}}
						target_menu.items[#target_menu.items + 1] = {title = title_part, items = items}
					end

					target_menu = submenus_by_id[submenu_id]
				else
					if command == 'ignore' then break end
					-- If command is already in menu, just append the key to it
					if target_menu.items_by_command[command] then
						local hint = target_menu.items_by_command[command].hint
						target_menu.items_by_command[command].hint = hint and hint .. ', ' .. key or key
					else
						local item = {
							title = title_part,
							hint = not is_dummy and key or nil,
							value = command,
						}
						target_menu.items_by_command[command] = item
						target_menu.items[#target_menu.items + 1] = item
					end
				end
			end
		end
	end

	if #main_menu.items > 0 then
		return main_menu.items
	else
		-- Default context menu
		return {
			{title = 'Open file', value = 'script-binding uosc/open-file'},
			{title = 'Playlist', value = 'script-binding uosc/playlist'},
			{title = 'Chapters', value = 'script-binding uosc/chapters'},
			{title = 'Subtitle tracks', value = 'script-binding uosc/subtitles'},
			{title = 'Audio tracks', value = 'script-binding uosc/audio'},
			{title = 'Stream quality', value = 'script-binding uosc/stream-quality'},
			{title = 'Navigation', items = {
				{title = 'Next', hint = 'playlist or file', value = 'script-binding uosc/next'},
				{title = 'Prev', hint = 'playlist or file', value = 'script-binding uosc/prev'},
				{title = 'Delete file & Next', value = 'script-binding uosc/delete-file-next'},
				{title = 'Delete file & Prev', value = 'script-binding uosc/delete-file-prev'},
				{title = 'Delete file & Quit', value = 'script-binding uosc/delete-file-quit'},
			},},
			{title = 'Utils', items = {
				{title = 'Load subtitles', value = 'script-binding uosc/load-subtitles'},
				{title = 'Aspect ratio', items = {
					{title = 'Default', value = 'set video-aspect-override "-1"'},
					{title = '16:9', value = 'set video-aspect-override "16:9"'},
					{title = '4:3', value = 'set video-aspect-override "4:3"'},
					{title = '2.35:1', value = 'set video-aspect-override "2.35:1"'},
				},},
				{title = 'Audio devices', value = 'script-binding uosc/audio-device'},
				{title = 'Screenshot', value = 'async screenshot'},
				{title = 'Show in directory', value = 'script-binding uosc/show-in-directory'},
				{title = 'Open config folder', value = 'script-binding uosc/open-config-directory'},
			},},
			{title = 'Quit', value = 'quit'},
		}
	end
end)()

-- EVENT HANDLERS

function create_state_setter(name, callback)
	return function(_, value)
		set_state(name, value)
		if callback then callback() end
		request_render()
	end
end

function set_state(name, value)
	state[name] = value
	Elements:trigger('prop_' .. name, value)
end

function update_cursor_position()
	cursor.x, cursor.y = mp.get_mouse_pos()

	-- mpv reports initial mouse position on linux as (0, 0), which always
	-- displays the top bar, so we hardcode cursor position as infinity until
	-- we receive a first real mouse move event with coordinates other than 0,0.
	if not state.first_real_mouse_move_received then
		if cursor.x > 0 and cursor.y > 0 then
			state.first_real_mouse_move_received = true
		else
			cursor.x = infinity
			cursor.y = infinity
		end
	end

	local dpi_scale = mp.get_property_native('display-hidpi-scale', 1.0)
	dpi_scale = dpi_scale * options.ui_scale

	cursor.x = cursor.x / dpi_scale
	cursor.y = cursor.y / dpi_scale

	update_proximities()
	request_render()
end

function handle_mouse_leave()
	-- Slowly fadeout elements that are currently visible
	for _, element_name in ipairs({'timeline', 'volume', 'top_bar'}) do
		local element = Elements[element_name]
		if element and element.proximity > 0 then
			element:tween_property('forced_visibility', element:get_visibility(), 0, function()
				element.forced_visibility = nil
			end)
		end
	end

	cursor.hidden = true
	update_proximities()
	Elements:trigger('global_mouse_leave')
end

function handle_mouse_enter()
	cursor.hidden = false
	update_cursor_position()
	tween_element_stop(state)
	Elements:trigger('global_mouse_enter')
end

function handle_mouse_move()
	-- Handle case when we are in cursor hidden state but not left the actual
	-- window (i.e. when autohide simulates mouse_leave).
	if cursor.hidden then
		handle_mouse_enter()
		return
	end

	update_cursor_position()
	Elements:trigger('global_mouse_move')
	request_render()

	-- Restart timer that hides UI when mouse is autohidden
	if options.autohide then
		state.cursor_autohide_timer:kill()
		state.cursor_autohide_timer:resume()
	end
end

function navigate_directory(direction)
	local path = mp.get_property_native('path')

	if not path or is_protocol(path) then return end

	local next_file = get_adjacent_file(path, direction, options.media_types)

	if next_file then
		mp.commandv('loadfile', utils.join_path(serialize_path(path).dirname, next_file))
	end
end

function load_file_in_current_directory(index)
	local path = mp.get_property_native('path')

	if not path or is_protocol(path) then return end

	local dirname = serialize_path(path).dirname
	local files = get_files_in_directory(dirname, options.media_types)

	if not files then return end
	if index < 0 then index = #files + index + 1 end

	if files[index] then
		mp.commandv('loadfile', utils.join_path(dirname, files[index]))
	end
end

function update_render_delay(name, fps)
	if fps then
		state.render_delay = 1 / fps
	end
end

function observe_display_fps(name, fps)
	if fps then
		mp.unobserve_property(update_render_delay)
		mp.unobserve_property(observe_display_fps)
		mp.observe_property('display-fps', 'native', update_render_delay)
	end
end

-- MENUS

function toggle_menu_with_items(items, menu_options)
	menu_options = menu_options or {}
	menu_options.type = 'menu'

	-- preselect 1st item
	if not menu_options.selected_index then menu_options.selected_index = 1 end

	if menu:is_open('menu') then
		menu:close()
	elseif items then
		menu:open(items, function(command) mp.command(command) end, menu_options)
	end
end

---@param options {type: string; title: string; list_prop: string; list_serializer: fun(name: string, value: any): MenuItem[]; active_prop?: string; active_index_serializer: fun(name: string, value: any): integer; on_select: fun(value: any)}
function create_self_updating_menu_opener(options)
	return function()
		if menu:is_open(options.type) then menu:close() return end

		-- Update active index and playlist content on playlist changes
		local function handle_list_prop_change(name, value)
			if menu:is_open(options.type) then
				local items, active_index, default_selected_index = options.list_serializer(name, value)
				Elements.menu:update({items = items, active_index = active_index})
			end
		end

		local function handle_active_prop_change(name, value)
			if menu:is_open(options.type) then
				Elements.menu:activate_index(options.active_index_serializer(name, value))
			end
		end

		-- Items and active_index are set in the handle_prop_change callback, since adding
		-- a property observer triggers its handler immediately, we just let that initialize the items.
		menu:open({}, options.on_select, {
			type = options.type,
			title = options.title,
			on_open = function()
				mp.observe_property(options.list_prop, 'native', handle_list_prop_change)
				if options.active_prop then
					mp.observe_property(options.active_prop, 'native', handle_active_prop_change)
				end
			end,
			on_close = function()
				mp.unobserve_property(handle_list_prop_change)
				mp.unobserve_property(handle_active_prop_change)
			end,
		})
	end
end

function create_select_tracklist_type_menu_opener(menu_title, track_type, track_prop, load_command)
	local function serialize_tracklist(_, tracklist)
		local items = {}
		local active_index = nil
		local disabled_item_index = nil

		if load_command then
			items[#items + 1] = {title = 'Load', bold = true, hint = 'open file', value = '{load}'}
		end

		-- Add option to disable a subtitle track. This works for all tracks,
		-- but why would anyone want to disable audio or video? Better to not
		-- let people mistakenly select what is unwanted 99.999% of the time.
		-- If I'm mistaken and there is an active need for this, feel free to
		-- open an issue.
		if track_type == 'sub' then
			items[#items + 1] = {title = 'Disabled', italic = true, muted = true, hint = '—', value = nil}
			disabled_item_index = #items
		end

		local static_items_count = #items
		for _, track in ipairs(tracklist) do
			if track.type == track_type then
				local hint_vals = {
					track.lang and track.lang:upper() or nil,
					track['demux-h'] and (track['demux-w'] and track['demux-w'] .. 'x' .. track['demux-h']
						or track['demux-h'] .. 'p'),
					track['demux-fps'] and string.format('%.5gfps', track['demux-fps']) or nil,
					track.codec,
					track['audio-channels'] and track['audio-channels'] .. ' channels' or nil,
					track['demux-samplerate'] and string.format('%.3gkHz', track['demux-samplerate'] / 1000) or nil,
					track.forced and 'forced' or nil,
					track.default and 'default' or nil,
				}
				local hint_vals_filtered = {}
				for i = 1, #hint_vals do
					if hint_vals[i] then
						hint_vals_filtered[#hint_vals_filtered + 1] = hint_vals[i]
					end
				end

				items[#items + 1] = {
					title = (track.title and track.title or 'Track ' .. track.id),
					hint = table.concat(hint_vals_filtered, ', '),
					value = track.id,
				}

				if track.selected then active_index = #items end
			end
		end

		-- Preselect disabled item if active index is missing
		if not active_index then active_index = disabled_item_index end

		-- items, active index, default selected index when active is nil
		return items, active_index, static_items_count + 1
	end

	local function selection_handler(value)
		if value == '{load}' then
			mp.command(load_command)
		else
			mp.commandv('set', track_prop, value and value or 'no')

			-- If subtitle track was selected, assume user also wants to see it
			if value and track_type == 'sub' then
				mp.commandv('set', 'sub-visibility', 'yes')
			end
		end
	end

	return create_self_updating_menu_opener({
		title = menu_title,
		type = track_type,
		list_prop = 'track-list',
		list_serializer = serialize_tracklist,
		on_select = selection_handler,
	})
end

---@alias NavigationMenuOptions {type: string, title?: string, allowed_types?: string[], active_path?: string, selected_path?: string}

-- Opens a file navigation menu with items inside `directory_path`.
---@param directory_path string
---@param handle_select fun(path: string): nil
---@param menu_options NavigationMenuOptions
function open_file_navigation_menu(directory_path, handle_select, menu_options)
	directory = serialize_path(directory_path)
	menu_options = menu_options or {}

	if not directory then
		msg.error('Couldn\'t serialize path "' .. directory_path .. '.')
		return
	end

	local directories, dirs_error = utils.readdir(directory.path, 'dirs')
	local files, files_error = get_files_in_directory(directory.path, menu_options.allowed_types)
	local is_root = not directory.dirname

	if not files or not directories then
		msg.error('Retrieving files from ' .. directory .. ' failed: ' .. (dirs_error or files_error or ''))
		return
	end

	-- Files are already sorted
	table.sort(directories, word_order_comparator)

	-- Pre-populate items with parent directory selector if not at root
	-- Each item value is a serialized path table it points to.
	local items = {}

	if is_root then
		if state.os == 'windows' then
			items[#items + 1] = {title = '..', hint = 'Drives', value = {is_drives = true, is_to_parent = true}}
		end
	else
		local serialized = serialize_path(directory.dirname)
		serialized.is_directory = true;
		serialized.is_to_parent = true;
		items[#items + 1] = {title = '..', hint = 'parent dir', value = serialized}
	end

	-- Index where actual items start
	local items_start_index = #items + 1

	for _, dir in ipairs(directories) do
		local serialized = serialize_path(utils.join_path(directory.path, dir))
		if serialized then
			serialized.is_directory = true
			items[#items + 1] = {title = serialized.basename, value = serialized, hint = '/'}
		end
	end

	for _, file in ipairs(files) do
		local serialized = serialize_path(utils.join_path(directory.path, file))
		if serialized then
			serialized.is_file = true
			items[#items + 1] = {title = serialized.basename, value = serialized}
		end
	end

	menu_options.active_index = nil

	for index, item in ipairs(items) do
		if not item.value.is_to_parent then
			if menu_options.active_path == item.value.path then
				menu_options.active_index = index
			end

			if menu_options.selected_path == item.value.path then
				menu_options.selected_index = index
			end
		end
	end

	if menu_options.selected_index == nil then
		menu_options.selected_index = menu_options.active_index or math.min(items_start_index, #items)
	end

	local inherit_title = false
	if menu_options.title == nil then
		menu_options.title = directory.basename .. '/'
	else
		inherit_title = true
	end

	menu:open(items, function(path)
		local inheritable_options = {
			type = menu_options.type,
			title = inherit_title and menu_options.title or nil,
			allowed_types = menu_options.allowed_types,
			active_path = menu_options.active_path,
		}

		if path.is_drives then
			open_drives_menu(function(drive_path)
				open_file_navigation_menu(drive_path, handle_select, inheritable_options)
			end, {type = inheritable_options.type, title = inheritable_options.title, selected_path = directory.path})
			return
		end

		if path.is_directory then
			--  Preselect directory we are coming from
			if path.is_to_parent then
				inheritable_options.selected_path = directory.path
			end

			open_file_navigation_menu(path.path, handle_select, inheritable_options)
		else
			handle_select(path.path)
			menu:close()
		end
	end, menu_options)
end

-- Opens a file navigation menu with Windows drives as items.
---@param handle_select fun(path: string): nil
---@param menu_options? NavigationMenuOptions
function open_drives_menu(handle_select, menu_options)
	menu_options = menu_options or {}
	local process = mp.command_native({
		name = 'subprocess',
		capture_stdout = true,
		playback_only = false,
		args = {'wmic', 'logicaldisk', 'get', 'name', '/value'},
	})
	local items = {}

	if process.status == 0 then
		for _, value in ipairs(split(process.stdout, '\n')) do
			local drive = string.match(value, 'Name=([A-Z]:)')
			if drive then
				local drive_path = normalize_path(drive)
				items[#items + 1] = {title = drive, hint = 'Drive', value = drive_path}
				if menu_options.selected_path == drive_path then
					menu_options.selected_index = #items
				end
			end
		end
	else
		msg.error(process.stderr)
	end

	if not menu_options.title then
		menu_options.title = 'Drives'
	end

	menu:open(items, handle_select, menu_options)
end

-- VALUE SERIALIZATION/NORMALIZATION

options.proximity_out = math.max(options.proximity_out, options.proximity_in + 1)
options.timeline_chapters = itable_index_of({'dots', 'lines', 'lines-top', 'lines-bottom'}, options.timeline_chapters)
	and
	options.timeline_chapters or 'never'
options.media_types = split(options.media_types, ' *, *')
options.subtitle_types = split(options.subtitle_types, ' *, *')
options.stream_quality_options = split(options.stream_quality_options, ' *, *')
options.timeline_cached_ranges = (function()
	if options.timeline_cached_ranges == '' or options.timeline_cached_ranges == 'no' then return nil end
	local parts = split(options.timeline_cached_ranges, ':')
	return parts[1] and {color = parts[1], opacity = tonumber(parts[2])} or nil
end)()
for _, name in ipairs({'timeline', 'controls', 'volume', 'top_bar', 'speed'}) do
	local option_name = name .. '_persistency'
	local flags = {}
	for _, state in ipairs(split(options[option_name], ' *, *')) do
		flags[state] = true
	end

	---@diagnostic disable-next-line: assign-type-mismatch
	options[option_name] = flags
end

-- HOOKS
mp.register_event('file-loaded', parse_chapters)
mp.observe_property('playback-time', 'number', create_state_setter('time', update_human_times))
mp.observe_property('duration', 'number', create_state_setter('duration', update_human_times))
mp.observe_property('speed', 'number', create_state_setter('speed', update_human_times))
mp.observe_property('track-list', 'native', function(name, value)
	-- checks the file dispositions
	local path = mp.get_property_native('path')
	local has_audio, is_video, is_image = false, false, false
	for _, track in ipairs(value) do
		if track.type == 'audio' then has_audio = true end
		if track.type == 'video' then
			is_image = track.image
			if not is_image and not track.albumart then
				is_video = true
			end
		end
	end
	set_state('is_audio', not is_video and has_audio)
	set_state('is_image', is_image)
	set_state('has_audio', has_audio)
	set_state('is_video', is_video)
	set_state('is_stream', is_protocol(path))
	Elements:trigger('dispositions')
end)
mp.observe_property('chapter-list', 'native', parse_chapters)
mp.observe_property('border', 'bool', create_state_setter('border'))
mp.observe_property('ab-loop-a', 'number', create_state_setter('ab_loop_a'))
mp.observe_property('ab-loop-b', 'number', create_state_setter('ab_loop_b'))
mp.observe_property('media-title', 'string', create_state_setter('media_title'))
mp.observe_property('playlist-pos-1', 'number', create_state_setter('playlist_pos'))
mp.observe_property('playlist-count', 'number', create_state_setter('playlist_count'))
mp.observe_property('fullscreen', 'bool', create_state_setter('fullscreen', update_fullormaxed))
mp.observe_property('window-maximized', 'bool', create_state_setter('maximized', update_fullormaxed))
mp.observe_property('idle-active', 'bool', create_state_setter('idle'))
mp.observe_property('pause', 'bool', create_state_setter('pause'))
mp.observe_property('volume', 'number', create_state_setter('volume'))
mp.observe_property('volume-max', 'number', create_state_setter('volume_max'))
mp.observe_property('mute', 'bool', create_state_setter('mute'))
mp.observe_property('osd-dimensions', 'native', function(name, val)
	update_display_dimensions()
	request_render()
end)
mp.observe_property('display-hidpi-scale', 'native', update_display_dimensions)
mp.observe_property('demuxer-cache-state', 'native', function(prop, cache_state)
	if cache_state == nil then
		state.cached_ranges = nil
		return
	end
	local cache_ranges = cache_state['seekable-ranges']
	state.cached_ranges = #cache_ranges > 0 and cache_ranges or nil
	request_render()
end)
mp.observe_property('display-fps', 'native', observe_display_fps)
mp.observe_property('estimated-display-fps', 'native', update_render_delay)

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
	end,
	}
end
mp.set_key_bindings(base_keybinds, 'mouse_movement', 'force')
mp.enable_key_bindings('mouse_movement', 'allow-vo-dragging+allow-hide-cursor')

-- Context based key bind groups

forced_key_bindings = (function()
	local function create_mouse_event_dispatcher(name)
		return function(...)
			for _, element in Elements:ipairs() do
				if element.proximity_raw == 0 then
					element:trigger(name, ...)
				end
				element:trigger('global_' .. name, ...)
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

-- MESSAGE HANDLERS

mp.register_script_message('get-version', function(script)
	mp.commandv('script-message-to', script, 'uosc-version', state.version)
end)
mp.register_script_message('show-menu', function(json)
	local menu_config = utils.parse_json(json)

	if type(menu_config) ~= 'table' or type(menu_config.items) ~= 'table' then
		msg.error('show-menu: received json didn\'t produce a table with menu configuration')
		return
	end

	function run_command(value)
		if type(value) == 'string' then
			mp.command(value)
		else
			---@diagnostic disable-next-line: deprecated
			mp.commandv((unpack or table.unpack)(value))
		end
	end

	if menu_config.type ~= nil and menu:is_open(menu_config.type) then
		menu:close()
		return
	end

	Menu:open(menu_config.items, run_command, {
		type = menu_config.type,
		title = menu_config.title,
		selected_index = menu_config.selected_index or menu_config.active_index or (#menu_config.items > 0 and 1 or nil),
		active_index = menu_config.active_index,
	})
end)
mp.register_script_message('show-submenu', function(name)
	local path = split(name, ' *>+ *')
	local items = state.context_menu_items
	local last_menu_title = nil

	if not items or #items < 1 then
		msg.error('Can\'t find submenu, context menu is empty.')
		return
	end

	while #path > 0 do
		local menu_title = path[1]
		last_menu_title = menu_title
		path = itable_slice(path, 2)
		local _, submenu_item = itable_find(items, function(_, item) return item.title == menu_title end)

		if not submenu_item then
			msg.error('Can\'t find submenu: ' .. menu_title)
			return
		end

		items = submenu_item.items or {}
	end

	if items then toggle_menu_with_items(items, {title = last_menu_title, selected_index = 1}) end
end)

-- KEY BINDABLE FEATURES

mp.add_key_binding(nil, 'peek-timeline', function()
	if Elements.timeline.proximity > 0.5 then
		Elements.timeline:tween_property('proximity', Elements.timeline.proximity, 0)
	else
		Elements.timeline:tween_property('proximity', Elements.timeline.proximity, 1)
	end
end)
mp.add_key_binding(nil, 'toggle-progress', function()
	local timeline = Elements.timeline
	if timeline.size_min_override then
		timeline:tween_property('size_min_override', timeline.size_min_override, timeline.size_min, function()
			timeline.size_min_override = nil
		end)
	else
		timeline:tween_property('size_min_override', timeline.size_min, 0)
	end
end)
mp.add_key_binding(nil, 'flash-timeline', function()
	Elements.timeline:flash()
end)
mp.add_key_binding(nil, 'flash-top-bar', function()
	Elements.top_bar:flash()
end)
mp.add_key_binding(nil, 'flash-volume', function()
	if Elements.volume then Elements.volume:flash() end
end)
mp.add_key_binding(nil, 'flash-speed', function()
	if Elements.speed then Elements.speed:flash() end
end)
mp.add_key_binding(nil, 'flash-pause-indicator', function()
	Elements.pause_indicator:flash()
end)
mp.add_key_binding(nil, 'decide-pause-indicator', function()
	Elements.pause_indicator:decide()
end)
function menu_key_binding() toggle_menu_with_items(state.context_menu_items) end
mp.add_key_binding(nil, 'menu', menu_key_binding)
local track_loaders = {
	{name = 'subtitles', prop = 'sub', extensions = options.subtitle_types --[[@as table]]},
	{name = 'audio', prop = 'audio'},
	{name = 'video', prop = 'video'},
}
for _, loader in ipairs(track_loaders) do
	local menu_type = 'load-' .. loader.name
	mp.add_key_binding(nil, menu_type, function()
		if menu:is_open(menu_type) then menu:close() return end

		local path = mp.get_property_native('path') --[[@as string|nil|false]]
		if path then
			if is_protocol(path) then
				path = false
			else
				local serialized_path = serialize_path(path)
				path = serialized_path ~= nil and serialized_path.dirname or false
			end
		end
		if not path then
			path = get_default_directory()
		end
		open_file_navigation_menu(
			path,
			function(path) mp.commandv(loader.prop .. '-add', path) end,
			{type = menu_type, title = 'Load ' .. loader.name, allowed_types = loader.extensions}
		)
	end)
end
mp.add_key_binding(nil, 'subtitles', create_select_tracklist_type_menu_opener(
	'Subtitles', 'sub', 'sid', 'script-binding uosc/load-subtitles'
))
mp.add_key_binding(nil, 'audio', create_select_tracklist_type_menu_opener(
	'Audio', 'audio', 'aid', 'script-binding uosc/load-audio'
))
mp.add_key_binding(nil, 'video', create_select_tracklist_type_menu_opener(
	'Video', 'video', 'vid', 'script-binding uosc/load-video'
))
mp.add_key_binding(nil, 'playlist', create_self_updating_menu_opener({
	title = 'Playlist',
	type = 'playlist',
	list_prop = 'playlist',
	list_serializer = function(_, playlist)
		local items = {}
		for index, item in ipairs(playlist) do
			local is_url = item.filename:find('://')
			local item_title = type(item.title) == 'string' and #item.title > 0 and item.title or false
			items[index] = {
				title = item_title or (is_url and item.filename or serialize_path(item.filename).basename),
				hint = tostring(index),
				value = index,
			}
		end
		return items
	end,
	active_prop = 'playlist-pos-1',
	active_index_serializer = function(_, playlist_pos) return playlist_pos end,
	on_select = function(index) mp.commandv('set', 'playlist-pos-1', tostring(index)) end,
}))
mp.add_key_binding(nil, 'chapters', create_self_updating_menu_opener({
	title = 'Chapters',
	type = 'chapters',
	list_prop = 'chapter-list',
	list_serializer = function(_, _)
		local items = {}
		local chapters = get_normalized_chapters()

		for index, chapter in ipairs(chapters) do
			items[#items + 1] = {
				title = chapter.title or '',
				hint = mp.format_time(chapter.time),
				value = chapter.time,
			}
		end
		return items
	end,
	active_prop = 'playback-time',
	active_index_serializer = function(_, playback_time)
		-- Select first chapter from the end with time lower
		-- than current playing position.
		local position = playback_time
		if not position then return nil end
		local items = Elements.menu.items
		for index = #items, 1, -1 do
			if position >= items[index].value then return index end
		end
	end,
	on_select = function(time) mp.commandv('seek', tostring(time), 'absolute') end,
}))
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
	local active_index = nil
	local formats = {}

	for index, height in ipairs(options.stream_quality_options) do
		local format = 'bestvideo[height<=?' .. height .. ']+bestaudio/best[height<=?' .. height .. ']'
		formats[#formats + 1] = {
			title = height .. 'p',
			value = format,
		}
		if format == ytdl_format then active_index = index end
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
		active_index = active_index,
	})
end)
mp.add_key_binding(nil, 'open-file', function()
	if menu:is_open('open-file') then menu:close() return end

	local path = mp.get_property_native('path')
	local directory
	local active_file

	if path == nil or is_protocol(path) then
		local serialized = serialize_path(get_default_directory())
		if serialized then
			directory = serialized.path
			active_file = nil
		end
	else
		local serialized = serialize_path(path)
		if serialized then
			directory = serialized.dirname
			active_file = serialized.path
		end
	end

	if not directory then
		msg.error('Couldn\'t serialize path "' .. path .. '".')
		return
	end

	-- Update selected file in directory navigation menu
	local function handle_file_loaded()
		if menu:is_open('open-file') then
			local path = normalize_path(mp.get_property_native('path'))
			Elements.menu:activate_value(path)
			Elements.menu:select_value(path)
		end
	end

	open_file_navigation_menu(
		directory,
		function(path) mp.commandv('loadfile', path) end,
		{
			type = 'open-file',
			allowed_types = options.media_types --[[@as table]] ,
			active_path = active_file,
			on_open = function() mp.register_event('file-loaded', handle_file_loaded) end,
			on_close = function() mp.unregister_event(handle_file_loaded) end,
		}
	)
end)
mp.add_key_binding(nil, 'items', function()
	if state.playlist_count > 1 then
		mp.command('script-binding uosc/playlist')
	else
		mp.command('script-binding uosc/open-file')
	end
end)
mp.add_key_binding(nil, 'next', function()
	if state.playlist_count > 1 then
		mp.command('playlist-next')
	else
		navigate_directory('forward')
	end
end)
mp.add_key_binding(nil, 'prev', function()
	if state.playlist_count > 1 then
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
	local playlist_count = mp.get_property_native('playlist-count')

	local next_file = nil

	local path = mp.get_property_native('path')
	local is_local_file = path and not is_protocol(path)

	if is_local_file then
		path = normalize_path(path)

		if menu:is_open('open-file') then
			Elements.menu:delete_value(path)
		end
	end

	if playlist_count > 1 then
		mp.commandv('playlist-remove', 'current')
	else
		if is_local_file then
			next_file = get_adjacent_file(path, 'forward', options.media_types)
		end

		if next_file then
			mp.commandv('loadfile', next_file)
		else
			mp.commandv('stop')
		end
	end

	if is_local_file then delete_file(path) end
end)
mp.add_key_binding(nil, 'delete-file-quit', function()
	local path = mp.get_property_native('path')
	mp.command('stop')
	if path and not is_protocol(path) then delete_file(normalize_path(path)) end
	mp.command('quit')
end)
mp.add_key_binding(nil, 'audio-device', create_self_updating_menu_opener({
	title = 'Audio devices',
	type = 'audio-device-list',
	list_prop = 'audio-device-list',
	list_serializer = function(_, audio_device_list)
		local current_device = mp.get_property('audio-device') or 'auto'
		local ao = mp.get_property('current-ao') or ''
		local items = {}
		local active_index = nil
		for _, device in ipairs(audio_device_list) do
			if device.name == 'auto' or string.match(device.name, '^' .. ao) then
				local hint = string.match(device.name, ao .. '/(.+)')
				if not hint then hint = device.name end
				items[#items + 1] = {
					title = device.description,
					hint = hint,
					value = device.name,
				}
				if device.name == current_device then active_index = #items end
			end
		end
		return items, active_index
	end,
	on_select = function(name) mp.commandv('set', 'audio-device', name) end,
}))
mp.add_key_binding(nil, 'open-config-directory', function()
	local config_path = mp.command_native({'expand-path', '~~/mpv.conf'})
	local config = serialize_path(config_path)

	if config then
		local args

		if state.os == 'windows' then
			args = {'explorer', '/select,', config.path}
		elseif state.os == 'macos' then
			args = {'open', '-R', config.path}
		elseif state.os == 'linux' then
			args = {'xdg-open', config.dirname}
		end

		utils.subprocess_detached({args = args, cancellable = false})
	else
		msg.error('Couldn\'t serialize config path "' .. config_path .. '".')
	end
end)
