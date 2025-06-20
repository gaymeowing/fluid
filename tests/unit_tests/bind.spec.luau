local TEST, CASE, CHECK = require("@vendor/testkit").test()
local bind = require("@src/instances/bind")
local fluid = require("@src/")
local task = require("@lune/task")

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

TEST(
	"async bindings",
	wrap_root(function()
		local text = fluid.source("hi")

		local mock_inst = {
			derivedvalue = 0,
		}

		bind({
			derivedvalue = fluid.async(function(set)
				task.wait(0.02)
				return #text()
			end),
		}, mock_inst :: any)

		task.wait(0.05)

		CHECK(mock_inst.derivedvalue == 2)

		text("one")
		task.wait(0.05)
		CHECK(mock_inst.derivedvalue == 3)
	end)
)

return nil
