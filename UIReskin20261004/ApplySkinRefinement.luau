return function(assets, changes)
	assert(not game:GetService("RunService"):IsRunning(), "Use Edit mode")
	local function resolve(path)
		local object = game
		for part in string.gmatch(path, "[^.]+") do object = object and object:FindFirstChild(part) end
		return assert(object, "Missing target: " .. path)
	end
	for _, mapping in ipairs(changes.mappings) do
		local target = resolve(mapping.path)
		assert(target:FindFirstChild("ReusableSkin"), "Missing skin: " .. mapping.path)
		assert(assets[mapping.asset], "Missing artwork: " .. mapping.asset)
	end
	for _, mapping in ipairs(changes.mappings) do
		local target = resolve(mapping.path)
		local image = target.ReusableSkin
		image.Image = assets[mapping.asset]
		image:SetAttribute("AssetKey", mapping.asset)
		image:SetAttribute("DefaultImage", image.Image)
		image.ScaleType = mapping.mode == "Slice" and Enum.ScaleType.Slice or Enum.ScaleType.Fit
		if mapping.sliceCenter then
			local rect = mapping.sliceCenter
			image.SliceCenter = Rect.new(rect[1], rect[2], rect[3], rect[4])
			image.SliceScale = mapping.sliceScale or 0.25
		end
		target:SetAttribute("UISkinDynamic", mapping.dynamic == true)
		target:SetAttribute("UISkinAssetKey", mapping.asset)
		local caption = target:FindFirstChild("Caption") or target:FindFirstChild("LiveCaption")
		if caption and caption:IsA("TextLabel") then
			local rect = mapping.textFaceRect
			caption.AnchorPoint = Vector2.zero
			caption.Position = UDim2.fromScale(rect[1], rect[2])
			caption.Size = UDim2.fromScale(rect[3], rect[4])
			local icon = target:FindFirstChild("Icon")
			if icon and icon:IsA("ImageLabel") and icon.Visible then
				icon.AnchorPoint = Vector2.new(0, 0.5)
				icon.Position = UDim2.fromScale(rect[1], rect[2] + rect[4] * 0.5)
				icon.Size = UDim2.fromScale(rect[3] * 0.17, rect[4] * 0.7)
				caption.Position = UDim2.fromScale(rect[1] + rect[3] * 0.22, rect[2])
				caption.Size = UDim2.fromScale(rect[3] * 0.78, rect[4])
			end
		end
	end
	game.StarterGui.PlaygroundShell.LevelPanel.XP.Text = "0 / 200 XP"
	game.StarterGui.PlaygroundShell.CompactLevelPanel.XP.Text = "0 / 200"
	local level = game.StarterGui.PlaygroundShell.LevelPanel
	level.LevelIcon.Position = UDim2.fromOffset(88, 10)
	level.Level.Position = UDim2.fromOffset(113, 8)
	level.Level.Size = UDim2.fromOffset(139, 26)
	level.XP.Position = UDim2.fromOffset(90, 36)
	level.XP.Size = UDim2.fromOffset(163, 17)
	level.XPTrack.Position = UDim2.fromOffset(90, 59)
	level.XPTrack.Size = UDim2.fromOffset(161, 10)
	return { refined = #changes.mappings }
end
