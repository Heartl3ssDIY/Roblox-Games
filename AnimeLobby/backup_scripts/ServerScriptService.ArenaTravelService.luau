local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ArenaConfig = require(ReplicatedStorage:WaitForChild("ArenaConfig"))
local events = ReplicatedStorage:WaitForChild("ArenaEvents")
local travel = events:FindFirstChild("TravelRequest") or Instance.new("RemoteFunction")
travel.Name = "TravelRequest"
travel.Parent = events

local visits = {}
local lastRequest = {}

local function getRoot(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return nil end
	return character:FindFirstChild("HumanoidRootPart")
end

local function moveRoot(root, target)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = target
end

local function lobbySpawn()
	local lobby = workspace:FindFirstChild("Lobby_MainModeZone")
	return lobby and lobby:FindFirstChild("MainModeSpawn", true)
end

local function leaveArena(player, root)
	local visit = visits[player]
	if visit and root == visit.root then
		moveRoot(root, visit.returnCFrame)
		root.Anchored = visit.wasAnchored
	end
	visits[player] = nil
	player:SetAttribute("ActiveArena", nil)
	return true
end

travel.OnServerInvoke = function(player, action)
	local root = getRoot(player)
	if action == "Leave" then return leaveArena(player, root) end
	if not root then return false, "Your character is not ready" end
	if action ~= "Enter" and action ~= "LobbyPortal" and action ~= "PackPortal" then return false, "Unknown destination" end
	local now = os.clock()
	if now - (lastRequest[player] or 0) < 0.4 then return false, "Please wait" end
	lastRequest[player] = now
	if action == "PackPortal" then
		if visits[player] then return false, "Leave the match first" end
		local lobby = workspace:FindFirstChild("Lobby_MainModeZone")
		local zone = lobby and lobby:FindFirstChild("Lobby_PackShopZone")
		local trigger = zone and zone:FindFirstChild("PackShopTrigger")
		if not trigger then return false, "Pack shop is unavailable" end
		moveRoot(root, trigger.CFrame)
		return true
	end

	if action == "LobbyPortal" then
		if visits[player] then return false, "Leave the match first" end
		local spawn = lobbySpawn()
		if not spawn then return false, "Lobby spawn is missing" end
		moveRoot(root, CFrame.lookAt(spawn.Position + Vector3.new(0, 3, 0), spawn.Position + Vector3.new(0, 3, -15)))
		return true
	end

	if visits[player] then return true end
	local arena = ArenaConfig.getArena()
	local sidelines = arena and arena:FindFirstChild("Sidelines")
	local spawn = sidelines and sidelines:FindFirstChild("Spawn_Player")
	if not spawn then return false, "Arena spawn is missing" end
	visits[player] = { root = root, returnCFrame = root.CFrame, wasAnchored = root.Anchored }
	root.Anchored = true
	moveRoot(root, spawn.CFrame * CFrame.new(0, 3, 0))
	player:SetAttribute("ActiveArena", ArenaConfig.arenaName)
	return true
end

local function setupPlayer(player)
	player.CharacterRemoving:Connect(function()
		leaveArena(player, getRoot(player))
	end)
end

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(player)
	visits[player] = nil
	lastRequest[player] = nil
end)
for _, player in ipairs(Players:GetPlayers()) do setupPlayer(player) end


