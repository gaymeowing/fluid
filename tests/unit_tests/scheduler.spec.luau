local TEST, CASE, CHECK = require("@vendor/testkit").test()
local fluid = require("@src/")
local signal = require("@vendor/signal")
local task = require("@lune/task")

local scheduler = fluid.__SCHEDULER_INTERFACE
local render_event: signal.Identity<number> = signal()

local step_fluid = fluid.provide_scheduler()

task.spawn(function()
	while true do
		step_fluid(render_event:wait())
	end

	return error("unreachable")
end)

--[=[
	Sandboxes the reactive graph root so we don't need to worry about side effects with implicit dependencies
]=]
local function wrap_root(fn: () -> ())
	return function()
		local destroy = fluid.root(function()
			fn()
		end)
		destroy()
	end
end

TEST("scheduler stepping", function()
	CASE("1 second delta time")
	do
		table.clear(scheduler.connections)
		local counted_seconds = 0

		scheduler.on_render(function(delta_time)
			counted_seconds += delta_time
		end)

		CHECK(counted_seconds == 0)
		render_event:fire(1)
		CHECK(counted_seconds == 1)
	end
end)

TEST(
	"bind_frame",
	wrap_root(function()
		CASE("polls each render")
		do
			table.clear(scheduler.connections)
			local counted_seconds = 0

			scheduler.on_render(function(delta_time)
				counted_seconds += delta_time
			end)

			local value = fluid.interval(function()
				return counted_seconds
			end)

			render_event:fire(1)
			CHECK(value() == 1)
		end
	end)
)

TEST(
	"spring",
	wrap_root(function()
		for _, test in
			{
				{ 5, 15, 5, -5, -60, 60, 20 },
				{
					vector.create(5, 10),
					vector.create(10, 5),
					vector.create(-5, -10),
					vector.create(1, 7),
					vector.create(0, 0),
					vector.create(10, 10),
				},
			}
		do
			local spring_target = fluid.source(test[1])
			local spring, controls = fluid.spring(spring_target, 10, 1)
			local data_type = type(test[1])

			local function rng_self_type(): vector | number
				if data_type == "vector" then
					return vector.create(math.random(), math.random(), math.random())
				end
				return math.random()
			end

			for i = 2, #test do
				local target = test[i]

				CASE(`spring [{test[i - 1]}] to [{target}]`)
				spring_target(target)
				render_event:fire(1 / 60)
				CHECK(spring() ~= target)
				render_event:fire(100)
				CHECK(spring() == target)

				CASE(`spring position`)
				controls({
					position = rng_self_type() * 10,
				})
				render_event:fire(1 / 60)
				CHECK(spring() ~= target)
				render_event:fire(3)
				CHECK(spring() == target)

				CASE(`spring velocity [self-type]`)
				controls({
					velocity = rng_self_type() * 10,
				})
				render_event:fire(1 / 60)
				CHECK(spring() ~= target)
				render_event:fire(3)
				CHECK(spring() == target)

				CASE(`spring impulse [self-type]`)
				controls({
					impulse = rng_self_type() * 10,
				})

				render_event:fire(1 / 60)
				CHECK(spring() ~= target)
				render_event:fire(3)
				CHECK(spring() == target)
			end
		end
	end)
)

return nil
