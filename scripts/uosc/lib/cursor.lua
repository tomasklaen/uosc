local cursor = {
	x = math.huge,
	y = math.huge,
	hidden = true,
	hover_raw = false,
	-- Event handlers that are only fired on cursor, bound during render loop. Guidelines:
	-- - element activations (clicks) go to `on_primary_down` handler
	-- - `on_primary_up` is only for clearing dragging/swiping, and prevents autohide when bound
	on_primary_down = nil,
	on_primary_up = nil,
	on_secondary_down = nil,
	on_secondary_up = nil,
	on_wheel_down = nil,
	on_wheel_up = nil,
	allow_dragging = false,
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
	-- Enables pointer key group captures needed by handlers (called at the end of each render)
	mbtn_left_enabled = nil,
	mbtn_right_enabled = nil,
	wheel_enabled = nil,
}

cursor.autohide_timer = (function()
	local timer = mp.add_timeout(mp.get_property_native('cursor-autohide') / 1000, function() cursor:autohide() end)
	timer:kill()
	return timer
end)()

-- Called at the beginning of each render
function cursor:reset_main_handlers()
	cursor.on_primary_down, cursor.on_primary_up = nil, nil
	cursor.on_secondary_down, cursor.on_secondary_up = nil, nil
	cursor.on_wheel_down, cursor.on_wheel_up = nil, nil
	cursor.allow_dragging = false
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
	call_maybe(cursor['on_' .. event], ...)
	for _, callback in ipairs(cursor.handlers[event]) do callback(...) end
	self:queue_autohide() -- refresh cursor autohide timer
end

---@param name string
function cursor:has_handler(name)
	return self['on_' .. name] ~= nil or #self.handlers[name] > 0
end

-- Enables or disables keybinding groups based on what event listeners are bound.
function cursor:decide_keybinds()
	local enable_mbtn_left = self:has_handler('primary_down') or self:has_handler('primary_up')
	local enable_mbtn_right = self:has_handler('secondary_down') or self:has_handler('secondary_up')
	local enable_wheel = self:has_handler('wheel_down') or self:has_handler('wheel_up')
	if enable_mbtn_left ~= self.mbtn_left_enabled then
		local flags = self.allow_dragging and 'allow-vo-dragging' or nil
		mp[(enable_mbtn_left and 'enable' or 'disable') .. '_key_bindings']('mbtn_left', flags)
		self.mbtn_left_enabled = enable_mbtn_left
	end
	if enable_mbtn_right ~= self.mbtn_right_enabled then
		mp[(enable_mbtn_right and 'enable' or 'disable') .. '_key_bindings']('mbtn_right')
		self.mbtn_right_enabled = enable_mbtn_right
	end
	if enable_wheel ~= self.wheel_enabled then
		mp[(enable_wheel and 'enable' or 'disable') .. '_key_bindings']('wheel')
		self.wheel_enabled = enable_wheel
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
	self.x = x == math.huge and x or x + 0.5
	self.y = y == math.huge and y or y + 0.5

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
			Elements:update_proximities()

			if self.hidden then
				-- Cancel potential fadeouts
				for _, id in ipairs(config.cursor_leave_fadeout_elements) do
					if Elements[id] then Elements[id]:tween_stop() end
				end

				self.hidden = false
				self.history:clear()
				Elements:trigger('global_mouse_enter')
			else
				-- Update history
				self.history:insert({x = self.x, y = self.y, time = mp.get_time()})
			end
		end

		Elements:proximity_trigger('mouse_move')
		self:queue_autohide()
	end

	self:trigger('move')

	request_render()
end

function cursor:leave() self:move(math.huge, math.huge) end

-- Cursor auto-hiding after period of inactivity.
function cursor:autohide()
	if not cursor.on_primary_up and not Menu:is_open() then cursor:leave() end
end

function cursor:queue_autohide()
	if options.autohide and not self.on_primary_up then
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

function cursor:make_handler(event, cb)
	return function(...)
		self:trigger(event, ...)
		call_maybe(cb, ...)
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
		cursor:make_handler('primary_up'),
		cursor:make_handler('primary_down', function(...)
			handle_mouse_pos(nil, mp.get_property_native('mouse-pos'))
		end),
	},
	{'mbtn_left_dbl', 'ignore'},
}, 'mbtn_left', 'force')
mp.set_key_bindings({
	{'mbtn_right', cursor:make_handler('secondary_up'), cursor:make_handler('secondary_down')},
}, 'mbtn_right', 'force')
mp.set_key_bindings({
	{'wheel_up', cursor:make_handler('wheel_up')},
	{'wheel_down', cursor:make_handler('wheel_down')},
}, 'wheel', 'force')

return cursor
