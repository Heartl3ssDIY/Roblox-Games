local result = {checks = 0, failures = {}, architecture = {}, counts = {}}
local origin = CFrame.new(11000, 33, 4546)
local fixture = Instance.new("Folder")
fixture.Name = "SchoolMapFixture20261010"
assert(not workspace:FindFirstChild(fixture.Name), "Previous school fixture remains")
fixture.Parent = workspace

local function check(condition, message)
	result.checks += 1
	if not condition then table.insert(result.failures, message) end
end

local ok, failure = pcall(function()
	local arena = BuildSchool(Furniture, fixture)
	task.wait()
	local building = arena.Geometry.PlaygroundPrimarySchool
	local gameplay = arena.Gameplay
	local shell = building.Structure
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = {arena}
	overlap.RespectCanCollide = true
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Include
	ray.FilterDescendantsInstances = {arena}
	ray.RespectCanCollide = true
	local function world(localPosition) return origin:PointToWorldSpace(localPosition) end
	local function localPosition(part) return origin:PointToObjectSpace(part.Position) end
	local function obstruction(position, size)
		local hits = workspace:GetPartBoundsInBox(CFrame.new(position), size, overlap)
		local names = {}
		for _, hit in ipairs(hits) do table.insert(names, (hit:GetFullName():gsub("Workspace.SchoolMapFixture20261010.Hide and Seek.", ""))) end
		return #hits == 0, table.concat(names, "; ")
	end
	local function avatarClear(foot, name, stepping)
		local bottom = stepping and 0.82 or 0.12
		local height = 6 - bottom
		local clear, blockers = obstruction(foot + Vector3.new(0, bottom + height / 2, 0), Vector3.new(2.2, height, 2.2))
		check(clear, name .. " obstructed for six-stud avatar: " .. blockers)
		return clear
	end
	local function support(foot, name)
		local hit = workspace:Raycast(foot + Vector3.new(0, 0.2, 0), Vector3.new(0, -1.25, 0), ray)
		check(hit ~= nil, name .. " has no continuous floor support")
	end
	local function openingFrames(name, height)
		local frames = {}
		for _, item in ipairs(shell:GetChildren()) do
			if item.Name == name .. "OpeningOutline" and math.abs(item.Size.Y - height) < 0.01 then table.insert(frames, item) end
		end
		return frames
	end
	local partCount, solidCount, decorativeCount, surfaceFaults, anchorFaults, collisionFaults = 0, 0, 0, {}, {}, {}
	for _, item in ipairs(arena:GetDescendants()) do
		if item:IsA("BasePart") then
			partCount += 1
			if not item.Anchored then table.insert(anchorFaults, item:GetFullName()) end
			for _, face in ipairs({"TopSurface", "BottomSurface", "LeftSurface", "RightSurface", "FrontSurface", "BackSurface"}) do
				if item[face] ~= Enum.SurfaceType.Studs then table.insert(surfaceFaults, item.Name .. "." .. face) end
			end
			if item.CanCollide then
				solidCount += 1
				if not item.CanQuery then table.insert(collisionFaults, item.Name .. " cannot be queried") end
			else
				decorativeCount += 1
				if item.CanQuery then table.insert(collisionFaults, item.Name .. " decorative query enabled") end
			end
		end
	end
	result.counts = {parts = partCount, solid = solidCount, decorative = decorativeCount, classrooms = #building.Classrooms:GetChildren(), toilets = #building.Toilets:GetChildren(), lockers = #gameplay.LockerSpots:GetChildren(), hiderSpawns = #gameplay.HiderSpawns:GetChildren(), seekerSpawns = #gameplay.SeekerSpawns:GetChildren()}
	check(#surfaceFaults == 0, "Missing stud faces: " .. table.concat(surfaceFaults, "; "))
	check(#anchorFaults == 0, "Unanchored parts: " .. table.concat(anchorFaults, "; "))
	check(#collisionFaults == 0, "Invalid collision/query: " .. table.concat(collisionFaults, "; "))
	check(result.counts.classrooms == 8, "Expected eight classrooms")
	check(result.counts.toilets == 2, "Expected two toilets")
	check(result.counts.lockers == 20, "Expected twenty lockers")
	check(result.counts.hiderSpawns == 16, "Expected sixteen hider spawns")
	check(result.counts.seekerSpawns >= 1, "Missing seeker spawns")
	check(arena:GetAttribute("RoundDuration") == 180 and arena:GetAttribute("MaxPlayers") == 16, "Round duration/player cap incorrect")
	for floor = 0, 1 do
		for _, z in ipairs({-51, -47, -34, -26, -17, -10, -6, 5, 12, 14, 22, 30, 34, 36}) do
			local foot = world(Vector3.new(0, floor * 18, z))
			avatarClear(foot, "Hallway floor" .. floor .. " z" .. z)
			support(foot, "Hallway floor" .. floor .. " z" .. z)
		end
		for _, side in ipairs({-1, 1}) do
			for _, z in ipairs({-17, 22}) do
				for _, x in ipairs({6, 11, 18, 28, 36}) do
					avatarClear(world(Vector3.new(side * x, floor * 18, z)), "Classroom entrance floor" .. floor .. " side" .. side .. " x" .. x .. " z" .. z)
				end
			end
			avatarClear(world(Vector3.new(side * 11, floor * 18, 50)), "Rear corridor entrance floor" .. floor .. " side" .. side)
			local divider = openingFrames("ClassDivider" .. floor .. side, 10)
			check(#divider == 2, "Divider must have one jump opening floor" .. floor .. " side" .. side)
			if #divider == 2 then
				local center = (localPosition(divider[1]) + localPosition(divider[2])) / 2
				local width = math.abs(divider[1].Position.X - divider[2].Position.X)
				check(width >= 7.9, "Divider jump opening too narrow")
				for _, zOffset in ipairs({-2.2, -1.1, 0, 1.1, 2.2}) do
					avatarClear(world(Vector3.new(center.X, floor * 18 + 2.26, center.Z + zOffset)), "Divider jump path floor" .. floor .. " side" .. side .. " offset" .. zOffset)
				end
			end
			local exteriorOpening = openingFrames("OutsideWall" .. floor .. side, 10)
			check(#exteriorOpening == 2, "Exterior must have one escape opening floor" .. floor .. " side" .. side)
			if #exteriorOpening == 2 then
				local center = (localPosition(exteriorOpening[1]) + localPosition(exteriorOpening[2])) / 2
				for _, xOffset in ipairs({-2.2, -1.1, 0, 1.1, 2.2}) do
					avatarClear(world(Vector3.new(center.X + xOffset, floor * 18 + 2.56, center.Z)), "Exterior jump path floor" .. floor .. " side" .. side .. " offset" .. xOffset)
				end
			end
		end
	end
	avatarClear(world(Vector3.new(0, 0.16, -58)), "Main entrance")
	for _, collection in ipairs({gameplay.HiderSpawns, gameplay.SeekerSpawns}) do
		for _, spawn in ipairs(collection:GetChildren()) do
			local foot = spawn.Position - Vector3.new(0, 3, 0)
			avatarClear(foot, spawn.Name .. " spawn")
			support(foot, spawn.Name .. " spawn")
		end
	end
	for _, locker in ipairs(gameplay.LockerSpots:GetChildren()) do
		check(locker.Door:FindFirstChild("LockerPrompt") ~= nil, locker.Name .. " lacks interaction prompt")
		avatarClear(locker.ExitPoint.Position - Vector3.new(0, 3, 0), locker.Name .. " exit")
		support(locker.ExitPoint.Position - Vector3.new(0, 3, 0), locker.Name .. " exit")
	end
	local stairs = building.SwitchbackStaircase
	local function verifyFlight(container, prefix, count)
		local previous
		for index = 1, count do
			local step = container:FindFirstChild(prefix .. index)
			check(step ~= nil, prefix .. index .. " missing")
			if step then
				local foot = step.Position + Vector3.new(0, step.Size.Y / 2, 0)
				avatarClear(foot, prefix .. index .. " headroom", true)
				if previous then
					local previousTop = previous.Position.Y + previous.Size.Y / 2
					local gap = math.abs(previous.Position.Z - step.Position.Z) - (previous.Size.Z + step.Size.Z) / 2
					check(math.abs(foot.Y - previousTop - 0.75) < 0.02, prefix .. index .. " riser is not 0.75 studs")
					check(gap <= 0.02, prefix .. index .. " has horizontal gap " .. gap)
				end
				previous = step
			end
		end
	end
	verifyFlight(stairs, "LowerStep", 12)
	verifyFlight(stairs, "UpperStep", 12)
	for _, x in ipairs({-5.2, -2.6, 0, 2.6, 5.2}) do
		avatarClear(world(Vector3.new(x, 9, 55.4)), "Switchback landing x" .. x, true)
		support(world(Vector3.new(x, 9, 55.4)), "Switchback landing x" .. x)
	end
	for _, z in ipairs({39.65, 39, 38.5, 38, 37.5}) do
		avatarClear(world(Vector3.new(5.2, 18, z)), "Upper stair exit z" .. z, true)
		support(world(Vector3.new(5.2, 18, z)), "Upper stair exit z" .. z)
	end
	local external = building.OutsideEscapeSteps
	verifyFlight(external, "ReturnStep", 24)
	for _, z in ipairs({-16.55, -17.2, -18, -19.5, -21}) do
		avatarClear(world(Vector3.new(76, 18, z)), "External upper landing z" .. z, true)
		support(world(Vector3.new(76, 18, z)), "External upper landing z" .. z)
	end
	for _, x in ipairs({76, 72, 68, 65.5}) do
		avatarClear(world(Vector3.new(x, 18, -18.5)), "External landing/ledge route x" .. x, true)
		support(world(Vector3.new(x, 18, -18.5)), "External landing/ledge route x" .. x)
	end
	for _, side in ipairs({-1, 1}) do
		for _, z in ipairs({-42, -30, -22, -18, -12, 0, 20, 38}) do
			avatarClear(world(Vector3.new(side * 65.5, 18, z)), "Escape ledge side" .. side .. " z" .. z, true)
			support(world(Vector3.new(side * 65.5, 18, z)), "Escape ledge side" .. side .. " z" .. z)
		end
	end
	local bounds = gameplay.ArenaBounds
	local outside = {}
	for _, item in ipairs(arena:GetDescendants()) do
		if item:IsA("BasePart") and item.CanCollide and not item:IsDescendantOf(arena.Geometry.FourthIsland) then
			local top = item.Position + Vector3.new(0, item.Size.Y / 2, 0)
			local point = bounds.CFrame:PointToObjectSpace(top)
			if math.abs(point.X) > bounds.Size.X / 2 or math.abs(point.Z) > bounds.Size.Z / 2 or point.Y > bounds.Size.Y / 2 then table.insert(outside, item:GetFullName()) end
		end
	end
	check(#outside == 0, "Playable geometry outside arena bounds: " .. table.concat(outside, "; "))
	result.architecture = {avatarHeight = 6, avatarWidth = 2.2, stairRiser = 0.75, mainStairSteps = 24, outsideStairSteps = 24, inspectedClassroomEntrances = 8, inspectedJumpOpenings = 8, nativeOverlapAndSupportQueries = true}
end)

fixture:Destroy()
if not ok then table.insert(result.failures, "Fixture runtime failure: " .. tostring(failure)) end
result.passed = #result.failures == 0
return result
