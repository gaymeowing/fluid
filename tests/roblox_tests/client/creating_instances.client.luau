local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local fluid = require(ReplicatedStorage.fluid)

local function iso_date()
	return fluid.create("ScreenGui")({
		Name = "iso",

		fluid.create("TextLabel")({
			Text = fluid.interval(function()
				return DateTime.now():ToIsoDate()
			end),

			Size = UDim2.fromScale(0.25, 0.25),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
		}),
	})
end

fluid.mount(function()
	return { iso_date() }
end, Players.LocalPlayer.PlayerGui)
