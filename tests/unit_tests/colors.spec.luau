local oklab = require("@src/utils/oklab")
local TEST, CASE, CHECK = require("@vendor/testkit").test()

local function within(epsilon: number)
	return function(value1: vector, value2: vector): boolean
		return vector.magnitude(value1 - value2) <= epsilon
	end
end

local colors_within = within(0.01)

TEST("oklab <-> srgb", function()
	CASE("converting integers back")
	do
		local rgb = vector.create(255, 176, 255)

		CHECK(colors_within(oklab.to_srgb(oklab.from_srgb(rgb)), rgb))
	end
end)

return true
