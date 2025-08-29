local graph = require("../reactive/graph")
local scheduler = require("../scheduler")

local function interval<T>(func: (dt: number) -> T, hz: number?)
	local scope = graph.assert_stable_parent()
	local internal_node = graph.create_source_node(func(0))
	local last_eval = 0

	local disconnect = scheduler.on_render(function(dt: number)
		if hz ~= nil then
			last_eval += dt
			if last_eval <= 1 / hz then
				return
			end
			last_eval = 0
		end

		graph.update_source_node(internal_node, func(dt))
	end)

	graph.push_cleanup(scope, disconnect)

	return function()
		graph.push_dependency(internal_node)
		return internal_node.cached_value
	end
end

return interval
