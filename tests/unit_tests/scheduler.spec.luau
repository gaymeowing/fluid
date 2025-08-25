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
	do
		CASE("1 second delta time")
		table.clear(scheduler.connections)
		local counted_seconds = 0

		local function func(delta_time: number)
			counted_seconds += delta_time
		end
		local disconnect = scheduler.on_render(func)

		CHECK(scheduler.connections[1] == func)
		CHECK(counted_seconds == 0)
		render_event:fire(1)

		CHECK(counted_seconds == 1)

		CASE("check disconnected")

		disconnect()
		CHECK(scheduler.connections[1] == nil)
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

			local value = fluid.interval(function(dt)
				CHECK(dt == 1 or dt == 0)
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

TEST(
	"interval",
	wrap_root(function()
		do
			CASE("go active")

			local interval_run_time = 0
			local destroy = fluid.root(function()
				fluid.interval(function(dt)
					CHECK(dt == 0)
					interval_run_time += 1
					return 1
				end)
			end)

			CHECK(interval_run_time == 1)
			render_event:fire(0)
			CHECK(interval_run_time == 2)

			CASE("cleanup")

			destroy()

			render_event:fire(0)
			render_event:fire(0)
			render_event:fire(0)

			CHECK(interval_run_time == 2)
		end

		do
			CASE("does not trigger while inactive")

			table.clear(scheduler.connections)

			local is_active = fluid.source(false)
			local interval_run_time = 0
			local destroy = fluid.root(function()
				fluid.effect(function()
					if is_active() then
						fluid.interval(function(dt)
							CHECK(dt == 0)
							interval_run_time += 1
							return 1
						end)
					end
				end)
			end)

			CHECK(interval_run_time == 0)
			render_event:fire(0)
			CHECK(interval_run_time == 0)
			CHECK(scheduler.connections[1] == nil)

			CASE("go active")

			is_active(true)
			CHECK(interval_run_time == 1)
			CHECK(scheduler.connections[1] ~= nil)
			render_event:fire(0)
			CHECK(interval_run_time == 2)

			CASE("go inactive")

			is_active(false)
			CHECK(interval_run_time == 2)
			render_event:fire(0)
			CHECK(interval_run_time == 2)

			CASE("go active again")

			is_active(true)
			CHECK(scheduler.connections[1] ~= nil)
			CHECK(interval_run_time == 3)

			CASE("cleanup")

			destroy()
			CHECK(interval_run_time == 3)
			render_event:fire(0)
			CHECK(interval_run_time == 3)
			CHECK(scheduler.connections[1] == nil)
		end

		do
			CASE("interval with hz paramater, should always output hz")
			table.clear(scheduler.connections)

			local HZ = 100
			local dt = 0
			fluid.interval(function(a)
				dt = a
				return 0
			end, HZ)

			CHECK(dt == (1 / HZ))

			CASE("other runs")

			for i = 1, 4 do
				render_event:fire(i)
				CHECK(dt == (1 / HZ))
			end
		end

		do
			CASE("interval with no 'hz' paramater, should start with 0, and become delta_time")
			table.clear(scheduler.connections)

			local dt = -1
			fluid.interval(function(a)
				dt = a
				return 0
			end)

			CHECK(dt == 0)

			CASE("other runs")

			for i = 1, 4 do
				render_event:fire(i)
				CHECK(dt == i)
			end
		end

		do
			CASE("interval in async")
			table.clear(scheduler.connections)

			local num = fluid.source(0)

			local counter = 0
			local value: () -> ...any
			local destroy = fluid.root(function()
				value = fluid.async(function()
					num()

					fluid.interval(function()
						counter += 1
						return 0
					end)
					coroutine.yield()
					return 0
				end)
			end)

			value()
			CHECK(counter == 1)
			CHECK(scheduler.connections[1] ~= nil)
			CHECK(scheduler.connections[2] == nil)

			CASE("previous interval should cleaned up")

			num(1)
			value()

			CHECK(counter == 2)
			CHECK(scheduler.connections[1] ~= nil)
			CHECK(scheduler.connections[2] == nil) -- if two interval was active then 'interval' didn't get cleaned up

			CASE("cleanup")
			destroy()
			CHECK(counter == 2)
			CHECK(scheduler.connections[1] == nil)
			CHECK(scheduler.connections[2] == nil)
		end
	end)
)

return nil
