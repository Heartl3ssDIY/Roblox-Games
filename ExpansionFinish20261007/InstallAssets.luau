local APPLY = true
assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local assets = assert(RS:FindFirstChild("PlaygroundCosmeticAssets"), "Missing cosmetic library")
local variant = assert(game.MaterialService:FindFirstChild("PlaygroundItemStuds"), "Missing existing stud material")
local ink = Color3.fromRGB(24, 35, 62)
local plans = {}
local function bounds(model)
	local low, high = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 1 and part:GetAttribute("PCStudLayer") ~= true then
			for x = -1, 1, 2 do for y = -1, 1, 2 do for z = -1, 1, 2 do
				local point = part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z) * 0.5)
				low, high = low:Min(point), high:Max(point)
			end end end
		end
	end
	assert(low.X ~= math.huge, "Empty model " .. model.Name)
	return low, high
end
for _, group in ipairs({ { "Bats", "B", 16, 25 }, { "Toys and misc items", "M", 16, 25 }, { "Pets2", "P", 21, 35 } }) do
	local folder = assert(workspace:FindFirstChild(group[1]), "Missing import folder " .. group[1])
	for index = group[3], group[4] do
		local id = string.format("%s%02d", group[2], index)
		local source
		for _, child in ipairs(folder:GetChildren()) do
			if child:IsA("Model") and child.Name:sub(1, 4):lower() == id:lower() .. "-" then
				assert(not source, "Duplicate imported model " .. id)
				source = child
			end
		end
		assert(source, "Missing imported model " .. id)
		local previous = assets:FindFirstChild(id)
		assert(not previous or previous:GetAttribute("PCExpansionVersion") == 20261007, "Existing asset conflict " .. id)
		local meshes, bones = 0, 0
		for _, part in ipairs(source:GetDescendants()) do
			assert(not part:IsA("LuaSourceContainer"), "Unexpected embedded script " .. id)
			if part:IsA("MeshPart") and part:GetAttribute("PCStudLayer") ~= true then
				assert(part.TextureID ~= "" or part:FindFirstChildOfClass("SurfaceAppearance"), "Missing colour palette " .. id)
				meshes += 1
			elseif part:IsA("Bone") then bones += 1 end
		end
		assert(meshes > 0, "No meshes " .. id)
		if group[2] == "P" then assert(bones > 0 and source.PrimaryPart, "Missing pet rig " .. id) end
		local low, high = bounds(source)
		table.insert(plans, { id = id, source = source, previous = previous, meshes = meshes, bones = bones, size = high - low })
	end
end
assert(#plans == 35)
local function style(model)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part:GetAttribute("PCStudLayer") ~= true then
			part.Anchored = true
			part.Locked = true
			if part.Transparency < 1 then
				part.Material = Enum.Material.SmoothPlastic
				if part:IsA("MeshPart") and (part.TextureID ~= "" or part:FindFirstChildOfClass("SurfaceAppearance")) then
					if not part:FindFirstChild("PCStudFinish") then
						local coat = part:Clone()
						for _, child in ipairs(coat:GetChildren()) do
							if not child:IsA("Bone") then child:Destroy() end
						end
						for _, bone in ipairs(coat:GetDescendants()) do
							if bone:IsA("Bone") then
								local originalBone = part:FindFirstChild(bone.Name, true)
								assert(originalBone and originalBone:IsA("Bone"), "Missing matching skin bone")
								local source = Instance.new("ObjectValue")
								source.Name, source.Value, source.Parent = "PCSourceBone", originalBone, bone
							end
						end
						coat.Name = "PCStudFinish"
						coat:SetAttribute("PCStudLayer", true)
						coat.TextureID = ""
						coat.Color = Color3.new(0.65, 0.65, 0.65)
						coat.MaterialVariant = variant.Name
						coat.Transparency = 0.68
						coat.Size = part.Size + Vector3.new(0.012, 0.012, 0.012)
						coat.CFrame = part.CFrame
						coat.CanCollide, coat.CanTouch, coat.CanQuery = false, false, false
						coat.Massless, coat.CastShadow = true, false
						coat.Parent = part
						local weld = Instance.new("WeldConstraint")
						weld.Name, weld.Part0, weld.Part1 = "StudFinishWeld", part, coat
						weld.Parent = coat
					end
				else part.MaterialVariant = variant.Name end
			end
		end
	end
	local outline = model:FindFirstChild("CartoonOutline")
	if not outline then outline = Instance.new("Highlight") outline.Name = "CartoonOutline" outline.Parent = model end
	assert(outline:IsA("Highlight"))
	outline.Adornee, outline.FillTransparency = model, 1
	outline.OutlineTransparency, outline.OutlineColor = 0, ink
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	model:SetAttribute("PCArtVersion", 1)
end
local report = { count = #plans, applied = APPLY, items = {} }
if APPLY then
	for _, plan in ipairs(plans) do
		local clone = plan.source:Clone()
		plan.clone = clone
		clone.Name = plan.id
		style(clone)
		if plan.id:sub(1, 1) == "P" then
			local root = clone:FindFirstChild("RootPart")
			if not root then
				root = Instance.new("Part")
				root.Name, root.Size = "RootPart", Vector3.new(0.2, 0.2, 0.2)
				root.Transparency, root.Anchored, root.CanCollide = 1, true, false
				root.CFrame = CFrame.new(clone:GetPivot().Position) * CFrame.Angles(0, -math.pi / 2, 0)
				root.Parent = clone
			end
			clone.PrimaryPart = root
			clone:PivotTo(CFrame.identity)
			clone:SetAttribute("PetFacingYaw", 0)
			clone:SetAttribute("PCProceduralPetRig", true)
		else
			local low, high = bounds(clone)
			clone.PrimaryPart = nil
			clone.WorldPivot = CFrame.new((low.X + high.X) * 0.5, low.Y, (low.Z + high.Z) * 0.5)
			clone:PivotTo(CFrame.identity)
		end
		clone:SetAttribute("PCImported", true)
		clone:SetAttribute("PCExpansionVersion", 20261007)
		clone:SetAttribute("OriginalModelName", plan.source.Name)
		clone:SetAttribute("CatalogId", plan.id)
		for _, part in ipairs(clone:GetDescendants()) do
			if part:IsA("BasePart") then part.CanCollide, part.CanTouch, part.CanQuery, part.Massless = false, false, false, true end
		end
	end
	local backup = SS:FindFirstChild("ExpansionFinishBackup20261007")
	if not backup then backup = Instance.new("Folder") backup.Name = "ExpansionFinishBackup20261007" backup.Parent = SS end
	for _, plan in ipairs(plans) do
		if not backup:FindFirstChild(plan.id) then
			local saved = plan.source:Clone()
			saved.Name = plan.id
			saved:SetAttribute("OriginalPath", plan.source:GetFullName())
			saved.Parent = backup
		end
	end
	for _, plan in ipairs(plans) do
		style(plan.source)
		if plan.previous then
			plan.previous.Name = plan.id .. "_PreviousLibrary"
			plan.previous.Parent = backup
		end
		plan.clone.Parent = assets
	end
end
for _, plan in ipairs(plans) do table.insert(report.items, { id = plan.id, source = plan.source:GetFullName(), library = plan.clone and plan.clone:GetFullName(), meshes = plan.meshes, bones = plan.bones, size = tostring(plan.size) }) end
return game:GetService("HttpService"):JSONEncode(report)
