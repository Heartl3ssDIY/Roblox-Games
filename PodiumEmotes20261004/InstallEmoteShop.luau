return function(dryRun)
	assert(not game:GetService("RunService"):IsRunning(), "Install the Emotes tab in Edit mode only")
	local shell = game:GetService("StarterGui"):FindFirstChild("PlaygroundShell")
	local shop = assert(shell and shell:FindFirstChild("ShopPanel"), "ShopPanel is missing")
	local categories = assert(shop:FindFirstChild("Categories"), "Category templates are missing")
	local template = assert(categories:FindFirstChild("Pets"), "Existing category button template is missing")
	assert(template:IsA("TextButton") and template:FindFirstChild("LiveCaption") and template:FindFirstChild("ReusableSkin"), "Inspect the editable category template")
	local names = { "All", "Bats", "Pets", "Toys", "Emotes" }
	for _, name in ipairs({ "All", "Bats", "Pets", "Toys" }) do assert(categories:FindFirstChild(name), "Category is missing: " .. name) end
	local report = { dryRun = dryRun == true, categories = names, addedItems = 0, animationIdsAdded = 0, changedPrices = 0 }
	if dryRun then return report end
	local button = categories:FindFirstChild("Emotes")
	if not button then
		button = template:Clone()
		button.Name = "Emotes"
		button.Parent = categories
	end
	assert(button:IsA("TextButton"), "Emotes must be an editable TextButton")
	button.Text = "EMOTES"
	button.Visible = true
	button.Active = true
	button.Selectable = true
	button.BackgroundColor3 = Color3.fromRGB(255, 255, 248)
	button:SetAttribute("ShopCategory", "Emotes")
	local caption = button:FindFirstChild("LiveCaption")
	caption.Text = "EMOTES"
	caption.AnchorPoint = Vector2.new(0.5, 0.5)
	caption.Position = UDim2.fromScale(0.5, 0.5)
	caption.Size = UDim2.new(1, -12, 1, -6)
	caption.TextXAlignment = Enum.TextXAlignment.Center
	caption.TextYAlignment = Enum.TextYAlignment.Center
	caption.TextScaled = true
	local textLimit = caption:FindFirstChildWhichIsA("UITextSizeConstraint")
	if textLimit then textLimit.MaxTextSize = 19 end
	local skin = button.ReusableSkin
	skin:SetAttribute("UISkinTargetPath", button:GetFullName())
	skin:SetAttribute("DefaultImage", template.ReusableSkin:GetAttribute("DefaultImage"))
	skin.Image = template.ReusableSkin.Image
	skin.Visible = true
	skin.ImageTransparency = 0
	local fallback = button:FindFirstChild("ReusableSkinFallback")
	if fallback then fallback.Visible = not skin.IsLoaded end
	local mark = button:FindFirstChild("SelectionMark")
	if mark then mark.Visible = false end
	for index, name in ipairs(names) do
		local tab = categories:FindFirstChild(name)
		tab.LayoutOrder = index
		tab.Size = UDim2.new(0.2, -8, 0, 33)
	end
	local layout = assert(categories:FindFirstChildWhichIsA("UIListLayout"), "Category layout is missing")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	local empty = shop:FindFirstChild("EmoteEmptyState")
	if not empty then
		empty = Instance.new("Frame")
		empty.Name = "EmoteEmptyState"
		empty.Parent = shop
	end
	empty:SetAttribute("EmoteShopVersion", 1)
	empty.BackgroundTransparency = 1
	empty.BorderSizePixel = 0
	empty.Active = false
	empty.Selectable = false
	empty.AnchorPoint = shop.Cards.AnchorPoint
	empty.Position = shop.Cards.Position
	empty.Size = shop.Cards.Size
	empty.ZIndex = shop.Cards.ZIndex + 2
	empty.Visible = false
	local function label(name, text, position, size, maxTextSize)
		local value = empty:FindFirstChild(name)
		if not value then value = caption:Clone() value.Name = name value.Parent = empty end
		value.Text = text
		value.BackgroundTransparency = 1
		value.AnchorPoint = Vector2.new(0.5, 0.5)
		value.Position = position
		value.Size = size
		value.ZIndex = empty.ZIndex + 1
		value.TextColor3 = Color3.fromRGB(255, 249, 224)
		value.TextTransparency = 0
		value.TextStrokeTransparency = 1
		value.TextXAlignment = Enum.TextXAlignment.Center
		value.TextYAlignment = Enum.TextYAlignment.Center
		value.TextScaled = true
		value.TextWrapped = true
		local limit = value:FindFirstChildWhichIsA("UITextSizeConstraint")
		if not limit then limit = Instance.new("UITextSizeConstraint") limit.Parent = value end
		limit.MinTextSize = 12
		limit.MaxTextSize = maxTextSize
		local stroke = value:FindFirstChild("TextOutline") or value:FindFirstChildWhichIsA("UIStroke")
		if not stroke then stroke = Instance.new("UIStroke") stroke.Name = "TextOutline" stroke.Parent = value end
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
		stroke.Thickness = 0.07
		stroke.Color = Color3.fromRGB(24, 30, 51)
		stroke.LineJoinMode = Enum.LineJoinMode.Round
		stroke.Transparency = 0
		stroke.Enabled = true
		return value
	end
	label("Title", "EMOTES ARE ON THE WAY", UDim2.new(0.5, 0, 0.5, -38), UDim2.new(0.9, 0, 0, 52), 28)
	label("Message", "New emotes will appear here when they're ready.", UDim2.new(0.5, 0, 0.5, 30), UDim2.new(0.84, 0, 0, 62), 20)
	report.button = button:GetFullName()
	report.emptyState = empty:GetFullName()
	report.backgroundFallbackPreserved = fallback ~= nil
	report.emojiTabUnchanged = categories:FindFirstChild("Emojis") ~= nil
	return report
end
