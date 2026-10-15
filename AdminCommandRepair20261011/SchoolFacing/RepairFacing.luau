local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Stop Play before repairing school assets")

local arena = workspace:FindFirstChild("Hide and Seek")
local school = assert(arena and arena.Geometry:FindFirstChild("PlaygroundPrimarySchool"))
local props = assert(school:FindFirstChild("SchoolAssetProps"))
local library = assert(game.ReplicatedStorage:FindFirstChild("SchoolPropTemplates"))
local version = "20261011-facing-v2"
local ids = {SA01=true, SA02=true, SA03=true, SA04=true, SA05=true, SA06=true, SA07=true, SA08=true, SA29=true, SA30=true}
local targets, worldCount, templateCount = {}, 0, 0
for _, model in props:GetChildren() do
	if model:IsA("Model") and ids[model:GetAttribute("HSPropId")] then
		assert(model:GetAttribute("SchoolFacingVersion") ~= version, "Facing repair already installed")
		assert(not model.PrimaryPart, "Unexpected primary part: " .. model.Name)
		assert(model:FindFirstChild("CollisionHull"), "Missing collision hull: " .. model.Name)
		table.insert(targets, model)
		worldCount += 1
	end
end
for id in ids do
	local model = assert(library:FindFirstChild(id), "Missing template " .. id)
	assert(model:GetAttribute("SchoolFacingVersion") ~= version, "Template already corrected: " .. id)
	assert(not model.PrimaryPart, "Unexpected template primary part")
	table.insert(targets, model)
	templateCount += 1
end
assert(worldCount == 320 and templateCount == 10, "Unexpected school asset counts")

local untouched = {}
for _, item in arena:GetDescendants() do
	if item:IsA("BasePart") then
		local model = item.Parent
		local target = false
		while model and model ~= arena do
			if model.Parent == props and ids[model:GetAttribute("HSPropId")] then target = true break end
			model = model.Parent
		end
		if not target or item.Name == "CollisionHull" then
			untouched[item] = {cf = item.CFrame, size = item.Size, collide = item.CanCollide, query = item.CanQuery, touch = item.CanTouch}
		end
	end
end

local backup = Instance.new("Folder")
backup.Name = "SchoolFacingBackup_20261011"
assert(not game.ServerStorage:FindFirstChild(backup.Name), "A previous backup already exists")
backup.Parent = game.ServerStorage
local originals = {}
for index, model in targets do
	local copy = model:Clone()
	copy:SetAttribute("OriginalParent", model.Parent:GetFullName())
	copy.Parent = backup
	originals[model] = {pivot = model:GetPivot(), parts = {}}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			originals[model].parts[part] = {cf = part.CFrame, size = part.Size, collide = part.CanCollide, query = part.CanQuery, touch = part.CanTouch, material = part.MaterialVariant, color = part.Color}
		end
	end
	if index % 20 == 0 then task.wait() end
end

local success, result = pcall(function()
	local moved, preserved = 0, 0
	for index, model in targets do
		local original = originals[model]
		local pivot = original.pivot
		local delta = pivot * CFrame.Angles(0, math.pi, 0) * pivot:Inverse()
		for part, values in original.parts do
			if part.Name ~= "CollisionHull" then part.CFrame = delta * values.cf moved += 1 end
		end
		model.WorldPivot = pivot
		model:SetAttribute("SchoolFacingVersion", version)
		model:SetAttribute("SchoolFrontAxis", "-Z")
		assert((model:GetPivot().Position - pivot.Position).Magnitude < .001, "Prop position changed")
		for part, values in original.parts do
			assert(part.Size == values.size and part.CanCollide == values.collide and part.CanQuery == values.query and part.CanTouch == values.touch, "Part physics changed")
			assert(part.MaterialVariant == values.material and part.Color == values.color, "Style changed")
		end
		if index % 20 == 0 then task.wait() end
	end
	for part, values in untouched do
		assert(part.CFrame == values.cf and part.Size == values.size and part.CanCollide == values.collide and part.CanQuery == values.query and part.CanTouch == values.touch, "Unrelated geometry changed: " .. part:GetFullName())
		preserved += 1
	end
	local boards, chairs = 0, 0
	for _, model in targets do
		local id = model:GetAttribute("HSPropId")
		if id == "SA29" or id == "SA30" then
			local face = assert(model:FindFirstChild(id .. "_B01_M02", true))
			assert(model:GetPivot():PointToObjectSpace(face.Position).Z < -.2, "Teaching face still points backward")
			boards += model.Parent == props and 1 or 0
		else
			chairs += model.Parent == props and 1 or 0
		end
	end
	library:SetAttribute("SchoolFacingVersion", version)
	arena:SetAttribute("SchoolFacingVersion", version)
	return {worldModels = worldCount, chairs = chairs, teachingBoards = boards, templates = templateCount, visualPartsRotated = moved, unaffectedPartsVerified = preserved, backup = backup:GetFullName()}
end)
if not success then
	for model, original in originals do
		for part, values in original.parts do part.CFrame = values.cf end
		model.WorldPivot = original.pivot
		model:SetAttribute("SchoolFacingVersion", nil)
		model:SetAttribute("SchoolFrontAxis", nil)
	end
	error("Repair rolled back: " .. tostring(result))
end
return result
