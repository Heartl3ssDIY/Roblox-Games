local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if game.PlaceId ~= 74498603638770 then
	return
end

local enterLobby = ReplicatedStorage:WaitForChild("GBloxEnterLobby")
local heldRoots = {}

local function holdCharacter(player, character)
	local root = character:WaitForChild("HumanoidRootPart", 15)
	if not root or player:GetAttribute("GBloxLobbyReady") then
		return
	end

	heldRoots[player] = { part = root, wasAnchored = root.Anchored }
	root.Anchored = true
end

local function setupPlayer(player)
	player:SetAttribute("GBloxLobbyReady", false)
	player.CharacterAdded:Connect(function(character)
		holdCharacter(player, character)
	end)
	if player.Character then
		task.spawn(holdCharacter, player, player.Character)
	end
end

enterLobby.OnServerEvent:Connect(function(player)
	if player:GetAttribute("GBloxLobbyReady") then
		return
	end

	local held = heldRoots[player]
	if held and held.part.Parent then
		held.part.Anchored = held.wasAnchored
	end
	heldRoots[player] = nil
	player:SetAttribute("GBloxLobbyReady", true)
end)

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(player)
	heldRoots[player] = nil
end)
for _, player in Players:GetPlayers() do
	setupPlayer(player)
end

