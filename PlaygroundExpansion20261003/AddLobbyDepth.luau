local lobby = workspace:FindFirstChild("Playground Lobby")
assert(lobby and lobby:GetAttribute("PlaygroundManaged") == true, "Install the managed Playground Lobby first")
local existing = lobby:FindFirstChild("Improvements20261003")
if existing then
	assert(existing:GetAttribute("PlaygroundManaged") == true, "Unmanaged lobby improvements already exist")
	return {created = false, applied = existing:GetAttribute("Applied") == true, version = existing:GetAttribute("Version")}
end

local root = Instance.new("Folder")
root.Name = "Improvements20261003"
root:SetAttribute("PlaygroundManaged", true)
root:SetAttribute("Version", 1)
root:SetAttribute("Applied", false)
root.Parent = lobby

local palette = {
	ink = Color3.fromRGB(62, 65, 50),
	rock = Color3.fromRGB(147, 111, 82),
	rockDark = Color3.fromRGB(119, 87, 66),
	rockLight = Color3.fromRGB(173, 131, 94),
	grass = Color3.fromRGB(88, 165, 83),
	grassBright = Color3.fromRGB(108, 181, 91),
	grassDark = Color3.fromRGB(66, 145, 72),
	leaf = Color3.fromRGB(44, 138, 65),
	leafBright = Color3.fromRGB(74, 166, 69),
	leafDark = Color3.fromRGB(33, 116, 62),
	wood = Color3.fromRGB(139, 93, 55),
	woodDark = Color3.fromRGB(88, 61, 40),
	woodLight = Color3.fromRGB(189, 145, 91),
	cream = Color3.fromRGB(246, 227, 184),
	sand = Color3.fromRGB(228, 204, 157),
	water = Color3.fromRGB(77, 175, 193),
	waterLight = Color3.fromRGB(147, 221, 227),
	foam = Color3.fromRGB(229, 250, 239),
	coral = Color3.fromRGB(205, 88, 72),
	gold = Color3.fromRGB(239, 188, 65),
	blue = Color3.fromRGB(70, 157, 191),
	pink = Color3.fromRGB(224, 139, 160),
}

local count = 0
local function folder(name, parent)
	local value = Instance.new("Folder")
	value.Name = name
	value.Parent = parent or root
	return value
end
local cliffs = folder("PerimeterCliffs")
local ledges = folder("GreenLedges")
local waterfall = folder("WaterfallAndStream")
local cave = folder("CaveAlcove")
local architecture = folder("SocialBuilding")
local tower = folder("LookoutTower")
local greenery = folder("TreeAndFlowerGroups")
local routeDetails = folder("RoutesAndFurniture")

local function part(name, size, frame, color, parent, collide, shape, className)
	local value = Instance.new(className or "Part")
	value.Name = name
	value.Size = size
	value.CFrame = typeof(frame) == "CFrame" and frame or CFrame.new(frame)
	value.Color = color
	value.Material = Enum.Material.SmoothPlastic
	value.Anchored = true
	value.CanCollide = collide ~= false
	value.CanTouch = false
	value.CanQuery = collide ~= false
	value.TopSurface = Enum.SurfaceType.Smooth
	value.BottomSurface = Enum.SurfaceType.Smooth
	if shape then value.Shape = shape end
	value.Parent = parent
	count += 1
	return value
end
local function disc(name, diameter, height, position, color, parent, collide)
	return part(name, Vector3.new(height, diameter, diameter), CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2), color, parent, collide, Enum.PartType.Cylinder)
end
local function ball(name, size, frame, color, parent, collide)
	return part(name, size, frame, color, parent, collide, Enum.PartType.Ball)
end
local function model(name, parent)
	local value = Instance.new("Model")
	value.Name = name
	value.Parent = parent
	return value
end
local function outline(value)
	local highlight = Instance.new("Highlight")
	highlight.Name = "SoftCartoonOutline"
	highlight.Adornee = value
	highlight.FillTransparency = 1
	highlight.OutlineColor = palette.ink
	highlight.OutlineTransparency = 0.4
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = value
end
local function beam(name, a, b, width, height, color, parent, collide)
	return part(name, Vector3.new(width, height, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, parent, collide)
end
local function patch(name, x, z, top, width, depth, parent, tint)
	part(name .. "Soil", Vector3.new(width + 0.5, 0.40, depth + 0.5), Vector3.new(x, top - 0.20, z), palette.rockDark, parent)
	return part(name, Vector3.new(width, 0.28, depth), Vector3.new(x, top + 0.02, z), tint or palette.grass, parent)
end

for _, value in ipairs(lobby.Island:GetChildren()) do
	if value:IsA("BasePart") then
		value.Color = string.find(value.Name, "Grass", 1, true) and palette.grass or palette.rockDark
	end
end
for _, value in ipairs(lobby.Paths:GetDescendants()) do
	if value:IsA("BasePart") then
		if string.find(value.Name, "Ink", 1, true) then value.Color = Color3.fromRGB(94, 107, 77)
		elseif string.find(value.Name, "Mint", 1, true) then value.Color = palette.grassBright
		elseif string.find(value.Name, "Inlay", 1, true) then value.Color = palette.gold
		else value.Color = value.Name == "PlazaCenter" and palette.woodLight or palette.sand end
	end
end
for _, value in ipairs(lobby.PicnicTerrace:GetDescendants()) do
	if value:IsA("BasePart") and string.find(value.Name, "GrassTerrace", 1, true) then
		value.Color = string.find(value.Name, "Rim", 1, true) and palette.rockDark or palette.grassBright
	elseif value:IsA("BasePart") and string.find(value.Name, "TerraceStep", 1, true) then
		value.Color = string.find(value.Name, "Rim", 1, true) and palette.woodDark or palette.sand
	end
end
for _, value in ipairs(lobby.Nature:GetDescendants()) do
	if value:IsA("BasePart") then
		if value.Name == "Trunk" or value.Name == "Log" then value.Color = palette.wood
		elseif value.Name == "Crown" then value.Color = palette.leaf
		elseif value.Name == "CrownLeft" then value.Color = palette.leafDark
		elseif value.Name == "CrownRight" then value.Color = palette.leafBright
		elseif string.find(value.Name, "Bush", 1, true) then value.Color = palette.leaf
		elseif string.find(value.Name, "Stem", 1, true) then value.Color = palette.leafDark end
	elseif value:IsA("Highlight") then
		value.OutlineColor = palette.ink
		value.OutlineTransparency = 0.35
	end
end
for _, value in ipairs(lobby.Pond:GetDescendants()) do
	if value:IsA("BasePart") and string.sub(value.Name, 1, 5) == "Water" then
		value.Color = palette.water
		value.Transparency = 0.18
	end
end

local cliffTops = {}
local function cliffColumn(name, x, z, width, depth, height, yaw, facing, number)
	local value = model(name, cliffs)
	local cf = CFrame.new(x, 4 + height / 2, z) * CFrame.Angles(0, yaw, 0)
	part("RockMass", Vector3.new(width, height, depth), cf, number % 3 == 0 and palette.rockDark or palette.rock, value)
	part("Crest", Vector3.new(width * 0.91, 3.8, depth * 0.93), CFrame.new(x, 4 + height + 0.8, z) * CFrame.Angles(0, yaw + math.rad(10), 0), palette.rockLight, value)
	local front = Vector3.new(x, 4 + height * 0.42, z) + facing * (math.min(width, depth) / 2 + 0.6)
	local faceSize = math.abs(facing.X) > 0.5 and Vector3.new(5, height * 0.53, depth * 0.45) or Vector3.new(width * 0.44, height * 0.53, 5)
	part("BrokenFace", faceSize, CFrame.new(front) * CFrame.Angles(0, yaw + math.rad(number % 2 == 0 and 9 or -7), 0), number % 2 == 0 and palette.rockLight or palette.rockDark, value)
	if number % 2 == 0 then
		local top = 4 + height + 2.9
		patch("CrestGrass", x + facing.X * 4, z + facing.Z * 4, top, width * 0.56, depth * 0.53, value, palette.grassBright)
	end
	table.insert(cliffTops, {x = x, z = z, y = 4 + height})
	return value
end
for index = 0, 10 do
	local x = -160 + index * 32
	local northHeight = 44 + (index * 7 % 6) * 5
	local southHeight = 43 + (index * 11 % 5) * 6
	cliffColumn("North" .. index, x, -160, 42, 38, northHeight, math.rad(index % 2 == 0 and 5 or -5), Vector3.new(0, 0, 1), index)
	cliffColumn("South" .. index, x, 160, 42, 38, southHeight, math.rad(index % 2 == 0 and -4 or 4), Vector3.new(0, 0, -1), index + 11)
end
for index = 0, 8 do
	local z = -128 + index * 32
	local westHeight = 48 + (index * 7 % 5) * 6
	local eastHeight = 46 + (index * 3 % 6) * 5
	cliffColumn("West" .. index, -164, z, 40, 42, westHeight, math.rad(index % 2 == 0 and 4 or -4), Vector3.new(1, 0, 0), index + 22)
	cliffColumn("East" .. index, 164, z, 40, 42, eastHeight, math.rad(index % 2 == 0 and -5 or 5), Vector3.new(-1, 0, 0), index + 31)
end
for _, x in ipairs({-160, 160}) do
	for _, z in ipairs({-152, 152}) do
		part("CornerMass", Vector3.new(54, 59, 54), CFrame.new(x, 33.5, z) * CFrame.Angles(0, math.pi / 4, 0), palette.rock, cliffs)
		part("CornerCrest", Vector3.new(43, 4, 43), CFrame.new(x, 65, z) * CFrame.Angles(0, math.pi / 4, 0), palette.rockLight, cliffs)
	end
end

part("NorthLedgeBase", Vector3.new(248, 23, 18), Vector3.new(-5, 15.5, -132), palette.rock, ledges)
patch("NorthLedgeGrass", -5, -132, 27, 248, 18, ledges)
part("WestGardenBase", Vector3.new(28, 10, 32), Vector3.new(-122, 9, 116), palette.rock, ledges)
patch("WestGardenGrass", -122, 116, 14, 28, 32, ledges, palette.grassBright)
part("WestTreeShelf", Vector3.new(12, 15, 64), Vector3.new(-138, 11.5, 4), palette.rockDark, ledges)
patch("WestTreeShelfGrass", -138, 4, 19, 12, 64, ledges)
part("EastTreeShelf", Vector3.new(12, 20, 120), Vector3.new(138, 14, 12), palette.rock, ledges)
patch("EastTreeShelfGrass", 138, 12, 24, 12, 120, ledges)
part("SouthTreeShelf", Vector3.new(136, 19, 12), Vector3.new(12, 13.5, 136), palette.rockDark, ledges)
patch("SouthTreeShelfGrass", 12, 136, 23, 136, 12, ledges)

local stairsData = {}
local function stairs(name, start, direction, steps, run, rise, width, parent)
	local value = model(name, parent)
	local right = Vector3.new(-direction.Z, 0, direction.X)
	local yaw = math.atan2(direction.X, direction.Z)
	local previous = {}
	for index = 1, steps do
		local center = start + direction * ((index - 0.5) * run) + Vector3.new(0, index * rise - 0.3, 0)
		part("Step" .. index, Vector3.new(width, 0.6, run + 0.12), CFrame.new(center) * CFrame.Angles(0, yaw, 0), index % 2 == 0 and palette.woodLight or palette.sand, value)
		part("StepNose" .. index, Vector3.new(width, 0.12, 0.22), CFrame.new(center + direction * (-run / 2 + 0.08) + Vector3.new(0, 0.32, 0)) * CFrame.Angles(0, yaw, 0), palette.woodDark, value, false)
		if index == 1 or index == steps or index % 4 == 0 then
			for _, side in ipairs({-1, 1}) do
				local railPoint = center + right * (side * (width / 2 - 0.35)) + Vector3.new(0, 2.9, 0)
				part("RailPost", Vector3.new(0.6, 3.0, 0.6), railPoint - Vector3.new(0, 1.1, 0), palette.woodDark, value)
				ball("PostCap", Vector3.new(0.85, 0.85, 0.85), railPoint + Vector3.new(0, 0.3, 0), palette.cream, value, false)
				if previous[side] then beam("Handrail", previous[side], railPoint, 0.45, 0.55, palette.cream, value) end
				previous[side] = railPoint
				if index % 8 == 0 then
					local height = center.Y - 4
					part("Trestle", Vector3.new(0.8, height, 0.8), Vector3.new(railPoint.X, 4 + height / 2, railPoint.Z), palette.woodDark, value)
				end
			end
		end
	end
	local finish = start + direction * (steps * run) + Vector3.new(0, steps * rise, 0)
	table.insert(stairsData, {name = name, count = steps, rise = rise, run = run, width = width, start = {start.X, start.Y, start.Z}, finish = {finish.X, finish.Y, finish.Z}})
	return value, finish
end
stairs("NorthGardenStairs", Vector3.new(-65, 4, -36), Vector3.new(0, 0, -1), 30, 2.8, 23 / 30, 14, ledges)
part("NorthLanding", Vector3.new(14, 0.60, 6), Vector3.new(-65, 26.7, -123), palette.sand, ledges)
stairs("WestGardenStairs", Vector3.new(-119, 4, 65), Vector3.new(0, 0, 1), 14, 2.5, 10 / 14, 14, ledges)

for _, value in ipairs(lobby.Nature:GetChildren()) do
	if value:IsA("Model") then
		local trunk = value:FindFirstChild("Trunk")
		if trunk and trunk:IsA("BasePart") then
			local position = trunk.Position
			local offset = Vector3.zero
			if position.Z <= -120 then
				offset = Vector3.new(math.clamp(position.X, -119, 110) - position.X, 23.15, -132 - position.Z)
			elseif position.X >= 130 then
				if position.Z < -48 or position.Z > 72 then
					local height = position.Z < -48 and 30 or 32
					part(value.Name .. "Perch", Vector3.new(18, height - 4, 20), Vector3.new(136, 4 + (height - 4) / 2, position.Z), palette.rock, ledges)
					patch(value.Name .. "PerchGrass", 136, position.Z, height, 18, 20, ledges)
					offset = Vector3.new(136 - position.X, height - 4 + 0.15, 0)
				else
					offset = Vector3.new(136 - position.X, 20.15, 0)
				end
			elseif position.X <= -130 then
				if position.Z >= 90 then offset = Vector3.new(-127 - position.X, 10.15, 118 - position.Z)
				elseif position.Z >= -28 and position.Z <= 35 then offset = Vector3.new(-136 - position.X, 15.15, 0)
				else
					local z = math.clamp(position.Z, -100, 100)
					part(value.Name .. "Perch", Vector3.new(26, 8, 22), Vector3.new(-139, 46, z), palette.rock, ledges)
					patch(value.Name .. "PerchGrass", -139, z, 50, 26, 22, ledges)
					offset = Vector3.new(-135 - position.X, 46.15, z - position.Z)
				end
			elseif position.Z >= 130 then
				if position.X < -56 or position.X > 80 then
					part(value.Name .. "Perch", Vector3.new(22, 24, 14), Vector3.new(position.X, 16, 135), palette.rock, ledges)
					patch(value.Name .. "PerchGrass", position.X, 135, 28, 22, 14, ledges)
					offset = Vector3.new(0, 24.15, 135 - position.Z)
				else offset = Vector3.new(0, 19.15, 135 - position.Z) end
			end
			if value.Name == "Tree21" then offset += Vector3.new(10, 0, 0) end
			if value.Name == "Tree27" then offset += Vector3.new(5, 0, 0) end
			if offset ~= Vector3.zero then value:PivotTo(value:GetPivot() + offset) end
		elseif string.find(value.Name, "FlowerBed", 1, true) or string.find(value.Name, "Shrub", 1, true) then
			local cf = value:GetBoundingBox()
			if cf.Position.Z < -122 then value:PivotTo(value:GetPivot() + Vector3.new(0, 23.2, -132 - cf.Position.Z))
			elseif cf.Position.X > 130 then value:PivotTo(value:GetPivot() + Vector3.new(136 - cf.Position.X, 20.2, math.clamp(cf.Position.Z, -43, 68) - cf.Position.Z))
			elseif cf.Position.X < -128 and cf.Position.Z > 99 then value:PivotTo(value:GetPivot() + Vector3.new(-127 - cf.Position.X, 10.2, 117 - cf.Position.Z))
			elseif cf.Position.X < -130 and cf.Position.Z >= -28 and cf.Position.Z <= 35 then value:PivotTo(value:GetPivot() + Vector3.new(-136 - cf.Position.X, 15.2, 0))
			elseif cf.Position.Z > 130 and cf.Position.X >= -56 and cf.Position.X <= 80 then value:PivotTo(value:GetPivot() + Vector3.new(0, 19.2, 135 - cf.Position.Z))
			elseif cf.Position.Z > 130 and cf.Position.X > 80 then value:PivotTo(value:GetPivot() + Vector3.new(116 - cf.Position.X, 6.2, 125 - cf.Position.Z)) end
		end
	end
end

local function tree(name, x, z, ground, scale, style)
	local value = model(name, greenery)
	part("Trunk", Vector3.new(2.4 * scale, 8.2 * scale, 2.4 * scale), Vector3.new(x, ground + 4.1 * scale, z), palette.wood, value)
	if style == "Fir" then
		for index = 1, 4 do
			local width = (15 - index * 2.7) * scale
			part("FirTier" .. index, Vector3.new(width, 4.7 * scale, width), CFrame.new(x, ground + (7 + index * 3.1) * scale, z) * CFrame.Angles(0, math.pi / 4, 0), index % 2 == 0 and palette.leaf or palette.leafBright, value, false)
		end
	else
		part("Branch", Vector3.new(1.1 * scale, 5.7 * scale, 1.1 * scale), CFrame.new(x + 1.6 * scale, ground + 7 * scale, z) * CFrame.Angles(0, 0, math.rad(-33)), palette.wood, value)
		for index, site in ipairs({{0,12,0,12,7,11},{-4,10,1,9,6,8},{4,14,-1,9,6,9}}) do
			part("FacetedCrown" .. index, Vector3.new(site[4], site[5], site[6]) * scale, CFrame.new(x + site[1] * scale, ground + site[2] * scale, z + site[3] * scale) * CFrame.Angles(0, math.rad(index * 17), 0), index == 2 and palette.leafDark or palette.leafBright, value, false)
		end
	end
	outline(value)
	return value
end
local treeSites = {
	{"NorthFir1",-100,-132,27,0.85,"Fir"}, {"NorthFir2",-79,-133,27,1.0,"Fir"}, {"NorthTree1",-33,-132,27,1.1,"Round"},
	{"NorthFir3",27,-132,27,0.9,"Fir"}, {"NorthTree2",82,-132,27,1.0,"Round"},
	{"TowerFir",111,-25,4,0.9,"Fir"}, {"TowerTree",114,9,4,1.1,"Round"},
	{"VoteFir",132,-106,4,0.88,"Fir"}, {"ShopFir",-128,-69,4,1.0,"Fir"},
	{"PondFir",-30,110,4,0.9,"Fir"}, {"WaterfallTree",-137,93,38,0.9,"Round"},
	{"WestGardenTree",-126,122,14,0.95,"Round"}, {"CaveRoofFir",-140,51,17.2,0.74,"Fir"},
	{"SouthFir",-22,136,23,0.9,"Fir"}, {"SouthTree",49,136,23,0.9,"Round"},
	{"EastFir",136,39,24,0.85,"Fir"}, {"EastTree",136,-15,24,0.95,"Round"},
}
for _, site in ipairs(treeSites) do tree(site[1], site[2], site[3], site[4], site[5], site[6]) end

part("WaterfallRock", Vector3.new(22, 34, 26), CFrame.new(-140, 21, 84) * CFrame.Angles(0, math.rad(-5), 0), palette.rockDark, waterfall)
part("WaterfallUpperShelf", Vector3.new(26, 4.4, 32), Vector3.new(-140, 35.8, 84), palette.rock, waterfall)
patch("WaterfallShelfGrass", -140, 84, 38, 26, 32, waterfall)
local upperWater = part("UpperPool", Vector3.new(15, 0.18, 16), Vector3.new(-134, 38.25, 84), palette.water, waterfall, false)
upperWater.Transparency = 0.10
local sheet = part("FallingWater", Vector3.new(0.45, 34.4, 10), Vector3.new(-128.05, 21.0, 84), palette.water, waterfall, false)
sheet.Transparency = 0.10
for index = 1, 5 do
	local stripe = part("WaterRibbon" .. index, Vector3.new(0.16, 32.6 - (index % 2) * 1.8, 0.8 + (index % 2) * 0.3), Vector3.new(-127.75, 21.0, 79.7 + index * 1.4), index % 2 == 0 and palette.waterLight or palette.foam, waterfall, false)
	stripe.Transparency = index % 2 == 0 and 0.12 or 0.30
end
part("StreamBed", Vector3.new(28, 0.14, 12), Vector3.new(-114, 4.08, 84), palette.rockDark, waterfall, false)
local stream = part("Stream", Vector3.new(28, 0.15, 10.5), Vector3.new(-114, 4.20, 84), palette.water, waterfall, false)
stream.Transparency = 0.12
disc("SplashPool", 15.5, 0.16, Vector3.new(-126, 4.26, 84), palette.waterLight, waterfall, false)
for index = 1, 7 do
	local theta = index * math.pi * 2 / 7
	ball("Foam", Vector3.new(2.6, 0.75, 1.8), Vector3.new(-126 + math.cos(theta) * 5, 4.65, 84 + math.sin(theta) * 4), palette.foam, waterfall, false)
end
for _, side in ipairs({-1, 1}) do
	part("StreamBank", Vector3.new(27, 0.55, 2.0), CFrame.new(-114, 4.25, 84 + side * 6.2) * CFrame.Angles(0, math.rad(side * 3), 0), palette.rock, waterfall, false)
	for index = 1, 3 do
		ball("RiverRock", Vector3.new(2.8, 1.6, 2.3), Vector3.new(-130 + index * 8, 4.60, 84 + side * 7.2), palette.rockLight, waterfall)
	end
end

part("CaveBack", Vector3.new(2.4, 11.4, 24), Vector3.new(-143, 9.7, 54), palette.woodDark, cave)
part("CaveWestWall", Vector3.new(18, 11.4, 3.8), CFrame.new(-134.8, 9.7, 41.7) * CFrame.Angles(0, math.rad(-4), 0), palette.rock, cave)
part("CaveEastWall", Vector3.new(18, 11.4, 3.8), CFrame.new(-134.8, 9.7, 66.3) * CFrame.Angles(0, math.rad(3), 0), palette.rockDark, cave)
part("CaveRoof", Vector3.new(21, 3.0, 28), Vector3.new(-134.5, 15.55, 54), palette.rock, cave)
patch("CaveRoofGrass", -134.5, 54, 17.1, 21, 28, cave)
part("CaveFloor", Vector3.new(18, 0.30, 20), Vector3.new(-134.2, 4.15, 54), palette.sand, cave)
part("CaveFrontLeft", Vector3.new(3.5, 9.6, 4.5), CFrame.new(-126.7, 8.8, 42.8) * CFrame.Angles(0, 0, math.rad(-6)), palette.rockLight, cave)
part("CaveFrontRight", Vector3.new(3.5, 9.6, 4.5), CFrame.new(-126.7, 8.8, 65.2) * CFrame.Angles(0, 0, math.rad(5)), palette.rockLight, cave)
part("CaveFrontTop", Vector3.new(3.5, 2.4, 24), Vector3.new(-126.7, 13.8, 54), palette.rockLight, cave)
part("CaveBench", Vector3.new(3, 0.65, 10), Vector3.new(-139, 6.15, 54), palette.woodLight, cave)
for _, z in ipairs({50, 58}) do part("CaveBenchLeg", Vector3.new(2.4, 2.0, 0.65), Vector3.new(-139, 5.0, z), palette.woodDark, cave) end
local lantern = part("CaveLantern", Vector3.new(1.1, 1.5, 1.1), Vector3.new(-139.5, 9.2, 44.3), palette.gold, cave, false)
local light = Instance.new("PointLight")
light.Name = "WarmLantern"
light.Color = palette.cream
light.Range = 18
light.Brightness = 0.6
light.Shadows = false
light.Parent = lantern
beam("CaveApproach", Vector3.new(-124, 4.12, 54), Vector3.new(-104, 4.12, 54), 8.3, 0.20, palette.sand, routeDetails, false)

part("BuildingFoundation", Vector3.new(34, 0.65, 44), Vector3.new(-123.5, 4.35, -31), palette.rockDark, architecture)
part("BuildingFloor", Vector3.new(32, 0.30, 42), Vector3.new(-123.5, 4.73, -31), palette.woodLight, architecture)
part("BackWall", Vector3.new(1.5, 11.5, 42), Vector3.new(-138.5, 10.25, -31), palette.cream, architecture)
for _, z in ipairs({-52, -10}) do
	part("SideWall", Vector3.new(32, 11.5, 1.5), Vector3.new(-123.5, 10.25, z), palette.cream, architecture)
	part("SideBaseTrim", Vector3.new(32.5, 1.5, 1.9), Vector3.new(-123.5, 5.3, z), palette.woodDark, architecture)
	part("SideTopTrim", Vector3.new(33, 0.65, 1.9), Vector3.new(-123.5, 15.95, z), palette.woodDark, architecture)
	part("SideWindowFrame", Vector3.new(15, 5.3, 0.5), Vector3.new(-124, 10.6, z + (z < -31 and -0.80 or 0.80)), palette.woodDark, architecture, false)
	local glass = part("SideWindow", Vector3.new(14.1, 4.4, 0.22), Vector3.new(-124, 10.6, z + (z < -31 and -1.08 or 1.08)), palette.waterLight, architecture, false)
	glass.Transparency = 0.35
	for index = -1, 1 do part("WindowMullion", Vector3.new(0.3, 4.5, 0.26), Vector3.new(-124 + index * 4.4, 10.6, z + (z < -31 and -1.25 or 1.25)), palette.woodDark, architecture, false) end
end
for _, side in ipairs({-1, 1}) do
	local z = -31 + side * 14.2
	part("FrontWall", Vector3.new(1.5, 11.5, 13.4), Vector3.new(-108.5, 10.25, z), palette.cream, architecture)
	part("FrontBaseTrim", Vector3.new(1.95, 1.5, 13.4), Vector3.new(-108.5, 5.3, z), palette.woodDark, architecture)
	part("FrontWindowFrame", Vector3.new(0.5, 5.1, 9.0), Vector3.new(-107.55, 10.55, z), palette.woodDark, architecture, false)
	local glass = part("FrontWindow", Vector3.new(0.22, 4.3, 8.3), Vector3.new(-107.15, 10.55, z), palette.waterLight, architecture, false)
	glass.Transparency = 0.35
	part("FrontWindowCross", Vector3.new(0.3, 4.5, 0.3), Vector3.new(-107.0, 10.55, z), palette.woodDark, architecture, false)
	part("FrontWindowCrossHorizontal", Vector3.new(0.3, 0.3, 8.4), Vector3.new(-107.0, 10.55, z), palette.woodDark, architecture, false)
end
part("DoorLintel", Vector3.new(2.0, 2.7, 15), Vector3.new(-108.4, 14.35, -31), palette.wood, architecture)
for _, z in ipairs({-38.4, -23.6}) do part("DoorFrame", Vector3.new(2.0, 8.3, 0.80), Vector3.new(-108.25, 8.7, z), palette.woodDark, architecture) end
part("FrontHeader", Vector3.new(2, 0.8, 44), Vector3.new(-108.5, 15.95, -31), palette.woodDark, architecture)
local roofPitch = math.atan(4.2 / 24)
part("NorthRoofSlope", Vector3.new(36, 0.95, 24.4), CFrame.new(-123.5, 18.50, -43) * CFrame.Angles(-roofPitch, 0, 0), palette.wood, architecture)
part("SouthRoofSlope", Vector3.new(36, 0.95, 24.4), CFrame.new(-123.5, 18.50, -19) * CFrame.Angles(roofPitch, 0, 0), palette.wood, architecture)
part("RoofRidge", Vector3.new(36.3, 0.75, 1.0), Vector3.new(-123.5, 20.6, -31), palette.woodDark, architecture)
for _, z in ipairs({-55, -7}) do part("EaveBeam", Vector3.new(36.6, 0.70, 1.0), Vector3.new(-123.5, 16.45, z), palette.woodDark, architecture) end
part("PorchFloor", Vector3.new(13.5, 0.65, 26), Vector3.new(-102.5, 4.55, -31), palette.woodLight, architecture)
part("PorchRoof", Vector3.new(14.4, 0.75, 27.2), CFrame.new(-102.4, 12.3, -31) * CFrame.Angles(0, 0, math.rad(3)), palette.wood, architecture)
part("PorchFrontBeam", Vector3.new(1.0, 1.0, 27.6), Vector3.new(-96.2, 12.0, -31), palette.woodDark, architecture)
for _, z in ipairs({-43.6, -18.4}) do
	part("PorchPost", Vector3.new(0.95, 7.8, 0.95), Vector3.new(-97, 8.1, z), palette.cream, architecture)
	part("PorchPostFoot", Vector3.new(1.5, 0.75, 1.5), Vector3.new(-97, 5.12, z), palette.woodDark, architecture)
	part("PorchBracket", Vector3.new(0.8, 2.2, 0.8), CFrame.new(-98.0, 11.3, z) * CFrame.Angles(0, 0, math.rad(-40)), palette.woodDark, architecture, false)
end
part("PorchEntryStep", Vector3.new(3.0, 0.35, 14), Vector3.new(-94.4, 4.2, -31), palette.sand, architecture)
part("PorchEntryStepTop", Vector3.new(2.4, 0.30, 14), Vector3.new(-96.0, 4.5, -31), palette.sand, architecture)
local oldBench = lobby.Furniture:FindFirstChild("ShopBench")
if oldBench and oldBench:IsA("Model") then oldBench:PivotTo(oldBench:GetPivot() + Vector3.new(5, -0.26, -6)) end
for _, side in ipairs({-1, 1}) do
	local box = model("PorchFlowerBox", architecture)
	part("Box", Vector3.new(2.4, 1.3, 6.5), Vector3.new(-101, 5.7, -31 + side * 11.7), palette.woodDark, box)
	for index = 1, 4 do
		ball("BoxLeaves", Vector3.new(2.3, 1.8, 2.2), Vector3.new(-101, 6.8, -34 + side * 11.7 + index * 1.4), palette.leaf, box, false)
		ball("Blossom", Vector3.new(0.9, 0.85, 0.9), Vector3.new(-100.9, 7.4, -34 + side * 11.7 + index * 1.4), index % 2 == 0 and palette.gold or palette.pink, box, false)
	end
end

local towerX, towerZ = 80, -14
disc("TowerFoundation", 25, 0.7, Vector3.new(towerX, 4.35, towerZ), palette.rockDark, tower)
for index = 1, 5 do
	disc("TowerStripe" .. index, 18, 10.8, Vector3.new(towerX, 4 + (index - 0.5) * 10.8, towerZ), index % 2 == 0 and palette.cream or palette.coral, tower)
end
disc("TowerBaseTrim", 19.6, 1.3, Vector3.new(towerX, 4.65, towerZ), palette.woodDark, tower)
local innerRails, outerRails = {}, {}
for index = 1, 72 do
	local theta = math.pi + index * math.pi * 2 / 24
	local top = 4 + index * 0.75
	local center = Vector3.new(towerX + math.cos(theta) * 15, top - 0.30, towerZ + math.sin(theta) * 15)
	part("LookoutStep" .. index, Vector3.new(8, 0.60, 5.7), CFrame.new(center) * CFrame.Angles(0, -theta, 0), index % 2 == 0 and palette.woodLight or palette.sand, tower)
	if index == 1 or index % 3 == 0 then
		for _, data in ipairs({{radius = 10.9, previous = innerRails}, {radius = 19.1, previous = outerRails}}) do
			if data.radius == 10.9 or index < 72 then
				local point = Vector3.new(towerX + math.cos(theta) * data.radius, top + 2.7, towerZ + math.sin(theta) * data.radius)
				local post = part("SpiralRailPost", Vector3.new(0.55, 2.8, 0.55), point - Vector3.new(0, 1.15, 0), palette.woodDark, tower)
				post:SetAttribute("RailSide", data.radius == 10.9 and "Inner" or "Outer")
				post:SetAttribute("RailStep", index)
				post:SetAttribute("RailRadius", data.radius)
				if data.previous.point then
					local rail = beam("SpiralHandrail", data.previous.point, point, 0.42, 0.50, palette.cream, tower)
					rail:SetAttribute("RailSide", data.radius == 10.9 and "Inner" or "Outer")
					rail:SetAttribute("RailStep", index)
					rail:SetAttribute("RailRadius", data.radius)
				end
				data.previous.point = point
			end
		end
	end
end
for index = 1, 24 do
	local theta = index * math.pi * 2 / 24
	local center = Vector3.new(towerX + math.cos(theta) * 21, 58.10, towerZ + math.sin(theta) * 21)
	part("ObservationRim" .. index, Vector3.new(8.6, 0.80, 8.3), CFrame.new(center) * CFrame.Angles(0, -theta, 0), palette.woodDark, tower)
	part("ObservationDeck" .. index, Vector3.new(8.0, 0.60, 7.9), CFrame.new(center + Vector3.new(0, 0.30, 0)) * CFrame.Angles(0, -theta, 0), palette.woodLight, tower)
end
local previousPoint
for index = 0, 12 do
	local theta = index * math.pi * 2 / 12
	local point = Vector3.new(towerX + math.cos(theta) * 24, 61.15, towerZ + math.sin(theta) * 24)
	part("ObservationPost", Vector3.new(0.80, 3.0, 0.80), point - Vector3.new(0, 1.1, 0), palette.cream, tower)
	if previousPoint then beam("ObservationRail", previousPoint, point, 0.6, 0.65, palette.woodDark, tower) end
	previousPoint = point
end
local innerPrevious
for index = 0, 24 do
	local theta = index * math.pi * 2 / 24
	local point = Vector3.new(towerX + math.cos(theta) * 17, 61.15, towerZ + math.sin(theta) * 17)
	if index == 11 or index == 12 or index == 13 then
		innerPrevious = nil
	else
		part("ObservationInnerPost", Vector3.new(0.65, 2.9, 0.65), point - Vector3.new(0, 1.1, 0), palette.woodDark, tower)
		if innerPrevious then beam("ObservationInnerRail", innerPrevious, point, 0.45, 0.55, palette.cream, tower) end
		innerPrevious = point
	end
end
for index = 1, 6 do
	local theta = index * math.pi * 2 / 6
	part("CanopyPost", Vector3.new(1.0, 7.5, 1.0), Vector3.new(towerX + math.cos(theta) * 22, 62.2, towerZ + math.sin(theta) * 22), palette.woodDark, tower)
end
disc("TowerRoofEave", 51.2, 1.0, Vector3.new(towerX, 66.3, towerZ), palette.woodDark, tower)
disc("TowerRoofLower", 49.0, 1.3, Vector3.new(towerX, 67.1, towerZ), palette.coral, tower)
disc("TowerRoofMiddle", 35.0, 1.4, Vector3.new(towerX, 68.3, towerZ), palette.coral, tower)
disc("TowerRoofUpper", 20.0, 1.4, Vector3.new(towerX, 69.5, towerZ), palette.wood, tower)
ball("TowerFinial", Vector3.new(3.2, 3.2, 3.2), Vector3.new(towerX, 71.4, towerZ), palette.gold, tower, false)
for _, side in ipairs({-1, 1}) do
	part("TowerWindowFrame", Vector3.new(0.4, 6.4, 3.8), Vector3.new(towerX + side * 9.05, 30, towerZ), palette.woodDark, tower, false)
	local glass = part("TowerWindow", Vector3.new(0.12, 5.6, 3.0), Vector3.new(towerX + side * 9.32, 30, towerZ), palette.waterLight, tower, false)
	glass.Transparency = 0.25
end

local function flowerGroup(name, x, z, ground, tint)
	local value = model(name, greenery)
	for index = 1, 6 do
		local theta = index * 2.4
		local distance = 1.2 + index % 3
		local position = Vector3.new(x + math.cos(theta) * distance, ground + 0.9, z + math.sin(theta) * distance)
		part("Stem", Vector3.new(0.18, 1.8, 0.18), position, palette.leafDark, value, false)
		ball("Leaf", Vector3.new(1.0, 0.35, 0.6), position + Vector3.new(0.3, -0.3, 0), palette.leaf, value, false)
		for petal = 1, 4 do
			local angle = petal * math.pi / 2
			ball("Petal", Vector3.new(0.7, 0.38, 0.7), position + Vector3.new(math.cos(angle) * 0.35, 0.9, math.sin(angle) * 0.35), tint, value, false)
		end
		ball("FlowerCenter", Vector3.new(0.45, 0.40, 0.45), position + Vector3.new(0, 1.05, 0), palette.gold, value, false)
	end
end
for index, data in ipairs({{-81,-131,27},{-37,-130,27},{23,-132,27},{92,-131,27},{-123,122,14},{-134,58,17.2},{-103,-63,4},{-84,-46,4},{-39,22,4},{-23,48,4},{17,72,4},{42,95,4},{110,11,4},{122,-70,4},{40,-91,4}}) do
	flowerGroup("FlowerGroup" .. index, data[1], data[2], data[3], index % 3 == 0 and palette.cream or (index % 2 == 0 and palette.pink or palette.waterLight))
end

local function bench(name, x, z, floor, yaw)
	local value = model(name, routeDetails)
	local base = CFrame.new(x, floor, z) * CFrame.Angles(0, yaw, 0)
	part("Seat", Vector3.new(10, 0.6, 3), base * CFrame.new(0, 2.0, 0), palette.woodLight, value)
	part("Back", Vector3.new(10, 2.2, 0.55), base * CFrame.new(0, 3.4, 1.2), palette.woodLight, value)
	for _, side in ipairs({-1, 1}) do part("Leg", Vector3.new(0.6, 2.0, 2.5), base * CFrame.new(side * 3.6, 1, 0), palette.woodDark, value) end
end
bench("NorthLookoutBench", -31, -131, 27.16, 0)
bench("NorthLookoutBench2", 48, -132, 27.16, 0)
bench("WestGardenBench", -118, 114, 14.16, -math.pi / 2)

local buntingColors = {palette.coral, palette.gold, palette.blue, palette.cream, palette.pink}
for index, pair in ipairs({{Vector3.new(-98, 16, -23), Vector3.new(-38, 17, -36)}, {Vector3.new(44, 17, -44), Vector3.new(119, 18, -62)}}) do
	local a, b = pair[1], pair[2]
	beam("BuntingRope" .. index, a, b, 0.12, 0.12, palette.woodDark, routeDetails, false)
	for flag = 1, 14 do
		local point = a:Lerp(b, flag / 15) - Vector3.new(0, 1.0 + math.sin(flag / 15 * math.pi) * 0.55, 0)
		part("BuntingFlag", Vector3.new(1.4, 1.8, 0.12), CFrame.new(point) * CFrame.Angles(0, math.atan2(b.X - a.X, b.Z - a.Z), math.rad(8)), buntingColors[(flag - 1) % #buntingColors + 1], routeDetails, false, nil, "WedgePart")
	end
end

root:SetAttribute("PartCount", count)
root:SetAttribute("Applied", true)
root:SetAttribute("HighestWalkableFloor", 58.7)
root:SetAttribute("CliffMaximumHeight", 80)
root:SetAttribute("MainStairWidth", 14)
root:SetAttribute("MaximumStairRise", 0.766667)
lobby:SetAttribute("DepthPassVersion", 1)

return {
	created = true, parts = count, floorY = 4, boundsUnchanged = true,
	spawnPlazaUnchanged = true, voteAndShopZonesUnchanged = true, coinMarkersUnchanged = true,
	stairs = stairsData,
	lookout = {center = {80, -14}, steps = 72, stepRise = 0.75, stairWidth = 8, observationFloor = 58.7, roofTop = 73},
	waterfall = {position = {-128.05, 21, 84}, sourceFloor = 38, drop = 34.4, decorative = true},
	cave = {center = {-135, 4.3, 54}, doorCenter = {-125, 8, 54}, clearWidth = 18, clearHeight = 8.3},
	shop = {doorCenter = {-108.5, 8.7, -31}, clearWidth = 14, clearHeight = 8.3},
	cameras = {
		{position = {220, 184, 224}, target = {0, 22, 0}},
		{position = {32, 10, 20}, target = {-118, 17, 30}},
		{position = {-92, 10, 115}, target = {-137, 27, 83}},
		{position = {12, 10, -61}, target = {80, 30, -14}},
	},
}
