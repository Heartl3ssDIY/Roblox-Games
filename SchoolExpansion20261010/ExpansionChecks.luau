return function(arena)
	arena = arena or assert(workspace:FindFirstChild("Hide and Seek"), "School island missing")
	local result = {checks = 0, failures = {}, counts = {}}
	local school = arena.Geometry.PlaygroundPrimarySchool
	local origin = assert(arena:GetAttribute("SchoolOriginCFrame"), "School origin missing")
	local function check(condition, message)
		result.checks += 1
		if not condition then table.insert(result.failures, message) end
	end
	local function position(item) return origin:PointToObjectSpace(item.Position) end
	local overlaps = OverlapParams.new()
	overlaps.FilterType = Enum.RaycastFilterType.Include
	overlaps.FilterDescendantsInstances = {arena}
	overlaps.RespectCanCollide = true
	local rays = RaycastParams.new()
	rays.FilterType = Enum.RaycastFilterType.Include
	rays.FilterDescendantsInstances = {arena}
	rays.RespectCanCollide = true
	local function clear(localFoot, name, stepping, bodyWidth)
		local foot = origin:PointToWorldSpace(localFoot)
		local bottom = stepping and 0.82 or 0.12
		local height = 6 - bottom
		local size = bodyWidth or 2.2
		local hits = workspace:GetPartBoundsInBox(CFrame.new(foot + Vector3.new(0, bottom + height / 2, 0)), Vector3.new(size, height, size), overlaps)
		local names = {}
		for _, hit in ipairs(hits) do table.insert(names, hit:GetFullName()) end
		check(#hits == 0, name .. " blocked for six-stud avatar: " .. table.concat(names, "; "))
	end
	local function support(localFoot, name)
		local foot = origin:PointToWorldSpace(localFoot)
		local hit = workspace:Raycast(foot + Vector3.new(0, 0.2, 0), Vector3.new(0, -1.3, 0), rays)
		check(hit ~= nil, name .. " has no floor support")
	end
	result.counts = {classrooms = #school.Classrooms:GetChildren(), toilets = #school.Toilets:GetChildren(), lockers = #arena.Gameplay.LockerSpots:GetChildren(), hiderSpawns = #arena.Gameplay.HiderSpawns:GetChildren()}
	check(result.counts.classrooms == 16, "Expected sixteen classrooms")
	check(result.counts.toilets == 4, "Expected four toilets")
	check(result.counts.lockers == 28, "Expected twenty-eight lockers")
	check(result.counts.hiderSpawns == 16, "Expected sixteen hider spawns")
	check(arena:GetAttribute("SchoolExpansionVersion") == "20261010", "Expansion marker missing")
	check(arena:GetAttribute("HideSeconds") == 30, "Hide time must remain thirty seconds")
	local ids, floorCount = {}, {[1] = 0, [2] = 0}
	for _, room in ipairs(school.Classrooms:GetChildren()) do
		local number = room:GetAttribute("ClassroomNumber")
		check(number and not ids[number], "Duplicate/missing classroom number")
		ids[number] = true
		local floor = room:GetAttribute("Floor")
		floorCount[floor] = (floorCount[floor] or 0) + 1
		local furniture = room:FindFirstChildWhichIsA("Model")
		check(furniture ~= nil and furniture:FindFirstChild("Whiteboard") ~= nil, room.Name .. " furniture missing")
	end
	check(floorCount[1] == 8 and floorCount[2] == 8, "Each floor must have eight classrooms")
	local toiletFloorCount, toiletWings = {[1] = 0, [2] = 0}, {}
	for _, room in ipairs(school.Toilets:GetChildren()) do
		local floor = room:GetAttribute("Floor")
		toiletFloorCount[floor] = (toiletFloorCount[floor] or 0) + 1
		toiletWings[tostring(floor) .. tostring(room:GetAttribute("Wing"))] = true
	end
	check(toiletFloorCount[1] == 2 and toiletFloorCount[2] == 2, "Each floor must have two toilets")
	for _, key in ipairs({"1Left", "1Right", "2Left", "2Right"}) do check(toiletWings[key] == true, "Missing toilet wing " .. key) end
	for base = 0, 18, 18 do
		for _, side in ipairs({-1, 1}) do
			for _, z in ipairs({-47, -17, 22, 61, 100}) do
				local columns = z == -47 and {6, 11, 18} or {6, 11, 18, 28, 36}
				for _, x in ipairs(columns) do
					local foot = Vector3.new(side * x, base, z)
					clear(foot, "Room/vestibule path " .. tostring(foot))
					support(foot, "Room/vestibule path " .. tostring(foot))
				end
			end
			if side == 1 then clear(Vector3.new(24, base, -51), "Vending display approach") support(Vector3.new(24, base, -51), "Vending display approach") end
			for _, x in ipairs({5.2, 7.5, 9, 10.5, 12.1}) do
				local foot = Vector3.new(side * x, base, 109.4)
				clear(foot, "R15 hall-to-toilet cross route", false, 2.6)
				support(foot, "R15 hall-to-toilet cross route")
			end
			for _, z in ipairs({112, 116, 120, 124, 128}) do
				local foot = Vector3.new(side * 12.1, base, z)
				clear(foot, "R15 toilet side aisle", false, 2.6)
				support(foot, "R15 toilet side aisle")
			end
			for _, x in ipairs({12.1, 15, 18, 24, 30}) do clear(Vector3.new(side * x, base, 128), "Toilet entrance", false, 2.6) end
			for _, x in ipairs({30, 42, 52}) do clear(Vector3.new(side * x, base, 125), "Toilet front aisle") end
			for _, x in ipairs({40, 50}) do clear(Vector3.new(side * x, base, 129), "Toilet cubicle access") end
			for _, z in ipairs({2.5, 41.5, 80.5}) do
				for _, offset in ipairs({-2.2, -1.1, 0, 1.1, 2.2}) do clear(Vector3.new(side * 36 + 16, base + 2.26, z + offset), "Divider escape path") end
			end
			for _, z in ipairs({-17, 61, 100}) do
				for _, offset in ipairs({-2.2, -1.1, 0, 1.1, 2.2}) do clear(Vector3.new(side * 62 + offset, base + 2.56, z), "Exterior escape path") end
			end
		end
		for _, z in ipairs({-51, -47, -17, 22, 40, 61, 80, 100, 106, 109}) do clear(Vector3.new(0, base, z), "Main corridor") support(Vector3.new(0, base, z), "Main corridor") end
	end
	for _, locker in ipairs(arena.Gameplay.LockerSpots:GetChildren()) do
		check(locker.Door:FindFirstChild("LockerPrompt") ~= nil, locker.Name .. " prompt missing")
		local exit = position(locker.ExitPoint) - Vector3.new(0, 3, 0)
		clear(exit, locker.Name .. " exit")
		support(exit, locker.Name .. " exit")
	end
	local farSpawns = 0
	for _, spawn in ipairs(arena.Gameplay.HiderSpawns:GetChildren()) do
		local foot = position(spawn) - Vector3.new(0, 3, 0)
		clear(foot, spawn.Name .. " spawn")
		support(foot, spawn.Name .. " spawn")
		if foot.Z > 40 then farSpawns += 1 end
	end
	check(farSpawns == 8, "Spawns must cover both newly added classroom rows")
	local floors = school.Structure
	check(math.abs(floors.GroundFloor.Size.Z - 194) < 0.02 and math.abs(position(floors.GroundFloor).Z - 39) < 0.02, "Ground floor expansion wrong")
	check(math.abs(position(floors.UpperFloorFront).Z + floors.UpperFloorFront.Size.Z / 2 - 110) < 0.02, "Upper central floor must stop at stair shaft110")
	check(math.abs(floors.UpperFloorBackBridge.Size.X - 18.4) < 0.02, "Rear bridge must touch side paths without overlap")
	local bounds = arena.Gameplay.ArenaBounds
	check(math.abs(bounds.Size.Z - 282) < 0.02 and math.abs(position(bounds).Z - 27) < 0.02, "Island bounds expansion wrong")
	local grassArea = 0
	for _, item in ipairs(arena.Geometry.FourthIsland:GetChildren()) do if item:IsA("BasePart") and item.Name:match("^StuddedGrass") then grassArea += item.Size.X * item.Size.Z end end
	check(math.abs(grassArea + 124 * 194 - 206 * 280) < 0.05, "Island grass/floor coverage contains a gap or duplicate")
	for _, side in ipairs({-1, 1}) do
		for _, z in ipairs({-42, -18, 0, 40, 61, 80, 100, 115}) do clear(Vector3.new(side * 65.5, 18, z), "Extended escape ledge", true) support(Vector3.new(side * 65.5, 18, z), "Extended escape ledge") end
	end
	local vendingCount = 0
	for _, item in ipairs(school.Details:GetChildren()) do if item.Name == "PlaygroundVendingMachine" then
		vendingCount += 1
		local base = position(item.Base)
		check(math.abs(base.X - 24) < 0.05 and math.abs(base.Z + 47) < 0.05, "Vending machine not moved to accessible vestibule")
	end end
	check(vendingCount == 2, "Expected two vending machines")
	local claddingCount = 0
	for _, item in ipairs(floors.ExteriorBrownCladding:GetChildren()) do if item:IsA("BasePart") then
		claddingCount += 1
		check(not item.CanCollide and not item.CanQuery, "Exterior cladding must remain decorative")
	end end
	check(claddingCount > 100, "Expanded exterior cladding missing")
	result.passed = #result.failures == 0
	return result
end
