local ReplicatedStorage = game:GetService("ReplicatedStorage")

local fluid = require(ReplicatedStorage.fluid)

local create = fluid.create
local scale = UDim2.fromScale
local px = UDim2.fromOffset

fluid.mount(function()
	local color = fluid.source(Color3.new())
	local size = fluid.source(px(60, 60))

	fluid.effect(function()
		color()
		size()

		task.delay(0.2, function()
			if color() == Color3.new(1, 1, 1) then
				color(Color3.new(0, 0, 0))
				size(px(60, 60))
			end
		end)
	end)

	return create("ScreenGui")({

		create("TextButton")({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = scale(0.5, 0.5),
			AutoButtonColor = false,

			BackgroundColor3 = color,
			Size = size,

			Text = "",

			MouseButton1Click = function()
				color(Color3.new(1, 1, 1))
				size(px(150, 60))
			end,
		}),
	})
end, game:GetService("Players").LocalPlayer.PlayerGui)
