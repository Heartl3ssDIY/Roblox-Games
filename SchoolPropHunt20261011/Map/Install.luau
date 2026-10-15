assert(not game:GetService("RunService"):IsRunning(), "Stop Play before school expansion")
local arena = assert(workspace:FindFirstChild("Hide and Seek"), "School arena missing")
assert(arena:GetAttribute("SchoolExpansionVersion") == "20261010", "School has changed or expansion was already installed")
assert(math.abs(arena.Geometry.PlaygroundPrimarySchool.Structure.GroundFloor.Size.Z - 194) < 0.02, "School length changed since audit")
local storage = game:GetService("ServerStorage")
local backupRoot = storage:FindFirstChild("SchoolPropHuntBackup20261011")
if not backupRoot then backupRoot = Instance.new("Folder") backupRoot.Name = "SchoolPropHuntBackup20261011" backupRoot.Parent = storage end
assert(not backupRoot:FindFirstChild("MapBefore"), "Map backup already exists; inspect it before retrying")
local backup = arena:Clone()
backup.Name = "MapBefore"
for _, node in ipairs(backup:GetDescendants()) do if node:IsA("BaseScript") then node.Enabled = false end end
local function attach(node, parent)
    if #node:GetDescendants() > 500 then
        local children = node:GetChildren()
        for _, child in ipairs(children) do child.Parent = nil end
        node.Parent = parent
        for _, child in ipairs(children) do attach(child, node) end
    else node.Parent = parent task.wait() end
end
attach(backup, backupRoot)
backup:SetAttribute("BackupOriginalPath", "Workspace.Hide and Seek")
local build = (function()
return function(arena)
	assert(not game:GetService("RunService"):IsRunning(), "Stop Play before expanding the school")
	arena = arena or assert(workspace:FindFirstChild("Hide and Seek"))
	local school = arena.Geometry.PlaygroundPrimarySchool
	local structure, details, gameplay = school.Structure, school.Details, arena.Gameplay
	local origin = assert(arena:GetAttribute("SchoolOriginCFrame"))
	local originals = {}
	for _, node in ipairs(school:GetDescendants()) do
		if node:IsA("Model") and node:GetAttribute("ClassroomNumber") then originals[node:GetAttribute("ClassroomNumber")] = node end
	end
	if arena:GetAttribute("SchoolExpansionVersion") == "20261011-32rooms" then
		assert(originals[32], "Expansion marker exists but rooms are missing")
		return {alreadyApplied = true, classrooms = 32}
	end
	for i = 1, 16 do assert(originals[i], "Missing classroom " .. i) end
	assert(not originals[17], "Classrooms changed since audit")
	assert(math.abs(structure.GroundFloor.Size.Z - 194) < 0.02, "School length changed since audit")
	assert(#school.Toilets:GetChildren() == 4, "Toilets changed since audit")
	local stair = assert(school:FindFirstChild("SwitchbackStaircase"))
	local stairBefore = {}
	for _, p in ipairs(stair:GetDescendants()) do if p:IsA("BasePart") then stairBefore[p] = {p.CFrame, p.Size, p.CanCollide} end end
	local function localPos(p) return origin:PointToObjectSpace(p.Position) end
	local function shift(node, distance)
		local delta = origin:VectorToWorldSpace(Vector3.new(0, 0, distance))
		if node:IsA("BasePart") then node.CFrame += delta else
			for _, p in ipairs(node:GetDescendants()) do if p:IsA("BasePart") then p.CFrame += delta end end
		end
	end
	local function extend(p)
		p.Size += Vector3.new(0, 0, 156)
		shift(p, -78)
	end
	local wallTemplate = assert(structure:FindFirstChild("CorridorWall01Panel")):Clone()
	local trimTemplate = assert(structure:FindFirstChild("CorridorWall01OpeningOutline")):Clone()
	local glassTemplate = assert(structure:FindFirstChild("OutsideWall01BlueWindow")):Clone()
	local exteriorTemplate
	for _, p in ipairs(structure.ExteriorBrownCladding:GetChildren()) do
		if p:IsA("BasePart") and p.Name:match("BrownFinish$") then exteriorTemplate = p:Clone() break end
	end
	assert(exteriorTemplate, "Brown facade template missing")
	local function part(template, parent, name, size, position, solid)
		local p = template:Clone()
		p.Name, p.Size, p.CFrame = name, size, origin * CFrame.new(position)
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, solid, false, solid
		p:SetAttribute("PCSchoolExpansion", true)
		p.Parent = parent
		return p
	end
	local function wall(name, axis, cross, along, length, base, height, openings)
		local cuts = {-length / 2, length / 2}
		for _, v in ipairs(openings) do table.insert(cuts, v.a) table.insert(cuts, v.b) end
		table.sort(cuts)
		local function pos(a, b, y) return axis == "X" and Vector3.new(along + (a + b) / 2, y, cross) or Vector3.new(cross, y, along + (a + b) / 2) end
		local function slab(a, b, bottom, tall, suffix)
			if b - a < 0.01 or tall < 0.01 then return end
			local size = axis == "X" and Vector3.new(b - a, tall, 1) or Vector3.new(1, tall, b - a)
			part(wallTemplate, structure, name .. suffix, size, pos(a, b, base + bottom + tall / 2), true)
		end
		for i = 1, #cuts - 1 do
			local a, b, cut = cuts[i], cuts[i + 1], nil
			for _, v in ipairs(openings) do if (a + b) / 2 >= v.a and (a + b) / 2 <= v.b then cut = v break end end
			if cut then slab(a, b, 0, cut.sill or 0, "Sill") slab(a, b, (cut.sill or 0) + cut.height, height - (cut.sill or 0) - cut.height, "Lintel")
			else slab(a, b, 0, height, "Panel") end
		end
		for _, v in ipairs(openings) do
			for _, edge in ipairs({v.a, v.b}) do part(trimTemplate, structure, name .. "OpeningOutline", Vector3.new(0.18, v.height, 0.18), pos(edge, edge, base + (v.sill or 0) + v.height / 2), false) end
			for _, edge in ipairs({v.sill or 0, (v.sill or 0) + v.height}) do
				part(trimTemplate, structure, name .. "OpeningOutline", axis == "X" and Vector3.new(v.b - v.a, 0.18, 0.18) or Vector3.new(0.18, 0.18, v.b - v.a), pos(v.a, v.b, base + edge), false)
			end
			if v.glass then part(glassTemplate, structure, name .. "BlueWindow", axis == "X" and Vector3.new(v.b - v.a, v.height, 0.15) or Vector3.new(0.15, v.height, v.b - v.a), pos(v.a, v.b, base + v.sill + v.height / 2), true) end
		end
	end
	for _, p in ipairs(structure:GetChildren()) do
		if p:IsA("BasePart") then
			if p.Name == "GroundFloor" or p.Name == "UpperFloorFront" or p.Name == "RoofNavyEdge" or p.Name == "SlateRoof" then extend(p)
			elseif p.Name:match("^FrontWall") or p.Name:match("^ClassFront") then shift(p, -156)
			elseif p.Name:match("^CorridorWall") or p.Name:match("^OutsideWall") then p:Destroy() end
		end
	end
	for _, p in ipairs(structure.CreamCeilingLinings:GetChildren()) do if p.Name == "UpperFloorFrontCreamCeiling" or p.Name == "RoofNavyEdgeCreamCeiling" then extend(p) end end
	for _, p in ipairs(details:GetChildren()) do
		if p:IsA("BasePart") then
			if p.Name == "RoofRidge" or p.Name == "FloorSkirting" or p.Name == "UpperEscapeLedge" then extend(p)
			elseif (p.Name == "BuildingCornerOutline" and localPos(p).Z < 0) or p.Name:match("^Clock") or p.Name == "SchoolClock" or p.Name == "SchoolName" or p.Name == "CanopyPillar" or p.Name == "EntranceCanopy" then shift(p, -156)
			elseif p.Name == "CeilingLight" and localPos(p).Z < -40 then shift(p, -156) end
		elseif p.Name == "PlaygroundVendingMachine" then shift(p, -156) end
	end
	for _, locker in ipairs(gameplay.LockerSpots:GetChildren()) do
		if math.abs(localPos(locker.HidePoint).X) < 10 and localPos(locker.HidePoint).Z < -30 then shift(locker, -156) end
	end
	for _, p in ipairs(arena.Geometry.FourthIsland:GetChildren()) do
		if p:IsA("BasePart") then
			if p.Name == "StuddedGrassFront" then shift(p, -156)
			elseif p.Name == "StuddedGrassRear" then
			elseif p.Name == "CornerRock" then if localPos(p).Z < 0 then shift(p, -156) end
			else extend(p) end
		end
	end
	for _, p in ipairs(arena.Grounds:GetChildren()) do
		if p:IsA("BasePart") and p.Name == "IslandBoundary" then
			if p.Size.Z > 10 then extend(p) elseif localPos(p).Z < 0 then shift(p, -156) end
		else shift(p, -156) end
	end
	extend(gameplay.ArenaBounds)
	shift(gameplay.SeekerSpawns, -156)
	shift(gameplay.SchoolBellEmitter, -78)
	local doors = {-203, -173, -134, -95, -56, -17, 22, 61, 100}
	for floor = 0, 1 do
		for _, side in ipairs({-1, 1}) do
			local base, height = floor * 18, floor == 0 and 17 or 16.7
			local openings = {}
			for _, z in ipairs(doors) do table.insert(openings, {a = z - 4 + 53, b = z + 4 + 53, height = 9}) end
			wall("CorridorWall" .. floor .. side, "Z", side * 11, -53, 322, base, height, openings)
			local outside = {}
			for _, z in ipairs({-182.5, -143.5, -104.5, -65.5, -26.5, 31.5, 70.5, 109.5}) do table.insert(outside, {a = z - 3.5 + 39, b = z + 3.5 + 39, sill = 5, height = 5, glass = true}) end
			for _, z in ipairs({-173, -134, -95, -56, -17, 61, 100}) do table.insert(outside, {a = z - 4 + 39, b = z + 4 + 39, sill = 2.5, height = 10}) end
			wall("OutsideWall" .. floor .. side, "Z", side * 62, -39, 350, base, height, outside)
			for row = 1, 4 do wall("ClassDividerFrontExpansion" .. floor .. side .. row, "X", -36 - (row - 1) * 39, side * 36, 50, base, height, {{a = 12, b = 20, sill = 2.2, height = 10}}) end
			task.wait()
		end
	end
	local roomCenters = {-173, -134, -95, -56, -17, 22, 61, 100}
	for number, room in pairs(originals) do
		local label = details:FindFirstChild("ClassroomLabel" .. number)
		local position = label and localPos(label)
		if position then room:SetAttribute("Wing", position.X < 0 and "Left" or "Right") room:SetAttribute("RoomCenter", Vector3.new(position.X < 0 and -36 or 36, (room:GetAttribute("Floor") - 1) * 18, position.Z)) end
	end
	local subjects = {"CREATIVE ARTS", "NATURE", "READING", "TECHNOLOGY", "DESIGN", "LANGUAGES", "STUDY", "SCIENCE"}
	local lockerTemplates = {}
	for _, locker in ipairs(gameplay.LockerSpots:GetChildren()) do
		local p = localPos(locker.HidePoint)
		if math.abs(p.Z + 3) < 0.1 and math.abs(math.abs(p.X) - 16) < 0.1 then lockerTemplates[(p.Y > 10 and "1" or "0") .. (p.X < 0 and "L" or "R")] = locker end
	end
	for floor = 0, 1 do
		for row = 1, 4 do
			for _, side in ipairs({-1, 1}) do
				local sideIndex = side < 0 and 1 or 2
				local number = 17 + floor * 8 + (row - 1) * 2 + sideIndex - 1
				local templateNumber = floor * 4 + sideIndex
				local offset = -39 * row
				local room = originals[templateNumber]:Clone()
				room.Name = string.format("Classroom%02d_%s", number, subjects[(row - 1) * 2 + sideIndex]:gsub(" ", ""))
				room:SetAttribute("ClassroomNumber", number)
				room:SetAttribute("ClassroomRow", 5 - row)
				room:SetAttribute("Floor", floor + 1)
				room:SetAttribute("Wing", side < 0 and "Left" or "Right")
				room:SetAttribute("RoomCenter", Vector3.new(side * 36, floor * 18, -17 + offset))
				shift(room, offset)
				local display = (floor + 1) * 100 + 8 + (row - 1) * 2 + sideIndex
				for _, p in ipairs(room:GetDescendants()) do
					if p:IsA("Model") and p:GetAttribute("RoomNumber") then p:SetAttribute("RoomNumber", number) p.Name = string.format("Classroom%02dFurniture", number)
					elseif p:IsA("TextLabel") and p.Name == "RoomNumber" then p.Text = "ROOM " .. display end
				end
				room.Parent = school
				local label = assert(details:FindFirstChild("ClassroomLabel" .. templateNumber)):Clone()
				label.Name = "ClassroomLabel" .. number
				shift(label, offset)
				label.EditableLabel.Caption.Text = string.format("%d · %s", display, subjects[(row - 1) * 2 + sideIndex])
				label.EditableLabel.Caption.TextWrapped = true
				label.EditableLabel.Caption.TextScaled = true
				label.Parent = details
				local locker = assert(lockerTemplates[tostring(floor) .. (side < 0 and "L" or "R")]):Clone()
				local id = #gameplay.LockerSpots:GetChildren() + 1
				locker.Name = string.format("Locker%02d", id)
				locker:SetAttribute("LockerId", id)
				shift(locker, offset)
				locker.Door.LockerPrompt.ObjectText = "Locker " .. id
				locker.Parent = gameplay.LockerSpots
				task.wait()
			end
		end
		local lightTemplate
		for _, p in ipairs(details:GetChildren()) do if p.Name == "CeilingLight" and math.abs(localPos(p).Z + 16) < 0.1 and math.abs(localPos(p).Y - (floor * 18 + 15.5)) < 1 then lightTemplate = p break end end
		assert(lightTemplate, "Corridor lamp missing")
		for row = 1, 4 do local lamp = lightTemplate:Clone() shift(lamp, -39 * row) lamp.Parent = details end
	end
	local railTemplate = assert(details:FindFirstChild("LedgeOuterRail"))
	for _, side in ipairs({-1, 1}) do
		for _, segment in ipairs({{-201, -177}, {-169, -138}, {-130, -99}, {-91, -60}, {-52, -45}}) do part(railTemplate, details, "LedgeOuterRail", Vector3.new(0.4, 3.5, segment[2] - segment[1]), Vector3.new(side * 68.7, 19.75, (segment[1] + segment[2]) / 2), true) end
	end
	local spawnIndex = 0
	for floor = 0, 1 do for _, side in ipairs({-1, 1}) do for _, row in ipairs({1, 3, 5, 7}) do
		spawnIndex += 1
		local marker = assert(gameplay.HiderSpawns:FindFirstChild(string.format("Hider%02d", spawnIndex)))
		marker.CFrame = origin * CFrame.new(side * 36, floor * 18 + 3, roomCenters[row])
	end end end
	local cladding = structure.ExteriorBrownCladding
	for _, p in ipairs(cladding:GetChildren()) do p:Destroy() end
	for index, p in ipairs(structure:GetChildren()) do
		if p:IsA("BasePart") and p.Transparency == 0 then
			local direction
			if p.Name:match("^FrontWall") then direction = Vector3.new(0, 0, -1)
			elseif p.Name:match("^BackWall") then direction = Vector3.new(0, 0, 1)
			elseif p.Name:match("^OutsideWall") then direction = Vector3.new(localPos(p).X < 0 and -1 or 1, 0, 0) end
			if direction then
				local facade
				if p.Name:find("OpeningOutline") then facade = p:Clone() facade.Name = p.Name .. "ExteriorTrim" facade.CFrame += origin:VectorToWorldSpace(direction * 0.65)
				else facade = exteriorTemplate:Clone() facade.Name = p.Name .. "BrownFinish" facade.Size = direction.X ~= 0 and Vector3.new(0.12, p.Size.Y, p.Size.Z) or Vector3.new(p.Size.X, p.Size.Y, 0.12) facade.CFrame = p.CFrame + origin:VectorToWorldSpace(direction * 0.55) end
				facade.CanCollide, facade.CanTouch, facade.CanQuery = false, false, false
				facade:SetAttribute("PCSchoolCladding", true)
				facade:SetAttribute("PCSchoolDecorative", true)
				facade.Parent = cladding
			end
		end
		if index % 150 == 0 then task.wait() end
	end
	for p, before in pairs(stairBefore) do assert(p.Parent and p.CFrame == before[1] and p.Size == before[2] and p.CanCollide == before[3], "Staircase was changed") end
	wallTemplate:Destroy() trimTemplate:Destroy() glassTemplate:Destroy() exteriorTemplate:Destroy()
	arena:SetAttribute("ClassroomCount", 32)
	arena:SetAttribute("SchoolLength", 350)
	arena:SetAttribute("SchoolFrontWallZ", -214)
	arena:SetAttribute("SchoolRearWallZ", 136)
	arena:SetAttribute("SchoolExpansionVersion", "20261011-32rooms")
	return {alreadyApplied = false, classrooms = 32, toilets = #school.Toilets:GetChildren(), lockers = #gameplay.LockerSpots:GetChildren(), schoolLength = 350, stairUnchanged = true}
end

end)()
local changes = build(arena)
local checks = (function()
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

end)()(arena)
arena:SetAttribute("SchoolExpansionChecksPassed", checks.passed)
assert(checks.passed, "School expansion collision checks failed: " .. table.concat(checks.failures, "; "))
return game:GetService("HttpService"):JSONEncode({changes = changes, checks = checks, backup = backup:GetFullName()})
