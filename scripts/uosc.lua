--[[ uosc 4.3.0 - 2022-Oct-11 | https://github.com/tomasklaen/uosc ]]
local uosc_version = '4.3.0'

local assdraw = require('mp.assdraw')
local opt = require('mp.options')
local utils = require('mp.utils')
local msg = require('mp.msg')
local osd = mp.create_osd_overlay('ass-events')
local infinity = 1e309
local quarter_pi_sin = math.sin(math.pi / 4)

--[[ BASE HELPERS ]]

---@param number number
function round(number) return math.floor(number + 0.5) end

---@param min number
---@param value number
---@param max number
function clamp(min, value, max) return math.max(min, math.min(value, max)) end

---@param rgba string `rrggbb` or `rrggbbaa` hex string.
function serialize_rgba(rgba)
	local a = rgba:sub(7, 8)
	return {
		color = rgba:sub(5, 6) .. rgba:sub(3, 4) .. rgba:sub(1, 2),
		opacity = clamp(0, tonumber(#a == 2 and a or 'ff', 16) / 255, 1),
	}
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
---@param from_end? boolean Search from the end of the table.
---@return number|nil index
---@return any|nil value
function itable_find(itable, compare, from_end)
	local from, to, step = from_end and #itable or 1, from_end and 1 or #itable, from_end and -1 or 1
	for index = from, to, step do
		if compare(itable[index], index) then return index, itable[index] end
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

---@generic T
---@param a T[]|nil
---@param b T[]|nil
---@return T[]
function itable_join(a, b)
	local result = {}
	if a then for _, value in ipairs(a) do result[#result + 1] = value end end
	if b then for _, value in ipairs(b) do result[#result + 1] = value end end
	return result
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
function table_shallow_copy(table)
	local result = {}
	for key, value in pairs(table) do result[key] = value end
	return result
end

--[[ OPTIONS ]]

local defaults = {
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
	timeline_chapters_opacity = 0.8,

	controls = 'menu,gap,subtitles,<has_many_audio>audio,<has_many_video>video,<has_many_edition>editions,<stream>stream-quality,gap,space,speed,space,shuffle,loop-playlist,loop-file,gap,prev,items,next,gap,fullscreen',
	controls_size = 32,
	controls_size_fullscreen = 40,
	controls_margin = 8,
	controls_spacing = 2,
	controls_persistency = '',

	volume = 'right',
	volume_size = 40,
	volume_size_fullscreen = 52,
	volume_persistency = '',
	volume_opacity = 0.9,
	volume_border = 1,
	volume_step = 1,

	speed_persistency = '',
	speed_opacity = 0.6,
	speed_step = 0.1,
	speed_step_is_factor = false,

	menu_item_height = 36,
	menu_item_height_fullscreen = 50,
	menu_min_width = 260,
	menu_min_width_fullscreen = 360,
	menu_opacity = 1,
	menu_parent_opacity = 0.4,

	top_bar = 'no-border',
	top_bar_size = 40,
	top_bar_size_fullscreen = 46,
	top_bar_persistency = '',
	top_bar_controls = true,
	top_bar_title = true,
	top_bar_title_opacity = 0.8,

	window_border_size = 1,
	window_border_opacity = 0.8,

	autoload = false,
	shuffle = false,

	ui_scale = 1,
	font_scale = 1,
	text_border = 1.2,
	pause_on_click_shorter_than = 0, -- deprecated by below
	click_threshold = 0,
	click_command = 'cycle pause; script-binding uosc/flash-pause-indicator',
	flash_duration = 1000,
	proximity_in = 40,
	proximity_out = 120,
	foreground = 'ffffff',
	foreground_text = '000000',
	background = '000000',
	background_text = 'ffffff',
	total_time = false,
	time_precision = 0,
	font_bold = false,
	autohide = false,
	buffered_time_threshold = 60,
	pause_indicator = 'flash',
	curtain_opacity = 0.5,
	stream_quality_options = '4320,2160,1440,1080,720,480,360,240,144',
	media_types = '3g2,3gp,aac,aiff,ape,apng,asf,au,avi,avif,bmp,dsf,f4v,flac,flv,gif,h264,h265,j2k,jp2,jfif,jpeg,jpg,jxl,m2ts,m4a,m4v,mid,midi,mj2,mka,mkv,mov,mp3,mp4,mp4a,mp4v,mpeg,mpg,oga,ogg,ogm,ogv,opus,png,rm,rmvb,spx,svg,tak,tga,tta,tif,tiff,ts,vob,wav,weba,webm,webp,wma,wmv,wv,y4m',
	subtitle_types = 'aqt,ass,gsub,idx,jss,lrc,mks,pgs,pjs,psb,rt,slt,smi,sub,sup,srt,ssa,ssf,ttxt,txt,usf,vt,vtt',
	font_height_to_letter_width_ratio = 0.5,
	default_directory = '~/',
	chapter_ranges = 'openings:30abf964,endings:30abf964,ads:c54e4e80',
	chapter_range_patterns = 'openings:オープニング;endings:エンディング',
}
local options = table_shallow_copy(defaults)
opt.read_options(options, 'uosc')
-- Normalize values
options.proximity_out = math.max(options.proximity_out, options.proximity_in + 1)
if options.chapter_ranges:sub(1, 4) == '^op|' then options.chapter_ranges = defaults.chapter_ranges end
if options.pause_on_click_shorter_than > 0 and options.click_threshold == 0 then
	msg.warn('`pause_on_click_shorter_than` is deprecated. Use `click_threshold` and `click_command` instead.')
	options.click_threshold = options.pause_on_click_shorter_than
end
-- Ensure required environment configuration
if options.autoload then mp.commandv('set', 'keep-open-pause', 'no') end
-- Color shorthands
local fg, bg = serialize_rgba(options.foreground).color, serialize_rgba(options.background).color
local fgt, bgt = serialize_rgba(options.foreground_text).color, serialize_rgba(options.background_text).color

--[[ CONFIG ]]

local function create_default_menu()
	return {
		{title = 'Subtitles', value = 'script-binding uosc/subtitles'},
		{title = 'Audio tracks', value = 'script-binding uosc/audio'},
		{title = 'Stream quality', value = 'script-binding uosc/stream-quality'},
		{title = 'Playlist', value = 'script-binding uosc/items'},
		{title = 'Chapters', value = 'script-binding uosc/chapters'},
		{title = 'Navigation', items = {
			{title = 'Next', hint = 'playlist or file', value = 'script-binding uosc/next'},
			{title = 'Prev', hint = 'playlist or file', value = 'script-binding uosc/prev'},
			{title = 'Delete file & Next', value = 'script-binding uosc/delete-file-next'},
			{title = 'Delete file & Prev', value = 'script-binding uosc/delete-file-prev'},
			{title = 'Delete file & Quit', value = 'script-binding uosc/delete-file-quit'},
			{title = 'Open file', value = 'script-binding uosc/open-file'},
		},},
		{title = 'Utils', items = {
			{title = 'Aspect ratio', items = {
				{title = 'Default', value = 'set video-aspect-override "-1"'},
				{title = '16:9', value = 'set video-aspect-override "16:9"'},
				{title = '4:3', value = 'set video-aspect-override "4:3"'},
				{title = '2.35:1', value = 'set video-aspect-override "2.35:1"'},
			},},
			{title = 'Audio devices', value = 'script-binding uosc/audio-device'},
			{title = 'Editions', value = 'script-binding uosc/editions'},
			{title = 'Screenshot', value = 'async screenshot'},
			{title = 'Show in directory', value = 'script-binding uosc/show-in-directory'},
			{title = 'Open config folder', value = 'script-binding uosc/open-config-directory'},
		},},
		{title = 'Quit', value = 'quit'},
	}
end

local config = {
	version = uosc_version,
	-- sets max rendering frequency in case the
	-- native rendering frequency could not be detected
	render_delay = 1 / 60,
	font = mp.get_property('options/osd-font'),
	media_types = split(options.media_types, ' *, *'),
	subtitle_types = split(options.subtitle_types, ' *, *'),
	stream_quality_options = split(options.stream_quality_options, ' *, *'),
	menu_items = (function()
		local input_conf_property = mp.get_property_native('input-conf')
		local input_conf_path = mp.command_native({
			'expand-path', input_conf_property == '' and '~~/input.conf' or input_conf_property,
		})
		local input_conf_meta, meta_error = utils.file_info(input_conf_path)

		-- File doesn't exist
		if not input_conf_meta or not input_conf_meta.is_file then return create_default_menu() end

		local main_menu = {items = {}, items_by_command = {}}
		local by_id = {}

		for line in io.lines(input_conf_path) do
			local key, command, comment = string.match(line, '%s*([%S]+)%s+(.-)%s+#%s*(.-)%s*$')
			local title = ''
			if comment then
				local comments = split(comment, '#')
				local titles = itable_filter(comments, function(v, i) return v:match('^!') or v:match('^menu:') end)
				if titles and #titles > 0 then
					title = titles[1]:match('^!%s*(.*)%s*') or titles[1]:match('^menu:%s*(.*)%s*')
				end
			end
			if title ~= '' then
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
			return create_default_menu()
		end
	end)(),
	chapter_ranges = (function()
		---@type table<string, string[]> Alternative patterns.
		local alt_patterns = {}
		if options.chapter_range_patterns and options.chapter_range_patterns ~= '' then
			for _, definition in ipairs(split(options.chapter_range_patterns, ';+ *')) do
				local name_patterns = split(definition, ' *:')
				local name, patterns = name_patterns[1], name_patterns[2]
				if name and patterns then alt_patterns[name] = split(patterns, ',') end
			end
		end

		---@type table<string, {color: string; opacity: number; patterns?: string[]}>
		local ranges = {}
		if options.chapter_ranges and options.chapter_ranges ~= '' then
			for _, definition in ipairs(split(options.chapter_ranges, ' *,+ *')) do
				local name_color = split(definition, ' *:+ *')
				local name, color = name_color[1], name_color[2]
				if name and color
					and name:match('^[a-zA-Z0-9_]+$') and color:match('^[a-fA-F0-9]+$')
					and (#color == 6 or #color == 8) then
					local range = serialize_rgba(name_color[2])
					range.patterns = alt_patterns[name]
					ranges[name_color[1]] = range
				end
			end
		end
		return ranges
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

local display = {width = 1280, height = 720, scale_x = 1, scale_y = 1}
local cursor = {hidden = true, x = 0, y = 0}
local state = {
	os = (function()
		if os.getenv('windir') ~= nil then return 'windows' end
		local homedir = os.getenv('HOME')
		if homedir ~= nil and string.sub(homedir, 1, 6) == '/Users' then return 'macos' end
		return 'linux'
	end)(),
	cwd = mp.get_property('working-directory'),
	path = nil, -- current file path or URL
	title = nil,
	time = nil, -- current media playback time
	speed = 1,
	duration = nil, -- current media duration
	time_human = nil, -- current playback time in human format
	duration_or_remaining_time_human = nil, -- depends on options.total_time
	pause = mp.get_property_native('pause'),
	chapters = {},
	current_chapter = nil,
	chapter_ranges = {},
	border = mp.get_property_native('border'),
	fullscreen = mp.get_property_native('fullscreen'),
	maximized = mp.get_property_native('window-maximized'),
	fullormaxed = mp.get_property_native('fullscreen') or mp.get_property_native('window-maximized'),
	render_timer = nil,
	render_last_time = 0,
	volume = nil,
	volume_max = nil,
	mute = nil,
	is_idle = false,
	is_video = false,
	is_audio = false, -- true if file is audio only (mp3, etc)
	is_image = false,
	is_stream = false,
	has_audio = false,
	has_sub = false,
	has_chapter = false,
	has_playlist = false,
	shuffle = options.shuffle,
	cursor_autohide_timer = mp.add_timeout(mp.get_property_native('cursor-autohide') / 1000, function()
		if not options.autohide then return end
		handle_mouse_leave()
	end),
	mouse_bindings_enabled = false,
	uncached_ranges = nil,
	cache = nil,
	cache_buffering = 100,
	cache_underrun = false,
	core_idle = false,
	eof_reached = false,
	render_delay = config.render_delay,
	first_real_mouse_move_received = false,
	playlist_count = 0,
	playlist_pos = 0,
	margin_top = 0,
	margin_bottom = 0,
	hidpi_scale = 1,
}
local thumbnail = {width = 0, height = 0, disabled = false}
local external = {} -- Properties set by external scripts

--[[ HELPERS ]]

-- Sorting comparator close to (but not exactly) how file explorers sort files
local file_order_comparator = (function()
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
			if callback then callback() end
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
	local dx = math.max(rect.ax - point.x, 0, point.x - rect.bx)
	local dy = math.max(rect.ay - point.y, 0, point.y - rect.by)
	return math.sqrt(dx * dx + dy * dy)
end

---@param text string|number
---@param font_size number
function text_width_estimate(text, font_size) return text_length_width_estimate(text_length(text), font_size) end

---@param length number
---@param font_size number
function text_length_width_estimate(length, font_size)
	return length * font_size * options.font_height_to_letter_width_ratio
end

---@param text string|number
function text_length(text)
	if not text or text == '' then return 0 end
	local text_length = 0
	for _, _, length in utf8_iter(tostring(text)) do text_length = text_length + length end
	return text_length
end

function utf8_iter(string)
	local byte_start, byte_count = 1, 1

	return function()
		if #string < byte_start then return nil end

		local char_byte = string.byte(string, byte_start)

		byte_count = 1
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
	return table.concat(lines, '\n'), max_length, #lines
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

	table.sort(files, file_order_comparator)

	return files
end

-- Returns full absolute paths of files in the same directory as file_path,
-- and index of the current file in the table.
---@param file_path string
---@param allowed_types? string[]
function get_adjacent_paths(file_path, allowed_types)
	local current_file = serialize_path(file_path)
	if not current_file then return end
	local files = get_files_in_directory(current_file.dirname, allowed_types)
	if not files then return end
	local current_file_index
	local paths = {}
	for index, file in ipairs(files) do
		paths[#paths + 1] = utils.join_path(current_file.dirname, file)
		if current_file.basename == file then current_file_index = index end
	end
	if not current_file_index then return end
	return paths, current_file_index
end

-- Navigates in a list, using delta or, when `state.shuffle` is enabled,
-- randomness to determine the next item. Loops around if `loop-playlist` is enabled.
---@param list table
---@param current_index number
---@param delta number
function decide_navigation_in_list(list, current_index, delta)
	if #list < 2 then return #list, list[#list] end

	if state.shuffle then
		local new_index = current_index
		math.randomseed(os.time())
		while current_index == new_index do new_index = math.random(#list) end
		return new_index, list[new_index]
	end

	local new_index = current_index + delta
	if mp.get_property_native('loop-playlist') then
		if new_index > #list then new_index = new_index % #list
		elseif new_index < 1 then new_index = #list - new_index end
	elseif new_index < 1 or new_index > #list then
		return
	end

	return new_index, list[new_index]
end

---@param delta number
function navigate_directory(delta)
	if not state.path or is_protocol(state.path) then return false end
	local paths, current_index = get_adjacent_paths(state.path, config.media_types)
	if paths and current_index then
		local _, path = decide_navigation_in_list(paths, current_index, delta)
		if path then mp.commandv('loadfile', path) return true end
	end
	return false
end

---@param delta number
function navigate_playlist(delta)
	local playlist, pos = mp.get_property_native('playlist'), mp.get_property_native('playlist-pos-1')
	if playlist and #playlist > 1 and pos then
		local index = decide_navigation_in_list(playlist, pos, delta)
		if index then mp.commandv('playlist-play-index', index - 1) return true end
	end
	return false
end

---@param delta number
function navigate_item(delta)
	if state.has_playlist then return navigate_playlist(delta) else return navigate_directory(delta) end
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

function serialize_chapter_ranges(normalized_chapters)
	local ranges = {}
	local simple_ranges = {
		{name = 'openings', patterns = {'^op ', '^op$', ' op$', 'opening$'}, requires_next_chapter = true},
		{name = 'intros', patterns = {'^intro$'}, requires_next_chapter = true},
		{name = 'endings', patterns = {'^ed ', '^ed$', ' ed$', 'ending$', 'closing$'}},
		{name = 'outros', patterns = {'^outro$'}},
	}
	local sponsor_ranges = {}

	-- Extend with alt patterns
	for _, meta in ipairs(simple_ranges) do
		local alt_patterns = config.chapter_ranges[meta.name] and config.chapter_ranges[meta.name].patterns
		if alt_patterns then meta.patterns = itable_join(meta.patterns, alt_patterns) end
	end

	-- Clone chapters
	local chapters = {}
	for i, normalized in ipairs(normalized_chapters) do chapters[i] = table_shallow_copy(normalized) end

	for i, chapter in ipairs(chapters) do
		-- Simple ranges
		for _, meta in ipairs(simple_ranges) do
			if config.chapter_ranges[meta.name] then
				local match = itable_find(meta.patterns, function(p) return chapter.lowercase_title:find(p) end)
				if match then
					local next_chapter = chapters[i + 1]
					if next_chapter or not meta.requires_next_chapter then
						ranges[#ranges + 1] = table_assign({
							start = chapter.time,
							['end'] = next_chapter and next_chapter.time or infinity,
						}, config.chapter_ranges[meta.name])
					end
				end
			end
		end

		-- Sponsor blocks
		if config.chapter_ranges.ads then
			local id = chapter.lowercase_title:match('segment start *%(([%w]%w-)%)')
			if id then -- ad range from sponsorblock
				for j = i + 1, #chapters, 1 do
					local end_chapter = chapters[j]
					local end_match = end_chapter.lowercase_title:match('segment end *%(' .. id .. '%)')
					if end_match then
						local range = table_assign({
							start_chapter = chapter, end_chapter = end_chapter,
							start = chapter.time, ['end'] = end_chapter.time,
						}, config.chapter_ranges.ads)
						ranges[#ranges + 1], sponsor_ranges[#sponsor_ranges + 1] = range, range
						end_chapter.is_end_only = true
						break
					end
				end -- single chapter for ad
			elseif not chapter.is_end_only and
				(chapter.lowercase_title:find('%[sponsorblock%]:') or chapter.lowercase_title:find('^sponsors?')) then
				local next_chapter = chapters[i + 1]
				ranges[#ranges + 1] = table_assign({
					start = chapter.time,
					['end'] = next_chapter and next_chapter.time or infinity,
				}, config.chapter_ranges.ads)
			end
		end
	end

	-- Fix overlapping sponsor block segments
	for index, range in ipairs(sponsor_ranges) do
		local next_range = sponsor_ranges[index + 1]
		if next_range then
			local delta = next_range.start - range['end']
			if delta < 0 then
				local mid_point = range['end'] + delta / 2
				range['end'], range.end_chapter.time = mid_point - 0.01, mid_point - 0.01
				next_range.start, next_range.start_chapter.time = mid_point, mid_point
			end
		end
	end
	table.sort(chapters, function(a, b) return a.time < b.time end)

	return chapters, ranges
end

-- Ensures chapters are in chronological order
function normalize_chapters(chapters)
	if not chapters then return {} end
	-- Ensure chronological order
	table.sort(chapters, function(a, b) return a.time < b.time end)
	-- Ensure titles
	for index, chapter in ipairs(chapters) do
		chapter.title = chapter.title or ('Chapter ' .. index)
		chapter.lowercase_title = chapter.title:lower()
	end
	return chapters
end

function serialize_chapters(chapters)
	chapters = normalize_chapters(chapters)
	if not chapters then return end
	for index, chapter in ipairs(chapters) do
		chapter.index = index
		chapter.title_wrapped, chapter.title_wrapped_width, chapter.title_wrapped_lines = wrap_text(chapter.title, 25)
		chapter.title_wrapped = ass_escape(chapter.title_wrapped)
	end
	return chapters
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
	opts.font, opts.size, opts.bold = 'MaterialIconsRound-Regular', size, false
	self:txt(x, y, opts.align or 5, name, opts)
end

-- Text
-- Named `txt` because `ass.text` is a value.
---@param x number
---@param y number
---@param align number
---@param value string|number
---@param opts {size: number; font?: string; color?: string; bold?: boolean; italic?: boolean; border?: number; border_color?: string; shadow?: number; shadow_color?: string; rotate?: number; wrap?: number; opacity?: number; clip?: string}
function ass_mt:txt(x, y, align, value, opts)
	local border_size = opts.border or 0
	local shadow_size = opts.shadow or 0
	local tags = '\\pos(' .. x .. ',' .. y .. ')\\rDefault\\an' .. align .. '\\blur0'
	-- font
	tags = tags .. '\\fn' .. (opts.font or config.font)
	-- font size
	tags = tags .. '\\fs' .. opts.size
	-- bold
	if opts.bold or (opts.bold == nil and options.font_bold) then tags = tags .. '\\b1' end
	-- italic
	if opts.italic then tags = tags .. '\\i1' end
	-- rotate
	if opts.rotate then tags = tags .. '\\frz' .. opts.rotate end
	-- wrap
	if opts.wrap then tags = tags .. '\\q' .. opts.wrap end
	-- border
	tags = tags .. '\\bord' .. border_size
	-- shadow
	tags = tags .. '\\shad' .. shadow_size
	-- colors
	tags = tags .. '\\1c&H' .. (opts.color or bgt)
	if border_size > 0 then tags = tags .. '\\3c&H' .. (opts.border_color or bg) end
	if shadow_size > 0 then tags = tags .. '\\4c&H' .. (opts.shadow_color or bg) end
	-- opacity
	if opts.opacity then tags = tags .. string.format('\\alpha&H%X&', opacity_to_alpha(opts.opacity)) end
	-- clip
	if opts.clip then tags = tags .. opts.clip end
	-- render
	self:new_event()
	self.text = self.text .. '{' .. tags .. '}' .. value
end

-- Tooltip
---@param element {ax: number; ay: number; bx: number; by: number}
---@param value string|number
---@param opts? {size?: number; offset?: number; bold?: boolean; italic?: boolean; text_length_override?: number; responsive?: boolean}
function ass_mt:tooltip(element, value, opts)
	opts = opts or {}
	opts.size = opts.size or 16
	opts.border = options.text_border
	opts.border_color = bg
	local offset = opts.offset or opts.size / 2
	local align_top = opts.responsive == false or element.ay - offset > opts.size * 2
	local x = element.ax + (element.bx - element.ax) / 2
	local y = align_top and element.ay - offset or element.by + offset
	local text_width = opts.text_length_override
		and opts.text_length_override * opts.size * options.font_height_to_letter_width_ratio
		or text_width_estimate(value, opts.size)
	local margin = text_width / 2
	self:txt(clamp(margin, x, display.width - margin), y, align_top and 2 or 8, value, opts)
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
	local tags = '\\pos(0,0)\\rDefault\\an7\\blur0'
	-- border
	tags = tags .. '\\bord' .. border_size
	-- colors
	tags = tags .. '\\1c&H' .. (opts.color or fg)
	if border_size > 0 then tags = tags .. '\\3c&H' .. (opts.border_color or bg) end
	-- opacity
	if opts.opacity then tags = tags .. string.format('\\alpha&H%X&', opacity_to_alpha(opts.opacity)) end
	if opts.border_opacity then tags = tags .. string.format('\\3a&H%X&', opacity_to_alpha(opts.border_opacity)) end
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

-- Texture
---@param ax number
---@param ay number
---@param bx number
---@param by number
---@param char string Texture font character.
---@param opts {size?: number; color: string; opacity?: number; clip?: string; anchor_x?: number, anchor_y?: number}
function ass_mt:texture(ax, ay, bx, by, char, opts)
	opts = opts or {}
	local anchor_x, anchor_y = opts.anchor_x or ax, opts.anchor_y or ay
	local clip = opts.clip or ('\\clip(' .. ax .. ',' .. ay .. ',' .. bx .. ',' .. by .. ')')
	local tile_size, opacity = opts.size or 100, opts.opacity or 0.2
	local x, y = ax - (ax - anchor_x) % tile_size, ay - (ay - anchor_y) % tile_size
	local width, height = bx - x, by - y
	local line = string.rep(char, math.ceil((width / tile_size)))
	local lines = ''
	for i = 1, math.ceil(height / tile_size), 1 do lines = lines .. (lines == '' and '' or '\\N') .. line end
	self:txt(
		x, y, 7, lines,
		{font = 'uosc_textures', size = tile_size, color = opts.color, bold = false, opacity = opacity, clip = clip})
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

-- Toggles passed elements' min visibilities between 0 and 1.
---@param ids string[] IDs of elements to peek.
function Elements:toggle(ids)
	local elements = itable_filter(self.itable, function(element) return itable_index_of(ids, element.id) ~= nil end)
	local all_visible = itable_find(elements, function(element) return element.min_visibility ~= 1 end) == nil
	local to = all_visible and 0 or 1
	for _, element in ipairs(elements) do element:tween_property('min_visibility', element.min_visibility, to) end
end

-- Flash passed elements.
---@param ids string[] IDs of elements to peek.
function Elements:flash(ids)
	local elements = itable_filter(self.itable, function(element) return itable_index_of(ids, element.id) ~= nil end)
	for _, element in ipairs(elements) do element:flash() end
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
	local scale = (state.hidpi_scale or 1) * options.ui_scale
	local real_width, real_height = mp.get_osd_size()
	local scaled_width, scaled_height = round(real_width / scale), round(real_height / scale)
	display.width, display.height = scaled_width, scaled_height
	display.scale_x, display.scale_y = real_width / scaled_width, real_height / scaled_height

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

-- Request that render() is called.
-- The render is then either executed immediately, or rate-limited if it was
-- called a small time ago.
state.render_timer = mp.add_timeout(0, render)
state.render_timer:kill()
function request_render()
	if state.render_timer:is_enabled() then return end
	local timeout = math.max(0, state.render_delay - (mp.get_time() - state.render_last_time))
	state.render_timer.timeout = timeout
	state.render_timer:resume()
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
	---@type number `0-1` factor to force min visibility. Used for toggling element's permanent visibility.
	self.min_visibility = 0
	---@type number `0-1` factor to force a visibility value. Used for flashing, fading out, and other animations
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
		self.proximity = 1 - (clamp(0, self.proximity_raw - options.proximity_in, range) / range)
	end
end

-- Decide elements visibility based on proximity and various other factors
function Element:get_visibility()
	-- Hide when menu is open, unless this is a menu
	---@diagnostic disable-next-line: undefined-global
	if not self.ignores_menu and Menu and Menu:is_open() then return 0 end

	-- Persistency
	local persist = config[self.id .. '_persistency']
	if persist and (
		(persist.audio and state.is_audio)
			or (persist.paused and state.pause)
			or (persist.video and state.is_video)
			or (persist.image and state.is_image)
			or (persist.idle and state.is_idle)
		) then return 1 end

	-- Forced visibility
	if self.forced_visibility then return math.max(self.forced_visibility, self.min_visibility) end

	-- Anchor inheritance
	-- If anchor returns -1, it means all attached elements should force hide.
	local anchor = self.anchor_id and Elements[self.anchor_id]
	local anchor_visibility = anchor and anchor:get_visibility() or 0

	return anchor_visibility == -1 and 0 or math.max(self.proximity, anchor_visibility, self.min_visibility)
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
			if callback then callback() end
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
		request_render()
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
---@alias MenuOptions {mouse_nav?: boolean; on_open?: fun(), on_close?: fun()}

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
	local open_menu = self:is_open()
	if open_menu then
		open_menu.is_being_replaced = true
		open_menu:close(true)
	end
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
			if callback then callback() end
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
---@param data MenuData
---@param callback fun(value: any)
---@param opts? MenuOptions
function Menu:init(data, callback, opts)
	Element.init(self, 'menu', {ignores_menu = true})

	-----@type fun()
	self.callback = callback
	self.opts = opts or {}
	self.offset_x = 0 -- Used for submenu transition animation.
	self.mouse_nav = self.opts.mouse_nav -- Stops pre-selecting items
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
	self.is_being_replaced = false
	self.is_closing = false

	self:update(data)

	if self.mouse_nav then
		if self.current then self.current.selected_index = nil end
	else
		for _, menu in ipairs(self.all) do self:scroll_to_index(menu.selected_index, menu) end
	end

	self:tween_property('opacity', 0, 1)
	self:enable_key_bindings()
	Elements.curtain:register('menu')
	if self.opts.on_open then self.opts.on_open() end
end

function Menu:destroy()
	Element.destroy(self)
	self:disable_key_bindings()
	if not self.is_being_replaced then Elements.curtain:unregister('menu') end
	if self.opts.on_close then self.opts.on_close() end
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

		if menu.is_root then menu.selected_index = menu_data.selected_index or first_active_index end

		-- Retain old state
		local old_menu = self.by_id[menu.is_root and '__root__' or menu.id]
		if old_menu then table_assign(menu, old_menu, {'selected_index', 'scroll_y'}) end

		new_all[#new_all + 1] = menu
		new_by_id[menu.is_root and '__root__' or menu.id] = menu
	end

	self.root, self.all, self.by_id = new_root, new_all, new_by_id
	self.current = self.by_id[old_current_id] or self.root

	self:update_content_dimensions()
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
		menu.width = round(clamp(min_width, menu.max_width, display.width * 0.9))
		local title_height = (menu.is_root and menu.title) and self.scroll_step or 0
		local max_height = round((display.height - title_height) * 0.9)
		local content_height = self.scroll_step * #menu.items
		menu.height = math.min(content_height - self.item_spacing, max_height)
		menu.top = round(math.max((display.height - menu.height) / 2, title_height * 1.5))
		menu.scroll_height = math.max(content_height - menu.height - self.item_spacing, 0)
		self:scroll_to(menu.scroll_y, menu) -- clamps scroll_y to scroll limits
	end

	local ax = round((display.width - self.current.width) / 2) + self.offset_x
	self:set_coordinates(ax, self.current.top, ax + self.current.width, self.current.top + self.current.height)
end

function Menu:reset_navigation()
	local menu = self.current

	-- Reset indexes and scroll
	self:scroll_to(menu.scroll_y) -- clamps scroll_y to scroll limits
	if self.mouse_nav then
		self:select_item_below_cursor()
	else
		self:select_index((menu.items and #menu.items > 0) and clamp(1, menu.selected_index or 1, #menu.items) or nil)
	end

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
	menu.scroll_y = clamp(0, pos or 0, menu.scroll_height)
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
	local index = itable_find(menu.items, function(_, item) return item.value == value end)
	self:activate_index(index, menu)
end

---@param value? any
---@param menu? MenuStack
function Menu:activate_unique_value(value, menu)
	menu = menu or self.current
	local index = itable_find(menu.items, function(_, item) return item.value == value end)
	self:activate_unique_index(index, menu)
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
	self.mouse_nav = true
	if self.proximity_raw == 0 then self:select_item_below_cursor()
	else self.current.selected_index = nil end
	request_render()
end

function Menu:on_wheel_up()
	self:scroll_to(self.current.scroll_y - self.scroll_step * 3)
	self:on_global_mouse_move() -- selects item below cursor
	request_render()
end

function Menu:on_wheel_down()
	self:scroll_to(self.current.scroll_y + self.scroll_step * 3)
	self:on_global_mouse_move() -- selects item below cursor
	request_render()
end

function Menu:on_pgup()
	local menu = self.current
	local items_per_page = round((menu.height / self.scroll_step) * 0.4)
	local paged_index = (menu.selected_index and menu.selected_index or #menu.items) - items_per_page
	menu.selected_index = clamp(1, paged_index, #menu.items)
	if menu.selected_index > 0 then self:scroll_to_index(menu.selected_index) end
end

function Menu:on_pgdwn()
	local menu = self.current
	local items_per_page = round((menu.height / self.scroll_step) * 0.4)
	local paged_index = (menu.selected_index and menu.selected_index or 1) + items_per_page
	menu.selected_index = clamp(1, paged_index, #menu.items)
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

function Menu:add_key_binding(key, name, fn, flags)
	self.key_bindings[#self.key_bindings + 1] = name
	mp.add_forced_key_binding(key, name, fn, flags)
end

function Menu:enable_key_bindings()
	-- The `mp.set_key_bindings()` method would be easier here, but that
	-- doesn't support 'repeatable' flag, so we are stuck with this monster.
	self:add_key_binding('up', 'menu-prev1', self:create_key_action('prev'), 'repeatable')
	self:add_key_binding('down', 'menu-next1', self:create_key_action('next'), 'repeatable')
	self:add_key_binding('left', 'menu-back1', self:create_key_action('back'))
	self:add_key_binding('right', 'menu-select1', self:create_key_action('open_selected_item_preselect'))
	self:add_key_binding('shift+right', 'menu-select-soft1', self:create_key_action('open_selected_item_soft'))
	self:add_key_binding('shift+mbtn_left', 'menu-select-soft', self:create_key_action('open_selected_item_soft'))
	self:add_key_binding('mbtn_back', 'menu-back-alt3', self:create_key_action('back'))
	self:add_key_binding('bs', 'menu-back-alt4', self:create_key_action('back'))
	self:add_key_binding('enter', 'menu-select-alt3', self:create_key_action('open_selected_item_preselect'))
	self:add_key_binding('kp_enter', 'menu-select-alt4', self:create_key_action('open_selected_item_preselect'))
	self:add_key_binding('shift+enter', 'menu-select-alt5', self:create_key_action('open_selected_item_soft'))
	self:add_key_binding('shift+kp_enter', 'menu-select-alt6', self:create_key_action('open_selected_item_soft'))
	self:add_key_binding('esc', 'menu-close', self:create_key_action('close'))
	self:add_key_binding('pgup', 'menu-page-up', self:create_key_action('on_pgup'))
	self:add_key_binding('pgdwn', 'menu-page-down', self:create_key_action('on_pgdwn'))
	self:add_key_binding('home', 'menu-home', self:create_key_action('on_home'))
	self:add_key_binding('end', 'menu-end', self:create_key_action('on_end'))
end

function Menu:disable_key_bindings()
	for _, name in ipairs(self.key_bindings) do mp.remove_key_binding(name) end
	self.key_bindings = {}
end

function Menu:create_key_action(name)
	return function(...)
		self.mouse_nav = false
		self:maybe(name, ...)
	end
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
		-- remove menu_opacity to start off with full opacity, but still decay for parent menus
		local text_opacity = opacity / options.menu_opacity

		-- Background
		ass:rect(ax, ay - (draw_title and self.item_height or 0) - 2, bx, by + 2, {
			color = bg, opacity = opacity, radius = 4,
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
			local font_color = item.active and fgt or bgt
			local shadow_color = item.active and fg or bg

			-- Separator
			local separator_ay = item.separator and item_by - 1 or item_by
			local separator_by = item_by + (item.separator and 2 or 1)
			if is_highlighted then separator_ay = item_by + 1 end
			if next_is_highlighted then separator_by = item_by end
			if separator_by - separator_ay > 0 and item_by < by then
				ass:rect(ax + spacing / 2, separator_ay, bx - spacing / 2, separator_by, {
					color = fg, opacity = opacity * (item.separator and 0.08 or 0.06),
				})
			end

			-- Highlight
			local highlight_opacity = 0 + (item.active and 0.8 or 0) + (selected_index == index and 0.15 or 0)
			if highlight_opacity > 0 then
				ass:rect(ax + 2, item_ay, bx - 2, item_by, {
					radius = 2, color = fg, opacity = highlight_opacity * text_opacity,
					clip = item_clip,
				})
			end

			-- Icon
			if item.icon then
				ass:icon(content_bx - (icon_size / 2), item_center_y, icon_size * 1.5, item.icon, {
					color = font_color, opacity = text_opacity, clip = item_clip,
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
					opacity = text_opacity * (item.muted and 0.5 or 1), clip = clip,
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
				color = fg, opacity = opacity * 0.8, radius = 2,
			})
			ass:texture(ax + 2, title_ay, bx - 2, title_ay + title_height, 'n', {
				size = 80, color = bg, opacity = opacity * 0.1,
			})

			-- Title
			ass:txt(ax + menu.width / 2, title_ay + (title_height / 2), 5, menu.title, {
				size = self.font_size, bold = true, color = bg, wrap = 2, opacity = opacity,
				clip = '\\clip(' .. ax .. ',' .. title_ay .. ',' .. bx .. ',' .. ay .. ')',
			})
		end

		-- Scrollbar
		if menu.scroll_height > 0 then
			local groove_height = menu.height - 2
			local thumb_height = math.max((menu.height / (menu.scroll_height + menu.height)) * groove_height, 40)
			local thumb_y = ay + 1 + ((menu.scroll_y / menu.scroll_height) * (groove_height - thumb_height))
			ass:rect(bx - 3, thumb_y, bx - 1, thumb_y + thumb_height, {color = fg, opacity = opacity * 0.8})
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
	speed_drag_current = clamp(0.01, speed_drag_current, 100)
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
	local visibility = self:get_visibility()
	local opacity = self.dragging and 1 or visibility

	if opacity <= 0 then return end

	local ass = assdraw.ass_new()

	-- Background
	ass:rect(self.ax, self.ay, self.bx, self.by, {color = bg, radius = 2, opacity = opacity * options.speed_opacity})

	-- Coordinates
	local ax, ay = self.ax, self.ay
	local bx, by = self.bx, ay + self.height
	local half_width = (self.width / 2)
	local half_x = ax + half_width

	-- Notches
	local speed_at_center = state.speed
	if self.dragging then
		speed_at_center = self.dragging.start_speed + self.dragging.speed_distance
		speed_at_center = clamp(0.01, speed_at_center, 100)
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
				color = fg, border = 1, border_color = bg,
				opacity = math.min(1.2 - (math.abs((notch_x - ax - half_width) / half_width)), 1) * opacity,
			})
		end
	end

	-- Center guide
	ass:new_event()
	ass:append('{\\rDefault\\an7\\blur0\\bord1\\shad0\\1c&H' .. fg .. '\\3c&H' .. bg .. '}')
	ass:opacity(opacity)
	ass:pos(0, 0)
	ass:draw_start()
	ass:move_to(half_x, by - 2 - guide_size)
	ass:line_to(half_x + guide_size, by - 2)
	ass:line_to(half_x - guide_size, by - 2)
	ass:draw_stop()

	-- Speed value
	local speed_text = (round(state.speed * 100) / 100) .. 'x'
	ass:txt(half_x, ay + (notch_ay_big - ay) / 2, 5, speed_text, {
		size = self.font_size, color = bgt, border = options.text_border, border_color = bg, opacity = opacity,
	})

	return ass
end

--[[ Button ]]

---@alias ButtonProps {icon: string; on_click: function; anchor_id?: string; active?: boolean; badge?: string|number; foreground?: string; background?: string; tooltip?: string}

---@class Button : Element
local Button = class(Element)

---@param id string
---@param props ButtonProps
function Button:new(id, props) return Class.new(self, id, props) --[[@as Button]] end
---@param id string
---@param props ButtonProps
function Button:init(id, props)
	self.icon = props.icon
	self.active = props.active
	self.tooltip = props.tooltip
	self.badge = props.badge
	self.foreground = props.foreground or fg
	self.background = props.background or bg
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
			opacity = visibility * (self.active and 1 or 0.3),
		})
	end

	-- Tooltip on hover
	if is_hover and self.tooltip then ass:tooltip(self, self.tooltip) end

	-- Badge
	local icon_clip
	if self.badge then
		local badge_font_size = self.font_size * 0.6
		local badge_width = text_width_estimate(self.badge, badge_font_size)
		local width, height = math.ceil(badge_width + (badge_font_size / 7) * 2), math.ceil(badge_font_size * 0.93)
		local bx, by = self.bx - 1, self.by - 1
		ass:rect(bx - width, by - height, bx, by, {
			color = foreground, radius = 2, opacity = visibility,
			border = self.active and 0 or 1, border_color = background,
		})
		ass:txt(bx - width / 2, by - height / 2, 5, self.badge, {
			size = badge_font_size, color = background, opacity = visibility,
		})

		local clip_border = math.max(self.font_size / 20, 1)
		local clip_path = assdraw.ass_new()
		clip_path:round_rect_cw(
			math.floor((bx - width) - clip_border), math.floor((by - height) - clip_border), bx, by, 3
		)
		icon_clip = '\\iclip(' .. clip_path.scale .. ', ' .. clip_path.text .. ')'
	end

	-- Icon
	local x, y = round(self.ax + (self.bx - self.ax) / 2), round(self.ay + (self.by - self.ay) / 2)
	ass:icon(x, y, self.font_size, self.icon, {
		color = foreground, border = self.active and 0 or options.text_border, border_color = background,
		opacity = visibility, clip = icon_clip,
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
---@param id string
---@param props CycleButtonProps
function CycleButton:init(id, props)
	local is_state_prop = itable_index_of({'shuffle'}, props.prop)
	self.prop = props.prop
	self.states = props.states

	Button.init(self, id, props)

	self.icon = self.states[1].icon
	self.active = self.states[1].active
	self.current_state_index = 1
	self.on_click = function()
		local new_state = self.states[self.current_state_index + 1] or self.states[1]
		local new_value = new_state.value
		if self.owner then
			mp.commandv('script-message-to', self.owner, 'set', self.prop, new_value)
		elseif is_state_prop then
			if itable_index_of({'yes', 'no'}, new_value) then new_value = new_value == 'yes' end
			set_state(self.prop, new_value)
		else
			mp.set_property(self.prop, new_value)
		end
	end

	self.handle_change = function(name, value)
		if is_state_prop and type(value) == 'boolean' then value = value and 'yes' or 'no' end
		local index = itable_find(self.states, function(state) return state.value == value end)
		self.current_state_index = index or 1
		self.icon = self.states[self.current_state_index].icon
		self.active = self.states[self.current_state_index].active
		request_render()
	end

	local prop_parts = split(self.prop, '@')
	if #prop_parts == 2 then -- External prop with a script owner
		self.prop, self.owner = prop_parts[1], prop_parts[2]
		self['on_external_prop_' .. self.prop] = function(_, value) self.handle_change(self.prop, value) end
		self.handle_change(self.prop, external[self.prop])
	elseif is_state_prop then -- uosc's state props
		self['on_prop_' .. self.prop] = function(self, value) self.handle_change(self.prop, value) end
		self.handle_change(self.prop, state[self.prop])
	else
		mp.observe_property(self.prop, 'string', self.handle_change)
	end
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
		ass:rect(0, 0, display.width + 1, display.height + 1, {
			color = bg, clip = clip, opacity = options.window_border_opacity,
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
		ass:rect(0, 0, display.width, display.height, {color = bg, opacity = self.opacity * 0.3})
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

--[[ BufferingIndicator ]]

---@class BufferingIndicator : Element
local BufferingIndicator = class(Element)

function BufferingIndicator:new() return Class.new(self) --[[@as BufferingIndicator]] end
function BufferingIndicator:init()
	Element.init(self, 'buffer_indicator')
	self.ignores_menu = true
	self.enabled = false
end

function BufferingIndicator:decide_enabled()
	local cache = state.cache_underrun or state.cache_buffering and state.cache_buffering < 100
	local player = state.core_idle and not state.eof_reached
	if self.enabled then
		if not player or (state.pause and not cache) then self.enabled = false end
	elseif player and cache and state.uncached_ranges then self.enabled = true end
end

function BufferingIndicator:on_prop_pause() self:decide_enabled() end
function BufferingIndicator:on_prop_core_idle() self:decide_enabled() end
function BufferingIndicator:on_prop_eof_reached() self:decide_enabled() end
function BufferingIndicator:on_prop_uncached_ranges() self:decide_enabled() end
function BufferingIndicator:on_prop_cache_buffering() self:decide_enabled() end
function BufferingIndicator:on_prop_cache_underrun() self:decide_enabled() end

function BufferingIndicator:render()
	local ass = assdraw.ass_new()
	ass:rect(0, 0, display.width, display.height, {color = bg, opacity = 0.3})
	local size = round(40 + math.min(display.width, display.height) / 8)
	local opacity = (Elements.menu and not Elements.menu.is_closing) and 0.3 or nil
	local opts = {rotate = (state.render_last_time * 2 % 1) * -360, color = fg, opacity = opacity}
	ass:icon(display.width / 2, display.height / 2, size, 'autorenew', opts)
	request_render()
	return ass
end

--[[ Timeline ]]

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
	self.enabled = not self.obstructed and state.duration and state.duration > 0 and state.time
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
function Timeline:clear_thumbnail() mp.commandv('script-message-to', 'thumbfast', 'clear') end

function Timeline:on_mbtn_left_down()
	self.pressed = true
	self:set_from_cursor()
end
function Timeline:on_prop_duration() self:decide_enabled() end
function Timeline:on_prop_time() self:decide_enabled() end
function Timeline:on_prop_border() self:update_dimensions() end
function Timeline:on_prop_fullormaxed() self:update_dimensions() end
function Timeline:on_display() self:update_dimensions() end
function Timeline:on_mouse_leave() self:clear_thumbnail() end
function Timeline:on_global_mbtn_left_up()
	self.pressed = false
	self:clear_thumbnail()
end
function Timeline:on_global_mouse_leave()
	self.pressed = false
	self:clear_thumbnail()
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

	if size < 1 then return end

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
			local ax = range[1] < 0.5 and bax or math.floor(t2x(range[1]))
			local bx = range[2] > state.duration - 0.5 and bbx or math.ceil(t2x(range[2]))
			opts.color, opts.opacity, opts.anchor_x = 'ffffff', 0.4 - (0.2 * visibility), bax
			ass:texture(ax, fay, bx, fby, texture_char, opts)
			opts.color, opts.opacity, opts.anchor_x = '000000', 0.6 - (0.2 * visibility), bax + offset
			ass:texture(ax, fay, bx, fby, texture_char, opts)
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
		-- Upcoming cache time
		if buffered_time and options.buffered_time_threshold > 0 and buffered_time < options.buffered_time_threshold then
			local x, align = fbx + 5, 4
			local font_size = self.font_size * 0.8
			local human = round(math.max(buffered_time, 0)) .. 's'
			local width = text_width_estimate(human, font_size)
			local min_x = bax + 5 + text_width_estimate(state.time_human, self.font_size)
			local max_x = bbx - 5 - text_width_estimate(state.duration_or_remaining_time_human, self.font_size)
			if x < min_x then x = min_x elseif x + width > max_x then x, align = max_x, 6 end
			draw_timeline_text(x, fcy, align, human, {size = font_size, opacity = text_opacity * 0.6, border = 1})
		end

		local opts = {size = self.font_size, opacity = text_opacity, border = 2}

		-- Elapsed time
		if state.time_human then
			draw_timeline_text(bax + spacing, fcy, 4, state.time_human, opts)
		end

		-- End time
		if state.duration_or_remaining_time_human then
			draw_timeline_text(bbx - spacing, fcy, 6, state.duration_or_remaining_time_human, opts)
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
		ass:tooltip(tooltip_anchor, format_time(hovered_seconds), {size = self.font_size, offset = 4})
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
			ass:rect(ax, ay, bx, by, {color = bg, border = 1, border_color = fg, border_opacity = 0.08, radius = 2})
			mp.commandv('script-message-to', 'thumbfast', 'thumb', hovered_seconds, thumb_x, thumb_y)
			tooltip_anchor.ax, tooltip_anchor.bx, tooltip_anchor.ay = ax, bx, ay
		end

		-- Chapter title
		if #state.chapters > 0 then
			local _, chapter = itable_find(state.chapters, function(c) return hovered_seconds >= c.time end, true)
			if chapter and not chapter.is_end_only then
				ass:tooltip(tooltip_anchor, chapter.title_wrapped, {
					size = self.font_size, offset = 10, responsive = false, bold = true,
					text_length_override = chapter.title_wrapped_width,
				})
			end
		end
	end

	return ass
end

--[[ TopBarButton ]]

---@alias TopBarButtonProps {icon: string; background: string; anchor_id?: string; command: string|fun()}

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

function TopBarButton:on_mbtn_left_down()
	mp.command(type(self.command) == 'function' and self.command() or self.command)
end

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
	ass:icon(self.ax + width / 2, self.ay + height / 2, icon_size, self.icon, {
		opacity = visibility, border = options.text_border,
	})

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

	local function decide_maximized_command()
		return state.border
			and (state.fullscreen and 'set fullscreen no;cycle window-maximized' or 'cycle window-maximized')
			or 'set window-maximized no;cycle fullscreen'
	end

	-- Order aligns from right to left
	self.buttons = {
		TopBarButton:new('tb_close', {icon = 'close', background = '2311e8', command = 'quit'}),
		TopBarButton:new('tb_max', {icon = 'crop_square', background = '222222', command = decide_maximized_command}),
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
	if options.top_bar_title and (state.title or state.has_playlist) then
		local bg_margin = math.floor((self.size - self.font_size) / 4)
		local padding = self.font_size / 2
		local title_ax = self.ax + bg_margin
		local title_ay = self.ay + bg_margin
		local max_bx = self.title_bx - self.spacing

		-- Playlist position
		if state.has_playlist then
			local text = state.playlist_pos .. '' .. state.playlist_count
			local formatted_text = '{\\b1}' .. state.playlist_pos .. '{\\b0\\fs' .. self.font_size * 0.9 .. '}/'
				.. state.playlist_count
			local bx = round(title_ax + text_length_width_estimate(#text, self.font_size) + padding * 2)
			ass:rect(title_ax, title_ay, bx, self.by - bg_margin, {color = fg, opacity = visibility, radius = 2})
			ass:txt(title_ax + (bx - title_ax) / 2, self.ay + (self.size / 2), 5, formatted_text, {
				size = self.font_size, wrap = 2, color = fgt, opacity = visibility,
			})
			title_ax = bx + bg_margin
		end

		-- Title
		if max_bx - title_ax > self.font_size * 3 then
			local text = state.title or 'n/a'
			local bx = math.min(max_bx, title_ax + text_width_estimate(text, self.font_size) + padding * 2)
			local by = self.by - bg_margin
			ass:rect(title_ax, title_ay, bx, by, {
				color = bg, opacity = visibility * options.top_bar_title_opacity, radius = 2,
			})
			ass:txt(title_ax + padding, self.ay + (self.size / 2), 4, text, {
				size = self.font_size, wrap = 2, color = bgt, border = 1, border_color = bg, opacity = visibility,
				clip = string.format('\\clip(%d, %d, %d, %d)', self.ax, self.ay, max_bx, self.by),
			})
			title_ay = by + 1
		end

		-- Subtitle: current chapter
		if state.current_chapter and max_bx - title_ax > self.font_size * 3 then
			local font_size = self.font_size * 0.8
			local height = font_size * 1.5
			local text = '└ ' .. state.current_chapter.index .. ': ' .. state.current_chapter.title
			local by = title_ay + height
			local bx = math.min(max_bx, title_ax + text_width_estimate(text, font_size) + padding * 2)
			ass:rect(title_ax, title_ay, bx, by, {
				color = bg, opacity = visibility * options.top_bar_title_opacity, radius = 2,
			})
			ass:txt(title_ax + padding, title_ay + height / 2, 4, '{\\i1}' .. text .. '{\\i0}', {
				size = font_size, wrap = 2, color = bgt, border = 1, border_color = bg, opacity = visibility * 0.8,
				clip = string.format('\\clip(%d, %d, %d, %d)', title_ax, title_ay, bx, by),
			})
		end
	end

	return ass
end

--[[ Controls ]]

-- `scale` - `options.controls_size` scale factor.
-- `ratio` - Width/height ratio of a static or dynamic element.
-- `ratio_min` Min ratio for 'dynamic' sized element.
-- `skip` - Whether it should be skipped, determined during layout phase.
---@alias ControlItem {element?: Element; kind: string; sizing: 'space' | 'static' | 'dynamic'; scale: number; ratio?: number; ratio_min?: number; hide: boolean; dispositions?: table<string, boolean>}

---@class Controls : Element
local Controls = class(Element)

function Controls:new() return Class.new(self) --[[@as Controls]] end
function Controls:init()
	Element.init(self, 'controls')
	---@type ControlItem[] All control elements serialized from `options.controls`.
	self.controls = {}
	---@type ControlItem[] Only controls that match current dispositions.
	self.layout = {}

	-- Serialize control elements
	local shorthands = {
		menu = 'command:menu:script-binding uosc/menu-blurred?Menu',
		subtitles = 'command:subtitles:script-binding uosc/subtitles#sub>0?Subtitles',
		audio = 'command:graphic_eq:script-binding uosc/audio#audio>1?Audio',
		['audio-device'] = 'command:speaker:script-binding uosc/audio-device?Audio device',
		video = 'command:theaters:script-binding uosc/video#video>1?Video',
		playlist = 'command:list_alt:script-binding uosc/playlist?Playlist',
		chapters = 'command:bookmark:script-binding uosc/chapters#chapters>0?Chapters',
		['editions'] = 'command:bookmarks:script-binding uosc/editions#editions>1?Editions',
		['stream-quality'] = 'command:high_quality:script-binding uosc/stream-quality?Stream quality',
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

	-- Parse out disposition/config pairs
	local items = {}
	local in_disposition = false
	local current_item = nil
	for c in options.controls:gmatch('.') do
		if not current_item then current_item = {disposition = '', config = ''} end
		if c == '<' and #current_item.config == 0 then in_disposition = true
		elseif c == '>' and #current_item.config == 0 then in_disposition = false
		elseif c == ',' and not in_disposition then
			items[#items + 1] = current_item
			current_item = nil
		else
			local prop = in_disposition and 'disposition' or 'config'
			current_item[prop] = current_item[prop] .. c
		end
	end
	items[#items + 1] = current_item

	-- Create controls
	self.controls = {}
	for i, item in ipairs(items) do
		local config = shorthands[item.config] and shorthands[item.config] or item.config
		local config_tooltip = split(config, ' *%? *')
		local tooltip = config_tooltip[2]
		config = shorthands[config_tooltip[1]]
			and split(shorthands[config_tooltip[1]], ' *%? *')[1] or config_tooltip[1]
		local config_badge = split(config, ' *# *')
		config = config_badge[1]
		local badge = config_badge[2]
		local parts = split(config, ' *: *')
		local kind, params = parts[1], itable_slice(parts, 2)

		-- Serialize dispositions
		local dispositions = {}
		for _, definition in ipairs(split(item.disposition, ' *, *')) do
			if #definition > 0 then
				local value = definition:sub(1, 1) ~= '!'
				local name = not value and definition:sub(2) or definition
				local prop = name:sub(1, 4) == 'has_' and name or 'is_' .. name
				dispositions[prop] = value
			end
		end

		-- Convert toggles into cycles
		if kind == 'toggle' then
			kind = 'cycle'
			params[#params + 1] = 'no/yes!'
		end

		-- Create a control element
		local control = {dispositions = dispositions, kind = kind}

		if kind == 'space' then
			control.sizing = 'space'
		elseif kind == 'gap' then
			table_assign(control, {sizing = 'dynamic', scale = 1, ratio = params[1] or 0.3, ratio_min = 0})
		elseif kind == 'command' then
			if #params ~= 2 then
				mp.error(string.format(
					'command button needs 2 parameters, %d received: %s', #params, table.concat(params, '/')
				))
			else
				local element = Button:new('control_' .. i, {
					icon = params[1],
					anchor_id = 'controls',
					on_click = function() mp.command(params[2]) end,
					tooltip = tooltip,
					count_prop = 'sub',
				})
				table_assign(control, {element = element, sizing = 'static', scale = 1, ratio = 1})
				if badge then self:register_badge_updater(badge, element) end
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
				table_assign(control, {element = element, sizing = 'static', scale = 1, ratio = 1})
				if badge then self:register_badge_updater(badge, element) end
			end
		elseif kind == 'speed' then
			if not Elements.speed then
				local element = Speed:new({anchor_id = 'controls'})
				table_assign(control, {
					element = element, sizing = 'dynamic', scale = params[1] or 1.3, ratio = 3.5, ratio_min = 2,
				})
			else
				msg.error('there can only be 1 speed slider')
			end
		else
			msg.error('unknown element kind "' .. kind .. '"')
			break
		end

		self.controls[#self.controls + 1] = control
	end

	self:reflow()
end

function Controls:reflow()
	-- Populate the layout only with items that match current disposition
	self.layout = {}
	for _, control in ipairs(self.controls) do
		local matches = true
		for prop, value in pairs(control.dispositions) do
			if state[prop] ~= value then
				matches = false
				break
			end
		end
		if control.element then control.element.enabled = matches end
		if matches then self.layout[#self.layout + 1] = control end
	end

	self:update_dimensions()
	Elements:trigger('controls_reflow')
end

---@param badge string
---@param element Element An element that supports `badge` property.
function Controls:register_badge_updater(badge, element)
	local prop_and_limit = split(badge, ' *> *')
	local prop, limit = prop_and_limit[1], tonumber(prop_and_limit[2] or -1)
	local observable_name, serializer, is_external_prop = prop, nil, false

	if itable_index_of({'sub', 'audio', 'video'}, prop) then
		observable_name = 'track-list'
		serializer = function(value)
			local count = 0
			for _, track in ipairs(value) do if track.type == prop then count = count + 1 end end
			return count
		end
	else
		local parts = split(prop, '@')
		-- Support both new `prop@owner` and old `@prop` syntaxes
		if #parts > 1 then prop, is_external_prop = parts[1] ~= '' and parts[1] or parts[2], true end
		serializer = function(value) return value and (type(value) == 'table' and #value or tostring(value)) or nil end
	end

	local function handler(_, value)
		local new_value = serializer(value) --[[@as nil|string|integer]]
		local value_number = tonumber(new_value)
		if value_number then new_value = value_number > limit and value_number or nil end
		element.badge = new_value
		request_render()
	end

	if is_external_prop then element['on_external_prop_' .. prop] = function(_, value) handler(prop, value) end
	else mp.observe_property(observable_name, 'native', handler) end
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

	-- Disable when not enough space
	local available_space = display.height - Elements.window_border.size * 2
	if Elements.top_bar.enabled then available_space = available_space - Elements.top_bar.size end
	if Elements.timeline.enabled then available_space = available_space - Elements.timeline.size_max end
	self.enabled = available_space > size + 10

	-- Reset hide/enabled flags
	for c, control in ipairs(self.layout) do
		control.hide = false
		if control.element then control.element.enabled = self.enabled end
	end

	if not self.enabled then return end

	-- Container
	self.bx = display.width - window_border - margin
	self.by = (Elements.timeline.enabled and Elements.timeline.ay or display.height - window_border) - margin
	self.ax, self.ay = window_border + margin, self.by - size

	-- Controls
	local available_width = self.bx - self.ax
	local statics_width = (#self.layout - 1) * spacing
	local min_content_width = statics_width
	local max_dynamics_width, dynamic_units, spaces = 0, 0, 0

	-- Calculate statics_width, min_content_width, and count spaces
	for c, control in ipairs(self.layout) do
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
		local i = math.ceil(#self.layout / 2 + 0.1)
		for a = 0, #self.layout - 1, 1 do
			i = i + (a * (a % 2 == 0 and 1 or -1))
			local control = self.layout[i]

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

	for c, control in ipairs(self.layout) do
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

	Elements:update_proximities()
	request_render()
end

function Controls:on_dispositions() self:reflow() end
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
	local ax, ay, bx, by = self.ax, self.ay, self.bx, self.by
	local width, height = bx - ax, by - ay

	if width <= 0 or height <= 0 or visibility <= 0 then return end

	local ass = assdraw.ass_new()
	local nudge_y, nudge_size = self.draw_nudge and self.nudge_y or -infinity, self.nudge_size
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
		local nudge_size = ((quarter_pi_sin * (nudge_size - p)) + p) / quarter_pi_sin
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
	return self.slider.pressed and 1 or Elements.timeline.proximity_raw == 0 and -1 or Element.get_visibility(self)
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

--[[ Curtain ]]

---@class Curtain : Element
local Curtain = class(Element)

function Curtain:new() return Class.new(self) --[[@as Curtain]] end
function Curtain:init()
	Element.init(self, 'curtain', {ignores_menu = true})
	self.opacity = 0
	---@type string[]
	self.dependents = {}
end

---@param id string
function Curtain:register(id)
	self.dependents[#self.dependents + 1] = id
	if #self.dependents == 1 then self:tween_property('opacity', self.opacity, 1) end
end

---@param id string
function Curtain:unregister(id)
	self.dependents = itable_filter(self.dependents, function(item) return item ~= id end)
	if #self.dependents == 0 then self:tween_property('opacity', self.opacity, 0) end
end

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
BufferingIndicator:new()
PauseIndicator:new()
TopBar:new()
Timeline:new()
if options.controls and options.controls ~= 'never' then Controls:new() end
if itable_index_of({'left', 'right'}, options.volume) then Volume:new() end
Curtain:new()

--[[ MENUS ]]

---@param data MenuData
---@param opts? {submenu?: string; mouse_nav?: boolean}
function open_command_menu(data, opts)
	local menu = Menu:open(data, function(value)
		if type(value) == 'string' then
			mp.command(value)
		else
			---@diagnostic disable-next-line: deprecated
			mp.commandv((unpack or table.unpack)(value))
		end
	end, opts)
	if opts and opts.submenu then menu:activate_submenu(opts.submenu) end
	return menu
end

---@param opts? {submenu?: string; mouse_nav?: boolean}
function toggle_menu_with_items(opts)
	if Menu:is_open('menu') then Menu:close()
	else open_command_menu({type = 'menu', items = config.menu_items}, opts) end
end

---@param options {type: string; title: string; list_prop: string; active_prop?: string; serializer: fun(list: any, active: any): MenuDataItem[]; on_select: fun(value: any)}
function create_self_updating_menu_opener(options)
	return function()
		if Menu:is_open(options.type) then Menu:close() return end
		local list = mp.get_property_native(options.list_prop)
		local active = options.active_prop and mp.get_property_native(options.active_prop) or nil
		local menu

		local function update() menu:update_items(options.serializer(list, active)) end

		local ignore_initial_list = true
		local function handle_list_prop_change(name, value)
			if ignore_initial_list then ignore_initial_list = false
			else list = value update() end
		end

		local ignore_initial_active = true
		local function handle_active_prop_change(name, value)
			if ignore_initial_active then ignore_initial_active = false
			else active = value update() end
		end

		local initial_items, selected_index = options.serializer(list, active)

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
	local function serialize_tracklist(tracklist)
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
				local hint_values = {}
				local function h(value) hint_values[#hint_values + 1] = value end

				if track.lang then h(track.lang:upper()) end
				if track['demux-h'] then
					h(track['demux-w'] and (track['demux-w'] .. 'x' .. track['demux-h']) or (track['demux-h'] .. 'p'))
				end
				if track['demux-fps'] then h(string.format('%.5gfps', track['demux-fps'])) end
				h(track.codec)
				if track['audio-channels'] then h(track['audio-channels'] .. ' channels') end
				if track['demux-samplerate'] then h(string.format('%.3gkHz', track['demux-samplerate'] / 1000)) end
				if track.forced then h('forced') end
				if track.default then h('default') end
				if track.external then h('external') end

				items[#items + 1] = {
					title = (track.title and track.title or 'Track ' .. track.id),
					hint = table.concat(hint_values, ', '),
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
		serializer = serialize_tracklist,
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
	table.sort(directories, file_order_comparator)

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
		serialized.is_directory = true
		serialized.is_to_parent = true
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

function update_cursor_position(x, y)
	-- mpv reports initial mouse position on linux as (0, 0), which always
	-- displays the top bar, so we hardcode cursor position as infinity until
	-- we receive a first real mouse move event with coordinates other than 0,0.
	if not state.first_real_mouse_move_received then
		if x > 0 and y > 0 then state.first_real_mouse_move_received = true
		else x, y = infinity, infinity end
	end

	-- add 0.5 to be in the middle of the pixel
	cursor.x, cursor.y = (x + 0.5) / display.scale_x, (y + 0.5) / display.scale_y

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

function handle_mouse_enter(x, y)
	cursor.hidden = false
	update_cursor_position(x, y)
	Elements:trigger('global_mouse_enter')
end

function handle_mouse_move(x, y)
	update_cursor_position(x, y)
	Elements:proximity_trigger('mouse_move')
	request_render()

	-- Restart timer that hides UI when mouse is autohidden
	if options.autohide then
		state.cursor_autohide_timer:kill()
		state.cursor_autohide_timer:resume()
	end
end

function handle_file_end()
	local resume = false
	if not state.loop_file then
		if state.has_playlist then resume = state.shuffle and navigate_playlist(1)
		else resume = options.autoload and navigate_directory(1) end
	end
	-- Resume only when navigation happened
	if resume then mp.command('set pause no') end
end
local file_end_timer = mp.add_timeout(1, handle_file_end)
file_end_timer:kill()

function load_file_index_in_current_directory(index)
	if not state.path or is_protocol(state.path) then return end

	local serialized = serialize_path(state.path)
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

function select_current_chapter()
	local current_chapter
	if state.time and state.chapters then
		_, current_chapter = itable_find(state.chapters, function(c) return state.time >= c.time end, true)
	end
	set_state('current_chapter', current_chapter)
end

--[[ HOOKS ]]

-- Click detection
if options.click_threshold > 0 then
	-- Executes custom command for clicks shorter than `options.click_threshold`
	-- while filtering out double clicks.
	local click_time = options.click_threshold / 1000
	local doubleclick_time = mp.get_property_native('input-doubleclick-time') / 1000
	local last_down, last_up = 0, 0
	local click_timer = mp.add_timeout(math.max(click_time, doubleclick_time), function()
		local delta = last_up - last_down
		if delta > 0 and delta < click_time and delta > 0.02 then mp.command(options.click_command) end
	end)
	click_timer:kill()
	mp.set_key_bindings({{'mbtn_left',
		function() last_up = mp.get_time() end,
		function()
			last_down = mp.get_time()
			if click_timer:is_enabled() then click_timer:kill() else click_timer:resume() end
		end,
	},}, 'mouse_movement', 'force')
	mp.enable_key_bindings('mouse_movement', 'allow-vo-dragging+allow-hide-cursor')
end

mp.observe_property('mouse-pos', 'native', function(_, mouse)
	if mouse.hover then
		if cursor.hidden then handle_mouse_enter(mouse.x, mouse.y) end
		handle_mouse_move(mouse.x, mouse.y)
	else handle_mouse_leave() end
end)
mp.observe_property('osc', 'bool', function(name, value) if value == true then mp.set_property('osc', 'no') end end)
function update_title(title_template)
	if title_template:sub(-6) == ' - mpv' then title_template = title_template:sub(1, -7) end
	set_state('title', ass_escape(mp.command_native({'expand-text', title_template})))
end
mp.register_event('file-loaded', function()
	set_state('path', normalize_path(mp.get_property_native('path')))
	update_title(mp.get_property_native('title'))
end)
mp.register_event('end-file', function(event)
	set_state('title', nil)
	if event.reason == 'eof' then
		file_end_timer:kill()
		handle_file_end()
	end
end)
do
	local hot_keywords = {'time', 'percent'}
	local timer = mp.add_periodic_timer(0.9, function() update_title(mp.get_property_native('title')) end)
	timer:kill()
	mp.observe_property('title', 'string', function(_, title)
		update_title(title)
		-- Enable periodic updates for templates with hot variables
		local is_hot = itable_find(hot_keywords, function(var) return string.find(title or '', var) ~= nil end)
		if is_hot then timer:resume() else timer:kill() end
	end)
end
mp.observe_property('playback-time', 'number', create_state_setter('time', function()
	-- Create a file-end event that triggers right before file ends
	file_end_timer:kill()
	if state.duration and state.time and not state.pause then
		local remaining = (state.duration - state.time) / state.speed
		if remaining < 5 then
			local timeout = remaining - 0.02
			if timeout > 0 then
				file_end_timer.timeout = timeout
				file_end_timer:resume()
			else handle_file_end() end
		end
	end

	update_human_times()
	select_current_chapter()
end))
mp.observe_property('duration', 'number', create_state_setter('duration', update_human_times))
mp.observe_property('speed', 'number', create_state_setter('speed', update_human_times))
mp.observe_property('track-list', 'native', function(name, value)
	-- checks the file dispositions
	local is_image = false
	local types = {sub = 0, audio = 0, video = 0}
	for _, track in ipairs(value) do
		if track.type == 'video' then
			is_image = track.image
			if not is_image and not track.albumart then types.video = types.video + 1 end
		elseif types[track.type] then types[track.type] = types[track.type] + 1 end
	end
	set_state('is_audio', types.video == 0 and types.audio > 0)
	set_state('is_image', is_image)
	set_state('has_audio', types.audio > 0)
	set_state('has_many_audio', types.audio > 1)
	set_state('has_sub', types.sub > 0)
	set_state('has_many_sub', types.sub > 1)
	set_state('is_video', types.video > 0)
	set_state('has_many_video', types.video > 1)
	Elements:trigger('dispositions')
end)
mp.observe_property('editions', 'number', function(_, editions)
	if editions then set_state('has_many_edition', editions > 1) end
	Elements:trigger('dispositions')
end)
mp.observe_property('chapter-list', 'native', function(_, chapters)
	local chapters, chapter_ranges = serialize_chapters(chapters), {}
	if chapters then chapters, chapter_ranges = serialize_chapter_ranges(chapters) end
	set_state('chapters', chapters)
	set_state('chapter_ranges', chapter_ranges)
	set_state('has_chapter', #chapters > 0)
	select_current_chapter()
	Elements:trigger('dispositions')
end)
mp.observe_property('border', 'bool', create_state_setter('border'))
mp.observe_property('loop-file', 'native', create_state_setter('loop_file'))
mp.observe_property('ab-loop-a', 'number', create_state_setter('ab_loop_a'))
mp.observe_property('ab-loop-b', 'number', create_state_setter('ab_loop_b'))
mp.observe_property('playlist-pos-1', 'number', create_state_setter('playlist_pos'))
mp.observe_property('playlist-count', 'number', function(_, value)
	set_state('playlist_count', value)
	set_state('has_playlist', value > 1)
	Elements:trigger('dispositions')
end)
mp.observe_property('fullscreen', 'bool', create_state_setter('fullscreen', update_fullormaxed))
mp.observe_property('window-maximized', 'bool', create_state_setter('maximized', update_fullormaxed))
mp.observe_property('idle-active', 'bool', function(_, idle)
	set_state('is_idle', idle)
	Elements:trigger('dispositions')
end)
mp.observe_property('pause', 'bool', create_state_setter('pause', function() file_end_timer:kill() end))
mp.observe_property('volume', 'number', create_state_setter('volume'))
mp.observe_property('volume-max', 'number', create_state_setter('volume_max'))
mp.observe_property('mute', 'bool', create_state_setter('mute'))
mp.observe_property('osd-dimensions', 'native', function(name, val)
	update_display_dimensions()
	request_render()
end)
mp.observe_property('display-hidpi-scale', 'native', create_state_setter('hidpi_scale', update_display_dimensions))
mp.observe_property('cache', 'native', create_state_setter('cache'))
mp.observe_property('cache-buffering-state', 'number', create_state_setter('cache_buffering'))
mp.observe_property('demuxer-via-network', 'native', create_state_setter('is_stream', function()
	Elements:trigger('dispositions')
end))
mp.observe_property('demuxer-cache-state', 'native', function(prop, cache_state)
	local cached_ranges, bof, eof, uncached_ranges = nil, nil, nil, nil
	if cache_state then
		cached_ranges, bof, eof = cache_state['seekable-ranges'], cache_state['bof-cached'], cache_state['eof-cached']
		set_state('cache_underrun', cache_state['underrun'])
	else cached_ranges = {} end

	if not (state.duration and (#cached_ranges > 0 or state.cache == 'yes' or
		(state.cache == 'auto' and state.is_stream))) then
		if state.uncached_ranges then set_state('uncached_ranges', nil) end
		return
	end

	-- Normalize
	local ranges = {}
	for _, range in ipairs(cached_ranges) do
		ranges[#ranges + 1] = {
			math.max(range['start'] or 0, 0),
			math.min(range['end'] or state.duration, state.duration),
		}
	end
	table.sort(ranges, function(a, b) return a[1] < b[1] end)
	if bof then ranges[1][1] = 0 end
	if eof then ranges[#ranges][2] = state.duration end
	-- Invert cached ranges into uncached ranges, as that's what we're rendering
	local inverted_ranges = {{0, state.duration}}
	for _, cached in pairs(ranges) do
		inverted_ranges[#inverted_ranges][2] = cached[1]
		inverted_ranges[#inverted_ranges + 1] = {cached[2], state.duration}
	end
	uncached_ranges = {}
	local last_range = nil
	for _, range in ipairs(inverted_ranges) do
		if last_range and last_range[2] + 0.5 > range[1] then -- fuse ranges
			last_range[2] = range[2]
		else
			if range[2] - range[1] > 0.5 then -- skip short ranges
				uncached_ranges[#uncached_ranges + 1] = range
				last_range = range
			end
		end
	end

	set_state('uncached_ranges', uncached_ranges)
end)
mp.observe_property('display-fps', 'native', observe_display_fps)
mp.observe_property('estimated-display-fps', 'native', update_render_delay)
mp.observe_property('eof-reached', 'native', create_state_setter('eof_reached'))
mp.observe_property('core-idle', 'native', create_state_setter('core_idle'))

-- KEY BINDABLE FEATURES

mp.add_key_binding(nil, 'toggle-ui', function() Elements:toggle({'timeline', 'controls', 'volume', 'top_bar'}) end)
mp.add_key_binding(nil, 'flash-ui', function() Elements:flash({'timeline', 'controls', 'volume', 'top_bar'}) end)
mp.add_key_binding(nil, 'flash-timeline', function() Elements:flash({'timeline'}) end)
mp.add_key_binding(nil, 'flash-top-bar', function() Elements:flash({'top_bar'}) end)
mp.add_key_binding(nil, 'flash-volume', function() Elements:flash({'volume'}) end)
mp.add_key_binding(nil, 'flash-speed', function() Elements:flash({'speed'}) end)
mp.add_key_binding(nil, 'flash-pause-indicator', function() Elements:flash({'pause_indicator'}) end)
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
mp.add_key_binding(nil, 'decide-pause-indicator', function() Elements.pause_indicator:decide() end)
mp.add_key_binding(nil, 'menu', function() toggle_menu_with_items() end)
mp.add_key_binding(nil, 'menu-blurred', function() toggle_menu_with_items({mouse_nav = true}) end)
local track_loaders = {
	{name = 'subtitles', prop = 'sub', allowed_types = config.subtitle_types},
	{name = 'audio', prop = 'audio', allowed_types = config.media_types},
	{name = 'video', prop = 'video', allowed_types = config.media_types},
}
for _, loader in ipairs(track_loaders) do
	local menu_type = 'load-' .. loader.name
	mp.add_key_binding(nil, menu_type, function()
		if Menu:is_open(menu_type) then Menu:close() return end

		local path = state.path
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
	serializer = function(playlist)
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
	active_prop = 'chapter',
	serializer = function(chapters, current_chapter)
		local items = {}
		chapters = normalize_chapters(chapters)
		for index, chapter in ipairs(chapters) do
			items[index] = {
				title = chapter.title or '',
				hint = mp.format_time(chapter.time),
				value = index,
				active = index - 1 == current_chapter,
			}
		end
		return items
	end,
	on_select = function(index) mp.commandv('set', 'chapter', tostring(index - 1)) end,
}))
mp.add_key_binding(nil, 'editions', create_self_updating_menu_opener({
	title = 'Editions',
	type = 'editions',
	list_prop = 'edition-list',
	active_prop = 'current-edition',
	serializer = function(editions, current_id)
		local items = {}
		for _, edition in ipairs(editions or {}) do
			items[#items + 1] = {
				title = edition.title or 'Edition',
				hint = tostring(edition.id + 1),
				value = edition.id,
				active = edition.id == current_id,
			}
		end
		return items
	end,
	on_select = function(id) mp.commandv('set', 'edition', id) end,
}))
mp.add_key_binding(nil, 'show-in-directory', function()
	-- Ignore URLs
	if not state.path or is_protocol(state.path) then return end

	if state.os == 'windows' then
		utils.subprocess_detached({args = {'explorer', '/select,', state.path}, cancellable = false})
	elseif state.os == 'macos' then
		utils.subprocess_detached({args = {'open', '-R', state.path}, cancellable = false})
	elseif state.os == 'linux' then
		local result = utils.subprocess({args = {'nautilus', state.path}, cancellable = false})

		-- Fallback opens the folder with xdg-open instead
		if result.status ~= 0 then
			utils.subprocess({args = {'xdg-open', serialize_path(state.path).dirname}, cancellable = false})
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

		-- Tries to determine live stream vs. pre-recorded VOD. VOD has non-zero
		-- duration property. When reloading VOD, to keep the current time position
		-- we should provide offset from the start. Stream doesn't have fixed start.
		-- Decent choice would be to reload stream from it's current 'live' position.
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

	local directory
	local active_file

	if state.path == nil or is_protocol(state.path) then
		local serialized = serialize_path(get_default_directory())
		if serialized then
			directory = serialized.path
			active_file = nil
		end
	else
		local serialized = serialize_path(state.path)
		if serialized then
			directory = serialized.dirname
			active_file = serialized.path
		end
	end

	if not directory then
		msg.error('Couldn\'t serialize path "' .. state.path .. '".')
		return
	end

	-- Update active file in directory navigation menu
	local function handle_file_loaded()
		if Menu:is_open('open-file') then
			Elements.menu:activate_value(normalize_path(mp.get_property_native('path')))
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
mp.add_key_binding(nil, 'shuffle', function() set_state('shuffle', not state.shuffle) end)
mp.add_key_binding(nil, 'items', function()
	if state.has_playlist then
		mp.command('script-binding uosc/playlist')
	else
		mp.command('script-binding uosc/open-file')
	end
end)
mp.add_key_binding(nil, 'next', function() navigate_item(1) end)
mp.add_key_binding(nil, 'prev', function() navigate_item(-1) end)
mp.add_key_binding(nil, 'next-file', function() navigate_directory(1) end)
mp.add_key_binding(nil, 'prev-file', function() navigate_directory(-1) end)
mp.add_key_binding(nil, 'first', function()
	if state.has_playlist then
		mp.commandv('set', 'playlist-pos-1', '1')
	else
		load_file_index_in_current_directory(1)
	end
end)
mp.add_key_binding(nil, 'last', function()
	if state.has_playlist then
		mp.commandv('set', 'playlist-pos-1', tostring(state.playlist_count))
	else
		load_file_index_in_current_directory(-1)
	end
end)
mp.add_key_binding(nil, 'first-file', function() load_file_index_in_current_directory(1) end)
mp.add_key_binding(nil, 'last-file', function() load_file_index_in_current_directory(-1) end)
mp.add_key_binding(nil, 'delete-file-next', function()
	local next_file = nil
	local is_local_file = state.path and not is_protocol(state.path)

	if is_local_file then
		if Menu:is_open('open-file') then Elements.menu:delete_value(state.path) end
	end

	if state.has_playlist then
		mp.commandv('playlist-remove', 'current')
	else
		if is_local_file then
			local paths, current_index = get_adjacent_paths(state.path, config.media_types)
			if paths and current_index then
				local index, path = decide_navigation_in_list(paths, current_index, 1)
				if path then next_file = path end
			end
		end

		if next_file then mp.commandv('loadfile', next_file)
		else mp.commandv('stop') end
	end

	if is_local_file then delete_file(state.path) end
end)
mp.add_key_binding(nil, 'delete-file-quit', function()
	mp.command('stop')
	if state.path and not is_protocol(state.path) then delete_file(state.path) end
	mp.command('quit')
end)
mp.add_key_binding(nil, 'audio-device', create_self_updating_menu_opener({
	title = 'Audio devices',
	type = 'audio-device-list',
	list_prop = 'audio-device-list',
	active_prop = 'audio-device',
	serializer = function(audio_device_list, current_device)
		current_device = current_device or 'auto'
		local ao = mp.get_property('current-ao') or ''
		local items = {}
		for _, device in ipairs(audio_device_list) do
			if device.name == 'auto' or string.match(device.name, '^' .. ao) then
				local hint = string.match(device.name, ao .. '/(.+)')
				if not hint then hint = device.name end
				items[#items + 1] = {
					title = device.description,
					hint = hint,
					active = device.name == current_device,
					value = device.name,
				}
			end
		end
		return items
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

mp.register_script_message('show-submenu', function(id) toggle_menu_with_items({submenu = id}) end)
mp.register_script_message('get-version', function(script)
	mp.commandv('script-message-to', script, 'uosc-version', config.version)
end)
mp.register_script_message('open-menu', function(json, submenu_id)
	local data = utils.parse_json(json)
	if type(data) ~= 'table' or type(data.items) ~= 'table' then
		msg.error('open-menu: received json didn\'t produce a table with menu configuration')
	else
		if data.type and Menu:is_open(data.type) then Menu:close()
		else open_command_menu(data, {submenu_id = submenu_id}) end
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
mp.register_script_message('thumbfast-info', function(json)
	local data = utils.parse_json(json)
	if type(data) ~= 'table' or not data.width or not data.height then
		thumbnail.disabled = true
		msg.error('thumbfast-info: received json didn\'t produce a table with thumbnail information')
	else
		thumbnail = data
		request_render()
	end
end)
mp.register_script_message('set', function(name, value)
	external[name] = value
	Elements:trigger('external_prop_' .. name, value)
end)
mp.register_script_message('toggle-elements', function(elements) Elements:toggle(split(elements, ' *, *')) end)
mp.register_script_message('flash-elements', function(elements) Elements:flash(split(elements, ' *, *')) end)
