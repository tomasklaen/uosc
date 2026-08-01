--[[ ASSDRAW EXTENSIONS ]]

local ass_mt = getmetatable(assdraw.ass_new())

-- Opacity.
---@param self table|nil
---@param opacity number|{primary?: number; border?: number, shadow?: number, main?: number} Opacity of all elements.
---@param fraction? number Optionally adjust the above opacity by this fraction.
---@return string|nil
function ass_mt.opacity(self, opacity, fraction)
	fraction = fraction ~= nil and fraction or 1
	opacity = type(opacity) == 'table' and opacity or {main = opacity}
	local text = ''
	if opacity.main then
		text = text .. string.format('\\alpha&H%X&', opacity_to_alpha(opacity.main * fraction))
	end
	if opacity.primary then
		text = text .. string.format('\\1a&H%X&', opacity_to_alpha(opacity.primary * fraction))
	end
	if opacity.border then
		text = text .. string.format('\\3a&H%X&', opacity_to_alpha(opacity.border * fraction))
	end
	if opacity.shadow then
		text = text .. string.format('\\4a&H%X&', opacity_to_alpha(opacity.shadow * fraction))
	end
	if self == nil then
		return text
	elseif text ~= '' then
		self.text = self.text .. '{' .. text .. '}'
	end
end

-- Icon.
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

-- Text.
-- Named `txt` because `ass.text` is a value.
---@param x number
---@param y number
---@param align number
---@param value string|number
---@param opts {size: number; font?: string; color?: string; bold?: boolean; italic?: boolean; border?: number; border_color?: string; shadow?: number; shadow_color?: string; rotate?: number; wrap?: number; opacity?: number|{primary?: number; border?: number, shadow?: number, main?: number}; clip?: string}
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
	if opts.opacity then tags = tags .. self.opacity(nil, opts.opacity) end
	-- clip
	if opts.clip then tags = tags .. opts.clip end
	-- render
	self:new_event()
	self.text = self.text .. '{' .. tags .. '}' .. value
end

-- Tooltip.
---@param element Rect
---@param value string|number
---@param opts? {size?: number; align?: number; offset?: number; bold?: boolean; italic?: boolean; width_overwrite?: number, margin?: number; responsive?: boolean; lines?: integer, timestamp?: boolean; invert_colors?: boolean}
function ass_mt:tooltip(element, value, opts)
	if value == '' then return end
	opts = opts or {}
	opts.size = opts.size or round(16 * state.scale)
	opts.border = options.text_border * state.scale
	opts.border_color = opts.invert_colors and fg or bg
	opts.margin = opts.margin or round(10 * state.scale)
	opts.lines = opts.lines or 1
	opts.color = opts.invert_colors and bg or fg
	local offset = opts.offset or 2
	local padding_y = round(opts.size / 6)
	local padding_x = round(opts.size / 3)
	local width = (opts.width_overwrite or text_width(value, opts)) + padding_x * 2
	local height = opts.size * opts.lines + 2 * padding_y
	local width_half, height_half = width / 2, height / 2
	local margin = opts.margin + Elements:v('window_border', 'size', 0)
	local align = opts.align or 8

	local x, y = 0, 0 -- center of tooltip

	-- Flip alignment to other side when not enough space
	if opts.responsive ~= false then
		if align == 8 then
			if element.ay - offset - height < margin then align = 2 end
		elseif align == 2 then
			if element.by + offset + height > display.height - margin then align = 8 end
		elseif align == 6 then
			if element.bx + offset + width > display.width - margin then align = 4 end
		elseif align == 4 then
			if element.ax - offset - width < margin then align = 6 end
		end
	end

	-- Calculate tooltip center based on alignment
	if align == 8 or align == 2 then
		x = clamp(margin + width_half, element.ax + (element.bx - element.ax) / 2, display.width - margin - width_half)
		y = align == 8 and element.ay - offset - height_half or element.by + offset + height_half
	else
		x = align == 6 and element.bx + offset + width_half or element.ax - offset - width_half
		y = clamp(margin + height_half, element.ay + (element.by - element.ay) / 2, display.height - margin - height_half)
	end

	-- Draw
	local ax, ay, bx, by = round(x - width_half), round(y - height_half), round(x + width_half), round(y + height_half)
	self:rect(ax, ay, bx, by, {
		color = opts.invert_colors and fg or bg, opacity = config.opacity.tooltip, radius = state.radius
	})
	local func = opts.timestamp and self.timestamp or self.txt
	func(self, x, y, 5, tostring(value), opts)
	return {ax = element.ax, ay = ay, bx = element.bx, by = by}
end

-- Timestamp with each digit positioned as if it was replaced with 0
---@param x number
---@param y number
---@param align number
---@param timestamp string
---@param opts {size: number; opacity?: number|{primary?: number; border?: number, shadow?: number, main?: number}}
function ass_mt:timestamp(x, y, align, timestamp, opts)
	local widths, width_total = {}, 0
	zero_rep = timestamp_zero_rep(timestamp)
	for i = 1, #zero_rep do
		local width = text_width(zero_rep:sub(i, i), opts)
		widths[i] = width
		width_total = width_total + width
	end

	-- shift x and y to fit align 5
	local mod_align = align % 3
	if mod_align == 0 then
		x = x - width_total
	elseif mod_align == 2 then
		x = x - width_total / 2
	end
	if align < 4 then
		y = y - opts.size / 2
	elseif align > 6 then
		y = y + opts.size / 2
	end

	local opacity = opts.opacity
	local primary_opacity
	if type(opacity) == 'table' then
		opts.opacity = {main = opacity.main, border = opacity.border, shadow = opacity.shadow, primary = 0}
		primary_opacity = opacity.primary or opacity.main
	else
		opts.opacity = {main = opacity, primary = 0}
		primary_opacity = opacity
	end
	for i, width in ipairs(widths) do
		self:txt(x + width / 2, y, 5, timestamp:sub(i, i), opts)
		x = x + width
	end
	x = x - width_total
	opts.opacity = {main = 0, primary = primary_opacity or 1}
	for i, width in ipairs(widths) do
		self:txt(x + width / 2, y, 5, timestamp:sub(i, i), opts)
		x = x + width
	end
	opts.opacity = opacity
end

-- Rectangle.
---@param ax number
---@param ay number
---@param bx number
---@param by number
---@param opts? {color?: string; border?: number; border_color?: string; opacity?: number|{primary?: number; border?: number, shadow?: number, main?: number}; clip?: string, radius?: number}
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
	if opts.opacity then tags = tags .. self.opacity(nil, opts.opacity) end
	-- clip
	if opts.clip then
		tags = tags .. opts.clip
	end
	-- draw
	self:new_event()
	self.text = self.text .. '{' .. tags .. '}'
	self:draw_start()
	if opts.radius and opts.radius > 0 then
		self:round_rect_cw(ax, ay, bx, by, opts.radius)
	else
		self:rect_cw(ax, ay, bx, by)
	end
	self:draw_stop()
end

-- Circle.
---@param x number
---@param y number
---@param radius number
---@param opts? {color?: string; border?: number; border_color?: string; opacity?: number; clip?: string}
function ass_mt:circle(x, y, radius, opts)
	opts = opts or {}
	opts.radius = radius
	self:rect(x - radius, y - radius, x + radius, y + radius, opts)
end

-- Texture.
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

-- Rotating spinner icon.
---@param x number
---@param y number
---@param size number
---@param opts? {color?: string; opacity?: number; clip?: string; border?: number; border_color?: string;}
function ass_mt:spinner(x, y, size, opts)
	opts = opts or {}
	opts.rotate = (state.render_last_time * 1.75 % 1) * -360
	opts.color = opts.color or fg
	self:icon(x, y, size, 'autorenew', opts)
	request_render()
end

-- Renders a smooth curve from Bezier segments.
---@param ax number
---@param ay number
---@param bx number
---@param by number
---@param points number[] Flat table of normalized points (0–1): start point followed by segment entries cp1x, cp1y, cp2x, cp2y, px, py, ...
---@param opts? {color?: string; border?: number; border_color?: string; opacity?: number|{primary?: number; border?: number, shadow?: number, main?: number}; clip?: string}
function ass_mt:smooth_curve(ax, ay, bx, by, points, opts)
	if not points or #points < 8 then return end
	opts = opts or {}
	local border_size = opts.border or 0
	local tags = '\\pos(0,0)\\rDefault\\an7\\blur0'
	-- border
	tags = tags .. '\\bord' .. border_size
	-- colors
	tags = tags .. '\\1c&H' .. (opts.color or fg)
	if border_size > 0 then tags = tags .. '\\3c&H' .. (opts.border_color or bg) end
	-- opacity
	if opts.opacity then tags = tags .. self.opacity(nil, opts.opacity) end
	-- clip
	if opts.clip then tags = tags .. opts.clip end
	-- draw
	self:new_event()
	self.text = self.text .. '{' .. tags .. '}'
	self:draw_start()

	-- Scale normalized (0–1) coordinates to rectangle bounds
	local width, height = bx - ax, by - ay
	local function scale(x, y)
		return ax + x * width, ay + y * height
	end

	local x0, y0 = scale(points[1], points[2])
	self:move_to(x0, y0)
	local max = math.floor((#points - 2) / 6) * 6 + 2
	for i = 3, max, 6 do
		local x1, y1 = scale(points[i],   points[i+1])
		local x2, y2 = scale(points[i+2], points[i+3])
		local x3, y3 = scale(points[i+4], points[i+5])
		self:bezier_curve(x1, y1, x2, y2, x3, y3)
	end
	self:draw_stop()
end