local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ArenaCatalog = require(ReplicatedStorage:WaitForChild("ArenaCatalog"))
local ArenaConfig = require(ReplicatedStorage:WaitForChild("ArenaConfig"))
local LobbyConfig = require(ReplicatedStorage:WaitForChild("LobbyConfig"))
local events = ReplicatedStorage:WaitForChild("ArenaEvents")
local travel = events:WaitForChild("TravelRequest")
assert(travel:IsA("RemoteFunction"), "ArenaEvents.TravelRequest must be a RemoteFunction")

local visits = {}
local lastRequest = {}
local actions = { Enter = true, Visit = true, Leave = true, LobbyPortal = true, PackPortal = true, Destination = true }

local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function numberSetting(key, fallback)
	local value = LobbyConfig[key]
	return finite(value) and value >= 0 and value or fallback
end

local function validName(value)
	return type(value) == "string" and #value > 0 and #value <= 128
end

local function getCharacter(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then return nil end
	return root, humanoid
end

local function moveRoot(root, target)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = target
end

local function rootClearance(root, humanoid)
	local fallback = numberSetting("RootClearance", 3.5)
	local halfRoot = root.Size.Y * 0.5
	local hipHeight = humanoid.HipHeight
	if not finite(halfRoot) or halfRoot <= 0 or not finite(hipHeight) or hipHeight < 0 then return fallback end
	if humanoid.RigType == Enum.HumanoidRigType.R6 and hipHeight <= 0.001 then
		local leg = root.Parent:FindFirstChild("Right Leg") or root.Parent:FindFirstChild("Left Leg")
		if not leg or not leg:IsA("BasePart") or not finite(leg.Size.Y) or leg.Size.Y <= 0 then return fallback end
		return halfRoot + leg.Size.Y
	end
	return halfRoot + hipHeight
end

local function lobbyRoot()
	local name = LobbyConfig.RootName
	return validName(name) and workspace:FindFirstChild(name) or nil
end

local function markerAt(lobby, name)
	if not validName(name) then return nil end
	local markers = lobby:FindFirstChild("Markers")
	local marker = markers and markers:FindFirstChild(name)
	return marker and marker:IsA("BasePart") and marker or nil
end

local function finitePosition(position)
	return finite(position.X) and finite(position.Y) and finite(position.Z)
end

local function lobbyTarget(root, humanoid, destination)
	local definitions = LobbyConfig.Destinations
	local entry = type(definitions) == "table" and definitions[destination] or nil
	if type(entry) ~= "table" or not validName(entry.marker) then return nil, "Unknown destination" end
	if entry.lookAt ~= nil and not validName(entry.lookAt) then return nil, "Destination is unavailable" end
	local lobby = lobbyRoot()
	if not lobby then return nil, "Lobby is unavailable" end
	local marker = markerAt(lobby, entry.marker)
	if not marker or not finitePosition(marker.Position) then return nil, "Destination is unavailable" end
	local lookAt = entry.lookAt and markerAt(lobby, entry.lookAt) or nil
	if entry.lookAt and (not lookAt or not finitePosition(lookAt.Position)) then
		return nil, "Destination is unavailable"
	end
	local floor = marker.Position
	local position = floor + Vector3.new(0, rootClearance(root, humanoid) + numberSetting("SafeLandingOffset", 0.12), 0)
	local direction = lookAt and lookAt.Position - floor or marker.CFrame.LookVector
	direction = Vector3.new(direction.X, 0, direction.Z)
	if direction.Magnitude <= 0.001 then
		direction = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	end
	if direction.Magnitude <= 0.001 then direction = Vector3.new(0, 0, -1) end
	return CFrame.lookAt(position, position + direction.Unit)
end

local function clearVisit(player, root, returnToLobby)
	local visit = visits[player]
	if visit then
		local visitedRoot = visit.root
		if visitedRoot.Parent then
			if returnToLobby and root == visitedRoot then moveRoot(visitedRoot, visit.returnCFrame) end
			visitedRoot.Anchored = visit.wasAnchored
		end
	end
	visits[player] = nil
	player:SetAttribute("ActiveArena", nil)
	player:SetAttribute("ArenaVisitOnly", nil)
end

local function arenaEntry(destination)
	if destination == nil then destination = ArenaConfig.arenaName end
	if not validName(destination) and not (finite(destination) and destination >= 1 and destination % 1 == 0) then
		return nil
	end
	return ArenaCatalog.find(destination)
end

travel.OnServerInvoke = function(player, action, destination)
	if type(action) ~= "string" or not actions[action] then return false, "Unknown destination" end
	if action == "Leave" then
		if destination ~= nil then return false, "Unknown destination" end
		clearVisit(player, getCharacter(player), true)
		return true
	end
	local destinationKey
	local entry
	if action == "Destination" then
		if not validName(destination) then return false, "Unknown destination" end
		destinationKey = destination
	elseif action == "LobbyPortal" or action == "PackPortal" then
		if destination ~= nil then return false, "Unknown destination" end
		destinationKey = action == "LobbyPortal" and "MainMode" or "Packs"
	else
		entry = arenaEntry(destination)
		if not entry then return false, "Unknown arena" end
	end
	local root, humanoid = getCharacter(player)
	if not root then return false, "Your character is not ready" end
	local visit = visits[player]
	if visit then
		if entry and visit.root == root and visit.arenaName == entry.modelName and visit.action == action then
			return true
		end
		return false, "Leave the match first"
	end
	local now = os.clock()
	local previous = lastRequest[player]
	if previous and now - previous < numberSetting("RequestCooldown", 0.4) then return false, "Please wait" end
	if destinationKey then
		local target, message = lobbyTarget(root, humanoid, destinationKey)
		if not target then return false, message end
		moveRoot(root, target)
		lastRequest[player] = now
		return true
	end
	local arena = ArenaConfig.getArena(entry.modelName)
	if not arena or arena:GetAttribute("TeleportReady") ~= true then return false, "Arena is unavailable" end
	if action == "Enter" and arena:GetAttribute("MatchReady") ~= true then
		return false, "This arena is available for visits only"
	end
	local sidelines = arena:FindFirstChild("Sidelines")
	local spawn = sidelines and sidelines:FindFirstChild("Spawn_Player")
	if not spawn or not spawn:IsA("BasePart") or not finitePosition(spawn.Position) then
		return false, "Arena spawn is missing"
	end
	local target = spawn.CFrame * CFrame.new(0, 3, 0)
	visits[player] = {
		root = root, returnCFrame = root.CFrame, wasAnchored = root.Anchored,
		arenaName = entry.modelName, action = action,
	}
	root.Anchored = action == "Enter"
	moveRoot(root, target)
	player:SetAttribute("ActiveArena", arena.Name)
	player:SetAttribute("ArenaVisitOnly", action == "Visit")
	lastRequest[player] = now
	return true
end

local function setupPlayer(player)
	player.CharacterRemoving:Connect(function()
		clearVisit(player, nil, false)
		lastRequest[player] = nil
	end)
end

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(player)
	clearVisit(player, nil, false)
	lastRequest[player] = nil
end)
for _, player in ipairs(Players:GetPlayers()) do setupPlayer(player) end