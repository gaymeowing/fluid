local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local fluid = require("../../src")

local other = fluid.style_sheet():rule("Frame.primary")({
	BackgroundTransparency = 0.5,
})

local sheet = fluid.style_sheet()
	:tokens({
		BackgroundTween = TweenInfo.new(0.01),
		PrimaryTransparency = 0.25,
		SelectedTransparency = 0.75,
		QueryTransparency = 0.375,
	})
	:rule "Frame.primary" {
		BackgroundTransparency = "$PrimaryTransparency",
		Transition = {
			Default = TweenInfo.new(0.01),
			BackgroundTransparency = "$BackgroundTween",
		},
	}
	:rule "Frame.selected" {
		BackgroundTransparency = "$SelectedTransparency",
		TextSize = 10, -- Extra keys follow normal Luau table behavior.
	}
	:rule(".rounded::UICorner")({
		CornerRadius = UDim.new(0, 8),
	})
	:rule(".phantom::StyleQuery #Wide")({
		MinSize = Vector2.new(400, 0),
	})
	:rule(".responsive")({
		queries = {
			Wide = {
				MinSize = Vector2.new(400, 0),
				BackgroundTransparency = "$QueryTransparency",
			},
		},
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
local player_gui = Players.LocalPlayer:WaitForChild("PlayerGui")
screen.Parent = player_gui
other_screen.Parent = player_gui

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

settle()

assert(frame:HasTag("rounded"), "expected rounded tag")
assert(frame:HasTag("primary"), "expected primary tag from source")
assert(not frame:HasTag("selected"), "selected should be inactive")
assert(responsive_frame:HasTag("responsive"), "expected responsive tag")
assert(phantom_frame:HasTag("phantom"), "expected phantom tag")

assert(frame.BackgroundTransparency == 0.25, `primary transparency {frame.BackgroundTransparency}`)
assert(other_frame.BackgroundTransparency == 0.5, `derived primary {other_frame.BackgroundTransparency}`)

local corner = frame:FindFirstChildWhichIsA("UICorner")
assert(corner ~= nil and corner:IsA("UICorner"), "expected UICorner from .rounded::UICorner")
assert(corner.CornerRadius == UDim.new(0, 8), "expected CornerRadius")

current("selected")
settle()
assert(frame:HasTag("selected"), "expected selected tag")
assert(not frame:HasTag("primary"), "primary should clear")
assert(frame.BackgroundTransparency == 0.75, `selected transparency {frame.BackgroundTransparency}`)

responsive_frame.Size = UDim2.fromOffset(500, 100)
phantom_frame.Size = UDim2.fromOffset(500, 100)
settle()
assert(
	responsive_frame.BackgroundTransparency == 0.375,
	`responsive query transparency {responsive_frame.BackgroundTransparency}`
)
assert(
	phantom_frame.BackgroundTransparency == 0.375,
	`phantom query transparency {phantom_frame.BackgroundTransparency}`
)

local style_link = screen:FindFirstChildWhichIsA("StyleLink")
local other_link = other_screen:FindFirstChildWhichIsA("StyleLink")
assert(style_link ~= nil, "expected StyleLink on screen")
assert(other_link ~= nil, "expected StyleLink on other_screen")
assert(style_link.StyleSheet == sheet.instance, "StyleLink should point at sheet")
assert(other_link.StyleSheet == other.instance, "other StyleLink should point at other")

destroy()
destroy_other()
settle()

assert(style_link.Parent == nil, "StyleLink cleaned up")
assert(other_link.Parent == nil, "other StyleLink cleaned up")
assert(not frame:HasTag("rounded"), "tags cleaned up")
assert(not frame:HasTag("selected"), "selected cleaned up")

print("style_sheet.client ok")
