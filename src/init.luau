local cleanup = require("@self/reactive/cleanup")
local derive = require("@self/reactive/derive")
local effect = require("@self/reactive/effect")
local graph = require("@self/reactive/graph")
local root = require("@self/reactive/root")
local source = require("@self/reactive/source")
local types = require("@self/reactive/types")
local untrack = require("@self/reactive/untrack")

export type UsedAs<T> = types.UsedAs<T>
export type Source<T> = types.Source<T>

local fluid = {}

fluid.cleanup = cleanup
fluid.derive = derive
fluid.effect = effect
fluid.graph = graph
fluid.root = root
fluid.source = source
fluid.untrack = untrack

return fluid
