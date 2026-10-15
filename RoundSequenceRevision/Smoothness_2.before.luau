local Workspace = game:GetService("Workspace")

local configuredObstacles = setmetatable({}, { __mode = "k" })

local function isPlatformAssetPart(part)
	local name = string.lower(part.Name)
	return string.find(name, "flat_platform_", 1, true) ~= nil
		or string.find(name, "redspike_base_", 1, true) ~= nil
end

local function configurePlatformPart(part)
	if not part:IsA("BasePart") or not isPlatformAssetPart(part) then return end

	local isRunSurface = string.find(
		string.lower(part.Name),
		"runsurface",
		1,
		true
	) ~= nil

	part.Anchored = true
	part.CanCollide = isRunSurface
	part.CanTouch = isRunSurface
	part.CanQuery = isRunSurface

	if isRunSurface then
		if part:IsA("MeshPart") then
			part.CollisionFidelity = Enum.CollisionFidelity.Box
		end
		part.CustomPhysicalProperties = PhysicalProperties.new(
			0.01,
			0,
			0,
			100,
			100
		)
	end
end

local function isSolidObstacleModel(instance)
	if not instance:IsA("Model") or string.lower(instance.Name) ~= "obstacle" then
		return false
	end

	local ancestor = instance.Parent
	while ancestor and ancestor ~= Workspace do
		if string.find(string.lower(ancestor.Name), "obstacle block", 1, true) then
			return true
		end
		ancestor = ancestor.Parent
	end
	return false
end

local function configureObstacle(model)
	if configuredObstacles[model] then return end
	configuredObstacles[model] = true

	task.defer(function()
		if not model.Parent then
			configuredObstacles[model] = nil
			return
		end

		local barrier = model:FindFirstChild("ObstacleCollisionBarrier")
		local obstacleParts = {}
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") and descendant ~= barrier then
				table.insert(obstacleParts, descendant)
			end
		end
		if #obstacleParts == 0 then
			configuredObstacles[model] = nil
			return
		end

		local barrierCFrame
		local barrierSize
		if #obstacleParts == 1 then
			barrierCFrame = obstacleParts[1].CFrame
			barrierSize = obstacleParts[1].Size
		else
			barrierCFrame, barrierSize = model:GetBoundingBox()
		end

		for _, part in obstacleParts do
			part.Anchored = true
			part.CanCollide = false
		end

		if not barrier then
			barrier = Instance.new("Part")
			barrier.Name = "ObstacleCollisionBarrier"
			barrier.Parent = model
		end
		barrier.CFrame = barrierCFrame
		barrier.Size = barrierSize + Vector3.new(0.2, 0.2, 0.2)
		barrier.Transparency = 1
		barrier.Anchored = true
		barrier.CanCollide = true
		barrier.CanTouch = false
		barrier.CanQuery = true
		barrier.CastShadow = false
		barrier.CollisionGroup = "Default"
		barrier.CustomPhysicalProperties = PhysicalProperties.new(
			0.01,
			0,
			0,
			100,
			100
		)
	end)
end

local function configureDescendant(instance)
	if instance:IsA("BasePart") then
		configurePlatformPart(instance)
	elseif isSolidObstacleModel(instance) then
		configureObstacle(instance)
	end
end

for _, descendant in Workspace:GetDescendants() do
	configureDescendant(descendant)
end

Workspace.DescendantAdded:Connect(configureDescendant)

