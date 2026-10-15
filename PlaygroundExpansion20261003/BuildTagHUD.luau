local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ink = Color3.fromRGB(24, 35, 62)
local paper = Color3.fromRGB(255, 250, 226)
local blue = Color3.fromRGB(54, 174, 255)
local red = Color3.fromRGB(255, 83, 100)
local yellow = Color3.fromRGB(255, 204, 54)
local headline = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local body = Font.new("rbxasset://fonts/families/FredokaOne.json")

local function make(className, name, parent, properties)
	local object = Instance.new(className)
	object.Name = name
	for key, value in pairs(properties or {}) do object[key] = value end
	object.Parent = parent
	return object
end

local function finish(object, color, radius)
	make("UICorner", "Corner", object, { CornerRadius = UDim.new(0, radius or 16) })
	make("UIStroke", "Outline", object, { Color = ink, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	object.BackgroundColor3 = color
	object.BorderSizePixel = 0
end

local function text(parent, name, value, position, size, font, color, maxSize)
	local label = make("TextLabel", name, parent, { BackgroundTransparency = 1, BorderSizePixel = 0,
		Position = position, Size = size, Text = value, TextColor3 = color or ink,
		FontFace = font or body, TextScaled = true, TextWrapped = true, ZIndex = 4 })
	make("UITextSizeConstraint", "TextLimit", label, { MinTextSize = 10, MaxTextSize = maxSize or 30 })
	return label
end

local assets = ReplicatedStorage:FindFirstChild("TagAssets") or make("Folder", "TagAssets", ReplicatedStorage)
if not assets:FindFirstChild("TaggerTemplate") then
	local billboard = make("BillboardGui", "TaggerTemplate", assets, { Size = UDim2.fromOffset(120, 48),
		StudsOffsetWorldSpace = Vector3.new(0, 3.8, 0), AlwaysOnTop = false, MaxDistance = 100,
		Enabled = true, LightInfluence = 0, ResetOnSpawn = false })
	local panel = make("Frame", "Panel", billboard, { Position = UDim2.fromScale(0.04, 0.06), Size = UDim2.fromScale(0.92, 0.85) })
	finish(panel, red, 12)
	text(panel, "Title", "YOU'RE IT!", UDim2.fromScale(0.04, 0.08), UDim2.fromScale(0.92, 0.83), headline, Color3.new(1, 1, 1), 28)
end
if StarterGui:FindFirstChild("TagHUD") then return { AlreadyExists = true, GUI = "StarterGui.TagHUD" } end
local gui = make("ScreenGui", "TagHUD", StarterGui, { Enabled = false, ResetOnSpawn = false,
	IgnoreGuiInset = false, DisplayOrder = 16, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
gui:SetAttribute("LayoutVersion", 1)
local top = make("Frame", "Top", gui, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.024), Size = UDim2.fromScale(0.44, 0.14) })
finish(top, paper)
make("UISizeConstraint", "SizeLimit", top, { MinSize = Vector2.new(290, 102), MaxSize = Vector2.new(620, 134) })
text(top, "Title", "TAG, YOU'RE IT!", UDim2.fromScale(0.035, 0.035), UDim2.fromScale(0.65, 0.27), headline, ink, 27)
text(top, "Timer", "3:00", UDim2.fromScale(0.73, 0.07), UDim2.fromScale(0.235, 0.47), headline, ink, 45)
local chip = make("Frame", "TaggerChip", top, { Position = UDim2.fromScale(0.035, 0.34), Size = UDim2.fromScale(0.65, 0.29) })
finish(chip, red, 10)
text(chip, "Name", "IT: PLAYER", UDim2.fromScale(0.035, 0.07), UDim2.fromScale(0.93, 0.85), body, Color3.new(1, 1, 1), 23)
text(top, "Rule", "LEAST TIME AS IT = SAFER", UDim2.fromScale(0.035, 0.72), UDim2.fromScale(0.93, 0.21), body, ink, 17)
local countdown = text(gui, "Countdown", "3", UDim2.fromScale(0.25, 0.34), UDim2.fromScale(0.5, 0.24), headline, Color3.new(1, 1, 1), 126)
countdown.Visible = false
countdown.Rotation = -3
make("UIStroke", "Outline", countdown, { Thickness = 6, Color = ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
local role = make("Frame", "Role", gui, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0.025, 0.955), Size = UDim2.fromScale(0.23, 0.085) })
finish(role, blue, 13)
make("UISizeConstraint", "SizeLimit", role, { MinSize = Vector2.new(145, 56), MaxSize = Vector2.new(285, 82) })
text(role, "Title", "RUNNER", UDim2.fromScale(0.04, 0.08), UDim2.fromScale(0.92, 0.43), headline, Color3.new(1, 1, 1), 29)
text(role, "Time", "TIME AS IT: 0.0s", UDim2.fromScale(0.04, 0.59), UDim2.fromScale(0.92, 0.28), body, ink, 18)
local protection = text(gui, "Protection", "TAGBACK SHIELD: 2s", UDim2.fromScale(0.30, 0.81), UDim2.fromScale(0.4, 0.055), body, yellow, 24)
protection.Visible = false
make("UIStroke", "Outline", protection, { Color = ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
local controls = make("Frame", "Controls", gui, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(0.975, 0.77),
	Size = UDim2.fromOffset(166, 132), BackgroundTransparency = 1, BorderSizePixel = 0 })
for index, action in ipairs({ "Vault", "Dodge" }) do
	local button = make("TextButton", action, controls, { Position = UDim2.fromOffset(0, (index - 1) * 69),
		Size = UDim2.fromOffset(166, 59), Text = action == "Vault" and "VAULT [Q]" or "DODGE [X]",
		FontFace = headline, TextScaled = true, TextColor3 = ink, AutoButtonColor = false })
	finish(button, action == "Vault" and yellow or blue, 14)
	make("UITextSizeConstraint", "TextLimit", button, { MinTextSize = 12, MaxTextSize = 25 })
end
local message = text(gui, "MoveMessage", "", UDim2.fromScale(0.23, 0.89), UDim2.fromScale(0.54, 0.05), body, Color3.new(1, 1, 1), 22)
make("UIStroke", "Outline", message, { Color = ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
local results = make("Frame", "Results", gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47),
	Size = UDim2.fromScale(0.56, 0.39), Visible = false, ZIndex = 10 })
finish(results, paper)
make("UISizeConstraint", "SizeLimit", results, { MinSize = Vector2.new(290, 215), MaxSize = Vector2.new(720, 350) })
text(results, "Title", "YOU WIN!", UDim2.fromScale(0.04, 0.06), UDim2.fromScale(0.92, 0.25), headline, blue, 54)
text(results, "Loser", "MOST TIME AS IT: PLAYER", UDim2.fromScale(0.07, 0.36), UDim2.fromScale(0.86, 0.19), body, red, 23)
local scroll = make("ScrollingFrame", "WinnersScroll", results, { Position = UDim2.fromScale(0.065, 0.61), Size = UDim2.fromScale(0.87, 0.31),
	BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4, ScrollBarImageColor3 = ink })
local winners = text(scroll, "Winners", "Winners", UDim2.fromScale(0.02, 0), UDim2.fromScale(0.96, 0), body, ink, 23)
winners.TextScaled = false
winners.TextSize = 20
winners.AutomaticSize = Enum.AutomaticSize.Y
winners.TextYAlignment = Enum.TextYAlignment.Top
return { GUI = gui:GetFullName(), Descendants = #gui:GetDescendants(), Template = assets.TaggerTemplate:GetFullName() }
