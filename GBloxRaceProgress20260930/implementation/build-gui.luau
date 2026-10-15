local function create(className, name, parent, properties)
	local object = Instance.new(className)
	object.Name = name
	for key, value in properties or {} do object[key] = value end
	object.Parent = parent
	return object
end

return function(assets)
	local gui = create("ScreenGui", "GBloxRaceProgress", nil, {
		DisplayOrder = 30, ResetOnSpawn = false, Enabled = true,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		SafeAreaCompatibility = Enum.SafeAreaCompatibility.None,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	gui:SetAttribute("RaceProgressVersion", 1)
	local artwork = create("Folder", "Artwork", gui)
	for key, asset in assets do create("StringValue", key, artwork, {Value = asset}) end
	local function frame(name, parent, props)
		local object = create("Frame", name, parent, {BackgroundTransparency = 1, BorderSizePixel = 0})
		for key, value in props or {} do object[key] = value end
		return object
	end
	local function image(name, parent, asset, position, size, anchor, z)
		return create("ImageLabel", name, parent, {
			BackgroundTransparency = 1, BorderSizePixel = 0, Image = assets[asset] or "",
			Position = position, Size = size, AnchorPoint = anchor or Vector2.zero,
			ZIndex = z or 1, ScaleType = Enum.ScaleType.Stretch,
		})
	end
	local hud = frame("HUD", gui, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.new(0.76, 0, 0, 82), Visible = false,
	})
	create("UISizeConstraint", "ResponsiveWidth", hud, {MinSize = Vector2.new(260, 82), MaxSize = Vector2.new(900, 82)})
	local track = frame("Track", hud, {Position = UDim2.new(0, 36, 0, 38), Size = UDim2.new(1, -72, 0, 16)})
	image("TrackArtwork", track, "track", UDim2.fromScale(0,0), UDim2.fromScale(1,1))
	local interior = frame("ProgressInterior", track, {Position = UDim2.fromOffset(4,3), Size = UDim2.new(1,-8,1,-6), ZIndex = 2})
	image("Fill", interior, "fill", UDim2.fromScale(0,0), UDim2.fromScale(0,1))
	image("StartLabel", track, "start", UDim2.new(0,0,1,8), UDim2.fromOffset(55,12), Vector2.new(0.5,0),3)
	image("FinishLabel", track, "finish", UDim2.new(1,0,1,8), UDim2.fromOffset(65,12), Vector2.new(0.5,0),3)
	image("FinishFlag", track, "flag", UDim2.new(1,8,0.5,0), UDim2.fromOffset(18,22), Vector2.new(0,0.5),3)
	frame("Markers", track, {Size = UDim2.fromScale(1,1), ZIndex = 10})
	local templates = create("Folder", "Templates", gui)
	local marker = frame("PlayerMarker", templates, {
		AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.fromScale(0,0.5),
		Size = UDim2.fromOffset(46,46), Visible = false, ZIndex = 20,
	})
	image("Ring", marker, "other-ring", UDim2.fromScale(0,0), UDim2.fromScale(1,1),nil,1)
	create("ViewportFrame", "Portrait", marker, {
		Position = UDim2.fromScale(0.5,0.48), AnchorPoint = Vector2.new(0.5,0.5), Size = UDim2.fromScale(0.68,0.68),
		BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2, Visible = false,
		Ambient = Color3.fromRGB(200,220,235), LightColor = Color3.fromRGB(245,250,255), LightDirection = Vector3.new(-1,-1,-2),
	})
	local thumb = image("Thumbnail", marker, "", UDim2.fromScale(0.5,0.48), UDim2.fromScale(0.68,0.68), Vector2.new(0.5,0.5),2)
	create("UICorner", "Circle", thumb, {CornerRadius = UDim.new(1,0)})
	local badge = image("Badge", marker, "other-badge", UDim2.fromScale(0.85,0.85), UDim2.fromOffset(18,18), Vector2.new(0.5,0.5),4)
	create("TextLabel", "Number", badge, {
		Size = UDim2.fromScale(1,1), BackgroundTransparency = 1, Text = "", TextSize = 18,
		TextColor3 = Color3.fromRGB(6,24,34), Font = Enum.Font.Arcade, ZIndex = 5,
	})
	local you = image("YouLabel", marker, "you-label", UDim2.new(0.5,0,0,-17), UDim2.fromOffset(42,16), Vector2.new(0.5,0),4)
	you.Visible = false
	local finished = image("Finished", marker, "flag", UDim2.new(1,-2,0,-5), UDim2.fromOffset(13,16), nil,4)
	finished.Visible = false
	create("TextLabel", "OutLabel", marker, {
		Position = UDim2.new(0.5,0,1,3), AnchorPoint = Vector2.new(0.5,0), Size = UDim2.fromOffset(36,14),
		BackgroundColor3 = Color3.fromRGB(6,24,34), BackgroundTransparency = 0.12, BorderSizePixel = 0,
		Text = "OUT", TextColor3 = Color3.fromRGB(185,207,216), Font = Enum.Font.Arcade,
		TextSize = 10, Visible = false, ZIndex = 4,
	})
	return gui
end
