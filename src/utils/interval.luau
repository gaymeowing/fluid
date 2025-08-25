local graph = require("../reactive/graph")
local scheduler = require("../scheduler")

-- if hz is not specified, the first run will have a delta_time of 0
local function interval<T>(func: (dt: number) -> T, hz: number?)
	local scope = graph.assert_scope()
	local internal_node = graph.create_source_node(func(if hz then 1 / hz else 0))
	local last_eval = 0

	graph.push_cleanup(
		scope,
		scheduler.on_render(function(dt: number)
			if hz ~= nil then
				local clock = os.clock()
				if clock - last_eval <= 1 / hz then
					return
				end
				last_eval = clock
			end

			graph.update_source_node(internal_node, func(if hz then 1 / hz else dt))
		end)
	)

	return function()
		graph.push_dependency(internal_node)
		return internal_node.cached_value
	end
end

return interval
