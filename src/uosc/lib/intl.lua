local intl_dir = mp.get_script_directory() .. '/intl/'
local locale = {}

-- https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/supported-languages?pivots=store-installer-msix#list-of-supported-languages
function get_languages()
	local languages = {}

	for _, lang in ipairs(comma_split(options.languages)) do
		if (lang == 'slang') then
			local slang = mp.get_property_native('slang')
			if slang then
				itable_append(languages, slang)
			end
		else
			languages[#languages +1] = lang
		end
	end

	return languages
end

---@param path string
function get_locale_from_json(path)
	local expand_path = mp.command_native({'expand-path', path})

	local meta, meta_error = utils.file_info(expand_path)
	if not meta or not meta.is_file then
		return nil
	end

	local json_file = io.open(expand_path, 'r')
	if not json_file then
		return nil
	end

	local json = json_file:read('*all')
	json_file:close()

	local json_table = utils.parse_json(json)
	return json_table
end

---@param path string
function make_locale(path)
	local translations = {}
	local languages = get_languages()
	for i = #languages, 1, -1 do
		lang = languages[i]
		if (lang:match('.json$')) then
			table_assign(translations, get_locale_from_json(lang))
		elseif (lang == 'en') then
			translations = {}
		else
			table_assign(translations, get_locale_from_json(path .. lang:lower() .. '.json'))
		end
	end

	return translations
end

---@param text string
function t(text, ...)
	if not text then
		return ''
	end

	local trans = locale[text] or text

	local arg = { ... }
	if #arg > 0 then
		local key = text
		for _, value in ipairs(arg) do
			key = key .. '|' .. value
		end
		if not locale[key] then
			locale[key] = string.format(trans, unpack(arg))
		end
		return locale[key]
	end

	return trans
end

---@param path? string
function get_locale(path)
	local locale_copy = table_copy(locale)
	if (path) then
		path = trim_end(trim_end(path, '\\'), '/') .. '/'
		table_assign(locale_copy, make_locale(path))
	end
	return locale_copy
end

locale = make_locale(intl_dir)

return { t = t, get_locale = get_locale }
