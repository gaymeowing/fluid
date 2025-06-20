local graph = require("../reactive/graph")

local function set_property(inst: Instance, prop_name: string, value: any)
	(inst :: any)[prop_name] = value
end

local function bind(props, inst: Instance)
	-- handle property sets
	for property: number | string, value in props do
		-- we use mixed tables
		if type(property) == "number" then
			continue
		end

		if type(value) == "function" then
			local first_value = value()

			local property_node = graph.create_reactive_node(
				graph.assert_stable_parent(),
				function()
					set_property(inst, property, value())
					return nil
				end,
				"eager",
				first_value
			)

			set_property(inst, property, first_value)

			graph.evaluate_node(property_node)

			continue
		end

		set_property(inst, property, value)
	end

	-- handle children
	for key, value in ipairs(props) do
		if typeof(value) ~= "Instance" then
			continue
		end

		value.Parent = inst
	end

	return inst
end

return bind
