assert(not game:GetService("RunService"):IsRunning(), "Stop Play before editing the school")
local root = assert(workspace:FindFirstChild("Hide and Seek"))
local school = root.Geometry.PlaygroundPrimarySchool
local black = Color3.fromRGB(20, 21, 23)
local floors, lights, fixtures = 0, 0, 0
for index, part in school:GetDescendants() do
	if part:IsA("BasePart") then
		if part.Parent == school.Structure and part.Name:find("Floor") then
			part.Color = black
			part.Material = Enum.Material.SmoothPlastic
			part.MaterialVariant = "PlaygroundRetroStuds"
			part.Reflectance = 0
			part:SetAttribute("SchoolBlackFloor", true)
			floors += 1
		elseif part.Name:find("CeilingLight") then
			part.Material = Enum.Material.SmoothPlastic
			part.MaterialVariant = ""
			part.Color = Color3.fromRGB(221, 213, 196)
			fixtures += 1
		end
	elseif part:IsA("Light") then
		part.Brightness = part:IsA("SurfaceLight") and 0.25 or 0.45
		part.Range = part.Parent.Name == "CeilingLight" and 22 or 28
		part.Color = Color3.fromRGB(255, 242, 221)
		part.Shadows = false
		lights += 1
	end
	if index % 500 == 0 then task.wait() end
end
local ceilings = school.Structure:FindFirstChild("CreamCeilingLinings")
if not ceilings then ceilings = Instance.new("Folder") ceilings.Name = "CreamCeilingLinings" ceilings.Parent = school.Structure end
for _, part in ceilings:GetChildren() do part:Destroy() end
for _, floor in school.Structure:GetChildren() do
	if floor:IsA("BasePart") and (floor.Name:match("^UpperFloor") or floor.Name == "RoofNavyEdge") then
		local lining = Instance.new("Part")
		lining.Name = floor.Name .. "CreamCeiling"
		local roof = floor.Name == "RoofNavyEdge"
		lining.Size = Vector3.new(floor.Size.X - (roof and 4 or 0), 0.04, floor.Size.Z - (roof and 4 or 0))
		lining.CFrame = floor.CFrame * CFrame.new(0, -floor.Size.Y / 2 - 0.015, 0)
		lining.Color = Color3.fromRGB(237, 227, 206)
		lining.Material = Enum.Material.SmoothPlastic
		lining.MaterialVariant = "PlaygroundRetroStuds"
		lining.Anchored = true
		lining.Locked = true
		lining.CanCollide = false
		lining.CanTouch = false
		lining.CanQuery = false
		lining:SetAttribute("PCSchoolDecorative", true)
		lining.Parent = ceilings
	end
end
root:SetAttribute("SchoolFloorColour", "Black")
root:SetAttribute("SchoolLighting", "Neutral ambient; low intensity ceiling lamps")
return {blackFloorSlabs = floors, dimmedLights = lights, softenedFixtures = fixtures, creamCeilings = #ceilings:GetChildren()}
