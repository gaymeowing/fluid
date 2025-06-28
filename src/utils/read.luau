
type function get_return_of_function(f: type)
	local returns = f:returns()

	return if returns.head then
			(returns.head :: any)[1]
		elseif returns.tail then
			returns.tail
		else
			types.singleton(nil)
end

type function CastIntoValue(value: type)
	if value.tag == "union" then
		local union = {}

		for _, component in value:components() do
			if component.tag == "function" then
				table.insert(union, get_return_of_function(component))
			else
				table.insert(union, component)
			end
		end

		return types.unionof(table.unpack(union))
	elseif value.tag == "function" then
		return get_return_of_function(value)
	else
		return value
	end
end

local function read<T>(value: T): CastIntoValue<T>
	return if type(value) == "function" then (value :: () -> T)() else value
end

return read
