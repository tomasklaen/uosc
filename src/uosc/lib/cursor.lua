---@alias CursorEventHandler fun(shortcut: Shortcut)

local cursor = {
	x = math.huge,
	y = math.huge,
	hidden = true,
	distance = 0, -- Distance traveled during current move. Reset by `cursor.distance_reset_timer`.
	hover_raw = false,
	-- Event handlers that are only fired on zones defined during render loop.
	---@type {event: string, hitbox: Hitbox; handler: CursorEventHandler}[]
	zones = {},
	handlers = {
		primary_down = {},
		primary_up = {},
		secondary_down = {},
		secondary_up = {},
		wheel_down = {},
		wheel_up = {},
		move = {},
	},
	first_real_mouse_move_received = false,
	history = CircularBuffer:new(10),
	autohide_fs_only = nil,
	-- Tracks current key binding levels for each event. 0: disabled, 1: enabled, 2: enabled + window dragging prevented
	binding_levels = {
		mbtn_left = 0,
		mbtn_left_dbl = 0,
		mbtn_right = 0,
		wheel = 0,
	},
	is_dragging_prevented = false,
	event_forward_map = {
		primary_down = 'MBTN_LEFT',
		primary_up = 'MBTN_LEFT',
		secondary_down = 'MBTN_RIGHT',
		secondary_up = 'MBTN_RIGHT',
		wheel_down = 'WHEEL_DOWN',
		wheel_up = 'WHEEL_UP',
	},
	event_binding_map = {
		primary_down = 'mbtn_left',
		primary_up = 'mbtn_left',
		primary_click = 'mbtn_left',
		secondary_down = 'mbtn_right',
		secondary_up = 'mbtn_right',
		secondary_click = 'mbtn_right',
		wheel_down = 'wheel',
		wheel_up = 'wheel',
	},
	window_dragging_blockers = create_set({'primary_click', 'primary_down'}),
	event_propagation_blockers = {
		primary_down = 'primary_click',
		primary_click = 'primary_down',
		secondary_down = 'secondary_click',
		secondary_click = 'secondary_down',
	},
	event_parent_map = {
		primary_down = {is_start = true, trigger_event = 'primary_click'},
		primary_up = {is_end = true, start_event = 'primary_down', trigger_event = 'primary_click'},
		secondary_down = {is_start = true, trigger_event = 'secondary_click'},
		secondary_up = {is_end = true, start_event = 'secondary_down', trigger_event = 'secondary_click'},
	},
	-- Holds positions of last events.
	---@type {[string]: {x: number, y: number, time: number}}
	last_event = {},
}

cursor.autohide_timer = mp.add_timeout(1, function() cursor:autohide() end)
cursor.autohide_timer:kill()
mp.observe_property('cursor-autohide', 'number', function(_, val)
	cursor.autohide_timer.timeout = (val or 1000) / 1000
end)

cursor.distance_reset_timer = mp.add_timeout(0.2, function()
	cursor.distance = 0
	request_render()
end)
cursor.distance_reset_timer:kill()

-- Called at the beginning of each render
function cursor:clear_zones()
	itable_clear(self.zones)
end

---@param hitbox Hitbox
function cursor:collides_with(hitbox)
	return point_collides_with(self, hitbox)
end

-- Returns zone for event at current cursor position.
---@param event string
function cursor:find_zone(event)
	-- Premature optimization to ignore a high frequency event that is not needed as a zone atm.
	if event == 'move' then return end

	for i = #self.zones, 1, -1 do
		local zone = self.zones[i]
		local is_blocking_only = zone.event == self.event_propagation_blockers[event]
		if (zone.event == event or is_blocking_only) and self:collides_with(zone.hitbox) then
			return not is_blocking_only and zone or nil
		end
	end
end

-- Defines an event zone for a hitbox on currently rendered screen. Available events:
-- - primary_down, primary_up, primary_click, secondary_down, secondary_up, secondary_click, wheel_down, wheel_up
--
-- Notes:
-- - Zones are cleared on beginning of every `render()`, and need to be rebound.
-- - One event type per zone: only the last bound zone per event gets triggered.
-- - In current implementation, you have to choose between `_click` or `_down`. Binding both makes only the last bound fire.
-- - Primary `_down` and `_click` disable dragging. Define `window_drag = true` on hitbox to re-enable.
-- - Anything that disables dragging also implicitly disables cursor autohide.
-- - `move` event zones are ignored due to it being a high frequency event that is currently not needed as a zone.
---@param event string
---@param hitbox Hitbox
---@param callback CursorEventHandler
function cursor:zone(event, hitbox, callback)
	self.zones[#self.zones + 1] = {event = event, hitbox = hitbox, handler = callback}
end

-- Binds a permanent cursor event handler active until manually unbound using `cursor:off()`.
-- `_click` events are not available as permanent global events, only as zones.
---@param event string
---@param callback CursorEventHandler
---@return fun() disposer Unbinds the event.
function cursor:on(event, callback)
	if self.handlers[event] and not itable_index_of(self.handlers[event], callback) then
		self.handlers[event][#self.handlers[event] + 1] = callback
		self:decide_keybinds()
	end
	return function() self:off(event, callback) end
end

-- Unbinds a cursor event handler.
---@param event string
function cursor:off(event, callback)
	if self.handlers[event] then
		local index = itable_index_of(self.handlers[event], callback)
		if index then
			table.remove(self.handlers[event], index)
			self:decide_keybinds()
		end
	end
end

-- Binds a cursor event handler to be called once.
---@param event string
function cursor:once(event, callback)
	local function callback_wrap()
		callback()
		self:off(event, callback_wrap)
	end
	return self:on(event, callback_wrap)
end

-- Trigger the event.
---@param event string
---@param shortcut? Shortcut
function cursor:trigger(event, shortcut)
	local forward = true

	-- Call raw event handlers.
	local zone = self:find_zone(event)
	local callbacks = self.handlers[event]
	if zone or #callbacks > 0 then
		forward = false
		if zone and shortcut then zone.handler(shortcut) end
		for _, callback in ipairs(callbacks) do callback(shortcut) end
	end

	-- Call compound/parent (click) event handlers if both start and end events are within `parent_zone.hitbox`.
	local parent = self.event_parent_map[event]
	if parent then
		local parent_zone = self:find_zone(parent.trigger_event)
		if parent_zone then
			forward = false -- Canceled here so we don't forward down events if they can lead to a click.
			if parent.is_end then
				local last_start_event = self.last_event[parent.start_event]
				if last_start_event and point_collides_with(last_start_event, parent_zone.hitbox) and shortcut then
					parent_zone.handler(create_shortcut('primary_click', shortcut.modifiers))
				end
			end
		end
	end

	-- Forward unhandled events.
	if forward then
		local forward_name = self.event_forward_map[event]
		if forward_name then
			-- Forward events if there was no handler.
			local active = find_active_keybindings(forward_name)
			if active and active.cmd then
				local is_wheel = event:find('wheel', 1, true)
				local is_up = event:sub(-3) == '_up'
				if active.owner then
					-- Binding belongs to other script, so make it look like regular key event.
					-- Mouse bindings are simple, other keys would require repeat and pressed handling,
					-- which can't be done with mp.set_key_bindings(), but is possible with mp.add_key_binding().
					local state = is_wheel and 'pm' or is_up and 'um' or 'dm'
					local name = active.cmd:sub(active.cmd:find('/') + 1, -1)
					mp.commandv('script-message-to', active.owner, 'key-binding', name, state, forward_name)
				elseif is_wheel or is_up then
					-- input.conf binding, react to button release for mouse buttons
					mp.command(active.cmd)
				end
			end
		end
	end

	-- Update last event position.
	local last = self.last_event[event] or {}
	last.x, last.y, last.time = self.x, self.y, mp.get_time()
	self.last_event[event] = last

	-- Refresh cursor autohide timer.
	self:queue_autohide()
end

-- Enables or disables keybinding groups based on what event listeners are bound.
function cursor:decide_keybinds()
	local new_levels = {mbtn_left = 0, mbtn_right = 0, wheel = 0}
	self.is_dragging_prevented = false

	-- Check global events.
	for name, handlers in ipairs(self.handlers) do
		local binding = self.event_binding_map[name]
		if binding then
			new_levels[binding] = #handlers > 0 and 1 or 0
		end
	end

	-- Check zones.
	for _, zone in ipairs(self.zones) do
		local binding = self.event_binding_map[zone.event]
		if binding and cursor:collides_with(zone.hitbox) then
			local new_level = (self.window_dragging_blockers[zone.event] and zone.hitbox.window_drag ~= true) and 2
				or math.max(new_levels[binding], zone.hitbox.window_drag == false and 2 or 1)
			new_levels[binding] = new_level
			if new_level > 1 then
				self.is_dragging_prevented = true
			end
		end
	end

	-- Window dragging only gets prevented when on top of an element, which is when double clicks should be ignored.
	new_levels.mbtn_left_dbl = new_levels.mbtn_left == 2 and 2 or 0

	for name, level in pairs(new_levels) do
		if level ~= self.binding_levels[name] then
			local flags = level == 1 and 'allow-vo-dragging+allow-hide-cursor' or ''
			mp[(level == 0 and 'disable' or 'enable') .. '_key_bindings'](name, flags)
			self.binding_levels[name] = level
			self:queue_autohide()
		end
	end
end

function cursor:_find_history_sample()
	local time = mp.get_time()
	for _, e in self.history:iter_rev() do
		if time - e.time > 0.1 then
			return e
		end
	end
	return self.history:tail()
end

-- Returns the current velocity vector in pixels per second.
---@return Point
function cursor:get_velocity()
	local snap = self:_find_history_sample()
	if snap then
		local x, y, time = self.x - snap.x, self.y - snap.y, mp.get_time()
		local time_diff = time - snap.time
		if time_diff > 0.001 then
			return {x = x / time_diff, y = y / time_diff}
		end
	end
	return {x = 0, y = 0}
end

---@param x integer
---@param y integer
function cursor:move(x, y)
	local old_x, old_y = self.x, self.y

	-- mpv reports initial mouse position on linux as (0, 0), which always
	-- displays the top bar, so we hardcode cursor position as infinity until
	-- we receive a first real mouse move event with coordinates other than 0,0.
	if not self.first_real_mouse_move_received then
		if x > 0 and y > 0 then
			self.first_real_mouse_move_received = true
		else
			x, y = math.huge, math.huge
		end
	end

	-- Add 0.5 to be in the middle of the pixel
	self.x, self.y = x + 0.5, y + 0.5

	if old_x ~= self.x or old_y ~= self.y then
		if self.x == math.huge or self.y == math.huge then
			self.hidden = true
			self.history:clear()

			-- Slowly fadeout elements that are currently visible
			for _, id in ipairs(config.cursor_leave_fadeout_elements) do
				local element = Elements[id]
				if element then
					local visibility = element:get_visibility()
					if visibility > 0 then
						element:tween_property('forced_visibility', visibility, 0, function()
							element.forced_visibility = nil
						end)
					end
				end
			end

			Elements:update_proximities()
			Elements:trigger('global_mouse_leave')
		else
			if self.hidden then
				-- Cancel potential fadeouts
				for _, id in ipairs(config.cursor_leave_fadeout_elements) do
					if Elements[id] then Elements[id]:tween_stop() end
				end

				self.hidden = false
				Elements:trigger('global_mouse_enter')
			end

			-- Update current move travel distance
			-- `mp.get_time() - last.time < 0.5` check is there to ignore first event after long inactivity to
			-- filter out big jumps due to window being repositioned/rescaled (e.g. opening a different file).
			local last = self.last_event.move
			if last and last.x < math.huge and last.y < math.huge and mp.get_time() - last.time < 0.5 then
				self.distance = self.distance + get_point_to_point_proximity(cursor, last)
				cursor.distance_reset_timer:kill()
				cursor.distance_reset_timer:resume()
			end

			Elements:update_proximities()
			-- Update history
			self.history:insert({x = self.x, y = self.y, time = mp.get_time()})
		end

		Elements:proximity_trigger('mouse_move')
		self:queue_autohide()
	end

	self:trigger('move')

	request_render()
end

function cursor:leave() self:move(math.huge, math.huge) end

function cursor:is_autohide_allowed()
	return options.autohide and (not self.autohide_fs_only or state.fullscreen)
		and not self.is_dragging_prevented
		and not Menu:is_open()
end
mp.observe_property('cursor-autohide-fs-only', 'bool', function(_, val) cursor.autohide_fs_only = val end)

-- Cursor auto-hiding after period of inactivity.
function cursor:autohide()
	if self:is_autohide_allowed() then
		self:leave()
		self.autohide_timer:kill()
	end
end

function cursor:queue_autohide()
	if self:is_autohide_allowed() then
		self.autohide_timer:kill()
		self.autohide_timer:resume()
	end
end

-- Calculates distance in which cursor reaches rectangle if it continues moving on the same path.
-- Returns `nil` if cursor is not moving towards the rectangle.
---@param rect Rect
function cursor:direction_to_rectangle_distance(rect)
	local prev = self:_find_history_sample()
	if not prev then return false end
	local end_x, end_y = self.x + (self.x - prev.x) * 1e10, self.y + (self.y - prev.y) * 1e10
	return get_ray_to_rectangle_distance(self.x, self.y, end_x, end_y, rect)
end

---@param event string
---@param shortcut Shortcut
---@param cb? fun(shortcut: Shortcut)
function cursor:create_handler(event, shortcut, cb)
	return function()
		if cb then cb(shortcut) end
		self:trigger(event, shortcut)
	end
end

-- Movement
function handle_mouse_pos(_, mouse)
	if not mouse then return end
	if cursor.hover_raw and not mouse.hover then
		cursor:leave()
	else
		cursor:move(mouse.x, mouse.y)
	end
	cursor.hover_raw = mouse.hover
end
mp.observe_property('mouse-pos', 'native', handle_mouse_pos)

-- Key binding groups
local modifiers = {nil, 'alt', 'alt+ctrl', 'alt+shift', 'alt+ctrl+shift', 'ctrl', 'ctrl+shift', 'shift'}
local primary_bindings = {}
for i = 1, #modifiers do
	local mods = modifiers[i]
	local mp_name = (mods and mods .. '+' or '') .. 'mbtn_left'
	primary_bindings[#primary_bindings + 1] = {
		mp_name,
		cursor:create_handler('primary_up', create_shortcut('primary_up', mods)),
		cursor:create_handler('primary_down', create_shortcut('primary_down', mods), function(...)
			handle_mouse_pos(nil, mp.get_property_native('mouse-pos'))
		end),
	}
end
mp.set_key_bindings(primary_bindings, 'mbtn_left', 'force')
mp.set_key_bindings({
	{'mbtn_left_dbl', 'ignore'},
}, 'mbtn_left_dbl', 'force')
mp.set_key_bindings({
	{
		'mbtn_right',
		cursor:create_handler('secondary_up', create_shortcut('secondary_up')),
		cursor:create_handler('secondary_down', create_shortcut('secondary_down')),
	},
}, 'mbtn_right', 'force')
mp.set_key_bindings({
	{'wheel_up', cursor:create_handler('wheel_up', create_shortcut('wheel_up'))},
	{'wheel_down', cursor:create_handler('wheel_down', create_shortcut('wheel_down'))},
}, 'wheel', 'force')

return cursor
