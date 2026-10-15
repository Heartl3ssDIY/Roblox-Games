assert(not game:GetService("RunService"):IsRunning(),"Stop Play before installing")
assert(game.PlaceId==95034648955135 and game.GameId==10769034155,"Wrong experience")
local furniture=(function()
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

end)()
local build=(function()
return function(furniture, target)
	target = target or workspace
	assert(not target:FindFirstChild("Hide and Seek"),"School island already exists")
	local arena=Instance.new("Folder")
	arena.Name="Hide and Seek"
	local origin=CFrame.new(11000,33,4546)
	local palette={ink=Color3.fromRGB(23,35,62),cream=Color3.fromRGB(255,246,214),blue=Color3.fromRGB(86,194,238),gold=Color3.fromRGB(255,204,77),grass=Color3.fromRGB(148,210,94),wall=Color3.fromRGB(248,207,126),brick=Color3.fromRGB(221,123,94)}
	local function folder(parent,name)
		local f=Instance.new("Folder") f.Name=name f.Parent=parent return f
	end
	local function model(parent,name)
		local m=Instance.new("Model") m.Name=name m.Parent=parent return m
	end
	local function part(parent,name,size,cf,color,collide)
		local p=Instance.new("Part")
		p.Name=name p.Size=size p.CFrame=cf p.Color=color p.Material=Enum.Material.SmoothPlastic
		p.Anchored=true p.CanCollide=collide~=false p.CanTouch=false p.CanQuery=collide~=false
		for _,face in {"TopSurface","BottomSurface","LeftSurface","RightSurface","FrontSurface","BackSurface"}do p[face]=Enum.SurfaceType.Studs end
		p.Parent=parent return p
	end
	local function localPart(parent,name,size,position,color,collide)
		return part(parent,name,size,origin*CFrame.new(position),color,collide)
	end
	local function sign(parent,name,cf,size,words,color)
		local board=part(parent,name,size,cf,palette.ink,false)
		local face=Instance.new("SurfaceGui")
		face.Name="EditableLabel" face.Face=Enum.NormalId.Front face.CanvasSize=Vector2.new(600,150)
		face.SizingMode=Enum.SurfaceGuiSizingMode.FixedSize face.LightInfluence=0 face.PixelsPerStud=40 face.Parent=board
		local text=Instance.new("TextLabel") text.Name="Caption" text.Size=UDim2.fromScale(1,1)
		text.BackgroundTransparency=1 text.Text=words text.TextColor3=color or palette.cream
		text.Font=Enum.Font.FredokaOne text.TextScaled=true text.Parent=face
		local stroke=Instance.new("UIStroke") stroke.Color=palette.ink stroke.Thickness=2 stroke.Parent=text
		return board
	end
	local geometry=folder(arena,"Geometry")
	local island=model(geometry,"FourthIsland")
	local centre=CFrame.new(11000,33,4534)
	part(island,"NavyIslandRim",Vector3.new(208,1.4,204),centre*CFrame.new(0,-.8,0),palette.ink)
	part(island,"StuddedGrass",Vector3.new(206,1,202),centre*CFrame.new(0,-.5,0),palette.grass)
	part(island,"WarmEarth",Vector3.new(202,22,198),centre*CFrame.new(0,-12.7,0),Color3.fromRGB(174,113,74))
	part(island,"BottomOutline",Vector3.new(204,1.2,200),centre*CFrame.new(0,-24.3,0),palette.ink)
	for _,x in {-1,1}do
		for _,z in {-1,1}do
			local rock=part(island,"CornerRock",Vector3.new(14,16,14),centre*CFrame.new(x*94,-17,z*92)*CFrame.Angles(0,math.rad(25*x*z),0),Color3.fromRGB(145,92,66))
			rock.Shape=Enum.PartType.Ball
		end
	end
	local grounds=folder(arena,"Grounds")
	for _,x in {-101,101}do part(grounds,"IslandBoundary",Vector3.new(1.4,4,200),centre*CFrame.new(x,2,0),palette.ink) end
	for _,z in {-99,99}do part(grounds,"IslandBoundary",Vector3.new(202,4,1.4),centre*CFrame.new(0,2,z),palette.ink) end
	localPart(grounds,"EntrancePath",Vector3.new(16,.15,22),Vector3.new(0,.08,-68),palette.cream)
	local building=model(geometry,"PlaygroundPrimarySchool")
	local shell=folder(building,"Structure")
	local roomFolder=folder(building,"Classrooms")
	local toilets=folder(building,"Toilets")
	local detail=folder(building,"Details")
	localPart(shell,"GroundFloor",Vector3.new(124,1,116),Vector3.new(0,-.5,0),palette.cream)
	localPart(shell,"UpperFloorFront",Vector3.new(124,1,96),Vector3.new(0,17.5,-10),palette.cream)
	for _,x in {-36.5,36.5}do localPart(shell,"UpperFloorRear",Vector3.new(51,1,20),Vector3.new(x,17.5,48),palette.cream)end
	localPart(shell,"UpperFloorBackBridge",Vector3.new(22,1,2),Vector3.new(0,17.5,57),palette.cream)
	localPart(shell,"RoofNavyEdge",Vector3.new(128,1.2,120),Vector3.new(0,35.3,0),palette.ink)
	localPart(shell,"CartoonBlueRoof",Vector3.new(126,1,118),Vector3.new(0,36.1,0),palette.blue)
	localPart(detail,"RoofRidge",Vector3.new(4,1.2,116),Vector3.new(0,37.2,0),palette.gold,false)
	local function wall(parent,name,axis,cross,along,length,base,height,holes,color)
		local cuts={-length/2,length/2}
		for _,h in holes or {}do table.insert(cuts,h.a) table.insert(cuts,h.b)end
		table.sort(cuts)
		local function slab(a,b,bottom,tall,suffix)
			if b-a<.01 or tall<.01 then return end
			local pos=axis=="X" and Vector3.new(along+(a+b)/2,base+bottom+tall/2,cross)or Vector3.new(cross,base+bottom+tall/2,along+(a+b)/2)
			local size=axis=="X" and Vector3.new(b-a,tall,1)or Vector3.new(1,tall,b-a)
			localPart(parent,name..suffix,size,pos,color or palette.wall)
		end
		for i=1,#cuts-1 do
			local a,b=cuts[i],cuts[i+1]
			local opening
			for _,h in holes or {}do if (a+b)/2>=h.a and (a+b)/2<=h.b then opening=h break end end
			if opening then slab(a,b,0,opening.sill or 0,"Sill") slab(a,b,(opening.sill or 0)+opening.height,height-(opening.sill or 0)-opening.height,"Lintel")
			else slab(a,b,0,height,"Panel")end
		end
		for _,h in holes or {}do
			local size=axis=="X"and Vector3.new(.18,h.height,.18)or Vector3.new(.18,h.height,.18)
			for _,edge in {h.a,h.b}do
				local pos=axis=="X"and Vector3.new(along+edge,base+(h.sill or 0)+h.height/2,cross)or Vector3.new(cross,base+(h.sill or 0)+h.height/2,along+edge)
				localPart(parent,name.."OpeningOutline",size,pos,palette.ink,false)
			end
			for _,edge in {h.sill or 0,(h.sill or 0)+h.height}do
				local pos=axis=="X"and Vector3.new(along+(h.a+h.b)/2,base+edge,cross)or Vector3.new(cross,base+edge,along+(h.a+h.b)/2)
				local trimSize=axis=="X"and Vector3.new(h.b-h.a,.18,.18)or Vector3.new(.18,.18,h.b-h.a)
				localPart(parent,name.."OpeningOutline",trimSize,pos,palette.ink,false)
			end
			if h.glass then
				local sizeGlass=axis=="X"and Vector3.new(h.b-h.a,h.height,.15)or Vector3.new(.15,h.height,h.b-h.a)
				local pos=axis=="X"and Vector3.new(along+(h.a+h.b)/2,base+h.sill+h.height/2,cross)or Vector3.new(cross,base+h.sill+h.height/2,along+(h.a+h.b)/2)
				local glass=localPart(parent,name.."BlueWindow",sizeGlass,pos,palette.blue)
				glass.Transparency=.28
			end
		end
	end
	local themes={Color3.fromRGB(105,193,247),Color3.fromRGB(113,210,153),Color3.fromRGB(238,142,177),Color3.fromRGB(248,202,92),Color3.fromRGB(179,144,239),Color3.fromRGB(100,214,214),Color3.fromRGB(246,162,106),Color3.fromRGB(145,190,251)}
	local subjects={"MATHS","SCIENCE","ART","ENGLISH","MUSIC","GEOGRAPHY","COMPUTING","HISTORY"}
	for floor=0,1 do
		local base=floor*18
		local frontOpenings={{a=-48,b=-36,sill=5,height=6,glass=true},{a=-31,b=-19,sill=5,height=6,glass=true},{a=19,b=31,sill=5,height=6,glass=true},{a=36,b=48,sill=5,height=6,glass=true}}
		table.insert(frontOpenings,floor==0 and {a=-6,b=6,sill=0,height=11}or {a=-6,b=6,sill=4,height=7,glass=true})
		wall(shell,"FrontWall"..floor,"X",-58,0,124,base,16,frontOpenings,palette.brick)
		wall(shell,"BackWall"..floor,"X",58,0,124,base,16,{},palette.brick)
		for _,side in {-1,1}do
			local gaps={{a=-30,b=-23,sill=5,height=5,glass=true},{a=28,b=35,sill=5,height=5,glass=true},{a=-21,b=-13,sill=2.5,height=10}}
			wall(shell,"OutsideWall"..floor..side,"Z",side*62,0,116,base,16,gaps,palette.wall)
			wall(shell,"CorridorWall"..floor..side,"Z",side*11,0,116,base,16,{{a=-21,b=-13,sill=0,height=9},{a=18,b=26,sill=0,height=9},{a=46,b=54,sill=0,height=9}},palette.cream)
			wall(shell,"ClassDivider"..floor..side,"X",2.5,side*36,50,base,16,{{a=12,b=20,sill=2.2,height=10}},palette.wall)
			wall(shell,"ClassFront"..floor..side,"X",-36,side*36,50,base,16,{},palette.wall)
			wall(shell,"ClassRear"..floor..side,"X",41,side*36,50,base,16,{},palette.wall)
			for row=1,2 do
				local number=floor*4+(row-1)*2+(side==1 and 2 or 1)
				local z=row==1 and -17 or 22
				local room=model(roomFolder,string.format("Classroom%02d_%s",number,subjects[number]))
				room:SetAttribute("ClassroomNumber",number)room:SetAttribute("Floor",floor+1)
				local cf=origin*CFrame.new(side*36,base,z)
				furniture.classroom(room,cf,themes[number],number)
				sign(detail,"ClassroomLabel"..number,origin*CFrame.new(side*10.42,base+10,z)*CFrame.Angles(0,side==1 and math.pi/2 or -math.pi/2,0),Vector3.new(6,1.5,.15),string.format("%d · %s",floor==0 and 100+number or 200+number-4,subjects[number]),palette.cream)
			end
		end
		local toilet=model(toilets,"ToiletFloor"..(floor+1))
		toilet:SetAttribute("Floor",floor+1)
		furniture.toilet(toilet,origin*CFrame.new(-36,base,51),floor+1)
		sign(detail,"ToiletSign"..floor,origin*CFrame.new(-10.42,base+10,50)*CFrame.Angles(0,-math.pi/2,0),Vector3.new(6,1.5,.15),"TOILETS",palette.cream)
		for _,z in {-45,-16,15,44}do
			local light=localPart(detail,"CeilingLight",Vector3.new(8,.3,2),Vector3.new(0,base+15.5,z),Color3.fromRGB(255,252,221),false)
			local glow=Instance.new("PointLight")glow.Brightness=.6 glow.Range=24 glow.Color=palette.cream glow.Shadows=false glow.Parent=light
		end
		for _,x in {-60.4,60.4,-10.4,10.4}do localPart(detail,"FloorSkirting",Vector3.new(.15,.5,113),Vector3.new(x,base+.25,0),palette.ink,false)end
		for _,x in {-62,62}do for _,z in {-58,58}do localPart(detail,"BuildingCornerOutline",Vector3.new(.2,16,.2),Vector3.new(x,base+8,z),palette.ink,false)end end
	end
	local stairs=model(building,"SwitchbackStaircase")
	for step=1,12 do
		local rise=step*.75
		local z=39+(step-.5)*1.3
		localPart(stairs,"LowerStep"..step,Vector3.new(7,rise,1.3),Vector3.new(-5.2,rise*.5,z),palette.gold)
		localPart(stairs,"StepEdge",Vector3.new(7,.12,.16),Vector3.new(-5.2,rise+.06,z-.55),palette.ink,false)
		local rise2=9+step*.75
		local z2=54.6-(step-.5)*1.3
		localPart(stairs,"UpperStep"..step,Vector3.new(7,.75,1.3),Vector3.new(5.2,rise2-.375,z2),palette.gold)
		localPart(stairs,"StepEdge",Vector3.new(7,.12,.16),Vector3.new(5.2,rise2+.06,z2+.55),palette.ink,false)
	end
	localPart(stairs,"MiddleLanding",Vector3.new(18,1,4),Vector3.new(0,8.5,56.5),palette.gold)
	localPart(stairs,"UpperLandingLink",Vector3.new(7,1,1.1),Vector3.new(5.2,17.5,38.5),palette.gold)
	for _,x in {-9.4,0,9.4}do
		for _,z in {40,44,48,52,56}do
			local height=x<0 and math.clamp((z-39)/1.3*.75,1,9)or x>0 and math.clamp(9+(54.6-z)/1.3*.75,9,18)or 9
			localPart(stairs,"RailPost",Vector3.new(.3,3,.3),Vector3.new(x,height+1.5,z),palette.ink,false)
		end
	end
	localPart(stairs,"LandingGuard",Vector3.new(18,3,.3),Vector3.new(0,10.5,58.2),palette.ink)
	local exterior=model(building,"OutsideEscapeSteps")
	for step=1,24 do
		local rise=step*.75
		localPart(exterior,"ReturnStep"..step,Vector3.new(8,rise,1.3),Vector3.new(76,rise/2,14-(step-.5)*1.3),palette.blue)
	end
	localPart(exterior,"UpperJumpLanding",Vector3.new(18,1,8.8),Vector3.new(70,17.5,-21.6),palette.blue)
	for _,x in {-65.5,65.5}do
		localPart(detail,"UpperEscapeLedge",Vector3.new(7,1,88),Vector3.new(x,17.5,-2),palette.cream)
		for _,range in {{-45,-21},{-13,41}}do
			localPart(detail,"LedgeOuterRail",Vector3.new(.4,3.5,range[2]-range[1]),Vector3.new(x+(x<0 and -3.2 or 3.2),19.75,(range[1]+range[2])/2),palette.ink)
		end
	end
	localPart(detail,"EntranceCanopy",Vector3.new(24,1,8),Vector3.new(0,12,-61),palette.blue)
	for _,x in {-11,11}do localPart(detail,"CanopyPillar",Vector3.new(1,12,1),Vector3.new(x,6,-64),palette.ink)end
	sign(detail,"SchoolName",origin*CFrame.new(0,14,-58.65),Vector3.new(24,3,.3),"PLAYGROUND PRIMARY",palette.gold)
	local clock=localPart(detail,"SchoolClock",Vector3.new(5,5,.3),Vector3.new(0,29,-58.7),palette.cream,false)
	localPart(detail,"ClockFrame",Vector3.new(5.4,5.4,.2),Vector3.new(0,29,-58.5),palette.ink,false)
	localPart(detail,"ClockHandLong",Vector3.new(.15,1.7,.2),Vector3.new(0,29.7,-58.95),palette.ink,false)
	localPart(detail,"ClockHandShort",Vector3.new(1.4,.15,.2),Vector3.new(.6,29,-58.95),palette.ink,false)
	furniture.vending(detail,origin*CFrame.new(43,0,48))
	furniture.vending(detail,origin*CFrame.new(43,18,48))
	furniture.playground(grounds,CFrame.new(11000,33,4457))
	local gameplay=folder(arena,"Gameplay")
	local bounds=part(gameplay,"ArenaBounds",Vector3.new(208,84,204),CFrame.new(11000,75,4534),palette.ink,false)
	bounds.Transparency=1
	local function marker(parent,name,cf)
		local p=part(parent,name,Vector3.new(.4,.4,.4),cf,palette.ink,false)p.Transparency=1 return p
	end
	local hiderSpawns=folder(gameplay,"HiderSpawns")
	for floor=0,1 do for side=-1,1,2 do for _,z in {-26,-10,14,30}do marker(hiderSpawns,string.format("Hider%02d",#hiderSpawns:GetChildren()+1),origin*CFrame.new(side*4,floor*18+3,z))end end end
	local seekerSpawns=folder(gameplay,"SeekerSpawns")
	for i=1,4 do marker(seekerSpawns,"Seeker"..i,origin*CFrame.new((i-2.5)*4,3,-51))end
	local lockers=folder(gameplay,"LockerSpots")
	local function locker(cf,color)
		local id=#lockers:GetChildren()+1
		local m=model(lockers,string.format("Locker%02d",id))m:SetAttribute("LockerId",id)
		part(m,"Back",Vector3.new(4,8,.35),cf*CFrame.new(0,4,-1.825),palette.ink)
		for _,x in {-1.825,1.825}do part(m,"Side",Vector3.new(.35,8,4),cf*CFrame.new(x,4,0),color)end
		part(m,"Top",Vector3.new(4,.35,4),cf*CFrame.new(0,7.825,0),palette.ink)
		part(m,"Base",Vector3.new(4,.2,4),cf*CFrame.new(0,.1,0),palette.ink)
		local door=part(m,"Door",Vector3.new(3.55,7.3,.25),cf*CFrame.new(0,3.85,2.02),color)
		part(m,"Handle",Vector3.new(.2,.9,.12),cf*CFrame.new(-1.12,3.8,2.22),palette.ink,false)
		for row=1,3 do part(m,"Vent",Vector3.new(1.4,.10,.09),cf*CFrame.new(0,5.8+row*.3,2.2),palette.ink,false)end
		marker(m,"HidePoint",cf*CFrame.new(0,3,0))
		marker(m,"ExitPoint",cf*CFrame.new(0,3,6.4))
		local prompt=Instance.new("ProximityPrompt")prompt.Name="LockerPrompt"prompt.ActionText="Hide / Search"prompt.ObjectText="Locker "..id
		prompt.KeyboardKeyCode=Enum.KeyCode.E prompt.GamepadKeyCode=Enum.KeyCode.ButtonX prompt.MaxActivationDistance=6 prompt.HoldDuration=.25 prompt.RequiresLineOfSight=true prompt.Parent=door
		return m
	end
	for floor=0,1 do
		for _,z in {-47,-34,-6,5,12,34}do
			local side=floor==0 and -1 or 1
			locker(origin*CFrame.new(side*8,floor*18,z)*CFrame.Angles(0,side<0 and math.pi/2 or -math.pi/2,0),floor==0 and palette.blue or palette.gold)
		end
		for side=-1,1,2 do for row=1,2 do
			local z=(row==1 and -17 or 22)+14
			locker(origin*CFrame.new(side*16,floor*18,z)*CFrame.Angles(0,math.pi,0),themes[floor*4+(row-1)*2+(side==1 and 2 or 1)])
		end end
	end
	for key,value in pairs({RoundDuration=180,HideSeconds=20,MinimumPlayers=2,MaxPlayers=16,BaseSpeed=16,SeekerSpeed=18,TagDistance=10,CountdownSeconds=3,ResultsSeconds=7,FloorY=33,BuildVersion="20261010",ClassroomCount=8,ToiletCount=2,IslandNumber=4})do arena:SetAttribute(key,value)end
	arena.Parent=target
	return arena
end

end)()
local arena=build(furniture)
local count=0 for _,object in arena:GetDescendants()do if object:IsA("BasePart")then count+=1 end end
return {name=arena.Name,parts=count,classrooms=#arena.Geometry.PlaygroundPrimarySchool.Classrooms:GetChildren(),toilets=#arena.Geometry.PlaygroundPrimarySchool.Toilets:GetChildren(),lockers=#arena.Gameplay.LockerSpots:GetChildren(),spawns=#arena.Gameplay.HiderSpawns:GetChildren(),attributes=arena:GetAttributes()}
