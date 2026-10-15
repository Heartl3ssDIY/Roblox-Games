local Players = game:GetService("Players")

Players.CharacterAutoLoads = false

local loading = {}

local function loadCharacter(player)
	if loading[player] or not player.Parent then return end
	loading[player] = true

	local success, character = pcall(function()
		local description = Players:GetHumanoidDescriptionFromUserIdAsync(player.UserId)
		return Players:CreateHumanoidModelFromDescriptionAsync(description,
			Enum.HumanoidRigType.R6)
	end)

	if not success or not player.Parent then
		loading[player] = nil
		if player.Parent then task.delay(2, loadCharacter, player) end
		return
	end

	character.Name = player.Name
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then root.Anchored = true end
	-- Custom R6 models do not use Roblox's automatic SpawnLocation selection.
	local registry = require(game.ServerScriptService:WaitForChild("CourseRegistry"))
	local descriptor, message = registry.Resolve(workspace,
		workspace:GetAttribute("RunnerCourseNumber") or 1, 6)
	if not descriptor then
		warn("[R6 spawn] " .. tostring(message))
		character:Destroy()
		loading[player] = nil
		task.delay(2, loadCharacter, player)
		return
	end
	local spawn = player.RespawnLocation
	if not spawn or not spawn:IsDescendantOf(descriptor.spawnFolder) then
		spawn = descriptor.spawns[1]
	end
	local up = spawn.CFrame.UpVector.Y < 0 and -Vector3.yAxis or Vector3.yAxis
	character:PivotTo(CFrame.lookAt(spawn.Position + up * 3.2,
		spawn.Position + up * 3.2 + Vector3.new(-1, 0, 0), up))
	local previousCharacter = player.Character
	character.Parent = workspace
	player.Character = character
	if previousCharacter and previousCharacter ~= character then previousCharacter:Destroy() end
	loading[player] = nil

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Once(function()
			task.delay(3, loadCharacter, player)
		end)
	end
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(loadCharacter, player)
end)

Players.PlayerRemoving:Connect(function(player)
	loading[player] = nil
end)

for _, player in Players:GetPlayers() do
	task.spawn(loadCharacter, player)
end

