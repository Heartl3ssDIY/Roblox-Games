local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local ink = Color3.fromRGB(24, 35, 62)
local paper = Color3.fromRGB(255, 250, 226)
local blue = Color3.fromRGB(42, 160, 255)
local red = Color3.fromRGB(255, 81, 92)
local yellow = Color3.fromRGB(255, 204, 54)
local white = Color3.fromRGB(255, 255, 255)
local headlineFont = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local bodyFont = Font.new("rbxasset://fonts/families/FredokaOne.json")

local function make(className, name, parent, properties)
	local object = Instance.new(className)
	object.Name = name
	for key, value in pairs(properties or {}) do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function corner(parent, radius)
	return make("UICorner", "Corner", parent, { CornerRadius = UDim.new(0, radius) })
end

local function stroke(parent, thickness, mode, color)
	return make("UIStroke", "Outline", parent, {
		Color = color or ink,
		Thickness = thickness,
		ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

local function label(parent, name, text, position, size, font, color, maxSize, minSize, zIndex)
	local object = make("TextLabel", name, parent, {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = position,
		Size = size,
		Text = text,
		TextColor3 = color or ink,
		FontFace = font or bodyFont,
		TextScaled = true,
		TextWrapped = true,
		ZIndex = zIndex or 4,
	})
	make("UITextSizeConstraint", "TextSizeLimit", object, {
		MinTextSize = minSize or 10,
		MaxTextSize = maxSize or 32,
	})
	return object
end

local function card(parent, name, position, size, minSize, maxSize, color, zIndex)
	local container = make("Frame", name, parent, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex or 2,
	})
	make("UISizeConstraint", "SizeLimit", container, {
		MinSize = minSize,
		MaxSize = maxSize,
	})
	local shadow = make("Frame", "Shadow", container, {
		Position = UDim2.fromOffset(0, 5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = ink,
		BorderSizePixel = 0,
		ZIndex = zIndex or 2,
	})
	corner(shadow, 16)
	local panel = make("Frame", "Panel", container, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color or paper,
		BorderSizePixel = 0,
		ZIndex = (zIndex or 2) + 1,
	})
	corner(panel, 16)
	stroke(panel, 4)
	return container, panel
end

local assets = ReplicatedStorage:FindFirstChild("BritishBulldogAssets")
if not assets then
	assets = make("Folder", "BritishBulldogAssets", ReplicatedStorage)
end

local taggedTemplate = assets:FindFirstChild("TaggedTemplate")
if not taggedTemplate then
	taggedTemplate = make("BillboardGui", "TaggedTemplate", assets, {
		Size = UDim2.fromOffset(160, 54),
		StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0),
		AlwaysOnTop = false,
		MaxDistance = 85,
		Enabled = true,
		LightInfluence = 0,
		ResetOnSpawn = false,
	})
	local panel = make("Frame", "Panel", taggedTemplate, {
		Position = UDim2.fromScale(0.025, 0.06),
		Size = UDim2.fromScale(0.95, 0.84),
		BackgroundColor3 = yellow,
		BorderSizePixel = 0,
	})
	corner(panel, 13)
	stroke(panel, 3)
	label(panel, "TaggedLabel", "TAGGED", UDim2.fromScale(0.06, 0.10), UDim2.fromScale(0.88, 0.82), headlineFont, ink, 31, 12)
end

local music = SoundService:FindFirstChild("BritishBulldogMusic")
if not music then
	music = make("Sound", "BritishBulldogMusic", SoundService, {
		SoundId = "",
		Volume = 0.35,
		Looped = true,
		Playing = false,
	})
	music:SetAttribute("Enabled", false)
end

local existing = StarterGui:FindFirstChild("BritishBulldogHUD")
if existing then
	return {
		HUD = existing:GetFullName(),
		AlreadyExists = true,
		TaggedTemplate = taggedTemplate:GetFullName(),
		Music = music:GetFullName(),
	}
end

local gui = make("ScreenGui", "BritishBulldogHUD", StarterGui, {
	Enabled = false,
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	DisplayOrder = 15,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
gui:SetAttribute("LayoutVersion", 1)

local topCard, topPanel = card(gui, "TopCard", UDim2.fromScale(0.5, 0.025), UDim2.fromScale(0.44, 0.125), Vector2.new(290, 92), Vector2.new(600, 120), paper)
topCard.AnchorPoint = Vector2.new(0.5, 0)
label(topPanel, "GameTitle", "BRITISH BULLDOG", UDim2.fromScale(0.035, 0.06), UDim2.fromScale(0.93, 0.20), headlineFont, ink, 24, 12)

local bulldogChip = make("Frame", "BulldogChip", topPanel, {
	Position = UDim2.fromScale(0.025, 0.35),
	Size = UDim2.fromScale(0.30, 0.48),
	BackgroundColor3 = red,
	BorderSizePixel = 0,
	ZIndex = 4,
})
corner(bulldogChip, 11)
stroke(bulldogChip, 3)
label(bulldogChip, "Count", "1", UDim2.fromScale(0.035, 0.07), UDim2.fromScale(0.29, 0.87), headlineFont, white, 38, 14, 5)
label(bulldogChip, "Caption", "BULLDOG", UDim2.fromScale(0.325, 0.23), UDim2.fromScale(0.635, 0.58), bodyFont, ink, 20, 9, 5)

local runnerChip = make("Frame", "RunnerChip", topPanel, {
	Position = UDim2.fromScale(0.675, 0.35),
	Size = UDim2.fromScale(0.30, 0.48),
	BackgroundColor3 = blue,
	BorderSizePixel = 0,
	ZIndex = 4,
})
corner(runnerChip, 11)
stroke(runnerChip, 3)
label(runnerChip, "Count", "23", UDim2.fromScale(0.035, 0.07), UDim2.fromScale(0.29, 0.87), headlineFont, white, 38, 14, 5)
label(runnerChip, "Caption", "RUNNERS", UDim2.fromScale(0.325, 0.23), UDim2.fromScale(0.635, 0.58), bodyFont, ink, 20, 9, 5)

local timer = label(topPanel, "Timer", "3:00", UDim2.fromScale(0.35, 0.29), UDim2.fromScale(0.30, 0.48), headlineFont, ink, 51, 24)
label(topPanel, "PhaseLabel", "CROSSING 1", UDim2.fromScale(0.34, 0.79), UDim2.fromScale(0.32, 0.16), bodyFont, ink, 15, 9)

local countdown = label(gui, "Countdown", "3", UDim2.fromScale(0.225, 0.32), UDim2.fromScale(0.55, 0.24), headlineFont, white, 130, 20, 20)
countdown.Rotation = -3
countdown.Visible = false
stroke(countdown, 6, Enum.ApplyStrokeMode.Contextual)

local rolePill, rolePanel = card(gui, "RolePill", UDim2.fromScale(0.035, 0.965), UDim2.fromScale(0.23, 0.062), Vector2.new(150, 36), Vector2.new(300, 58), blue)
rolePill.AnchorPoint = Vector2.new(0, 1)
label(rolePanel, "RoleLabel", "RUNNER", UDim2.fromScale(0.06, 0.12), UDim2.fromScale(0.88, 0.77), headlineFont, white, 31, 15)

local departure, departurePanel = card(gui, "Departure", UDim2.fromScale(0.5, 0.855), UDim2.fromScale(0.34, 0.092), Vector2.new(250, 62), Vector2.new(490, 100), yellow, 7)
departure.Visible = false
label(departurePanel, "Prompt", "LEAVE SAFE ZONE", UDim2.fromScale(0.04, 0.12), UDim2.fromScale(0.72, 0.78), bodyFont, ink, 28, 14, 9)
local secondsBadge = make("Frame", "SecondsBadge", departurePanel, {
	Position = UDim2.fromScale(0.795, 0.12),
	Size = UDim2.fromScale(0.175, 0.74),
	BackgroundColor3 = white,
	BorderSizePixel = 0,
	ZIndex = 9,
})
corner(secondsBadge, 11)
stroke(secondsBadge, 3)
label(secondsBadge, "Seconds", "5", UDim2.fromScale(0.10, 0.08), UDim2.fromScale(0.80, 0.84), headlineFont, ink, 52, 20, 10)

local tagged, taggedPanel = card(gui, "Tagged", UDim2.fromScale(0.5, 0.74), UDim2.fromScale(0.29, 0.12), Vector2.new(240, 74), Vector2.new(460, 120), yellow, 7)
tagged.Visible = false
label(taggedPanel, "Title", "TAGGED", UDim2.fromScale(0.06, 0.07), UDim2.fromScale(0.88, 0.54), headlineFont, ink, 46, 24, 9)
label(taggedPanel, "Status", "FROZEN", UDim2.fromScale(0.06, 0.65), UDim2.fromScale(0.88, 0.24), bodyFont, ink, 23, 12, 9)

local results, resultsPanel = card(gui, "Results", UDim2.fromScale(0.5, 0.45), UDim2.fromScale(0.55, 0.30), Vector2.new(290, 200), Vector2.new(720, 310), paper, 12)
results.Visible = false
label(resultsPanel, "RoundLabel", "ROUND FINISHED", UDim2.fromScale(0.08, 0.10), UDim2.fromScale(0.84, 0.13), bodyFont, ink, 23, 12, 14)
label(resultsPanel, "Title", "SURVIVORS WIN!", UDim2.fromScale(0.04, 0.28), UDim2.fromScale(0.92, 0.30), headlineFont, blue, 56, 24, 14)
local winnersScroll = make("ScrollingFrame", "WinnersScroll", resultsPanel, {
	Position = UDim2.fromScale(0.075, 0.63),
	Size = UDim2.fromScale(0.85, 0.29),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.fromScale(0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = ink,
	ZIndex = 14,
})
local winnersLabel = label(winnersScroll, "Winners", "Player names", UDim2.fromScale(0.03, 0), UDim2.fromScale(0.94, 0), bodyFont, ink, 28, 12, 15)
winnersLabel.TextScaled = false
winnersLabel.TextSize = 20
winnersLabel.AutomaticSize = Enum.AutomaticSize.Y
winnersLabel.TextYAlignment = Enum.TextYAlignment.Top

return {
	HUD = gui:GetFullName(),
	Descendants = #gui:GetDescendants(),
	Enabled = gui.Enabled,
	TaggedTemplate = taggedTemplate:GetFullName(),
	Music = music:GetFullName(),
	RuntimeScriptInstalled = false,
}
