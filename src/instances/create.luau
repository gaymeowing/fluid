local bind = require("./bind")
local types = require("./types")

-- cached per class, so creating an instance doesn't also create a new closure every time
-- weak so constructors that don't get used often will be cleared
local constructors: { [string]: ({}) -> Instance } = setmetatable({}, { __mode = "v" })

--stylua: ignore
local function create<ClassName>(
	class_name: ClassName | keyof<types.Instances> | ""
): (props: types.PropertiesFor<ClassName>) -> types.GetInstance<ClassName, types.Instances>
	local name = class_name :: string
	local constructor = constructors[name]

	if not constructor then
		function constructor(props: {})
			return bind(Instance.new(name), props :: any)
		end

		constructors[name] = constructor
	end

	return constructor :: any
end

return create
