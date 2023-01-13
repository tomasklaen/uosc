--[[ UI specific utilities that might or might not depend on its state or options ]]

-- Sorting comparator close to (but not exactly) how file explorers sort files.
sort_filenames = (function()
	local symbol_order
	local default_order

	if state.os == 'windows' then
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

	-- Alphanumeric sorting for humans in Lua
	-- http://notebook.kulchenko.com/algorithms/alphanumeric-natural-sorting-for-humans-in-lua
	local function pad_number(n, d)
		return #d > 0 and ("%03d%s%.12f"):format(#n, n, tonumber(d) / (10 ^ #d))
			or ("%03d%s"):format(#n, n)
	end

	--- In place sorting of filenames
	---@param filenames string[]
	return function(filenames)
		local tuples = {}
		for i, filename in ipairs(filenames) do
			local first_char = filename:sub(1, 1)
			local order = symbol_order[first_char] or default_order
			local formatted = filename:lower():gsub('0*(%d+)%.?(%d*)', pad_number)
			tuples[i] = {order, formatted, filename}
		end
		table.sort(tuples, function(a, b)
			if a[1] ~= b[1] then return a[1] < b[1] end
			return a[2] == b[2] and #b[3] < #a[3] or a[2] < b[2]
		end)
		for i, tuple in ipairs(tuples) do filenames[i] = tuple[3] end
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

-- Extracts the properties used by property expansion of that string.
---@param str string
---@param res { [string] : boolean } | nil
---@return { [string] : boolean }
function get_expansion_props(str, res)
	res = res or {}
	for str in str:gmatch('%$(%b{})') do
		local name, str = str:match('^{[?!]?=?([^:]+):?(.*)}$')
		if name then
			local s = name:find('==') or nil
			if s then name = name:sub(0, s - 1) end
			res[name] = true
			if str and str ~= '' then get_expansion_props(str, res) end
		end
	end
	return res
end

-- Escape a string for verbatim display on the OSD.
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

path_separator = (function()
	local os_separator = state.os == 'windows' and '\\' or '/'

	-- Get appropriate path separator for the given path.
	---@param path string
	---@return string
	return function(path)
		return path:sub(1, 2) == '\\\\' and '\\' or os_separator
	end
end)()

-- Joins paths with the OS aware path separator or UNC separator.
---@param p1 string
---@param p2 string
---@return string
function join_path(p1, p2)
	local p1, separator = trim_trailing_separator(p1)
	-- Prevents joining drive letters with a redundant separator (`C:\\foo`),
	-- as `trim_trailing_separator()` doesn't trim separators from drive letters.
	return p1:sub(#p1) == separator and p1 .. p2 or p1 .. separator.. p2
end

-- Check if path is absolute.
---@param path string
---@return boolean
function is_absolute(path)
	if path:sub(1, 2) == '\\\\' then return true
	elseif state.os == 'windows' then return path:find('^%a+:') ~= nil
	else return path:sub(1, 1) == '/' end
end

-- Ensure path is absolute.
---@param path string
---@return string
function ensure_absolute(path)
	if is_absolute(path) then return path end
	return join_path(state.cwd, path)
end

-- Remove trailing slashes/backslashes.
---@param path string
---@return string path, string trimmed_separator_type
function trim_trailing_separator(path)
	local separator = path_separator(path)
	path = trim_end(path, separator)
	if state.os == 'windows' then
		-- Drive letters on windows need trailing backslash
		if path:sub(#path) == ':' then path = path .. '\\' end
	else
		if path == '' then path = '/' end
	end
	return path, separator
end

-- Ensures path is absolute, remove trailing slashes/backslashes.
-- Lightweight version of normalize_path for performance critical parts.
---@param path string
---@return string
function normalize_path_lite(path)
	if not path or is_protocol(path) then return path end
	path = trim_trailing_separator(ensure_absolute(path))
	return path
end

-- Ensures path is absolute, remove trailing slashes/backslashes, normalization of path separators and deduplication.
---@param path string
---@return string
function normalize_path(path)
	if not path or is_protocol(path) then return path end

	path = ensure_absolute(path)
	local is_unc = path:sub(1, 2) == '\\\\'
	if state.os == 'windows' or is_unc then path = path:gsub('/', '\\') end
	path = trim_trailing_separator(path)

	--Deduplication of path separators
	if is_unc then path = path:gsub('(.\\)\\+', '%1')
	elseif state.os == 'windows' then path = path:gsub('\\\\+', '\\')
	else path = path:gsub('//+', '/') end

	return path
end

-- Check if path is a protocol, such as `http://...`.
---@param path string
function is_protocol(path)
	return type(path) == 'string' and (path:find('^%a[%a%d-_]+://') ~= nil or path:find('^%a[%a%d-_]+:\\?') ~= nil)
end

---@param path string
---@param extensions string[] Lowercase extensions without the dot.
function has_any_extension(path, extensions)
	local path_last_dot_index = string_last_index_of(path, '.')
	if not path_last_dot_index then return false end
	local path_extension = path:sub(path_last_dot_index + 1):lower()
	for _, extension in ipairs(extensions) do
		if path_extension == extension then return true end
	end
	return false
end

---@return string
function get_default_directory()
	return mp.command_native({'expand-path', options.default_directory})
end

-- Serializes path into its semantic parts.
---@param path string
---@return nil|{path: string; is_root: boolean; dirname?: string; basename: string; filename: string; extension?: string;}
function serialize_path(path)
	if not path or is_protocol(path) then return end

	local normal_path = normalize_path_lite(path)
	local dirname, basename = utils.split_path(normal_path)
	if basename == '' then basename, dirname = dirname:sub(1, #dirname - 1), nil end
	local dot_i = string_last_index_of(basename, '.')

	return {
		path = normal_path,
		is_root = dirname == nil,
		dirname = dirname,
		basename = basename,
		filename = dot_i and basename:sub(1, dot_i - 1) or basename,
		extension = dot_i and basename:sub(dot_i + 1) or nil,
	}
end

-- Reads items in directory and splits it into directories and files tables.
---@param path string
---@param allowed_types? string[] Filter `files` table to contain only files with these extensions.
---@return string[]|nil files
---@return string[]|nil directories
function read_directory(path, allowed_types)
	local items, error = utils.readdir(path, 'all')

	if not items then
		msg.error('Reading files from "' .. path .. '" failed: ' .. error)
		return nil, nil
	end

	local files, directories = {}, {}

	for _, item in ipairs(items) do
		if item ~= '.' and item ~= '..' then
			local info = utils.file_info(join_path(path, item))
			if info then
				if info.is_file then
					if not allowed_types or has_any_extension(item, allowed_types) then
						files[#files + 1] = item
					end
				else directories[#directories + 1] = item end
			end
		end
	end

	return files, directories
end

-- Returns full absolute paths of files in the same directory as file_path,
-- and index of the current file in the table.
---@param file_path string
---@param allowed_types? string[]
function get_adjacent_files(file_path, allowed_types)
	local current_file = serialize_path(file_path)
	if not current_file then return end
	local files = read_directory(current_file.dirname, allowed_types)
	if not files then return end
	sort_filenames(files)
	local current_file_index
	local paths = {}
	for index, file in ipairs(files) do
		paths[#paths + 1] = join_path(current_file.dirname, file)
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
	local paths, current_index = get_adjacent_files(state.path, config.media_types)
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
	if state.os == 'windows' then
		if options.use_trash then
            local ps_code = [[
				Add-Type -AssemblyName Microsoft.VisualBasic
				[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile('__path__', 'OnlyErrorDialogs', 'SendToRecycleBin')
			]]

            local escaped_path = string.gsub(path, "'", "''")
            escaped_path = string.gsub(escaped_path, "’", "’’")
            escaped_path = string.gsub(escaped_path, "%%", "%%%%")
            ps_code = string.gsub(ps_code, "__path__", escaped_path)
		    args = { 'powershell', '-NoProfile', '-Command', ps_code }
		else
			args = { 'cmd', '/C', 'del', path }
		end
	else
		if options.use_trash then
			--On Linux and Macos the app trash-cli/trash must be installed first.
		    args = { 'trash', path }
	    else
		    args = { 'rm', path }
		end
	end
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
	--- timeline font size isn't accessible here, so normalize to size 1 and then scale during rendering
	local opts = {size = 1, bold = true}
	for index, chapter in ipairs(chapters) do
		chapter.index = index
		chapter.title_wrapped = wrap_text(chapter.title, opts, 25)
		chapter.title_wrapped_width = text_width(chapter.title_wrapped, opts)
		chapter.title_wrapped = ass_escape(chapter.title_wrapped)
	end
	return chapters
end

--[[ RENDERING ]]

function render()
	if not display.initialized then return end
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
