local now = 10
local passed = 0
local function check(value, message)
 assert(value, message)
 passed += 1
end
local function signal()
 local callbacks = {}
 return {
  Connect = function(_, callback)
   table.insert(callbacks, callback)
   local connected = true
   return { Disconnect = function() if connected then connected = false table.remove(callbacks, table.find(callbacks, callback)) end end }
  end,
  Fire = function(_, ...) for _, callback in ipairs(table.clone(callbacks)) do callback(...) end end,
 }
end
local function attrs(initial)
 local object = { values = initial or {}, signals = {} }
 function object:GetAttribute(name) return self.values[name] end
 function object:SetAttribute(name, value)
  if self.values[name] == value then return end
  self.values[name] = value
  if self.signals[name] then self.signals[name]:Fire() end
 end
 function object:GetAttributeChangedSignal(name)
  self.signals[name] = self.signals[name] or signal()
  return self.signals[name]
 end
 return object
end
local Players = { list = {}, PlayerAdded = signal(), PlayerRemoving = signal() }
function Players:GetPlayers() return self.list end
local state = attrs()
local voteRemote, sessionRemote = {}, {}
local ReplicatedStorage = {}
function ReplicatedStorage:WaitForChild(name)
 return ({ PlaygroundState = state, PlaygroundVoteRequest = voteRemote, PlaygroundSessionRequest = sessionRemote })[name]
end
local game = { GetService = function(_, name) return ({Players = Players, ReplicatedStorage = ReplicatedStorage, RunService = {}})[name] end }
local Random = { new = function() return {} end }
local os = { clock = function() return now end }
local task = { spawn = function() end }
local workspace = {GetServerTimeNow = function() return now end}
function Players:GetPlayerByUserId(id) for _, p in ipairs(self.list) do if p.UserId == id and p.Parent == self then return p end end end
local Coordinator = (function()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Coordinator = {}
Coordinator.__index = Coordinator
local games = { "BritishBulldog", "TagYoureIt", "StuckInTheMud" }
local titles = { BritishBulldog = "British Bulldog", TagYoureIt = "Tag You're It", StuckInTheMud = "Stuck in the Mud" }

function Coordinator.new(services, lobby, economy)
	local self = setmetatable({}, Coordinator)
	self.services = services
	self.lobby = lobby
	self.economy = economy
	self.zone = lobby.Gameplay.VoteZone
	self.state = ReplicatedStorage:WaitForChild("PlaygroundState")
	self.votes = {}
	self.lastVote = {}
	self.lastSessionRequest = {}
	self.sessionConnections = {}
	self.spectators = {}
	self.lastSpectateStamp = {}
	self.lastSpectateRequest = {}
	self.connections = {}
	self.running = false
	self.autoEnabled = true
	self.votingEndsAt = 0
	self.random = Random.new()
	self.lastGame = nil
	return self
end

function Coordinator:ActiveGame()
	for _, id in ipairs(games) do if self.services[id] and self.services[id].active then return id end end
	return nil
end

function Coordinator:_participating(player)
	return player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or player:GetAttribute("MDParticipating") == true
end

function Coordinator:_afkRequested(player)
	return player:GetAttribute("PCAFK") == true or player:GetAttribute("PCAFKRequested") == true
end

function Coordinator:_syncAFK(player)
	local requested = player:GetAttribute("PCAFKRequested") == true
	local participating = self:_participating(player)
	player:SetAttribute("PCAFK", requested and not participating)
	player:SetAttribute("PCAFKQueued", requested and participating)
	if participating then self:_clearSpectate(player) end
end

function Coordinator:_clearSpectate(player)
	local entry = self.spectators[player]
	if not entry then return end
	self.spectators[player] = nil
	pcall(player.RemoveReplicationFocus, player, entry.root)
end

function Coordinator:_spectateTarget(player, userId)
	if player.Parent ~= Players or self:_participating(player) then return nil end
	local active = self:ActiveGame()
	local service = active and self.services[active]
	local phase = service and service.state:GetAttribute("Phase")
	if not service or phase == "Waiting" or phase == "Results" or phase == "Intermission" then return nil end
	local target = Players:GetPlayerByUserId(userId)
	local attribute = ({ BritishBulldog = "BBParticipating", TagYoureIt = "TGParticipating", StuckInTheMud = "MDParticipating" })[active]
	local character = target and target.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if target == player or not target or not target:GetAttribute(attribute) or not humanoid or humanoid.Health <= 0 or not root then return nil end
	return target, root
end

function Coordinator:SetSpectate(player, userId, stamp)
	local now = workspace:GetServerTimeNow()
	if player.Parent ~= Players or typeof(stamp) ~= "number" or stamp ~= stamp or math.abs(stamp - now) > 30
		or stamp <= (self.lastSpectateStamp[player] or -math.huge) then return { ok = false, message = "Expired spectate request." } end
	self.lastSpectateStamp[player] = stamp
	if userId == 0 then self:_clearSpectate(player) return { ok = true } end
	if typeof(userId) ~= "number" or userId ~= userId or userId % 1 ~= 0 then return { ok = false, message = "Invalid player." } end
	if now - (self.lastSpectateRequest[player] or -math.huge) < 0.2 then return { ok = false, message = "Please wait a moment." } end
	self.lastSpectateRequest[player] = now
	local target, root = self:_spectateTarget(player, userId)
	if not target then self:_clearSpectate(player) return { ok = false, message = "That player is no longer in the round." } end
	local entry = self.spectators[player]
	if not entry or entry.root ~= root then
		self:_clearSpectate(player)
		local ok = pcall(player.AddReplicationFocus, player, root)
		if not ok then return { ok = false, message = "Could not load that arena. Try again." } end
		entry = { userId = userId, root = root }
		self.spectators[player] = entry
	end
	entry.expiresAt = now + 12
	return { ok = true, position = root.Position }
end

function Coordinator:_updateSpectators()
	local now = workspace:GetServerTimeNow()
	for player, entry in pairs(self.spectators) do
		local target, root = self:_spectateTarget(player, entry.userId)
		local ownHumanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not target or root ~= entry.root or now >= entry.expiresAt or not ownHumanoid or ownHumanoid.Health <= 0 then self:_clearSpectate(player) end
	end
end

function Coordinator:SetAFK(player, enabled)
	if player.Parent ~= Players or typeof(enabled) ~= "boolean" then
		return { ok = false, message = "Invalid AFK request." }
	end
	local now = os.clock()
	if now - (self.lastSessionRequest[player] or -math.huge) < 0.4 then
		return { ok = false, message = "Please wait a moment." }
	end
	self.lastSessionRequest[player] = now
	player:SetAttribute("PCAFKRequested", enabled)
	self:_syncAFK(player)
	if enabled then
		self.votes[player] = nil
		if self.padChoices then self.padChoices[player] = nil end
		player:SetAttribute("PCVote", "")
		self:_counts()
	end
	return {
		ok = true,
		afk = player:GetAttribute("PCAFK") == true,
		queued = player:GetAttribute("PCAFKQueued") == true,
		requested = enabled,
		message = enabled and (self:_participating(player) and "AFK after this round." or "AFK on. You will stay in the lobby.") or "AFK off. You can join the next round.",
	}
end

function Coordinator:_watchSessionPlayer(player)
	if self.sessionConnections[player] then return end
	player:SetAttribute("PCAFKRequested", false)
	player:SetAttribute("PCAFK", false)
	player:SetAttribute("PCAFKQueued", false)
	local connections = {}
	self.sessionConnections[player] = connections
	for _, name in ipairs({ "BBParticipating", "TGParticipating", "MDParticipating" }) do
		table.insert(connections, player:GetAttributeChangedSignal(name):Connect(function()
			self:_syncAFK(player)
		end))
	end
end

function Coordinator:_readyPlayers()
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and not self:_afkRequested(player) and not player:GetAttribute("BBParticipating") and not player:GetAttribute("TGParticipating") and not player:GetAttribute("MDParticipating") and player:GetAttribute("PCDataReady") == true then
			table.insert(list, player)
		end
	end
	return list
end

function Coordinator:MinimumPlayers(id)
	local service=self.services[id]
	local minimum=service and service.arena and service.arena:GetAttribute("MinimumPlayers")
	if typeof(minimum)~="number" or minimum~=minimum or math.abs(minimum)==math.huge then minimum=id=="StuckInTheMud" and 4 or 2 end
	return math.max(2,math.floor(minimum))
end

function Coordinator:GameAvailable(id, readyCount)
	local service=self.services[id]
	if not service then return false end
	if id=="StuckInTheMud" and service.state:GetAttribute("GunAccessReady")==false then return false end
	return (readyCount or #self:_readyPlayers())>=self:MinimumPlayers(id)
end

function Coordinator:_availability(readyCount)
	self.state:SetAttribute("ReadyPlayerCount",readyCount)
	for _,id in ipairs(games) do
	 self.state:SetAttribute("Available"..id,self:GameAvailable(id,readyCount))
	 if self.services[id] then self.state:SetAttribute("Minimum"..id,self:MinimumPlayers(id)) end
	end
end

function Coordinator:_insideZone(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local point = self.zone.CFrame:PointToObjectSpace(root.Position)
	local half = self.zone.Size / 2
	return math.abs(point.X) <= half.X and math.abs(point.Y) <= half.Y and math.abs(point.Z) <= half.Z
end

function Coordinator:_counts()
	local counts = { BritishBulldog = 0, TagYoureIt = 0, StuckInTheMud = 0 }
	for player, id in pairs(self.votes) do
		if player.Parent == Players and not self:_afkRequested(player) and counts[id] then counts[id] += 1 end
	end
	for id, count in pairs(counts) do self.state:SetAttribute("Votes" .. id, count) end
	return counts
end

function Coordinator:_clearVotes()
	for player in pairs(self.votes) do if player.Parent == Players then player:SetAttribute("PCVote", "") end end
	table.clear(self.votes)
	self:_counts()
end

function Coordinator:SetAutoEnabled(enabled)
	self.autoEnabled = enabled == true
	self.votingEndsAt = 0
	self.state:SetAttribute("AutomaticRounds", self.autoEnabled)
	self.state:SetAttribute("VotingEndsAt", 0)
	if not self:ActiveGame() then
		self.state:SetAttribute("Phase", self.autoEnabled and "Waiting" or "Paused")
		self:_clearVotes()
	end
end

function Coordinator:Vote(player, id)
	if typeof(id) ~= "string" or not self.services[id] then return { ok = false, message = "Choose an available game." } end
	if self.state:GetAttribute("Phase") ~= "Voting" or self:ActiveGame() or not self.autoEnabled then return { ok = false, message = "Voting opens between rounds." } end
	if self:_afkRequested(player) then return { ok = false, message = "Turn AFK off before voting." } end
	if player:GetAttribute("PCDataReady") ~= true then return { ok = false, message = "Your player data is loading." } end
	if not self:GameAvailable(id) then return {ok=false,message="This game is not ready for the next round."} end
	if player:GetAttribute("BBParticipating") or player:GetAttribute("TGParticipating") or player:GetAttribute("MDParticipating") or not self:_insideZone(player) then return { ok = false, message = "Walk into the voting area first." } end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return { ok = false, message = "Your character is loading." } end
	local now = os.clock()
	if now - (self.lastVote[player] or -math.huge) < 0.35 then return { ok = false, message = "Please wait a moment." } end
	self.lastVote[player] = now
	self.votes[player] = id
	player:SetAttribute("PCVote", id)
	self:_counts()
	return { ok = true, message = "Vote saved." }
end

function Coordinator:StartGame(id, player, role, automatic)
	local service = self.services[id]
	if not service then return false, "This game is not available yet." end
	if self:ActiveGame() then return false, "A game is running. Stop it first." end
	if role and (not player or self:_afkRequested(player)) then return false, "Turn AFK off before starting practice." end
	if not automatic then self:SetAutoEnabled(false) end
	self.votingEndsAt = 0
	self.state:SetAttribute("VotingEndsAt", 0)
	self:_clearVotes()
	local started, reason
	if role then started, reason = service:StartPractice(player, role)
	else started, reason = service:StartRound(self:_readyPlayers()) end
	if started then
		self.lastGame = id
		self.state:SetAttribute("ActiveGame", id)
		self.state:SetAttribute("GameTitle", titles[id])
		self.state:SetAttribute("Phase", "Playing")
	end
	return started, reason
end

function Coordinator:StopGame()
	local stopped = false
	for _, id in ipairs(games) do
		if self.services[id] and self.services[id].active then self.services[id]:StopRound() stopped = true end
	end
	self:SetAutoEnabled(false)
	self.state:SetAttribute("ActiveGame", "")
	self.state:SetAttribute("GameTitle", "")
	return true, stopped and "Back in the lobby." or "Ready in the lobby."
end

function Coordinator:_chooseGame()
	local counts = self:_counts()
	local readyCount=#self:_readyPlayers()
	local maximum = 0
	for _, id in ipairs(games) do if self:GameAvailable(id,readyCount) then maximum = math.max(maximum, counts[id]) end end
	local tied = {}
	for _, id in ipairs(games) do if self:GameAvailable(id,readyCount) and counts[id] == maximum then table.insert(tied, id) end end
	if maximum == 0 and self.lastGame then
		for _, id in ipairs(tied) do if id ~= self.lastGame then return id end end
	end
	return #tied>0 and tied[self.random:NextInteger(1, #tied)] or nil
end

function Coordinator:_rewardBulldog()
	local service = self.services.BritishBulldog
	if service.phase ~= "Results" then return end
	local state = service.state
	local team = state:GetAttribute("WinnerTeam")
	if team ~= "Runners" and team ~= "Bulldogs" then return end
	local winnerIds, participantIds = {}, {}
	for player, record in pairs(service.records) do
		if not record.isBot and record.participating and player.Parent == Players then
			table.insert(participantIds, player.UserId)
			if (team == "Runners" and record.role == "Runner") or (team == "Bulldogs" and record.role == "Bulldog") then table.insert(winnerIds, player.UserId) end
		end
	end
	table.sort(winnerIds)
	table.sort(participantIds)
	self.economy:AwardRound("BB:" .. tostring(state:GetAttribute("RoundNumber")), winnerIds, string.find(state:GetAttribute("Mode") or "", "Practice", 1, true) ~= nil, participantIds, { gameId = "BritishBulldog" })
end

function Coordinator:_rewardTag()
	local state = self.services.TagYoureIt.state
	local ids, participants = {}, {}
	for value in string.gmatch(state:GetAttribute("LastResultWinnerIds") or "", "%-?%d+") do table.insert(ids, tonumber(value)) end
	for value in string.gmatch(state:GetAttribute("LastResultParticipantIds") or "", "%-?%d+") do table.insert(participants, tonumber(value)) end
	self.economy:AwardRound("TAG:" .. tostring(state:GetAttribute("LastResultRound")), ids, state:GetAttribute("LastResultPractice") == true, participants, { gameId = "TagYoureIt" })
end

function Coordinator:_rewardMud()
 local service=self.services.StuckInTheMud
 if not service then return end
 local state=service.state
 local ids,participants={},{}
 for value in string.gmatch(state:GetAttribute("LastResultWinnerIds") or "", "%-?%d+") do table.insert(ids,tonumber(value)) end
 for value in string.gmatch(state:GetAttribute("LastResultParticipantIds") or "", "%-?%d+") do table.insert(participants,tonumber(value)) end
 self.economy:AwardRound("MUD:"..tostring(state:GetAttribute("LastResultRound")),ids,state:GetAttribute("LastResultPractice")==true,participants,{gameId="StuckInTheMud",winnerXP=50,loserXP=50})
end

function Coordinator:_padVoting()
 self.padChoices=self.padChoices or {}
 if self.state:GetAttribute("Phase")~="Voting" then table.clear(self.padChoices) return end
 local choices=self.lobby.Gameplay:FindFirstChild("VoteChoices")
 if not choices then return end
 for _,player in ipairs(Players:GetPlayers()) do
  local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  local choice
  if root and not self:_afkRequested(player) and self:_insideZone(player) then
   for _,pad in ipairs(choices:GetChildren()) do
    if pad:IsA("BasePart") and pad:GetAttribute("Available")~=false then
     local point=pad.CFrame:PointToObjectSpace(root.Position)
     local half=pad.Size/2
     if math.abs(point.X)<=half.X and math.abs(point.Y)<=half.Y and math.abs(point.Z)<=half.Z then choice=pad:GetAttribute("GameId") break end
    end
   end
  end
  if choice and not self:GameAvailable(choice) then choice=nil end
  if choice~=self.padChoices[player] then
   self.padChoices[player]=choice
   if choice then self:Vote(player,choice) end
  end
 end
end

function Coordinator:_loop()
	while self.running do
		self:_updateSpectators()
		local active = self:ActiveGame()
		local readyCount=#self:_readyPlayers()
		self:_availability(readyCount)
		local now = workspace:GetServerTimeNow()
		if active then
			self.votingEndsAt = 0
			self.state:SetAttribute("Phase", "Playing")
			self.state:SetAttribute("ActiveGame", active)
			self.state:SetAttribute("GameTitle", titles[active])
			self.state:SetAttribute("VotingEndsAt", 0)
		elseif not self.autoEnabled then
			self.state:SetAttribute("Phase", "Paused")
			self.state:SetAttribute("ActiveGame", "")
			self.state:SetAttribute("GameTitle", "")
		elseif readyCount < 2 then
			self.votingEndsAt = 0
			self.state:SetAttribute("Phase", "Waiting")
			self.state:SetAttribute("ActiveGame", "")
			self.state:SetAttribute("GameTitle", "")
			self.state:SetAttribute("VotingEndsAt", 0)
			self:_clearVotes()
		elseif self.votingEndsAt == 0 then
			self:_clearVotes()
			self.votingEndsAt = now + 35
			self.state:SetAttribute("Phase", "Voting")
			self.state:SetAttribute("ActiveGame", "")
			self.state:SetAttribute("VotingEndsAt", self.votingEndsAt)
		elseif now >= self.votingEndsAt then
			local selected = self:_chooseGame()
			self.votingEndsAt = 0
			local started = self:StartGame(selected, nil, nil, true)
			if not started then self.state:SetAttribute("Phase", "Waiting") end
		end
		self:_padVoting()
		task.wait(0.25)
	end
end

function Coordinator:Start()
	if self.running then return end
	self.running = true
	self.state:SetAttribute("AutomaticRounds", true)
	self.state:SetAttribute("Phase", "Waiting")
	self.state:SetAttribute("ActiveGame", "")
	self.state:SetAttribute("VotingEndsAt", 0)
	self:_counts()
	local remote = ReplicatedStorage:WaitForChild("PlaygroundVoteRequest")
	remote.OnServerInvoke = function(player, id) return self:Vote(player, id) end
	self.remote = remote
	local sessionRemote = ReplicatedStorage:WaitForChild("PlaygroundSessionRequest")
	sessionRemote.OnServerInvoke = function(player, action, value, stamp)
		if action == "SetSpectate" then return self:SetSpectate(player, value, stamp) end
		if action ~= "SetAFK" then return { ok = false, message = "Invalid session request." } end
		return self:SetAFK(player, value)
	end
	self.sessionRemote = sessionRemote
	table.insert(self.connections, Players.PlayerAdded:Connect(function(player) self:_watchSessionPlayer(player) end))
	for _, player in ipairs(Players:GetPlayers()) do self:_watchSessionPlayer(player) end
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player)
		self.votes[player] = nil
		self.lastVote[player] = nil
		self.lastSessionRequest[player] = nil
		self:_clearSpectate(player)
		self.lastSpectateStamp[player] = nil
		self.lastSpectateRequest[player] = nil
		for _, connection in ipairs(self.sessionConnections[player] or {}) do connection:Disconnect() end
		self.sessionConnections[player] = nil
		self:_counts()
	end))
	table.insert(self.connections, self.services.BritishBulldog.state:GetAttributeChangedSignal("Phase"):Connect(function() self:_rewardBulldog() end))
	table.insert(self.connections, self.services.TagYoureIt.state:GetAttributeChangedSignal("LastResultRound"):Connect(function() self:_rewardTag() end))
	if self.services.StuckInTheMud then table.insert(self.connections,self.services.StuckInTheMud.state:GetAttributeChangedSignal("LastResultRound"):Connect(function() self:_rewardMud() end)) end
	task.spawn(function() self:_loop() end)
end

function Coordinator:Stop()
	self.running = false
	self:StopGame()
	for _, connection in ipairs(self.connections) do connection:Disconnect() end
	if self.remote then self.remote.OnServerInvoke = nil end
	if self.sessionRemote then self.sessionRemote.OnServerInvoke = nil end
	for player in pairs(self.spectators) do self:_clearSpectate(player) end
	table.clear(self.lastSpectateStamp)
	table.clear(self.lastSpectateRequest)
	for player, connections in pairs(self.sessionConnections) do
		for _, connection in ipairs(connections) do connection:Disconnect() end
		if player.Parent == Players then
			player:SetAttribute("PCAFKRequested", false)
			player:SetAttribute("PCAFK", false)
			player:SetAttribute("PCAFKQueued", false)
		end
	end
	table.clear(self.sessionConnections)
	table.clear(self.lastSessionRequest)
end

return Coordinator




end)()
local function player(id)
 local result = attrs({ PCDataReady = true })
 result.UserId, result.Parent = id, Players
 result.Character = {Humanoid = {Health = 100}, HumanoidRootPart = {Position = {}}}
 function result.Character:FindFirstChildOfClass(name) return self.Humanoid end
 function result.Character:FindFirstChild(name) return self[name] end
 result.focuses = {}
 function result:AddReplicationFocus(root) self.focuses[root] = true end
 function result:RemoveReplicationFocus(root) self.focuses[root] = nil end
 table.insert(Players.list, result)
 return result
end
local one, two, three = player(1), player(2), player(3)
local seen
local services = {}
for _, name in ipairs({"BritishBulldog", "TagYoureIt", "StuckInTheMud"}) do
 services[name] = {
  active = false,
  arena = attrs({MinimumPlayers = 2}),
  state = attrs(),
  StartRound = function(_, ready) seen = ready return true end,
  StartPractice = function() return true end,
 }
end
local coordinator = Coordinator.new(services, {Gameplay = {VoteZone = {}}}, {})
coordinator._insideZone = function() return true end
coordinator:Start()
check(#coordinator:_readyPlayers() == 3, "All three eligible players should start ready")
check(not sessionRemote.OnServerInvoke(one, "Unknown", true).ok, "Unknown session action accepted")
check(not sessionRemote.OnServerInvoke(one, "SetAFK", "yes").ok, "Nonboolean AFK payload accepted")
state:SetAttribute("Phase", "Voting")
check(coordinator:Vote(one, "BritishBulldog").ok, "Ready player's vote rejected")
check(state:GetAttribute("VotesBritishBulldog") == 1, "Vote was not counted")
check(sessionRemote.OnServerInvoke(one, "SetAFK", true).ok, "Lobby AFK request rejected")
check(one:GetAttribute("PCAFK") and not one:GetAttribute("PCAFKQueued"), "Lobby AFK was not effective immediately")
check(#coordinator:_readyPlayers() == 2, "AFK player stayed ready")
check(state:GetAttribute("VotesBritishBulldog") == 0 and one:GetAttribute("PCVote") == "", "AFK player's vote remained counted")
check(not coordinator:Vote(one, "BritishBulldog").ok, "AFK player could vote")
check(not coordinator:StartGame("BritishBulldog", one, "Runner", false), "AFK player could enter admin practice")
check(coordinator:StartGame("BritishBulldog", nil, nil, true), "Eligible round failed")
check(#seen == 2 and not table.find(seen, one), "Automatic start selected AFK player")
check(not sessionRemote.OnServerInvoke(one, "SetAFK", false).ok, "AFK rate limit missing")
now += 1
check(sessionRemote.OnServerInvoke(one, "SetAFK", false).ok and #coordinator:_readyPlayers() == 3, "AFK off failed to restore eligibility")
two:SetAttribute("BBParticipating", true)
check(#coordinator:_readyPlayers() == 2, "Current participant was eligible for next round")
check(sessionRemote.OnServerInvoke(two, "SetAFK", true).ok, "Queued AFK request rejected")
check(two:GetAttribute("PCAFKQueued") and not two:GetAttribute("PCAFK"), "Midround AFK should queue")
check(two:GetAttribute("BBParticipating"), "AFK incorrectly removed current participant")
two:SetAttribute("BBParticipating", false)
check(two:GetAttribute("PCAFK") and not two:GetAttribute("PCAFKQueued"), "AFK did not activate when round ended")
check(#coordinator:_readyPlayers() == 2, "Queued AFK player rejoined next round")
three:SetAttribute("MDParticipating", true)
check(sessionRemote.OnServerInvoke(three, "SetAFK", true).ok, "Mud AFK queue failed")
now += 1
check(sessionRemote.OnServerInvoke(three, "SetAFK", false).ok, "Cancel queued AFK failed")
three:SetAttribute("MDParticipating", false)
check(not three:GetAttribute("PCAFK") and not three:GetAttribute("PCAFKQueued"), "Cancelled queued AFK reactivated")
two.Parent = nil
Players.PlayerRemoving:Fire(two)
check(coordinator.sessionConnections[two] == nil and coordinator.lastSessionRequest[two] == nil, "Leaving player retained session state")
coordinator:Stop()
check(sessionRemote.OnServerInvoke == nil, "Stop retained the AFK remote callback")
check(not one:GetAttribute("PCAFKRequested") and not three:GetAttribute("PCAFKRequested"), "Stop failed to clear session attributes")
print(string.format("%d AFK eligibility, voting, queue, rate-limit and lifecycle checks passed", passed))


services.TagYoureIt.active = true
services.TagYoureIt.state:SetAttribute("Phase", "Playing")
three:SetAttribute("TGParticipating", true)
now += 1
check(coordinator:SetSpectate(one, three.UserId, now).ok, "Valid distant target denied")
check(one.focuses[three.Character.HumanoidRootPart], "Target replication focus missing")
check(not coordinator:SetSpectate(one, three.UserId, now).ok, "Stale target request accepted")
now += 1
check(not coordinator:SetSpectate(one, one.UserId, now).ok, "Self spectate allowed")
check(next(one.focuses) == nil, "Invalid selection retained old focus")
now += 1
check(coordinator:SetSpectate(one, three.UserId, now).ok, "Second target focus failed")
now += 1
check(coordinator:SetSpectate(one, 0, now).ok and next(one.focuses) == nil, "Exit did not remove additional focus")
check(not coordinator:SetSpectate(one, three.UserId, now - 0.5).ok, "Late request refocused after exit")
now += 1
one:SetAttribute("BBParticipating", true)
check(not coordinator:SetSpectate(one, three.UserId, now).ok, "A round participant could spectate")
one:SetAttribute("BBParticipating", false)
now += 1
three.Character.Humanoid.Health = 0
check(not coordinator:SetSpectate(one, three.UserId, now).ok, "Dead target accepted")
three.Character.Humanoid.Health = 100
now += 1
check(coordinator:SetSpectate(one, three.UserId, now).ok, "Living target failed after recovery")
now += 13
coordinator:_updateSpectators()
check(next(one.focuses) == nil and coordinator.spectators[one] == nil, "Expired focus lease leaked")
now += 1
check(coordinator:SetSpectate(one, three.UserId, now).ok, "Focus failed before round-end check")
services.TagYoureIt.state:SetAttribute("Phase", "Results")
coordinator:_updateSpectators()
check(next(one.focuses) == nil, "Round results did not clear spectator focus")
check(not coordinator:SetSpectate(one, three.UserId, now + 1000).ok, "Forged future stamp accepted")
print(string.format("%d combined AFK and streaming-focus validation checks passed", passed))
