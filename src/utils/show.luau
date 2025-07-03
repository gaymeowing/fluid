local derive = require("../reactive/derive")
local untrack = require("../reactive/untrack")

local function show<T, U>(
	condition: () -> boolean,
	truthy: () -> T,
	falsy: (() -> U)?
): () -> T | U
	return derive(function()
		if condition() then
			return untrack(truthy)
		elseif falsy then
			return untrack(falsy)
		end

		return nil
	end)
end

return show :: (<T>(condition: () -> boolean, truthy: () -> T) -> T?) & <T, U>(
	condition: () -> boolean,
	truthy: () -> T,
	falsy: () -> U
) -> T | U
