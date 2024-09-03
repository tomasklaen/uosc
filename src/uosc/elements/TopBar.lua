local Element = require('elements/Element')

---@alias TopBarButtonProps {icon: string; hover_fg?: string; hover_bg?: string; command: (fun():string)}

---@class TopBar : Element
local TopBar = class(Element)

function TopBar:new() return Class.new(self) --[[@as TopBar]] end
function TopBar:init()
	Element.init(self, 'top_bar', {render_order = 4})
	self.size = 0
	self.icon_size, self.font_size, self.title_by = 1, 1, 1
	self.show_alt_title = false
	self.main_title, self.alt_title = nil, nil

	local function maximized_command()
		if state.platform == 'windows' then
			mp.command(state.border
				and (state.fullscreen and 'set fullscreen no;cycle window-maximized' or 'cycle window-maximized')
				or 'set window-maximized no;cycle fullscreen')
		else
			mp.command(state.fullormaxed and 'set fullscreen no;set window-maximized no' or 'set window-maximized yes')
		end
	end

	local close = {icon = 'close', hover_bg = '2311e8', hover_fg = 'ffffff', command = function() mp.command('quit') end}
	local max = {icon = 'crop_square', command = maximized_command}
	local min = {icon = 'minimize', command = function() mp.command('cycle window-minimized') end}
	self.buttons = options.top_bar_controls == 'left' and {close, max, min} or {min, max, close}

	self:decide_titles()
	self:decide_enabled()
	self:update_dimensions()
end

function TopBar:decide_enabled()
	if options.top_bar == 'no-border' then
		self.enabled = not state.border or state.title_bar == false or state.fullscreen
	else
		self.enabled = options.top_bar == 'always'
	end
	self.enabled = self.enabled and (options.top_bar_controls or options.top_bar_title ~= 'no' or state.has_playlist)
end

function TopBar:decide_titles()
	self.alt_title = state.alt_title ~= '' and state.alt_title or nil
	self.main_title = state.title ~= '' and state.title or nil

	if (self.main_title == 'No file') then
		self.main_title = t('No file')
	end

	-- Fall back to alt title if main is empty
	if not self.main_title then
		self.main_title, self.alt_title = self.alt_title, nil
	end

	-- Deduplicate the main and alt titles by checking if one completely
	-- contains the other, and using only the longer one.
	if self.main_title and self.alt_title and not self.show_alt_title then
		local longer_title, shorter_title
		if #self.main_title < #self.alt_title then
			longer_title, shorter_title = self.alt_title, self.main_title
		else
			longer_title, shorter_title = self.main_title, self.alt_title
		end

		local escaped_shorter_title = regexp_escape(shorter_title --[[@as string]])
		if string.match(longer_title --[[@as string]], escaped_shorter_title) then
			self.main_title, self.alt_title = longer_title, nil
		end
	end
end

function TopBar:update_dimensions()
	self.size = round(options.top_bar_size * state.scale)
	self.icon_size = round(self.size * 0.5)
	self.font_size = math.floor((self.size - (math.ceil(self.size * 0.25) * 2)) * options.font_scale)
	local window_border_size = Elements:v('window_border', 'size', 0)
	self.ax = window_border_size
	self.ay = window_border_size
	self.bx = display.width - window_border_size
	self.by = self.size + window_border_size
end

function TopBar:toggle_title()
	if options.top_bar_alt_title_place ~= 'toggle' then return end
	self.show_alt_title = not self.show_alt_title
	request_render()
end

function TopBar:on_prop_title() self:decide_titles() end
function TopBar:on_prop_alt_title() self:decide_titles() end

function TopBar:on_prop_border()
	self:decide_enabled()
	self:update_dimensions()
end

function TopBar:on_prop_title_bar()
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

function TopBar:on_prop_has_playlist()
	self:decide_enabled()
	self:update_dimensions()
end

function TopBar:on_display() self:update_dimensions() end

function TopBar:on_options()
	self:decide_enabled()
	self:update_dimensions()
end

function TopBar:render()
	local visibility = self:get_visibility()
	if visibility <= 0 then return end
	local ass = assdraw.ass_new()
	local ax, bx = self.ax, self.bx
	local margin = math.floor((self.size - self.font_size) / 4)

	-- Window controls
	if options.top_bar_controls then
		local is_left, button_ax = options.top_bar_controls == 'left', 0
		if is_left then
			button_ax = ax
			ax = self.size * #self.buttons
		else
			button_ax = bx - self.size * #self.buttons
			bx = button_ax
		end

		for _, button in ipairs(self.buttons) do
			local rect = {ax = button_ax, ay = self.ay, bx = button_ax + self.size, by = self.by}
			local is_hover = get_point_to_rectangle_proximity(cursor, rect) == 0
			local opacity = is_hover and 1 or config.opacity.controls
			local button_fg = is_hover and (button.hover_fg or bg) or fg
			local button_bg = is_hover and (button.hover_bg or fg) or bg

			cursor:zone('primary_click', rect, button.command)

			local bg_size = self.size - margin
			local bg_ax, bg_ay = rect.ax + (is_left and margin or 0), rect.ay + margin
			local bg_bx, bg_by = bg_ax + bg_size, bg_ay + bg_size

			ass:rect(bg_ax, bg_ay, bg_bx, bg_by, {
				color = button_bg, opacity = visibility * opacity, radius = state.radius,
			})

			ass:icon(bg_ax + bg_size / 2, bg_ay + bg_size / 2, bg_size * 0.5, button.icon, {
				color = button_fg,
				border_color = button_bg,
				opacity = visibility,
				border = options.text_border * state.scale,
			})

			button_ax = button_ax + self.size
		end
	end

	-- Window title
	if state.title or state.has_playlist then
		local padding = self.font_size / 2
		local spacing = 1
		local left_aligned = options.top_bar_controls == 'left'
		local title_ax, title_bx, title_ay = ax + margin, bx - margin, self.ay + margin

		-- Playlist position
		if state.has_playlist then
			local text = state.playlist_pos .. '' .. state.playlist_count
			local formatted_text = '{\\b1}' .. state.playlist_pos .. '{\\b0\\fs' .. self.font_size * 0.9 .. '}/'
				.. state.playlist_count
			local opts = {size = self.font_size, wrap = 2, color = fgt, opacity = visibility}
			local rect_width = round(text_width(text, opts) + padding * 2)
			local ax = left_aligned and title_bx - rect_width or title_ax
			local rect = {
				ax = ax,
				ay = title_ay,
				bx = ax + rect_width,
				by = self.by - margin,
			}
			local opacity = get_point_to_rectangle_proximity(cursor, rect) == 0
				and 1 or config.opacity.playlist_position
			if opacity > 0 then
				ass:rect(rect.ax, rect.ay, rect.bx, rect.by, {
					color = fg, opacity = visibility * opacity, radius = state.radius,
				})
			end
			ass:txt(rect.ax + (rect.bx - rect.ax) / 2, rect.ay + (rect.by - rect.ay) / 2, 5, formatted_text, opts)
			if left_aligned then title_bx = rect.ax - margin else title_ax = rect.bx + margin end

			-- Click action
			cursor:zone('primary_click', rect, function() mp.command('script-binding uosc/playlist') end)
		end

		-- Skip rendering titles if there's not enough horizontal space
		if title_bx - title_ax > self.font_size * 3 and options.top_bar_title ~= 'no' then
			-- Main title
			local main_title = self.show_alt_title and self.alt_title or self.main_title
			if main_title then
				local opts = {
					size = self.font_size,
					wrap = 2,
					color = bgt,
					opacity = visibility,
					border = options.text_border * state.scale,
					border_color = bg,
					clip = string.format('\\clip(%d, %d, %d, %d)', self.ax, self.ay, title_bx, self.by),
				}
				local rect_ideal_width = round(text_width(main_title, opts) + padding * 2)
				local rect_width = math.min(rect_ideal_width, title_bx - title_ax)
				local ax = left_aligned and title_bx - rect_width or title_ax
				local by = self.by - margin
				local title_rect = {ax = ax, ay = title_ay, bx = ax + rect_width, by = by}

				if options.top_bar_alt_title_place == 'toggle' then
					cursor:zone('primary_click', title_rect, function() self:toggle_title() end)
				end

				ass:rect(title_rect.ax, title_rect.ay, title_rect.bx, title_rect.by, {
					color = bg, opacity = visibility * config.opacity.title, radius = state.radius,
				})
				local align = left_aligned and rect_ideal_width == rect_width and 6 or 4
				local x = align == 6 and title_rect.bx - padding or ax + padding
				ass:txt(x, self.ay + (self.size / 2), align, main_title, opts)
				title_ay = by + spacing
			end

			-- Alt title
			if self.alt_title and options.top_bar_alt_title_place == 'below' then
				local font_size = self.font_size * 0.9
				local height = font_size * 1.3
				local by = title_ay + height
				local opts = {
					size = font_size,
					wrap = 2,
					color = bgt,
					border = options.text_border * state.scale,
					border_color = bg,
					opacity = visibility,
				}
				local rect_ideal_width = round(text_width(self.alt_title, opts) + padding * 2)
				local rect_width = math.min(rect_ideal_width, title_bx - title_ax)
				local ax = left_aligned and title_bx - rect_width or title_ax
				local bx = ax + rect_width
				opts.clip = string.format('\\clip(%d, %d, %d, %d)', title_ax, title_ay, bx, by)
				ass:rect(ax, title_ay, bx, by, {
					color = bg, opacity = visibility * config.opacity.title, radius = state.radius,
				})
				local align = left_aligned and rect_ideal_width == rect_width and 6 or 4
				local x = align == 6 and bx - padding or ax + padding
				ass:txt(x, title_ay + height / 2, align, self.alt_title, opts)
				title_ay = by + spacing
			end

			-- Current chapter
			if state.current_chapter then
				local padding_half = round(padding / 2)
				local font_size = self.font_size * 0.8
				local height = font_size * 1.3
				local prefix, postfix = left_aligned and '' or '└ ', left_aligned and ' ┘' or ''
				local text = prefix .. state.current_chapter.index .. ': ' .. state.current_chapter.title .. postfix
				local next_chapter = state.chapters[state.current_chapter.index + 1]
				local chapter_end = next_chapter and next_chapter.time or state.duration or 0
				local remaining_time = ((state.time or 0) - chapter_end) /
					(options.destination_time == 'time-remaining' and 1 or state.speed)
				local remaining_human = format_time(remaining_time, math.abs(remaining_time))
				local opts = {
					size = font_size,
					italic = true,
					wrap = 2,
					color = bgt,
					border = options.text_border * state.scale,
					border_color = bg,
					opacity = visibility * 0.8,
				}
				local remaining_width = timestamp_width(remaining_human, opts)
				local remaining_box_width = remaining_width + padding_half * 2

				-- Title
				local max_bx = title_bx - remaining_box_width - spacing
				local rect_ideal_width = round(text_width(text, opts) + padding * 2)
				local rect_width = math.min(rect_ideal_width, max_bx - title_ax)
				local ax = left_aligned and title_bx - rect_width or title_ax
				local rect = {
					ax = ax,
					ay = title_ay,
					bx = ax + rect_width,
					by = title_ay + height,
				}
				opts.clip = string.format('\\clip(%d, %d, %d, %d)', title_ax, title_ay, rect.bx, rect.by)
				ass:rect(rect.ax, rect.ay, rect.bx, rect.by, {
					color = bg, opacity = visibility * config.opacity.title, radius = state.radius,
				})
				local align = left_aligned and rect_ideal_width == rect_width and 6 or 4
				local x = align == 6 and rect.bx - padding or rect.ax + padding
				ass:txt(x, rect.ay + height / 2, align, text, opts)

				-- Click action
				cursor:zone('primary_click', rect, function() mp.command('script-binding uosc/chapters') end)

				-- Time
				rect.ax = left_aligned and rect.ax - spacing - remaining_box_width or rect.bx + spacing
				rect.bx = rect.ax + remaining_box_width
				opts.clip = nil
				ass:rect(rect.ax, rect.ay, rect.bx, rect.by, {
					color = bg, opacity = visibility * config.opacity.title, radius = state.radius,
				})
				ass:txt(rect.ax + padding_half, rect.ay + height / 2, 4, remaining_human, opts)

				title_ay = rect.by + spacing
			end
		end
		self.title_by = title_ay - 1
	else
		self.title_by = self.ay
	end

	return ass
end

return TopBar
