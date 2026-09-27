-- Static regression fixture. Run with check_style_sheet.py; do not execute.
local fluid = require("@src")
local style_sheet = require("@src/instances/style_sheet")

local base = style_sheet()
	:tokens({
		Inherited = 0.5,
		Override = "base",
	})
	:rule("Frame.base")({ BackgroundTransparency = "$Inherited" })

local sheet = fluid.style_sheet()
	:tokens({
		Alpha = 0.25,
		Color = Color3.new(1, 0, 0),
		Size = UDim.new(0, 8),
		Enabled = true,
		Minimum = Vector2.new(400, 0),
		Override = 0.75,
	})
	:rule("Frame.primary")({
	BackgroundTransparency = "$Alpha",
	BackgroundColor3 = "$Color",
	Visible = "$Enabled",
	Transition = { Default = TweenInfo.new(0.1), BackgroundTransparency = TweenInfo.new(0.1) },
	queries = {
		Wide = { Size = UDim2.fromOffset(400, 100), BackgroundTransparency = "$Alpha", MinSize = Vector2.new(400, 0) },
	},
})
	:rule("Frame.primary > TextLabel.title:Hover")({
	TextSize = 16,
})
	:rule(".rounded::UICorner")({
	CornerRadius = "$Size",
})
	:rule(".responsive::StyleQuery #Wide")({
	MinSize = "$Minimum",
})
	:rule(".primary@Wide, .responsive@Wide")({
	BackgroundTransparency = "$Alpha",
})
	:rule("TextLabel.label, TextButton.button")({
	TextSize = 18,
})
	:rule("Frame::UIStroke #Outer::UIGradient")({
	Rotation = 90,
})
	:tokens({ Later = 0.9 })
	:derive(base)
	:rule("Frame.final")({
	BackgroundTransparency = "$Inherited",
})

sheet:rule("Frame")({ BackgroundTransparency = "$Override" })
sheet:rule("Frame")({ BackgroundTransparency = "$Later" })
sheet:tags({ "primary", "title", "rounded", "responsive", "label", "button", "base", "final" })
sheet:tags({
	function(): "primary"?
		return nil
	end,
})
sheet:link()

-- An explicitly annotated selector must also preserve the receiver's tokens.
local annotated = style_sheet():tokens({ Alpha = 0.5 }):rule("Frame.test" :: "Frame.test")({
	BackgroundTransparency = "$Alpha",
})
local typed: style_sheet.Sheet<{ Alpha: number }, { test: true }> = annotated
typed:tags({ "test" })

local properties: fluid.StyleProperties<"TextLabel", { Color: Color3 }> = {
	TextColor3 = "$Color",
	TextSize = 14,
}
fluid.style_sheet():tokens({ Color = Color3.new() }):rule("TextLabel")(properties)

-- Verify generated keys, independent of call-site checking.
type FrameProperties = style_sheet.StyleProperties<"Frame", {}>
local property: keyof<FrameProperties> = "BackgroundTransparency"
local transition: keyof<index<FrameProperties, "Transition"> & {}> = "BackgroundTransparency"
print(property, transition)

-- Property tables stay optional and have no catch-all indexer. As with normal
-- Luau tables, extra fields are accepted; their keys are not generated.
type function PlainProperties(properties: type): type
	return types.singleton(properties:is("table") and properties:indexer() == nil)
end

type QueryProperties = index<index<FrameProperties, "queries"> & {}, string>
local plain_rule: PlainProperties<FrameProperties> = true
local plain_transition: PlainProperties<index<FrameProperties, "Transition"> & {}> = true
local plain_query: PlainProperties<QueryProperties> = true
style_sheet():rule("Frame")({ TextSize = 10 })
print(plain_rule, plain_transition, plain_query)
