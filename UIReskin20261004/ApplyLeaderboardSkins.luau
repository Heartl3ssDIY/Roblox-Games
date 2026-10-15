return function(assets)
	assert(typeof(assets) == "table", "Provide the uploaded artwork asset map")
	local lobby = assert(workspace:FindFirstChild("Playground Lobby"), "Playground Lobby is missing")
	local boards = assert(lobby:FindFirstChild("Leaderboards"), "Authored leaderboards are missing")
	local ink = Color3.fromRGB(24, 30, 51)
	local light = Color3.fromRGB(255, 249, 224)
	local keys = { "avatar-border", "board-background", "header-background", "player-row", "rank-bronze", "rank-fourth-onwards", "rank-gold", "rank-silver" }
	local images = {}
	for _, name in ipairs(keys) do
		local key = "Leaderboard/" .. name .. ".png"
		local value = assets[key]
		assert(typeof(value) == "string" and value ~= "", "Uploaded artwork is missing: " .. key)
		images[name] = value
	end
	local function required(parent, name, className)
		local child = assert(parent:FindFirstChild(name), parent:GetFullName() .. "." .. name .. " is missing")
		assert(child:IsA(className), child:GetFullName() .. " must be a " .. className)
		return child
	end
	local targets = {}
	for _, name in ipairs({ "HighestLevel", "MostWins" }) do
		local model = required(boards, name, "Model")
		local gui = required(required(model, "Face", "BasePart"), "Display", "SurfaceGui")
		local header = required(gui, "Header", "Frame")
		local body = required(gui, "Body", "Frame")
		local rows = {}
		for rank = 1, 10 do table.insert(rows, { row = required(body, string.format("Row%02d", rank), "Frame"), rank = rank }) end
		local template = required(required(gui, "Templates", "Folder"), "RowTemplate", "Frame")
		table.insert(rows, { row = template, rank = 4 })
		for _, entry in ipairs(rows) do
			required(entry.row, "RankBadge", "Frame")
			required(entry.row, "Avatar", "ImageLabel")
			for _, label in ipairs({ "Rank", "PlayerName", "Value" }) do required(entry.row, label, "TextLabel") end
		end
		table.insert(targets, { gui = gui, header = header, body = body, rows = rows })
	end
	local imageCount = 0
	local glyphCount = 0
	local function clearBackground(target)
		target.BackgroundTransparency = 1
		target.BorderSizePixel = 0
		for _, child in ipairs(target:GetChildren()) do
			if child:IsA("UIStroke") then child.Enabled = false end
		end
	end
	local function image(parent, name, content, zIndex, key)
		local artwork = parent:FindFirstChild(name)
		assert(not artwork or artwork:IsA("ImageLabel"), parent:GetFullName() .. "." .. name .. " is not an ImageLabel")
		if not artwork then
			artwork = Instance.new("ImageLabel")
			artwork.Name = name
			artwork.Parent = parent
		end
		artwork.AnchorPoint = Vector2.zero
		artwork.Position = UDim2.fromScale(0, 0)
		artwork.Size = UDim2.fromScale(1, 1)
		artwork.BackgroundTransparency = 1
		artwork.BorderSizePixel = 0
		artwork.Image = content
		artwork.ImageColor3 = Color3.new(1, 1, 1)
		artwork.ImageTransparency = 0
		artwork.ScaleType = Enum.ScaleType.Fit
		artwork.ZIndex = zIndex
		artwork.Active = false
		artwork.Selectable = false
		artwork.Visible = true
		artwork:SetAttribute("UISkinAssetKey", key)
		artwork:SetAttribute("UISkinPixelPolicy", "Original PNG; fit without distortion")
		imageCount += 1
		return artwork
	end
	local function glyph(label)
		clearBackground(label)
		label.TextColor3 = light
		label.TextTransparency = 0
		label.TextStrokeTransparency = 1
		label.ZIndex = 15
		local outline = label:FindFirstChild("TextOutline")
		assert(not outline or outline:IsA("UIStroke"), label:GetFullName() .. ".TextOutline is not a UIStroke")
		if not outline then
			outline = Instance.new("UIStroke")
			outline.Name = "TextOutline"
			outline.Parent = label
		end
		outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		outline.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
		outline.Thickness = 0.085
		outline.Color = ink
		outline.Transparency = 0
		outline.LineJoinMode = Enum.LineJoinMode.Round
		outline.Enabled = true
		glyphCount += 1
	end
	for _, target in ipairs(targets) do
		local gui, header, body = target.gui, target.header, target.body
		for _, descendant in ipairs(gui:GetDescendants()) do
			if descendant:IsA("TextLabel") then
				glyph(descendant)
			elseif descendant:IsA("Frame") or descendant:IsA("ImageLabel") then
				clearBackground(descendant)
			end
		end
		image(gui, "LeaderboardBoardArtwork", images["board-background"], 1, "Leaderboard/board-background.png")
		header.ZIndex = 5
		body.ZIndex = 5
		image(header, "LeaderboardHeaderArtwork", images["header-background"], 6, "Leaderboard/header-background.png")
		for _, entry in ipairs(target.rows) do
			local row = entry.row
			row.ZIndex = 5
			image(row, "LeaderboardRowArtwork", images["player-row"], 6, "Leaderboard/player-row.png")
			local badge, avatar = row.RankBadge, row.Avatar
			badge.ZIndex = 8
			avatar.ZIndex = 9
			local rankKey = entry.rank == 1 and "rank-gold" or entry.rank == 2 and "rank-silver" or entry.rank == 3 and "rank-bronze" or "rank-fourth-onwards"
			image(badge, "LeaderboardRankArtwork", images[rankKey], 9, "Leaderboard/" .. rankKey .. ".png")
			image(avatar, "LeaderboardAvatarBorder", images["avatar-border"], 12, "Leaderboard/avatar-border.png")
		end
		local star = header:FindFirstChild("Star")
		local starAsset = assets["Attachments/icon-xp-star.png"]
		if star and star:IsA("TextLabel") and typeof(starAsset) == "string" and starAsset ~= "" then
			star.TextTransparency = 1
			local outline = star:FindFirstChild("TextOutline")
			if outline then outline.Enabled = false end
			image(star, "LeaderboardStarArtwork", starAsset, 16, "Attachments/icon-xp-star.png")
		elseif star then
			local previous = star:FindFirstChild("LeaderboardStarArtwork")
			if previous and previous:IsA("ImageLabel") then previous.Visible = false end
		end
		gui:SetAttribute("LeaderboardArtworkVersion", "UIReskin20261004")
	end
	return { boards = #targets, rowsIncludingTemplates = 22, artworkPlacements = imageCount, styledLabels = glyphCount, runtimeScriptsChanged = false, authoredLayoutPreserved = true }
end
