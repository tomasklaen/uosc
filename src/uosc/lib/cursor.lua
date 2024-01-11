local cursor = {
	x = math.huge,
	y = math.huge,
	hidden = true,
	hover_raw = false,
	-- Event handlers that are only fired on cursor, bound during render loop. Guidelines:
	-- - element activations (clicks) go to `primary_down` handler
	-- - `primary_up` is only for clearing dragging/swiping, and prevents autohide when bound
	---@type {[string]: {hitbox: Hitbox; handler: fun(...)}[]}
	zones = {
		primary_down = {},
		primary_up = {},
		secondary_down = {},
		secondary_up = {},
		wheel_down = {},
		wheel_up = {},
		move = {},
	},
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
	event_forward_map = {
		primary_down = 'MBTN_LEFT',
		primary_up = 'MBTN_LEFT',
		secondary_down = 'MBTN_RIGHT',
		secondary_up = 'MBTN_RIGHT',
		wheel_down = 'WHEEL',
		wheel_up = 'WHEEL',
	}
}

cursor.autohide_timer = mp.add_timeout(1, function() cursor:autohide() end)
cursor.autohide_timer:kill()
mp.observe_property('cursor-autohide', 'number', function(_, val)
	cursor.autohide_timer.timeout = (val or 1000) / 1000
end)

-- Called at the beginning of each render
function cursor:clear_zones()
	for _, handlers in pairs(self.zones) do
		itable_clear(handlers)
	end
end

---@param hitbox Hitbox
function cursor:collides_with(hitbox)
	return (hitbox.r and get_point_to_point_proximity(self, hitbox.point) <= hitbox.r) or
		(not hitbox.r and get_point_to_rectangle_proximity(self, hitbox) == 0)
end

---@param event string
function cursor:find_zone_handler(event)
	local zones = self.zones[event]
	for i = #zones, 1, -1 do
		local zone = zones[i]
		if self:collides_with(zone.hitbox) then return zone.handler end
	end
end

---@param event string
---@param hitbox Hitbox
---@param callback fun(...)
function cursor:zone(event, hitbox, callback)
	local event_zones = self.zones[event]
	event_zones[#event_zones + 1] = {hitbox = hitbox, handler = callback}
end

-- Binds a cursor event handler.
---@param event string
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
function cursor:trigger(event, ...)
	local zone_handler = self:find_zone_handler(event)
	local callbacks = self.handlers[event]
	if zone_handler or #callbacks > 0 then
		call_maybe(zone_handler, ...)
		for _, callback in ipairs(callbacks) do callback(...) end
	else
		local forward_name = self.event_forward_map[event]
		if forward_name then
			-- Forward events if there was no handler.
			local active = find_active_keybindings(forward_name)
			if active then
				local is_up = event:sub(-3) == '_up'
				if active.owner then
					-- Binding belongs to other script, so make it look like regular key event.
					-- Mouse bindings are simple, other keys would require repeat and pressed handling,
					-- which can't be done with mp.set_key_bindings(), but is possible with mp.add_key_binding().
					local state = is_up and 'um' or 'dm'
					local name = active.cmd:sub(active.cmd:find('/') + 1, -1)
					mp.commandv('script-message-to', active.owner, 'key-binding', name, state, forward_name)
				elseif not is_up then
					-- input.conf binding
					mp.command(active.cmd)
				end
			end
		end
	end
	self:queue_autohide() -- refresh cursor autohide timer
end

-- Decides necessary bindings level for passed event, where:
--   0: bindings should be disabled
--   1: bindings should be enabled
--   2: bindings should be enabled, and window dragging prevented
---@param event string
function cursor:get_binding_level(event)
	local level = #self.handlers[event] > 0 and 1 or 0
	for _, zone in ipairs(self.zones[event]) do
		if zone.hitbox.window_drag == false and cursor:collides_with(zone.hitbox) then return 2 end
		level = math.max(level, 1)
	end
	return level
end

-- Enables or disables keybinding groups based on what event listeners are bound.
function cursor:decide_keybinds()
	local mbtn_left_level = math.max(self:get_binding_level('primary_down'), self:get_binding_level('primary_up'))
	local new_levels = {
		mbtn_left = mbtn_left_level,
		mbtn_left_dbl = mbtn_left_level,
		mbtn_right = math.max(self:get_binding_level('secondary_down'), self:get_binding_level('secondary_up')),
		wheel = math.max(self:get_binding_level('wheel_down'), self:get_binding_level('wheel_up')),
	}

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

-- Returns a table with current velocities in in pixels per second.
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
	return options.autohide and (not self.autohide_fs_only or state.fullscreen) and
		not (self.mbtn_left_dbl_enabled or self.mbtn_right_enabled or self.wheel_enabled) and
		not Menu:is_open()
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

function cursor:create_handler(event, cb)
	return function(...)
		call_maybe(cb, ...)
		self:trigger(event, ...)
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
mp.set_key_bindings({
	{
		'mbtn_left',
		cursor:create_handler('primary_up'),
		cursor:create_handler('primary_down', function(...)
			handle_mouse_pos(nil, mp.get_property_native('mouse-pos'))
		end),
	},
}, 'mbtn_left', 'force')
mp.set_key_bindings({
	{'mbtn_left_dbl', 'ignore'},
}, 'mbtn_left_dbl', 'force')
mp.set_key_bindings({
	{'mbtn_right', cursor:create_handler('secondary_up'), cursor:create_handler('secondary_down')},
}, 'mbtn_right', 'force')
mp.set_key_bindings({
	{'wheel_up', cursor:create_handler('wheel_up')},
	{'wheel_down', cursor:create_handler('wheel_down')},
}, 'wheel', 'force')

return cursor
