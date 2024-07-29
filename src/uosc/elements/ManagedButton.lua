local Button = require('elements/Button')

---@alias ManagedButtonProps {name: string; anchor_id?: string; render_order?: number}

---@class ManagedButton : Button
local ManagedButton = class(Button)

---@param id string
---@param props ManagedButtonProps
function ManagedButton:new(id, props) return Class.new(self, id, props) --[[@as ManagedButton]] end
---@param id string
---@param props ManagedButtonProps
function ManagedButton:init(id, props)
	---@type string | table | nil
	self.command = nil

	Button.init(self, id, table_assign({}, props, {on_click = function() execute_command(self.command) end}))

	self:register_disposer(buttons:subscribe(props.name, function(data) self:update(data) end))
end

function ManagedButton:update(data)
	for _, prop in ipairs({'icon', 'active', 'badge', 'command', 'tooltip'}) do
		self[prop] = data[prop]
	end
	self.is_clickable = self.command ~= nil
end

return ManagedButton
