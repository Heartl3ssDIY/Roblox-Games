-- Install as a Script in ServerScriptService/ProfilePersistence. Put its
-- sibling modules in the same folder. This is the only DataStore entry point.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Store = require(script.Parent.ProfileStore)
local Schema = require(script.Parent.ProfileSchema)
local Sync = require(script.Parent.ProfileSync)
local Actions = require(script.Parent.ProfileActions)
local UnitData = require(ReplicatedStorage:WaitForChild("UnitData"))
local SeasonPassData = require(ReplicatedStorage:WaitForChild("SeasonPassData"))
local ArenaConfig = require(ReplicatedStorage:WaitForChild("ArenaConfig"))

local studioMode = RunService:IsStudio()
local dataStoreName = studioMode and "ACU_PlayerProfile_StudioTest_v1" or "ACU_PlayerProfile_v1"
local backend = DataStoreService:GetDataStore(dataStoreName)
if studioMode then
	warn("[Profile] Studio Play saves persistently to " .. dataStoreName .. "; live player data is separate")
end

local remotes = ReplicatedStorage:FindFirstChild("ProfileRemotes")
if not remotes then remotes = Instance.new("Folder"); remotes.Name = "ProfileRemotes"; remotes.Parent = ReplicatedStorage end
local function remote(name, className)
	local object = remotes:FindFirstChild(name)
	if object then assert(object.ClassName == className, name .. " remote has wrong class"); return object end
	object = Instance.new(className)
	object.Name = name
	object.Parent = remotes
	return object
end
local bootstrap = remote("Bootstrap", "RemoteFunction")
local sync = remote("SyncPrototype", "RemoteFunction")
local matchTicket = remote("MatchTicket", "RemoteFunction")
local matchOutcome = remote("MatchOutcome", "RemoteFunction")
local action = remote("Action", "RemoteFunction")
local changed = remote("Changed", "RemoteEvent")

local store = Store.new(backend, {
	jobId = (game.JobId ~= "" and game.JobId or "studio") .. ":" .. HttpService:GenerateGUID(false),
	leaseSeconds = 180,
	onChanged = function(userId, snapshot)
		local player = Players:GetPlayerByUserId(userId)
		if player then changed:FireClient(player, snapshot) end
	end,
})
local loadErrors = {}
local tickets = {}
local syncSequence = {}

local function rewardAt(level, lane)
	return SeasonPassData.reward(level, lane)
end

local function result(ok, payload, player)
	if ok then return {ok = true, result = payload, snapshot = store:snapshot(player.UserId)} end
	return {ok = false, error = tostring(payload), snapshot = store:snapshot(player.UserId)}
end

local function ensureSaved(userId)
	for _ = 1, 12 do
		local ok, reason = store:save(userId, false)
		if ok then return true end
		if reason ~= "save already running" then return false, reason end
		task.wait(0.25)
	end
	return false, "save busy"
end

local function loadPlayer(player)
	player:SetAttribute("ProfileReady", false)
	player:SetAttribute("ProfileLoadError", nil)
	local ok, snapshotOrError = store:load(player.UserId)
	if not player.Parent then
		if ok then store:close(player.UserId) end
		return
	end
	if not ok then
		loadErrors[player.UserId] = snapshotOrError
		player:SetAttribute("ProfileLoadError", tostring(snapshotOrError))
		warn("[Profile] load failed for " .. player.UserId .. ": " .. tostring(snapshotOrError))
		return
	end
	loadErrors[player.UserId] = nil
	player:SetAttribute("ProfileReady", true)
	changed:FireClient(player, snapshotOrError)
end

bootstrap.OnServerInvoke = function(player)
	for _ = 1, 300 do
		if store:isReady(player.UserId) then return result(true, "ready", player) end
		if loadErrors[player.UserId] then return result(false, loadErrors[player.UserId], player) end
		task.wait(0.1)
	end
	return result(false, "profile load timed out", player)
end

sync.OnServerInvoke = function(player, sequence, report)
	if not store:isReady(player.UserId) then return result(false, "profile unavailable", player) end
	if type(sequence) ~= "number" or sequence ~= math.floor(sequence) or sequence < 1 then
		return result(false, "invalid sync sequence", player)
	end
	if sequence <= (syncSequence[player.UserId] or 0) then return result(true, "already synchronized", player) end
	if sequence > (syncSequence[player.UserId] or 0) + 1 then return result(false, "sync out of order", player) end
	local ok, payload = store:mutate(player.UserId, function(profile) return Sync.merge(profile, report, UnitData) end)
	if ok then syncSequence[player.UserId] = sequence end
	return result(ok, payload, player)
end

matchTicket.OnServerInvoke = function(player)
	if not store:isReady(player.UserId) then return result(false, "profile unavailable", player) end
	if player:GetAttribute("ActiveArena") ~= ArenaConfig.arenaName or player:GetAttribute("ArenaVisitOnly") == true then
		return result(false, "not in a playable arena", player)
	end
	local existing = tickets[player.UserId]
	if existing and not existing.reported and os.time() - existing.issuedAt < 3600 then
		return result(true, existing.id, player)
	end
	local snapshot = store:snapshot(player.UserId)
	if not snapshot or #snapshot.loadout ~= 4 then return result(false, "equip four units", player) end
	local ticket = {
		id = HttpService:GenerateGUID(false),
		arena = ArenaConfig.progressionKey,
		unitIds = snapshot.loadout,
		issuedAt = os.time(),
		reported = false,
	}
	tickets[player.UserId] = ticket
	return result(true, ticket.id, player)
end

matchOutcome.OnServerInvoke = function(player, ticketId, outcome)
	if not store:isReady(player.UserId) then return result(false, "profile unavailable", player) end
	local ticket = tickets[player.UserId]
	if not ticket or ticket.id ~= ticketId or os.time() - ticket.issuedAt > 3600 then
		return result(false, "missing or expired match ticket", player)
	end
	if outcome ~= "win" and outcome ~= "loss" and outcome ~= "forfeit" then return result(false, "invalid outcome", player) end
	-- The client currently simulates combat. This ticket prevents accidental
	-- duplicate grants but does not prove who won; move combat to server next.
	local ok, payload = store:mutate(player.UserId, function(profile)
		return Actions.awardMatch(profile, {
			ticket = ticket.id, arena = ticket.arena, unitIds = ticket.unitIds, outcome = outcome,
		}, rewardAt, UnitData, os.time())
	end)
	if not ok then return result(false, payload, player) end
	local saved, saveError = ensureSaved(player.UserId)
	if not saved then return result(false, "reward pending save: " .. tostring(saveError), player) end
	ticket.reported = true
	return result(true, payload, player)
end

action.OnServerInvoke = function(player, name, payload, actionId)
	if not store:isReady(player.UserId) then return result(false, "profile unavailable", player) end
	if type(actionId) ~= "string" or #actionId < 8 or #actionId > 128 then return result(false, "invalid action ID", player) end
	local ok, value = store:mutate(player.UserId, function(profile)
		return Actions.applyUnique(profile, actionId, name, function(current)
			if name == "LevelUnit" then
				return Actions.levelUnit(current, payload, UnitData)
			elseif name == "SetUnitLock" and type(payload) == "table" then
				return Actions.setUnitLock(current, payload.id, payload.locked, UnitData)
			elseif name == "SetLoadout" then
				return Actions.setLoadout(current, payload, UnitData)
			elseif name == "ConsumeDailyPack" then
				return Actions.consumeDailyPack(current)
			elseif name == "BoostMastery" then
				return Actions.boostMastery(current, payload, UnitData)
			end
			return false, "unknown action"
		end)
	end)
	if ok then
		local saved, reason = ensureSaved(player.UserId)
		if not saved then
			local pending = result(false, "action pending save: " .. tostring(reason), player)
			pending.retryable = true
			return pending
		end
	end
	local response = result(ok, value, player)
	if not ok and value == "profile busy" then response.retryable = true end
	return response
end

Players.PlayerAdded:Connect(function(player) task.spawn(loadPlayer, player) end)
Players.PlayerRemoving:Connect(function(player)
	local ok, reason = store:close(player.UserId)
	if not ok then
		warn("[Profile] final save retry queued for " .. player.UserId .. ": " .. tostring(reason))
		task.spawn(function()
			while store.entries[player.UserId] do
				task.wait(3)
				local released, retryReason = store:close(player.UserId)
				if released then break end
				warn("[Profile] final save still pending for " .. player.UserId .. ": " .. tostring(retryReason))
			end
		end)
	end
	tickets[player.UserId] = nil
	syncSequence[player.UserId] = nil
	loadErrors[player.UserId] = nil
end)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(loadPlayer, player) end

task.spawn(function()
	while true do
		task.wait(45)
		local ok, errors = store:saveAll(false)
		if not ok then for userId, reason in pairs(errors) do warn("[Profile] autosave failed for " .. userId .. ": " .. tostring(reason)) end end
	end
end)

game:BindToClose(function()
	local deadline = os.clock() + 25
	repeat
		local ok = store:saveAll(true)
		if ok then return end
		task.wait(1)
	until os.clock() >= deadline
	warn("[Profile] shutdown save deadline exceeded")
end)

