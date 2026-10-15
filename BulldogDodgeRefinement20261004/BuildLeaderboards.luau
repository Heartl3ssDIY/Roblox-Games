return function(parent, baseCFrame)
	assert(typeof(parent) == "Instance" and typeof(baseCFrame) == "CFrame", "Provide a lobby parent and floor CFrame")
	local existing = parent:FindFirstChild("Leaderboards")
	if existing then
		assert(existing:GetAttribute("PlaygroundLeaderboardVersion") == 1, "An unrelated Leaderboards object already exists")
		return existing
	end
	local ink = Color3.fromRGB(27, 42, 65)
	local cream = Color3.fromRGB(255, 246, 220)
	local gold = Color3.fromRGB(255, 202, 69)
	local cyan = Color3.fromRGB(67, 192, 242)
	local muted = Color3.fromRGB(91, 109, 125)
	local root = Instance.new("Model")
	root.Name = "Leaderboards"
	root:SetAttribute("PlaygroundLeaderboardVersion", 1)
	root:SetAttribute("PlaygroundManaged", true)
	root:SetAttribute("FrontDirection", "Local negative Z")

	local function make(class, name, owner, properties)
		local item = Instance.new(class)
		item.Name = name
		for key, value in pairs(properties or {}) do item[key] = value end
		item.Parent = owner
		return item
	end
	local function corner(owner, radius)
		make("UICorner", "Corner", owner, { CornerRadius = UDim.new(0, radius) })
	end
	local function stroke(owner, width, color)
		make("UIStroke", "Outline", owner, { Thickness = width, Color = color or ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	end
	local function label(owner, name, text, position, size, textSize, color)
		return make("TextLabel", name, owner, { Position = position, Size = size, BackgroundTransparency = 1, BorderSizePixel = 0, Font = Enum.Font.FredokaOne, Text = text, TextSize = textSize, TextColor3 = color or ink, TextTruncate = Enum.TextTruncate.AtEnd })
	end
	local function part(owner, name, size, frame, color)
		return make("Part", name, owner, { Size = size, CFrame = frame, Color = color, Anchored = true, CanCollide = true, CanTouch = false, CanQuery = true, Material = Enum.Material.SmoothPlastic, TopSurface = Enum.SurfaceType.Studs, BottomSurface = Enum.SurfaceType.Smooth })
	end
	for index, info in ipairs({
		{ name = "HighestLevel", title = "HIGHEST LEVEL", accent = cyan, stat = "XP", note = "LEVEL · TOTAL XP BREAKS TIES", symbol = "★" },
		{ name = "MostWins", title = "MOST WINS", accent = gold, stat = "Wins", note = "WINS ACROSS ALL THREE GAMES", symbol = "★" },
	}) do
		local model = make("Model", info.name, root)
		model:SetAttribute("LeaderboardStat", info.stat)
		local frame = baseCFrame * CFrame.new((index == 1 and -1 or 1) * 8.9, 0, 0)
		part(model, "BaseOutline", Vector3.new(17, 0.7, 5.2), frame * CFrame.new(0, 0.35, 0), ink)
		part(model, "Base", Vector3.new(16.4, 0.6, 4.6), frame * CFrame.new(0, 0.85, 0), info.accent)
		for _, side in ipairs({-1, 1}) do
			part(model, "Post" .. side, Vector3.new(1.1, 8.6, 1.3), frame * CFrame.new(side * 5.8, 5.1, 0.4), ink)
			part(model, "PostInset" .. side, Vector3.new(0.55, 7.6, 0.16), frame * CFrame.new(side * 5.8, 5.2, -0.35), info.accent)
		end
		part(model, "BoardOutline", Vector3.new(15.8, 21.1, 1.25), frame * CFrame.new(0, 14.15, 0), ink)
		part(model, "BoardInset", Vector3.new(15.25, 20.55, 0.5), frame * CFrame.new(0, 14.15, -0.66), info.accent)
		local face = part(model, "Face", Vector3.new(14.7, 20.05, 0.18), frame * CFrame.new(0, 14.15, -0.99), cream)
		part(model, "TopLip", Vector3.new(16.25, 0.55, 1.7), frame * CFrame.new(0, 24.9, -0.15), ink)
		part(model, "TopHighlight", Vector3.new(15.75, 0.22, 1.25), frame * CFrame.new(0, 25.27, -0.15), info.accent)
		for _, side in ipairs({-1, 1}) do
			local pin = part(model, "CornerPin" .. side, Vector3.new(0.34, 0.34, 0.18), frame * CFrame.new(side * 7.35, 24.1, -1.16), ink)
			pin.Shape = Enum.PartType.Ball
		end
		local gui = make("SurfaceGui", "Display", face, { Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.FixedSize, CanvasSize = Vector2.new(720, 1000), LightInfluence = 0, AlwaysOnTop = false, MaxDistance = 180, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
		local header = make("Frame", "Header", gui, { Position = UDim2.fromOffset(18, 18), Size = UDim2.fromOffset(684, 128), BackgroundColor3 = info.accent, BorderSizePixel = 0 })
		corner(header, 22)
		stroke(header, 4)
		label(header, "Star", info.symbol, UDim2.fromOffset(16, 14), UDim2.fromOffset(62, 62), 58, ink)
		label(header, "Title", info.title, UDim2.fromOffset(79, 14), UDim2.fromOffset(585, 62), 46, ink)
		label(header, "Subtitle", "ALL TIME · TOP 10", UDim2.fromOffset(20, 82), UDim2.fromOffset(644, 28), 23, ink)
		local body = make("Frame", "Body", gui, { Position = UDim2.fromOffset(24, 174), Size = UDim2.fromOffset(672, 742), BackgroundTransparency = 1, BorderSizePixel = 0 })
		local templates = make("Folder", "Templates", gui)
		local row = make("Frame", "RowTemplate", templates, { Size = UDim2.fromOffset(672, 67), BackgroundColor3 = Color3.fromRGB(248, 236, 207), BorderSizePixel = 0, Visible = false })
		corner(row, 13)
		stroke(row, 2, Color3.fromRGB(209, 197, 177))
		local badge = make("Frame", "RankBadge", row, { Position = UDim2.fromOffset(8, 10), Size = UDim2.fromOffset(47, 47), BackgroundColor3 = ink, BorderSizePixel = 0 })
		corner(badge, 12)
		label(row, "Rank", "1", UDim2.fromOffset(8, 10), UDim2.fromOffset(47, 47), 30, cream)
		local avatar = make("ImageLabel", "Avatar", row, { Position = UDim2.fromOffset(69, 7), Size = UDim2.fromOffset(53, 53), BackgroundColor3 = Color3.fromRGB(227, 232, 226), BorderSizePixel = 0, Image = "", ScaleType = Enum.ScaleType.Crop })
		corner(avatar, 13)
		stroke(avatar, 2, ink)
		label(avatar, "Placeholder", "?", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 29, muted)
		local name = label(row, "PlayerName", "Player", UDim2.fromOffset(137, 6), UDim2.fromOffset(331, 55), 30, ink)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local value = label(row, "Value", "—", UDim2.fromOffset(476, 6), UDim2.fromOffset(178, 55), 32, ink)
		value.TextXAlignment = Enum.TextXAlignment.Right
		value.TextScaled = true
		make("UITextSizeConstraint", "TextSize", value, { MinTextSize = 14, MaxTextSize = 32 })
		for rank = 1, 10 do
			local copy = row:Clone()
			copy.Name = string.format("Row%02d", rank)
			copy.Position = UDim2.fromOffset(0, (rank - 1) * 74)
			copy.Rank.Text = tostring(rank)
			if rank <= 3 then
				copy.RankBadge.BackgroundColor3 = rank == 1 and gold or rank == 2 and Color3.fromRGB(190, 214, 228) or Color3.fromRGB(218, 158, 113)
				copy.Rank.TextColor3 = ink
			end
			copy.Parent = body
		end
		local empty = label(gui, "Empty", "Scores appear when the game starts", UDim2.fromOffset(60, 405), UDim2.fromOffset(600, 150), 36, muted)
		empty.TextWrapped = true
		label(gui, "Status", "GLOBAL · ALL TIME", UDim2.fromOffset(24, 927), UDim2.fromOffset(672, 25), 23, ink)
		label(gui, "Footnote", info.note, UDim2.fromOffset(24, 960), UDim2.fromOffset(672, 22), 18, muted)
	end
	root.Parent = parent
	return root
end
