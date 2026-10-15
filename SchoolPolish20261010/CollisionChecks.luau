return function(arena)
	arena = arena or assert(workspace:FindFirstChild("Hide and Seek"), "School island missing")
	local result = {checks = 0, failures = {}, coplanarPairs = {}}
	local building = arena.Geometry.PlaygroundPrimarySchool
	local structure = building.Structure
	local floor = structure.GroundFloor
	local origin = floor.CFrame * CFrame.new(0, floor.Size.Y / 2, 0)
	local function check(condition, message)
		result.checks += 1
		if not condition then table.insert(result.failures, message) end
	end
	local function relative(item) return origin:PointToObjectSpace(item.Position) end
	local function flatOverlap(a, b)
		local pa, pb = relative(a), relative(b)
		local dx = math.min(pa.X + a.Size.X / 2, pb.X + b.Size.X / 2) - math.max(pa.X - a.Size.X / 2, pb.X - b.Size.X / 2)
		local dz = math.min(pa.Z + a.Size.Z / 2, pb.Z + b.Size.Z / 2) - math.max(pa.Z - a.Size.Z / 2, pb.Z - b.Size.Z / 2)
		local sameTop = math.abs(pa.Y + a.Size.Y / 2 - pb.Y - b.Size.Y / 2) < 0.02
		return sameTop and dx > 0.02 and dz > 0.02
	end
	check(arena:GetAttribute("CollisionPolishVersion") == "20261010", "Collision polish version missing")
	local grass = {}
	local area = 0
	for _, item in ipairs(arena.Geometry.FourthIsland:GetChildren()) do
		if item:IsA("BasePart") and item.Name:match("^StuddedGrass") then
			table.insert(grass, item)
			area += item.Size.X * item.Size.Z
			check(item.Anchored and item.CanCollide and item.CanQuery, item.Name .. " grass collision missing")
			local position = relative(item)
			check(math.abs(position.Y + item.Size.Y / 2) < 0.02, item.Name .. " grass floor height changed")
			check(not flatOverlap(item, floor), item.Name .. " overlaps school floor top")
		end
	end
	check(#grass == 4, "Expected four non-overlapping grass regions")
	check(math.abs(area + floor.Size.X * floor.Size.Z - 206 * 202) < 0.02, "Grass split lost or duplicated ground area")
	for first = 1, #grass do
		for second = first + 1, #grass do check(not flatOverlap(grass[first], grass[second]), "Grass regions overlap") end
	end
	local pairsToInspect = {
		{building.SwitchbackStaircase.MiddleLanding, building.SwitchbackStaircase.LowerStep12},
		{building.SwitchbackStaircase.UpperLandingLink, structure.UpperFloorFront},
		{building.SwitchbackStaircase.UpperLandingLink, building.SwitchbackStaircase.UpperStep12},
		{building.OutsideEscapeSteps.UpperJumpLanding, structure.UpperFloorFront},
		{building.OutsideEscapeSteps.UpperJumpLanding, building.OutsideEscapeSteps.ReturnStep24},
	}
	for _, item in ipairs(building.Details:GetChildren()) do
		if item.Name == "UpperEscapeLedge" then table.insert(pairsToInspect, {building.OutsideEscapeSteps.UpperJumpLanding, item}) end
	end
	for _, pair in ipairs(pairsToInspect) do
		local overlaps = flatOverlap(pair[1], pair[2])
		check(not overlaps, pair[1].Name .. " has coplanar overlap with " .. pair[2].Name)
		if overlaps then table.insert(result.coplanarPairs, {pair[1]:GetFullName(), pair[2]:GetFullName()}) end
	end
	local wallCount = 0
	for _, item in ipairs(structure:GetChildren()) do
		if item:IsA("BasePart") and (item.Name:match("Panel$") or item.Name:match("Lintel$")) then
			wallCount += 1
			local top = relative(item).Y + item.Size.Y / 2
			check(math.abs(top - 17) < 0.02 or math.abs(top - 34.7) < 0.02, item.Name .. " wall top leaves a floor/roof gap")
		end
	end
	check(wallCount == 100, "Wall count changed")
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {arena}
	params.RespectCanCollide = true
	local function clear(localFoot, name)
		local foot = origin:PointToWorldSpace(localFoot)
		local hits = workspace:GetPartBoundsInBox(CFrame.new(foot + Vector3.new(0, 3.41, 0)), Vector3.new(2.2, 5.18, 2.2), params)
		local blockers = {}
		for _, item in ipairs(hits) do table.insert(blockers, item:GetFullName()) end
		check(#blockers == 0, name .. " blocked: " .. table.concat(blockers, "; "))
	end
	for base = 0, 18, 18 do
		for _, side in ipairs({-1, 1}) do
			for _, z in ipairs({-17, 22}) do clear(Vector3.new(side * 11, base, z), "Classroom doorway") end
		end
		for _, point in ipairs({Vector3.new(-11, base, 50), Vector3.new(-30, base, 47), Vector3.new(-42, base, 47), Vector3.new(-52, base, 47), Vector3.new(-50, base, 51), Vector3.new(-40, base, 51)}) do clear(point, "Toilet circulation") end
	end
	for _, x in ipairs({-5.2, 0, 5.2}) do clear(Vector3.new(x, 9, 55.4), "Middle stair landing") end
	for _, z in ipairs({39.65, 39, 38.5, 38, 37.5}) do clear(Vector3.new(5.2, 18, z), "Upper stair link") end
	for _, z in ipairs({-16.55, -17.2, -18, -21}) do clear(Vector3.new(76, 18, z), "External stair landing") end
	for _, x in ipairs({76, 72, 70, 68, 65.5}) do clear(Vector3.new(x, 18, -18.5), "External landing/ledge link") end
	result.passed = #result.failures == 0
	return result
end
