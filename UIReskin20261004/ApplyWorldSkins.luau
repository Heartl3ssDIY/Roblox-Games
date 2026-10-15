local function collectTargets()
	local targets = {}
	local function add(instance, kind, palette)
		if instance then table.insert(targets, {instance = instance, kind = kind, palette = palette}) end
	end
	for _,mapName in {"British Bulldog game", "Tag You're It"} do
		local map = workspace:FindFirstChild(mapName)
		local scenery = map and map:FindFirstChild("SchoolScenery")
		if scenery then
			for _,gui in scenery:GetDescendants() do
				if gui:IsA("SurfaceGui") and gui.Name == "ClassDetail" and gui.Parent:IsA("BasePart") then
					local host = gui.Parent.Name
					if host == "HopscotchSquare" then add(gui, "hopscotch")
					elseif host == "RoomPlaque" or host == "PinnedClassPaper" then add(gui, "school", "cream") end
				end
			end
		end
		local walls = map and map:FindFirstChild("ArenaWalls")
		if mapName == "British Bulldog game" and walls then
			for _,gui in walls:GetDescendants() do
				if gui:IsA("SurfaceGui") and gui.Name == "TitleArtwork" and gui.Parent.Name == "TitleCreamPanel" then add(gui, "title", "gold") end
			end
		end
	end
	local lobby = workspace:FindFirstChild("Playground Lobby")
	local voting = lobby and lobby:FindFirstChild("VotingAlcove")
	if voting then
		for standName, palette in {BritishBulldogStand = "blue", TagYoureItStand = "red", StuckInTheMudStand = "green"} do
			local stand = voting:FindFirstChild(standName)
			local face = stand and stand:FindFirstChild("ChoiceCardFace")
			local gui = face and face:FindFirstChild("GameName")
			if gui and gui:IsA("SurfaceGui") then add(gui, "vote", palette) end
		end
	end
	for _,spec in {{"BritishBulldogAssets", "TaggedTemplate", "gold"}, {"TagAssets", "TaggerTemplate", "red"}, {"MudAssets", "MuddyTemplate", "mud"}} do
		local assets = game:GetService("ReplicatedStorage"):FindFirstChild(spec[1])
		local gui = assets and assets:FindFirstChild(spec[2])
		if gui and gui:IsA("BillboardGui") then add(gui, "overhead", spec[3]) end
	end
	return targets
end

local function styleText(label)
	for _,child in label:GetChildren() do
		if child:IsA("UIStroke") then child.Enabled = false end
	end
	local outline = label:FindFirstChild("TextOutline")
	if not outline then outline = Instance.new("UIStroke") outline.Name = "TextOutline" outline.Parent = label end
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	outline.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	outline.Thickness = 0.085
	outline.Color = Color3.fromRGB(24, 30, 51)
	outline.LineJoinMode = Enum.LineJoinMode.Round
	outline.Transparency = 0
	outline.Enabled = true
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 249, 224)
	label.TextTransparency = 0
	label.TextStrokeTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = math.max(4, label.ZIndex)
end

local function nearestBackplate(colour)
	local best, distance = "gold", math.huge
	for name, reference in {red = Color3.fromRGB(255, 127, 121), gold = Color3.fromRGB(255, 203, 68), green = Color3.fromRGB(92, 209, 166)} do
		local delta = (colour.R - reference.R)^2 + (colour.G - reference.G)^2 + (colour.B - reference.B)^2
		if delta < distance then best, distance = name, delta end
	end
	return best
end

return function(assets)
	assert(not game:GetService("RunService"):IsRunning(), "Apply world skins in Edit mode only")
	local targets = collectTargets()
	assert(#targets == 30, "Expected 27 world SurfaceGuis and 3 overhead templates; inspect scope before applying")
	for _,target in targets do
		if target.kind == "hopscotch" then
			target.asset = "Attachments/backplate-" .. nearestBackplate(target.instance.Parent.Color) .. ".png"
		else
			target.asset = "PNG/07-Resizable-Skins/" .. target.palette .. "-normal.png"
		end
		assert(assets[target.asset], "Missing uploaded image: " .. target.asset)
		if target.kind == "overhead" then
			target.host = target.instance:FindFirstChild("Panel") or target.instance:FindFirstChild("Card")
			assert(target.host and target.host:IsA("Frame"), "Missing overhead panel: " .. target.instance:GetFullName())
		else target.host = target.instance end
	end
	local report = {surfaceGuis = 0, overheadTemplates = 0, labels = 0, instances = {}}
	for _,target in targets do
		local gui, host = target.instance, target.host
		local previous = host:FindFirstChild("ReusableSkin")
		if previous then previous:Destroy() end
		if host:IsA("GuiObject") then
			host.BackgroundTransparency = 1
			host.BorderSizePixel = 0
			for _,child in host:GetChildren() do
				if child:IsA("UIStroke") then child.Transparency = 1 end
			end
		end
		local skin = Instance.new("ImageLabel")
		skin.Name = "ReusableSkin"
		skin.BackgroundTransparency = 1
		skin.BorderSizePixel = 0
		skin.Size = UDim2.fromScale(1, 1)
		skin.Position = UDim2.fromScale(0, 0)
		skin.Image = assets[target.asset]
		skin.ImageColor3 = Color3.new(1, 1, 1)
		skin.Active = false
		skin.Selectable = false
		skin.ZIndex = 2
		skin:SetAttribute("UISkinAssetPath", target.asset)
		if target.kind == "hopscotch" then
			skin.ScaleType = Enum.ScaleType.Fit
		else
			skin.ScaleType = Enum.ScaleType.Slice
			skin.SliceCenter = Rect.new(88, 88, 424, 232)
			skin.SliceScale = 0.25
		end
		skin.Parent = host
		for _,label in gui:GetDescendants() do
			if label:IsA("TextLabel") or label:IsA("TextButton") then styleText(label) report.labels += 1 end
		end
		gui:SetAttribute("ReusableSkinRevision", "20261004")
		if target.kind == "overhead" then report.overheadTemplates += 1 else report.surfaceGuis += 1 end
		table.insert(report.instances, {path = gui:GetFullName(), kind = target.kind, asset = target.asset})
	end
	return report
end