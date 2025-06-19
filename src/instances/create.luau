local function try_create_inst(class_name: string): Instance
	local success, result = pcall(Instance.new, class_name)
	if not success then
		-- error at the location of the create call
		error(`Instance class "{class_name}" does not exist`, 3)
	end

	return result
end

local function create(
	class_name: string
): (props: { [string | number]: unknown }) -> Instance
	local function apply_props(props)
		local created_inst = try_create_inst(class_name)

		-- handle property sets
		for property, value in props do
			-- we use mixed tables
			if type(property) == "number" then
				continue
			end

			created_inst[property] = value
		end

		-- handle children
		for key, value in ipairs(props) do
			if typeof(value) ~= "Instance" then
				continue
			end

			value.Parent = created_inst
		end

		return created_inst
	end

	return apply_props
end

return create
