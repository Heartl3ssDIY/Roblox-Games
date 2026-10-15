local arena = assert(workspace:FindFirstChild("Hide and Seek"))
local library = assert(game.ReplicatedStorage:FindFirstChild("SchoolPropTemplates"))
local school = arena.Geometry.PlaygroundPrimarySchool
local props = assert(school:FindFirstChild("SchoolAssetProps"))
local checks, rooms, morphs, storageCount, meshCount = 0, 0, 0, 0, 0
local function check(value, why) assert(value, why) checks += 1 end
check(#library:GetChildren() == 37, "Incorrect template count")
local used, roomAssets = {}, {}
for _, model in library:GetChildren() do
	check(model:GetAttribute("SchoolAssetVersion") == "20261011", "Stale template")
	if model:GetAttribute("HSPropEligible") then morphs += 1 end
	for _, item in model:GetDescendants() do
		check(not item:IsA("Highlight") and not item:IsA("LuaSourceContainer") and not item:IsA("Seat") and not item:IsA("ProximityPrompt"), "Unexpected template behavior")
		if item:IsA("MeshPart") and not item:GetAttribute("SchoolPreserveEmblem") then
			check(item.MaterialVariant == "PlaygroundRetroStuds" and not item:FindFirstChildOfClass("SurfaceAppearance"), "Template lacks visible studs: " .. item.Name)
			meshCount += 1
		end
	end
end
check(morphs == 13, "Incorrect morph allowlist")
local function collect(prop)
	if not prop:IsA("Model") then return end
	local id, room = prop:GetAttribute("HSPropId"), prop:GetAttribute("ClassroomNumber")
	if id then used[id] = true end
	if room then roomAssets[room] = (roomAssets[room] or 0) + 1 end
end
for _, prop in props:GetChildren() do collect(prop) end
local blockedExits = {}
for _, storage in arena.Gameplay.LockerSpots:GetChildren() do
	if storage:IsA("Model") then
		collect(storage)
		storageCount += 1
		check(storage:GetAttribute("HSPropEligible") == false, "Storage must not become a disguise")
		check(storage:FindFirstChild("Door") and storage.Door:FindFirstChild("LockerPrompt") and storage:FindFirstChild("HidePoint") and storage:FindFirstChild("ExitPoint"), "Missing hiding interaction")
		check((storage.ExitPoint.Position - storage.Door.Position).Magnitude <= 8 and (storage.HidePoint.Position-storage.Door.Position).Magnitude <= 6, "Invalid hiding distances")
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {storage}
		local hits = workspace:GetPartBoundsInBox(CFrame.new(storage.ExitPoint.Position), Vector3.new(2.4, 5, 2.4), params)
		local obstruction = {}
		for _, hit in hits do
			if hit.CanCollide and hit:IsDescendantOf(arena) then table.insert(obstruction, hit:GetFullName()) end
		end
		if #obstruction > 0 then table.insert(blockedExits, {storage = storage.Name, obstruction = obstruction}) end
	end
end
for _, model in library:GetChildren() do check(used[model.Name] == true, "Unused asset: " .. model.Name) end
for _, room in school:GetChildren() do
	local number = room:GetAttribute("ClassroomNumber")
	if number then rooms += 1 check((roomAssets[number] or 0) >= 13, "Incomplete room dressing: " .. room.Name) end
end
check(rooms == 32, "Expected 32 classrooms")
check(storageCount == 76, "Expected 44 corridor cupboards and 32 classroom hiding spots")
check(props.CartoonOutline.FillTransparency == 1 and arena.Gameplay.LockerSpots.CartoonOutline.FillTransparency == 1, "Outline fills hide the models")
return {checks = checks, rooms = rooms, templates = #library:GetChildren(), morphs = morphs, studMeshes = meshCount, storage = storageCount, blockedExits = blockedExits}
