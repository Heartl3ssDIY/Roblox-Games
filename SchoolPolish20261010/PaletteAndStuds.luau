local root = assert(workspace:FindFirstChild("Hide and Seek"))
local school = root.Geometry.PlaygroundPrimarySchool
local structure = school.Structure
local cream = Color3.fromRGB(237, 227, 206)
local ink = Color3.fromRGB(26, 30, 38)
local wood = Color3.fromRGB(170, 136, 99)
local metal = Color3.fromRGB(115, 121, 109)
local slate = Color3.fromRGB(65, 70, 69)
local brown = Color3.fromRGB(143, 109, 80)
local bookColors = {
	["244,126,129"] = Color3.fromRGB(156, 101, 87),
	["149,211,111"] = Color3.fromRGB(119, 138, 104),
	["121,165,232"] = Color3.fromRGB(109, 128, 142),
}
local function colorKey(color)
	return string.format("%d,%d,%d", math.round(color.R * 255), math.round(color.G * 255), math.round(color.B * 255))
end
local function isInk(color)
	return math.max(color.R, color.G, color.B) < 0.26
end
local painted = 0
for index, part in root:GetDescendants() do
	if part:IsA("BasePart") and part.Transparency < 1 and not part:GetAttribute("PCSchoolCladding") then
		local name = part.Name
		local oldKey = part:GetAttribute("PCOriginalColour") or colorKey(part.Color)
		part:SetAttribute("PCOriginalColour", oldKey)
		if oldKey == "19,28,49" or oldKey == "23,35,62" or isInk(part.Color) then
			part.Color = ink
		elseif name:match("^StuddedGrass") then part.Color = Color3.fromRGB(133, 165, 106)
		elseif name == "WarmEarth" then part.Color = Color3.fromRGB(133, 101, 73)
		elseif name == "CornerRock" then part.Color = Color3.fromRGB(119, 103, 86)
		elseif name:find("BlueWindow") or name == "DisplayGlass" then
			part.Color = Color3.fromRGB(183, 201, 194)
			part.Transparency = name == "DisplayGlass" and 0.6 or 0.42
		elseif name == "Mirror" then part.Color = Color3.fromRGB(193, 207, 201)
		elseif name == "CartoonBlueRoof" or name == "SlateRoof" then
			part.Name = "SlateRoof"
			part.Color = slate
		elseif name == "RoofRidge" or name == "EntranceCanopy" then part.Color = slate
		elseif part.Parent == structure and (name:find("Wall") or name:find("Class")) then part.Color = cream
		elseif name:find("Floor") or name == "EntrancePath" or name == "UpperEscapeLedge" then part.Color = Color3.fromRGB(207, 198, 176)
		elseif name:find("Step") or name == "MiddleLanding" or name == "UpperLandingLink" or name == "UpperJumpLanding" then part.Color = Color3.fromRGB(162, 156, 141)
		elseif part:IsDescendantOf(root.Gameplay.LockerSpots) then part.Color = Color3.fromRGB(143, 148, 128)
		elseif name == "BoardFace" then part.Color = Color3.fromRGB(248, 246, 234)
		elseif name == "DeskTop" or name == "ChairBack" or name == "BenchBack" or name == "BenchSeat" then part.Color = wood
		elseif name == "Leg" or name == "SideSupport" then part.Color = metal
		elseif name == "CubiclePartition" then part.Color = Color3.fromRGB(181, 181, 158)
		elseif name == "OpaqueBack" or (part.Parent.Name == "ReadingCushion" and name == "Base") then part.Color = Color3.fromRGB(138, 148, 120)
		elseif name == "LeftCabinet" or name == "RightCabinet" or name == "CabinetBack" or name == "Roof" then part.Color = Color3.fromRGB(118, 130, 112)
		elseif bookColors[oldKey] then part.Color = bookColors[oldKey]
		elseif name == "BowlInterior" or name == "BasinWater" then part.Color = Color3.fromRGB(164, 184, 175)
		elseif name:find("CeilingLight") then part.Color = Color3.fromRGB(250, 244, 221)
		elseif oldKey == "81,186,219" or oldKey == "86,194,238" then part.Color = metal
		else part.Color = cream end
		painted += 1
	end
	if index % 500 == 0 then task.wait() end
end

local cladding = structure:FindFirstChild("ExteriorBrownCladding")
if not cladding then cladding = Instance.new("Folder") cladding.Name = "ExteriorBrownCladding" cladding.Parent = structure end
for _, old in cladding:GetChildren() do old:Destroy() end
local panels = 0
for _, part in structure:GetChildren() do
	if part:IsA("BasePart") and part.Transparency == 0 then
		local direction
		if part.Name:match("^FrontWall") then direction = Vector3.new(0, 0, -1)
		elseif part.Name:match("^BackWall") then direction = Vector3.new(0, 0, 1)
		elseif part.Name:match("^OutsideWall") then direction = Vector3.new(part.Position.X < 11000 and -1 or 1, 0, 0) end
		if direction and part.Name:find("OpeningOutline") then
			local trim = part:Clone()
			trim.Name = part.Name .. "ExteriorTrim"
			trim.CFrame = part.CFrame + direction * 0.65
			trim.CanCollide = false
			trim.CanTouch = false
			trim.CanQuery = false
			trim:SetAttribute("PCSchoolCladding", true)
			trim:SetAttribute("PCSchoolDecorative", true)
			trim.Parent = cladding
		elseif direction and not isInk(part.Color) then
			panels += 1
			local panel = Instance.new("Part")
			panel.Name = part.Name .. "BrownFinish"
			panel.Size = direction.X ~= 0 and Vector3.new(0.12, part.Size.Y, part.Size.Z) or Vector3.new(part.Size.X, part.Size.Y, 0.12)
			panel.CFrame = part.CFrame + direction * 0.55
			panel.Color = brown
			panel.Anchored = true
			panel.CanCollide = false
			panel.CanTouch = false
			panel.CanQuery = false
			panel.Material = Enum.Material.SmoothPlastic
			panel:SetAttribute("PCSchoolCladding", true)
			panel:SetAttribute("PCSchoolDecorative", true)
			panel.Parent = cladding
		end
	end
end
for _, part in school.Details:GetChildren() do
	if part:IsA("BasePart") and part.Name == "BuildingCornerOutline" then
		local x = part.Position.X < 11000 and 10937.4 or 11062.6
		local z = part.Position.Z < 4546 and 4487.4 or 4604.6
		part.Position = Vector3.new(x, part.Position.Y, z)
	elseif part:IsA("BasePart") and part.Name == "ClockFrame" then
		part.Position = Vector3.new(part.Position.X, part.Position.Y, 4487.32)
	end
end

local variant = assert(game:GetService("MaterialService"):FindFirstChild("PlaygroundRetroStuds"), "World stud material is missing")
assert(variant:IsA("MaterialVariant"), "Expected a material variant")
local texturedParts, removedTextures = 0, 0
for index, part in root:GetDescendants() do
	if part:IsA("BasePart") then
		local skip = part.Transparency > 0 or isInk(part.Color) or part:FindFirstChildWhichIsA("SurfaceGui") or part.Name == "Mirror" or part.Name:find("CeilingLight")
		for _, child in part:GetChildren() do
			if child:IsA("Texture") and child:GetAttribute("PCSchoolStuds") then child:Destroy() removedTextures += 1 end
		end
		for _, surface in {"TopSurface", "BottomSurface", "FrontSurface", "BackSurface", "LeftSurface", "RightSurface"} do part[surface] = Enum.SurfaceType.Smooth end
		if not skip then
			part.Material = variant.BaseMaterial
			part.MaterialVariant = variant.Name
			texturedParts += 1
		else
			part.MaterialVariant = ""
		end
	end
	if index % 250 == 0 then task.wait() end
end
for _, node in root:GetDescendants() do
	if node:IsA("TextLabel") then
		if node.Parent.Name == "EditableLabel" then node.TextColor3 = cream
		elseif node.Parent.Parent.Name == "Nameplate" or node.Name == "Flavour" then node.TextColor3 = cream
		else node.TextColor3 = ink end
	elseif node:IsA("UIStroke") then node.Color = ink end
end
root:SetAttribute("SchoolPalette", "Cream interiors / brown exterior / slate roof")
root:SetAttribute("SchoolStudTexture", variant.ColorMap)
root:SetAttribute("SchoolStudMaterial", variant.Name)
return {painted = painted, exteriorPanels = panels, studdedParts = texturedParts, removedGridTextures = removedTextures, material = variant.Name}
