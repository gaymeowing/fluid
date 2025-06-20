local graph = require("../reactive/graph")
local scheduler = require("../scheduler")
local types = require("../reactive/types")

local function interval<T>(func: types.Readable<T>, hz: number?)
	local internal_node = graph.create_source_node(func())
	local last_eval = 0

	scheduler.on_render(function()
		if os.clock() - last_eval <= 1 / (hz or 60) then
			return
		end

		graph.update_source_node(internal_node, func())
		last_eval = os.clock()
	end)

	return function()
		graph.push_dependency(internal_node)
		return internal_node.cached_value
	end
end

return interval
