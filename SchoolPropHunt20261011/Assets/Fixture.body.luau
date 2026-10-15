local host = Instance.new("Folder")
host.Name = "SchoolAssetIsolatedFixture"
local arena
local checks = 0
local function check(value, message) assert(value, message) checks += 1 end
local ok, result = xpcall(function()
	local templates, libraryResult = Assets.BuildLibrary(workspace, host)
	check(libraryResult.templates == 37, "Expected 37 imported assets")
	check(libraryResult.eligible == 13, "Expected 13 fair morph forms")
	local styled, emblems = 0, 0
	for _, model in templates:GetChildren() do
		local cf, size = model:GetBoundingBox()
		check(math.abs(cf.Position.X) < .01 and math.abs(cf.Position.Z) < .01 and math.abs(cf.Position.Y - size.Y / 2) < .01, "Template pivot/ground mismatch " .. model.Name)
		check(model:GetPivot().Position.Magnitude < .001, "Template pivot not zero " .. model.Name)
		if model:GetAttribute("HSPropEligible") then
			check(size.Y >= 1.4 and math.max(size.X, size.Z) >= 1.8 and size.X * size.Y * size.Z >= 4 and math.max(size.X, size.Y, size.Z) <= 8, "Morph bounds rejected " .. model.Name)
		end
		for _, item in model:GetDescendants() do
			check(not item:IsA("LuaSourceContainer") and not item:IsA("ProximityPrompt") and not item:IsA("Highlight") and not item:IsA("Seat"), "Unsafe template child")
			if item:IsA("BasePart") then
				check(not item.Name:find("_REF_", 1, true), "Import marker survived")
				check(item.Anchored and not item.CanCollide and not item.CanTouch and not item.CanQuery, "Template physics unsafe")
				if item:GetAttribute("SchoolPreserveEmblem") then emblems += 1 else
					check(item.MaterialVariant == "PlaygroundRetroStuds", "Stud texture missing " .. item.Name)
					check(not item:FindFirstChildOfClass("SurfaceAppearance"), "PBR masks studs " .. item.Name)
					styled += 1
				end
			end
		end
	end
	for _, id in {"SA09","SA10","SA12","SA13","SA14","SA15","SA16","SA20","SA21","SA22","SA23","SA24","SA25","SA26","SA27","SA28","SA29","SA30","SA33","SA35","SA36","SA37","SA38"} do
		check(templates[id]:GetAttribute("HSPropEligible") == false, "Disallowed morph " .. id)
	end
	arena = workspace["Hide and Seek"]:Clone()
	arena:SetAttribute("SchoolAssetFixture", true)
	local backup = Instance.new("Folder") backup.Name = "OriginalProps" backup.Parent = host
	local applied = Assets.InstallWorld(arena, templates, backup)
	check(applied.rooms >= 16, "Room replacements missing")
	check(applied.outlineGroups == 2, "Outline budget excessive")
	local root = arena.Geometry.PlaygroundPrimarySchool.SchoolAssetProps
	check(root.CartoonOutline.FillTransparency == 1 and root.CartoonOutline.DepthMode == Enum.HighlightDepthMode.Occluded, "Outline hides colors or sees through walls")
	local seen, collisions = {}, 0
	for _, prop in root:GetChildren() do
		if prop:IsA("Model") then
			seen[prop:GetAttribute("HSPropId")] = true
			check(prop:GetAttribute("SchoolPlacedProp") == true, "Unmarked placed prop")
			local hull = prop:FindFirstChild("CollisionHull")
			if hull then
				check(hull.CanCollide and hull.Anchored and hull.Transparency == 1, "Bad prop collider")
				local delta = hull.Position - Vector3.new(11000, 33, 4546)
				check(math.abs(delta.X) > 13, "Prop blocks central corridor: " .. prop.Name)
				collisions += 1
			end
		end
	end
	for _, storage in arena.Gameplay.LockerSpots:GetChildren() do
		if storage:IsA("Model") then
			seen[storage:GetAttribute("HSPropId")] = true
			check(storage:GetAttribute("HSPropEligible") == false, "Storage became a morph")
			check(storage.Door:FindFirstChild("LockerPrompt") ~= nil, "Storage prompt missing")
			check((storage.HidePoint.Position-storage.Door.Position).Magnitude <= 6 and (storage.ExitPoint.Position-storage.Door.Position).Magnitude <= 8 and (storage.ExitPoint.Position-storage.HidePoint.Position).Magnitude <= 10, "Hiding contract exceeds distances: " .. storage.Name)
		end
	end
	for _, m in templates:GetChildren() do check(seen[m.Name] == true, "Asset never placed: " .. m.Name) end
	return {checks = checks, templates = libraryResult, placement = applied, studMeshes = styled, preservedEmblems = emblems, solidProps = collisions}
end, debug.traceback)
if arena then arena:Destroy() end
host:Destroy()
if not ok then error(result) end
return result
