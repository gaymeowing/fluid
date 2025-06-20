local graph = require("./graph")

local function untrack<T>(source: () -> T): T
	local scope = graph.get_scope()
	if (not scope) or (scope and not scope.effect) then
		return source()
	end

	-- temporarily unbind effect
	local effect = scope.effect
	scope.effect = false :: any

	local value = source()

	scope.effect = effect

	return value
end

return untrack
