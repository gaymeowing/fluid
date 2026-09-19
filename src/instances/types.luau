local action = require("./action")

type UnknownConnectCallback = (...any) -> ()

type Signal = RBXScriptSignal

type function get_connect(v: type): type?
	local connect = v:readproperty(types.singleton("Connect"))

	if connect and connect:is("function") then
		local head = connect:parameters().head

		if not head then
			return nil
		end
		local callback = head[2]

		if callback and callback:is("function") then
			return callback
		end
	end

	return nil
end

type function is_signal(v: type): type?
	if v == Signal and v.tag == "extern" then
		return UnknownConnectCallback
	-- luau lsp types RBXScriptSignals as tables
	elseif v.tag == "table" then
		local connect = get_connect(v)

		if connect then
			return connect
		end

		-- i cba to test if this is needed or not
		local metatable = v:metatable()

		if metatable then
			connect = get_connect(metatable)

			if connect then
				return connect
			end
		end
	end

	return nil
end

type instance = Instance

type Action = action.Identity

export type function PropertiesFor(object: type): type
	if not object:issubtypeof(instance) then
		error("Cannot get properties of a non Instance type")
	end
	local head_table = {}
	local args_table = { head = head_table }
	local properties = types.newtable()
	local current = object
	local empty_table = {}

	local read_only_properties = table.freeze({
		types.singleton("RobloxLocked"),
		types.singleton("ClassName"),
		types.singleton("UniqueId"),
	})

	while current do
		for property, value in current:properties() do
			if table.find(read_only_properties, property) then
				continue
			end

			local value_read = value.read
			local callback = is_signal(value_read)

			if callback then
				properties:setproperty(property, types.optional(callback))
			elseif value_read.tag == "function" or value_read.tag == "intersection" then
				continue
			elseif value.write then
				head_table[1] = value_read

				properties:setproperty(
					property,
					types.optional(
						types.unionof(types.newfunction(empty_table :: any, args_table :: any), value.write)
					)
				)
			end
		end

		current = current:readparent()
	end

	-- Functions returning a child can return an array of children, or alike functions, nested to any level
	local function_returns_child = types.newfunction()
	local child_only_union = types.unionof(function_returns_child, instance)

	-- TODO: Use a read only indexer when released to properly accept children which are subtypes of `Instance`
	-- TODO: Nesting throws a type error, seemingly a solver bug caused whenever the keys are a union instead of direct type
	-- Happens even with a union between `Instance` and `any`, but disappears when it's just `Instance`
	local nested_table_or_function_or_child = types.newtable()
	local nested_child_union = types.unionof(child_only_union, nested_table_or_function_or_child)
	nested_table_or_function_or_child:setindexer(types.number, nested_child_union)
	function_returns_child:setreturns({ nested_child_union })

	local full_union = types.unionof(child_only_union, Action, properties)
	properties:setindexer(types.number, types.optional(full_union))

	return properties
end

return nil
