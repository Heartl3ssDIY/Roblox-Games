local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local GROUP_NAME = "RunnerCharacters"

pcall(function()
	PhysicsService:RegisterCollisionGroup(GROUP_NAME)
end)
PhysicsService:CollisionGroupSetCollidable(GROUP_NAME, GROUP_NAME, true)
PhysicsService:CollisionGroupSetCollidable(GROUP_NAME, "Default", false)

local function addRunnerCollider(character)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root or not character.Parent then return end

	local oldCollider = character:FindFirstChild("RunnerPlayerCollider")
	if oldCollider then oldCollider:Destroy() end

	local collider = Instance.new("Part")
	collider.Name = "RunnerPlayerCollider"
	collider.Size = Vector3.new(2, 6, 1.5)
	collider.CFrame = root.CFrame
	collider.Transparency = 1
	collider.Anchored = false
	collider.CanCollide = true
	collider.CanTouch = false
	collider.CanQuery = false
	collider.Massless = true
	collider.CollisionGroup = GROUP_NAME
	collider.CustomPhysicalProperties = PhysicalProperties.new(
		0.01,
		0,
		0,
		100,
		100
	)
	collider.Parent = character

	local weld = Instance.new("WeldConstraint")
	weld.Name = "RunnerPlayerColliderWeld"
	weld.Part0 = root
	weld.Part1 = collider
	weld.Parent = collider
end

local function addPlayer(player)
	player.CharacterAdded:Connect(addRunnerCollider)
	if player.Character then
		task.defer(addRunnerCollider, player.Character)
	end
end

Players.PlayerAdded:Connect(addPlayer)
for _, player in Players:GetPlayers() do
	addPlayer(player)
end

