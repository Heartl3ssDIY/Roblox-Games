local StarterGui = game:GetService("StarterGui")

local existing = StarterGui:FindFirstChild("PlaygroundAdminPanel")
if existing then
	return { GUI = existing:GetFullName(), AlreadyExists = true }
end

local ink = Color3.fromRGB(24, 35, 62)
local paper = Color3.fromRGB(255, 250, 226)
local white = Color3.fromRGB(255, 255, 255)
local blue = Color3.fromRGB(42, 160, 255)
local red = Color3.fromRGB(255, 81, 92)
local yellow = Color3.fromRGB(255, 204, 54)
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
	make("UICorner", "Corner", parent, { CornerRadius = UDim.new(0, radius) })
end

local function stroke(parent, thickness)
	make("UIStroke", "Outline", parent, {
		Color = ink,
		Thickness = thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

local function label(parent, name, text, position, size, font, color, maxTextSize)
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
		ZIndex = 4,
	})
	make("UITextSizeConstraint", "TextSizeLimit", object, {
		MinTextSize = 10,
		MaxTextSize = maxTextSize or 24,
	})
	return object
end

local function button(parent, name, text, position, size, color, maxTextSize)
	local object = make("TextButton", name, parent, {
		Position = position,
		Size = size,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AutoButtonColor = true,
		Text = text,
		TextColor3 = ink,
		FontFace = headlineFont,
		TextScaled = true,
		TextWrapped = true,
		ZIndex = 4,
	})
	make("UITextSizeConstraint", "TextSizeLimit", object, {
		MinTextSize = 10,
		MaxTextSize = maxTextSize or 23,
	})
	make("UIPadding", "TextPadding", object, {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		PaddingTop = UDim.new(0, 3),
		PaddingBottom = UDim.new(0, 3),
	})
	corner(object, 11)
	stroke(object, 3)
	object:SetAttribute("ReadyColor", color)
	return object
end

local gui = make("ScreenGui", "PlaygroundAdminPanel", StarterGui, {
	Enabled = false,
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	DisplayOrder = 40,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
gui:SetAttribute("LayoutVersion", 2)

button(gui, "Toggle", "ADMIN", UDim2.fromOffset(16, 16), UDim2.fromOffset(112, 42), yellow, 24)

local panel = make("Frame", "Panel", gui, {
	Position = UDim2.fromOffset(16, 70),
	Size = UDim2.new(0.34, 0, 0.72, 0),
	BackgroundColor3 = paper,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 2,
})
make("UISizeConstraint", "SizeLimit", panel, {
	MinSize = Vector2.new(280, 190),
	MaxSize = Vector2.new(380, 470),
})
corner(panel, 16)
stroke(panel, 4)

label(panel, "Title", "PLAYGROUND ADMIN", UDim2.fromScale(0.055, 0.035), UDim2.fromScale(0.79, 0.075), headlineFont, ink, 28)
button(panel, "Close", "X", UDim2.fromScale(0.87, 0.025), UDim2.fromScale(0.085, 0.085), white, 23)

local body = make("ScrollingFrame", "Body", panel, {
	Position = UDim2.fromScale(0.045, 0.135),
	Size = UDim2.fromScale(0.91, 0.825),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.fromScale(0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = ink,
	ZIndex = 3,
})
local content = make("Frame", "Content", body, {
	Position = UDim2.fromOffset(4, 4),
	Size = UDim2.new(1, -14, 0, 380),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 3,
})
local gameCard = make("Frame", "GameCard", content, {
	Size = UDim2.fromScale(1, 0.70),
	BackgroundColor3 = white,
	BorderSizePixel = 0,
	ZIndex = 3,
})
corner(gameCard, 13)
stroke(gameCard, 3)
label(gameCard, "GameTitle", "BRITISH BULLDOG", UDim2.fromScale(0.05, 0.04), UDim2.fromScale(0.9, 0.13), headlineFont, ink, 30)
label(gameCard, "Status", "Waiting for server", UDim2.fromScale(0.05, 0.18), UDim2.fromScale(0.9, 0.10), bodyFont, ink, 16)
button(gameCard, "StartRound", "START ROUND", UDim2.fromScale(0.05, 0.325), UDim2.fromScale(0.90, 0.18), yellow, 26)
label(gameCard, "StartCaption", "All ready players", UDim2.fromScale(0.05, 0.51), UDim2.fromScale(0.9, 0.065), bodyFont, ink, 14)
button(gameCard, "PracticeRunner", "PLAY AS RUNNER", UDim2.fromScale(0.05, 0.61), UDim2.fromScale(0.90, 0.16), blue, 23)
button(gameCard, "PracticeBulldog", "PLAY AS BULLDOG", UDim2.fromScale(0.05, 0.81), UDim2.fromScale(0.90, 0.16), red, 23)

button(content, "StopRound", "STOP / BACK TO LOBBY", UDim2.fromScale(0, 0.745), UDim2.fromScale(1, 0.12), red, 23)
local message = label(content, "Message", "Choose a mode to play.", UDim2.fromScale(0.01, 0.90), UDim2.fromScale(0.98, 0.09), bodyFont, ink, 16)
message.TextYAlignment = Enum.TextYAlignment.Top

return {
	GUI = gui:GetFullName(),
	Descendants = #gui:GetDescendants(),
	Enabled = gui.Enabled,
	RuntimeScriptInstalled = false,
}
