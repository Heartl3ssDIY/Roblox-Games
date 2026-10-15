return function(dryRun, shellOverride)
	assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
	local shell = shellOverride or game:GetService("StarterGui"):WaitForChild("PlaygroundShell")
	local dock = shell:WaitForChild("Dock")
	local shop = dock:WaitForChild("Shop")
	local pets = dock:WaitForChild("Emote")
	local toys = dock:WaitForChild("Emoji")
	assert(shop:IsA("TextButton") and pets:IsA("TextButton") and toys:IsA("TextButton"), "Dock buttons are required")
	assert(shop:FindFirstChild("ReusableSkin") and shop:FindFirstChild("ReusableSkinFallback") and shop:FindFirstChild("LiveCaption"), "Shop style template is incomplete")
	local report = {
		dryRun = dryRun == true,
		changed = { "Dock", "Dock.Shop", "Dock.Emote", "Dock.Emoji" },
		shopPanelChanged = false,
		controllerChanged = false,
		desktopButtonSize = "118 x 46",
		mobileButtonWidthAt320 = (320 - 36 - 28) / 3,
	}
	if dryRun then return report end
	if not shellOverride then
		local storage = game:GetService("ServerStorage")
		local backup = storage:FindFirstChild("UIShellPolishBackup20261004")
		if not backup then
			backup = Instance.new("Folder")
			backup.Name = "UIShellPolishBackup20261004"
			backup.Parent = storage
		end
		if not backup:FindFirstChild("Dock") then dock:Clone().Parent = backup end
		report.backup = backup:GetFullName() .. ".Dock"
	end
	local template = shop:Clone()
	template.Parent = nil
	local specifications = {
		{ button = shop, label = "SHOP", image = "rbxassetid://84589903135132", key = "PNG/07-Resizable-Skins/gold-normal.png", face = Color3.fromRGB(255, 205, 57) },
		{ button = pets, label = "PETS", image = "rbxassetid://90528629970043", key = "PNG/07-Resizable-Skins/blue-normal.png", face = Color3.fromRGB(42, 160, 235) },
		{ button = toys, label = "TOYS", image = "rbxassetid://91168456076260", key = "PNG/07-Resizable-Skins/silver-normal.png", face = Color3.fromRGB(176, 188, 206) },
	}
	dock.Size = UDim2.new(1, -36, 0, 48)
	dock.ClipsDescendants = false
	local sizeLimit = dock:FindFirstChild("DockSizeLimit")
	if not sizeLimit then
		sizeLimit = Instance.new("UISizeConstraint")
		sizeLimit.Name = "DockSizeLimit"
		sizeLimit.Parent = dock
	end
	sizeLimit.MinSize = Vector2.new(0, 48)
	sizeLimit.MaxSize = Vector2.new(382, 48)
	local layout = dock:FindFirstChild("DockLayout")
	if not layout then
		layout = Instance.new("UIListLayout")
		layout.Name = "DockLayout"
		layout.Parent = dock
	end
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 14)
	for index, spec in ipairs(specifications) do
		local button = spec.button
		if button ~= shop then
			for _, child in ipairs(button:GetChildren()) do child:Destroy() end
			for _, child in ipairs(template:GetChildren()) do child:Clone().Parent = button end
		end
		button.Size = UDim2.new(1 / 3, -28 / 3, 0, 46)
		button.AnchorPoint = Vector2.zero
		button.Position = UDim2.fromOffset((index - 1) * 132, 0)
		button.LayoutOrder = index
		button.Text = spec.label
		button.TextTransparency = 1
		button.BackgroundTransparency = 1
		button.BackgroundColor3 = spec.face
		button.TextXAlignment = Enum.TextXAlignment.Center
		button.TextYAlignment = Enum.TextYAlignment.Center
		button:SetAttribute("UISkinAssetKey", spec.key)
		button:SetAttribute("UISkinHiddenText", true)
		button:SetAttribute("UISkinManaged", true)
		button:SetAttribute("UISkinDynamic", false)
		button:SetAttribute("UISkinSelectionFromColour", false)
		button:SetAttribute("UISkinSelectionFromOutline", false)
		local skin = button.ReusableSkin
		skin.Position = UDim2.fromScale(0, 0)
		skin.Size = UDim2.fromScale(1, 1)
		skin.AnchorPoint = Vector2.zero
		skin.Image = spec.image
		skin.ImageColor3 = Color3.new(1, 1, 1)
		skin.ImageTransparency = 0
		skin.Visible = true
		skin:SetAttribute("DefaultImage", spec.image)
		skin:SetAttribute("AssetKey", spec.key)
		skin:SetAttribute("UISkinTargetPath", "StarterGui.PlaygroundShell.Dock." .. button.Name)
		local caption = button.LiveCaption
		caption.Text = spec.label
		caption.AnchorPoint = Vector2.new(0.5, 0.5)
		caption.Position = UDim2.fromScale(0.5, 0.5)
		caption.Size = UDim2.fromScale(0.8, 0.6)
		caption.TextXAlignment = Enum.TextXAlignment.Center
		caption.TextYAlignment = Enum.TextYAlignment.Center
		caption.TextTransparency = 0
		caption.Visible = true
		local textOutline = caption:FindFirstChildOfClass("UIStroke")
		assert(textOutline, "Shop caption outline is required")
		textOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		local fallback = button.ReusableSkinFallback
		fallback.Position = skin.Position
		fallback.Size = skin.Size
		fallback.AnchorPoint = skin.AnchorPoint
		fallback.Visible = not skin.IsLoaded
		fallback:SetAttribute("FallbackFaceColor", spec.face)
		fallback.Edge.BackgroundColor3 = spec.face:Lerp(Color3.new(1, 1, 1), 0.72)
		fallback.Edge.Face.BackgroundColor3 = spec.face
	end
	template:Destroy()
	dock:SetAttribute("DockPolishVersion", 1)
	return report
end

