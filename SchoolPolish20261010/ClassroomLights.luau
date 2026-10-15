local school = workspace["Hide and Seek"].Geometry.PlaygroundPrimarySchool
local count = 0
for _, room in school.Classrooms:GetChildren() do
	local furniture = room:FindFirstChildWhichIsA("Model")
	local desk = furniture and furniture:FindFirstChild("Table11")
	if desk then
		local fixture = room:FindFirstChild("ClassroomCeilingLight")
		if not fixture then
			fixture = Instance.new("Part")
			fixture.Name = "ClassroomCeilingLight"
			fixture.Size = Vector3.new(10, 0.25, 3)
			fixture.CFrame = desk.DeskTop.CFrame * CFrame.new(9, 13.7, 8.3)
			fixture.Anchored = true
			fixture.CanCollide = false
			fixture.CanTouch = false
			fixture.CanQuery = false
			fixture.Color = Color3.fromRGB(255, 240, 213)
			fixture.Material = Enum.Material.Neon
			fixture:SetAttribute("PCSchoolDecorative", true)
			fixture.Parent = room
		end
		local light = fixture:FindFirstChildWhichIsA("SurfaceLight") or Instance.new("SurfaceLight")
		light.Name = "WarmClassroomLight"
		light.Face = Enum.NormalId.Bottom
		light.Angle = 170
		light.Range = 36
		light.Brightness = 0.65
		light.Color = Color3.fromRGB(255, 233, 205)
		light.Shadows = false
		light.Parent = fixture
		local fill = fixture:FindFirstChild("WarmRoomFill") or Instance.new("PointLight")
		fill.Name = "WarmRoomFill"
		fill.Brightness = 2.5
		fill.Range = 38
		fill.Color = Color3.fromRGB(255, 216, 172)
		fill.Shadows = false
		fill.Parent = fixture
		count += 1
	end
end
local floor = school.Structure.GroundFloor
local origin = floor.CFrame * CFrame.new(0, floor.Size.Y / 2, 0)
for floorIndex = 0, 1 do
	for _, side in {-1, 1} do
		local name = (side < 0 and "ToiletCeilingLight" or "AlcoveCeilingLight") .. floorIndex
		local fixture = school.Details:FindFirstChild(name)
		if not fixture then
			fixture = Instance.new("Part")
			fixture.Name = name
			fixture.Size = Vector3.new(10, 0.25, 2)
			fixture.CFrame = origin * CFrame.new(side * 36, floorIndex * 18 + 16.65, 50)
			fixture.Color = Color3.fromRGB(250, 244, 221)
			fixture.Material = Enum.Material.Neon
			fixture.Anchored = true
			fixture.CanCollide = false
			fixture.CanTouch = false
			fixture.CanQuery = false
			fixture:SetAttribute("PCSchoolDecorative", true)
			fixture.Parent = school.Details
		end
		local light = fixture:FindFirstChildWhichIsA("PointLight") or Instance.new("PointLight")
		light.Name = "WarmRoomFill"
		light.Brightness = 2.5
		light.Range = 30
		light.Color = Color3.fromRGB(255, 216, 172)
		light.Shadows = false
		light.Parent = fixture
	end
end
for _, lamp in school.Details:GetChildren() do
	if lamp.Name == "CeilingLight" then
		local light = lamp:FindFirstChildWhichIsA("PointLight")
		if light then light.Brightness = 1.6 light.Color = Color3.fromRGB(255, 220, 184) end
	end
end
return {classroomLights = count}
