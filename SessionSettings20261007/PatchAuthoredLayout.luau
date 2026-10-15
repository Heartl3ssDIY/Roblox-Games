return function(gui)
	local dock = gui.Dock
	local afk = dock.AFK
	local settings = gui.Toggle
	local spectate = dock:FindFirstChild("Spectate") or gui.Spectate
	local ink = Color3.fromRGB(24, 30, 51)
	local function label(name, text, position, size, maximum)
		local object = dock.Notice:Clone()
		object.Name = name
		object.Text = text
		object.Position = position
		object.Size = size
		object.Visible = true
		local constraint = object:FindFirstChildOfClass("UITextSizeConstraint")
		constraint.MinTextSize = 10
		constraint.MaxTextSize = maximum
		object.Parent = dock
		return object
	end
	local function icon(button, image, text, position, anchor, width)
		button.BackgroundTransparency = 1
		button.Position = position
		button.AnchorPoint = anchor or Vector2.zero
		button.Size = UDim2.fromOffset(44, 44)
		button:SetAttribute("NormalImage", image)
		button:SetAttribute("SelectedImage", image)
		button:SetAttribute("DisabledImage", image)
		button:SetAttribute("IconButton", true)
		button.ReusableSkin.Image = image
		button.ReusableSkin.ScaleType = Enum.ScaleType.Fit
		button.ReusableSkin.Size = UDim2.fromScale(1, 1)
		button.ReusableSkin.Position = UDim2.fromOffset(0, 0)
		button.ReusableSkin.SliceCenter = Rect.new()
		button.Label.Position = UDim2.fromOffset((44 - width) / 2, 46)
		button.Label.Size = UDim2.fromOffset(width, 16)
		button.Label.Text = text
		button.Label.TextWrapped = false
		local limit = button.Label:FindFirstChildOfClass("UITextSizeConstraint")
		limit.MinTextSize = 9
		limit.MaxTextSize = 11
		button.Parent = gui
	end
	icon(settings, "rbxassetid://140169882716044", "SETTINGS", UDim2.new(0.45, -56, 0, 70), nil, 68)
	icon(spectate, "rbxassetid://93214358251373", "SPECTATE", UDim2.new(0.45, 12, 0, 70), nil, 76)
	settings.NextSelectionRight = spectate
	spectate.NextSelectionLeft = settings
	local roundSettings = settings:Clone()
	roundSettings.Name = "RoundToggle"
	roundSettings.Position = UDim2.new(1, -12, 0, 88)
	roundSettings.AnchorPoint = Vector2.new(1, 0)
	roundSettings.NextSelectionRight = nil
	roundSettings.Visible = false
	roundSettings.Parent = gui
	dock.Position = UDim2.fromScale(0.5, 0.5)
	dock.AnchorPoint = Vector2.new(0.5, 0.5)
	dock.Size = UDim2.fromOffset(292, 234)
	dock.BackgroundTransparency = 1
	dock.Visible = false
	local skin = Instance.new("ImageLabel")
	skin.Name = "ReusableSkin"
	skin.BackgroundTransparency = 1
	skin.Size = UDim2.fromScale(1, 1)
	skin.Image = "rbxassetid://117403446558356"
	skin.ScaleType = Enum.ScaleType.Slice
	skin.SliceCenter = Rect.new(88, 88, 424, 232)
	skin.SliceScale = 0.25
	skin.ZIndex = dock.ZIndex
	skin.Parent = dock
	label("Title", "SETTINGS", UDim2.fromOffset(22, 12), UDim2.fromOffset(204, 32), 24)
	afk.Position = UDim2.fromOffset(22, 56)
	afk.Size = UDim2.fromOffset(248, 46)
	afk.Label:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize = 20
	dock.Notice.Position = UDim2.fromOffset(22, 104)
	dock.Notice.Size = UDim2.fromOffset(248, 24)
	dock.Notice:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize = 12
	local visibility = afk:Clone()
	visibility.Name = "Visibility"
	visibility.Position = UDim2.fromOffset(22, 132)
	visibility.Size = UDim2.fromOffset(248, 46)
	visibility.Label.Text = "HIDE UI"
	visibility.Parent = dock
	local close = afk:Clone()
	close.Name = "Close"
	close.Position = UDim2.new(1, -52, 0, 8)
	close.Size = UDim2.fromOffset(44, 44)
	close.Label.Text = "X"
	close.Label:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize = 22
	close.Parent = dock
	afk.NextSelectionDown = visibility
	afk.NextSelectionRight = close
	visibility.NextSelectionUp = afk
	visibility.NextSelectionDown = close
	close.NextSelectionDown = afk
	close.NextSelectionLeft = afk
	label("VisibilityHelp", "Hide lobby panels; keep game controls.", UDim2.fromOffset(18, 184), UDim2.fromOffset(256, 26), 12)
	dock.Hint.Position = UDim2.fromOffset(12, 218)
	dock.Hint.Size = UDim2.fromOffset(268, 12)
	dock.Hint:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize = 9
	dock.Hint.Text = "D-PAD UP: SETTINGS  •  RIGHT: WATCH"
	gui:SetAttribute("UIHidden", false)
	gui:SetAttribute("SettingsUIVersion", 2)
	gui:SetAttribute("SettingsKeyboardHint", "DPadUp")
	gui:SetAttribute("SpectateGamepadHint", "DPadRight")
	return gui
end
