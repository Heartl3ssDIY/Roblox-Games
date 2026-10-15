local Furniture = {}
local navy = Color3.fromRGB(19, 28, 49)
local cream = Color3.fromRGB(255, 246, 208)
local blue = Color3.fromRGB(81, 186, 219)
local yellow = Color3.fromRGB(248, 207, 81)
local white = Color3.fromRGB(247, 250, 241)
local drinks = {
	Color3.fromRGB(244, 126, 129),
	Color3.fromRGB(149, 211, 111),
	Color3.fromRGB(121, 165, 232),
}

local function model(parent, name)
	local result = Instance.new("Model")
	result.Name = name
	result:SetAttribute("PCSchoolFurniture", true)
	result.Parent = parent
	return result
end

local function part(parent, name, size, cf, color, solid, className)
	local result = Instance.new(className or "Part")
	result.Name = name
	result.Size = size
	result.CFrame = cf
	result.Color = color
	result.Material = Enum.Material.SmoothPlastic
	result.Anchored = true
	result.CanCollide = solid ~= false
	result.CanTouch = solid ~= false
	result.CanQuery = solid ~= false
	result.CastShadow = solid ~= false
	result.TopSurface = Enum.SurfaceType.Studs
	result.BottomSurface = Enum.SurfaceType.Studs
	result.FrontSurface = Enum.SurfaceType.Studs
	result.BackSurface = Enum.SurfaceType.Studs
	result.LeftSurface = Enum.SurfaceType.Studs
	result.RightSurface = Enum.SurfaceType.Studs
	if solid == false then
		result:SetAttribute("PCSchoolDecorative", true)
	end
	result.Parent = parent
	if parent:IsA("Model") and not parent.PrimaryPart and solid ~= false then
		parent.PrimaryPart = result
	end
	return result
end

local function block(parent, name, size, cf, xyz, color, solid)
	return part(parent, name, size, cf * CFrame.new(xyz), color, solid)
end

local function topRim(parent, cf, width, depth, y, color)
	local thickness = 0.13
	block(parent, "FrontEdge", Vector3.new(width, thickness, thickness), cf, Vector3.new(0, y, -depth / 2 + thickness / 2), color, false)
	block(parent, "BackEdge", Vector3.new(width, thickness, thickness), cf, Vector3.new(0, y, depth / 2 - thickness / 2), color, false)
	block(parent, "LeftEdge", Vector3.new(thickness, thickness, depth - thickness * 2), cf, Vector3.new(-width / 2 + thickness / 2, y, 0), color, false)
	block(parent, "RightEdge", Vector3.new(thickness, thickness, depth - thickness * 2), cf, Vector3.new(width / 2 - thickness / 2, y, 0), color, false)
end

local function frontRim(parent, cf, width, height, thickness, color)
	block(parent, "TopOutline", Vector3.new(width, thickness, thickness), cf, Vector3.new(0, height / 2 - thickness / 2, 0), color, false)
	block(parent, "BottomOutline", Vector3.new(width, thickness, thickness), cf, Vector3.new(0, -height / 2 + thickness / 2, 0), color, false)
	block(parent, "LeftOutline", Vector3.new(thickness, height - thickness * 2, thickness), cf, Vector3.new(-width / 2 + thickness / 2, 0, 0), color, false)
	block(parent, "RightOutline", Vector3.new(thickness, height - thickness * 2, thickness), cf, Vector3.new(width / 2 - thickness / 2, 0, 0), color, false)
end

local function surfaceText(target, name, text, position, size, textColor, outline)
	local gui = target:FindFirstChild("AuthoredLabels")
	if not gui then
		gui = Instance.new("SurfaceGui")
		gui.Name = "AuthoredLabels"
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 48
		gui.LightInfluence = 0
		gui.AlwaysOnTop = false
		gui.Parent = target
	end
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Text = text
	label.TextColor3 = textColor
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextWrapped = true
	label.TextStrokeTransparency = outline and 0 or 1
	label.TextStrokeColor3 = navy
	label.Parent = gui
	return label
end

local function desk(parent, cf, width, depth, topHeight, color, name)
	local result = model(parent, name or "StudentTable")
	block(result, "DeskTop", Vector3.new(width, 0.5, depth), cf, Vector3.new(0, topHeight - 0.25, 0), color)
	topRim(result, cf, width, depth, topHeight + 0.02, navy)
	for _, x in ipairs({-width / 2 + 0.65, width / 2 - 0.65}) do
		for _, z in ipairs({-depth / 2 + 0.5, depth / 2 - 0.5}) do
			block(result, "Leg", Vector3.new(0.45, topHeight - 0.5, 0.45), cf, Vector3.new(x, (topHeight - 0.5) / 2, z), blue)
		end
	end
	return result
end

local function chair(parent, cf, color, name)
	local result = model(parent, name or "StudentChair")
	part(result, "Seat", Vector3.new(2.2, 0.38, 2.2), cf * CFrame.new(0, 1.9, 0), cream, true, "Seat")
	block(result, "ChairBack", Vector3.new(2.2, 2.05, 0.32), cf, Vector3.new(0, 3, 0.98), color)
	block(result, "BackOutline", Vector3.new(2.2, 0.14, 0.36), cf, Vector3.new(0, 3.96, 0.98), navy, false)
	for _, x in ipairs({-0.85, 0.85}) do
		block(result, "SideSupport", Vector3.new(0.3, 1.7, 1.8), cf, Vector3.new(x, 0.85, 0), blue)
	end
	return result
end

local function readingCubby(parent, cf, theme)
	local result = model(parent, "ReadingCubby")
	block(result, "OpaqueBack", Vector3.new(9, 7.2, 0.4), cf, Vector3.new(0, 3.8, 1.4), theme)
	for _, x in ipairs({-4.35, 4.35}) do
		block(result, "Side", Vector3.new(0.3, 7.2, 3), cf, Vector3.new(x, 3.8, 0), cream)
	end
	for _, y in ipairs({0.4, 3.5, 7.2}) do
		block(result, "Shelf", Vector3.new(9, 0.3, 3), cf, Vector3.new(0, y, 0), cream)
		block(result, "ShelfLip", Vector3.new(9, 0.16, 0.16), cf, Vector3.new(0, y, -1.46), navy, false)
	end
	for index, x in ipairs({-2.9, -1.2, 1.2, 2.9}) do
		local height = index % 2 == 0 and 2 or 2.4
		local bookCF = cf * CFrame.new(x, 3.7 + height / 2, 0.15) * CFrame.Angles(0, 0, math.rad(index % 2 == 0 and -5 or 5))
		part(result, "StoryBook" .. index, Vector3.new(0.95, height, 1.65), bookCF, drinks[(index - 1) % #drinks + 1])
		part(result, "BookSpine" .. index, Vector3.new(0.96, 0.22, 0.1), bookCF * CFrame.new(0, height * 0.22, -0.84), navy, false)
	end
	return result
end

function Furniture.classroom(parent, centerFloor, themeColor, roomNumber)
	local theme = themeColor or blue
	local result = model(parent, string.format("Classroom%02dFurniture", roomNumber))
	result:SetAttribute("RoomNumber", roomNumber)
	result:SetAttribute("MainWalkwayWidth", 8)
	for row, z in ipairs({-8.3, 9.7}) do
		for column, x in ipairs({-9, 9}) do
			local tableCF = centerFloor * CFrame.new(x, 0, z)
			desk(result, tableCF, 8.2, 3.2, 3.2, theme, string.format("Table%d%d", row, column))
			for seatIndex, offset in ipairs({-2.15, 2.15}) do
				chair(result, centerFloor * CFrame.new(x + offset, 0, z - 3.2) * CFrame.Angles(0, math.pi, 0), theme, string.format("Chair%d%d%d", row, column, seatIndex))
			end
		end
	end
	desk(result, centerFloor * CFrame.new(6, 0, 14.7), 9, 3.7, 3.35, yellow, "TeacherTable")
	chair(result, centerFloor * CFrame.new(6, 0, 17.35), yellow, "TeacherChair")
	local board = model(result, "Whiteboard")
	local boardCF = centerFloor * CFrame.new(-2, 8.4, 18.2)
	local boardFace = part(board, "BoardFace", Vector3.new(17, 6, 0.25), boardCF, white)
	frontRim(board, boardCF * CFrame.new(0, 0, -0.145), 17, 6, 0.19, navy)
	part(board, "MarkerTray", Vector3.new(17.1, 0.22, 0.7), boardCF * CFrame.new(0, -3.1, -0.2), yellow)
	for index, x in ipairs({-5.5, -4.1}) do
		part(board, "BoardMarker" .. index, Vector3.new(0.75, 0.14, 0.18), boardCF * CFrame.new(x, -2.93, -0.33), index == 1 and navy or blue, false)
	end
	surfaceText(boardFace, "RoomNumber", "ROOM " .. tostring(roomNumber), UDim2.fromScale(0.05, 0.08), UDim2.fromScale(0.9, 0.22), blue)
	surfaceText(boardFace, "Lesson", "TODAY: PLAY FAIR", UDim2.fromScale(0.05, 0.4), UDim2.fromScale(0.9, 0.26), navy)
	surfaceText(boardFace, "Reminder", "RUN. HIDE. HELP.", UDim2.fromScale(0.09, 0.75), UDim2.fromScale(0.82, 0.16), navy)
	readingCubby(result, centerFloor * CFrame.new(-19, 0, -13.1), theme)
	local cushion = model(result, "ReadingCushion")
	block(cushion, "Base", Vector3.new(4.2, 1.2, 3), centerFloor, Vector3.new(-19, 0.6, -7.7), theme)
	block(cushion, "SoftTop", Vector3.new(4.25, 0.35, 3.05), centerFloor, Vector3.new(-19, 1.32, -7.7), cream)
	block(cushion, "FrontPiping", Vector3.new(4.25, 0.12, 0.12), centerFloor, Vector3.new(-19, 1.3, -9.18), navy, false)
	return result
end

local function toiletBowl(parent, cf)
	local result = model(parent, "Toilet")
	block(result, "Pedestal", Vector3.new(1.3, 1.05, 1.7), cf, Vector3.new(0, 0.525, 0), cream)
	block(result, "Bowl", Vector3.new(2.25, 0.65, 2.5), cf, Vector3.new(0, 1.25, -0.15), cream)
	block(result, "BowlInterior", Vector3.new(1.4, 0.08, 1.45), cf, Vector3.new(0, 1.61, -0.28), blue, false)
	for _, x in ipairs({-0.96, 0.96}) do
		block(result, "SeatSide", Vector3.new(0.34, 0.22, 2.48), cf, Vector3.new(x, 1.67, -0.15), white)
	end
	for _, z in ipairs({-1.24, 0.95}) do
		block(result, "SeatEnd", Vector3.new(2.24, 0.22, 0.3), cf, Vector3.new(0, 1.67, z), white)
	end
	block(result, "FrontSeatOutline", Vector3.new(2.26, 0.13, 0.13), cf, Vector3.new(0, 1.77, -1.34), navy, false)
	block(result, "Cistern", Vector3.new(2.25, 2.3, 0.8), cf, Vector3.new(0, 2.6, 1.25), cream)
	block(result, "CisternLid", Vector3.new(2.4, 0.22, 0.95), cf, Vector3.new(0, 3.82, 1.25), white)
	block(result, "LidOutline", Vector3.new(2.4, 0.12, 0.12), cf, Vector3.new(0, 3.91, 0.82), navy, false)
	block(result, "FlushButton", Vector3.new(0.4, 0.08, 0.25), cf, Vector3.new(0.6, 3.97, 1.25), blue, false)
	return result
end

local function sink(parent, cf)
	local result = model(parent, "Sink")
	block(result, "Pedestal", Vector3.new(1.2, 2.5, 1.5), cf, Vector3.new(0, 1.25, 0.35), cream)
	block(result, "Basin", Vector3.new(4.2, 0.6, 2.8), cf, Vector3.new(0, 2.9, 0), white)
	block(result, "BasinWater", Vector3.new(2.8, 0.09, 1.6), cf, Vector3.new(0, 3.23, -0.15), blue, false)
	topRim(result, cf, 4.2, 2.8, 3.23, navy)
	block(result, "TapStem", Vector3.new(0.28, 0.85, 0.28), cf, Vector3.new(0, 3.55, 1), navy)
	block(result, "TapSpout", Vector3.new(0.28, 0.24, 0.85), cf, Vector3.new(0, 3.93, 0.69), blue)
	block(result, "TapHandle", Vector3.new(0.85, 0.15, 0.3), cf, Vector3.new(0, 4.09, 1), yellow, false)
	return result
end

function Furniture.toilet(parent, centerFloor, floorNumber)
	local result = model(parent, "ToiletFurnitureFloor" .. tostring(floorNumber))
	for _, x in ipairs({-19, -9, 1}) do
		block(result, "CubiclePartition", Vector3.new(0.3, 7, 8), centerFloor, Vector3.new(x, 3.5, 2.5), blue)
		block(result, "PartitionTopOutline", Vector3.new(0.34, 0.16, 8), centerFloor, Vector3.new(x, 7.01, 2.5), navy, false)
	end
	for _, x in ipairs({-14, -4}) do
		toiletBowl(result, centerFloor * CFrame.new(x, 0, 3.8))
		local doorCF = centerFloor * CFrame.new(x + 2.9, 3.5, -1.5) * CFrame.Angles(0, math.rad(55), 0)
		part(result, "OpenCubicleDoor", Vector3.new(3.2, 5.6, 0.28), doorCF, cream)
		part(result, "CubicleDoorTopOutline", Vector3.new(3.2, 0.14, 0.3), doorCF * CFrame.new(0, 2.75, 0), navy, false)
		part(result, "CubicleDoorHandle", Vector3.new(0.13, 0.5, 0.25), doorCF * CFrame.new(-1.1, -0.2, -0.25), blue, false)
	end
	sink(result, centerFloor * CFrame.new(10, 0, 4.65))
	sink(result, centerFloor * CFrame.new(17, 0, 4.65))
	local mirrorCF = centerFloor * CFrame.new(13.5, 6.4, 6.66)
	local mirror = part(result, "Mirror", Vector3.new(12, 3.5, 0.18), mirrorCF, Color3.fromRGB(189, 225, 233))
	mirror.Reflectance = 0.1
	frontRim(result, mirrorCF * CFrame.new(0, 0, -0.105), 12, 3.5, 0.14, navy)
	surfaceText(mirror, "WashHands", "WASH YOUR HANDS", UDim2.fromScale(0.04, 0.7), UDim2.fromScale(0.92, 0.23), navy)
	return result
end

function Furniture.vending(parent, floorCF)
	local result = model(parent, "PlaygroundVendingMachine")
	block(result, "LeftCabinet", Vector3.new(0.5, 10, 3.6), floorCF, Vector3.new(-3.25, 5, 0), blue)
	block(result, "RightCabinet", Vector3.new(0.5, 10, 3.6), floorCF, Vector3.new(3.25, 5, 0), blue)
	block(result, "CabinetBack", Vector3.new(6.4, 9.7, 0.4), floorCF, Vector3.new(0, 5, 1.6), blue)
	block(result, "Roof", Vector3.new(7, 0.55, 3.6), floorCF, Vector3.new(0, 9.75, 0), blue)
	block(result, "LowerCabinet", Vector3.new(6.4, 3.2, 3.4), floorCF, Vector3.new(0, 1.6, 0), yellow)
	block(result, "Base", Vector3.new(7, 0.4, 3.65), floorCF, Vector3.new(0, 0.2, 0), navy)
	frontRim(result, floorCF * CFrame.new(0, 5, -1.86), 7, 10, 0.17, navy)
	for _, x in ipairs({-3.45, 3.45}) do
		block(result, "RearOutline", Vector3.new(0.15, 9.8, 0.15), floorCF, Vector3.new(x, 5, 1.72), navy, false)
	end
	local header = block(result, "Nameplate", Vector3.new(6.3, 1.05, 0.24), floorCF, Vector3.new(0, 9.05, -1.7), yellow)
	surfaceText(header, "Name", "PLAYGROUND POP", UDim2.fromScale(0.03, 0.08), UDim2.fromScale(0.94, 0.84), cream, true)
	local windowCF = floorCF * CFrame.new(-0.45, 6.15, -1.75)
	local glass = part(result, "DisplayGlass", Vector3.new(4.9, 4.4, 0.1), windowCF, Color3.fromRGB(210, 246, 253), false)
	glass.Transparency = 0.6
	frontRim(result, windowCF * CFrame.new(0, 0, -0.07), 5.05, 4.58, 0.15, cream)
	for row, y in ipairs({4.82, 7.08}) do
		block(result, "DisplayShelf" .. row, Vector3.new(5, 0.2, 2.3), floorCF, Vector3.new(-0.45, y - 0.92, -0.25), navy)
		for index, x in ipairs({-2.05, -0.45, 1.15}) do
			local drink = block(result, "DrinkCarton" .. row .. index, Vector3.new(0.85, 1.5, 0.85), floorCF, Vector3.new(x, y, -0.35), drinks[index], false)
			block(result, "CartonCap", Vector3.new(0.85, 0.16, 0.85), floorCF, Vector3.new(x, y + 0.82, -0.35), cream, false)
			surfaceText(drink, "Flavour", ({"POP", "ZIP", "FIZZ"})[index], UDim2.fromScale(0.06, 0.22), UDim2.fromScale(0.88, 0.5), cream, true)
		end
	end
	for index, y in ipairs({7.9, 6.7, 5.5}) do
		block(result, "DrinkButton" .. index, Vector3.new(0.6, 0.6, 0.2), floorCF, Vector3.new(2.55, y, -1.85), drinks[index], false)
		block(result, "ButtonBottomOutline" .. index, Vector3.new(0.65, 0.12, 0.22), floorCF, Vector3.new(2.55, y - 0.28, -1.87), navy, false)
	end
	block(result, "CoinSlot", Vector3.new(0.18, 0.72, 0.1), floorCF, Vector3.new(2.55, 4.08, -1.83), navy, false)
	block(result, "CollectionOpening", Vector3.new(4.8, 1.2, 0.12), floorCF, Vector3.new(-0.45, 1.85, -1.77), navy, false)
	block(result, "CollectionLip", Vector3.new(4.9, 0.24, 0.7), floorCF, Vector3.new(-0.45, 1.19, -1.95), cream)
	return result
end

local function bench(parent, floorCF, name)
	local result = model(parent, name or "PlaygroundBench")
	block(result, "BenchSeat", Vector3.new(10, 0.5, 2.5), floorCF, Vector3.new(0, 2.1, 0), cream)
	block(result, "BenchBack", Vector3.new(10, 2.6, 0.45), floorCF, Vector3.new(0, 3.75, 1.08), blue)
	block(result, "BackOutline", Vector3.new(10, 0.15, 0.48), floorCF, Vector3.new(0, 5.07, 1.08), navy, false)
	for _, x in ipairs({-3.75, 3.75}) do
		block(result, "Leg", Vector3.new(0.65, 1.9, 2.1), floorCF, Vector3.new(x, 0.95, 0), blue)
	end
	block(result, "SeatFrontOutline", Vector3.new(10, 0.13, 0.13), floorCF, Vector3.new(0, 2.34, -1.22), navy, false)
	for index, x in ipairs({-2.5, 2.5}) do
		local seat = part(result, "SitHere" .. index, Vector3.new(2.4, 0.12, 2), floorCF * CFrame.new(x, 2.42, 0), cream, true, "Seat")
		seat.Transparency = 1
		seat.CastShadow = false
	end
	return result
end

local function goal(parent, cf, name)
	local result = model(parent, name)
	for _, x in ipairs({-8.75, 8.75}) do
		block(result, "FrontGoalpost", Vector3.new(0.6, 8, 0.6), cf, Vector3.new(x, 4, 0), cream)
		block(result, "PostOutline", Vector3.new(0.12, 8.03, 0.64), cf, Vector3.new(x + (x < 0 and -0.25 or 0.25), 4, 0), navy, false)
		block(result, "RearGoalpost", Vector3.new(0.6, 8, 0.6), cf, Vector3.new(x, 4, 4.3), cream)
		block(result, "RoofRail", Vector3.new(0.6, 0.6, 4.9), cf, Vector3.new(x, 8, 2.15), cream)
	end
	block(result, "FrontCrossbar", Vector3.new(18.1, 0.6, 0.6), cf, Vector3.new(0, 8, 0), cream)
	block(result, "RearCrossbar", Vector3.new(18.1, 0.6, 0.6), cf, Vector3.new(0, 8, 4.3), cream)
	block(result, "CrossbarOutline", Vector3.new(18.1, 0.12, 0.64), cf, Vector3.new(0, 8.26, 0), navy, false)
	block(result, "RearCrossbarOutline", Vector3.new(18.1, 0.12, 0.64), cf, Vector3.new(0, 8.26, 4.3), navy, false)
	return result
end

function Furniture.playground(parent, centerFloor)
	local result = model(parent, "PlaygroundFurniture")
	goal(result, centerFloor * CFrame.new(0, 0, 14), "NorthGoal")
	goal(result, centerFloor * CFrame.new(0, 0, -14) * CFrame.Angles(0, math.pi, 0), "SouthGoal")
	bench(result, centerFloor * CFrame.new(-31.5, 0, -7) * CFrame.Angles(0, math.rad(-90), 0), "SidelineBench")
	local picnicCF = centerFloor * CFrame.new(31.5, 0, 4) * CFrame.Angles(0, math.rad(90), 0)
	desk(result, picnicCF, 10, 4, 3.5, yellow, "PicnicTable")
	bench(result, picnicCF * CFrame.new(0, 0, 4.4), "PicnicBenchOne")
	bench(result, picnicCF * CFrame.new(0, 0, -4.4) * CFrame.Angles(0, math.pi, 0), "PicnicBenchTwo")
	return result
end

return Furniture
