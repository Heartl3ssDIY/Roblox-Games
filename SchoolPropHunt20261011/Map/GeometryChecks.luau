return function(arena)
	local school, gameplay = arena.Geometry.PlaygroundPrimarySchool, arena.Gameplay
	local origin = arena:GetAttribute("SchoolOriginCFrame")
	local result = {checks = 0, failures = {}, rooms = 0, floors = {0, 0}}
	local function check(ok, message) result.checks += 1 if not ok then table.insert(result.failures, message) end end
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = {arena}
	overlap.RespectCanCollide = true
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Include
	ray.FilterDescendantsInstances = {arena}
	ray.RespectCanCollide = true
	local function path(foot, name, raised, width)
		local bottom = raised and 0.83 or 0.12
		local base = origin:PointToWorldSpace(foot)
		local hits = workspace:GetPartBoundsInBox(origin * CFrame.new(foot + Vector3.new(0, (bottom + 6) / 2, 0)), Vector3.new(width or 2.2, 6 - bottom, width or 2.2), overlap)
		local names = {}
		for _, hit in ipairs(hits) do table.insert(names, hit.Name) end
		check(#hits == 0, name .. " blocked: " .. table.concat(names, ","))
		if not raised then check(workspace:Raycast(base + Vector3.new(0, 0.2, 0), Vector3.new(0, -1.3, 0), ray) ~= nil, name .. " unsupported") end
	end
	local numbers = {}
	for _, room in ipairs(school:GetDescendants()) do
		if room:IsA("Model") and room:GetAttribute("ClassroomNumber") then
			result.rooms += 1
			local id, floor = room:GetAttribute("ClassroomNumber"), room:GetAttribute("Floor")
			check(not numbers[id], "Duplicate classroom ID") numbers[id] = true
			result.floors[floor] += 1
			check(room:GetAttribute("RoomCenter") ~= nil, room.Name .. " lacks room center")
			local furniture = room:FindFirstChildWhichIsA("Model")
			check(furniture and furniture:FindFirstChild("Whiteboard") ~= nil, room.Name .. " furniture template missing")
		end
	end
	check(result.rooms == 32, "Expected32 classrooms")
	check(result.floors[1] == 16 and result.floors[2] == 16, "Expected16 classrooms per floor")
	check(#school.Toilets:GetChildren() == 4, "Toilet count changed")
	check(#gameplay.LockerSpots:GetChildren() == 44, "Expected44 original/new lockers")
	check(#gameplay.HiderSpawns:GetChildren() == 16, "Expected16 hider spawns")
	check(arena:GetAttribute("SchoolLength") == 350, "School length must be350")
	local s = school.Structure
	local function z(p) return origin:PointToObjectSpace(p.Position).Z end
	check(math.abs(z(s.GroundFloor) - s.GroundFloor.Size.Z / 2 + 214) < 0.02, "Newfront floor boundary wrong")
	check(math.abs(z(s.GroundFloor) + s.GroundFloor.Size.Z / 2 - 136) < 0.02, "Rear floor boundary moved")
	check(math.abs(z(s.UpperFloorFront) + s.UpperFloorFront.Size.Z / 2 - 110) < 0.02, "Upper floor entered stair shaft")
	check(math.abs(s.GroundFloor.Size.Z - 350) < 0.02, "Ground floor size wrong")
	check(math.abs(s.UpperFloorFront.Size.Z - 324) < 0.02, "Upper floor size wrong")
	check(math.abs(s.RoofNavyEdge.Size.Z - 354) < 0.02, "Roof size wrong")
	check(s.GroundFloor.Color.R < 0.2 and s.UpperFloorFront.Color.R < 0.2, "Floor must remainblack")
	local area = 0
	for _, p in ipairs(arena.Geometry.FourthIsland:GetChildren()) do if p:IsA("BasePart") and p.Name:match("^StuddedGrass") then area += p.Size.X * p.Size.Z end end
	check(math.abs(area + 124 * 350 - 206 * 436) < 0.05, "Floor/grasscoverage gap or overlap")
	for base = 0, 18, 18 do
		for _, side in ipairs({-1, 1}) do
			for _, center in ipairs({-173, -134, -95, -56, -17, 22, 61, 100}) do
				for _, x in ipairs({6, 11, 18, 28, 36}) do path(Vector3.new(side * x, base, center), "Room doorway " .. side .. "/" .. base .. "/" .. center .. "/" .. x) end
			end
			for _, x in ipairs({6, 11, 18}) do path(Vector3.new(side * x, base, -203), "Front vestibule " .. side .. "/" .. base .. "/" .. x) end
			for _, z0 in ipairs({-153, -114, -75, -36, 2.5, 41.5, 80.5}) do
				for _, offset in ipairs({-2.2, 0, 2.2}) do path(Vector3.new(side * 36 + 16, base + 2.26, z0 + offset), "Roomjump " .. base .. "/" .. side .. "/" .. z0, true) end
			end
			for _, z0 in ipairs({-173, -134, -95, -56, -17, 61, 100}) do
				for _, offset in ipairs({-2.2, 0, 2.2}) do path(Vector3.new(side * 62 + offset, base + 2.56, z0), "Windowjump " .. base .. "/" .. side .. "/" .. z0, true) end
			end
			for _, x in ipairs({5.2, 7.5, 9, 10.5, 12.1}) do path(Vector3.new(side * x, base, 109.4), "Unchanged stair approach", false, 2.6) end
			for _, z0 in ipairs({112, 116, 120, 124, 128}) do path(Vector3.new(side * 12.1, base, z0), "Unchangedtoilet aisle", false, 2.6) end
		end
		for z0 = -209, 107, 4 do path(Vector3.new(0, base, z0), "Main corridor " .. base .. "/" .. z0) end
	end
	for _, side in ipairs({-1, 1}) do for _, z0 in ipairs({-198, -180, -173, -155, -134, -120, -95, -75, -56, -42, 0, 40, 80, 115}) do path(Vector3.new(side * 65.5, 18, z0), "Exterior ledge " .. side .. "/" .. z0, true) end end
	for _, locker in ipairs(gameplay.LockerSpots:GetChildren()) do path(origin:PointToObjectSpace(locker.ExitPoint.Position) - Vector3.new(0, 3, 0), locker.Name .. " exit") end
	for _, spawn in ipairs(gameplay.HiderSpawns:GetChildren()) do path(origin:PointToObjectSpace(spawn.Position) - Vector3.new(0, 3, 0), spawn.Name) end
	for _, spawn in ipairs(gameplay.SeekerSpawns:GetChildren()) do path(origin:PointToObjectSpace(spawn.Position) - Vector3.new(0, 3, 0), spawn.Name) end
	for z0 = -231, -204, 3 do path(Vector3.new(0, 0.16, z0), "Entrance " .. z0) end
	result.passed = #result.failures == 0
	return result
end
