local graph = require("../reactive/graph")
local scheduler = require("../scheduler")
local types = require("../reactive/types")

local function interval<T>(f: types.Readable<T>, hz: number?): () -> T
	local internal_node = graph.create_source_node(f())
	local new_hz = hz or 60
	local last_eval = 0

	scheduler.on_render(function()
		local current = os.clock()

		if current - last_eval <= 1 / new_hz then
			return
		end
		graph.update_source_node(internal_node, f())
		last_eval = current
	end)

	return function()
		graph.push_dependency(internal_node)
		return internal_node.cached_value
	end
end

return interval
