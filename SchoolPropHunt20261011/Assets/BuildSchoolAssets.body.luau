local Assets = {}
local version = "20261011"
local ink = Color3.fromRGB(14, 18, 25)

local function part(parent, name, size, cf, solid)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame = name, size, cf
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, solid, false, solid
	p.Transparency, p.CastShadow = 1, false
	p.Parent = parent
	return p
end

local function outline(model)
	local h = Instance.new("Highlight")
	h.Name = "CartoonOutline"
	h.Adornee, h.FillTransparency, h.OutlineTransparency = model, 1, 0
	h.OutlineColor, h.DepthMode = ink, Enum.HighlightDepthMode.Occluded
	h.Parent = model
	return h
end

local function physicalBounds(model)
	local cf, size = model:GetBoundingBox()
	return CFrame.new(cf.Position.X, cf.Position.Y - size.Y / 2, cf.Position.Z), size
end

function Assets.BuildLibrary(importParent, target)
	assert(target and not target:FindFirstChild("SchoolPropTemplates"), "SchoolPropTemplates already exists")
	assert(game.MaterialService:FindFirstChild("PlaygroundRetroStuds"), "Stud material is missing")
	local imports = {}
	for _, m in importParent:GetChildren() do
		local id = m.Name:match("^(SA%d%d)_")
		if id and m:IsA("Model") and metadata[id] then assert(not imports[id], "Duplicate " .. id) imports[id] = m end
	end
	for id in metadata do assert(imports[id], "Imported model missing: " .. id) end
	local library = Instance.new("Folder")
	library.Name = "SchoolPropTemplates"
	library:SetAttribute("SchoolAssetVersion", version)
	library.Parent = target
	local count, eligible = 0, 0
	for id, info in metadata do
		local model = imports[id]:Clone()
		model.Name = id
		model.PrimaryPart = nil
		for _, d in model:GetDescendants() do
			if d:IsA("LuaSourceContainer") or d:IsA("ProximityPrompt") or d:IsA("Highlight") or d:IsA("Seat") or d:IsA("JointInstance") or d:IsA("Constraint") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				if d.Name:find("_REF_", 1, true) then d:Destroy() else
					local style = assert(info.meshes[d.Name], "Missing material mapping: " .. d.Name)
					d.Anchored, d.CanCollide, d.CanTouch, d.CanQuery, d.Massless = true, false, false, false, true
					d.CastShadow = true
					d:SetAttribute("SchoolAssetMaterial", style.name)
					if not style.preserve then
						for _, child in d:GetChildren() do if child:IsA("SurfaceAppearance") then child:Destroy() end end
						if d:IsA("MeshPart") then d.TextureID = "" d.RenderFidelity = Enum.RenderFidelity.Automatic end
						d.Color = Color3.fromRGB(table.unpack(style.rgb))
						d.Material, d.MaterialVariant = Enum.Material.SmoothPlastic, "PlaygroundRetroStuds"
					else d:SetAttribute("SchoolPreserveEmblem", true) end
					d:SetAttribute("SchoolStyled", true)
				end
			end
		end
		local storageFacing = id == "SA21" or id == "SA22" or id == "SA23"
		local canonicalFacing = storageFacing or id:match("^SA0[1-8]$") ~= nil or id == "SA29" or id == "SA30"
		model:PivotTo(CFrame.Angles(0, canonicalFacing and 0 or math.pi, 0))
		local bottom, size = physicalBounds(model)
		model:TranslateBy(-bottom.Position)
		model.WorldPivot = CFrame.new()
		if canonicalFacing then
			model:SetAttribute("SchoolFacingVersion", "20261011-facing-v2")
			model:SetAttribute("SchoolFrontAxis", "-Z")
		end
		if storageFacing then
			model:SetAttribute("SchoolFacingVersion", "20261012-storage-facing-v1")
			model:SetAttribute("StorageFacingVersion", "20261012-storage-facing-v1")
		end
		model:SetAttribute("SchoolAssetVersion", version)
		model:SetAttribute("HSPropId", id)
		model:SetAttribute("DisplayName", info.name)
		model:SetAttribute("HSPropEligible", info.eligible)
		model:SetAttribute("HSPropSize", size)
		model:SetAttribute("HSOutlineColor", ink)
		model:SetAttribute("SchoolSourceName", imports[id].Name)
		model.Parent = library
		count += 1
		if info.eligible then eligible += 1 end
		if count % 5 == 0 then task.wait() end
	end
	library:SetAttribute("TemplateCount", count)
	library:SetAttribute("EligibleCount", eligible)
	return library, {templates = count, eligible = eligible}
end

function Assets.InstallWorld(arena, library, backup)
	assert(arena and library and backup, "Arena, library and backup required")
	assert(arena:GetAttribute("SchoolAssetsVersion") ~= version, "School assets already installed")
	local school, gameplay = arena.Geometry.PlaygroundPrimarySchool, arena.Gameplay
	assert(not school:FindFirstChild("SchoolAssetProps"), "Existing school asset props")
	local rooms = {}
	for _, item in school:GetChildren() do if item:IsA("Model") and item:GetAttribute("ClassroomNumber") then table.insert(rooms, item) end end
	table.sort(rooms, function(a, b) return a:GetAttribute("ClassroomNumber") < b:GetAttribute("ClassroomNumber") end)
	assert(#rooms == 32 or arena:GetAttribute("SchoolAssetFixture") == true, "Expand to 32 rooms first")
	local root = Instance.new("Model")
	root.Name = "SchoolAssetProps"
	root:SetAttribute("SchoolAssetVersion", version)
	root.Parent = school
	outline(root)
	local originalLockers = gameplay.LockerSpots
	local lockers
	if originalLockers:IsA("Model") then lockers = originalLockers else
		lockers = Instance.new("Model")
		lockers.Name = "LockerSpots"
		for key, value in originalLockers:GetAttributes() do lockers:SetAttribute(key, value) end
		for _, child in originalLockers:GetChildren() do child.Parent = lockers end
		originalLockers.Parent = backup
		originalLockers.Name = "OriginalEmptyLockerSpotsFolder"
		lockers.Parent = gameplay
	end
	outline(lockers)
	local replaced, placed, storageCount = 0, 0, 0
	local function preserve(old)
		old:SetAttribute("SchoolOriginalParent", old.Parent:GetFullName())
		old:SetAttribute("SchoolOriginalName", old.Name)
		replaced += 1
		old.Name = string.format("%03d_%s", replaced, old.Name)
		old.Parent = backup
	end
	local function put(id, cf, name, parent, options)
		options = options or {}
		local prop = assert(library:FindFirstChild(id), id):Clone()
		prop.Name = name or metadata[id].name
		prop.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		if options.scale then prop:ScaleTo(prop:GetScale() * options.scale) end
		local _, bounds = prop:GetBoundingBox()
		prop:PivotTo(cf)
		prop:SetAttribute("SchoolPlacedProp", true)
		if options.room then prop:SetAttribute("ClassroomNumber", options.room) end
		if options.solid then
			part(prop, "CollisionHull", Vector3.new(bounds.X * .88, bounds.Y, bounds.Z * .85), cf * CFrame.new(0, bounds.Y / 2, 0), true)
		end
		prop.Parent = parent or root
		placed += 1
		return prop, bounds
	end
	local function storage(id, cf, name, room, old)
		local model, bounds = put(id, cf, name, lockers, {solid = true, room = room})
		model:SetAttribute("HSPropEligible", false)
		model:SetAttribute("HSHidingSpot", true)
		model:SetAttribute("HSHidingSpotName", id == "SA23" and "Tray drawers" or "Cupboard")
		local door = part(model, "Door", Vector3.new(math.min(bounds.X - .2, 4.4), math.min(bounds.Y - .1, 6), .12), cf * CFrame.new(0, math.min(bounds.Y * .5, 3.8), -bounds.Z / 2 - .08), false)
		door.CanQuery = true
		local hide = part(model, "HidePoint", Vector3.new(.2,.2,.2), cf * CFrame.new(0, math.min(3, bounds.Y * .65), 0), false)
		local exit = part(model, "ExitPoint", Vector3.new(.2,.2,.2), cf * CFrame.new(0, 3, -bounds.Z / 2 - 4), false)
		if old then
			for key, value in old:GetAttributes() do if key ~= "HSPropEligible" then model:SetAttribute(key, value) end end
			hide.CFrame, exit.CFrame = old.HidePoint.CFrame, old.ExitPoint.CFrame
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name, prompt.ActionText, prompt.ObjectText = "LockerPrompt", "Hide", model:GetAttribute("HSHidingSpotName")
		prompt.HoldDuration, prompt.MaxActivationDistance, prompt.RequiresLineOfSight = .15, 6, false
		prompt.KeyboardKeyCode, prompt.GamepadKeyCode = Enum.KeyCode.E, Enum.KeyCode.ButtonY
		prompt.Parent = door
		storageCount += 1
		return model
	end
	local oldLockers = lockers:GetChildren()
	for _, old in oldLockers do
		if old:IsA("Model") and old:FindFirstChild("Door") and old:FindFirstChild("HidePoint") and old:FindFirstChild("ExitPoint") then
			local floorY = old.HidePoint.Position.Y - 3
			local centre = Vector3.new(old.HidePoint.Position.X, floorY, old.HidePoint.Position.Z)
			local look = old.ExitPoint.Position - old.HidePoint.Position
			local cf = CFrame.lookAt(centre, centre + Vector3.new(look.X, 0, look.Z))
			storage("SA21", cf, old.Name, nil, old)
			preserve(old)
		end
		if storageCount % 6 == 0 then task.wait() end
	end
	local floorPart = assert(school.Structure:FindFirstChild("GroundFloor"))
	local floorY = floorPart.Position.Y + floorPart.Size.Y / 2
	for _, room in rooms do
		local number, floor = room:GetAttribute("ClassroomNumber"), room:GetAttribute("Floor") or 1
		local furniture
		for _, item in room:GetChildren() do if item:IsA("Model") and item:FindFirstChild("Table11") then furniture = item break end end
		assert(furniture, "Classroom furniture missing: " .. room.Name)
		local desk = furniture.Table11.DeskTop
		local centre = Vector3.new(desk.Position.X + 9, floorY + (floor - 1) * 18, desk.Position.Z + 8.3)
		local cf = CFrame.new(centre)
		for _, old in furniture:GetChildren() do
			if old:IsA("Model") and (old.Name:match("^Chair%d") or old.Name == "TeacherChair") then
				local seat = assert(old:FindFirstChild("Seat"), "Chair seat missing")
				local id = old.Name == "TeacherChair" and string.format("SA%02d", 6 + (number - 1) % 3) or string.format("SA%02d", 1 + (number - 1) % 5)
				local at = seat.CFrame * CFrame.new(0, -1.9, 0)
				put(id, at, string.format("Room%02d_%s", number, old.Name), root, {solid = true, room = number})
				preserve(old)
			elseif old:IsA("Model") and old.Name == "Whiteboard" then
				local board = old.BoardFace
				local id = number % 4 == 3 and "SA30" or "SA29"
				put(id, CFrame.new(board.Position.X, centre.Y, board.Position.Z - .7), string.format("Room%02d_TeachingBoard", number), root, {solid = true, room = number, scale = .8})
				preserve(old)
			elseif old:IsA("Model") and old.Name == "ReadingCubby" then
				local id = number % 3 == 0 and "SA21" or number % 3 == 1 and "SA23" or "SA22"
				storage(id, cf * CFrame.new(-19, 0, -13.1) * CFrame.Angles(0, math.pi, 0), string.format("Room%02d_HidingStorage", number), number)
				preserve(old)
			elseif old:IsA("Model") and old.Name == "ReadingCushion" then preserve(old) end
		end
		put(number % 2 == 0 and "SA31" or "SA32", cf * CFrame.new(19, 0, 14.5), string.format("Room%02d_Plant", number), root, {solid = true, room = number})
		local tableTop = furniture.TeacherTable.DeskTop
		local tableCF = CFrame.new(tableTop.Position.X, tableTop.Position.Y + tableTop.Size.Y / 2, tableTop.Position.Z)
		local detailId = ({"SA09", "SA10", "SA12", "SA13"})[(number - 1) % 4 + 1]
		put(detailId, tableCF * CFrame.new(2.6, .015, -.1), string.format("Room%02d_DeskSupplies", number), root, {room = number})
		if number % 4 == 3 then
			put("SA15", tableCF * CFrame.new(-1.5, .015, .2), string.format("Room%02d_Monitor", number), root, {room = number})
			put("SA16", tableCF * CFrame.new(-1.5, .015, -1.0), string.format("Room%02d_Keyboard", number), root, {room = number})
		elseif number % 4 == 0 then
			put("SA14", tableCF * CFrame.new(-1.5, .015, 0), string.format("Room%02d_Laptop", number), root, {room = number})
		elseif number % 4 == 1 then
			put("SA24", tableCF * CFrame.new(-2, .015, .3), string.format("Room%02d_Kettle", number), root, {room = number})
		end
		put(string.format("SA%02d", 25 + (number - 1) % 4), tableCF * CFrame.new(.6, .015, -.5), string.format("Room%02d_Cup", number), root, {room = number})
		if number % 8 == 5 then
			put("SA17", cf * CFrame.new(-17, 0, 3.2), string.format("Room%02d_Piano", number), root, {solid = true, room = number})
			put("SA18", cf * CFrame.new(-17, 0, -.8), string.format("Room%02d_PianoBench", number), root, {solid = true, room = number})
			put("SA19", cf * CFrame.new(-19, 0, 11), string.format("Room%02d_Guitar", number), root, {solid = true, room = number})
			put("SA20", cf * CFrame.new(-19, 0, 16), string.format("Room%02d_Clarinet", number), root, {solid = true, room = number})
		end
		task.wait()
	end
	for _, old in arena.Grounds:GetDescendants() do
		if old:IsA("Model") and old:FindFirstChild("BenchSeat") then
			local seat = old.BenchSeat
			local at = seat.CFrame * CFrame.new(0, -2.1, 0)
			put(old.Name:find("Picnic") and "SA38" or "SA37", at, old.Name, root, {solid = true})
			preserve(old)
		end
	end
	local origin = arena:GetAttribute("SchoolOriginCFrame") or CFrame.new(floorPart.Position.X, floorY, floorPart.Position.Z - 39)
	for _, side in {-1, 1} do
		for index, z in {-185, -115, -45, 25, 95} do
			local id = index % 2 == 1 and "SA34" or "SA33"
			put(id, origin * CFrame.new(side * 76, 0, z), string.format("OutdoorPlant_%s_%02d", side == -1 and "West" or "East", index), root, {solid = true})
		end
		for index, z in {-160, 70} do
			local id = index == 1 and "SA35" or "SA36"
			put(id, origin * CFrame.new(side * 88, 0, z), string.format("SchoolTree_%s_%02d", side == -1 and "West" or "East", index), root, {solid = true})
		end
	end
	arena:SetAttribute("SchoolAssetsVersion", version)
	return {rooms = #rooms, replaced = replaced, placed = placed, hidingSpots = storageCount, outlineGroups = 2}
end

return Assets
