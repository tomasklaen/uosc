local Element = require('uosc_shared/elements/Element')

-- Menu data structure accepted by `Menu:open(menu)`.
---@alias MenuData {type?: string; title?: string; hint?: string; keep_open?: boolean; separator?: boolean; items?: MenuDataItem[]; selected_index?: integer;}
---@alias MenuDataItem MenuDataValue|MenuData
---@alias MenuDataValue {title?: string; hint?: string; icon?: string; value: any; bold?: boolean; italic?: boolean; muted?: boolean; active?: boolean; keep_open?: boolean; separator?: boolean;}
---@alias MenuOptions {mouse_nav?: boolean; on_open?: fun(); on_close?: fun(); on_back?: fun(); on_move_item?: fun(from_index: integer, to_index: integer, submenu_path: integer[]); on_delete_item?: fun(index: integer, submenu_path: integer[])}

-- Internal data structure created from `Menu`.
---@alias MenuStack {id?: string; type?: string; title?: string; hint?: string; selected_index?: number; keep_open?: boolean; separator?: boolean; items: MenuStackItem[]; parent_menu?: MenuStack; submenu_path: integer[]; active?: boolean; width: number; height: number; top: number; scroll_y: number; scroll_height: number; title_width: number; hint_width: number; max_width: number; is_root?: boolean; fling?: Fling}
---@alias MenuStackItem MenuStackValue|MenuStack
---@alias MenuStackValue {title?: string; hint?: string; icon?: string; value: any; active?: boolean; bold?: boolean; italic?: boolean; muted?: boolean; keep_open?: boolean; separator?: boolean; title_width: number; hint_width: number}
---@alias Fling {y: number, distance: number, time: number, easing: fun(x: number), duration: number, update_cursor?: boolean}

---@alias Modifiers {shift?: boolean, ctrl?: boolean, alt?: boolean}
---@alias MenuCallbackMeta {modifiers: Modifiers}
---@alias MenuCallback fun(value: any, meta: MenuCallbackMeta)

---@class Menu : Element
local Menu = class(Element)

---@param data MenuData
---@param callback MenuCallback
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
			cursor.queue_autohide()
			if callback then callback() end
			request_render()
		end

		menu.is_closing = true

		if immediate then close()
		else menu:fadeout(close) end
	end
end

---@param data MenuData
---@param callback MenuCallback
---@param opts? MenuOptions
---@return Menu
function Menu:new(data, callback, opts) return Class.new(self, data, callback, opts) --[[@as Menu]] end
---@param data MenuData
---@param callback MenuCallback
---@param opts? MenuOptions
function Menu:init(data, callback, opts)
	Element.init(self, 'menu', {ignores_menu = true})

	-----@type fun()
	self.callback = callback
	self.opts = opts or {}
	self.offset_x = 0 -- Used for submenu transition animation.
	self.mouse_nav = self.opts.mouse_nav -- Stops pre-selecting items
	---@type Modifiers|nil
	self.modifiers = nil
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
	self.is_closing, self.is_closed = false, false
	---@type {y: integer, time: number}[]
	self.drag_data = nil
	self.is_dragging = false

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
	self.is_closed = true
	if not self.is_being_replaced then Elements.curtain:unregister('menu') end
	if self.opts.on_close then self.opts.on_close() end
end

---@param data MenuData
function Menu:update(data)
	self.type = data.type

	local new_root = {is_root = true, submenu_path = {}}
	local new_all = {}
	local new_by_id = {}
	local menus_to_serialize = {{new_root, data}}
	local old_current_id = self.current and self.current.id

	table_assign(new_root, data, {'type', 'title', 'hint', 'keep_open'})

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

			-- Submenu
			if item_data.items then
				item.parent_menu = menu
				item.submenu_path = itable_join(menu.submenu_path, {i})
				menus_to_serialize[#menus_to_serialize + 1] = {item, item_data}
			end

			menu.items[i] = item
		end

		if menu.is_root then menu.selected_index = menu_data.selected_index or first_active_index end

		-- Retain old state
		local old_menu = self.by_id[menu.is_root and '__root__' or menu.id]
		if old_menu then table_assign(menu, old_menu, {'selected_index', 'scroll_y', 'fling'}) end

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

	local title_opts = {size = self.font_size, italic = false, bold = false}
	local hint_opts = {size = self.font_size_hint}

	for _, menu in ipairs(self.all) do
		title_opts.bold, title_opts.italic = true, false
		local max_width = text_width(menu.title, title_opts) + 2 * self.item_padding

		-- Estimate width of a widest item
		for _, item in ipairs(menu.items) do
			local icon_width = item.icon and self.font_size or 0
			item.title_width = text_width(item.title, title_opts)
			item.hint_width = text_width(item.hint, hint_opts)
			local spacings_in_item = 1 + (item.title_width > 0 and 1 or 0)
				+ (item.hint_width > 0 and 1 or 0) + (icon_width > 0 and 1 or 0)
			local estimated_width = item.title_width + item.hint_width + icon_width
				+ (self.item_padding * spacings_in_item)
			if estimated_width > max_width then max_width = estimated_width end
		end

		menu.max_width = max_width
	end

	self:update_dimensions()
end

function Menu:update_dimensions()
	-- Coordinates and sizes are of the scrollable area to make
	-- consuming values in rendering and collisions easier. Title is rendered
	-- above it, so we need to account for that in max_height and ay position.
	local min_width = state.fullormaxed and options.menu_min_width_fullscreen or options.menu_min_width

	for _, menu in ipairs(self.all) do
		menu.width = round(clamp(min_width, menu.max_width, display.width * 0.9))
		local title_height = (menu.is_root and menu.title) and self.scroll_step or 0
		local max_height = round((display.height - title_height) * 0.9)
		local content_height = self.scroll_step * #menu.items
		menu.height = math.min(content_height - self.item_spacing, max_height)
		menu.top = round(math.max((display.height - menu.height) / 2, title_height * 1.5))
		menu.scroll_height = math.max(content_height - menu.height - self.item_spacing, 0)
		menu.scroll_y = menu.scroll_y or 0
		self:scroll_to(menu.scroll_y, menu) -- clamps scroll_y to scroll limits
	end

	self:update_coordinates()
end

-- Updates element coordinates to match currently open (sub)menu.
function Menu:update_coordinates()
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
function Menu:set_scroll_to(pos, menu)
	menu = menu or self.current
	menu.scroll_y = clamp(0, pos or 0, menu.scroll_height)
	request_render()
end

---@param delta? number
---@param menu? MenuStack
function Menu:set_scroll_by(delta, menu)
	menu = menu or self.current
	self:set_scroll_to(menu.scroll_y + delta, menu)
end

---@param pos? number
---@param menu? MenuStack
---@param fling_options? table
function Menu:scroll_to(pos, menu, fling_options)
	menu = menu or self.current
	menu.fling = {
		y = menu.scroll_y, distance = clamp(-menu.scroll_y, pos - menu.scroll_y, menu.scroll_height - menu.scroll_y),
		time = mp.get_time(), duration = 0.1, easing = ease_out_sext,
	}
	if fling_options then table_assign(menu.fling, fling_options) end
	request_render()
end

---@param delta? number
---@param menu? MenuStack
---@param fling_options? Fling
function Menu:scroll_by(delta, menu, fling_options)
	menu = menu or self.current
	self:scroll_to((menu.fling and (menu.fling.y + menu.fling.distance) or menu.scroll_y) + delta, menu, fling_options)
end

---@param index? integer
---@param menu? MenuStack
---@param immediate? boolean
function Menu:scroll_to_index(index, menu, immediate)
	menu = menu or self.current
	if (index and index >= 1 and index <= #menu.items) then
		local position = round((self.scroll_step * (index - 1)) - ((menu.height - self.scroll_step) / 2))
		if immediate then self:set_scroll_to(position, menu)
		else self:scroll_to(position, menu) end
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
	local index = itable_find(menu.items, function(item) return item.value == value end)
	self:select_index(index)
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
function Menu:activate_one_index(index, menu)
	self:deactivate_items(menu)
	self:activate_index(index, menu)
end

---@param value? any
---@param menu? MenuStack
function Menu:activate_value(value, menu)
	menu = menu or self.current
	local index = itable_find(menu.items, function(item) return item.value == value end)
	self:activate_index(index, menu)
end

---@param value? any
---@param menu? MenuStack
function Menu:activate_one_value(value, menu)
	menu = menu or self.current
	local index = itable_find(menu.items, function(item) return item.value == value end)
	self:activate_one_index(index, menu)
end

---@param menu MenuStack One of menus in `self.all`.
function Menu:activate_menu(menu)
	if itable_index_of(self.all, menu) then
		self.current = menu
		self:update_coordinates()
		self:reset_navigation()
		request_render()
	else
		msg.error('Attempt to open a menu not in `self.all` list.')
	end
end

---@param id string
function Menu:activate_submenu(id)
	local submenu = self.by_id[id]
	if submenu then self:activate_menu(submenu)
	else msg.error(string.format('Requested submenu id "%s" doesn\'t exist', id)) end
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
	local index = itable_find(menu.items, function(item) return item.value == value end)
	self:delete_index(index)
end

---@param menu? MenuStack
function Menu:prev(menu)
	menu = menu or self.current
	menu.selected_index = math.max(menu.selected_index and menu.selected_index - 1 or #menu.items, 1)
	self:scroll_to_index(menu.selected_index, menu, true)
end

---@param menu? MenuStack
function Menu:next(menu)
	menu = menu or self.current
	menu.selected_index = math.min(menu.selected_index and menu.selected_index + 1 or 1, #menu.items)
	self:scroll_to_index(menu.selected_index, menu, true)
end

function Menu:back()
	if self.opts.on_back then
		self.opts.on_back()
		if self.is_closed then return end
	end

	local menu = self.current
	local parent = menu.parent_menu

	if parent then
		menu.selected_index = nil
		self:activate_menu(parent)
		self:tween(self.offset_x - menu.width / 2, 0, function(offset) self:set_offset_x(offset) end)
		self.opacity = 1 -- in case tween above canceled fade in animation
	else
		self:close()
	end
end

---@param opts? {keep_open?: boolean, preselect_submenu_item?: boolean}
function Menu:open_selected_item(opts)
	opts = opts or {}
	local menu = self.current
	if menu.selected_index then
		local item = menu.items[menu.selected_index]
		-- Is submenu
		if item.items then
			if opts.preselect_submenu_item then
				item.selected_index = #item.items > 0 and 1 or nil
			end
			self:activate_menu(item)
			self:tween(self.offset_x + menu.width / 2, 0, function(offset) self:set_offset_x(offset) end)
			self.opacity = 1 -- in case tween above canceled fade in animation
		else
			self.callback(item.value, {modifiers = self.modifiers or {}})
			if not item.keep_open and not opts.keep_open then self:close() end
		end
	end
end

function Menu:open_selected_item_soft() self:open_selected_item({keep_open = true}) end
function Menu:open_selected_item_preselect() self:open_selected_item({preselect_submenu_item = true}) end
function Menu:select_item_below_cursor() self.current.selected_index = self:get_item_index_below_cursor() end

---@param index integer
function Menu:move_selected_item_to(index)
	local from, callback = self.current.selected_index, self.opts.on_move_item
	if callback and from and from ~= index and index >= 1 and index <= #self.current.items then
		callback(from, index, self.current.submenu_path)
		self.current.selected_index = index
		request_render()
	end
end

function Menu:move_selected_item_up()
	if self.current.selected_index then self:move_selected_item_to(self.current.selected_index - 1) end
end

function Menu:move_selected_item_down()
	if self.current.selected_index then self:move_selected_item_to(self.current.selected_index + 1) end
end

function Menu:delete_selected_item()
	local index, callback = self.current.selected_index, self.opts.on_delete_item
	if callback and index then callback(index, self.current.submenu_path) end
end

function Menu:on_display() self:update_dimensions() end
function Menu:on_prop_fullormaxed() self:update_content_dimensions() end

function Menu:handle_cursor_down()
	if self.proximity_raw == 0 then
		self.drag_data = {{y = cursor.y, time = mp.get_time()}}
		self.current.fling = nil
	else
		if cursor.x < self.ax and self.current.parent_menu then self:back()
		else self:close() end
	end
end

function Menu:fling_distance()
	local first, last = self.drag_data[1], self.drag_data[#self.drag_data]
	if mp.get_time() - last.time > 0.05 then return 0 end
	for i = #self.drag_data - 1, 1, -1 do
		local drag = self.drag_data[i]
		if last.time - drag.time > 0.03 then return ((drag.y - last.y) / ((last.time - drag.time) / 0.03)) * 10 end
	end
	return #self.drag_data < 2 and 0 or ((first.y - last.y) / ((first.time - last.time) / 0.03)) * 10
end

function Menu:handle_cursor_up()
	if self.proximity_raw == 0 and self.drag_data and not self.is_dragging then
		self:select_item_below_cursor()
		self:open_selected_item({preselect_submenu_item = false, keep_open = self.modifiers and self.modifiers.shift})
	end
	if self.is_dragging then
		local distance = self:fling_distance()
		if math.abs(distance) > 50 then
			self.current.fling = {
				y = self.current.scroll_y, distance = distance, time = self.drag_data[#self.drag_data].time,
				easing = ease_out_quart, duration = 0.5, update_cursor = true,
			}
		end
	end
	self.is_dragging = false
	self.drag_data = nil
end


function Menu:on_global_mouse_move()
	self.mouse_nav = true
	if self.drag_data then
		self.is_dragging = self.is_dragging or math.abs(cursor.y - self.drag_data[1].y) >= 10
		local distance = self.drag_data[#self.drag_data].y - cursor.y
		if distance ~= 0 then self:set_scroll_by(distance) end
		self.drag_data[#self.drag_data + 1] = {y = cursor.y, time = mp.get_time()}
	end
	if self.proximity_raw == 0 or self.is_dragging then self:select_item_below_cursor()
	else self.current.selected_index = nil end
	request_render()
end

function Menu:handle_wheel_up() self:scroll_by(self.scroll_step * -3, nil, {update_cursor = true}) end
function Menu:handle_wheel_down() self:scroll_by(self.scroll_step * 3, nil, {update_cursor = true}) end

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
	self:add_key_binding('ctrl+up', 'menu-move-up', self:create_key_action('move_selected_item_up'), 'repeatable')
	self:add_key_binding('ctrl+down', 'menu-move-down', self:create_key_action('move_selected_item_down'), 'repeatable')
	self:add_key_binding('left', 'menu-back1', self:create_key_action('back'))
	self:add_key_binding('right', 'menu-select1', self:create_key_action('open_selected_item_preselect'))
	self:add_key_binding('shift+right', 'menu-select-soft1',
		self:create_key_action('open_selected_item_soft', {shift = true}))
	self:add_key_binding('shift+mbtn_left', 'menu-select3', self:create_modified_mbtn_left_handler({shift = true}))
	self:add_key_binding('ctrl+mbtn_left', 'menu-select4', self:create_modified_mbtn_left_handler({ctrl = true}))
	self:add_key_binding('mbtn_back', 'menu-back-alt3', self:create_key_action('back'))
	self:add_key_binding('bs', 'menu-back-alt4', self:create_key_action('back'))
	self:add_key_binding('enter', 'menu-select-alt3', self:create_key_action('open_selected_item_preselect'))
	self:add_key_binding('kp_enter', 'menu-select-alt4', self:create_key_action('open_selected_item_preselect'))
	self:add_key_binding('ctrl+enter', 'menu-select-ctrl1',
		self:create_key_action('open_selected_item_preselect', {ctrl = true}))
	self:add_key_binding('ctrl+kp_enter', 'menu-select-ctrl2',
		self:create_key_action('open_selected_item_preselect', {ctrl = true}))
	self:add_key_binding('shift+enter', 'menu-select-alt5',
		self:create_key_action('open_selected_item_soft', {shift = true}))
	self:add_key_binding('shift+kp_enter', 'menu-select-alt6',
		self:create_key_action('open_selected_item_soft', {shift = true}))
	self:add_key_binding('esc', 'menu-close', self:create_key_action('close'))
	self:add_key_binding('pgup', 'menu-page-up', self:create_key_action('on_pgup'), 'repeatable')
	self:add_key_binding('pgdwn', 'menu-page-down', self:create_key_action('on_pgdwn'), 'repeatable')
	self:add_key_binding('home', 'menu-home', self:create_key_action('on_home'))
	self:add_key_binding('end', 'menu-end', self:create_key_action('on_end'))
	self:add_key_binding('del', 'menu-delete-item', self:create_key_action('delete_selected_item'))
end

function Menu:disable_key_bindings()
	for _, name in ipairs(self.key_bindings) do mp.remove_key_binding(name) end
	self.key_bindings = {}
end

---@param modifiers Modifiers
function Menu:create_modified_mbtn_left_handler(modifiers)
	return function()
		self.mouse_nav = true
		self.modifiers = modifiers
		self:handle_cursor_down()
		self:handle_cursor_up()
		self.modifiers = nil
	end
end

---@param name string
---@param modifiers? Modifiers
function Menu:create_key_action(name, modifiers)
	return function()
		self.mouse_nav = false
		self.modifiers = modifiers
		self:maybe(name)
		self.modifiers = nil
	end
end

function Menu:render()
	local update_cursor = false
	for _, menu in ipairs(self.all) do
		if menu.fling then
			update_cursor = update_cursor or menu.fling.update_cursor or false
			local time_delta = state.render_last_time - menu.fling.time
			local progress = menu.fling.easing(math.min(time_delta / menu.fling.duration, 1))
			self:set_scroll_to(round(menu.fling.y + menu.fling.distance * progress), menu)
			if progress < 1 then request_render() else menu.fling = nil end
		end
	end
	if update_cursor then self:select_item_below_cursor() end

	cursor.on_primary_down = function() self:handle_cursor_down() end
	cursor.on_primary_up = function() self:handle_cursor_up() end
	if self.proximity_raw == 0 then
		cursor.on_wheel_down = function() self:handle_wheel_down() end
		cursor.on_wheel_up = function() self:handle_wheel_up() end
	end

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
				local x, y = content_bx - (icon_size / 2), item_center_y
				if item.icon == 'spinner' then
					ass:spinner(x, y, icon_size * 1.5, {color = font_color, opacity = text_opacity * 0.8})
				else
					ass:icon(x, y, icon_size * 1.5, item.icon, {
						color = font_color, opacity = text_opacity, clip = item_clip,
						shadow = 1, shadow_color = shadow_color,
					})
				end
				content_bx = content_bx - icon_size - spacing
			end

			local title_cut_x = content_bx
			if item.hint_width > 0 then
				-- controls title & hint clipping proportional to the ratio of their widths
				local title_content_ratio = item.title_width / (item.title_width + item.hint_width)
				title_cut_x = round(content_ax + (content_bx - content_ax - spacing) * title_content_ratio
					+ (item.title_width > 0 and spacing / 2 or 0))
			end

			-- Hint
			if item.hint then
				item.ass_safe_hint = item.ass_safe_hint or ass_escape(item.hint)
				local clip = '\\clip(' .. title_cut_x .. ',' ..
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
					.. title_cut_x .. ',' .. math.min(item_by, by) .. ')'
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
			ass:txt(ax + menu.width / 2, title_ay + (title_height / 2), 5, menu.ass_safe_title, {
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

return Menu
