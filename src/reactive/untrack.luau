local graph = require("./graph")

local function untrack<T>(source: () -> T): T
	local scope = graph.get_scope()
	if not scope then
		return source()
	end

	local effect = scope.effect
	scope.effect = false

	local ok, result = xpcall(source, debug.traceback)

	scope.effect = effect

	if not ok then
		error(result, 0)
	end

	return result :: T
end

return untrack :: (<T>(fn: () -> T) -> T) & ((fn: () -> ()) -> ())
