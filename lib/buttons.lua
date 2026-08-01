---@alias ButtonData {icon: string; active?: boolean; badge?: string; command?: string | string[]; tooltip?: string;}
---@alias ButtonSubscriber fun(data: ButtonData)

local buttons = {
	---@type ButtonData[]
	data = {},
	---@type table<string, ButtonSubscriber[]>
	subscribers = {},
}

---@param name string
---@return ButtonData
function buttons:get(name)
	return self.data[name] or {icon = 'help_center', tooltip = 'Uninitialized button "' .. name .. '"'}
end

---@param name string
---@param callback fun(data: ButtonData)
function buttons:subscribe(name, callback)
	local pool = self.subscribers[name]
	if not pool then
		pool = {}
		self.subscribers[name] = pool
	end
	pool[#pool + 1] = callback
	return function() buttons:unsubscribe(name, callback) end
end

---@param name string
---@param callback? ButtonSubscriber
function buttons:unsubscribe(name, callback)
	if self.subscribers[name] then
		if callback == nil then
			self.subscribers[name] = {}
		else
			itable_delete_value(self.subscribers[name], callback)
		end
	end
end

---@param name string
function buttons:trigger(name)
	local pool = self.subscribers[name]
	if pool then
		local data = self:get(name)
		for _, callback in ipairs(pool) do callback(data) end
	end
end

---@param name string
---@param data ButtonData
function buttons:set(name, data)
	buttons.data[name] = data
	buttons:trigger(name)
	request_render()
end

mp.register_script_message('set-button', function(name, data)
	if type(name) ~= 'string' then
		msg.error('Invalid set-button message parameter: 1st parameter (name) has to be a string.')
		return
	end
	if type(data) ~= 'string' then
		msg.error('Invalid set-button message parameter: 2nd parameter (data) has to be a string.')
		return
	end

	local data = utils.parse_json(data)
	if type(data) == 'table' and type(data.icon) == 'string' then
		buttons:set(name, data)
	end
end)

return buttons
