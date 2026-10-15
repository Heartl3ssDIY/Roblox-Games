local Workspace = game:GetService("Workspace")
local existing = Workspace:FindFirstChild("Playground Lobby")
if existing then
	assert(existing:GetAttribute("PlaygroundManaged") == true, "An unowned Playground Lobby already exists")
	return {created = false, folder = existing:GetFullName(), version = existing:GetAttribute("BuilderVersion")}
end

local root = Instance.new("Folder")
root.Name = "Playground Lobby"
root:SetAttribute("PlaygroundManaged", true)
root:SetAttribute("BuilderVersion", 1)
root:SetAttribute("FloorY", 4)
root:SetAttribute("BoundsSize", Vector3.new(320, 80, 304))
root:SetAttribute("VoteZoneCenter", Vector3.new(88, 10, -82))
root:SetAttribute("VoteZoneSize", Vector3.new(74, 12, 60))
root.Parent = Workspace

local colors = {
	ink = Color3.fromRGB(29, 46, 72),
	grass = Color3.fromRGB(125, 208, 133),
	grassLight = Color3.fromRGB(157, 225, 142),
	grassDark = Color3.fromRGB(104, 187, 129),
	mint = Color3.fromRGB(106, 219, 177),
	cream = Color3.fromRGB(255, 242, 197),
	path = Color3.fromRGB(247, 218, 166),
	wood = Color3.fromRGB(184, 119, 77),
	gold = Color3.fromRGB(255, 207, 88),
	blue = Color3.fromRGB(94, 179, 232),
	pink = Color3.fromRGB(250, 154, 177),
	lilac = Color3.fromRGB(182, 163, 233),
	leaf = Color3.fromRGB(71, 179, 130),
	leafLight = Color3.fromRGB(113, 213, 143),
	water = Color3.fromRGB(87, 191, 223),
	white = Color3.fromRGB(255, 251, 232),
}

local partCount = 0
local function folder(name, parent)
	local value = Instance.new("Folder")
	value.Name = name
	value.Parent = parent or root
	return value
end

local island = folder("Island")
local paths = folder("Paths")
local nature = folder("Nature")
local furniture = folder("Furniture")
local pond = folder("Pond")
local terrace = folder("PicnicTerrace")
local shop = folder("ShopNook")
local voting = folder("VotingAlcove")
local gameplay = folder("Gameplay")
local coinSpawns = folder("CoinSpawns", gameplay)
local voteChoices = folder("VoteChoices", gameplay)

local function part(name, size, position, color, parent, collide, shape)
	local value = Instance.new("Part")
	value.Name = name
	value.Size = size
	value.CFrame = typeof(position) == "CFrame" and position or CFrame.new(position)
	value.Color = color
	value.Anchored = true
	value.CanCollide = collide ~= false
	value.CanTouch = false
	value.CanQuery = true
	value.Material = Enum.Material.SmoothPlastic
	value.TopSurface = Enum.SurfaceType.Smooth
	value.BottomSurface = Enum.SurfaceType.Smooth
	if shape then value.Shape = shape end
	value.Parent = parent
	partCount += 1
	return value
end

local function disc(name, diameter, height, position, color, parent, collide)
	return part(name, Vector3.new(height, diameter, diameter), CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2), color, parent, collide, Enum.PartType.Cylinder)
end

local function ball(name, size, position, color, parent, collide)
	return part(name, size, position, color, parent, collide, Enum.PartType.Ball)
end

local function model(name, parent)
	local value = Instance.new("Model")
	value.Name = name
	value.Parent = parent
	return value
end

local function outline(value)
	local highlight = Instance.new("Highlight")
	highlight.Name = "CartoonOutline"
	highlight.Adornee = value
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 0
	highlight.OutlineColor = colors.ink
	highlight.Parent = value
end

local function slab(name, size, top, x, z, color, parent)
	part(name .. "Rim", Vector3.new(size.X + 1.2, size.Y, size.Z + 1.2), Vector3.new(x, top - size.Y / 2 - 0.12, z), colors.ink, parent)
	return part(name, size, Vector3.new(x, top - size.Y / 2, z), color, parent)
end

local function marker(name, size, position, parent)
	local value = part(name, size, position, colors.white, parent, false)
	value.Transparency = 1
	value.CanQuery = false
	value.CastShadow = false
	return value
end

part("MainOutline", Vector3.new(284, 8, 308), Vector3.new(0, -1.15, 0), colors.ink, island)
part("WestOutline", Vector3.new(22, 8, 264), Vector3.new(-153, -1.15, 0), colors.ink, island)
part("EastOutline", Vector3.new(22, 8, 264), Vector3.new(153, -1.15, 0), colors.ink, island)
part("MainGrass", Vector3.new(280, 8, 304), Vector3.new(0, 0, 0), colors.grass, island)
part("WestGrass", Vector3.new(20, 8, 260), Vector3.new(-150, 0, 0), colors.grass, island)
part("EastGrass", Vector3.new(20, 8, 260), Vector3.new(150, 0, 0), colors.grass, island)
for _, side in ipairs({-1, 1}) do
	for _, endSide in ipairs({-1, 1}) do
		part("CornerGrass", Vector3.new(22, 8, 22), CFrame.new(side * 139, 0, endSide * 130) * CFrame.Angles(0, math.pi / 4, 0), colors.grass, island)
	end
end

disc("PlazaInk", 68, 0.12, Vector3.new(0, 4.01, 0), colors.ink, paths, false)
disc("PlazaMint", 66.6, 0.12, Vector3.new(0, 4.08, 0), colors.mint, paths, false)
disc("PlazaCream", 61, 0.12, Vector3.new(0, 4.15, 0), colors.cream, paths, false)
disc("PlazaCenter", 15, 0.10, Vector3.new(0, 4.21, 0), colors.path, paths, false)
for index = 1, 8 do
	local angle = index * math.pi / 4
	local dot = disc("PlazaInlay" .. index, 2.1, 0.08, Vector3.new(math.cos(angle) * 24.5, 4.24, math.sin(angle) * 24.5), colors.gold, paths, false)
	dot.CastShadow = false
end

local pathRoutes = {
	{Vector3.new(18, 0, -18), Vector3.new(38, 0, -38), Vector3.new(58, 0, -59), Vector3.new(70, 0, -69)},
	{Vector3.new(-28, 0, -6), Vector3.new(-51, 0, -12), Vector3.new(-76, 0, -25), Vector3.new(-95, 0, -31)},
	{Vector3.new(-18, 0, 24), Vector3.new(-32, 0, 42), Vector3.new(-52, 0, 50), Vector3.new(-62, 0, 50)},
	{Vector3.new(29, 0, 17), Vector3.new(51, 0, 29), Vector3.new(73, 0, 43), Vector3.new(90, 0, 50)},
	{Vector3.new(-102, 0, -32), Vector3.new(-104, 0, -76), Vector3.new(-69, 0, -110), Vector3.new(-15, 0, -118), Vector3.new(44, 0, -116), Vector3.new(73, 0, -107)},
	{Vector3.new(-62, 0, 115), Vector3.new(-37, 0, 127), Vector3.new(8, 0, 129), Vector3.new(50, 0, 122), Vector3.new(67, 0, 114)},
	{Vector3.new(0, 0, 29), Vector3.new(0, 0, 60), Vector3.new(11, 0, 85), Vector3.new(8, 0, 129)},
}

local function route(points, number)
	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]
		local midpoint = (a + b) / 2
		local length = (a - b).Magnitude
		local yaw = math.atan2(b.X - a.X, b.Z - a.Z)
		local frame = CFrame.new(midpoint.X, 4.025, midpoint.Z) * CFrame.Angles(0, yaw, 0)
		part("PathInk" .. number .. "_" .. index, Vector3.new(10.2, 0.10, length + 1), frame, colors.ink, paths, false).CastShadow = false
		part("Path" .. number .. "_" .. index, Vector3.new(8.8, 0.10, length + 1.3), frame + Vector3.new(0, 0.075, 0), colors.path, paths, false).CastShadow = false
	end
	for index, point in ipairs(points) do
		disc("PathInkJoin" .. number .. "_" .. index, 10.2, 0.10, Vector3.new(point.X, 4.025, point.Z), colors.ink, paths, false).CastShadow = false
		disc("PathJoin" .. number .. "_" .. index, 8.8, 0.10, Vector3.new(point.X, 4.10, point.Z), colors.path, paths, false).CastShadow = false
	end
end
for index, points in ipairs(pathRoutes) do route(points, index) end

local function tree(name, x, z, height, scale, tint, ground)
	ground = ground or 4
	local value = model(name, nature)
	local trunkHeight = height * 0.45
	part("Trunk", Vector3.new(2.6 * scale, trunkHeight, 2.6 * scale), Vector3.new(x, ground + trunkHeight / 2, z), colors.wood, value)
	local canopyY = ground + height * 0.70
	ball("Crown", Vector3.new(13 * scale, 11 * scale, 12 * scale), Vector3.new(x, canopyY, z), tint, value, false)
	ball("CrownLeft", Vector3.new(8 * scale, 8 * scale, 8 * scale), Vector3.new(x - 4.5 * scale, canopyY - scale, z + 0.5 * scale), colors.leaf, value, false)
	ball("CrownRight", Vector3.new(9 * scale, 8 * scale, 8 * scale), Vector3.new(x + 4.2 * scale, canopyY + 1.2 * scale, z - 0.6 * scale), colors.leafLight, value, false)
	outline(value)
	return value
end

local treeSites = {
	{-138, -106, 21, 1.10}, {-122, -125, 19, 0.95}, {-85, -130, 22, 1.1},
	{-43, -137, 18, 0.9}, {13, -136, 22, 1.1}, {52, -135, 18, 0.9},
	{137, -121, 24, 1.15}, {143, -82, 20, 1.0}, {139, -28, 22, 1.1},
	{144, 20, 19, 0.95}, {144, 58, 24, 1.15}, {139, 113, 22, 1.0},
	{106, 138, 21, 1.1}, {38, 142, 19, 0.9}, {-12, 141, 22, 1.0},
	{-107, 128, 23, 1.1}, {-138, 95, 19, 0.9}, {-140, 52, 22, 1.1},
	{-141, 4, 20, 1.0}, {-130, -61, 23, 1.1}, {-57, -70, 18, 0.9},
	{-29, -48, 18, 0.85}, {27, -67, 20, 0.95}, {51, -10, 17, 0.85},
	{-33, 72, 17, 0.8}, {32, 62, 19, 0.85}, {-112, 70, 19, 0.9},
}
for index, site in ipairs(treeSites) do
	tree("Tree" .. index, site[1], site[2], site[3], site[4], index % 3 == 0 and colors.leafLight or colors.leaf)
end

local function shrub(name, x, z, width, tint, ground)
	ground = ground or 4
	local value = model(name, nature)
	ball("Bush", Vector3.new(width, width * 0.58, width * 0.78), Vector3.new(x, ground + width * 0.20, z), tint or colors.leaf, value, false)
	ball("BushSide", Vector3.new(width * 0.55, width * 0.44, width * 0.60), Vector3.new(x + width * 0.32, ground + width * 0.13, z + width * 0.08), colors.leafLight, value, false)
	return value
end

for index, site in ipairs({{-117,-98,9},{-66,-130,10},{-10,-133,8},{114,-122,10},{138,-54,9},{134,47,10},{126,134,11},{61,140,8},{-76,131,8},{-135,114,10},{-131,30,10},{-90,8,9},{-66,-50,8},{44,-50,10},{59,15,8},{-28,92,9}}) do
	shrub("Shrub" .. index, site[1], site[2], site[3], index % 3 == 0 and colors.mint or colors.leaf)
end

local function flowerCluster(name, x, z, count, ground)
	ground = ground or 4
	local value = model(name, nature)
	for index = 1, count do
		local angle = index * 2.4
		local distance = 1.1 + (index % 3) * 1.1
		local fx, fz = x + math.cos(angle) * distance, z + math.sin(angle) * distance
		part("Stem" .. index, Vector3.new(0.20, 1.3, 0.20), Vector3.new(fx, ground + 0.65, fz), colors.leaf, value, false)
		local tint = index % 3 == 0 and colors.pink or (index % 2 == 0 and colors.lilac or colors.white)
		for petal = 1, 4 do
			local theta = petal * math.pi / 2
			ball("Petal", Vector3.new(0.8, 0.45, 0.8), Vector3.new(fx + math.cos(theta) * 0.35, ground + 1.3, fz + math.sin(theta) * 0.35), tint, value, false)
		end
		ball("Center", Vector3.new(0.45, 0.42, 0.45), Vector3.new(fx, ground + 1.5, fz), colors.gold, value, false)
	end
	return value
end
for index, site in ipairs({{-120,-108},{-84,-119},{-51,-124},{23,-129},{128,-58},{127,28},{120,132},{29,135},{-22,133},{-123,106},{-132,23},{-92,-2},{-34,-39},{43,-37},{-29,103},{41,69}}) do
	flowerCluster("FlowerBed" .. index, site[1], site[2], 3)
end

local function bench(name, x, z, yaw, ground, tint)
	ground = ground or 4
	local value = model(name, furniture)
	local base = CFrame.new(x, ground, z) * CFrame.Angles(0, yaw, 0)
	for _, side in ipairs({-1, 1}) do
		part("Leg", Vector3.new(0.65, 2, 2.5), base * CFrame.new(side * 3.5, 1, 0), colors.ink, value)
	end
	part("Seat", Vector3.new(9, 0.60, 3), base * CFrame.new(0, 2, 0), tint or colors.cream, value)
	part("Back", Vector3.new(9, 2.1, 0.6), base * CFrame.new(0, 3.4, 1.2), tint or colors.cream, value)
	outline(value)
	return value
end
bench("PlazaBenchWest", -34, -15, math.pi / 2)
bench("PlazaBenchEast", 34, -16, -math.pi / 2)
bench("PromenadeBench", -19, -106, 0, 4, colors.mint)
bench("PondBench", -101, 115, math.pi, 4, colors.pink)
bench("SouthBench", 32, 115, math.pi, 4, colors.lilac)

local function rock(name, x, z, size, ground)
	ground = ground or 4
	local value = model(name, nature)
	local base = part("Stone", size, CFrame.new(x, ground + size.Y / 2, z) * CFrame.Angles(0, math.rad((x + z) % 45), 0), Color3.fromRGB(184, 204, 204), value)
	part("StoneCap", Vector3.new(size.X * 0.85, 0.3, size.Z * 0.86), base.CFrame * CFrame.new(0, size.Y / 2 + 0.1, 0), colors.cream, value)
	outline(value)
	return value
end
rock("LowRock", -105, 14, Vector3.new(9, 1.2, 8))
rock("MiddleRock", -111, 23, Vector3.new(10, 2.2, 8))
rock("WideRock", -101, 33, Vector3.new(12, 1.6, 8))
rock("PondRockWest", -108, 86, Vector3.new(5, 1.2, 4))
rock("PondRockEast", -20, 87, Vector3.new(6, 1.8, 5))
rock("NorthRock", 9, -95, Vector3.new(8, 1.4, 6))

local log = model("FallenLog", nature)
part("Log", Vector3.new(21, 3, 3), CFrame.new(-110, 5.5, 46) * CFrame.Angles(0, math.rad(-12), 0), colors.wood, log, true, Enum.PartType.Cylinder)
for _, side in ipairs({-1, 1}) do
	part("CutEnd", Vector3.new(0.14, 2.65, 2.65), CFrame.new(-110, 5.5, 46) * CFrame.Angles(0, math.rad(-12), 0) * CFrame.new(side * 10.6, 0, 0), colors.path, log, false, Enum.PartType.Cylinder)
end
outline(log)

part("PondBorder", Vector3.new(44, 0.14, 39.8), Vector3.new(-62, 4.00, 82), colors.ink, pond, false)
disc("PondBorderWest", 39.8, 0.14, Vector3.new(-84, 4.00, 82), colors.ink, pond, false)
disc("PondBorderEast", 39.8, 0.14, Vector3.new(-40, 4.00, 82), colors.ink, pond, false)
part("ShallowBottom", Vector3.new(44, 0.14, 37.4), Vector3.new(-62, 4.09, 82), colors.path, pond, false)
disc("ShallowBottomWest", 37.4, 0.14, Vector3.new(-84, 4.09, 82), colors.path, pond, false)
disc("ShallowBottomEast", 37.4, 0.14, Vector3.new(-40, 4.09, 82), colors.path, pond, false)
local waterSurfaces = {
	part("Water", Vector3.new(44, 0.12, 37), Vector3.new(-62, 4.18, 82), colors.water, pond, false),
	disc("WaterWest", 37, 0.12, Vector3.new(-84, 4.18, 82), colors.water, pond, false),
	disc("WaterEast", 37, 0.12, Vector3.new(-40, 4.18, 82), colors.water, pond, false),
}
for _, surface in ipairs(waterSurfaces) do
	surface.Transparency = 0.28
	surface.CastShadow = false
end
for index, site in ipairs({{-88,75},{-89,91},{-41,72},{-35,86},{-51,94}}) do
	disc("LilyPad" .. index, index % 2 == 0 and 3.4 or 2.8, 0.12, Vector3.new(site[1], 4.30, site[2]), colors.leaf, pond, false)
	if index % 2 == 0 then
		ball("LilyFlower", Vector3.new(0.9, 0.6, 0.9), Vector3.new(site[1], 4.65, site[2]), colors.pink, pond, false)
	end
end
for index, site in ipairs({{-94,68},{-95,97},{-32,68},{-29,99}}) do
	local reeds = model("Reeds" .. index, pond)
	for stem = 1, 3 do
		local rx, rz = site[1] + (stem - 2) * 0.6, site[2] + (stem % 2) * 0.7
		part("Stem", Vector3.new(0.16, 2.6, 0.16), Vector3.new(rx, 5.3, rz), colors.leaf, reeds, false)
		part("Tip", Vector3.new(0.40, 0.9, 0.4), Vector3.new(rx, 6.35, rz), colors.wood, reeds, false)
	end
end

local bridge = model("Footbridge", pond)
part("BridgeBase", Vector3.new(14, 0.60, 40), Vector3.new(-62, 6.08, 82), colors.ink, bridge)
for index = 1, 10 do
	part("Plank" .. index, Vector3.new(13.2, 0.30, 3.86), Vector3.new(-62, 6.25, 62 + (index - 0.5) * 4), index % 2 == 0 and colors.cream or colors.path, bridge)
end
for index = 1, 4 do
	local top = 4 + index * 0.6
	local northZ = 48.5 + index * 3
	local southZ = 115.5 - index * 3
	slab("NorthBridgeStep" .. index, Vector3.new(13.2, top - 4, 3), top, -62, northZ, colors.path, bridge)
	slab("SouthBridgeStep" .. index, Vector3.new(13.2, top - 4, 3), top, -62, southZ, colors.path, bridge)
end
for _, side in ipairs({-1, 1}) do
	part("SideRail", Vector3.new(0.70, 0.75, 40), Vector3.new(-62 + side * 6.6, 8.65, 82), colors.cream, bridge)
	for index = 0, 4 do
		part("Post", Vector3.new(0.9, 3.1, 0.9), Vector3.new(-62 + side * 6.6, 7.50, 63 + index * 9.5), colors.blue, bridge)
		ball("RoundCap", Vector3.new(1.1, 1.1, 1.1), Vector3.new(-62 + side * 6.6, 9.15, 63 + index * 9.5), colors.gold, bridge, false)
	end
end
outline(bridge)

local duck = model("PondDuck", pond)
ball("Body", Vector3.new(2.8, 1.3, 1.8), Vector3.new(-82, 4.9, 85), colors.white, duck, false)
ball("Head", Vector3.new(1.1, 1.1, 1.1), Vector3.new(-83.0, 5.6, 85), colors.white, duck, false)
part("Beak", Vector3.new(0.8, 0.25, 0.65), Vector3.new(-83.7, 5.45, 85), colors.gold, duck, false)
ball("Eye", Vector3.new(0.16, 0.16, 0.16), Vector3.new(-83.13, 5.76, 84.51), colors.ink, duck, false)
outline(duck)

local terraceTops = {7, 10, 13, 16}
local terraceSizes = {Vector3.new(76, 3, 68), Vector3.new(60, 3, 56), Vector3.new(44, 3, 44), Vector3.new(28, 3, 32)}
local terraceCenters = {96, 102, 108, 114}
for index, top in ipairs(terraceTops) do
	slab("GrassTerrace" .. index, terraceSizes[index], top, 90, terraceCenters[index], index % 2 == 0 and colors.grassLight or colors.grass, terrace)
end
for index = 1, 16 do
	local top = 4 + index * 0.75
	slab("TerraceStep" .. index, Vector3.new(10, top - 4, 3), top, 90, 48.5 + index * 3, colors.path, terrace)
end
disc("PicnicPadInk", 24, 0.14, Vector3.new(90, 16.05, 114), colors.ink, terrace, false)
disc("PicnicPad", 22.7, 0.14, Vector3.new(90, 16.15, 114), colors.cream, terrace, false)
local picnic = model("PicnicTable", terrace)
part("TableTop", Vector3.new(10, 0.65, 4.4), Vector3.new(90, 19, 114), colors.path, picnic)
for _, side in ipairs({-1, 1}) do
	part("TableLeg", Vector3.new(0.7, 2.8, 3.8), Vector3.new(90 + side * 3.1, 17.55, 114), colors.ink, picnic)
	part("BenchSeat", Vector3.new(10, 0.60, 1.6), Vector3.new(90, 17.65, 114 + side * 3.5), colors.mint, picnic)
	for _, endSide in ipairs({-1, 1}) do
		part("BenchLeg", Vector3.new(0.6, 1.7, 1.3), Vector3.new(90 + endSide * 3.4, 16.85, 114 + side * 3.5), colors.ink, picnic)
	end
end
outline(picnic)
tree("TerraceTree", 115, 113, 16, 0.85, colors.leafLight, 10)
flowerCluster("TerraceFlowersWest", 69, 111, 4, 10)
flowerCluster("TerraceFlowersEast", 110, 123, 3, 13)

slab("ShopPaving", Vector3.new(42, 0.24, 38), 4.26, -111, -31, colors.cream, shop)
local kiosk = model("Kiosk", shop)
part("CounterBody", Vector3.new(7.5, 3.2, 25), Vector3.new(-120, 5.85, -31), colors.mint, kiosk)
part("CounterRim", Vector3.new(8.4, 0.6, 26), Vector3.new(-120, 7.5, -31), colors.ink, kiosk)
part("CounterTop", Vector3.new(8.0, 0.32, 25.4), Vector3.new(-120, 7.85, -31), colors.cream, kiosk)
for _, side in ipairs({-1, 1}) do
	part("AwningPost", Vector3.new(0.9, 8.8, 0.9), Vector3.new(-122.8, 8.65, -31 + side * 12), colors.blue, kiosk)
end
part("CanopyRim", Vector3.new(13.3, 0.9, 27), Vector3.new(-120, 13.10, -31), colors.ink, kiosk)
for index = 1, 6 do
	part("CanopyStripe" .. index, Vector3.new(12.6, 0.7, 4.35), Vector3.new(-120, 13.38, -44.05 + (index - 0.5) * 4.35), index % 2 == 0 and colors.pink or colors.cream, kiosk)
end
for index = 1, 3 do
	disc("DisplayPlinth" .. index, 3.8, 0.5, Vector3.new(-120, 8.25, -39 + (index - 1) * 8), colors.blue, kiosk)
	ball("DisplayBubble" .. index, Vector3.new(2.3, 2.3, 2.3), Vector3.new(-120, 9.6, -39 + (index - 1) * 8), index == 1 and colors.gold or (index == 2 and colors.pink or colors.lilac), kiosk, false)
end
outline(kiosk)
bench("ShopBench", -97, -43, -math.pi / 2, 4.26, colors.lilac)
marker("ShopZone", Vector3.new(34, 12, 38), Vector3.new(-107, 10, -31), gameplay)

slab("VotingPaving", Vector3.new(68, 0.26, 54), 4.28, 88, -82, colors.lilac, voting)
slab("VotingInner", Vector3.new(63, 0.18, 49), 4.46, 88, -82, colors.cream, voting)
for _, site in ipairs({{56,-105},{120,-105},{56,-59},{120,-59}}) do
	disc("PlanterBase", 5.5, 1.0, Vector3.new(site[1], 4.75, site[2]), colors.ink, voting)
	disc("Planter", 4.9, 1.0, Vector3.new(site[1], 5.10, site[2]), colors.path, voting)
	shrub("VotingShrub", site[1], site[2], 5.7, colors.mint, 5.2)
end

local choiceData = {
	{key = "BritishBulldog", label = "British Bulldog", x = 71, color = colors.blue},
	{key = "TagYoureIt", label = "Tag You're It", x = 105, color = colors.pink},
}
for _, data in ipairs(choiceData) do
	local stand = model(data.key .. "Stand", voting)
	slab("ChoicePad", Vector3.new(25, 0.24, 28), 4.70, data.x, -84, data.color, stand)
	for _, side in ipairs({-1, 1}) do
		part("ArchPost", Vector3.new(1.3, 10, 1.3), Vector3.new(data.x + side * 11.4, 9.70, -96), colors.blue, stand)
		ball("ArchCap", Vector3.new(1.6, 1.6, 1.6), Vector3.new(data.x + side * 11.4, 14.80, -96), colors.gold, stand, false)
	end
	part("ArchTop", Vector3.new(24.5, 1.5, 2.1), Vector3.new(data.x, 14.15, -96), colors.cream, stand)
	part("ChoiceCard", Vector3.new(19, 5.0, 0.65), Vector3.new(data.x, 10.65, -96), colors.ink, stand)
	part("ChoiceCardFace", Vector3.new(18.3, 4.35, 0.20), Vector3.new(data.x, 10.65, -95.55), data.color, stand)
	local pad = marker(data.key, Vector3.new(25, 8, 28), Vector3.new(data.x, 8.6, -84), voteChoices)
	pad:SetAttribute("GameId", data.key)
	pad:SetAttribute("DisplayName", data.label)
	pad:SetAttribute("Available", true)
	local label = Instance.new("SurfaceGui")
	label.Name = "GameName"
	label.Face = Enum.NormalId.Back
	label.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	label.PixelsPerStud = 38
	label.AlwaysOnTop = false
	label.LightInfluence = 0
	label.Parent = stand.ChoiceCardFace
	local text = Instance.new("TextLabel")
	text.Name = "Label"
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.Text = data.label
	text.TextColor3 = colors.white
	text.TextStrokeColor3 = colors.ink
	text.TextStrokeTransparency = 0
	text.TextScaled = true
	text.TextWrapped = true
	text.Parent = label
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = text
	outline(stand)
end

local voteZone = marker("VoteZone", Vector3.new(74, 12, 60), Vector3.new(88, 10, -82), gameplay)
voteZone:SetAttribute("IsVotingArea", true)
voteZone:SetAttribute("AvailableGames", "BritishBulldog,TagYoureIt")
marker("LobbyBounds", Vector3.new(320, 80, 304), Vector3.new(0, 40, 0), gameplay)

local spawn = Instance.new("SpawnLocation")
spawn.Name = "LobbySpawn"
spawn.Size = Vector3.new(12, 1, 12)
spawn.Position = Vector3.new(0, 4.6, 0)
spawn.Anchored = true
spawn.Transparency = 1
spawn.CanCollide = false
spawn.CanTouch = false
spawn.CanQuery = false
spawn.Enabled = true
spawn.Neutral = true
spawn.Duration = 0
spawn.AllowTeamChangeOnTouch = false
spawn:SetAttribute("PlaygroundLobbySpawn", true)
spawn.Parent = gameplay
partCount += 1

local coinSites = {
	Vector3.new(0, 6.4, 43), Vector3.new(-39, 6.4, -9), Vector3.new(-84, 6.4, -27),
	Vector3.new(-88, 6.4, -94), Vector3.new(7, 6.4, -118), Vector3.new(66, 6.4, -114),
	Vector3.new(-62, 8.7, 82), Vector3.new(-101, 7.8, 33), Vector3.new(90, 18.4, 100),
	Vector3.new(34, 6.4, 126),
}
for index, position in ipairs(coinSites) do
	local value = marker(string.format("Coin%02d", index), Vector3.new(1, 1, 1), position, coinSpawns)
	value:SetAttribute("PickupId", "LobbyCoin" .. index)
	value:SetAttribute("Value", 1)
	value:SetAttribute("RespawnSeconds", 45)
end

root:SetAttribute("PartCount", partCount)
root:SetAttribute("NavigationStepHeight", 0.75)
root:SetAttribute("BridgeStepHeight", 0.6)
root:SetAttribute("MainPathWidth", 8.8)
root:SetAttribute("SpawnPlazaDiameter", 61)
root:SetAttribute("WaterIsDecorative", true)

return {
	created = true,
	folder = root:GetFullName(),
	parts = partCount,
	bounds = {320, 80, 304},
	floorY = 4,
	spawn = {0, 4.6, 0},
	voteZone = {center = {88, 10, -82}, size = {74, 12, 60}},
	shopZone = {center = {-107, 10, -31}, size = {34, 12, 38}},
	coinSpawns = #coinSites,
	navigation = {pathWidth = 8.8, bridgeWidth = 13.2, terraceStep = 0.75, bridgeStep = 0.6, highestFloor = 16},
}
