if _G.__DEV__ == nil then
	-- thanks type state
	_G.__DEV__ = (game and not game:GetService("RunService"):IsStudio()) :: any
end

local cleanup = require("@self/reactive/cleanup")
local create = require("@self/instances/create")
local derive = require("@self/reactive/derive")
local effect = require("@self/reactive/effect")
local graph = require("@self/reactive/graph")
local root = require("@self/reactive/root")
local scheduler = require("@self/scheduler")
local source = require("@self/reactive/source")
local types = require("@self/reactive/types")
local untrack = require("@self/reactive/untrack")

export type UsedAs<T> = types.UsedAs<T>
export type Source<T> = types.Source<T>

if game then
	local RunService = game:GetService("RunService")

	scheduler.provide(function(render)
		while true do
			local delta_time = RunService.PreRender:Wait()

			render(delta_time)
		end

		return error("unreachable")
	end)
end

local fluid = {}

fluid.create = create

-- Reactive graph
fluid.cleanup = cleanup
fluid.derive = derive
fluid.effect = effect
fluid.graph = graph
fluid.root = root
fluid.source = source
fluid.untrack = untrack

fluid.__SCHEDULER_INTERFACE = scheduler

return fluid
