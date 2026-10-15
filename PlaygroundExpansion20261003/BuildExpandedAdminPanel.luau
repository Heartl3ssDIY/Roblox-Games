local StarterGui = game:GetService("StarterGui")
local ServerStorage = game:GetService("ServerStorage")
local old = StarterGui:FindFirstChild("PlaygroundAdminPanel")
if old and old:GetAttribute("ExpansionVersion") == 1 then return { created = false, preserved = true } end
if old then
	local backups = ServerStorage:WaitForChild("PlaygroundBeforeExpansion20261003")
	if not backups:FindFirstChild("AdminPanelBeforeExpansion") then local backup = old:Clone() backup.Name = "AdminPanelBeforeExpansion" backup.Parent = backups end
	old:Destroy()
end
local ink = Color3.fromRGB(24, 35, 62)
local cream = Color3.fromRGB(255, 250, 226)
local yellow = Color3.fromRGB(255, 207, 59)
local blue = Color3.fromRGB(42, 160, 255)
local red = Color3.fromRGB(255, 81, 92)
local mint = Color3.fromRGB(101, 218, 177)
local headline = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local bodyFont = Font.new("rbxasset://fonts/families/FredokaOne.json")
local function make(class, name, parent, properties)
	local object = Instance.new(class)
	object.Name = name
	for key, value in pairs(properties or {}) do object[key] = value end
	object.Parent = parent
	return object
end
local function border(parent, thickness)
	make("UICorner", "Corner", parent, { CornerRadius = UDim.new(0, 14) })
	make("UIStroke", "Stroke", parent, { Color = ink, Thickness = thickness or 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end
local function label(parent, name, text, position, size, font, maximum)
	local object = make("TextLabel", name, parent, { Position = position, Size = size, BackgroundTransparency = 1, Text = text, TextColor3 = ink, FontFace = font or bodyFont, TextScaled = true, TextWrapped = true })
	make("UITextSizeConstraint", "TextLimit", object, { MinTextSize = 10, MaxTextSize = maximum or 24 })
	return object
end
local function button(parent, name, text, position, size, color, max)
	local object = make("TextButton", name, parent, { Position = position, Size = size, BackgroundColor3 = color, BorderSizePixel = 0, Text = text, FontFace = headline, TextColor3 = ink, TextScaled = true, TextWrapped = true, AutoButtonColor = true })
	object:SetAttribute("ReadyColor", color)
	border(object, 3)
	make("UITextSizeConstraint", "TextLimit", object, { MinTextSize = 11, MaxTextSize = max or 24 })
	return object
end
local gui = make("ScreenGui", "PlaygroundAdminPanel", StarterGui, { Enabled = false, ResetOnSpawn = false, DisplayOrder = 50, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
gui:SetAttribute("ExpansionVersion", 1)
button(gui, "Toggle", "ADMIN", UDim2.fromScale(0.012, 0.045), UDim2.fromOffset(112, 44), yellow)
local panel = make("Frame", "Panel", gui, { Position = UDim2.fromScale(0.012, 0.125), Size = UDim2.fromScale(0.29, 0.86), BackgroundColor3 = cream, BorderSizePixel = 0, Visible = false })
make("UISizeConstraint", "SizeLimit", panel, { MinSize = Vector2.new(300, 450), MaxSize = Vector2.new(390, 650) })
border(panel, 4)
label(panel, "Title", "PLAYGROUND ADMIN", UDim2.fromScale(0.04, 0.02), UDim2.fromScale(0.77, 0.075), headline, 28)
button(panel, "Close", "X", UDim2.fromScale(0.865, 0.025), UDim2.fromScale(0.09, 0.07), Color3.new(1, 1, 1), 24)
local scroll = make("ScrollingFrame", "Body", panel, { Position = UDim2.fromScale(0.045, 0.12), Size = UDim2.fromScale(0.91, 0.625), BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.fromOffset(0, 434), AutomaticCanvasSize = Enum.AutomaticSize.None, ScrollBarThickness = 4, ScrollingDirection = Enum.ScrollingDirection.Y, ClipsDescendants = true })
local content = make("Frame", "Content", scroll, { Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -14, 0, 426), BackgroundTransparency = 1 })
local function card(name, title, offset, start, first, second, firstText, secondText)
	local frame = make("Frame", name, content, { Position = UDim2.fromOffset(0, offset), Size = UDim2.new(1, 0, 0, 204), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 })
	border(frame)
	label(frame, "Title", title, UDim2.fromScale(0.04, 0.03), UDim2.fromScale(0.92, 0.17), headline, 29)
	label(frame, "Status", "Ready", UDim2.fromScale(0.04, 0.21), UDim2.fromScale(0.92, 0.12), bodyFont, 14)
	button(frame, start, "START ROUND", UDim2.fromScale(0.04, 0.35), UDim2.fromScale(0.92, 0.185), yellow, 23)
	button(frame, first, firstText, UDim2.fromScale(0.04, 0.565), UDim2.fromScale(0.92, 0.185), blue, 22)
	button(frame, second, secondText, UDim2.fromScale(0.04, 0.78), UDim2.fromScale(0.92, 0.185), red, 22)
end
card("BritishBulldog", "BRITISH BULLDOG", 0, "BBStart", "BBRunner", "BBBulldog", "SOLO RUNNER", "SOLO BULLDOG")
card("TagYoureIt", "TAG YOU'RE IT", 218, "TagStart", "TagRunner", "TagTagger", "SOLO RUNNER", "SOLO TAGGER")
button(panel, "StopRound", "STOP / BACK TO LOBBY", UDim2.fromScale(0.055, 0.78), UDim2.fromScale(0.89, 0.075), red, 22)
button(panel, "ToggleAutomatic", "AUTO ROUNDS: ON", UDim2.fromScale(0.055, 0.875), UDim2.fromScale(0.89, 0.06), mint, 19)
label(panel, "Message", "Choose a game to test.", UDim2.fromScale(0.05, 0.947), UDim2.fromScale(0.9, 0.042), bodyFont, 14)
return { created = true, panel = gui:GetFullName(), games = 2 }
