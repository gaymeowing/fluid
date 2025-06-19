local graph = require("./graph")
local types = require("./types")

local function get_argument_from<T>(...: T): (boolean, T)
	if select("#", ...) == 0 then
		return false, nil :: any
	end

	local value = ... :: T
	return true, value
end

local function source<T>(initial_value: T): types.Source<T>
	local node = graph.create_source_node(initial_value)

	-- This uses varargs so we can tell the difference between f(), f(nil), and f(value)
	local function update_source(...: T): T
		local has_value, value = get_argument_from(...)

		if not has_value then
			graph.push_dependency(node)

			return node.cached_value
		end

		graph.update_source_node(node, value)
		return value
	end

	return update_source :: types.Source<T>
end

return source :: <T>(initial_value: T) -> types.Source<T>
