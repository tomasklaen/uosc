--[[ ASSDRAW EXTENSIONS ]]

local ass_mt = getmetatable(assdraw.ass_new())

-- Opacity.
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

-- Tooltip.
---@param element {ax: number; ay: number; bx: number; by: number}
---@param value string|number
---@param opts? {size?: number; offset?: number; bold?: boolean; italic?: boolean; width_overwrite?: number, responsive?: boolean}
function ass_mt:tooltip(element, value, opts)
	opts = opts or {}
	opts.size = opts.size or 16
	opts.border = options.text_border
	opts.border_color = bg
	local offset = opts.offset or opts.size / 2
	local align_top = opts.responsive == false or element.ay - offset > opts.size * 2
	local x = element.ax + (element.bx - element.ax) / 2
	local y = align_top and element.ay - offset or element.by + offset
	local margin = (opts.width_overwrite or text_width(value, opts)) / 2 + 10
	self:txt(clamp(margin, x, display.width - margin), y, align_top and 2 or 8, value, opts)
end

-- Rectangle.
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
