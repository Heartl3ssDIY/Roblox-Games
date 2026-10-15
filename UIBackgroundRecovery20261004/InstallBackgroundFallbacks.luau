return function(controllerSource, dryRun)
	assert(not game:GetService("RunService"):IsRunning(), "Apply background recovery in Edit mode only")
	assert(type(controllerSource) == "string" and #controllerSource > 100, "Provide the background fallback controller source")
	local starterGui = game:GetService("StarterGui")
	local palette = {
		blue = Color3.fromRGB(42, 160, 235), gold = Color3.fromRGB(255, 205, 57),
		cream = Color3.fromRGB(255, 249, 224), green = Color3.fromRGB(94, 203, 162),
		red = Color3.fromRGB(255, 105, 120), pink = Color3.fromRGB(255, 153, 166),
		silver = Color3.fromRGB(176, 188, 206), black = Color3.fromRGB(61, 69, 86),
		orange = Color3.fromRGB(255, 153, 66), mud = Color3.fromRGB(168, 108, 59),
		purple = Color3.fromRGB(175, 124, 229),
	}
	local imagePalette = {
		["90528629970043"] = "blue", ["84589903135132"] = "gold",
		["80217215544210"] = "cream", ["117403446558356"] = "cream",
		["78972575698291"] = "green", ["96220174131051"] = "red",
		["91168456076260"] = "silver", ["137398265947826"] = "black",
		["70427716988197"] = "orange", ["98268172973975"] = "mud",
		["109174047078490"] = "purple",
	}
	local boards = { LeaderboardBoardArtwork = "cream", LeaderboardHeaderArtwork = "blue", LeaderboardRowArtwork = "cream" }
	local excluded = { Fill = true, Track = true, XPTrack = true, Icon = true, Coin = true, Avatar = true, SelectionMark = true, Progress = true }
	local function eligible(skin)
		if not skin:IsA("ImageLabel") then return false end
		if skin.Name ~= "ReusableSkin" and not boards[skin.Name] then return false end
		if excluded[skin.Parent.Name] then return false end
		local ancestor = skin.Parent
		while ancestor and ancestor ~= game do
			if ancestor.Name == "CoinPickupPopup" or ancestor.Name == "AssetLibrary" then return false end
			ancestor = ancestor.Parent
		end
		local key = string.lower(skin:GetAttribute("AssetKey") or skin:GetAttribute("UISkinAssetKey") or "")
		if string.find(key, "04%-meter%-parts") or string.find(key, "avatar") or string.find(key, "selection") or string.find(key, "icon") then return false end
		return true
	end
	local function colorFor(skin)
		if boards[skin.Name] then return palette[boards[skin.Name]] end
		local id = string.match(skin.Image, "^rbxassetid://(%d+)") or string.match(skin.Image, "[?&]id=(%d+)")
		if id and imagePalette[id] then return palette[imagePalette[id]] end
		local key = string.lower(skin:GetAttribute("AssetKey") or skin:GetAttribute("UISkinAssetKey") or "")
		if string.find(key, "heat") then return palette.orange end
		if string.find(key, "mud%-slot") then return palette.mud end
		if string.find(key, "sprint") then return palette.blue end
		if string.find(key, "dodge") or string.find(key, "splat") then return palette.gold end
		if string.find(key, "close") then return palette.silver end
		for name, color in pairs(palette) do if string.find(key, name, 1, true) then return color end end
		if skin.Parent:IsA("GuiObject") then
			local color = skin.Parent.BackgroundColor3
			if color.R > 0.94 and color.G > 0.94 and color.B > 0.85 then return palette.cream end
			return color
		end
		return palette.cream
	end
	local targets, screens = {}, {}
	for _, name in ipairs({ "BritishBulldogHUD", "TagHUD", "MudHUD", "PlaygroundShell", "PlaygroundAdminPanel", "PlaygroundLeaderboards" }) do
		local screen = starterGui:FindFirstChild(name)
		if screen and screen:IsA("ScreenGui") then
			table.insert(screens, screen)
			for _, object in ipairs(screen:GetDescendants()) do if eligible(object) then table.insert(targets, object) end end
		end
	end
	local lobby = workspace:FindFirstChild("Playground Lobby")
	local leaderboards = lobby and lobby:FindFirstChild("Leaderboards")
	if leaderboards then
		for _, object in ipairs(leaderboards:GetDescendants()) do
			if object:FindFirstAncestorWhichIsA("SurfaceGui") and eligible(object) then table.insert(targets, object) end
		end
	end
	local report = { dryRun = dryRun == true, count = #targets, controllers = {}, targets = {} }
	for _, skin in ipairs(targets) do table.insert(report.targets, skin:GetFullName()) end
	if dryRun then return report end
	local template = assert(starterGui.PlaygroundShell:FindFirstChild("ReusableSkinController"), "Existing controller capability template missing")
	assert(template:IsA("LocalScript"), "Capability template must be LocalScript")
	local function corner(parent, radius)
		local value = Instance.new("UICorner")
		value.Name = "Corner"
		value.CornerRadius = radius
		value.Parent = parent
	end
	local function frame(name, color, z, parent)
		local value = Instance.new("Frame")
		value.Name = name
		value.BorderSizePixel = 0
		value.BackgroundColor3 = color
		value.Active = false
		value.Selectable = false
		value.ZIndex = z
		value.Parent = parent
		return value
	end
	for _, skin in ipairs(targets) do
		local name = skin.Name .. "Fallback"
		local previous = skin.Parent:FindFirstChild(name)
		if previous then
			assert(previous:GetAttribute("BackgroundFallbackFor") == skin.Name, "Unmanaged name collision: " .. previous:GetFullName())
			previous:Destroy()
		end
		local color = colorFor(skin)
		local ink = Color3.fromRGB(31, 38, 60)
		local z = math.max(0, skin.ZIndex - 1)
		local fallback = frame(name, ink, z, nil)
		fallback:SetAttribute("BackgroundFallbackFor", skin.Name)
		fallback:SetAttribute("BackgroundFallbackVersion", 1)
		fallback:SetAttribute("FallbackFaceColor", color)
		fallback:SetAttribute("FallbackInkColor", ink)
		fallback.Position = skin.Position
		fallback.Size = skin.Size
		fallback.AnchorPoint = skin.AnchorPoint
		fallback.Rotation = skin.Rotation
		fallback.LayoutOrder = skin.LayoutOrder
		fallback.ClipsDescendants = true
		fallback.Visible = skin.Visible and skin.Image ~= "" and not skin.IsLoaded and skin.ImageTransparency < 1
		local sourceCorner = skin:FindFirstChildWhichIsA("UICorner") or skin.Parent:FindFirstChildWhichIsA("UICorner")
		local radius = sourceCorner and sourceCorner.CornerRadius or UDim.new(0, 12)
		corner(fallback, radius)
		local edge = frame("Edge", color:Lerp(Color3.new(1, 1, 1), 0.72), z, fallback)
		edge.Position = UDim2.fromOffset(2, 2)
		edge.Size = UDim2.new(1, -4, 1, -4)
		corner(edge, UDim.new(radius.Scale, math.max(0, radius.Offset - 2)))
		local face = frame("Face", color, z, edge)
		face.Position = UDim2.fromOffset(2, 2)
		face.Size = UDim2.new(1, -4, 1, -6)
		corner(face, UDim.new(radius.Scale, math.max(0, radius.Offset - 4)))
		local gradient = Instance.new("UIGradient")
		gradient.Name = "FaceShade"
		gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.93, 0.93, 0.93))
		gradient.Rotation = 90
		gradient.Parent = face
		for _, value in ipairs({ fallback, edge, face }) do
			value.BackgroundTransparency = skin.ImageTransparency
			local c = value.BackgroundColor3
			value.BackgroundColor3 = Color3.new(c.R * skin.ImageColor3.R, c.G * skin.ImageColor3.G, c.B * skin.ImageColor3.B)
		end
		for _, object in ipairs(skin:GetChildren()) do
			if object:IsA("UISizeConstraint") or object:IsA("UIAspectRatioConstraint") or object:IsA("UIScale") then object:Clone().Parent = fallback end
		end
		fallback.Parent = skin.Parent
	end
	for _, screen in ipairs(screens) do
		local existing = screen:FindFirstChild("BackgroundFallbackController")
		if existing then
			assert(existing:IsA("LocalScript") and existing:GetAttribute("BackgroundFallbackVersion") == 1, "Unmanaged controller name collision")
			existing:Destroy()
		end
		local controller = (screen:FindFirstChild("ReusableSkinController") or template):Clone()
		controller.Name = "BackgroundFallbackController"
		controller.Source = controllerSource
		controller:SetAttribute("BackgroundFallbackVersion", 1)
		controller.Enabled = true
		controller.Parent = screen
		table.insert(report.controllers, { path = controller:GetFullName(), capabilities = tostring(controller.Capabilities), sandboxed = controller.Sandboxed })
	end
	return report
end
