local X_CONST = vector.create(0.4122214708, 0.5363325363, 0.0514459929)
local Y_CONST = vector.create(0.2119034982, 0.6806995451, 0.1073969566)
local Z_CONST = vector.create(0.0883024619, 0.2817188376, 0.6299787005)

local oklab = {}

function oklab.from_srgb(color: vector): vector
	local l = vector.dot(color, X_CONST) ^ (1 / 3)
	local m = vector.dot(color, Y_CONST) ^ (1 / 3)
	local s = vector.dot(color, Z_CONST) ^ (1 / 3)

	return vector.create(
		(0.2104542553 * l) + (0.7936177850 * m) - (0.0040720468 * s),
		(1.9779984951 * l) - (2.4285922050 * m) + (0.4505937099 * s),
		(0.0259040371 * l) + (0.7827717662 * m) - (0.8086757660 * s)
	)
end

function oklab.to_srgb(color: vector): vector
	local intermediate = vector.create(
		(color.x + 0.3963377774 * color.y + 0.2158037573 * color.z),
		(color.x - 0.1055613458 * color.y - 0.0638541728 * color.z),
		(color.x - 0.0894841775 * color.y - 1.2914855480 * color.z)
	)

	-- Cube it!
	intermediate = intermediate * intermediate * intermediate

	local l, m, s = intermediate.x, intermediate.y, intermediate.z

	return vector.create(
		4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
		-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
		-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
	)
end

return oklab
