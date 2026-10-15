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
	character.Parent = workspace
	player.Character = character
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

