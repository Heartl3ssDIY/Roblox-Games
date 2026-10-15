local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalizationService = game:GetService("LocalizationService")
local BritishBulldog = require(ServerScriptService:WaitForChild("BritishBulldogService"))
local Tag = require(ServerScriptService:WaitForChild("TagService"))
local Mud = require(ServerScriptService:WaitForChild("StuckInTheMudService"))
local TagSprint = require(ServerScriptService:WaitForChild("TagSprintService"))
local Economy = require(ServerScriptService:WaitForChild("PlaygroundEconomyService"))
local Coordinator = require(ServerScriptService:WaitForChild("PlaygroundCoordinator"))
local Admin = require(ServerScriptService:WaitForChild("PlaygroundAdminService"))

local lobby = workspace:WaitForChild("Playground Lobby")
local britishBulldog = BritishBulldog.new(workspace:WaitForChild("British Bulldog game"))
local tag = Tag.new(workspace:WaitForChild("Tag You're It"))
local mud = Mud.new(workspace:WaitForChild("Stuck in the Mud"))
local tagSprint = TagSprint.new(tag)
local spawn = lobby.Gameplay.LobbySpawn
britishBulldog.lobbySpawn = spawn
tag.lobbySpawn = spawn
mud.lobbySpawn = spawn
britishBulldog:Start()
tag:Start()
mud:Start()
tagSprint:Start()
local economy = Economy.new(lobby)
local leaderboardModule = ServerScriptService:FindFirstChild("PlaygroundLeaderboardService")
if leaderboardModule and lobby:FindFirstChild("Leaderboards") then
	local ok, result = pcall(function()
		local Leaderboards = require(leaderboardModule)
		local Regions = require(ServerScriptService:WaitForChild("PlaygroundRegions"))
		return Leaderboards.new(lobby, {
			resolveRegion = function(player)
				return Regions.Resolve(LocalizationService:GetCountryRegionForPlayerAsync(player))
			end,
		}):Start()
	end)
	if ok then
		economy.leaderboards = result
		local request = ReplicatedStorage:WaitForChild("PlaygroundLeaderboardRequest")
		local requests = {}
		local scopes = { global = true, server = true, region = true }
		request.OnServerInvoke = function(player, scope)
			if player.Parent ~= Players or type(scope) ~= "string" or not scopes[scope] then
				return { state = "unavailable", status = "INVALID REQUEST" }
			end
			local now = os.clock()
			local rate = requests[player]
			if not rate or now - rate.started >= 5 then
				rate = { started = now, count = 0 }
				requests[player] = rate
			end
			if rate.count >= 10 then
				return { scope = scope, state = "loading", status = "PLEASE WAIT", retryAfter = 5 }
			end
			rate.count += 1
			local succeeded, snapshot = pcall(result.GetSnapshot, result, player, scope)
			if succeeded then return snapshot end
			warn("Leaderboard request failed: " .. tostring(snapshot))
			return { scope = scope, state = "unavailable", status = "RANKINGS UNAVAILABLE", retryAfter = 10 }
		end
		local leaving = Players.PlayerRemoving:Connect(function(player)
			requests[player] = nil
		end)
		script.Destroying:Connect(function()
			request.OnServerInvoke = nil
			leaving:Disconnect()
			table.clear(requests)
			result:Stop()
		end)
	else
		warn("Lobby leaderboards could not start: " .. tostring(result))
	end
end
economy:Start()
local Equipment = require(ServerScriptService:WaitForChild("PlaygroundEquipmentService"))
local equipment = Equipment.new({ BritishBulldog = britishBulldog, TagYoureIt = tag }):Start()
script.Destroying:Connect(function() equipment:Stop() end)
local coordinator = Coordinator.new({ BritishBulldog = britishBulldog, TagYoureIt = tag, StuckInTheMud = mud }, lobby, economy)
coordinator:Start()
local admin = Admin.Start(coordinator)
script:SetAttribute("Ready", true)

