local TEST, CASE, CHECK = require("@vendor/testkit").test()
local fluid = require("@src/")
local signal = require("@vendor/signal")

local scheduler = fluid.__SCHEDULER_INTERFACE
local step_by: signal.Identity<number> = signal()

scheduler.provide(function(render)
	while true do
		render(step_by:wait())
	end

	return error("unreachable")
end)

TEST("scheduler stepping", function()
	CASE("1 second delta time")
	do
		table.clear(scheduler.connections)
		local counted_seconds = 0

		scheduler.on_render(function(delta_time)
			counted_seconds += delta_time
		end)

		CHECK(counted_seconds == 0)
		step_by:fire(1)
		CHECK(counted_seconds == 1)
	end
end)

return nil
