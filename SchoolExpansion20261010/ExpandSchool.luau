return function(arena)
	assert(not game:GetService("RunService"):IsRunning(), "Stop Play before school expansion")
	arena = arena or assert(workspace:FindFirstChild("Hide and Seek"), "School island missing")
	if arena:GetAttribute("SchoolExpansionVersion") == "20261010" then
		assert(#arena.Geometry.PlaygroundPrimarySchool.Classrooms:GetChildren() == 16, "Expanded classroom count changed")
		return {alreadyApplied = true, classrooms = 16, toilets = 4}
	end
	local school = arena.Geometry.PlaygroundPrimarySchool
	local structure, details = school.Structure, school.Details
	local rooms, toilets = school.Classrooms, school.Toilets
	local gameplay = arena.Gameplay
	assert(#rooms:GetChildren() == 8 and #toilets:GetChildren() == 2, "School layout changed since expansion audit")
	local origin = structure.GroundFloor.CFrame * CFrame.new(0, structure.GroundFloor.Size.Y / 2, 0)
	local added = 0
	local function localPos(item) return origin:PointToObjectSpace(item.Position) end
	local function translate(node, delta)
		local transform = origin * CFrame.new(delta) * origin:Inverse()
		if node:IsA("BasePart") then node.CFrame = transform * node.CFrame return end
		for _, item in ipairs(node:GetDescendants()) do
			if item:IsA("BasePart") then item.CFrame = transform * item.CFrame end
		end
	end
	local function shift(node, distance) translate(node, Vector3.new(0, 0, distance)) end
	local function sizeAt(item, size, position)
		item.Size = size
		item.CFrame = origin * CFrame.new(position)
	end
	local function styledPart(template, parent, name, size, position, solid)
		local item = template:Clone()
		item.Name = name
		item.Size = size
		item.CFrame = origin * CFrame.new(position)
		item.Anchored = true
		item.CanCollide = solid
		item.CanTouch = false
		item.CanQuery = solid
		item:SetAttribute("PCSchoolExpansion", true)
		item.Parent = parent
		added += 1
		return item
	end
	local wallTemplate = assert(structure:FindFirstChild("CorridorWall01Panel")):Clone()
	local trimTemplate = assert(structure:FindFirstChild("CorridorWall01OpeningOutline")):Clone()
	local glassTemplate = assert(structure:FindFirstChild("OutsideWall01BlueWindow")):Clone()
	local exteriorTemplate = assert(structure.ExteriorBrownCladding:FindFirstChildWhichIsA("BasePart")):Clone()
	for _, child in ipairs(exteriorTemplate:GetChildren()) do if child:IsA("SurfaceGui") then child:Destroy() end end
	local wallColor = wallTemplate.Color
	local claddingColor = Color3.fromRGB(143, 109, 80)
	for _, item in ipairs(structure.ExteriorBrownCladding:GetChildren()) do
		if item:IsA("BasePart") and item.Name:match("BrownFinish$") then exteriorTemplate:Destroy() exteriorTemplate = item:Clone() claddingColor = item.Color break end
	end
	local function wall(name, axis, cross, along, length, base, height, openings)
		local cuts = {-length / 2, length / 2}
		for _, opening in ipairs(openings) do table.insert(cuts, opening.a) table.insert(cuts, opening.b) end
		table.sort(cuts)
		local function slab(a, b, bottom, tall, suffix)
			if b - a < 0.01 or tall < 0.01 then return end
			local position = axis == "X" and Vector3.new(along + (a + b) / 2, base + bottom + tall / 2, cross) or Vector3.new(cross, base + bottom + tall / 2, along + (a + b) / 2)
			local size = axis == "X" and Vector3.new(b - a, tall, 1) or Vector3.new(1, tall, b - a)
			local item = styledPart(wallTemplate, structure, name .. suffix, size, position, true)
			item.Color = wallColor
		end
		for index = 1, #cuts - 1 do
			local a, b = cuts[index], cuts[index + 1]
			local current
			for _, opening in ipairs(openings) do if (a + b) / 2 >= opening.a and (a + b) / 2 <= opening.b then current = opening break end end
			if current then
				slab(a, b, 0, current.sill or 0, "Sill")
				slab(a, b, (current.sill or 0) + current.height, height - (current.sill or 0) - current.height, "Lintel")
			else slab(a, b, 0, height, "Panel") end
		end
		for _, opening in ipairs(openings) do
			for _, edge in ipairs({opening.a, opening.b}) do
				local position = axis == "X" and Vector3.new(along + edge, base + (opening.sill or 0) + opening.height / 2, cross) or Vector3.new(cross, base + (opening.sill or 0) + opening.height / 2, along + edge)
				styledPart(trimTemplate, structure, name .. "OpeningOutline", Vector3.new(0.18, opening.height, 0.18), position, false)
			end
			for _, edge in ipairs({opening.sill or 0, (opening.sill or 0) + opening.height}) do
				local position = axis == "X" and Vector3.new(along + (opening.a + opening.b) / 2, base + edge, cross) or Vector3.new(cross, base + edge, along + (opening.a + opening.b) / 2)
				local size = axis == "X" and Vector3.new(opening.b - opening.a, 0.18, 0.18) or Vector3.new(0.18, 0.18, opening.b - opening.a)
				styledPart(trimTemplate, structure, name .. "OpeningOutline", size, position, false)
			end
			if opening.glass then
				local position = axis == "X" and Vector3.new(along + (opening.a + opening.b) / 2, base + opening.sill + opening.height / 2, cross) or Vector3.new(cross, base + opening.sill + opening.height / 2, along + (opening.a + opening.b) / 2)
				local size = axis == "X" and Vector3.new(opening.b - opening.a, opening.height, 0.15) or Vector3.new(0.15, opening.height, opening.b - opening.a)
				styledPart(glassTemplate, structure, name .. "BlueWindow", size, position, true)
			end
		end
	end
	local originals = {}
	for _, item in ipairs(rooms:GetChildren()) do originals[item:GetAttribute("ClassroomNumber")] = item end
	for number = 1, 8 do assert(originals[number], "Missing classroom template " .. number) end
	for number, room in pairs(originals) do
		local displayNumber = number <= 4 and 100 + number or 200 + number - 4
		for _, item in ipairs(room:GetDescendants()) do if item:IsA("TextLabel") and item.Name == "RoomNumber" then item.Text = "ROOM " .. displayNumber end end
	end
	local lockerTemplates = {}
	for _, item in ipairs(gameplay.LockerSpots:GetChildren()) do
		local position = localPos(item.HidePoint)
		if math.abs(position.Z - 36) < 0.05 and math.abs(math.abs(position.X) - 16) < 0.05 then
			local floorIndex = position.Y > 10 and 1 or 0
			lockerTemplates[floorIndex .. (position.X < 0 and "L" or "R")] = item
		end
	end
	assert(#gameplay.LockerSpots:GetChildren() == 20, "Locker layout changed")
	for _, key in ipairs({"0L", "0R", "1L", "1R"}) do assert(lockerTemplates[key], "Missing locker template " .. key) end
	arena:SetAttribute("SchoolOriginCFrame", origin)
	for _, name in ipairs({"Locker01", "Locker11"}) do
		local locker = assert(gameplay.LockerSpots:FindFirstChild(name))
		local position = localPos(locker.HidePoint)
		assert(math.abs(position.Z + 47) < 0.03 or math.abs(position.Z + 39) < 0.03, name .. " moved since vestibule audit")
		if math.abs(position.Z + 47) < 0.03 then shift(locker, 8) end
		locker:SetAttribute("VestibuleClearanceVersion", "20261010")
	end
	sizeAt(structure.GroundFloor, Vector3.new(124, 1, 194), Vector3.new(0, -0.5, 39))
	sizeAt(structure.UpperFloorFront, Vector3.new(124, 1, 168), Vector3.new(0, 17.5, 26))
	for _, item in ipairs(structure:GetChildren()) do
		if item.Name == "UpperFloorRear" then sizeAt(item, Vector3.new(47, 1, 26), Vector3.new(localPos(item).X < 0 and -38.5 or 38.5, 17.5, 123))
		elseif item.Name == "UpperFloorBackBridge" then sizeAt(item, Vector3.new(18.4, 1, 1.2), Vector3.new(0, 17.5, 135.4))
		elseif item.Name == "RoofNavyEdge" or item.Name == "SlateRoof" then
			item.Size += Vector3.new(0, 0, 78)
			shift(item, 39)
		elseif item:IsA("BasePart") and item.Name:match("^BackWall") then shift(item, 78)
		elseif item:IsA("BasePart") and item.Name:match("^ClassRear") then
			local position = localPos(item)
			sizeAt(item, Vector3.new(46, item.Size.Y, item.Size.Z), Vector3.new(position.X < 0 and -38 or 38, position.Y, position.Z + 78))
		end
	end
	for _, item in ipairs(details:GetChildren()) do
		if item:IsA("BasePart") then
			local position = localPos(item)
			if item.Name == "RoofRidge" or item.Name == "FloorSkirting" or item.Name == "UpperEscapeLedge" then item.Size += Vector3.new(0, 0, 78) shift(item, 39)
			elseif item.Name == "BuildingCornerOutline" and position.Z > 0 then shift(item, 78)
			elseif item.Name:match("^ToiletSign") then translate(item, Vector3.new(-4, 0, 78))
			elseif item.Name:match("^ToiletCeilingLight") or item.Name:match("^AlcoveCeilingLight") then shift(item, 78)
			elseif item.Name == "CeilingLight" and math.abs(position.Z - 44) < 0.05 then shift(item, 78) end
		end
	end
	shift(school.SwitchbackStaircase, 78)
	for _, item in ipairs(arena.Geometry.FourthIsland:GetChildren()) do
		if item:IsA("BasePart") then
			if item.Name == "StuddedGrassFront" then
			elseif item.Name == "StuddedGrassRear" then shift(item, 78)
			elseif item.Name == "CornerRock" then if localPos(item).Z > 0 then shift(item, 78) end
			else item.Size += Vector3.new(0, 0, 78) shift(item, 39) end
		end
	end
	for _, item in ipairs(arena.Grounds:GetChildren()) do
		if item:IsA("BasePart") and item.Name == "IslandBoundary" then
			if item.Size.Z > 10 then item.Size += Vector3.new(0, 0, 78) shift(item, 39)
			elseif localPos(item).Z > 0 then shift(item, 78) end
		end
	end
	gameplay.ArenaBounds.Size += Vector3.new(0, 0, 78)
	shift(gameplay.ArenaBounds, 39)
	for _, item in ipairs(structure:GetChildren()) do
		if item:IsA("BasePart") and (item.Name:match("^CorridorWall") or item.Name:match("^OutsideWall")) then item:Destroy() end
	end
	for floorIndex = 0, 1 do
		local base, height = floorIndex * 18, floorIndex == 0 and 17 or 16.7
		for _, side in ipairs({-1, 1}) do
			local doors = {}
			for _, z in ipairs({-47, -17, 22, 61, 100}) do table.insert(doors, {a = z - 4 - 25, b = z + 4 - 25, height = 9}) end
			wall("CorridorWall" .. floorIndex .. side, "Z", side * 11, 25, 166, base, height, doors)
			wall("RearCorridorWall" .. floorIndex .. side, "Z", side * 15, 122, 28, base, height, {{a = 2, b = 10, height = 9}})
			local outsideOpenings = {}
			for _, z in ipairs({-26.5, 31.5, 70.5, 109.5}) do table.insert(outsideOpenings, {a = z - 3.5 - 39, b = z + 3.5 - 39, sill = 5, height = 5, glass = true}) end
			for _, z in ipairs({-17, 61, 100}) do table.insert(outsideOpenings, {a = z - 4 - 39, b = z + 4 - 39, sill = 2.5, height = 10}) end
			wall("OutsideWall" .. floorIndex .. side, "Z", side * 62, 39, 194, base, height, outsideOpenings)
			for row = 3, 4 do
				local boundary = 2.5 + (row - 2) * 39
				wall("ClassDividerExtended" .. floorIndex .. side .. row, "X", boundary, side * 36, 50, base, height, {{a = 12, b = 20, sill = 2.2, height = 10}})
			end
			task.wait()
		end
	end
	local subjects = {[9] = "READING", [10] = "DRAMA", [11] = "DESIGN", [12] = "LANGUAGES", [13] = "ROBOTICS", [14] = "BIOLOGY", [15] = "STUDY", [16] = "SOCIAL STUDIES"}
	for floorIndex = 0, 1 do
		for row = 3, 4 do
			for _, side in ipairs({-1, 1}) do
				local sideNumber = side < 0 and 1 or 2
				local number = 9 + floorIndex * 4 + (row - 3) * 2 + sideNumber - 1
				local templateNumber = floorIndex * 4 + 2 + sideNumber
				local distance = (row - 2) * 39
				local room = originals[templateNumber]:Clone()
				room.Name = string.format("Classroom%02d_%s", number, subjects[number]:gsub(" ", ""))
				room:SetAttribute("ClassroomNumber", number)
				room:SetAttribute("ClassroomRow", row)
				shift(room, distance)
				local displayNumber = (floorIndex + 1) * 100 + (row - 1) * 2 + sideNumber
				for _, item in ipairs(room:GetDescendants()) do
					if item:IsA("Model") and item:GetAttribute("RoomNumber") then item:SetAttribute("RoomNumber", number) item.Name = string.format("Classroom%02dFurniture", number)
					elseif item:IsA("TextLabel") and item.Name == "RoomNumber" then item.Text = "ROOM " .. displayNumber end
				end
				room.Parent = rooms
				local label = assert(details:FindFirstChild("ClassroomLabel" .. templateNumber)):Clone()
				label.Name = "ClassroomLabel" .. number
				shift(label, distance)
				label.EditableLabel.Caption.Text = string.format("%d · %s", displayNumber, subjects[number])
				label.Parent = details
				local locker = lockerTemplates[floorIndex .. (side < 0 and "L" or "R")]:Clone()
				local id = #gameplay.LockerSpots:GetChildren() + 1
				locker.Name = string.format("Locker%02d", id)
				locker:SetAttribute("LockerId", id)
				shift(locker, distance)
				if row == 4 then translate(locker, Vector3.new(side * 4, 0, 0)) end
				locker.Door.LockerPrompt.ObjectText = "Locker " .. id
				locker.Parent = gameplay.LockerSpots
				task.wait()
			end
		end
	end
	local function mirrorToRight(node, oldFrame, newFrame)
		local function reflect(vector) return Vector3.new(-vector.X, vector.Y, vector.Z) end
		for _, item in ipairs(node:GetDescendants()) do
			if item:IsA("BasePart") then
				local frame = oldFrame:ToObjectSpace(item.CFrame)
				item.CFrame = newFrame * CFrame.fromMatrix(reflect(frame.Position), -reflect(frame.RightVector), reflect(frame.UpVector), -reflect(frame.LookVector))
			end
		end
	end
	for floorIndex = 0, 1 do
		local left = assert(toilets:FindFirstChild("ToiletFloor" .. (floorIndex + 1)))
		shift(left, 78)
		left:SetAttribute("Wing", "Left")
		local right = left:Clone()
		right.Name = "ToiletFloor" .. (floorIndex + 1) .. "Right"
		right:SetAttribute("Wing", "Right")
		mirrorToRight(right, origin * CFrame.new(-36, floorIndex * 18, 129), origin * CFrame.new(36, floorIndex * 18, 129))
		right.Parent = toilets
		local sign = assert(details:FindFirstChild("ToiletSign" .. floorIndex)):Clone()
		sign.Name = "ToiletSign" .. floorIndex .. "Right"
		local frame = origin:ToObjectSpace(sign.CFrame)
		local reflect = function(vector) return Vector3.new(-vector.X, vector.Y, vector.Z) end
		sign.CFrame = origin * CFrame.fromMatrix(reflect(frame.Position), -reflect(frame.RightVector), reflect(frame.UpVector), -reflect(frame.LookVector))
		sign.Parent = details
		for _, item in ipairs(details:GetChildren()) do
			if item.Name == "PlaygroundVendingMachine" and item:IsA("Model") then
				local base = item:FindFirstChild("Base")
				if base and (localPos(base).Y > 10 and 1 or 0) == floorIndex then
					local transform = origin * CFrame.new(-19, 0, -95) * origin:Inverse()
					for _, piece in ipairs(item:GetDescendants()) do if piece:IsA("BasePart") then piece.CFrame = transform * piece.CFrame end end
				end
			end
		end
		local lampTemplate
		for _, item in ipairs(details:GetChildren()) do if item.Name == "CeilingLight" and math.abs(localPos(item).Y - (floorIndex * 18 + 15.5)) < 0.05 and math.abs(localPos(item).Z - 15) < 0.05 then lampTemplate = item break end end
		if lampTemplate then for _, z in ipairs({54, 85}) do local lamp = lampTemplate:Clone() shift(lamp, z - 15) lamp.Parent = details end end
		task.wait()
	end
	local railTemplate
	for _, item in ipairs(details:GetChildren()) do if item.Name == "LedgeOuterRail" then railTemplate = item:Clone() break end end
	assert(railTemplate, "Escape ledge rail template missing")
	for _, item in ipairs(details:GetChildren()) do if item.Name == "LedgeOuterRail" then item:Destroy() end end
	for _, side in ipairs({-1, 1}) do
		for _, segment in ipairs({{-45, -21}, {-13, 57}, {65, 96}, {104, 119}}) do styledPart(railTemplate, details, "LedgeOuterRail", Vector3.new(0.4, 3.5, segment[2] - segment[1]), Vector3.new(side * 68.7, 19.75, (segment[1] + segment[2]) / 2), true) end
	end
	local spawnNumber = 0
	for floorIndex = 0, 1 do for _, side in ipairs({-1, 1}) do for _, z in ipairs({-17, 22, 61, 100}) do
		spawnNumber += 1
		local spawn = assert(gameplay.HiderSpawns:FindFirstChild(string.format("Hider%02d", spawnNumber)))
		spawn.CFrame = origin * CFrame.new(side * 36, floorIndex * 18 + 3, z)
	end end end
	local cladding = structure.ExteriorBrownCladding
	for _, item in ipairs(cladding:GetChildren()) do item:Destroy() end
	for index, item in ipairs(structure:GetChildren()) do
		if item:IsA("BasePart") and item.Transparency == 0 then
			local direction
			if item.Name:match("^FrontWall") then direction = Vector3.new(0, 0, -1)
			elseif item.Name:match("^BackWall") then direction = Vector3.new(0, 0, 1)
			elseif item.Name:match("^OutsideWall") then direction = Vector3.new(localPos(item).X < 0 and -1 or 1, 0, 0) end
			if direction then
				local facade
				if item.Name:find("OpeningOutline") then
					facade = item:Clone()
					facade.Name = item.Name .. "ExteriorTrim"
					facade.CFrame += origin:VectorToWorldSpace(direction * 0.65)
				else
					facade = exteriorTemplate:Clone()
					facade.Name = item.Name .. "BrownFinish"
					facade.Size = direction.X ~= 0 and Vector3.new(0.12, item.Size.Y, item.Size.Z) or Vector3.new(item.Size.X, item.Size.Y, 0.12)
					facade.CFrame = item.CFrame + origin:VectorToWorldSpace(direction * 0.55)
					facade.Color = claddingColor
				end
				facade.CanCollide = false facade.CanTouch = false facade.CanQuery = false
				facade:SetAttribute("PCSchoolCladding", true)
				facade:SetAttribute("PCSchoolDecorative", true)
				facade.Parent = cladding
			end
		end
		if index % 100 == 0 then task.wait() end
	end
	wallTemplate:Destroy() trimTemplate:Destroy() glassTemplate:Destroy() exteriorTemplate:Destroy() railTemplate:Destroy()
	arena:SetAttribute("ClassroomCount", 16)
	arena:SetAttribute("ToiletCount", 4)
	arena:SetAttribute("SchoolLength", 194)
	arena:SetAttribute("SchoolRearWallZ", 136)
	arena:SetAttribute("StairShaftFrontZ", 110)
	arena:SetAttribute("StairShaftRearZ", 136)
	arena:SetAttribute("SchoolExpansionVersion", "20261010")
	arena:SetAttribute("VestibuleClearanceVersion", "20261010")
	return {alreadyApplied = false, classrooms = #rooms:GetChildren(), toilets = #toilets:GetChildren(), lockers = #gameplay.LockerSpots:GetChildren(), hiderSpawns = #gameplay.HiderSpawns:GetChildren(), newParts = added, lengthAdded = 78}
end
