local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local fluid = require(ReplicatedStorage.fluid)

local sheet = fluid.style_sheet():tokens({
	PrimaryTransparency = 0.25,
	SelectedTransparency = 0.75,
	QueryTransparency = 0.375,
})
sheet:rule("Frame.primary")({
	BackgroundTransparency = "$PrimaryTransparency",
	Transition = {
		Default = TweenInfo.new(0.01),
		BackgroundTransparency = TweenInfo.new(0.01),
	},
})
sheet:rule("Frame.selected")({
	BackgroundTransparency = "$SelectedTransparency",
})
sheet:rule(".rounded::UICorner")({
	CornerRadius = UDim.new(0, 8),
})
sheet:rule(".phantom::StyleQuery #Wide")({
	MinSize = Vector2.new(400, 0),
})
sheet:rule(".responsive")({
	queries = {
		Wide = { MinSize = Vector2.new(400, 0) },
	},
})
sheet:rule(".responsive@Wide, .phantom@Wide")({
	BackgroundTransparency = "$QueryTransparency",
})

local other = fluid.style_sheet()
other:rule("Frame.primary")({
	BackgroundTransparency = 0.5,
})
sheet:derive(other)

sheet.instance.Parent = ReplicatedStorage
other.instance.Parent = ReplicatedStorage

local typed_sheet: fluid.StyleSheet<{
	PrimaryTransparency: number,
	SelectedTransparency: number,
	QueryTransparency: number,
}, {
	primary: true,
	selected: true,
	rounded: true,
	responsive: true,
	phantom: true,
}> =
	sheet
local current = fluid.source("primary" :: "primary" | "selected" | nil)
local frame = Instance.new("Frame")
local other_frame = Instance.new("Frame")
local responsive_frame = Instance.new("Frame")
responsive_frame.Size = UDim2.fromOffset(200, 100)
local phantom_frame = Instance.new("Frame")
phantom_frame.Size = UDim2.fromOffset(200, 100)
local screen = Instance.new("ScreenGui")
local other_screen = Instance.new("ScreenGui")
frame.Parent = screen
responsive_frame.Parent = screen
phantom_frame.Parent = screen
other_frame.Parent = other_screen
screen.Parent = Players.LocalPlayer.PlayerGui
other_screen.Parent = Players.LocalPlayer.PlayerGui

local function settle()
	fluid.graph.flush_deferred_nodes()
	RunService.PreRender:Wait()
	RunService.PreRender:Wait()
end

local destroy = fluid.root(function()
	fluid.bind(screen, { typed_sheet:link() })
	fluid.bind(frame, { typed_sheet:tags({ "rounded", current }) })
	fluid.bind(responsive_frame, { typed_sheet:tags({ "responsive" }) })
	fluid.bind(phantom_frame, { typed_sheet:tags({ "phantom" }) })
end)
local destroy_other = fluid.root(function()
	fluid.bind(other_screen, { other:link() })
	fluid.bind(other_frame, { other:tags({ "primary" }) })
end)

local success, message = pcall(function()
	for _, rule in sheet.instance:GetChildren() do
		assert(rule:IsA("StyleRule"))
		assert(rule.SelectorError == "", rule.SelectorError)
	end

	assert(sheet.instance:GetAttribute("PrimaryTransparency") == 0.25)
	assert(sheet.instance:GetAttribute("SelectedTransparency") == 0.75)
	assert(sheet.instance:GetAttribute("QueryTransparency") == 0.375)

	local primary = sheet.instance:FindFirstChild("Frame.primary")
	local selected = sheet.instance:FindFirstChild("Frame.selected")
	local responsive = sheet.instance:FindFirstChild(".responsive")
	local other_primary = other.instance:FindFirstChild("Frame.primary")
	assert(primary and primary:IsA("StyleRule"))
	assert(selected and selected:IsA("StyleRule"))
	assert(responsive and responsive:IsA("StyleRule"))
	assert(other_primary and other_primary:IsA("StyleRule"))
	assert(primary:GetProperties().BackgroundTransparency == "$PrimaryTransparency")
	assert(primary.Selector == "Frame.primary" and other_primary.Selector == "Frame.primary")
	assert(selected.Selector == "Frame.selected")
	assert(primary:GetDefaultPropertyTransition().Time == 0.01)
	assert(primary:GetPropertyTransitions().BackgroundTransparency.Time == 0.01)

	local query = responsive:FindFirstChild("Wide")
	assert(query and query:IsA("StyleQuery"))
	assert(query.Parent == responsive and query.Name == "Wide")
	assert(query:GetCondition("MinSize") == Vector2.new(400, 0))

	local derives = sheet.instance:GetDerives()
	assert(#derives == 1 and derives[1] == other.instance)

	local primary_tag = "primary"
	local selected_tag = "selected"

	settle()
	assert(frame:HasTag(primary_tag))
	assert(frame:GetStyled("BackgroundTransparency") == 0.25)
	assert(other_frame:GetStyled("BackgroundTransparency") == 0.5)
	assert(frame:GetStyled("CornerRadius", "::UICorner") == UDim.new(0, 8))
	assert(responsive_frame:GetStyled("BackgroundTransparency") == 0)
	assert(phantom_frame:GetStyled("BackgroundTransparency") == 0)
	assert(not query.IsActive)
	responsive_frame.Size = UDim2.fromOffset(500, 100)
	phantom_frame.Size = UDim2.fromOffset(500, 100)
	settle()
	assert(query.IsActive, "StyleQuery on StyleRule must activate at MinSize")
	assert(responsive_frame:GetStyled("BackgroundTransparency") == 0.375, "StyleQuery must activate at MinSize")
	assert(phantom_frame:GetStyled("BackgroundTransparency") == 0.375, "phantom StyleQuery must still work")
	responsive_frame.Size = UDim2.fromOffset(200, 100)
	phantom_frame.Size = UDim2.fromOffset(200, 100)
	settle()
	assert(not query.IsActive)
	assert(responsive_frame:GetStyled("BackgroundTransparency") == 0, "StyleQuery must deactivate below MinSize")
	assert(phantom_frame:GetStyled("BackgroundTransparency") == 0)

	current("selected")
	settle()
	assert(not frame:HasTag(primary_tag) and frame:HasTag(selected_tag))
	assert(frame:GetStyled("BackgroundTransparency") == 0.75)

	current(nil)
	settle()
	assert(not frame:HasTag(selected_tag))
	assert(frame:GetStyled("BackgroundTransparency") == 0)

	-- A link action can be reused without reparenting an existing link.
	local extra_screen = Instance.new("ScreenGui")
	local destroy_extra = fluid.root(function()
		fluid.bind(extra_screen, { sheet:link() })
	end)
	assert(extra_screen:FindFirstChildOfClass("StyleLink"))
	assert(screen:FindFirstChildOfClass("StyleLink"))
	destroy_extra()
	assert(not extra_screen:FindFirstChildOfClass("StyleLink"))
	assert(screen:FindFirstChildOfClass("StyleLink"))
	extra_screen:Destroy()

	-- Cleanup removes tags and links but leaves a shared sheet alive.
	current("primary")
	settle()
	assert(frame:HasTag(primary_tag))
end)

destroy()
destroy_other()

local cleanup_success, cleanup_message = pcall(function()
	assert(#frame:GetTags() == 0 and #other_frame:GetTags() == 0)
	assert(#responsive_frame:GetTags() == 0)
	assert(#phantom_frame:GetTags() == 0)
	local responsive = sheet.instance:FindFirstChild(".responsive")
	assert(responsive and responsive:FindFirstChild("Wide"), "query lifetime belongs to its rule")
	assert(not screen:FindFirstChildOfClass("StyleLink"))
	assert(not other_screen:FindFirstChildOfClass("StyleLink"))
	assert(sheet.instance.Parent == ReplicatedStorage)
	current("selected")
	settle()
	assert(#frame:GetTags() == 0, "disposed actions must stop reacting")
end)

screen:Destroy()
other_screen:Destroy()
sheet.instance:Destroy()
other.instance:Destroy()

assert(success, message)
assert(cleanup_success, cleanup_message)
print("style_sheet: tokens, transitions, nested queries, derive, reactivity, and cleanup passed")
