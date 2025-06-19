local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local fluid = require(ReplicatedStorage.fluid)

local part = fluid.create("Part")({
	Parent = Workspace,

	fluid.create("PointLight")({}),
})

print(part)
