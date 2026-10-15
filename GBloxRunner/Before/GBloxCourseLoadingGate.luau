local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if game.PlaceId ~= 128350578096458 then return end

local loadedEvent = ReplicatedStorage:WaitForChild("GBloxCourseLoaded")
local heldRoots = {}

local function holdCharacter(player, character)
	local root = character:WaitForChild("HumanoidRootPart", 15)
	if not root or player:GetAttribute("GBloxCourseReady") then return end
	heldRoots[player] = { part = root, wasAnchored = root.Anchored }
	root.Anchored = true
end

local function setupPlayer(player)
	player:SetAttribute("GBloxCourseReady", false)
	player.CharacterAdded:Connect(function(character)
		holdCharacter(player, character)
	end)
	if player.Character then task.spawn(holdCharacter, player, player.Character) end
end

loadedEvent.OnServerEvent:Connect(function(player)
	if player:GetAttribute("GBloxCourseReady") then return end
	local held = heldRoots[player]
	if held and held.part.Parent then
		held.part.Anchored = held.wasAnchored
	end
	heldRoots[player] = nil
	player:SetAttribute("GBloxCourseReady", true)
end)

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(player)
	heldRoots[player] = nil
end)
for _, player in Players:GetPlayers() do setupPlayer(player) end

