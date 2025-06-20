local graph = require("./graph")

local function cleanup(callback: () -> ())
	graph.push_cleanup(graph.assert_scope(), callback)
end

return cleanup
