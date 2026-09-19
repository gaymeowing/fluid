local types = require("./types")
local bind = require("./bind")

local function hydrate<Instance>(instance: Instance): (props: types.PropertiesFor<Instance>) -> Instance
	return function(properties)
		return bind(instance, properties) :: any
	end
end

return hydrate
