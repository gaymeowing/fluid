-- exists so we
local action_metatable_symbol = table.freeze({})

export type Identity = setmetatable<{
	callback: (instance: Instance) -> (),
	priority: number,
}, typeof(action_metatable_symbol)>

local action = {
	metatable = action_metatable_symbol,
}

function action.is_action(action: {} & unknown): boolean
	return getmetatable(action) :: any == action_metatable_symbol
end

function action.create(
	callback: (instance: Instance) -> (),
	priority: number?
): Identity
	return setmetatable({
		callback = callback,
		priority = priority or 1,
	}, action_metatable_symbol)
end

return action
