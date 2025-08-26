local Element = require('elements/Element')
local dots = {'.', '..', '...'}

local function cleanup_output(output)
	return tostring(output):gsub('%c*\n%c*', '\n'):match('^[%s%c]*(.-)[%s%c]*$')
end

---@class Updater : Element
local Updater = class(Element)

function Updater:new() return Class.new(self) --[[@as Updater]] end
function Updater:init()
	Element.init(self, 'updater', {render_order = 1000})
	self.output = nil
	self.title = ''
	self.state = 'circle' -- Also used as an icon name. 'pending' maps to 'spinner'.
	self.update_available = false

	-- Buttons
	self.check_button = {method = 'check', title = t('Check for updates')}
	self.update_button = {method = 'update', title = t('Update uosc'), color = config.color.success}
	self.changelog_button = {method = 'open_changelog', title = t('Open changelog')}
	self.close_button = {method = 'destroy', title = t('Close') .. ' (Esc)', color = config.color.error}
	self.quit_button = {method = 'quit', title = t('Quit')}
	self.buttons = {self.check_button, self.close_button}
	self.selected_button_index = 1

	-- Key bindings
	self:add_key_binding('right', 'select_next_button')
	self:add_key_binding('tab', 'select_next_button')
	self:add_key_binding('left', 'select_prev_button')
	self:add_key_binding('shift+tab', 'select_prev_button')
	self:add_key_binding('enter', 'activate_selected_button')
	self:add_key_binding('kp_enter', 'activate_selected_button')
	self:add_key_binding('esc', 'destroy')

	Elements:maybe('curtain', 'register', self.id)
	self:check()
end

function Updater:destroy()
	Elements:maybe('curtain', 'unregister', self.id)
	Element.destroy(self)
end

function Updater:quit()
	mp.command('quit')
end

function Updater:select_prev_button()
	self.selected_button_index = self.selected_button_index - 1
	if self.selected_button_index < 1 then self.selected_button_index = #self.buttons end
	request_render()
end

function Updater:select_next_button()
	self.selected_button_index = self.selected_button_index + 1
	if self.selected_button_index > #self.buttons then self.selected_button_index = 1 end
	request_render()
end

function Updater:activate_selected_button()
	local button = self.buttons[self.selected_button_index]
	if button then self[button.method](self) end
end

---@param msg string
function Updater:append_output(msg)
	self.output = (self.output or '') .. ass_escape('\n' .. cleanup_output(msg))
	request_render()
end

---@param msg string
function Updater:display_error(msg)
	self.state = 'error'
	self.title = t('An error has occurred.') .. ' ' .. t('See console for details.')
	self:append_output(msg)
	print(msg)
end

function Updater:open_changelog()
	if self.state == 'pending' then return end

	local url = 'https://github.com/tomasklaen/uosc/releases'

	self:append_output('Opening URL: ' .. url)

	call_ziggy_async({'open', url}, function(error)
		if error then
			self:display_error(error)
			return
		end
	end)
end

function Updater:check()
	if self.state == 'pending' then return end
	self.state = 'pending'
	self.title = t('Checking for updates') .. '...'

	local url = 'https://api.github.com/repos/tomasklaen/uosc/releases/latest'
	local headers = utils.format_json({
		Accept = 'application/vnd.github+json',
	})
	local args = {'http-get', '--headers', headers, url}

	self:append_output('Fetching: ' .. url)

	call_ziggy_async(args, function(error, response)
		if error then
			self:display_error(error)
			return
		end

		release = utils.parse_json(type(response.body) == 'string' and response.body or '')
		if response.status == 200 and type(release) == 'table' and type(release.tag_name) == 'string' then
			self.update_available = config.version ~= release.tag_name
			self:append_output('Response: 200 OK')
			self:append_output('Current version: ' .. config.version)
			self:append_output('Latest version: ' .. release.tag_name)
			if self.update_available then
				self.state = 'upgrade'
				self.title = t('Update available')
				self.buttons = {self.update_button, self.changelog_button, self.close_button}
				self.selected_button_index = 1
			else
				self.state = 'done'
				self.title = t('Up to date')
			end
		else
			self:display_error('Response couldn\'t be parsed, is invalid, or not-OK status code.\nStatus: ' ..
				response.status .. '\nBody: ' .. response.body)
		end

		request_render()
	end)
end

function Updater:update()
	if self.state == 'pending' then return end
	self.state = 'pending'
	self.title = t('Updating uosc')
	self.output = nil
	request_render()

	local config_dir = mp.command_native({'expand-path', '~~/'})

	local function handle_result(success, result, error)
		if success and result and result.status == 0 then
			self.state = 'done'
			self.title = t('uosc has been installed. Restart mpv for it to take effect.')
			self.buttons = {self.quit_button, self.close_button}
			self.selected_button_index = 1
		else
			self.state = 'error'
			self.title = t('An error has occurred.') .. ' ' .. t('See above for clues.')
		end

		local output = (result.stdout or '') .. '\n' .. (error or result.stderr or '')
		if state.platform == 'darwin' then
			output =
				'Self-updater is known not to work on MacOS.\nIf you know about a solution, please make an issue and share it with us!.\n' ..
				output
		end
		self:append_output(output)
	end

	local function update(args)
		local env = utils.get_env_list()
		env[#env + 1] = 'MPV_CONFIG_DIR=' .. config_dir

		mp.command_native_async({
			name = 'subprocess',
			capture_stderr = true,
			capture_stdout = true,
			playback_only = false,
			args = args,
			env = env,
		}, handle_result)
	end

	if state.platform == 'windows' then
		local url = 'https://raw.githubusercontent.com/tomasklaen/uosc/HEAD/installers/windows.ps1'
		update({'powershell', '-NoProfile', '-Command', 'irm ' .. url .. ' | iex'})
	else
		-- Detect missing dependencies. We can't just let the process run and
		-- report an error, as on snap packages there's no error. Everything
		-- either exits with 0, or no helpful output/error message.
		local missing = {}

		for _, name in ipairs({'curl', 'unzip'}) do
			local result = mp.command_native({
				name = 'subprocess',
				capture_stdout = true,
				playback_only = false,
				args = {'which', name},
			})
			local path = cleanup_output(result and result.stdout or '')
			if path == '' then
				missing[#missing + 1] = name
			end
		end

		if #missing > 0 then
			local stderr = 'Missing dependencies: ' .. table.concat(missing, ', ')
			if config_dir:match('/snap/') then
				stderr = stderr ..
					'\nThis is a known error for mpv snap packages.\nYou can still update uosc by entering the Linux install command from uosc\'s readme into your terminal, it just can\'t be done this way.\nIf you know about a solution, please make an issue and share it with us!'
			end
			handle_result(false, {stderr = stderr})
		else
			local url = 'https://raw.githubusercontent.com/tomasklaen/uosc/HEAD/installers/unix.sh'
			update({'/bin/bash', '-c', 'source <(curl -fsSL ' .. url .. ')'})
		end
	end
end

function Updater:render()
	local ass = assdraw.ass_new()

	local text_size = math.min(20 * state.scale, display.height / 20)
	local icon_size = text_size * 2
	local center_x = round(display.width / 2)

	local color = fg
	if self.state == 'done' or self.update_available then
		color = config.color.success
	elseif self.state == 'error' then
		color = config.color.error
	end

	-- Divider
	local divider_width = round(math.min(500 * state.scale, display.width * 0.8))
	local divider_half, divider_border_half, divider_y = divider_width / 2, round(1 * state.scale), display.height * 0.65
	local divider_ay, divider_by = round(divider_y - divider_border_half), round(divider_y + divider_border_half)
	ass:rect(center_x - divider_half, divider_ay, center_x - icon_size, divider_by, {
		color = color, border = options.text_border * state.scale, border_color = bg, opacity = 0.5,
	})
	ass:rect(center_x + icon_size, divider_ay, center_x + divider_half, divider_by, {
		color = color, border = options.text_border * state.scale, border_color = bg, opacity = 0.5,
	})
	if self.state == 'pending' then
		ass:spinner(center_x, divider_y, icon_size, {
			color = fg, border = options.text_border * state.scale, border_color = bg,
		})
	else
		ass:icon(center_x, divider_y, icon_size * 0.8, self.state, {
			color = color, border = options.text_border * state.scale, border_color = bg,
		})
	end

	-- Output
	local output = self.output or dots[math.ceil((mp.get_time() % 1) * #dots)]
	ass:txt(center_x, divider_y - icon_size, 2, output, {
		size = text_size, color = fg, border = options.text_border * state.scale, border_color = bg,
	})

	-- Title
	ass:txt(center_x, divider_y + icon_size, 5, self.title, {
		size = text_size, bold = true, color = color, border = options.text_border * state.scale, border_color = bg,
	})

	-- Buttons
	local outline = round(1 * state.scale)
	local spacing = outline * 9
	local padding = round(text_size * 0.5)

	local text_opts = {size = text_size, bold = true}

	-- Calculate button text widths
	local total_width = (#self.buttons - 1) * spacing
	for _, button in ipairs(self.buttons) do
		button.width = text_width(button.title, text_opts) + padding * 2
		total_width = total_width + button.width
	end

	-- Render buttons
	local ay = round(divider_y + icon_size * 1.8)
	local ax = round(display.width / 2 - total_width / 2)
	local height = text_size + padding * 2
	for index, button in ipairs(self.buttons) do
		local rect = {
			ax = ax,
			ay = ay,
			bx = ax + button.width,
			by = ay + height,
		}
		ax = rect.bx + spacing
		local is_hovered = get_point_to_rectangle_proximity(cursor, rect) <= 0

		-- Background
		ass:rect(rect.ax, rect.ay, rect.bx, rect.by, {
			color = button.color or fg,
			radius = state.radius,
			opacity = is_hovered and 1 or 0.8,
		})
		-- Selected outline
		if index == self.selected_button_index then
			ass:rect(rect.ax - outline * 4, rect.ay - outline * 4, rect.bx + outline * 4, rect.by + outline * 4, {
				border = outline,
				border_color = button.color or fg,
				radius = state.radius + outline * 4,
				opacity = {primary = 0, border = 0.5},
			})
		end
		-- Text
		local x, y = rect.ax + (rect.bx - rect.ax) / 2, rect.ay + (rect.by - rect.ay) / 2
		ass:txt(x, y, 5, button.title, {size = text_size, bold = true, color = fgt})

		cursor:zone('primary_down', rect, self:create_action(button.method))

		-- Select hovered button
		if is_hovered then self.selected_button_index = index end
	end

	return ass
end

return Updater
