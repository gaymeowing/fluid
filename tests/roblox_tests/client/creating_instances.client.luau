local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local fluid = require(ReplicatedStorage.fluid)

local function iso_date()
	local text = fluid.interval(function()
		return string.rep("W", math.random(1, 20))
	end)

	return fluid.create("ScreenGui")({
		Name = "iso",

		fluid.create("TextButton")({
			Text = text,

			Activated = function()
				print("button pressed!")
			end,

			Size = fluid.async(function(set)
				local text_value = text()

				local params = Instance.new("GetTextBoundsParams")
				params.Text = text_value

				local bounds = TextService:GetTextBoundsAsync(params)

				print("evaluating")

				return UDim2.fromOffset(bounds.X, bounds.Y)
			end),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
		}),
	})
end

fluid.mount(function()
	return { iso_date() }
end, Players.LocalPlayer.PlayerGui)
