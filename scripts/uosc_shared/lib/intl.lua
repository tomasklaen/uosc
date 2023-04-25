local intl_directories = {'~~/scripts/uosc_shared/intl/'}
local locale = {}
local cache = {}
local reload_timer = nil

-- https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/supported-languages?pivots=store-installer-msix#list-of-supported-languages
function get_languages()
	local languages = {}
	for _, lang in ipairs(split(options.languages, ',')) do
		if (lang == 'slang') then
			local slang = mp.get_property_native('slang')
			if slang then
				itable_append(languages, slang)
			end
		else
			itable_append(languages, { lang })
		end
	end

	return languages
end

---@param path string
function get_locale_from_json(path)
	local expand_path = mp.command_native({ 'expand-path', path })

	local meta, meta_error = utils.file_info(expand_path)
	if not meta or not meta.is_file then
		return {}
	end

	local json_file = io.open(expand_path, 'r')
	if not json_file then
		return {}
	end

	local json = json_file:read('*all')
	json_file:close()

	return utils.parse_json(json)
end

function make_locale()
	local translations = {}
	local languages = get_languages()
	for i = #languages, 1, -1 do
		lang = languages[i]
		if (lang:match('.json$')) then
			table_assign(translations, get_locale_from_json(lang))
		elseif (lang == 'en') then
			translations = {}
		else
			for _, path in ipairs(intl_directories) do
				table_assign(translations, get_locale_from_json(path .. lang:lower() .. '.json'))
			end
		end
	end

	return translations
end

function reload()
	reload_timer, cache = nil, {}
	locale = make_locale()
end

---@param path string
function add_directory(path)
	path = trim_end(trim_end(path, '\\'), '/') .. '/'
	if itable_index_of(intl_directories, path) then return end
	intl_directories[#intl_directories + 1] = path
	if not reload_timer then
		reload_timer = mp.add_timeout(0.1, reload)
	end
end

---@param text string
function t(text, a)
	if not text then return '' end
	local key = text
	if a then key = key .. '|' .. a end
	if cache[key] then return cache[key] end
	cache[key] = string.format(locale[text] or text, a or '')
	return cache[key]
end

reload()

return {t = t, add_directory = add_directory}
