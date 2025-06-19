local graph = require("./graph")

local function cleanup(callback: () -> ())
	local scope = graph.get_scope()
	assert(scope, "Cannot call cleanup from outside of a reactive scope")

	graph.push_cleanup(scope, callback)
end

return cleanup
