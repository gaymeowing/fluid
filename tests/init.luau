local process = require("@lune/process")
local _, _, _, FINISH = require("@vendor/testkit").test()

local function tests()
	require("@self/unit_tests/reactive_graph.spec")
	require("@self/unit_tests/scheduler.spec")
	require("@self/unit_tests/bind.spec")

	local ok = FINISH()
	if not ok then
		process.exit(1)
	end
end

return tests
