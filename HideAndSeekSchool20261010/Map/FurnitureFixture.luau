local result = {checks = 0, failures = {}, props = {}}
local root = Instance.new("Model")
root.Name = "SchoolFurnitureFixture"

local function check(condition, message)
	result.checks += 1
	if not condition then
		table.insert(result.failures, message)
	end
end

local function bounds(item, floorCF)
	local minimum = Vector3.new(math.huge, math.huge, math.huge)
	local maximum = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, x in ipairs({-0.5, 0.5}) do
		for _, y in ipairs({-0.5, 0.5}) do
			for _, z in ipairs({-0.5, 0.5}) do
				local point = floorCF:PointToObjectSpace(item.CFrame:PointToWorldSpace(item.Size * Vector3.new(x, y, z)))
				minimum = minimum:Min(point)
				maximum = maximum:Max(point)
			end
		end
	end
	return minimum, maximum
end

local function validate(model, floorCF, name)
	local count, seats, solids, decoration = 0, 0, 0, 0
	local minBounds = Vector3.new(math.huge, math.huge, math.huge)
	local maxBounds = Vector3.new(-math.huge, -math.huge, -math.huge)
	local errors = {}
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then
			count += 1
			if item:IsA("Seat") then seats += 1 end
			if not item.Anchored then table.insert(errors, item.Name .. " is not anchored") end
			for _, face in ipairs({"TopSurface", "BottomSurface", "LeftSurface", "RightSurface", "FrontSurface", "BackSurface"}) do
				if item[face] ~= Enum.SurfaceType.Studs then table.insert(errors, item.Name .. " lacks " .. face) end
			end
			if item:GetAttribute("PCSchoolDecorative") then
				decoration += 1
				if item.CanCollide or item.CanTouch or item.CanQuery then table.insert(errors, item.Name .. " has decorative collision/query") end
			else
				solids += 1
				if not item.CanCollide or not item.CanQuery then table.insert(errors, item.Name .. " lacks physical collision/query") end
			end
			local itemMin, itemMax = bounds(item, floorCF)
			minBounds = minBounds:Min(itemMin)
			maxBounds = maxBounds:Max(itemMax)
		end
	end
	check(#errors == 0, name .. ": " .. table.concat(errors, "; "))
	result.props[name] = {parts = count, seats = seats, solids = solids, decorative = decoration, min = tostring(minBounds), max = tostring(maxBounds)}
	return count, seats, minBounds, maxBounds
end

for _, rotation in ipairs({0, math.pi / 2}) do
	local floorCF = CFrame.new(11000, rotation == 0 and 33 or 51, 4546) * CFrame.Angles(0, rotation, 0)
	local classroom = Furniture.classroom(root, floorCF, Color3.fromRGB(135, 196, 233), rotation == 0 and 1 or 8)
	local count, seats, minimum, maximum = validate(classroom, floorCF, "Classroom" .. tostring(rotation))
	check(count <= 120, "Classroom part budget exceeded: " .. count)
	check(seats == 9, "Classroom must have eight student seats and one teacher seat")
	check(minimum.X >= -25 and maximum.X <= 25 and minimum.Z >= -19 and maximum.Z <= 19, "Classroom furniture escapes 50×38 room")
	check(minimum.Y >= -0.01 and maximum.Y < 17, "Classroom furniture breaks floor/ceiling")
	local obstructed, lockerOverlap = {}, {}
	for _, item in ipairs(classroom:GetDescendants()) do
		if item:IsA("BasePart") and item.CanCollide then
			local itemMin, itemMax = bounds(item, floorCF)
			if itemMin.Z < 4 and itemMax.Z > -4 then table.insert(obstructed, item:GetFullName()) end
			for _, x in ipairs({-20, 20}) do
				if itemMin.X < x + 2 and itemMax.X > x - 2 and itemMin.Z < 17 and itemMax.Z > 11 then
					table.insert(lockerOverlap, item:GetFullName())
				end
			end
		end
	end
	check(#obstructed == 0, "Eight-stud doorway route blocked: " .. table.concat(obstructed, "; "))
	check(#lockerOverlap == 0, "Reserved inner corner locker area obstructed: " .. table.concat(lockerOverlap, "; "))
	check(classroom.Whiteboard.BoardFace.AuthoredLabels:FindFirstChild("Lesson") ~= nil, "Editable whiteboard label missing")
end

local toiletCF = CFrame.new(10964, 33, 4597)
local toilet = Furniture.toilet(root, toiletCF, 1)
local toiletCount, _, toiletMinimum, toiletMaximum = validate(toilet, toiletCF, "Toilet")
check(toiletCount <= 70, "Toilet part budget exceeded")
check(toiletMinimum.X >= -22 and toiletMaximum.X <= 22 and toiletMinimum.Z >= -7 and toiletMaximum.Z <= 7, "Toilet furniture escapes 44×14 room")
check(toiletMinimum.Z >= -3.2, "Toilet entrance walkway blocked")
local stalls, sinks = 0, 0
for _, item in ipairs(toilet:GetChildren()) do
	if item.Name == "Toilet" then stalls += 1 end
	if item.Name == "Sink" then sinks += 1 end
end
check(stalls == 2 and sinks == 2, "Toilet must have two stalls and two sinks")

local vendingCF = CFrame.new(11000, 33, 4520)
local vending = Furniture.vending(root, vendingCF)
local vendingCount = validate(vending, vendingCF, "Vending")
check(vendingCount <= 60, "Vending part budget exceeded")
check(vending.DisplayGlass.Transparency > 0.4 and vending.DisplayGlass.CanCollide == false, "Vending window must reveal drinks without extra invisible collisions")
check(vending.Nameplate.AuthoredLabels:FindFirstChild("Name").Text == "PLAYGROUND POP", "Vending nameplate missing")

local playgroundCF = CFrame.new(11000, 33, 4457)
local playground = Furniture.playground(root, playgroundCF)
local playgroundCount, playgroundSeats, playgroundMinimum, playgroundMaximum = validate(playground, playgroundCF, "Playground")
check(playgroundCount <= 80, "Playground part budget exceeded")
check(playgroundSeats == 6, "Playground requires six sittable bench seats")
check(playgroundMinimum.X >= -40 and playgroundMaximum.X <= 40 and playgroundMinimum.Z >= -20 and playgroundMaximum.Z <= 20, "Playground props exceed compact field area")
check(playground.NorthGoal ~= nil and playground.SouthGoal ~= nil, "Two goal frames required")

root:Destroy()
result.passed = #result.failures == 0
return result
