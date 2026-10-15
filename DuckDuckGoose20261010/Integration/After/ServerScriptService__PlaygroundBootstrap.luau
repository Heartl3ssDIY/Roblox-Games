local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalizationService = game:GetService("LocalizationService")
local BritishBulldog = require(ServerScriptService:WaitForChild("BritishBulldogService"))
local Tag = require(ServerScriptService:WaitForChild("TagService"))
local Mud = require(ServerScriptService:WaitForChild("StuckInTheMudService"))
local HideAndSeek = require(ServerScriptService:WaitForChild("HideAndSeekService"))
local DuckDuckGoose = require(ServerScriptService:WaitForChild("DuckDuckGooseService"))
local TagSprint = require(ServerScriptService:WaitForChild("TagSprintService"))
local Economy = require(ServerScriptService:WaitForChild("PlaygroundEconomyService"))
local Coordinator = require(ServerScriptService:WaitForChild("PlaygroundCoordinator"))
local Admin = require(ServerScriptService:WaitForChild("PlaygroundAdminService"))

local lobby = workspace:WaitForChild("Playground Lobby")
local britishBulldog = BritishBulldog.new(workspace:WaitForChild("British Bulldog game"))
local tag = Tag.new(workspace:WaitForChild("Tag You're It"))
local mud = Mud.new(workspace:WaitForChild("Stuck in the Mud"))
local hideAndSeek = HideAndSeek.new(workspace:WaitForChild("Hide and Seek"))
local duckDuckGoose = DuckDuckGoose.new(workspace:WaitForChild("Duck Duck Goose"))
local tagSprint = TagSprint.new(tag)
local spawn = lobby.Gameplay.LobbySpawn
britishBulldog.lobbySpawn = spawn
tag.lobbySpawn = spawn
mud.lobbySpawn = spawn
hideAndSeek.lobbySpawn = spawn
duckDuckGoose.lobbySpawn = spawn
britishBulldog:Start()
tag:Start()
mud:Start()
hideAndSeek:Start()
duckDuckGoose:Start()
script.Destroying:Connect(function() duckDuckGoose:Stop() end)
script.Destroying:Connect(function() hideAndSeek:Stop() end)
tagSprint:Start()
local Push = require(ServerScriptService:WaitForChild("PlaygroundPushService"))
local push = Push.new(britishBulldog, tag):Start()
script.Destroying:Connect(function() push:Stop() end)
local economy = Economy.new(lobby)
local leaderboardModule = ServerScriptService:FindFirstChild("PlaygroundLeaderboardService")
if leaderboardModule and lobby:FindFirstChild("Leaderboards") then
	local ok, result = pcall(function()
		local Leaderboards = require(leaderboardModule)
		local Regions = require(ServerScriptService:WaitForChild("PlaygroundRegions"))
		return Leaderboards.new(lobby, {
			resolveEmote = function(userId) return economy:GetPodiumEmote(userId) end,
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
local lobbyActivities = {}
local function startLobbyActivity(name, create)
	local ok, activity = pcall(function() return create(require(ServerScriptService:FindFirstChild(name))) end)
	if ok then table.insert(lobbyActivities, activity) else warn("Lobby activity unavailable: " .. name .. " - " .. tostring(activity)) end
end
startLobbyActivity("PlaygroundSecretObbyService", function(module)
	return module.new(lobby.SecretCaveObby, lobby.Improvements20261003.CaveAlcove.SecretPassage, economy):Start()
end)
startLobbyActivity("PlaygroundLobbySwingService", function(module) return module.Start() end)
startLobbyActivity("PlaygroundLobbyBenchService", function(module) return module.Start() end)
startLobbyActivity("PlaygroundCommerceService", function(module) return module.new(economy):Start() end)
startLobbyActivity("PlaygroundFishingService", function(module) return module.new(lobby.PondFishing, economy):Start() end)
script.Destroying:Connect(function()
	for _, activity in lobbyActivities do activity:Stop() end
end)
local Equipment = require(ServerScriptService:WaitForChild("PlaygroundEquipmentService"))
local Toys = require(ServerScriptService:WaitForChild("PlaygroundToyService"))
local toys = Toys.new({ playBonk = function(position)
	local template = ReplicatedStorage:FindFirstChild("ToyBonk")
	if not template or not template:IsA("Sound") then return end
	local anchor = Instance.new("Part")
	anchor.Name, anchor.Size, anchor.Position = "ToyBonkSound", Vector3.new(0.1, 0.1, 0.1), position
	anchor.Anchored, anchor.CanCollide, anchor.CanTouch, anchor.CanQuery, anchor.Transparency = true, false, false, false, 1
	anchor.Parent = workspace
	local sound = template:Clone()
	sound.Volume, sound.RollOffMaxDistance, sound.Parent = 0.4, 50, anchor
	sound:Play()
	game:GetService("Debris"):AddItem(anchor, 4)
end }):Start()
local equipment = Equipment.new({ BritishBulldog = britishBulldog, TagYoureIt = tag, HideAndSeek = hideAndSeek, DuckDuckGoose = duckDuckGoose }, toys):Start()
for service, methodName in pairs({ [britishBulldog] = "_beginRound", [tag] = "_begin", [mud] = "_begin", [hideAndSeek] = "_begin", [duckDuckGoose] = "_begin" }) do
	local original = service[methodName]
	service[methodName] = function(instance, selected, ...)
		equipment:PrepareRound(selected)
		return original(instance, selected, ...)
	end
end
local toyRequest = ReplicatedStorage:WaitForChild("PlaygroundToyRequest")
local toyRequests = {}
toyRequest.OnServerInvoke = function(player, action, aim)
	if player.Parent ~= Players or action ~= "Use" then return { ok = false, message = "Invalid toy request." } end
	local current = os.clock()
	if current - (toyRequests[player] or -math.huge) < 0.1 then return { ok = false, message = "Please wait." } end
	toyRequests[player] = current
	return equipment:UseToy(player, aim)
end
local toyLeaving = Players.PlayerRemoving:Connect(function(player) toyRequests[player] = nil end)
script.Destroying:Connect(function()
	toyRequest.OnServerInvoke = nil
	toyLeaving:Disconnect()
	equipment:Stop()
	toys:Stop()
end)
local coordinator = Coordinator.new({ BritishBulldog = britishBulldog, TagYoureIt = tag, StuckInTheMud = mud, HideAndSeek = hideAndSeek, DuckDuckGoose = duckDuckGoose }, lobby, economy)
coordinator:Start()
local admin = Admin.Start(coordinator)
script:SetAttribute("Ready", true)