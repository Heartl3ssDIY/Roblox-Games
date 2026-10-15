local function install(starterGui)
	local shell = assert(starterGui:FindFirstChild("PlaygroundShell"), "PlaygroundShell missing")
	local hotbar = assert(starterGui:FindFirstChild("PlaygroundToyHotbar"), "PlaygroundToyHotbar missing")
	local cards = shell.ShopPanel.Cards
	local templates = shell:FindFirstChild("Templates")
	local targets = {}
	for _, child in ipairs(cards:GetChildren()) do
		if child:IsA("Frame") and child:FindFirstChild("Preview") and child:FindFirstChild("Action") then table.insert(targets, child) end
	end
	local template = templates and templates:FindFirstChild("ItemCard")
	if template then table.insert(targets, template) end
	for index = 1, 4 do table.insert(targets, assert(hotbar.Bar.Slots:FindFirstChild("Slot" .. tostring(index)))) end
	local created = 0
	for _, host in ipairs(targets) do
		local preview = assert(host:FindFirstChild("Preview"), "Preview missing")
		local thumbnail = host:FindFirstChild("Thumbnail")
		if not thumbnail then
			thumbnail = Instance.new("ImageLabel")
			thumbnail.Name = "Thumbnail"
			thumbnail.AnchorPoint = preview.AnchorPoint
			thumbnail.Position = preview.Position
			thumbnail.Size = preview.Size
			thumbnail.Rotation = preview.Rotation
			thumbnail.ZIndex = preview.ZIndex
			thumbnail.LayoutOrder = preview.LayoutOrder
			thumbnail.BackgroundTransparency = 1
			thumbnail.BorderSizePixel = 0
			thumbnail.ScaleType = Enum.ScaleType.Fit
			thumbnail.ImageColor3 = Color3.new(1, 1, 1)
			thumbnail.Visible = false
			thumbnail:SetAttribute("Purpose", "Original supplied item PNG; image bound from catalog.thumbnail")
			thumbnail.Parent = host
			created += 1
		end
		assert(thumbnail:IsA("ImageLabel"), "Thumbnail must be an editable ImageLabel")
		preview.Visible = false
	end
	return { created = created, targets = #targets }
end
return install

