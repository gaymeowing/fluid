local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local fluid = require(ReplicatedStorage.fluid)
local create = fluid.create
local keys = fluid.for_keys
local mount = fluid.mount
local source = fluid.source

local parent_screen = create("ScreenGui")({
	Name = "ParentScreen",
	ResetOnSpawn = false,
	Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
})

mount(function()
	return create("Frame")({
		Size = UDim2.fromScale(1, 1),
		Position = fluid.spring(
			fluid.interval(function()
				return UDim2.fromScale(math.random(), math.random())
			end),
			1,
			1
		),

		BackgroundColor3 = fluid.spring(
			fluid.interval(function()
				return Color3.fromRGB(
					math.random() * 255,
					math.random() * 255,
					math.random() * 255
				)
			end, 2),
			1,
			1
		),
	})
end, parent_screen)
