return function(arena)
	assert(not game:GetService("RunService"):IsRunning(), "Stop Play before school geometry edits")
	arena = arena or assert(workspace:FindFirstChild("Hide and Seek"), "School island missing")
	if arena:GetAttribute("CollisionPolishVersion") == "20261010" then
		return {changed = 0, grassRegions = 4, alreadyApplied = true}
	end
	local building = arena.Geometry.PlaygroundPrimarySchool
	local structure = building.Structure
	local floor = structure.GroundFloor
	local origin = floor.CFrame * CFrame.new(0, floor.Size.Y / 2, 0)
	local island = arena.Geometry.FourthIsland
	local grass = island.StuddedGrass
	local jobs = {}
	local wallChanges, outlineChanges = 0, 0
	local function near(a, b) return (a - b).Magnitude < 0.025 end
	local function plan(item, oldSize, oldPosition, newSize, newPosition)
		assert(near(item.Size, oldSize), item.Name .. " size changed since collision audit")
		assert(near(origin:PointToObjectSpace(item.Position), oldPosition), item.Name .. " moved since collision audit")
		table.insert(jobs, {item = item, size = newSize, cf = origin * CFrame.new(newPosition)})
	end
	assert(near(floor.Size, Vector3.new(124, 1, 116)), "School floor size changed")
	assert(near(grass.Size, Vector3.new(206, 1, 202)), "Island grass size changed")
	assert(near(origin:PointToObjectSpace(grass.Position), Vector3.new(0, -0.5, -12)), "Island grass moved")
	for _, name in ipairs({"StuddedGrassEast", "StuddedGrassFront", "StuddedGrassRear"}) do
		assert(not island:FindFirstChild(name), "Grass split already exists without version marker")
	end
	plan(building.SwitchbackStaircase.MiddleLanding, Vector3.new(18, 1, 4), Vector3.new(0, 8.5, 56.5), Vector3.new(18, 1, 2.9), Vector3.new(0, 8.5, 56.05))
	plan(building.SwitchbackStaircase.UpperLandingLink, Vector3.new(7, 1, 1.1), Vector3.new(5.2, 17.5, 38.5), Vector3.new(7, 1, 1), Vector3.new(5.2, 17.5, 38.5))
	plan(building.OutsideEscapeSteps.UpperJumpLanding, Vector3.new(18, 1, 8.8), Vector3.new(70, 17.5, -21.6), Vector3.new(11, 1, 8.8), Vector3.new(74.5, 17.5, -21.6))
	local function extendTop(item, amount)
		table.insert(jobs, {item = item, size = item.Size + Vector3.new(0, amount, 0), cf = item.CFrame * CFrame.new(0, amount / 2, 0)})
	end
	for _, item in ipairs(structure:GetChildren()) do
		if item:IsA("BasePart") and (item.Name:match("Panel$") or item.Name:match("Lintel$")) then
			local top = origin:PointToObjectSpace(item.Position).Y + item.Size.Y / 2
			if math.abs(top - 16) < 0.02 then
				extendTop(item, 1)
				wallChanges += 1
			elseif math.abs(top - 34) < 0.02 then
				extendTop(item, 0.7)
				wallChanges += 1
			end
		end
	end
	assert(wallChanges == 100, "School wall structure changed since collision audit")
	for _, item in ipairs(building.Details:GetChildren()) do
		if item:IsA("BasePart") and item.Name == "BuildingCornerOutline" then
			local top = origin:PointToObjectSpace(item.Position).Y + item.Size.Y / 2
			if math.abs(top - 16) < 0.02 then extendTop(item, 1) outlineChanges += 1
			elseif math.abs(top - 34) < 0.02 then extendTop(item, 0.7) outlineChanges += 1 end
		end
	end
	assert(outlineChanges == 8, "School corner outline structure changed")
	local regions = {
		{name = "StuddedGrassEast", size = Vector3.new(41, 1, 202), position = Vector3.new(82.5, -0.5, -12), region = "East"},
		{name = "StuddedGrassFront", size = Vector3.new(124, 1, 55), position = Vector3.new(0, -0.5, -85.5), region = "Front"},
		{name = "StuddedGrassRear", size = Vector3.new(124, 1, 31), position = Vector3.new(0, -0.5, 73.5), region = "Rear"},
	}
	local prepared = {}
	for _, region in ipairs(regions) do
		local item = grass:Clone()
		item.Name = region.name
		item.Size = region.size
		item.CFrame = origin * CFrame.new(region.position)
		item:SetAttribute("SchoolGrassRegion", region.region)
		table.insert(prepared, item)
	end
	for _, job in ipairs(jobs) do
		job.item.Size = job.size
		job.item.CFrame = job.cf
		job.item:SetAttribute("CollisionPolishVersion", "20261010")
	end
	grass.Size = Vector3.new(41, 1, 202)
	grass.CFrame = origin * CFrame.new(-82.5, -0.5, -12)
	grass:SetAttribute("SchoolGrassRegion", "West")
	grass:SetAttribute("CollisionPolishVersion", "20261010")
	for _, item in ipairs(prepared) do item.Parent = island end
	arena:SetAttribute("CollisionPolishVersion", "20261010")
	return {changed = #jobs + 4, wallTops = wallChanges, cornerOutlines = outlineChanges, grassRegions = 4, alreadyApplied = false}
end
