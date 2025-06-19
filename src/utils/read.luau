local types = require("../reactive/types")

local function read<T>(value: T | types.Readable<T>): T
	return if type(value) == "function" then value() else value
end

return read
