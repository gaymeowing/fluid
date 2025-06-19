local graph = require("./graph")
local types = require("./types")

local function effect<T>(callback: types.Effect<T> | () -> (), initial_value: T)
	local node = graph.create_reactive_node(
		graph.assert_stable_parent(),
		callback,
		"eager",
		initial_value -- Unsure how to solve this type error
	)

	graph.evaluate_node(node)
end

return effect
