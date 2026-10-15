local ink = Color3.fromRGB(24, 30, 51)
local cream = Color3.fromRGB(255, 249, 229)
local skins = {
	Panel = "rbxassetid://117403446558356",
	Blue = "rbxassetid://90528629970043",
	Gold = "rbxassetid://84589903135132",
	Green = "rbxassetid://78972575698291",
	Red = "rbxassetid://96220174131051",
	Disabled = "rbxassetid://101720017581430",
}

local function label(parent, name, text, position, size, maximum, minimum)
	local object = Instance.new("TextLabel")
	object.Name = name
	object.BackgroundTransparency = 1
	object.BorderSizePixel = 0
	object.Position = position
	object.Size = size
	object.Text = text
	object.Font = Enum.Font.FredokaOne
	object.TextColor3 = cream
	object.TextScaled = true
	object.TextWrapped = true
	object.TextStrokeTransparency = 1
	object.ZIndex = parent.ZIndex + 2
	object.Parent = parent
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = minimum or 10
	limit.MaxTextSize = maximum or 18
	limit.Parent = object
	local stroke = Instance.new("UIStroke")
	stroke.Name = "TextOutline"
	stroke.Color = ink
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	stroke.BorderStrokePosition = Enum.BorderStrokePosition.Outer
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Thickness = 0.085
	stroke.Parent = object
	return object
end

local function skin(parent, image)
	local object = Instance.new("ImageLabel")
	object.Name = "ReusableSkin"
	object.BackgroundTransparency = 1
	object.Size = UDim2.fromScale(1, 1)
	object.Image = image
	object.ScaleType = Enum.ScaleType.Slice
	object.SliceCenter = Rect.new(88, 88, 424, 232)
	object.SliceScale = 0.25
	object.ZIndex = parent.ZIndex
	object.Parent = parent
	return object
end

local function button(parent, name, text, position, size, image)
	local object = Instance.new("TextButton")
	object.Name = name
	object.Position = position
	object.Size = size
	object.BackgroundTransparency = 1
	object.Text = ""
	object.AutoButtonColor = false
	object.ZIndex = parent:IsA("GuiObject") and parent.ZIndex + 1 or 2
	object:SetAttribute("NormalImage", image)
	object:SetAttribute("SelectedImage", skins.Green)
	object:SetAttribute("DisabledImage", skins.Disabled)
	object.Parent = parent
	skin(object, image)
	label(object, "Label", text, UDim2.fromOffset(8, 6), UDim2.new(1, -16, 1, -14), 18, 10)
	return object
end

local gui = Instance.new("ScreenGui")
gui.Name = "PlaygroundSessionControls"
gui.ResetOnSpawn = false
gui.DisplayOrder = 32
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui:SetAttribute("AuthoredUIVersion", 1)
gui:SetAttribute("Spectating", false)
gui:SetAttribute("SpectatingUserId", 0)
gui:SetAttribute("SessionMenuOpen", false)
local backdrop = Instance.new("TextButton")
backdrop.Name = "MenuBackdrop"
backdrop.BackgroundTransparency = 0.7
backdrop.BackgroundColor3 = ink
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.Text = ""
backdrop.AutoButtonColor = false
backdrop.Selectable = false
backdrop.ZIndex = 1
backdrop.Visible = false
backdrop.Parent = gui
local toggle = button(gui, "Toggle", "•••", UDim2.fromOffset(126, 8), UDim2.fromOffset(44, 44), skins.Blue)
toggle.ZIndex = 5
toggle.ReusableSkin.ZIndex = 5
toggle.Label.ZIndex = 7
toggle.Label:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize = 24
local dock = Instance.new("Frame")
dock.Name = "Dock"
dock.BackgroundTransparency = 1
dock.AnchorPoint = Vector2.new(0.5, 0)
dock.Position = UDim2.new(0.5, 0, 0, 76)
dock.Size = UDim2.fromOffset(232, 104)
dock.ZIndex = 2
dock.Visible = false
dock.Parent = gui
local afk = button(dock, "AFK", "AFK: OFF", UDim2.fromOffset(0, 0), UDim2.fromOffset(112, 48), skins.Gold)
local spectate = button(dock, "Spectate", "SPECTATE", UDim2.fromOffset(120, 0), UDim2.fromOffset(112, 48), skins.Blue)
afk.NextSelectionRight = spectate
spectate.NextSelectionLeft = afk
label(dock, "Notice", "", UDim2.fromOffset(0, 50), UDim2.fromOffset(232, 32), 12, 10)
local hint = label(dock, "Hint", "D-PAD UP: CONTROLS", UDim2.fromOffset(0, 86), UDim2.fromOffset(232, 16), 10, 9)
hint.Visible = false
local panel = Instance.new("Frame")
panel.Name = "SpectatePanel"
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -80)
panel.Size = UDim2.fromOffset(304, 146)
panel.BackgroundTransparency = 1
panel.ZIndex = 3
panel.Visible = false
panel.Parent = gui
skin(panel, skins.Panel)
label(panel, "Title", "SPECTATING", UDim2.fromOffset(58, 8), UDim2.fromOffset(188, 16), 13, 10)
label(panel, "PlayerName", "PLAYER", UDim2.fromOffset(56, 26), UDim2.fromOffset(192, 23), 18, 10)
label(panel, "Username", "@Username", UDim2.fromOffset(56, 50), UDim2.fromOffset(192, 16), 12, 10)
label(panel, "Counter", "1 / 1", UDim2.fromOffset(12, 8), UDim2.fromOffset(40, 16), 12, 10)
local previous = button(panel, "Previous", "<", UDim2.fromOffset(8, 24), UDim2.fromOffset(44, 48), skins.Blue)
local nextButton = button(panel, "Next", ">", UDim2.fromOffset(252, 24), UDim2.fromOffset(44, 48), skins.Blue)
local exit = button(panel, "Exit", "BACK TO LOBBY", UDim2.fromOffset(72, 72), UDim2.fromOffset(160, 44), skins.Red)
previous.NextSelectionRight = exit
exit.NextSelectionLeft = previous
exit.NextSelectionRight = nextButton
nextButton.NextSelectionLeft = exit
label(panel, "Controls", "ARROWS: PLAYER   BACKSPACE: EXIT", UDim2.fromOffset(10, 118), UDim2.fromOffset(284, 12), 10, 9)
label(panel, "JoinStatus", "YOU WILL JOIN THE NEXT ROUND", UDim2.fromOffset(10, 130), UDim2.fromOffset(284, 12), 10, 9)
return gui
