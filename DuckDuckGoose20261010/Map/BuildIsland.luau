return function(target, options)
	target = target or workspace
	options = options or {}
	assert(not target:FindFirstChild("Duck Duck Goose"), "Duck Duck Goose island already exists")
	local origin = options.origin or CFrame.new(12800, 33, 4534)
	local variant = assert(game:GetService("MaterialService"):FindFirstChild("PlaygroundRetroStuds"), "World stud material missing")
	local ink = Color3.fromRGB(26, 30, 38)
	local cream = Color3.fromRGB(237, 227, 206)
	local grass = Color3.fromRGB(133, 165, 106)
	local hedge = Color3.fromRGB(100, 132, 83)
	local wood = Color3.fromRGB(166, 132, 94)
	local tan = Color3.fromRGB(203, 183, 144)
	local yellow = Color3.fromRGB(227, 191, 81)
	local arena = Instance.new("Folder")
	arena.Name = "Duck Duck Goose"
	local function folder(parent, name)
		local item = Instance.new("Folder") item.Name = name item.Parent = parent return item
	end
	local function model(parent, name)
		local item = Instance.new("Model") item.Name = name item.Parent = parent return item
	end
	local function part(parent, name, size, frame, color, solid, className)
		local item = Instance.new(className or "Part")
		item.Name = name item.Size = size item.CFrame = frame item.Color = color
		item.Anchored = true item.CanCollide = solid ~= false item.CanQuery = solid ~= false
		item.CanTouch = className == "Seat"
		item.Material = variant.BaseMaterial
		item.MaterialVariant = color == ink and "" or variant.Name
		for _, face in ipairs({"TopSurface", "BottomSurface", "LeftSurface", "RightSurface", "FrontSurface", "BackSurface"}) do item[face] = Enum.SurfaceType.Smooth end
		item:SetAttribute("DGDuckMap", true)
		if solid == false then item:SetAttribute("DGDecorative", true) item.CastShadow = false end
		item.Parent = parent
		return item
	end
	local function block(parent, name, size, position, color, solid)
		return part(parent, name, size, origin * CFrame.new(position), color, solid)
	end
	local function marker(parent, name, frame)
		local item = part(parent, name, Vector3.new(0.3, 0.3, 0.3), frame, ink, false)
		item.Transparency = 1
		return item
	end
	local function disc(parent, name, radius, top, thickness, color, solid)
		local item = part(parent, name, Vector3.new(thickness, radius * 2, radius * 2), origin * CFrame.new(0, top - thickness / 2, 0) * CFrame.Angles(0, 0, math.pi / 2), color, solid)
		item.Shape = Enum.PartType.Cylinder
		return item
	end
	local function rim(parent, frame, width, depth, y)
		for _, z in ipairs({-depth / 2 + 0.05, depth / 2 - 0.05}) do part(parent, "SeatOutline", Vector3.new(width, 0.1, 0.1), frame * CFrame.new(0, y, z), ink, false) end
		for _, x in ipairs({-width / 2 + 0.05, width / 2 - 0.05}) do part(parent, "SeatOutline", Vector3.new(0.1, 0.1, depth - 0.2), frame * CFrame.new(x, y, 0), ink, false) end
	end
	local function label(host, face, text, name)
		local gui = Instance.new("SurfaceGui") gui.Name = "EditableLabel" gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud gui.PixelsPerStud = 48 gui.LightInfluence = 0.15 gui.Parent = host
		local caption = Instance.new("TextLabel") caption.Name = name or "Caption" caption.Size = UDim2.fromScale(1, 1)
		caption.BackgroundTransparency = 1 caption.Text = text caption.TextColor3 = cream
		caption.Font = Enum.Font.FredokaOne caption.TextWrapped = true caption.TextScaled = true caption.TextStrokeColor3 = ink caption.TextStrokeTransparency = 0
		caption.Parent = gui
		host.MaterialVariant = ""
	end
	local geometry = folder(arena, "Geometry")
	local island = model(geometry, "FifthIsland")
	block(island, "NavyIslandRim", Vector3.new(146, 1.2, 146), Vector3.new(0, -0.7, 0), ink)
	block(island, "StuddedGrass", Vector3.new(144, 1, 144), Vector3.new(0, -0.5, 0), grass)
	block(island, "WarmEarth", Vector3.new(140, 18, 140), Vector3.new(0, -10, 0), Color3.fromRGB(133, 101, 73))
	block(island, "BottomOutline", Vector3.new(142, 0.8, 142), Vector3.new(0, -19.4, 0), ink)
	local grounds = folder(arena, "Grounds")
	local track = model(grounds, "CircularRunningTrack")
	disc(track, "OuterTrackOutline", 36.35, 0.06, 0.08, ink, false)
	disc(track, "StuddedTanTrack", 36, 0.10, 0.12, tan)
	disc(track, "InnerTrackOutline", 25.18, 0.13, 0.08, ink, false)
	disc(track, "CentreGrass", 25, 0.16, 0.14, grass)
	for index = 1, 24 do
		local angle = (index - 1) * math.pi * 2 / 24
		local radial = Vector3.new(math.sin(angle), 0, -math.cos(angle))
		part(track, "OuterLaneDash", Vector3.new(1.7, 0.035, 0.18), origin * CFrame.new(radial * 34.6 + Vector3.new(0, 0.123, 0)) * CFrame.Angles(0, -angle, 0), cream, false)
	end
	local directions = model(track, "TrackDirections")
	directions:SetAttribute("DGPaintedDirections", true)
	for index = 1, 8 do
		local angle = (index - 1) * math.pi * 2 / 8
		local radial = Vector3.new(math.sin(angle), 0, -math.cos(angle))
		local forward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local arrow = model(directions, string.format("Chevron%02d", index))
		arrow:SetAttribute("ClockwiseAngle", angle)
		for _, side in ipairs({-1, 1}) do
			local tip = radial * 30.5 + forward * 1.15 + radial * (side * 0.30) + Vector3.new(0, 0.15, 0)
			local tail = radial * 30.5 - forward * 1.15 + radial * (side * 1.70) + Vector3.new(0, 0.15, 0)
			local arm = tip - tail
			local frame = CFrame.fromMatrix(origin:PointToWorldSpace((tip + tail) / 2), origin:VectorToWorldSpace(arm.Unit), origin.UpVector)
			local paint = part(arrow, side == -1 and "InnerArm" or "OuterArm", Vector3.new(arm.Magnitude, 0.04, 0.45), frame, cream, false)
			paint.MaterialVariant = ""
		end
	end
	local centreFence = model(grounds, "LowCentreHedge")
	for index = 1, 32 do
		local angle = (index - 1) * math.pi * 2 / 32
		local radial = Vector3.new(math.sin(angle), 0, -math.cos(angle))
		local frame = origin * CFrame.new(radial * 17.5 + Vector3.new(0, 1.11, 0)) * CFrame.Angles(0, -angle, 0)
		part(centreFence, "LowHedge", Vector3.new(3.1, 1.9, 0.65), frame, hedge)
		part(centreFence, "HedgeOutline", Vector3.new(3.1, 0.12, 0.72), frame * CFrame.new(0, 0.96, 0), ink, false)
	end
	local gameplay = folder(arena, "Gameplay")
	local bounds = part(gameplay, "ArenaBounds", Vector3.new(144, 80, 144), origin * CFrame.new(0, 40, 0), ink, false)
	bounds.Transparency = 1
	marker(gameplay, "CircleCenter", origin)
	local seats = folder(gameplay, "Seats")
	for index = 1, 16 do
		local angle = (index - 1) * math.pi * 2 / 16
		local radial = Vector3.new(math.sin(angle), 0, -math.cos(angle))
		local position = origin:PointToWorldSpace(radial * 22 + Vector3.new(0, 0.16, 0))
		local frame = CFrame.lookAt(position, origin:PointToWorldSpace(Vector3.new(0, 0.16, 0)), origin.UpVector)
		local seatModel = model(seats, string.format("Seat%02d", index))
		seatModel:SetAttribute("DGSeatIndex", index)
		seatModel:SetAttribute("SeatAngle", angle)
		local seat = part(seatModel, "Seat", Vector3.new(2.9, 0.35, 2.1), frame * CFrame.new(0, 1.45, 0), wood, true, "Seat")
		seatModel.PrimaryPart = seat
		for _, x in ipairs({-1.1, 1.1}) do
			part(seatModel, "FrontLeg", Vector3.new(0.32, 1.3, 0.32), frame * CFrame.new(x, 0.65, -0.83), wood)
			part(seatModel, "RearUpright", Vector3.new(0.3, 3.4, 0.3), frame * CFrame.new(x, 1.7, 0.9), ink)
		end
		rim(seatModel, frame, 2.9, 2.1, 1.64)
		local back = part(seatModel, "Backrest", Vector3.new(2.9, 1.65, 0.36), frame * CFrame.new(0, 2.65, 0.9), wood)
		for _, x in ipairs({-1.4, 1.4}) do part(seatModel, "BackOutline", Vector3.new(0.1, 1.65, 0.39), frame * CFrame.new(x, 2.65, 0.9), ink, false) end
		for _, y in ipairs({1.875, 3.425}) do part(seatModel, "BackOutline", Vector3.new(2.9, 0.1, 0.39), frame * CFrame.new(0, y, 0.9), ink, false) end
		part(seatModel, "DuckYellowAccent", Vector3.new(2.65, 0.14, 0.1), frame * CFrame.new(0, 3.24, 1.11), yellow, false)
		label(back, Enum.NormalId.Back, tostring(index), "SeatNumber")
		marker(seatModel, "Spot", seat.CFrame * CFrame.new(0, 2.1, 0))
		local standPosition = origin:PointToWorldSpace(radial * 25.2 + Vector3.new(0, 3.10, 0))
		marker(seatModel, "StandPoint", CFrame.lookAt(standPosition, origin:PointToWorldSpace(Vector3.new(0, 3.10, 0)), origin.UpVector))
		if index % 4 == 0 then task.wait() end
	end
	local benches = folder(grounds, "SpectatorBenches")
	local function bench(position, name)
		local frame = CFrame.lookAt(origin:PointToWorldSpace(position), origin:PointToWorldSpace(Vector3.new(0, position.Y, 0)), origin.UpVector)
		local group = model(benches, name)
		part(group, "BenchSeat", Vector3.new(10, 0.5, 2.5), frame * CFrame.new(0, 1.9, 0), wood)
		part(group, "BenchBack", Vector3.new(10, 2.2, 0.4), frame * CFrame.new(0, 3.25, 1.07), wood)
		part(group, "BackOutline", Vector3.new(10, 0.14, 0.43), frame * CFrame.new(0, 4.3, 1.07), ink, false)
		part(group, "SeatOutline", Vector3.new(10, 0.13, 0.13), frame * CFrame.new(0, 2.14, -1.22), ink, false)
		for _, x in ipairs({-3.8, 3.8}) do part(group, "Leg", Vector3.new(0.55, 1.65, 2), frame * CFrame.new(x, 0.825, 0), ink) end
		for _, x in ipairs({-2.5, 2.5}) do
			local seat = part(group, "SpectatorSeat", Vector3.new(2.4, 0.1, 2), frame * CFrame.new(x, 2.2, 0), wood, true, "Seat")
			seat.Transparency = 1 seat.CastShadow = false
		end
	end
	bench(Vector3.new(-49, 0, -16), "WestBenchOne")
	bench(Vector3.new(-49, 0, 16), "WestBenchTwo")
	bench(Vector3.new(49, 0, -16), "EastBenchOne")
	bench(Vector3.new(49, 0, 16), "EastBenchTwo")
	bench(Vector3.new(0, 0, 47), "NorthBench")
	local entries = folder(gameplay, "EntrySpawns")
	for row = 1, 4 do for column = 1, 4 do marker(entries, string.format("Entry%02d", #entries:GetChildren() + 1), origin * CFrame.new((column - 2.5) * 4, 3, -56 + (row - 1) * 4)) end end
	local spectators = folder(gameplay, "SpectatorSpawns")
	for row = 1, 4 do for _, x in ipairs({-24, -8, 8, 24}) do marker(spectators, string.format("Spectator%02d", #spectators:GetChildren() + 1), origin * CFrame.new(x, 3, 52 + (row - 1) * 4)) end end
	local signs = model(grounds, "GameSign")
	local signFrame = origin * CFrame.new(-48, 8.2, -48)
	local sign = part(signs, "Nameboard", Vector3.new(17, 3.8, 0.45), signFrame, wood, false)
	label(sign, Enum.NormalId.Front, "DUCK DUCK GOOSE")
	label(sign, Enum.NormalId.Back, "DUCK DUCK GOOSE")
	for _, x in ipairs({-8.42, 8.42}) do part(signs, "SignSideOutline", Vector3.new(0.16, 3.8, 0.48), signFrame * CFrame.new(x, 0, 0), ink, false) end
	for _, y in ipairs({-1.82, 1.82}) do part(signs, "SignHorizontalOutline", Vector3.new(17, 0.16, 0.48), signFrame * CFrame.new(0, y, 0), ink, false) end
	for _, x in ipairs({-7.5, 7.5}) do part(signs, "SignPost", Vector3.new(0.6, 8.1, 0.6), origin * CFrame.new(-48 + x, 4.05, -48), ink) end
	part(signs, "DuckYellowAccent", Vector3.new(16.6, 0.16, 0.08), signFrame * CFrame.new(0, 1.48, -0.265), yellow, false)
	for _, side in ipairs({-1, 1}) do
		block(grounds, "LowBoundary", Vector3.new(0.5, 2.4, 136), Vector3.new(side * 68, 1.2, 0), wood)
		block(grounds, "BoundaryOutline", Vector3.new(0.55, 0.14, 136), Vector3.new(side * 68, 2.45, 0), ink, false)
		block(grounds, "LowBoundary", Vector3.new(136, 2.4, 0.5), Vector3.new(0, 1.2, side * 68), wood)
		block(grounds, "BoundaryOutline", Vector3.new(136, 0.14, 0.55), Vector3.new(0, 2.45, side * 68), ink, false)
	end
	for key, value in pairs({IslandNumber = 5, FloorY = origin.Position.Y, MinimumPlayers = 2, MaxPlayers = 16, SeatCount = 16, SeatCircleRadius = 22, LapInnerRadius = 25, LapOuterRadius = 36, LapRadius = 30.5, RoundDuration = 180, SelectionSeconds = 15, LapDirection = "Clockwise", BuildVersion = "20261010", StudMaterial = variant.Name}) do arena:SetAttribute(key, value) end
	arena:SetAttribute("DGOriginCFrame", origin)
	arena.Parent = target
	return arena
end
