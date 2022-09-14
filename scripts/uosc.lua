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

--[[ BASE HELPERS ]]

---@param number number
function round(number)
	local modulus = number % 1
	return modulus < 0.5 and math.floor(number) or math.ceil(number)
end

function call_me_maybe(fn, ...)
	if fn then fn(...) end
end

---@param str string
---@param pattern string
---@return string[]
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

---@param target any[]
---@param source any[]
function itable_append(target, source)
	for _, value in ipairs(source) do target[#target + 1] = value end
	return target
end

---@param target any[]
---@param source any[]
---@param props? string[]
function table_assign(target, source, props)
	if props then
		for _, name in ipairs(props) do target[name] = source[name] end
	else
		for prop, value in pairs(source) do target[prop] = value end
	end
	return target
end

---@generic T
---@param table T
---@return T
function table_copy(table)
	local result = {}
	for key, value in pairs(table) do result[key] = type(value) == 'table' and table_copy(value) or value end
	return result
end

---@generic T
---@param table T
---@return T
function table_shallow_copy(table)
	local result = {}
	for key, value in pairs(table) do result[key] = value end
	return result
end

--[[ OPTIONS ]]

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
	timeline_cached_ranges = '4e845c:0.8',
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

	speed_persistency = '',
	speed_opacity = 1,
	speed_step = 0.1,
	speed_step_is_factor = false,

	menu_item_height = 36,
	menu_item_height_fullscreen = 50,
	menu_min_width = 260,
	menu_min_width_fullscreen = 360,
	menu_wasd_navigation = false,
	menu_hjkl_navigation = false,
	menu_opacity = 1,
	menu_parent_opacity = 0.4,

	top_bar = 'no-border',
	top_bar_size = 40,
	top_bar_size_fullscreen = 46,
	top_bar_persistency = '',
	top_bar_controls = true,
	top_bar_title = true,

	window_border_size = 1,
	window_border_opacity = 0.8,

	ui_scale = 1,
	font_scale = 1,
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
-- Normalize values
options.proximity_out = math.max(options.proximity_out, options.proximity_in + 1)
options.timeline_chapters = itable_index_of({'dots', 'lines', 'lines-top', 'lines-bottom'}, options.timeline_chapters)
	and options.timeline_chapters or 'never'

--[[ CONFIG ]]

local config = {
	version = uosc_version,
	-- sets max rendering frequency in case the
	-- native rendering frequency could not be detected
	render_delay = 1 / 60,
	font = mp.get_property('options/osd-font'),
	media_types = split(options.media_types, ' *, *'),
	subtitle_types = split(options.subtitle_types, ' *, *'),
	stream_quality_options = split(options.stream_quality_options, ' *, *'),
	cached_ranges = (function()
		if options.timeline_cached_ranges == '' or options.timeline_cached_ranges == 'no' then return nil end
		local parts = split(options.timeline_cached_ranges, ':')
		return parts[1] and {color = parts[1], opacity = tonumber(parts[2])} or nil
	end)(),
	menu_items = (function()
		local input_conf_path = mp.command_native({'expand-path', '~~/input.conf'})
		local input_conf_meta, meta_error = utils.file_info(input_conf_path)

		-- File doesn't exist
		if not input_conf_meta or not input_conf_meta.is_file then return end

		local main_menu = {items = {}, items_by_command = {}}
		local by_id = {}

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

						if not by_id[submenu_id] then
							local items = {}
							by_id[submenu_id] = {items = items, items_by_command = {}}
							target_menu.items[#target_menu.items + 1] = {title = title_part, items = items}
						end

						target_menu = by_id[submenu_id]
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
	end)(),
}
-- Adds `{element}_persistency` property with table of flags when the element should be visible (`{paused = true}`)
for _, name in ipairs({'timeline', 'controls', 'volume', 'top_bar', 'speed'}) do
	local option_name = name .. '_persistency'
	local value, flags = options[option_name], {}

	if type(value) == 'string' then
		for _, state in ipairs(split(value, ' *, *')) do flags[state] = true end
	end

	config[option_name] = flags
end

--[[ STATE ]]

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
	has_playlist = nil,
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

-- Parse `chapter_ranges` option into workable data structure
local chapter_ranges = nil
for _, definition in ipairs(split(options.chapter_ranges, ' *,+ *')) do
	local start_patterns, color, opacity, end_patterns = string.match(
		definition, '([^<]+)<(%x%x%x%x%x%x):(%d?%.?%d*)>([^>]+)'
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

		chapter_ranges = chapter_ranges or {}
		chapter_ranges[#chapter_ranges + 1] = chapter_range
	end
end

--[[ CLASSES ]]

---@class Class
local Class = {}
function Class:new(...)
	local object = setmetatable({}, {__index = self})
	object:init(...)
	return object
end
function Class:init() end
function Class:destroy() end

function class(parent) return setmetatable({}, {__index = parent or Class}) end

--[[ HELPERS ]]

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

	---@param a string|number
	---@param b string|number
	---@return boolean
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
---@param from number
---@param to number|fun():number
---@param setter fun(value: number)
---@param factor_or_callback? number|fun()
---@param callback? fun() Called either on animation end, or when animation is killed.
function tween(from, to, setter, factor_or_callback, callback)
	local factor = factor_or_callback
	if type(factor_or_callback) == 'function' then callback = factor_or_callback end
	if type(factor) ~= 'number' then factor = 0.3 end

	local current, done, timeout = from, false, nil
	local get_to = type(to) == 'function' and to or function() return to --[[@as number]] end
	local cutoff = math.abs(get_to() - from) * 0.01

	local function finish()
		if not done then
			done = true
			timeout:kill()
			call_me_maybe(callback)
		end
	end

	local function tick()
		local to = get_to()
		current = current + ((to - current) * factor)
		local is_end = math.abs(to - current) <= cutoff
		setter(is_end and to or current)
		request_render()
		if is_end then finish()
		else timeout:resume() end
	end

	timeout = mp.add_timeout(state.render_delay, tick)
	tick()

	return finish
end

---@param point {x: number; y: number}
---@param rect {ax: number; ay: number; bx: number; by: number}
function get_point_to_rectangle_proximity(point, rect)
	local dx = math.max(rect.ax - point.x, 0, point.x - rect.bx + 1)
	local dy = math.max(rect.ay - point.y, 0, point.y - rect.by + 1)
	return math.sqrt(dx * dx + dy * dy);
end

---@param text string|number
---@param font_size number
function text_width_estimate(text, font_size)
	return text_length(text) * font_size * options.font_height_to_letter_width_ratio
end

---@param length number
---@param font_size number
function text_length_width_estimate(length, font_size)
	return length * font_size * options.font_height_to_letter_width_ratio
end

---@param text string|number
function text_length(text)
	if not text or text == '' then return 0 end
	local text_length = 0
	for _, _, length in utf8_iter(text) do text_length = text_length + length end
	return text_length
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
---@param str string
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

---@param opacity number 0-1
function opacity_to_alpha(opacity)
	return 255 - math.ceil(255 * opacity)
end

-- Ensures path is absolute and normalizes slashes to the current platform
---@param path string
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
---@param path string
function is_protocol(path)
	return type(path) == 'string' and path:match('^%a[%a%d-_]+://') ~= nil
end

---@param path string
function get_extension(path)
	local parts = split(path, '%.')
	return parts and #parts > 1 and parts[#parts] or nil
end

---@return string
function get_default_directory()
	return mp.command_native({'expand-path', options.default_directory})
end

-- Serializes path into its semantic parts
---@param path string
---@return nil|{path: string; is_root: boolean; dirname?: string; basename: string; filename: string; extension?: string;}
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

---@param directory string
---@param allowed_types? string[]
---@return nil|string[]
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

---@param file_path string
---@param direction 'forward'|'backward'
---@param allowed_types? string[]
---@return nil|string
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
---@param path string
function delete_file(path)
	local args = state.os == 'windows' and {'cmd', '/C', 'del', path} or {'rm', path}
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

--[[ ASSDRAW EXTENSIONS ]]

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
	opts.font = 'MaterialIconsRound-Regular'
	self:txt(x, y, opts.align or 5, name, opts)
end

-- Text
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
---@param opts? {color?: string; border?: number; border_color?: string; opacity?: number; border_opacity?: number; clip?: string, radius?: number}
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
		tags = tags .. string.format('\\1a&H%X&', opacity_to_alpha(opts.opacity))
	end
	-- border opacity
	if opts.border_opacity then
		tags = tags .. string.format('\\3a&H%X&', opacity_to_alpha(opts.border_opacity))
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

--[[ ELEMENTS COLLECTION ]]

local Elements = {itable = {}}

---@param element Element
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
		if not element.destroyed then element:destroy() end
		element.enabled = false
		self.itable = itable_remove(self.itable, self[id])
		self[id] = nil
		request_render()
	end
end

function Elements:update_proximities()
	local capture_mbtn_left = false
	local capture_wheel = false
	local menu_only = Elements.menu ~= nil
	local mouse_leave_elements = {}
	local mouse_enter_elements = {}

	-- Calculates proximities and opacities for defined elements
	for _, element in self:ipairs() do
		if element.enabled then
			local previous_proximity_raw = element.proximity_raw

			-- If menu is open, all other elements have to be disabled
			if menu_only then
				if element.ignores_menu then
					capture_mbtn_left = true
					capture_wheel = true
					element:update_proximity()
				else
					element.proximity_raw = infinity
					element.proximity = 0
				end
			else
				element:update_proximity()
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

	-- Enable key group captures requested by elements
	mp[capture_mbtn_left and 'enable_key_bindings' or 'disable_key_bindings']('mbtn_left')
	mp[capture_wheel and 'enable_key_bindings' or 'disable_key_bindings']('wheel')

	-- Trigger `mouse_leave` and `mouse_enter` events
	for _, element in ipairs(mouse_leave_elements) do element:trigger('mouse_leave') end
	for _, element in ipairs(mouse_enter_elements) do element:trigger('mouse_enter') end
end

---@param name string Event name.
function Elements:trigger(name, ...)
	for _, element in self:ipairs() do element:trigger(name, ...) end
end

-- Trigger two events, `name` and `global_name`, depending on element-cursor proximity.
-- Disabled elements don't receive these events.
---@param name string Event name.
function Elements:proximity_trigger(name, ...)
	for _, element in self:ipairs() do
		if element.enabled then
			if element.proximity_raw == 0 then element:trigger(name, ...) end
			element:trigger('global_' .. name, ...)
		end
	end
end

function Elements:has(id) return self[id] ~= nil end
function Elements:ipairs() return ipairs(self.itable) end

---@param name string Event name.
function Elements:create_proximity_dispatcher(name)
	return function(...) self:proximity_trigger(name, ...) end
end

mp.set_key_bindings({
	{
		'mbtn_left',
		Elements:create_proximity_dispatcher('mbtn_left_up'),
		Elements:create_proximity_dispatcher('mbtn_left_down'),
	},
	{'mbtn_left_dbl', 'ignore'},
}, 'mbtn_left', 'force')

mp.set_key_bindings({
	{'wheel_up', Elements:create_proximity_dispatcher('wheel_up')},
	{'wheel_down', Elements:create_proximity_dispatcher('wheel_down')},
}, 'wheel', 'force')

--[[ STATE UPDATES ]]

function update_display_dimensions()
	local dpi_scale = mp.get_property_native('display-hidpi-scale', 1.0)
	dpi_scale = dpi_scale * options.ui_scale

	local width, height, aspect = mp.get_osd_size()
	display.width = width / dpi_scale
	display.height = height / dpi_scale
	display.aspect = aspect

	-- Tell elements about this
	Elements:trigger('display')

	-- Some elements probably changed their rectangles as a reaction to `display`
	Elements:update_proximities()
	request_render()
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

-- Notifies other scripts such as console about where the unoccupied parts of the screen are.
function update_margins()
	-- margins are normalized to window size
	local timeline, top_bar, controls = Elements.timeline, Elements.top_bar, Elements.controls
	local bottom_y = controls and controls.enabled and controls.ay or timeline.ay
	local top, bottom = 0, (display.height - bottom_y) / display.height

	if top_bar.enabled and top_bar:get_visibility() > 0 then
		top = (top_bar.size or 0) / display.height
	end

	if top == state.margin_top and bottom == state.margin_bottom then return end

	state.margin_top = top
	state.margin_bottom = bottom

	utils.shared_script_property_set('osc-margins', string.format('%f,%f,%f,%f', 0, 0, top, bottom))
end

--[[ RENDERING ]]

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

--[[ ELEMENT ]]

---@alias ElementProps {enabled?: boolean; ax?: number; ay?: number; bx?: number; by?: number; ignores_menu?: boolean; anchor_id?: string;}

-- Base class all elements inherit from.
---@class Element : Class
local Element = class()

---@param id string
---@param props? ElementProps
function Element:init(id, props)
	self.id = id
	-- `false` means element won't be rendered, or receive events
	self.enabled = true
	-- Element coordinates
	self.ax, self.ay, self.bx, self.by = 0, 0, 0, 0
	-- Relative proximity from `0` - mouse outside `proximity_max` range, to `1` - mouse within `proximity_min` range.
	self.proximity = 0
	-- Raw proximity in pixels.
	self.proximity_raw = infinity
	---@type number `0-1` factor to force elements visibility.
	self.forced_visibility = nil
	---@type boolean Render this element even when menu is open.
	self.ignores_menu = false
	---@type nil|string ID of an element from which this one should inherit visibility.
	self.anchor_id = nil

	if props then table_assign(self, props) end

	-- Flash timer
	self._flash_out_timer = mp.add_timeout(options.flash_duration / 1000, function()
		local getTo = function() return self.proximity end
		self:tween_property('forced_visibility', 1, getTo, function()
			self.forced_visibility = nil
		end)
	end)
	self._flash_out_timer:kill()

	Elements:add(self)
end

function Element:destroy()
	self.destroyed = true
	Elements:remove(self)
end

---@param ax number
---@param ay number
---@param bx number
---@param by number
function Element:set_coordinates(ax, ay, bx, by)
	self.ax, self.ay, self.bx, self.by = ax, ay, bx, by
	Elements:update_proximities()
	self:maybe('on_coordinates')
end

function Element:update_proximity()
	if cursor.hidden then
		self.proximity_raw = infinity
		self.proximity = 0
	else
		local range = options.proximity_out - options.proximity_in
		self.proximity_raw = get_point_to_rectangle_proximity(cursor, self)
		self.proximity = 1 - (math.min(math.max(self.proximity_raw - options.proximity_in, 0), range) / range)
	end
end

-- Decide elements visibility based on proximity and various other factors
function Element:get_visibility()
	-- Hide when menu is open, unless this is a menu
	---@diagnostic disable-next-line: undefined-global
	if not self.ignores_menu and menu and menu:is_open() then return 0 end

	-- Persistency
	local persist = config[self.id .. '_persistency'];
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

-- Attach a tweening animation to this element
---@param from number
---@param to number|fun():number
---@param setter fun(value: number)
---@param factor_or_callback? number|fun()
---@param callback? fun() Called either on animation end, or when animation is killed.
function Element:tween(from, to, setter, factor_or_callback, callback)
	self:tween_stop()
	self._kill_tween = self.enabled and tween(
		from, to, setter, factor_or_callback,
		function()
			self._kill_tween = nil
			call_me_maybe(callback)
		end
	)
end

function Element:is_tweening() return self and self._kill_tween end
function Element:tween_stop() self:maybe('_kill_tween') end

-- Animate an element property between 2 values.
---@param prop string
---@param from number
---@param to number|fun():number
---@param factor_or_callback? number|fun()
---@param callback? fun() Called either on animation end, or when animation is killed.
function Element:tween_property(prop, from, to, factor_or_callback, callback)
	self:tween(from, to, function(value) self[prop] = value end, factor_or_callback, callback)
end

---@param name string
function Element:trigger(name, ...)
	self:maybe('on_' .. name, ...)
	request_render()
end

-- Briefly flashes the element for `options.flash_duration` milliseconds.
-- Useful to visualize changes of volume and timeline when changed via hotkeys.
function Element:flash()
	if options.flash_duration > 0 and (self.proximity < 1 or self._flash_out_timer:is_enabled()) then
		self:tween_stop()
		self.forced_visibility = 1
		self._flash_out_timer:kill()
		self._flash_out_timer:resume()
	end
end

--[[ MENU ]]
--[[
Usage:
```
local data = {
	type = 'foo',
	title = 'Foo',
	items = {
		{title = 'Foo title', hint = 'Ctrl+F', value = 'foo'},
		{title = 'Submenu', items = {...}}
	}
}

function open_item(value)
	-- do something with value
end

local menu = Menu:open(items, open_item)
menu.update(new_data)
menu.update_items(new_items)
menu.close()
```
]]

-- Menu data structure accepted by `Menu:open(menu)`.
---@alias MenuData {type?: string; title?: string; hint?: string; keep_open?: boolean; separator?: boolean; items?: MenuDataItem[]; selected_index?: integer;}
---@alias MenuDataItem MenuDataValue|MenuData
---@alias MenuDataValue {title?: string; hint?: string; icon?: string; value: any; bold?: boolean; italic?: boolean; muted?: boolean; active?: boolean; keep_open?: boolean; separator?: boolean;}
---@alias MenuOptions {on_open?: fun(), on_close?: fun()}

-- Internal data structure created from `Menu`.
---@alias MenuStack {id?: string; type?: string; title?: string; hint?: string; selected_index?: number; keep_open?: boolean; separator?: boolean; items: MenuStackItem[]; parent_menu?: MenuStack; active?: boolean; width: number; height: number; top: number; scroll_y: number; scroll_height: number; title_length: number; title_width: number; hint_length: number; hint_width: number; max_width: number; is_root?: boolean;}
---@alias MenuStackItem MenuStackValue|MenuStack
---@alias MenuStackValue {title?: string; hint?: string; icon?: string; value: any; active?: boolean; bold?: boolean; italic?: boolean; muted?: boolean; keep_open?: boolean; separator?: boolean; title_length: number; title_width: number; hint_length: number; hint_width: number}

---@class Menu : Element
local Menu = class(Element)

---@param data MenuData
---@param callback fun(value: any)
---@param opts? MenuOptions
function Menu:open(data, callback, opts)
	if self:is_open() then self:close(true) end
	return Menu:new(data, callback, opts)
end

---@param menu_type? string
---@return Menu|nil
function Menu:is_open(menu_type)
	return Elements.menu and (not menu_type or Elements.menu.type == menu_type) and Elements.menu or nil
end

---@param immediate? boolean Close immediately without fadeout animation.
---@param callback? fun() Called after the animation (if any) ends and element is removed and destroyed.
---@overload fun(callback: fun())
function Menu:close(immediate, callback)
	if type(immediate) ~= 'boolean' then callback = immediate end

	local menu = self == Menu and Elements.menu or self

	if menu and not menu.destroyed then
		if menu.is_closing then
			menu:tween_stop()
			return
		end

		local function close()
			Elements:remove('menu')
			menu.is_closing, menu.stack, menu.current, menu.all, menu.by_id = false, nil, nil, {}, {}
			menu:disable_key_bindings()
			Elements:update_proximities()
			call_me_maybe(callback)
			request_render()
		end

		menu.is_closing = true

		if immediate then close()
		else menu:fadeout(close) end
	end
end

---@param data MenuData
---@param callback fun(value: any)
---@param opts? MenuOptions
---@return Menu
function Menu:new(data, callback, opts) return Class.new(self, data, callback, opts) --[[@as Menu]] end
function Menu:init(data, callback, opts)
	Element.init(self, 'menu', {ignores_menu = true})

	-----@type fun()
	self.callback = callback
	self.opts = opts or {}
	self.offset_x = 0 -- Used for submenu transition animation.
	self.item_height = nil
	self.item_spacing = 1
	self.item_padding = nil
	self.font_size = nil
	self.font_size_hint = nil
	self.scroll_step = nil -- Item height + item spacing.
	self.scroll_height = nil -- Items + spacings - container height.
	self.opacity = 0 -- Used to fade in/out.
	self.type = data.type
	---@type MenuStack Root MenuStack.
	self.root = nil
	---@type MenuStack Current MenuStack.
	self.current = nil
	---@type MenuStack[] All menus in a flat array.
	self.all = nil
	---@type table<string, MenuStack> Map of submenus by their ids, such as `'Tools > Aspect ratio'`.
	self.by_id = {}
	self.key_bindings = {}
	self.is_closing = false

	self:update(data)

	for _, menu in ipairs(self.all) do
		self:scroll_to_index(menu.selected_index, menu)
	end

	self:tween_property('opacity', 0, 1)
	self:enable_key_bindings()
	Elements.curtain:fadein()
	call_me_maybe(self.opts.on_open)
end

---@param data MenuData
function Menu:update(data)
	self.type = data.type

	local new_root = {is_root = true, title_length = text_length(data.title), hint_length = text_length(data.hint)}
	local new_all = {}
	local new_by_id = {}
	local menus_to_serialize = {{new_root, data}}
	local old_current_id = self.current and self.current.id

	table_assign(new_root, data, {'title', 'hint', 'keep_open'})

	local i = 0
	while i < #menus_to_serialize do
		i = i + 1
		local menu, menu_data = menus_to_serialize[i][1], menus_to_serialize[i][2]
		local parent_id = menu.parent_menu and not menu.parent_menu.is_root and menu.parent_menu.id
		if not menu.is_root then
			menu.id = (parent_id and parent_id .. ' > ' or '') .. (menu_data.title or i)
		end
		menu.icon = 'chevron_right'

		-- Update items
		local first_active_index = nil
		menu.items = {}

		for i, item_data in ipairs(menu_data.items or {}) do
			if item_data.active and not first_active_index then first_active_index = i end

			local item = {}
			table_assign(item, item_data, {
				'title', 'icon', 'hint', 'active', 'bold', 'italic', 'muted', 'value', 'keep_open', 'separator',
			})
			if item.keep_open == nil then item.keep_open = menu.keep_open end
			item.title_length = text_length(item.title)
			item.hint_length = text_length(item.hint)

			-- Submenu
			if item_data.items then
				item.parent_menu = menu
				menus_to_serialize[#menus_to_serialize + 1] = {item, item_data}
			end

			menu.items[i] = item
		end

		if menu.is_root then
			menu.selected_index = menu_data.selected_index or first_active_index or (#menu.items > 0 and 1 or nil)
		end

		-- Retain old state
		local old_menu = self.by_id[menu.is_root and '__root__' or menu.id]
		if old_menu then table_assign(menu, old_menu, {'selected_index', 'scroll_y'}) end

		new_all[#new_all + 1] = menu
		new_by_id[menu.is_root and '__root__' or menu.id] = menu
	end

	self.root, self.all, self.by_id = new_root, new_all, new_by_id
	self.current = self.by_id[old_current_id] or self.root
	local current_selected_index = self.current.selected_index

	self:update_content_dimensions()
	-- `update_content_dimensions()` triggers `select_item_below_cursor()`
	-- so we need to remember and re-apply `selected_index`.
	self.current.selected_index = current_selected_index
	self:reset_navigation()
end

---@param items MenuDataItem[]
function Menu:update_items(items)
	local data = table_shallow_copy(self.root)
	data.items = items
	self:update(data)
end

function Menu:update_content_dimensions()
	self.item_height = state.fullormaxed and options.menu_item_height_fullscreen or options.menu_item_height
	self.font_size = round(self.item_height * 0.48 * options.font_scale)
	self.font_size_hint = self.font_size - 1
	self.item_padding = round((self.item_height - self.font_size) * 0.6)
	self.scroll_step = self.item_height + self.item_spacing

	for _, menu in ipairs(self.all) do
		-- Estimate width of a widest item
		local max_width = 0
		for _, item in ipairs(menu.items) do
			local spacings_in_item = 2 + (item.hint and 1 or 0) + (item.icon and 1 or 0)
			local icon_width = item.icon and self.font_size or 0
			item.title_width = text_length_width_estimate(item.title_length, self.font_size)
			item.hint_width = text_length_width_estimate(item.hint_length, self.font_size_hint)
			local estimated_width = item.title_width + item.hint_width + icon_width
				+ (self.item_padding * spacings_in_item)
			if estimated_width > max_width then max_width = estimated_width end
		end

		-- Also check menu title
		local menu_title_width = text_length_width_estimate(menu.title_length, self.font_size)
		if menu_title_width > max_width then max_width = menu_title_width end

		menu.max_width = max_width
	end

	self:update_dimensions()
end

function Menu:update_dimensions()
	-- Coordinates and sizes are of the scrollable area to make
	-- consuming values in rendering and collisions easier. Title drawn above this, so
	-- we need to account for that in max_height and ay position.
	local min_width = state.fullormaxed and options.menu_min_width_fullscreen or options.menu_min_width

	for _, menu in ipairs(self.all) do
		menu.width = round(math.min(math.max(menu.max_width, min_width), display.width * 0.9))
		local title_height = (menu.is_root and menu.title) and self.scroll_step or 0
		local title_top_adjustment = title_height > 0 and self.scroll_step / 2 or 0
		local max_height = round((display.height - title_height) * 0.9)
		local content_height = self.scroll_step * #menu.items
		menu.height = math.min(content_height - self.item_spacing, max_height)
		menu.top = round((display.height - menu.height) / 2 + title_top_adjustment)
		menu.scroll_height = math.max(content_height - menu.height - self.item_spacing, 0)
		self:scroll_to(menu.scroll_y, menu) -- re-applies scroll limits
	end

	local ax = round((display.width - self.current.width) / 2) + self.offset_x
	self:set_coordinates(ax, self.current.top, ax + self.current.width, self.current.top + self.current.height)
end

function Menu:reset_navigation()
	local menu = self.current

	-- Reset indexes and scroll
	self:select_index(menu.selected_index or (menu.items and #menu.items > 0 and 1 or nil))
	self:scroll_to(menu.scroll_y)

	-- Walk up the parent menu chain and activate items that lead to current menu
	local parent = menu.parent_menu
	while parent do
		parent.selected_index = itable_index_of(parent.items, menu)
		menu, parent = parent, parent.parent_menu
	end

	request_render()
end

function Menu:set_offset_x(offset)
	local delta = offset - self.offset_x
	self.offset_x = offset
	self:set_coordinates(self.ax + delta, self.ay, self.bx + delta, self.by)
end

function Menu:fadeout(callback) self:tween_property('opacity', 1, 0, callback) end

function Menu:get_item_index_below_cursor()
	local menu = self.current
	if #menu.items < 1 or self.proximity_raw > 0 then return nil end
	return math.max(1, math.min(math.ceil((cursor.y - self.ay + menu.scroll_y) / self.scroll_step), #menu.items))
end

function Menu:get_first_active_index(menu)
	menu = menu or self.current
	for index, item in ipairs(self.current.items) do
		if item.active then return index end
	end
end

---@param pos? number
---@param menu? MenuStack
function Menu:scroll_to(pos, menu)
	menu = menu or self.current
	menu.scroll_y = math.max(math.min(pos or 0, menu.scroll_height), 0)
	request_render()
end

---@param index? integer
---@param menu? MenuStack
function Menu:scroll_to_index(index, menu)
	menu = menu or self.current
	if (index and index >= 1 and index <= #menu.items) then
		self:scroll_to(round((self.scroll_step * (index - 1)) - ((menu.height - self.scroll_step) / 2)), menu)
	end
end

---@param index? integer
---@param menu? MenuStack
function Menu:select_index(index, menu)
	menu = menu or self.current
	menu.selected_index = (index and index >= 1 and index <= #menu.items) and index or nil
	request_render()
end

---@param value? any
---@param menu? MenuStack
function Menu:select_value(value, menu)
	menu = menu or self.current
	local index = itable_find(menu.items, function(_, item) return item.value == value end)
	self:select_index(index, 5)
end

---@param menu? MenuStack
function Menu:deactivate_items(menu)
	menu = menu or self.current
	for _, item in ipairs(menu.items) do item.active = false end
	request_render()
end

---@param index? integer
---@param menu? MenuStack
function Menu:activate_index(index, menu)
	menu = menu or self.current
	if index and index >= 1 and index <= #menu.items then menu.items[index].active = true end
	request_render()
end

---@param index? integer
---@param menu? MenuStack
function Menu:activate_unique_index(index, menu)
	self:deactivate_items(menu)
	self:activate_index(index, menu)
end

---@param value? any
---@param menu? MenuStack
function Menu:activate_value(value, menu)
	menu = menu or self.current
	self:activate_index(itable_find(menu.items, function(_, item) return item.value == value end), menu)
end

---@param value? any
---@param menu? MenuStack
function Menu:activate_unique_value(value, menu)
	menu = menu or self.current
	self:activate_unique_index(itable_find(menu.items, function(_, item) return item.value == value end), menu)
end

---@param id string
function Menu:activate_submenu(id)
	local submenu = self.by_id[id]
	if submenu then
		self.current = submenu
		request_render()
	else
		msg.error(string.format('Requested submenu id "%s" doesn\'t exist', id))
	end
	self:reset_navigation()
end

---@param index? integer
---@param menu? MenuStack
function Menu:delete_index(index, menu)
	menu = menu or self.current
	if (index and index >= 1 and index <= #menu.items) then
		table.remove(menu.items, index)
		self:update_content_dimensions()
		self:scroll_to_index(menu.selected_index, menu)
	end
end

---@param value? any
---@param menu? MenuStack
function Menu:delete_value(value, menu)
	menu = menu or self.current
	local index = itable_find(menu.items, function(_, item) return item.value == value end)
	self:delete_index(index)
end

---@param menu? MenuStack
function Menu:prev(menu)
	menu = menu or self.current
	menu.selected_index = math.max(menu.selected_index and menu.selected_index - 1 or #menu.items, 1)
	self:scroll_to_index(menu.selected_index, menu)
end

---@param menu? MenuStack
function Menu:next(menu)
	menu = menu or self.current
	menu.selected_index = math.min(menu.selected_index and menu.selected_index + 1 or 1, #menu.items)
	self:scroll_to_index(menu.selected_index, menu)
end

function Menu:back()
	local menu = self.current
	local parent = menu.parent_menu

	if not parent then return self:close() end

	menu.selected_index = nil
	self.current = parent
	self:update_dimensions()
	self:tween(self.offset_x - menu.width / 2, 0, function(offset) self:set_offset_x(offset) end)
	self.opacity = 1 -- in case tween above canceled fade in animation
end

---@param opts? {keep_open?: boolean, preselect_submenu_item?: boolean}
function Menu:open_selected_item(opts)
	opts = opts or {}
	local menu = self.current
	if menu.selected_index then
		local item = menu.items[menu.selected_index]
		-- Is submenu
		if item.items then
			self.current = item
			if opts.preselect_submenu_item then
				item.selected_index = #item.items > 0 and 1 or nil
			end
			self:update_dimensions()
			self:tween(self.offset_x + menu.width / 2, 0, function(offset) self:set_offset_x(offset) end)
			self.opacity = 1 -- in case tween above canceled fade in animation
		else
			self.callback(item.value)
			if not item.keep_open and not opts.keep_open then self:close() end
		end
	end
end

function Menu:open_selected_item_soft() self:open_selected_item({keep_open = true}) end
function Menu:open_selected_item_preselect() self:open_selected_item({preselect_submenu_item = true}) end
function Menu:select_item_below_cursor() self.current.selected_index = self:get_item_index_below_cursor() end

function Menu:on_display() self:update_dimensions() end
function Menu:on_prop_fullormaxed() self:update_content_dimensions() end

function Menu:on_global_mbtn_left_down()
	if self.proximity_raw == 0 then
		self:select_item_below_cursor()
		self:open_selected_item({preselect_submenu_item = false})
	else
		if cursor.x < self.ax then self:back()
		else self:close() end
	end
end

function Menu:on_global_mouse_move()
	if self.proximity_raw == 0 then self:select_item_below_cursor()
	else self.current.selected_index = nil end
	request_render()
end

function Menu:on_wheel_up()
	self:scroll_to(self.current.scroll_y - self.scroll_step)
	self:on_global_mouse_move() -- selects item below cursor
	request_render()
end

function Menu:on_wheel_down()
	self:scroll_to(self.current.scroll_y + self.scroll_step)
	self:on_global_mouse_move() -- selects item below cursor
	request_render()
end

function Menu:on_pgup()
	local menu = self.current
	local items_per_page = round((menu.height / self.scroll_step) * 0.4)
	local paged_index = (menu.selected_index and menu.selected_index or #menu.items) - items_per_page
	menu.selected_index = math.min(math.max(1, paged_index), #menu.items)
	if menu.selected_index > 0 then self:scroll_to_index(menu.selected_index) end
end

function Menu:on_pgdwn()
	local menu = self.current
	local items_per_page = round((menu.height / self.scroll_step) * 0.4)
	local paged_index = (menu.selected_index and menu.selected_index or 1) + items_per_page
	menu.selected_index = math.min(math.max(1, paged_index), #menu.items)
	if menu.selected_index > 0 then self:scroll_to_index(menu.selected_index) end
end

function Menu:on_home()
	self.current.selected_index = math.min(1, #self.current.items)
	if self.current.selected_index > 0 then self:scroll_to_index(self.current.selected_index) end
end

function Menu:on_end()
	self.current.selected_index = #self.current.items
	if self.current.selected_index > 0 then self:scroll_to_index(self.current.selected_index) end
end

function Menu:destroy()
	Element.destroy(self)
	self:disable_key_bindings()
	Elements.curtain:fadeout()
	call_me_maybe(self.opts.on_close)
end

function Menu:add_key_binding(key, name, fn, flags)
	self.key_bindings[#self.key_bindings + 1] = name
	mp.add_forced_key_binding(key, name, fn, flags)
end

function Menu:enable_key_bindings()
	-- The `mp.set_key_bindings()` method would be easier here, but that
	-- doesn't support 'repeatable' flag, so we are stuck with this monster.
	self:add_key_binding('up', 'menu-prev1', self:create_action('prev'), 'repeatable')
	self:add_key_binding('down', 'menu-next1', self:create_action('next'), 'repeatable')
	self:add_key_binding('left', 'menu-back1', self:create_action('back'))
	self:add_key_binding('right', 'menu-select1', self:create_action('open_selected_item_preselect'))
	self:add_key_binding('shift+right', 'menu-select-soft1', self:create_action('open_selected_item_soft'))
	self:add_key_binding('shift+mbtn_left', 'menu-select-soft', self:create_action('open_selected_item_soft'))

	if options.menu_wasd_navigation then
		self:add_key_binding('w', 'menu-prev2', self:create_action('prev'), 'repeatable')
		self:add_key_binding('a', 'menu-back2', self:create_action('back'))
		self:add_key_binding('s', 'menu-next2', self:create_action('next'), 'repeatable')
		self:add_key_binding('d', 'menu-select2', self:create_action('open_selected_item_preselect'))
		self:add_key_binding('shift+d', 'menu-select-soft2', self:create_action('open_selected_item_soft'))
	end

	if options.menu_hjkl_navigation then
		self:add_key_binding('h', 'menu-back3', self:create_action('back'))
		self:add_key_binding('j', 'menu-next3', self:create_action('next'), 'repeatable')
		self:add_key_binding('k', 'menu-prev3', self:create_action('prev'), 'repeatable')
		self:add_key_binding('l', 'menu-select3', self:create_action('open_selected_item_preselect'))
		self:add_key_binding('shift+l', 'menu-select-soft3', self:create_action('open_selected_item_soft'))
	end

	self:add_key_binding('mbtn_back', 'menu-back-alt3', self:create_action('back'))
	self:add_key_binding('bs', 'menu-back-alt4', self:create_action('back'))
	self:add_key_binding('enter', 'menu-select-alt3', self:create_action('open_selected_item_preselect'))
	self:add_key_binding('kp_enter', 'menu-select-alt4', self:create_action('open_selected_item_preselect'))
	self:add_key_binding('shift+enter', 'menu-select-alt5', self:create_action('open_selected_item_soft'))
	self:add_key_binding('shift+kp_enter', 'menu-select-alt6', self:create_action('open_selected_item_soft'))
	self:add_key_binding('esc', 'menu-close', self:create_action('close'))
	self:add_key_binding('pgup', 'menu-page-up', self:create_action('on_pgup'))
	self:add_key_binding('pgdwn', 'menu-page-down', self:create_action('on_pgdwn'))
	self:add_key_binding('home', 'menu-home', self:create_action('on_home'))
	self:add_key_binding('end', 'menu-end', self:create_action('on_end'))
end

function Menu:disable_key_bindings()
	for _, name in ipairs(self.key_bindings) do mp.remove_key_binding(name) end
	self.key_bindings = {}
end

function Menu:create_action(name)
	return function(...) self:maybe(name, ...) end
end

function Menu:render()
	local ass = assdraw.ass_new()
	local opacity = options.menu_opacity * self.opacity
	local spacing = self.item_padding
	local icon_size = self.font_size

	function draw_menu(menu, x, y, opacity)
		local ax, ay, bx, by = x, y, x + menu.width, y + menu.height
		local draw_title = menu.is_root and menu.title
		local scroll_clip = '\\clip(0,' .. ay .. ',' .. display.width .. ',' .. by .. ')'
		local start_index = math.floor(menu.scroll_y / self.scroll_step) + 1
		local end_index = math.ceil((menu.scroll_y + menu.height) / self.scroll_step)
		local selected_index = menu.selected_index or -1

		-- Background
		ass:rect(ax, ay - (draw_title and self.item_height or 0) - 2, bx, by + 2, {
			color = options.color_background, opacity = opacity, radius = 4,
		})

		for index = start_index, end_index, 1 do
			local item = menu.items[index]
			local next_item = menu.items[index + 1]
			local is_highlighted = selected_index == index or item.active
			local next_is_active = next_item and next_item.active
			local next_is_highlighted = selected_index == index + 1 or next_is_active

			if not item then break end

			local item_ay = ay - menu.scroll_y + self.scroll_step * (index - 1)
			local item_by = item_ay + self.item_height
			local item_center_y = item_ay + (self.item_height / 2)
			local item_clip = (item_ay < ay or item_by > by) and scroll_clip or nil
			-- controls title & hint clipping proportional to the ratio of their widths
			local title_hint_ratio = item.hint and item.title_width / (item.title_width + item.hint_width) or 1
			local content_ax, content_bx = ax + spacing, bx - spacing
			local font_color = item.active and options.color_foreground_text or options.color_background_text
			local shadow_color = item.active and options.color_foreground or options.color_background

			-- Separator
			local separator_ay = item.separator and item_by - 1 or item_by
			local separator_by = item_by + (item.separator and 2 or 1)
			if is_highlighted then separator_ay = item_by + 1 end
			if next_is_highlighted then separator_by = item_by end
			if separator_by - separator_ay > 0 and item_by < by then
				ass:rect(ax + spacing / 2, separator_ay, bx - spacing / 2, separator_by, {
					color = options.color_foreground, opacity = opacity * 0.13,
				})
			end

			-- Highlight
			local highlight_opacity = 0 + (item.active and 0.8 or 0) + (selected_index == index and 0.15 or 0)
			if highlight_opacity > 0 then
				ass:rect(ax + 2, item_ay, bx - 2, item_by, {
					radius = 2, color = options.color_foreground, opacity = highlight_opacity * self.opacity,
					clip = item_clip,
				})
			end

			-- Icon
			if item.icon then
				ass:icon(content_bx - (icon_size / 2), item_center_y, icon_size * 1.5, item.icon, {
					color = font_color, opacity = self.opacity, clip = item_clip,
					shadow = 1, shadow_color = shadow_color,
				})
				content_bx = content_bx - icon_size - spacing
			end

			local title_hint_cut_x = content_ax + (content_bx - content_ax - spacing) * title_hint_ratio

			-- Hint
			if item.hint then
				item.ass_safe_hint = item.ass_safe_hint or ass_escape(item.hint)
				local clip = '\\clip(' .. round(title_hint_cut_x + spacing / 2) .. ',' ..
					math.max(item_ay, ay) .. ',' .. bx .. ',' .. math.min(item_by, by) .. ')'
				ass:txt(content_bx, item_center_y, 6, item.ass_safe_hint, {
					size = self.font_size_hint, color = font_color, wrap = 2, opacity = 0.5 * opacity, clip = clip,
					shadow = 1, shadow_color = shadow_color,
				})
			end

			-- Title
			if item.title then
				item.ass_safe_title = item.ass_safe_title or ass_escape(item.title)
				local clip = '\\clip(' .. ax .. ',' .. math.max(item_ay, ay) .. ','
					.. round(title_hint_cut_x - spacing / 2) .. ',' .. math.min(item_by, by) .. ')'
				ass:txt(content_ax, item_center_y, 4, item.ass_safe_title, {
					size = self.font_size, color = font_color, italic = item.italic, bold = item.bold, wrap = 2,
					opacity = self.opacity * (item.muted and 0.5 or 1), clip = clip,
					shadow = 1, shadow_color = shadow_color,
				})
			end
		end

		-- Menu title
		if draw_title then
			local title_ay = ay - self.item_height
			local title_height = self.item_height - 3
			menu.ass_safe_title = menu.ass_safe_title or ass_escape(menu.title)

			-- Background
			ass:rect(ax + 2, title_ay, bx - 2, title_ay + title_height, {
				color = options.color_foreground, opacity = opacity * 0.55, radius = 2,
			})

			-- Title
			ass:txt(ax + menu.width / 2, title_ay + (title_height / 2), 5, menu.title, {
				size = self.font_size, bold = true, color = options.color_background, wrap = 2, opacity = opacity,
				clip = '\\clip(' .. ax .. ',' .. title_ay .. ',' .. bx .. ',' .. ay .. ')',
			})
		end

		-- Scrollbar
		if menu.scroll_height > 0 then
			local groove_height = menu.height - 2
			local thumb_height = math.max((menu.height / (menu.scroll_height + menu.height)) * groove_height, 40)
			local thumb_y = ay + 1 + ((menu.scroll_y / menu.scroll_height) * (groove_height - thumb_height))
			ass:rect(bx - 3, thumb_y, bx - 1, thumb_y + thumb_height, {
				color = options.color_foreground, opacity = opacity * 0.8,
			})
		end
	end

	-- Main menu
	draw_menu(self.current, self.ax, self.ay, opacity)

	-- Parent menus
	local parent_menu = self.current.parent_menu
	local parent_offset_x = self.ax
	local parent_opacity_factor = options.menu_parent_opacity
	local menu_gap = 2

	while parent_menu do
		parent_offset_x = parent_offset_x - parent_menu.width - menu_gap
		draw_menu(parent_menu, parent_offset_x, parent_menu.top, parent_opacity_factor * opacity)
		parent_opacity_factor = parent_opacity_factor * parent_opacity_factor
		parent_menu = parent_menu.parent_menu
	end

	-- Selected menu
	local selected_menu = self.current.items[self.current.selected_index]

	if selected_menu and selected_menu.items then
		draw_menu(selected_menu, self.bx + menu_gap, selected_menu.top, options.menu_parent_opacity * opacity)
	end

	return ass
end

--[[ Speed ]]

---@alias Dragging { start_time: number; start_x: number; distance: number; speed_distance: number; start_speed: number; }

---@class Speed : Element
local Speed = class(Element)

---@param props? ElementProps
function Speed:new(props) return Class.new(self, props) --[[@as Speed]] end
function Speed:init(props)
	Element.init(self, 'speed', props)

	self.width = 0
	self.height = 0
	self.notches = 10
	self.notch_every = 0.1
	---@type number
	self.notch_spacing = nil
	---@type number
	self.font_size = nil
	---@type Dragging|nil
	self.dragging = nil
end

function Speed:get_visibility()
	-- We force inherit, because I want to see speed value when peeking timeline
	local this_visibility = Element.get_visibility(self)
	return Elements.timeline.proximity_raw ~= 0
		and math.max(Elements.timeline.proximity, this_visibility) or this_visibility
end

function Speed:on_coordinates()
	self.height, self.width = self.by - self.ay, self.bx - self.ax
	self.notch_spacing = self.width / (self.notches + 1)
	self.font_size = round(self.height * 0.48 * options.font_scale)
end

function Speed:speed_step(speed, up)
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
end

function Speed:on_mbtn_left_down()
	self:tween_stop() -- Stop and cleanup possible ongoing animations
	self.dragging = {
		start_time = mp.get_time(),
		start_x = cursor.x,
		distance = 0,
		speed_distance = 0,
		start_speed = state.speed,
	}
end

function Speed:on_global_mouse_move()
	if not self.dragging then return end

	self.dragging.distance = cursor.x - self.dragging.start_x
	self.dragging.speed_distance = (-self.dragging.distance / self.notch_spacing * self.notch_every)

	local speed_current = state.speed
	local speed_drag_current = self.dragging.start_speed + self.dragging.speed_distance
	speed_drag_current = math.min(math.max(speed_drag_current, 0.01), 100)
	local drag_dir_up = speed_drag_current > speed_current

	local speed_step_next = speed_current
	local speed_drag_diff = math.abs(speed_drag_current - speed_current)
	while math.abs(speed_step_next - speed_current) < speed_drag_diff do
		speed_step_next = self:speed_step(speed_step_next, drag_dir_up)
	end
	local speed_step_prev = self:speed_step(speed_step_next, not drag_dir_up)

	local speed_new = speed_step_prev
	local speed_next_diff = math.abs(speed_drag_current - speed_step_next)
	local speed_prev_diff = math.abs(speed_drag_current - speed_step_prev)
	if speed_next_diff < speed_prev_diff then
		speed_new = speed_step_next
	end

	if speed_new ~= speed_current then
		mp.set_property_native('speed', speed_new)
	end
end

function Speed:on_mbtn_left_up()
	-- Reset speed on short clicks
	if self.dragging and math.abs(self.dragging.distance) < 6 and mp.get_time() - self.dragging.start_time < 0.15 then
		mp.set_property_native('speed', 1)
	end
end

function Speed:on_global_mbtn_left_up()
	self.dragging = nil
	request_render()
end

function Speed:on_global_mouse_leave()
	self.dragging = nil
	request_render()
end

function Speed:on_wheel_up() mp.set_property_native('speed', self:speed_step(state.speed, true)) end
function Speed:on_wheel_down() mp.set_property_native('speed', self:speed_step(state.speed, false)) end

function Speed:render()
	if not self.dragging and (Elements.curtain.opacity > 0) then return end

	local visibility = self:get_visibility()
	local opacity = self.dragging and 1 or visibility

	if opacity <= 0 then return end

	local ass = assdraw.ass_new()

	-- Background
	ass:rect(self.ax, self.ay, self.bx, self.by, {
		color = options.color_background, radius = 2, opacity = opacity * 0.6,
	})

	-- Coordinates
	local ax, ay = self.ax, self.ay
	local bx, by = self.bx, ay + self.height
	local half_width = (self.width / 2)
	local half_x = ax + half_width

	-- Notches
	local speed_at_center = state.speed
	if self.dragging then
		speed_at_center = self.dragging.start_speed + self.dragging.speed_distance
		speed_at_center = math.min(math.max(speed_at_center, 0.01), 100)
	end
	local nearest_notch_speed = round(speed_at_center / self.notch_every) * self.notch_every
	local nearest_notch_x = half_x + (((nearest_notch_speed - speed_at_center) / self.notch_every) * self.notch_spacing)
	local guide_size = math.floor(self.height / 7.5)
	local notch_by = by - guide_size
	local notch_ay_big = ay + round(self.font_size * 1.1)
	local notch_ay_medium = notch_ay_big + ((notch_by - notch_ay_big) * 0.2)
	local notch_ay_small = notch_ay_big + ((notch_by - notch_ay_big) * 0.4)
	local from_to_index = math.floor(self.notches / 2)

	for i = -from_to_index, from_to_index do
		local notch_speed = nearest_notch_speed + (i * self.notch_every)

		if notch_speed >= 0 and notch_speed <= 100 then
			local notch_x = nearest_notch_x + (i * self.notch_spacing)
			local notch_thickness = 1
			local notch_ay = notch_ay_small
			if (notch_speed % (self.notch_every * 10)) < 0.00000001 then
				notch_ay = notch_ay_big
				notch_thickness = 1.5
			elseif (notch_speed % (self.notch_every * 5)) < 0.00000001 then
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
		size = self.font_size, color = options.color_background_text,
		border = 1, border_color = options.color_background, opacity = opacity,
	})

	return ass
end

--[[ Button ]]

---@alias ButtonProps {icon: string; on_click: function; anchor_id?: string; active?: boolean; foreground?: string; background?: string; tooltip?: string}

---@class Button : Element
local Button = class(Element)

---@param id string
---@param props ButtonProps
function Button:new(id, props) return Class.new(self, id, props) --[[@as Button]] end
function Button:init(id, props)
	self.icon = props.icon
	self.active = props.active
	self.tooltip = props.tooltip
	self.foreground = props.foreground or options.color_foreground
	self.background = props.background or options.color_background
	---@type fun()
	self.on_click = props.on_click
	Element.init(self, id, props)
end

function Button:on_coordinates() self.font_size = round((self.by - self.ay) * 0.7) end
function Button:on_mbtn_left_down()
	-- We delay the callback to next tick, otherwise we are risking race
	-- conditions as we are in the middle of event dispatching.
	-- For example, handler might add a menu to the end of the element stack, and that
	-- than picks up this click even we are in right now, and instantly closes itself.
	mp.add_timeout(0.01, self.on_click)
end

function Button:render()
	local visibility = self:get_visibility()
	if visibility <= 0 then return end

	local ass = assdraw.ass_new()
	local is_hover = self.proximity_raw == 0
	local is_hover_or_active = is_hover or self.active
	local foreground = self.active and self.background or self.foreground
	local background = self.active and self.foreground or self.background

	-- Background
	if is_hover_or_active then
		ass:rect(self.ax, self.ay, self.bx, self.by, {
			color = self.active and background or foreground, radius = 2,
			opacity = visibility * (self.active and 0.8 or 0.3),
		})
	end

	-- Tooltip on hover
	if is_hover and self.tooltip then ass:tooltip(self, self.tooltip) end

	-- Icon
	local x, y = round(self.ax + (self.bx - self.ax) / 2), round(self.ay + (self.by - self.ay) / 2)
	ass:icon(x, y, self.font_size, self.icon, {
		color = foreground, border = self.active and 0 or 1, border_color = background, opacity = visibility,
	})

	return ass
end

--[[ CycleButton ]]

---@alias CycleState {value: any; icon: string; active?: boolean}
---@alias CycleButtonProps {prop: string; states: CycleState[]; anchor_id?: string; tooltip?: string}

---@class CycleButton : Button
local CycleButton = class(Button)

---@param id string
---@param props CycleButtonProps
function CycleButton:new(id, props) return Class.new(self, id, props) --[[@as CycleButton]] end
function CycleButton:init(id, props)
	self.prop = props.prop
	self.states = props.states

	Button.init(self, id, props)

	self.icon = self.states[1].icon
	self.active = self.states[1].active
	self.current_state_index = 1
	self.on_click = function()
		local new_state = self.states[self.current_state_index + 1] or self.states[1]
		mp.set_property(self.prop, new_state.value)
	end

	self.handle_change = function(name, value)
		local index = itable_find(self.states, function(state) return state.value == value end)
		self.current_state_index = index or 1
		self.icon = self.states[self.current_state_index].icon
		self.active = self.states[self.current_state_index].active
		request_render()
	end

	mp.observe_property(self.prop, 'string', self.handle_change)
end

function CycleButton:destroy()
	Button.destroy(self)
	mp.unobserve_property(self.handle_change)
end

--[[ WindowBorder ]]

---@class WindowBorder : Element
local WindowBorder = class(Element)

function WindowBorder:new() return Class.new(self) --[[@as WindowBorder]] end
function WindowBorder:init()
	Element.init(self, 'window_border')
	self.ignores_menu = true
	self.size = 0
end

function WindowBorder:decide_enabled()
	self.enabled = options.window_border_size > 0 and not state.fullormaxed and not state.border
	self.size = self.enabled and options.window_border_size or 0
end

function WindowBorder:on_prop_border() self:decide_enabled() end
function WindowBorder:on_prop_fullormaxed() self:decide_enabled() end

function WindowBorder:render()
	if self.size > 0 then
		local ass = assdraw.ass_new()
		local clip = '\\iclip(' .. self.size .. ',' .. self.size .. ',' ..
			(display.width - self.size) .. ',' .. (display.height - self.size) .. ')'
		ass:rect(0, 0, display.width, display.height, {
			color = options.color_background, clip = clip, opacity = options.window_border_opacity,
		})
		return ass
	end
end

--[[ PauseIndicator ]]

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
		ass:rect(0, 0, display.width, display.height, {color = options.color_background, opacity = self.opacity * 0.3})
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

--[[ Timeline ]]

---@class Timeline : Element
local Timeline = class(Element)

function Timeline:new() return Class.new(self) --[[@as Timeline]] end
function Timeline:init()
	Element.init(self, 'timeline')
	self.pressed = false
	self.size_max = 0
	self.size_min = 0
	self.size_min_override = options.timeline_start_hidden and 0 or nil
	self.font_size = 0
	self.top_border = options.timeline_border
end

function Timeline:get_visibility()
	return Elements.controls
		and math.max(Elements.controls.proximity, Element.get_visibility(self)) or Element.get_visibility(self)
end

function Timeline:decide_enabled()
	self.enabled = state.duration and state.duration > 0 and state.time
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
end

function Timeline:get_time_at_x(x)
	-- line width 1 for timeline_style=bar so mouse input can go all the way from 0 to 1 progress
	local line_width = (options.timeline_style == 'line' and self:get_effective_line_width() or 1)
	local time_width = self.width - line_width
	local progress_x = x - self.ax - line_width / 2
	local progress = math.max(0, math.min(progress_x / time_width, 1))
	return state.duration * progress
end

function Timeline:set_from_cursor()
	-- add 0.5 to be in the middle of the pixel
	mp.commandv('seek', self:get_time_at_x(cursor.x + 0.5), 'absolute+exact')
end

function Timeline:on_mbtn_left_down()
	self.pressed = true
	self:set_from_cursor()
end

function Timeline:on_prop_duration() self:decide_enabled() end
function Timeline:on_prop_time() self:decide_enabled() end
function Timeline:on_prop_border() self:update_dimensions() end
function Timeline:on_prop_fullormaxed() self:update_dimensions() end
function Timeline:on_display() self:update_dimensions() end
function Timeline:on_global_mbtn_left_up() self.pressed = false end
function Timeline:on_global_mouse_leave() self.pressed = false end
function Timeline:on_global_mouse_move()
	if self.pressed then self:set_from_cursor() end
end
function Timeline:on_wheel_up() mp.commandv('seek', options.timeline_step) end
function Timeline:on_wheel_down() mp.commandv('seek', -options.timeline_step) end

function Timeline:render()
	if self.size_max == 0 then return end

	local size_min = self:get_effective_size_min()
	local size = self:get_effective_size()

	if size < 1 then return end

	local ass = assdraw.ass_new()

	-- Text opacity rapidly drops to 0 just before it starts overflowing, or before it reaches timeline.size_min
	local hide_text_below = math.max(self.font_size * 0.7, size_min * 2)
	local hide_text_ramp = hide_text_below / 2
	local text_opacity = math.max(math.min(size - hide_text_below, hide_text_ramp), 0) / hide_text_ramp

	local spacing = math.max(math.floor((self.size_max - self.font_size) / 2.5), 4)
	local progress = state.time / state.duration
	local is_line = options.timeline_style == 'line'

	-- Foreground & Background bar coordinates
	local bax, bay, bbx, bby = self.ax, self.by - size - self.top_border, self.bx, self.by
	local fax, fay, fbx, fby = 0, bay + self.top_border, 0, bby

	local line_width = 0

	if is_line then
		local minimized_fraction = 1 - (size - size_min) / (self.size_max - size_min)
		local width_normal = self:get_effective_line_width()
		local max_min_width_delta = size_min > 0
			and width_normal - width_normal * options.timeline_line_width_minimized_scale
			or 0
		line_width = width_normal - (max_min_width_delta * minimized_fraction)
		local time_width = self.width - line_width
		fax = bax + time_width * progress
		fbx = fax + line_width
	else
		fax = bax
		fbx = bax + self.width * progress
	end

	local time_x = bax + line_width / 2
	local time_width = self.width - line_width
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
	ass:rect(fax, fay, fbx, fby, {opacity = options.timeline_opacity})

	-- Custom ranges
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

	-- Chapters
	if (options.timeline_chapters ~= 'never'
		and (state.chapters ~= nil and #state.chapters > 0 or state.ab_loop_a or state.ab_loop_b)
		) then
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
			chapter_height = math.min(self.size_max / 3, size)
			chapter_y = fay + (chapter_height / 2)
		elseif options.timeline_chapters == 'lines-bottom' then
			chapter_height = math.min(self.size_max / 3, size)
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
				local opts = {
					color = options.color_foreground,
					clip = dots and '\\iclip(' .. foreground_coordinates .. ')' or nil,
					opacity = options.timeline_chapters_opacity,
				}
				
				if dots then
					local cx, dx = math.max(ax, fax), math.min(bx, fbx)
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
					local cx, dx = math.max(ax, fax), math.min(bx, fbx)
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
					if not chapter._uosc_used_as_range_point then draw_chapter(chapter.time) end
				end
			end

			if state.ab_loop_a and state.ab_loop_a > 0 then draw_chapter(state.ab_loop_a) end
			if state.ab_loop_b and state.ab_loop_b > 0 then draw_chapter(state.ab_loop_b) end
		end
	end

	-- Cached ranges
	if config.cached_ranges and state.cached_ranges then
		local range_height = math.max(math.floor(math.min(self.size_max / 10, foreground_size / 2)), 1)
		local range_ay = fby - range_height
		-- Fully include the start and end pixels of the time range
		local left_ax = math.floor(time_x)
		local right_bx = math.ceil(time_x + time_width)
		local cache_width = right_bx - left_ax

		for _, range in ipairs(state.cached_ranges) do
			local range_start = math.max(type(range['start']) == 'number' and range['start'] or 0.000001, 0.000001)
			local range_end = math.min(type(range['end']) and range['end'] or state.duration, state.duration)
			ass:rect(
				left_ax + cache_width * (range_start / state.duration), range_ay,
				left_ax + cache_width * (range_end / state.duration), range_ay + range_height,
				{color = config.cached_ranges.color, opacity = config.cached_ranges.opacity}
			)
		end

		-- Visualize padded time area limits
		if (left_ax - bax) > 0 then
			local notch_ay = math.max(range_ay - 2, fay)
			local opts = {color = config.cached_ranges.color, opacity = options.timeline_opacity}
			ass:rect(left_ax - 1, notch_ay, left_ax, bby, opts)
			ass:rect(right_bx, notch_ay, right_bx + 1, bby, opts)
		end
	end

	-- Time values
	if text_opacity > 0 then
		local opts = {size = self.font_size, opacity = math.min(options.timeline_opacity + 0.1, 1) * text_opacity}

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

	-- Hovered time and chapter
	if (self.proximity_raw == 0 or self.pressed) and not (Elements.speed and Elements.speed.dragging) then
		-- add 0.5 to be in the middle of the pixel
		local hovered_seconds = self:get_time_at_x(cursor.x + 0.5)
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
		ass:tooltip(line, format_time(hovered_seconds), {size = self.font_size, offset = 2})

		-- Chapter title
		if chapter_title then
			ass:tooltip(line, chapter_title, {
				offset = 2 + self.font_size * 1.4, size = self.font_size, bold = true,
				text_length_override = chapter_title_width,
			})
		end
	end

	return ass
end

--[[ TopBarButton ]]

---@alias TopBarButtonProps {icon: string; background: string; anchor_id?: string; command: string}

---@class TopBarButton : Element
local TopBarButton = class(Element)

---@param id string
---@param props TopBarButtonProps
function TopBarButton:new(id, props) return Class.new(self, id, props) --[[@as CycleButton]] end
function TopBarButton:init(id, props)
	Element.init(self, id, props)
	self.anchor_id = 'top_bar'
	self.icon = props.icon
	self.background = props.background
	self.command = props.command
end

function TopBarButton:on_mbtn_left_down() mp.command(self.command) end

function TopBarButton:render()
	local visibility = self:get_visibility()
	if visibility <= 0 then return end
	local ass = assdraw.ass_new()

	-- Background on hover
	if self.proximity_raw == 0 then
		ass:rect(self.ax, self.ay, self.bx, self.by, {color = self.background, opacity = visibility})
	end

	local width, height = self.bx - self.ax, self.by - self.ay
	local icon_size = math.min(width, height) * 0.5
	ass:icon(self.ax + width / 2, self.ay + height / 2, icon_size, self.icon, {opacity = visibility, border = 1})

	return ass
end

--[[ TopBar ]]

---@class TopBar : Element
local TopBar = class(Element)

function TopBar:new() return Class.new(self) --[[@as TopBar]] end
function TopBar:init()
	Element.init(self, 'top_bar')
	self.pressed = false
	self.size, self.size_max, self.size_min = 0, 0, 0
	self.icon_size, self.spacing, self.font_size, self.title_bx = 1, 1, 1, 1
	self.size_min_override = options.timeline_start_hidden and 0 or nil
	self.top_border = options.timeline_border

	-- Order aligns from right to left
	self.buttons = {
		TopBarButton:new('tb_close', {icon = 'close', background = '2311e8', command = 'quit'}),
		TopBarButton:new('tb_max', {icon = 'crop_square', background = '222222', command = 'cycle window-maximized'}),
		TopBarButton:new('tb_min', {icon = 'minimize', background = '222222', command = 'cycle window-minimized'}),
	}
end

function TopBar:decide_enabled()
	if options.top_bar == 'no-border' then
		self.enabled = not state.border or state.fullscreen
	else
		self.enabled = options.top_bar == 'always'
	end
	self.enabled = self.enabled and (options.top_bar_controls or options.top_bar_title)
	for _, element in ipairs(self.buttons) do
		element.enabled = self.enabled and options.top_bar_controls
	end
end

function TopBar:update_dimensions()
	self.size = state.fullormaxed and options.top_bar_size_fullscreen or options.top_bar_size
	self.icon_size = round(self.size * 0.5)
	self.spacing = math.ceil(self.size * 0.25)
	self.font_size = math.floor((self.size - (self.spacing * 2)) * options.font_scale)
	self.button_width = round(self.size * 1.15)
	self.ay = Elements.window_border.size
	self.bx = display.width - Elements.window_border.size
	self.by = self.size + Elements.window_border.size
	self.title_bx = self.bx - (options.top_bar_controls and (self.button_width * 3) or 0)
	self.ax = options.top_bar_title and Elements.window_border.size or self.title_bx

	local button_bx = self.bx
	for _, element in pairs(self.buttons) do
		element.ax, element.bx = button_bx - self.button_width, button_bx
		element.ay, element.by = self.ay, self.by
		button_bx = button_bx - self.button_width
	end
end

function TopBar:on_prop_border()
	self:decide_enabled()
	self:update_dimensions()
end

function TopBar:on_prop_fullscreen()
	self:decide_enabled()
	self:update_dimensions()
end

function TopBar:on_prop_maximized()
	self:decide_enabled()
	self:update_dimensions()
end

function TopBar:on_display() self:update_dimensions() end

function TopBar:render()
	local visibility = self:get_visibility()
	if visibility <= 0 then return end
	local ass = assdraw.ass_new()

	-- Window title
	if options.top_bar_title and (state.media_title or state.has_playlist) then
		local max_bx = self.title_bx - self.spacing
		local text = state.media_title or 'n/a'
		if state.has_playlist then
			text = string.format('%d/%d - ', state.playlist_pos, state.playlist_count) .. text
		end

		-- Background
		local padding = self.font_size / 2
		local bg_margin = math.floor((self.size - self.font_size) / 4)
		local bg_ax = self.ax + bg_margin
		local bg_bx = math.min(max_bx, self.ax + text_width_estimate(text, self.font_size) + padding * 2)
		ass:rect(bg_ax, self.ay + bg_margin, bg_bx, self.by - bg_margin, {
			color = options.color_background, opacity = visibility * 0.8, radius = 2,
		})

		-- Text
		ass:txt(bg_ax + padding, self.ay + (self.size / 2), 4, text, {
			size = self.font_size, wrap = 2, color = 'FFFFFF', border = 1, border_color = '000000', opacity = visibility,
			clip = string.format('\\clip(%d, %d, %d, %d)', self.ax, self.ay, max_bx, self.by),
		})
	end

	return ass
end

--[[ Controls ]]

-- `scale` - `options.controls_size` scale factor.
-- `ratio` - Width/height ratio of a static or dynamic element.
-- `ratio_min` Min ratio for 'dynamic' sized element.
-- `skip` - Whether it should be skipped, determined during layout phase.
---@alias ControlItem {element?: Element; kind: string; sizing: 'space' | 'static' | 'dynamic'; scale: number; ratio?: number; ratio_min?: number; hide: boolean;}

---@class Controls : Element
local Controls = class(Element)

function Controls:new() return Class.new(self) --[[@as Controls]] end
function Controls:init()
	Element.init(self, 'controls')
	---@type ControlItem[]
	self.controls = {}
	self:serialize()
end

function Controls:serialize()
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
			local prop = (name == 'has_audio' or name == 'has_playlist') and name or 'is_' .. name
			if state[prop] ~= value then return false end
		end
		return true
	end)

	-- Create controls
	self.controls = {}
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
			self.controls[#self.controls + 1] = {kind = kind, sizing = 'space'}
		elseif kind == 'gap' then
			self.controls[#self.controls + 1] = {
				kind = kind, sizing = 'dynamic', scale = 1, ratio = params[1] or 0.3, ratio_min = 0,
			}
		elseif kind == 'command' then
			if #params ~= 2 then
				mp.error(string.format(
					'command button needs 2 parameters, %d received: %s',
					#params, table.concat(params, '/')
				))
			else
				local element = Button:new('control_' .. i, {
					icon = params[1],
					anchor_id = 'controls',
					on_click = function() mp.command(params[2]) end,
					tooltip = tooltip,
				})
				self.controls[#self.controls + 1] = {
					kind = kind, element = element, sizing = 'static', scale = 1, ratio = 1,
				}
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

				local element = CycleButton:new('control_' .. i, {
					prop = params[2], anchor_id = 'controls', states = states, tooltip = tooltip,
				})
				self.controls[#self.controls + 1] = {
					kind = kind, element = element, sizing = 'static', scale = 1, ratio = 1,
				}
			end
		elseif kind == 'speed' then
			if not Elements.speed then
				local element = Speed:new({anchor_id = 'controls'})
				self.controls[#self.controls + 1] = {
					kind = kind, element = element,
					sizing = 'dynamic', scale = params[1] or 1.3, ratio = 3.5, ratio_min = 2,
				}
			else
				msg.error('there can only be 1 speed slider')
			end
		end
	end

	self:update_dimensions()
	Elements:update_proximities()
	Elements:trigger('controls_reflow')
end

function Controls:clean_controls()
	for _, control in ipairs(self.controls) do
		if control.element then Elements:remove(control.element) end
	end
	self.controls = {}
	request_render()
end

function Controls:get_visibility()
	local timeline_is_hovered = Elements.timeline.enabled and Elements.timeline.proximity_raw == 0
	return (Elements.speed and Elements.speed.dragging) and 1 or timeline_is_hovered
		and -1 or Element.get_visibility(self)
end

function Controls:update_dimensions()
	local window_border = Elements.window_border.size
	local size = state.fullormaxed and options.controls_size_fullscreen or options.controls_size
	local spacing = options.controls_spacing
	local margin = options.controls_margin

	-- Container
	self.bx = display.width - window_border - margin
	self.by = (Elements.timeline.enabled and Elements.timeline.ay or display.height - window_border) - margin
	self.ax, self.ay = window_border + margin, self.by - size

	-- Re-enable all elements
	for c, control in ipairs(self.controls) do
		control.hide = false
		if control.element then control.element.enabled = true end
	end

	-- Controls
	local available_width = self.bx - self.ax
	local statics_width = (#self.controls - 1) * spacing
	local min_content_width = statics_width
	local max_dynamics_width, dynamic_units, spaces = 0, 0, 0

	-- Calculate statics_width, min_content_width, and count spaces
	for c, control in ipairs(self.controls) do
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
		local i = math.ceil(#self.controls / 2 + 0.1)
		for a = 0, #self.controls - 1, 1 do
			i = i + (a * (a % 2 == 0 and 1 or -1))
			local control = self.controls[i]

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
	local current_x = self.ax
	local width_for_dynamics = available_width - statics_width
	local space_width = (width_for_dynamics - max_dynamics_width) / spaces

	for c, control in ipairs(self.controls) do
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
			if element then element:set_coordinates(round(current_x), round(self.by - height), bx, self.by) end
			current_x = bx + spacing
		end
	end

	request_render()
end

function Controls:on_dispositions()
	self:clean_controls()
	self:serialize()
end
function Controls:on_display() self:update_dimensions() end
function Controls:on_prop_border() self:update_dimensions() end
function Controls:on_prop_fullormaxed() self:update_dimensions() end

--[[ MuteButton ]]

---@class MuteButton : Element
local MuteButton = class(Element)
---@param props? ElementProps
function MuteButton:new(props) return Class.new(self, 'volume_mute', props) --[[@as MuteButton]] end
function MuteButton:on_mbtn_left_down() mp.commandv('cycle', 'mute') end
function MuteButton:render()
	local visibility = self:get_visibility()
	if visibility <= 0 then return end
	local ass = assdraw.ass_new()
	local icon_name = state.mute and 'volume_off' or 'volume_up'
	local width = self.bx - self.ax
	ass:icon(self.ax + (width / 2), self.by, width * 0.7, icon_name,
		{border = options.volume_border, opacity = options.volume_opacity * visibility, align = 2}
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
end

function VolumeSlider:set_volume(volume)
	volume = round(volume / options.volume_step) * options.volume_step
	if state.volume == volume then return end
	mp.commandv('set', 'volume', math.max(math.min(volume, state.volume_max), 0))
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
end
function VolumeSlider:on_mbtn_left_down()
	self.pressed = true
	self:set_from_cursor()
end
function VolumeSlider:on_global_mbtn_left_up() self.pressed = false end
function VolumeSlider:on_global_mouse_leave() self.pressed = false end
function VolumeSlider:on_global_mouse_move()
	if self.pressed then self:set_from_cursor() end
end
function VolumeSlider:on_wheel_up() self:set_volume(state.volume + options.volume_step) end
function VolumeSlider:on_wheel_down() self:set_volume(state.volume - options.volume_step) end

function VolumeSlider:render()
	local visibility = self:get_visibility()
	local width, height = self.bx - self.ax, self.by - self.ay
	if width <= 0 or height <= 0 or visibility <= 0 then return end
	local ass = assdraw.ass_new()

	local nudge_y, nudge_size = self.draw_nudge and self.nudge_y or -infinity, self.nudge_size

	-- Background bar coordinates
	local bax, bay, bbx, bby = self.ax, self.ay, self.bx, self.by

	-- Foreground bar coordinates
	local height_without_border = height - (options.volume_border * 2)
	local fax = self.ax + options.volume_border
	local fay = self.ay + (height_without_border * (1 - math.min(state.volume / state.volume_max, 1))) +
		options.volume_border
	local fbx = self.bx - options.volume_border
	local fby = self.by - options.volume_border

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
	local font_size = round(((width * 0.6) - (#volume_string * (width / 20))) * options.font_scale)
	local opacity = math.min(options.volume_opacity + 0.1, 1) * visibility
	if fay < self.by - self.spacing then
		ass:txt(self.ax + (width / 2), self.by - self.spacing, 2, volume_string, {
			size = font_size, color = options.color_foreground_text, opacity = opacity,
			clip = '\\clip(' .. fg_path.scale .. ', ' .. fg_path.text .. ')',
		})
	end
	if fay > self.by - self.spacing - font_size then
		ass:txt(self.ax + (width / 2), self.by - self.spacing, 2, volume_string, {
			size = font_size, color = options.color_background_text, opacity = opacity,
			clip = '\\iclip(' .. fg_path.scale .. ', ' .. fg_path.text .. ')',
		})
	end

	-- Disabled stripes for no audio
	if not state.has_audio then
		-- Create 100 foreground clip path
		local f100ax, f100ay = self.ax + options.volume_border, self.ay + options.volume_border
		local f100bx, f100by = self.bx - options.volume_border, self.by - options.volume_border
		local fg_100_path = make_nudged_path(f100ax, f100ay, f100bx, f100by)

		-- Render stripes
		local stripe_height = 12
		local skew_height = stripe_height
		local colors = {'000000', 'ffffff'}

		for c, color in ipairs(colors) do
			local stripe_y = self.ay + stripe_height * (c - 1)

			ass:new_event()
			ass:append('{\\blur0\\bord0\\shad0\\1c&H' .. color ..
				'\\clip(' .. fg_100_path.scale .. ',' .. fg_100_path.text .. ')}')
			ass:opacity(0.15 * opacity)
			ass:pos(0, 0)
			ass:draw_start()

			while stripe_y - skew_height < self.by do
				ass:move_to(self.ax, stripe_y)
				ass:line_to(self.bx, stripe_y - skew_height)
				ass:line_to(self.bx, stripe_y - skew_height + stripe_height)
				ass:line_to(self.ax, stripe_y + stripe_height)
				stripe_y = stripe_y + stripe_height * #colors
			end

			ass:draw_stop()
		end
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

function Volume:update_dimensions()
	local width = state.fullormaxed and options.volume_size_fullscreen or options.volume_size
	local controls, timeline, top_bar = Elements.controls, Elements.timeline, Elements.top_bar
	local min_y = top_bar.enabled and top_bar.by or 0
	local max_y = (controls and controls.enabled and controls.ay) or (timeline.enabled and timeline.ay) or 0
	local available_height = max_y - min_y
	local max_height = available_height * 0.8
	local height = round(math.min(width * 8, max_height))
	self.enabled = height > width * 2 -- don't render if too small
	local margin = (width / 2) + Elements.window_border.size
	self.ax = round(options.volume == 'left' and margin or display.width - margin - width)
	self.ay = min_y + round((available_height - height) / 2)
	self.bx = round(self.ax + width)
	self.by = round(self.ay + height)
	self.mute:set_coordinates(self.ax, self.by - round(width * 0.8), self.bx, self.by)
	self.slider:set_coordinates(self.ax, self.ay, self.bx, self.mute.ay)
end

function Volume:on_display() self:update_dimensions() end
function Volume:on_prop_border() self:update_dimensions() end
function Volume:on_controls_reflow() self:update_dimensions() end

--[[ Curtain ]]

---@class Curtain : Element
local Curtain = class(Element)

function Curtain:new() return Class.new(self) --[[@as Curtain]] end
function Curtain:init()
	Element.init(self, 'curtain', {ignores_menu = true})
	self.opacity = 0
end

function Curtain:fadeout() self:tween_property('opacity', self.opacity, 0) end
function Curtain:fadein() self:tween_property('opacity', self.opacity, 1) end

function Curtain:render()
	if self.opacity == 0 or options.curtain_opacity == 0 then return end
	local ass = assdraw.ass_new()
	ass:rect(0, 0, display.width, display.height, {
		color = '000000', opacity = options.curtain_opacity * self.opacity,
	})
	return ass
end

--[[ CREATE STATIC ELEMENTS ]]

WindowBorder:new()
PauseIndicator:new()
Timeline:new()
TopBar:new()
if options.controls and options.controls ~= 'never' then Controls:new() end
if itable_index_of({'left', 'right'}, options.volume) then Volume:new() end
Curtain:new()

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

	Elements:update_proximities()
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
	Elements:update_proximities()
	Elements:trigger('global_mouse_leave')
end

function handle_mouse_enter()
	cursor.hidden = false
	update_cursor_position()
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
	Elements:proximity_trigger('mouse_move')
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

	local next_file = get_adjacent_file(path, direction, config.media_types)

	if next_file then
		mp.commandv('loadfile', utils.join_path(serialize_path(path).dirname, next_file))
	end
end

function load_file_in_current_directory(index)
	local path = mp.get_property_native('path')

	if not path or is_protocol(path) then return end

	local serialized = serialize_path(path)
	if serialized and serialized.dirname then
		local files = get_files_in_directory(serialized.dirname, config.media_types)

		if not files then return end
		if index < 0 then index = #files + index + 1 end

		if files[index] then
			mp.commandv('loadfile', utils.join_path(serialized.dirname, files[index]))
		end
	end
end

function update_render_delay(name, fps)
	if fps then state.render_delay = 1 / fps end
end

function observe_display_fps(name, fps)
	if fps then
		mp.unobserve_property(update_render_delay)
		mp.unobserve_property(observe_display_fps)
		mp.observe_property('display-fps', 'native', update_render_delay)
	end
end

--[[ MENUS ]]

---@param data MenuData
---@param submenu_id? string ID of submenu to pre-open.
function open_command_menu(data, submenu_id)
	local menu = Menu:open(data, function(value)
		if type(value) == 'string' then
			mp.command(value)
		else
			---@diagnostic disable-next-line: deprecated
			mp.commandv((unpack or table.unpack)(value))
		end
	end)
	if submenu_id then menu:activate_submenu(submenu_id) end
	return menu
end

---@param submenu_id? string Id of submenu to pre-open
function toggle_menu_with_items(submenu_id)
	if Menu:is_open('menu') then Menu:close()
	else open_command_menu({type = 'menu', items = config.menu_items}, submenu_id) end
end

---@param options {type: string; title: string; list_prop: string; list_serializer: fun(name: string, value: any): MenuDataItem[]; active_prop?: string; on_active_prop: fun(name: string, value: any, menu: Menu): integer; on_select: fun(value: any)}
function create_self_updating_menu_opener(options)
	return function()
		if Menu:is_open(options.type) then Menu:close() return end
		local menu

		-- Update active index and playlist content on playlist changes
		local ignore_initial_prop = true
		local function handle_list_prop_change(name, value)
			if ignore_initial_prop then ignore_initial_prop = false
			else menu:update_items(options.list_serializer(name, value)) end
		end

		local ignore_initial_active = true
		local function handle_active_prop_change(name, value)
			if ignore_initial_active then ignore_initial_active = false
			else options.on_active_prop(name, value, menu) end
		end

		local initial_items, selected_index = options.list_serializer(
			options.list_prop,
			mp.get_property_native(options.list_prop)
		)

		-- Items and active_index are set in the handle_prop_change callback, since adding
		-- a property observer triggers its handler immediately, we just let that initialize the items.
		menu = Menu:open(
			{type = options.type, title = options.title, items = initial_items, selected_index = selected_index},
			options.on_select, {
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

		if load_command then
			items[#items + 1] = {
				title = 'Load', bold = true, italic = true, hint = 'open file', value = '{load}', separator = true,
			}
		end

		local first_item_index = #items + 1
		local active_index = nil
		local disabled_item = nil

		-- Add option to disable a subtitle track. This works for all tracks,
		-- but why would anyone want to disable audio or video? Better to not
		-- let people mistakenly select what is unwanted 99.999% of the time.
		-- If I'm mistaken and there is an active need for this, feel free to
		-- open an issue.
		if track_type == 'sub' then
			disabled_item = {title = 'Disabled', italic = true, muted = true, hint = '—', value = nil, active = true}
			items[#items + 1] = disabled_item
		end

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
					active = track.selected,
				}

				if track.selected then
					if disabled_item then disabled_item.active = false end
					active_index = #items
				end
			end
		end

		return items, active_index or first_item_index
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

---@alias NavigationMenuOptions {type: string, title?: string, allowed_types?: string[], active_path?: string, selected_path?: string; on_open?: fun(); on_close?: fun()}

-- Opens a file navigation menu with items inside `directory_path`.
---@param directory_path string
---@param handle_select fun(path: string): nil
---@param opts NavigationMenuOptions
function open_file_navigation_menu(directory_path, handle_select, opts)
	directory = serialize_path(directory_path)
	opts = opts or {}

	if not directory then
		msg.error('Couldn\'t serialize path "' .. directory_path .. '.')
		return
	end

	local directories, dirs_error = utils.readdir(directory.path, 'dirs')
	local files, files_error = get_files_in_directory(directory.path, opts.allowed_types)
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
			items[#items + 1] = {
				title = '..', hint = 'Drives', value = {is_drives = true, is_to_parent = true}, separator = true,
			}
		end
	else
		local serialized = serialize_path(directory.dirname)
		serialized.is_directory = true;
		serialized.is_to_parent = true;
		items[#items + 1] = {title = '..', hint = 'parent dir', value = serialized, separator = true}
	end

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

	for index, item in ipairs(items) do
		if not item.value.is_to_parent then
			if index == items_start_index then item.selected = true end

			if opts.active_path == item.value.path then
				item.active = true
				if not opts.selected_path then item.selected = true end
			end

			if opts.selected_path == item.value.path then item.selected = true end
		end
	end

	local menu_data = {
		type = opts.type, title = opts.title or directory.basename .. '/', items = items,
		on_open = opts.on_open, on_close = opts.on_close,
	}

	return Menu:open(menu_data, function(path)
		local inheritable_options = {
			type = opts.type, title = opts.title, allowed_types = opts.allowed_types, active_path = opts.active_path,
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
		end
	end)
end

-- Opens a file navigation menu with Windows drives as items.
---@param handle_select fun(path: string): nil
---@param opts? NavigationMenuOptions
function open_drives_menu(handle_select, opts)
	opts = opts or {}
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
				items[#items + 1] = {
					title = drive, hint = 'Drive', value = drive_path,
					selected = opts.selected_path == drive_path,
					active = opts.active_path == drive_path,
				}
			end
		end
	else
		msg.error(process.stderr)
	end

	return Menu:open({type = opts.type, title = opts.title or 'Drives', items = items}, handle_select)
end

--[[ HOOKS]]

-- Mouse movement key binds
local mouse_keybinds = {
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
	mouse_keybinds[#mouse_keybinds + 1] = {'mbtn_left', function()
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
mp.set_key_bindings(mouse_keybinds, 'mouse_movement', 'force')
mp.enable_key_bindings('mouse_movement', 'allow-vo-dragging+allow-hide-cursor')

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
mp.observe_property('playlist-count', 'number', function(_, value)
	set_state('playlist_count', value)
	set_state('has_playlist', value > 1)
	Elements:trigger('dispositions')
end)
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
mp.add_key_binding(nil, 'menu', function() toggle_menu_with_items() end)
local track_loaders = {
	{name = 'subtitles', prop = 'sub', allowed_types = config.subtitle_types},
	{name = 'audio', prop = 'audio', allowed_types = config.media_types},
	{name = 'video', prop = 'video', allowed_types = config.media_types},
}
for _, loader in ipairs(track_loaders) do
	local menu_type = 'load-' .. loader.name
	mp.add_key_binding(nil, menu_type, function()
		if Menu:is_open(menu_type) then Menu:close() return end

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
			{type = menu_type, title = 'Load ' .. loader.name, allowed_types = loader.allowed_types}
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
				active = item.current,
				value = index,
			}
		end
		return items
	end,
	on_select = function(index) mp.commandv('set', 'playlist-pos-1', tostring(index)) end,
}))
mp.add_key_binding(nil, 'chapters', create_self_updating_menu_opener({
	title = 'Chapters',
	type = 'chapters',
	list_prop = 'chapter-list',
	list_serializer = function(_, _)
		local items = {}
		local chapters = get_normalized_chapters()
		local active_found = false

		for index, chapter in ipairs(chapters) do
			local item = {
				title = chapter.title or '',
				hint = mp.format_time(chapter.time),
				value = chapter.time,
			}
			items[#items + 1] = item
			if active_found == false then
				local is_active = chapter.time >= state.time
				if is_active then
					item.active = true
					active_found = true
				end
			end
		end
		return items
	end,
	active_prop = 'playback-time',
	on_active_prop = function(_, playback_time, menu)
		-- Select first chapter from the end with time lower
		-- than current playing position.
		local position = playback_time
		if not position then
			menu:deactivate_items()
			return
		end
		local items = menu.current.items
		for index = #items, 1, -1 do
			if position >= items[index].value then
				menu:activate_unique_index(index)
				return
			end
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
	if Menu:is_open('stream-quality') then Menu:close() return end

	local ytdl_format = mp.get_property_native('ytdl-format')
	local items = {}

	for _, height in ipairs(config.stream_quality_options) do
		local format = 'bestvideo[height<=?' .. height .. ']+bestaudio/best[height<=?' .. height .. ']'
		items[#items + 1] = {title = height .. 'p', value = format, active = format == ytdl_format}
	end

	Menu:open({type = 'stream-quality', title = 'Stream quality', items = items}, function(format)
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
	end)
end)
mp.add_key_binding(nil, 'open-file', function()
	if Menu:is_open('open-file') then Menu:close() return end

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

	-- Update active file in directory navigation menu
	local function handle_file_loaded()
		if Menu:is_open('open-file') then
			local path = normalize_path(mp.get_property_native('path'))
			Elements.menu:activate_value(path)
		end
	end

	open_file_navigation_menu(
		directory,
		function(path) mp.commandv('loadfile', path) end,
		{
			type = 'open-file',
			allowed_types = config.media_types,
			active_path = active_file,
			on_open = function() mp.register_event('file-loaded', handle_file_loaded) end,
			on_close = function() mp.unregister_event(handle_file_loaded) end,
		}
	)
end)
mp.add_key_binding(nil, 'items', function()
	if state.has_playlist then
		mp.command('script-binding uosc/playlist')
	else
		mp.command('script-binding uosc/open-file')
	end
end)
mp.add_key_binding(nil, 'next', function()
	if state.has_playlist then
		mp.command('playlist-next')
	else
		navigate_directory('forward')
	end
end)
mp.add_key_binding(nil, 'prev', function()
	if state.has_playlist then
		mp.command('playlist-prev')
	else
		navigate_directory('backward')
	end
end)
mp.add_key_binding(nil, 'next-file', function() navigate_directory('forward') end)
mp.add_key_binding(nil, 'prev-file', function() navigate_directory('backward') end)
mp.add_key_binding(nil, 'first', function()
	if state.has_playlist then
		mp.commandv('set', 'playlist-pos-1', '1')
	else
		load_file_in_current_directory(1)
	end
end)
mp.add_key_binding(nil, 'last', function()
	if state.has_playlist then
		mp.commandv('set', 'playlist-pos-1', tostring(state.playlist_count))
	else
		load_file_in_current_directory(-1)
	end
end)
mp.add_key_binding(nil, 'first-file', function() load_file_in_current_directory(1) end)
mp.add_key_binding(nil, 'last-file', function() load_file_in_current_directory(-1) end)
mp.add_key_binding(nil, 'delete-file-next', function()
	local next_file = nil
	local path = mp.get_property_native('path')
	local is_local_file = path and not is_protocol(path)

	if is_local_file then
		path = normalize_path(path)
		if Menu:is_open('open-file') then Elements.menu:delete_value(path) end
	end

	if state.has_playlist then
		mp.commandv('playlist-remove', 'current')
	else
		if is_local_file then
			next_file = get_adjacent_file(path, 'forward', config.media_types)
		end

		if next_file then mp.commandv('loadfile', next_file)
		else mp.commandv('stop') end
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

-- MESSAGE HANDLERS

mp.register_script_message('show-submenu', toggle_menu_with_items)
mp.register_script_message('get-version', function(script)
	mp.commandv('script-message-to', script, 'uosc-version', config.version)
end)
mp.register_script_message('open-menu', function(json, submenu_id)
	local data = utils.parse_json(json)
	if type(data) ~= 'table' or type(data.items) ~= 'table' then
		msg.error('open-menu: received json didn\'t produce a table with menu configuration')
	else
		if data.type and Menu:is_open(data.type) then Menu:close()
		else open_command_menu(data, submenu_id) end
	end
end)
mp.register_script_message('update-menu', function(json)
	local data = utils.parse_json(json)
	if type(data) ~= 'table' or type(data.items) ~= 'table' then
		msg.error('update-menu: received json didn\'t produce a table with menu configuration')
	else
		local menu = data.type and Menu:is_open(data.type)
		if menu then menu:update(data)
		else open_command_menu(data) end
	end
end)
