local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

local MAIN_PLACE_ID = 74498603638770
local TUTORIAL_PLACE_ID = 128350578096458
local progressStore = DataStoreService:GetDataStore("GBloxPlayerProgress_v1")
local tutorialGate = ReplicatedStorage:WaitForChild("GBloxTutorialGate")
local lastRequest = {}

local function readTutorialCompletion(player)
	if RunService:IsStudio() then return true, true end
	for attempt = 1, 2 do
		local success, progress = pcall(function()
			return progressStore:GetAsync("player_" .. player.UserId)
		end)
		if success then
			return true, type(progress) == "table"
				and progress.TutorialCompleted == true
		end
		if attempt == 1 then task.wait(0.5) end
	end
	return false, false
end

tutorialGate.OnServerInvoke = function(player)
	if game.PlaceId ~= MAIN_PLACE_ID then return "Unavailable" end
	local now = os.clock()
	if now - (lastRequest[player] or 0) < 1 then return "Busy" end
	lastRequest[player] = now

	local loaded, completed = readTutorialCompletion(player)
	if not loaded then return "Unavailable" end
	if completed then return "Completed" end

	local options = Instance.new("TeleportOptions")
	options:SetTeleportData({ FromGBloxMenu = true, HumanCount = 1 })
	local success = pcall(function()
		TeleportService:TeleportAsync(TUTORIAL_PLACE_ID, { player }, options)
	end)
	return success and "Teleporting" or "Unavailable"
end

Players.PlayerRemoving:Connect(function(player)
	lastRequest[player] = nil
end)
