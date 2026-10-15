assert(not game:GetService("RunService"):IsRunning(),"Edit only")
local fixture=Instance.new("Folder") fixture.Name="SkippingRopeIntegrationFixture" fixture.Parent=game.ServerStorage
local ok,result=xpcall(function()
local CoordinatorFixtureModule=game.ServerScriptService.PlaygroundCoordinator:Clone()
CoordinatorFixtureModule.Name="CoordinatorFixture"
CoordinatorFixtureModule.Source=[======[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Coordinator = {}
Coordinator.__index = Coordinator
local games = { "BritishBulldog", "TagYoureIt", "StuckInTheMud", "HideAndSeek", "DuckDuckGoose", "SkippingRope" }
local INTERMISSION_SECONDS = 35
local START_RETRY_SECONDS = 5
local titles = { BritishBulldog = "British Bulldog", TagYoureIt = "Tag You're It", StuckInTheMud = "Stuck in the Mud", HideAndSeek = "Hide and Seek", DuckDuckGoose = "Duck Duck Goose", SkippingRope = "Skipping Rope" }

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
	self.startRetryAt = 0
	self.random = Random.new()
	self.lastGame = nil
	return self
end

function Coordinator:ActiveGame()
	for _, id in ipairs(games) do if self.services[id] and self.services[id].active then return id end end
	return nil
end

function Coordinator:_participating(player)
	return player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or player:GetAttribute("MDParticipating") == true or player:GetAttribute("HSParticipating") == true or player:GetAttribute("DGParticipating") == true or player:GetAttribute("SKParticipating") == true or player:GetAttribute("SKEliminated") == true
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
	local attribute = ({ BritishBulldog = "BBParticipating", TagYoureIt = "TGParticipating", StuckInTheMud = "MDParticipating", HideAndSeek = "HSParticipating", DuckDuckGoose = "DGParticipating", SkippingRope = "SKParticipating" })[active]
	local character = target and target.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if target == player or not target or not target:GetAttribute(attribute) or not humanoid or humanoid.Health <= 0 or not root then return nil end
	if active == "SkippingRope" and target:GetAttribute("SKEliminated") == true then return nil end
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
	for _, name in ipairs({ "BBParticipating", "TGParticipating", "MDParticipating", "HSParticipating", "DGParticipating", "SKParticipating", "SKEliminated" }) do
		table.insert(connections, player:GetAttributeChangedSignal(name):Connect(function()
			self:_syncAFK(player)
		end))
	end
end

function Coordinator:_readyPlayers()
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and not self:_afkRequested(player) and not self:_participating(player) and player:GetAttribute("PCDataReady") == true then
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
	if not service or service.running == false then return false end
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
	local counts = { BritishBulldog = 0, TagYoureIt = 0, StuckInTheMud = 0, HideAndSeek = 0, DuckDuckGoose = 0, SkippingRope = 0 }
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
	self.startRetryAt = 0
	self.state:SetAttribute("LastRoundStartError", "")
	self.state:SetAttribute("IntermissionStatus", self.autoEnabled and "Waiting for ready players" or "Automatic rounds paused by an admin")
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
	if self:_participating(player) or not self:_insideZone(player) then return { ok = false, message = "Walk into the voting area first." } end
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
	local started, reason
	if role and not service.StartPractice then return false, "This game requires a normal round." end
	if role then started, reason = service:StartPractice(player, role)
	else started, reason = service:StartRound(self:_readyPlayers()) end
	if started then
		self.votingEndsAt = 0
		self.startRetryAt = 0
		self.state:SetAttribute("VotingEndsAt", 0)
		self.state:SetAttribute("LastRoundStartError", "")
		self.state:SetAttribute("IntermissionStatus", "")
		self:_clearVotes()
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
	if maximum == 0 and self.lastGame and #tied > 1 then
		local previous = table.find(tied, self.lastGame)
		if previous then table.remove(tied, previous) end
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

function Coordinator:_rewardHideAndSeek()
 local service = self.services.HideAndSeek
 if not service then return end
 local state = service.state
 local ids, participants = {}, {}
 for value in string.gmatch(state:GetAttribute("LastResultWinnerIds") or "", "%-?%d+") do table.insert(ids, tonumber(value)) end
 for value in string.gmatch(state:GetAttribute("LastResultParticipantIds") or "", "%-?%d+") do table.insert(participants, tonumber(value)) end
 self.economy:AwardRound("HS:" .. tostring(state:GetAttribute("LastResultRound")), ids, state:GetAttribute("LastResultPractice") == true, participants, { gameId = "HideAndSeek" })
end

function Coordinator:_rewardDuckDuckGoose()
 local service = self.services.DuckDuckGoose
 if not service then return end
 local state = service.state
 local ids, participants = {}, {}
 for value in string.gmatch(state:GetAttribute("LastResultWinnerIds") or "", "%-?%d+") do table.insert(ids, tonumber(value)) end
 for value in string.gmatch(state:GetAttribute("LastResultParticipantIds") or "", "%-?%d+") do table.insert(participants, tonumber(value)) end
 self.economy:AwardRound("DG:" .. tostring(state:GetAttribute("LastResultRound")), ids, state:GetAttribute("LastResultPractice") == true, participants, { gameId = "DuckDuckGoose" })
end

function Coordinator:_rewardSkippingRope()
 local service = self.services.SkippingRope
 if not service then return end
 local state = service.state
 local ids, participants = {}, {}
 for value in string.gmatch(state:GetAttribute("LastResultWinnerIds") or "", "%-?%d+") do table.insert(ids, tonumber(value)) end
 for value in string.gmatch(state:GetAttribute("LastResultParticipantIds") or "", "%-?%d+") do table.insert(participants, tonumber(value)) end
 self.economy:AwardRound("SK:" .. tostring(state:GetAttribute("LastResultRound")), ids, state:GetAttribute("LastResultPractice") == true, participants, { gameId = "SkippingRope" })
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

function Coordinator:_step(now)
	self:_updateSpectators()
	local active = self:ActiveGame()
	local readyCount = #self:_readyPlayers()
	self:_availability(readyCount)
	local minimum, available = math.huge, false
	for _, id in ipairs(games) do
		local service = self.services[id]
		if service and service.running ~= false and not (id == "StuckInTheMud" and service.state:GetAttribute("GunAccessReady") == false) then
			minimum = math.min(minimum, self:MinimumPlayers(id))
			available = available or self:GameAvailable(id, readyCount)
		end
	end
	if minimum == math.huge then minimum = 2 end
	self.state:SetAttribute("MinimumReadyPlayers", minimum)
	if active then
		self.votingEndsAt, self.startRetryAt = 0, 0
		self.state:SetAttribute("Phase", "Playing")
		self.state:SetAttribute("ActiveGame", active)
		self.state:SetAttribute("GameTitle", titles[active])
		self.state:SetAttribute("VotingEndsAt", 0)
		self.state:SetAttribute("IntermissionStatus", "")
	elseif not self.autoEnabled then
		self.state:SetAttribute("Phase", "Paused")
		self.state:SetAttribute("ActiveGame", "")
		self.state:SetAttribute("GameTitle", "")
		self.state:SetAttribute("IntermissionStatus", "Automatic rounds paused by an admin")
	elseif not available then
		self.votingEndsAt, self.startRetryAt = 0, 0
		self.state:SetAttribute("Phase", "Waiting")
		self.state:SetAttribute("ActiveGame", "")
		self.state:SetAttribute("GameTitle", "")
		self.state:SetAttribute("VotingEndsAt", 0)
		self.state:SetAttribute("IntermissionStatus", readyCount < minimum
			and string.format("Waiting for ready players (%d/%d)", readyCount, minimum)
			or "Waiting for an available game")
		self:_clearVotes()
	elseif self.votingEndsAt == 0 then
		self:_clearVotes()
		self.votingEndsAt = now + INTERMISSION_SECONDS
		self.state:SetAttribute("Phase", "Voting")
		self.state:SetAttribute("ActiveGame", "")
		self.state:SetAttribute("GameTitle", "")
		self.state:SetAttribute("VotingEndsAt", self.votingEndsAt)
		self.state:SetAttribute("IntermissionStatus", "Next round starts in")
		self.state:SetAttribute("LastRoundStartError", "")
	elseif now >= self.votingEndsAt and now >= self.startRetryAt then
		local selected = self:_chooseGame()
		local ok, started, reason = pcall(self.StartGame, self, selected, nil, nil, true)
		if not ok or not started then
			local failure = tostring(ok and reason or started)
			self.startRetryAt = now + START_RETRY_SECONDS
			self.state:SetAttribute("IntermissionStatus", "Preparing the next round - retrying")
			self.state:SetAttribute("LastRoundStartError", failure)
			warn("Automatic round could not start: " .. failure)
		end
	end
	self:_padVoting()
end

function Coordinator:_loop()
	while self.running do
		self:_step(workspace:GetServerTimeNow())
		task.wait(0.25)
	end
end

function Coordinator:Start()
	if self.running then return end
	self.running = true
	self.state:SetAttribute("AutomaticRounds", self.autoEnabled)
	self.state:SetAttribute("IntermissionSeconds", INTERMISSION_SECONDS)
	self.state:SetAttribute("MinimumReadyPlayers", 2)
	self.state:SetAttribute("IntermissionStatus", "Waiting for ready players")
	self.state:SetAttribute("LastRoundStartError", "")
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
	if self.services.HideAndSeek then table.insert(self.connections, self.services.HideAndSeek.state:GetAttributeChangedSignal("LastResultRound"):Connect(function() self:_rewardHideAndSeek() end)) end
	if self.services.DuckDuckGoose then table.insert(self.connections, self.services.DuckDuckGoose.state:GetAttributeChangedSignal("LastResultRound"):Connect(function() self:_rewardDuckDuckGoose() end)) end
	if self.services.SkippingRope then table.insert(self.connections, self.services.SkippingRope.state:GetAttributeChangedSignal("LastResultRound"):Connect(function() self:_rewardSkippingRope() end)) end
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

return {Coordinator=Coordinator,SetPlayers=function(value)Players=value end}]======]
CoordinatorFixtureModule.Parent=fixture
local CoordinatorFixture=require(CoordinatorFixtureModule)
local AdminModule=game.ServerScriptService.PlaygroundAdminService:Clone()
AdminModule.Name="Admin"
AdminModule.Source=[======[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local Admin = {}
Admin.__index = Admin
local controls = {
	BBStart = { game = "BritishBulldog" }, BBRunner = { game = "BritishBulldog", role = "Runner" }, BBBulldog = { game = "BritishBulldog", role = "Bulldog" },
	TagStart = { game = "TagYoureIt" }, TagRunner = { game = "TagYoureIt", role = "Runner" }, TagTagger = { game = "TagYoureIt", role = "Tagger" },
	MudStart = { game = "StuckInTheMud" }, MudShooter = { game = "StuckInTheMud", role = "Shooter" }, MudMedic = { game = "StuckInTheMud", role = "Medic" },
}
controls.HSStart = { game = "HideAndSeek" }
controls.DGStart = { game = "DuckDuckGoose" }
controls.SKStart = { game = "SkippingRope" }
local aliases = { StartRound = "BBStart", PracticeRunner = "BBRunner", PracticeBulldog = "BBBulldog" }
local grants = { GrantItem = true, GrantCoins = true, AddLevels = true, GrantVIP = true, GrantBetaTester = true }

function Admin.new(coordinator, config, isStudio, playerSource)
	return setmetatable({ coordinator = coordinator, config = config, isStudio = isStudio, players = playerSource or Players, lastRequest = {}, lastStatus = {}, busy = false, connections = {} }, Admin)
end

function Admin:IsAuthorized(player)
	local userId = player and player.UserId
	if typeof(userId) ~= "number" or userId <= 0 or userId % 1 ~= 0 or userId >= 9007199254740991 then return false end
	if userId == self.config:GetAttribute("AdminUserId") then return true end
	local extraIds = self.config:GetAttribute("ExtraAdminUserIds")
	if typeof(extraIds) ~= "string" then return false end
	for token in extraIds:gmatch("[^,]+") do
		local digits = token:match("^%s*(%d+)%s*$")
		if digits and tonumber(digits) == userId then return true end
	end
	return false
end

function Admin:_target(player, payload)
	if payload ~= nil and typeof(payload) ~= "table" then return nil, "Choose a player in this server." end
	local id = player.UserId
	if payload and payload.targetUserId ~= nil then id = payload.targetUserId end
	if typeof(id) ~= "number" or id ~= id or id % 1 ~= 0 or id == 0 or math.abs(id) > 1000000000000 or (id < 0 and not self.isStudio) then
		return nil, "Choose a player in this server."
	end
	local target = self.players:GetPlayerByUserId(id)
	if not target then return nil, "That player is no longer in this server." end
	return target
end

function Admin:Status(player, ok, message, target)
	local active = self.coordinator:ActiveGame()
	local service = active and self.coordinator.services[active]
	local reply = { ok = ok, message = message or "", game = active or "", phase = service and service.phase or "Waiting", mode = service and service.state:GetAttribute("Mode") or "Waiting", role = active == "SkippingRope" and player:GetAttribute("SKRole") or active == "DuckDuckGoose" and player:GetAttribute("DGRole") or active == "HideAndSeek" and player:GetAttribute("HSRole") or active == "StuckInTheMud" and (player:GetAttribute("MDMuddy") and "Stuck" or "Free") or active == "TagYoureIt" and player:GetAttribute("TGRole") or player:GetAttribute("BBRole"), automatic = self.coordinator.autoEnabled }
	reply.players = {}
	for _, online in ipairs(self.players:GetPlayers()) do
		table.insert(reply.players, { userId = online.UserId, name = online.Name, displayName = online.DisplayName, ready = online:GetAttribute("PCDataReady") == true })
	end
	table.sort(reply.players, function(a, b)
		if a.name == b.name then return a.userId < b.userId end
		return a.name:lower() < b.name:lower()
	end)
	local economy = self.coordinator.economy
	if economy then
		reply.limits = table.clone(economy.AdminLimits)
		if target == false then target = nil
		else target = target or self.players:GetPlayerByUserId(player.UserId) end
		if target then
			reply.targetUserId = target.UserId
			reply.target = economy:Status(target, true)
			reply.target.userId = target.UserId
			reply.target.name = target.Name
			reply.target.displayName = target.DisplayName
		end
	end
	return reply
end

function Admin:Handle(player, action, payload)
	if not self:IsAuthorized(player) then return { ok = false, message = "Admin access required." } end
	if typeof(action) ~= "string" then return self:Status(player, false, "Unknown control.") end
	action = aliases[action] or action
	if not controls[action] and not grants[action] and action ~= "StopRound" and action ~= "GetStatus" and action ~= "ToggleAutomatic" then return self:Status(player, false, "Unknown control.") end
	local target, targetError
	if grants[action] or action == "GetStatus" then
		if grants[action] and (typeof(payload) ~= "table" or payload.targetUserId == nil) then return self:Status(player, false, "Choose a target player for this action.") end
		target, targetError = self:_target(player, payload)
		if not target then return self:Status(player, false, targetError, false) end
	end
	local now = os.clock()
	local timestamps = action == "GetStatus" and self.lastStatus or self.lastRequest
	if now - (timestamps[player] or -math.huge) < (action == "GetStatus" and 0.1 or 0.5) then return self:Status(player, false, "Please wait a moment.", target) end
	timestamps[player] = now
	if action == "GetStatus" then return self:Status(player, true, "Ready to play.", target) end
	if self.busy then return self:Status(player, false, "Another control is finishing.", target) end
	self.busy = true
	local ok, success, message = xpcall(function()
		if grants[action] then
			local economy = self.coordinator.economy
			if not economy then return false, "The player economy is not ready." end
			if typeof(payload) ~= "table" then return false, "Choose an item or grant amount." end
			if action == "GrantItem" then
				return economy:AdminGrantItem(target, payload.itemId, payload.equip)
			end
			if action == "GrantCoins" then return economy:AdminGrantCoins(target, payload.amount) end
			if action == "AddLevels" then return economy:AdminAddLevels(target, payload.amount) end
			if action == "GrantVIP" then return economy:AdminGrantEntitlement(target, "VIP") end
			if action == "GrantBetaTester" then return economy:AdminGrantEntitlement(target, "BetaTester") end
		end
		if action == "StopRound" then return self.coordinator:StopGame() end
		if action == "ToggleAutomatic" then
			self.coordinator:SetAutoEnabled(not self.coordinator.autoEnabled)
			return true, self.coordinator.autoEnabled and "Automatic voting rounds are on." or "Automatic rounds paused."
		end
		local control = controls[action]
		local started, reason = self.coordinator:StartGame(control.game, player, control.role, false)
		if not started and reason == "Not enough ready players" then reason = "Use a solo button to test alone. Normal rounds need two players." end
		return started, started and "Starting your game." or reason
	end, debug.traceback)
	self.busy = false
	if not ok then
		local detail = string.sub(tostring(success), 1, 4096)
		self.config:SetAttribute("LastCommandFailureAction", action)
		self.config:SetAttribute("LastCommandFailure", detail)
		self.config:SetAttribute("LastCommandFailureAt", os.time())
		warn(string.format("Playground admin %s failed (place version %d): %s", action, game.PlaceVersion, detail))
		local reply = self:Status(player, false, "Could not finish " .. action .. ". See the error details.", target)
		reply.errorDetail = string.format("%s · Place version %d\n%s", action, game.PlaceVersion, detail)
		return reply
	end
	if success and grants[action] then print("Playground admin " .. player.UserId .. " used " .. action .. " for " .. target.UserId) end
	return self:Status(player, success == true, message, target)
end

function Admin.Start(coordinator)
	local config = ServerStorage:WaitForChild("PlaygroundAdminConfig")
	local remote = ReplicatedStorage:WaitForChild("PlaygroundAdminRequest")
	local self = Admin.new(coordinator, config, RunService:IsStudio())
	self.remote = remote
	remote.OnServerInvoke = function(player, action, payload) return self:Handle(player, action, payload) end
	local function bind(player) player:SetAttribute("PlaygroundAdmin", self:IsAuthorized(player)) end
	table.insert(self.connections, Players.PlayerAdded:Connect(bind))
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player) self.lastRequest[player] = nil self.lastStatus[player] = nil end))
	for _, player in ipairs(Players:GetPlayers()) do bind(player) end
	table.insert(self.connections, config.AttributeChanged:Connect(function() for _, player in ipairs(Players:GetPlayers()) do bind(player) end end))
	return self
end

function Admin:Destroy()
	for _, connection in ipairs(self.connections) do connection:Disconnect() end
	if self.remote then self.remote.OnServerInvoke = nil end
end

return Admin
]======]
AdminModule.Parent=fixture
local Admin=require(AdminModule)
local EconomyFixtureModule=game.ServerScriptService.PlaygroundEconomyService:Clone()
EconomyFixtureModule.Name="EconomyFixture"
EconomyFixtureModule.Source=[======[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Debris = game:GetService("Debris")
local Catalog = require(ReplicatedStorage:WaitForChild("PlaygroundCatalog"))

local Economy = {}
Economy.__index = Economy
local slots = { Bat = true, Pet = true, Emote = true, Emoji = true, Trail = true, Highlight = true, Gear = true }
local actions = { RedeemCode = true, GetStatus = true, Buy = true, Equip = true, Unequip = true, SelectToy = true, UseEmote = true, StopEmote = true, UseEmoji = true }
local ink = Color3.fromRGB(24, 35, 62)
local games = { BritishBulldog = true, TagYoureIt = true, StuckInTheMud = true, HideAndSeek = true, DuckDuckGoose = true, SkippingRope = true }
local gamePrefixes = { BB = "BritishBulldog", TAG = "TagYoureIt", MUD = "StuckInTheMud", HS = "HideAndSeek", DG = "DuckDuckGoose", SK = "SkippingRope" }
local adminLimits = table.freeze({ coinsPerGrant = 1000000, levelsPerGrant = 100, maxLevel = 1000, maxCoins = 1000000000 })
local coinPickupAmount = 5
local maxToySlots = 4
local fishingCatchesPerDay = 3
local fishingBoostSeconds = 300

local function boundedInteger(value, minimum, maximum)
	return typeof(value) == "number" and value == value and value % 1 == 0 and value >= minimum and value <= maximum
end

local function integer(value, fallback)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return fallback end
	return math.clamp(math.floor(value), 0, 1000000000)
end

local function timestamp(value)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return 0 end
	return math.clamp(math.floor(value), 0, 1000000000000)
end

local function isToy(item)
	return typeof(item) == "table" and item.category == "Toys" and item.slot == "Gear"
end

local function inGame(player)
	return player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or ( player:GetAttribute("MDParticipating") == true or player:GetAttribute("HSParticipating") == true or player:GetAttribute("DGParticipating") == true or player:GetAttribute("DGEliminated") == true or player:GetAttribute("SKParticipating") == true or player:GetAttribute("SKEliminated") == true )
end

local function emoteDetails(data)
	if typeof(data) ~= "table" or typeof(data.Equipped) ~= "table" or typeof(data.Owned) ~= "table" then return nil end
	local id = data.Equipped.Emote
	local item = id and Catalog.ById[id]
	local animation = item and Catalog.EmoteAnimations[id]
	local animationId = animation and animation.R15AnimationId
	if not item or item.slot ~= "Emote" or item.available == false or item.playable ~= true
		or not data.Owned or data.Owned[id] ~= true or not boundedInteger(animationId, 1, 9007199254740991) then return nil end
	return { emoteId = id, emoteAnimationId = "rbxassetid://" .. string.format("%.0f", animationId), emoteRigType = "R15" }
end

local function stopEmote(player)
	player:SetAttribute("PCEmoteUntil", 0)
	player:SetAttribute("PCEmoteAction", "")
	player:SetAttribute("PCEmoteAnimationId", "")
end

local function cleanToyLoadout(equipped, owned)
	equipped = typeof(equipped) == "table" and equipped or {}
	local toys, seen = {}, {}
	local function add(id)
		local item = typeof(id) == "string" and Catalog.ById[id]
		if #toys < maxToySlots and isToy(item) and item.available ~= false and owned[id] == true and not seen[id] then
			seen[id] = true
			table.insert(toys, id)
		end
	end
	local active = typeof(equipped.Gear) == "string" and equipped.Gear or equipped.Toy
	if typeof(equipped.Toys) == "table" then
		if boundedInteger(equipped.ToyIndex, 1, 64) then active = equipped.Toys[equipped.ToyIndex] end
		for index = 1, 64 do
			add(equipped.Toys[index])
			if #toys == maxToySlots then break end
		end
	else
		add(equipped.Gear)
		if #toys == 0 then add(equipped.Toy) end
	end
	return toys, table.find(toys, active) or (#toys > 0 and 1 or 0)
end

local function setToyLoadout(data, toys, index)
	data.Equipped.Toys = toys
	data.Equipped.ToyIndex = index
	data.Equipped.Gear = toys[index]
	data.Equipped.Toy = toys[index]
end

local function equipToy(data, id)
	local toys = cleanToyLoadout(data.Equipped, data.Owned)
	local selected = table.find(toys, id)
	if not selected then
		if #toys >= maxToySlots then return false, "Your four toy slots are full. Unequip a toy first." end
		table.insert(toys, id)
		selected = #toys
	end
	setToyLoadout(data, toys, selected)
	return true
end

local function unequipToy(data, id)
	local toys, index = cleanToyLoadout(data.Equipped, data.Owned)
	local active = toys[index]
	local removed = table.find(toys, id)
	if not removed then return false, "That toy is not in your loadout." end
	table.remove(toys, removed)
	setToyLoadout(data, toys, table.find(toys, active) or math.min(index, #toys))
	return true
end

local function levelProgress(xp, base, step)
	xp = integer(xp, 0)
	base = math.max(1, integer(base, 100))
	step = integer(step, 50)
	local completed = 0
	local function cost(count) return count * base + step * count * (count - 1) / 2 end
	if step == 0 then
		completed = math.floor(xp / base)
	elseif xp > 0 then
		local linear = base - step / 2
		local root = math.sqrt(linear * linear + 2 * step * xp)
		completed = math.floor(linear >= 0 and 2 * xp / (root + linear) or (root - linear) / step)
		if cost(completed) > xp then completed = math.max(0, completed - 1) end
		if cost(completed + 1) <= xp then completed += 1 end
	end
	return completed + 1, xp - cost(completed), base + step * completed
end

local function cleanData(value)
	value = typeof(value) == "table" and value or {}
	local result = { Coins = integer(value.Coins, 0), Wins = integer(value.Wins, 0), XP = integer(value.XP, 0), Owned = {}, Equipped = {}, GameWins = {}, CoinPurchases = {}, Entitlements = {}, RedeemedCodes = {}, Version = 6 }
	local entitlements = typeof(value.Entitlements) == "table" and value.Entitlements or {}
	result.Entitlements.VIP = entitlements.VIP == true
	result.Entitlements.BetaTester = entitlements.BetaTester == true
	if typeof(value.RedeemedCodes) == "table" then
		for code, redeemedAt in pairs(value.RedeemedCodes) do
			if typeof(code) == "string" and #code > 0 and #code <= 32 and code:match("^[A-Z0-9_%-]+$") and timestamp(redeemedAt) > 0 then
				result.RedeemedCodes[code] = timestamp(redeemedAt)
			end
		end
	end
	result.SecretObbyClaimDay = integer(value.SecretObbyClaimDay, 0)
	result.FishingDay = integer(value.FishingDay, 0)
	result.FishingUsed = math.min(fishingCatchesPerDay, integer(value.FishingUsed, 0))
	result.FishingCoinsExpires = timestamp(value.FishingCoinsExpires)
	result.FishingXPExpires = timestamp(value.FishingXPExpires)
	if typeof(value.CoinPurchases) == "table" then
		for purchaseId, purchase in pairs(value.CoinPurchases) do
			if typeof(purchaseId) == "string" and #purchaseId > 0 and #purchaseId <= 128 and typeof(purchase) == "table"
				and boundedInteger(purchase.ProductId, 1, 9007199254740991) and boundedInteger(purchase.Coins, 1, 100000) then
				result.CoinPurchases[purchaseId] = { ProductId = purchase.ProductId, Coins = purchase.Coins }
			end
		end
	end
	for gameId in pairs(games) do
		result.GameWins[gameId] = integer(typeof(value.GameWins) == "table" and value.GameWins[gameId] or nil, 0)
	end
	if typeof(value.Owned) == "table" then
		for id, owned in pairs(value.Owned) do
			if typeof(id) == "string" and #id <= 48 and owned == true then result.Owned[id] = true end
		end
	end
	result.Owned[Catalog.StarterBat] = true
	if typeof(value.Equipped) == "table" then
		for slot, id in pairs(value.Equipped) do
			local item = typeof(id) == "string" and Catalog.ById[id]
			if slot ~= "Gear" and slots[slot] and typeof(id) == "string" and #id <= 48 and result.Owned[id] and (not item or item.slot == slot) then
				result.Equipped[slot] = id
			end
		end
	end
	local toys, toyIndex = cleanToyLoadout(value.Equipped, result.Owned)
	setToyLoadout(result, toys, toyIndex)
	if integer(value.Version, 0) < 3 and not result.Equipped.Bat then result.Equipped.Bat = Catalog.StarterBat end
	return result
end

local function unlockStatus(data, item, level, entitlements)
	local rule = item.unlock or {}
	local kind = rule.kind
	local target = integer(rule.amount, 0)
	local owned = data.Owned[item.id] == true
	local progress, unlocked, label = 0, false, "Unavailable"
	if kind == "Starter" then
		unlocked, label = true, "Starter reward"
	elseif kind == "Coins" then
		progress, unlocked, label = integer(data.Coins, 0), true, tostring(item.price) .. " coins"
	elseif kind == "VIP" or kind == "BetaTester" then
		local granted = entitlements or data.Entitlements or {}
		unlocked, label = granted[kind] == true, kind == "VIP" and "VIP reward" or "Beta Tester reward"
	elseif kind == "Level" then
		progress, label = level, "Level " .. target
		unlocked = progress >= target
	elseif kind == "Wins" and (rule.gameId == "All" or games[rule.gameId]) then
		progress = rule.gameId == "All" and integer(data.Wins, 0) or integer(data.GameWins and data.GameWins[rule.gameId], 0)
		label = target .. " " .. Catalog.GameNames[rule.gameId] .. " wins"
		unlocked = progress >= target
	end
	return {
		kind = kind, progress = progress, target = target, required = target,
		available = item.available ~= false and (owned or unlocked), unlocked = owned or unlocked,
		owned = owned, label = label,
		purchasable = kind == "Coins" and item.available ~= false and not owned and integer(data.Coins, 0) >= item.price,
	}
end

function Economy:_unlockRewards(profile)
	local level = self:LevelProgress(profile.data.XP)
	local awarded = {}
	for _, item in ipairs(Catalog.Items) do
		if item.available ~= false and item.unlock.kind ~= "Coins" and not profile.data.Owned[item.id] and unlockStatus(profile.data, item, level, self:_entitlements(profile.player)).unlocked then
			profile.data.Owned[item.id] = true
			table.insert(awarded, item.id)
		end
	end
	if #awarded > 0 then
		profile.newlyUnlocked = awarded
		profile.unlockSerial = (profile.unlockSerial or 0) + 1
	end
	return awarded
end

function Economy:_setting(name, fallback)
	return integer(self.lobby:GetAttribute(name), fallback)
end

function Economy:LevelProgress(xp)
	return levelProgress(xp, self:_setting("BaseLevelXP", 200), self:_setting("LevelXPStep", 50))
end

function Economy.new(lobby, storeOverride, studioOverride)
	local self = setmetatable({}, Economy)
	self.lobby = lobby
	self.bounds = lobby.Gameplay.LobbyBounds
	self.profiles = {}
	self.passBenefits = {}
	self.redemptionCodes = require(script.Parent:WaitForChild("PlaygroundRedemptionCodes"))
	self.fishingRandom = Random.new()
	self.lastFishingSecond = 0
	self.connections = {}
	self.awarded = {}
	self.podiumEmotes = {}
	self.podiumEmoteReads = 0
	self.isStudio = studioOverride == nil and RunService:IsStudio() or studioOverride
	self.sessionId = game.JobId .. ":" .. HttpService:GenerateGUID(false)
	self.store = storeOverride
	if not self.isStudio and not self.store then
		local ok, store = pcall(function() return DataStoreService:GetDataStore("PlaygroundClassics_Profiles_v1") end)
		if ok then self.store = store end
	end
	self.sessionOnly = not self.isStudio and self.store == nil
	self.assets = ReplicatedStorage:WaitForChild("PlaygroundCosmeticAssets")
	self.effects = Instance.new("Folder")
	self.effects.Name = "PlaygroundCosmeticEffects"
	self.effects.Parent = workspace
	self.hiddenCoins = Instance.new("Folder")
	self.hiddenCoins.Name = "PlaygroundCoinRespawns"
	self.hiddenCoins.Parent = ServerStorage
	self.coins = {}
	self.running = false
	self.elapsed = 0
	self.lastSave = os.clock()
	return self
end

function Economy:_sync(profile)
	local player = profile.player
	local toys, toyIndex = cleanToyLoadout(profile.data.Equipped, profile.data.Owned)
	setToyLoadout(profile.data, toys, toyIndex)
	profile.data.XP = integer(profile.data.XP, 0)
	local level, levelXP, requiredXP = self:LevelProgress(profile.data.XP)
	self:_syncPassBenefits(player)
	self:_syncFishing(profile)
	player:SetAttribute("PCCoins", profile.data.Coins)
	player:SetAttribute("PCSecretObbyClaimDay", profile.data.SecretObbyClaimDay)
	player:SetAttribute("PCWins", profile.data.Wins)
	player:SetAttribute("PCXP", profile.data.XP)
	player:SetAttribute("PCLevel", level)
	player:SetAttribute("PCLevelXP", levelXP)
	player:SetAttribute("PCLevelXPRequired", requiredXP)
	player:SetAttribute("PCInventoryVersion", profile.version or 0)
	player:SetAttribute("PCUnlockSerial", profile.unlockSerial or 0)
	for gameId in pairs(games) do player:SetAttribute("PCWins" .. gameId, profile.data.GameWins[gameId]) end
	player:SetAttribute("PCDataReady", profile.ready == true)
	player:SetAttribute("PCDataMode", self.isStudio and "Studio" or self.sessionOnly and "Session" or "Persistent")
	for slot in pairs(slots) do
		local id = profile.data.Equipped[slot]
		local item = id and Catalog.ById[id]
		player:SetAttribute("PC" .. slot, profile.ready == true and item and item.available ~= false and item.slot == slot and profile.data.Owned[id] == true and id or "")
	end
	local emote = profile.ready and emoteDetails(profile.data)
	player:SetAttribute("PCEquippedEmoteAnimationId", emote and emote.emoteAnimationId or "")
	player:SetAttribute("PCEquippedEmoteRigType", emote and emote.emoteRigType or "")
	for index = 1, maxToySlots do player:SetAttribute("PCToySlot" .. index, profile.ready == true and toys[index] or "") end
	player:SetAttribute("PCToy", profile.ready == true and toys[toyIndex] or "")
	player:SetAttribute("PCToyIndex", profile.ready == true and toyIndex or 0)
	player:SetAttribute("PCToyLoadoutVersion", profile.version or 0)
	local board = player:FindFirstChild("leaderstats")
	if board then
		local wins = board:FindFirstChild("Wins")
		local coins = board:FindFirstChild("Coins")
		local levelCounter = board:FindFirstChild("Level")
		if wins then wins.Value = profile.data.Wins end
		if coins then coins.Value = profile.data.Coins end
		if levelCounter then levelCounter.Value = level end
	end
end

function Economy:GetToyLoadout(player)
	local profile = self.profiles[player]
	if not profile or not profile.ready or profile.closed or profile.released then
		return { items = {}, activeIndex = 0, maxSlots = maxToySlots }
	end
	local toys, index = cleanToyLoadout(profile.data.Equipped, profile.data.Owned)
	return { items = toys, activeIndex = index, activeId = toys[index], maxSlots = maxToySlots }
end

function Economy:GetEquipped(player, slot)
	local profile = self.profiles[player]
	if not profile or not profile.ready or profile.closed or profile.released then return nil end
	if slot == "Gear" or slot == "Toy" then return self:GetToyLoadout(player).activeId end
	if typeof(slot) ~= "string" or not slots[slot] then return nil end
	local id = profile.data.Equipped[slot]
	local item = typeof(id) == "string" and Catalog.ById[id]
	return item and item.available ~= false and item.slot == slot and profile.data.Owned[id] == true and id or nil
end

function Economy:SelectToySlot(player, index)
	local profile = self.profiles[player]
	if not profile or not profile.ready or profile.closed or profile.released then return false, "Your items are still loading." end
	if inGame(player) then return false, "Toys are available in the lobby between rounds." end
	local toys, current = cleanToyLoadout(profile.data.Equipped, profile.data.Owned)
	if not boundedInteger(index, 1, maxToySlots) or not toys[index] then return false, "Choose a filled toy slot from 1 to 4." end
	if current ~= index then setToyLoadout(profile.data, toys, index) self:_touch(profile) end
	return true, "Selected " .. Catalog.ById[toys[index]].name .. "."
end

function Economy:_publishLeaderboard(userId, snapshot)
	if not self.leaderboards then return end
	local ok, err = pcall(function() self.leaderboards:PublishSaved(userId, snapshot) end)
	if not ok then warn("Leaderboard update delayed: " .. tostring(err)) end
end

function Economy:_claim(profile)
	if self.isStudio or self.sessionOnly then
		profile.data = cleanData({ Coins = self.isStudio and 150 or 0 })
		profile.ready = true
		return true
	end
	local ok, value = pcall(function()
		return self.store:UpdateAsync("u:" .. profile.player.UserId, function(old)
			old = typeof(old) == "table" and old or {}
			local lease = old.Session
			if typeof(lease) == "table" and lease.Id ~= self.sessionId and timestamp(lease.Expires) > os.time() then return nil end
			local data = cleanData(old)
			data.Session = { Id = self.sessionId, Expires = os.time() + 180 }
			return data
		end)
	end)
	if ok and typeof(value) == "table" and value.Session and value.Session.Id == self.sessionId then
		profile.data = cleanData(value)
		profile.savedPurchases = table.clone(profile.data.CoinPurchases)
		profile.savedEntitlements = table.clone(profile.data.Entitlements)
		profile.savedCodes = table.clone(profile.data.RedeemedCodes)
		profile.ready = true
		self:_publishLeaderboard(profile.player.UserId, profile.data)
		return true
	end
	return false
end

function Economy:_save(profile, release)
	if self.isStudio or self.sessionOnly or not profile.ready or profile.released then return true end
	local untilTime = os.clock() + 8
	while profile.saving and os.clock() < untilTime do task.wait(0.1) end
	if profile.released then return true end
	if profile.saving then return false end
	profile.saving = true
	local version = profile.version
	local snapshot = cleanData(profile.data)
	local saved = false
	for attempt = 1, 3 do
		local ok, value = pcall(function()
			return self.store:UpdateAsync("u:" .. profile.player.UserId, function(old)
				if typeof(old) ~= "table" or typeof(old.Session) ~= "table" or old.Session.Id ~= self.sessionId then return nil end
				local data = cleanData(snapshot)
				if not release then data.Session = { Id = self.sessionId, Expires = os.time() + 180 } end
				return data
			end)
		end)
		if ok and typeof(value) == "table" then saved = true break end
		if ok and value == nil then
			profile.ready = false
			self:_sync(profile)
			break
		end
		if attempt < 3 then task.wait(attempt) end
	end
	profile.saving = false
	if saved and release then profile.released = true end
	if saved and version == profile.version then profile.dirty = false end
	if saved then
		profile.savedPurchases = snapshot.CoinPurchases
		profile.savedEntitlements = snapshot.Entitlements
		profile.savedCodes = snapshot.RedeemedCodes
		self:_publishLeaderboard(profile.player.UserId, snapshot)
	end
	if not saved then warn("Playground profile save is pending for user " .. profile.player.UserId) end
	return saved
end

function Economy:_touch(profile)
	if profile.ready then self:_unlockRewards(profile) end
	profile.version += 1
	profile.dirty = true
	self:_sync(profile)
end

function Economy:_clearAppearance(profile)
	if profile.pet then profile.pet:Destroy() profile.pet = nil end
	local character = profile.player.Character
	if character then
		for _, name in ipairs({ "PCOutline", "PCTrail", "PCTrailTop", "PCTrailBottom" }) do
			local object = character:FindFirstChild(name, true)
			if object then object:Destroy() end
		end
	end
end

function Economy:_applyAppearance(profile)
	self:_clearAppearance(profile)
	local character = profile.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not profile.ready or profile.closed then return end
	local equipped = {}
	for slot, id in pairs(profile.data.Equipped) do
		local item = Catalog.ById[id]
		if item and item.available ~= false and item.slot == slot and profile.data.Owned[id] then equipped[slot] = id end
	end
	local outlineItem = Catalog.ById[equipped.Highlight]
	if outlineItem then
		local outline = Instance.new("Highlight")
		outline.Name = "PCOutline"
		outline.Adornee = character
		outline.FillTransparency = 1
		outline.OutlineTransparency = 0
		outline.OutlineColor = outlineItem.color
		outline.Enabled = not (profile.player:GetAttribute("BBParticipating") == true or (profile.player:GetAttribute("TGParticipating") == true or ( profile.player:GetAttribute("MDParticipating") == true or profile.player:GetAttribute("HSParticipating") == true or profile.player:GetAttribute("DGParticipating") == true or profile.player:GetAttribute("DGEliminated") == true or profile.player:GetAttribute("SKParticipating") == true or profile.player:GetAttribute("SKEliminated") == true )))
		outline.DepthMode = Enum.HighlightDepthMode.Occluded
		outline.Parent = character
	end
	local trailItem = Catalog.ById[equipped.Trail]
	if trailItem then
		local top = Instance.new("Attachment")
		top.Name = "PCTrailTop"
		top.Position = Vector3.new(0, 0.6, 1)
		top.Parent = root
		local bottom = Instance.new("Attachment")
		bottom.Name = "PCTrailBottom"
		bottom.Position = Vector3.new(0, -0.8, 1)
		bottom.Parent = root
		local trail = Instance.new("Trail")
		trail.Name = "PCTrail"
		trail.Attachment0 = top
		trail.Attachment1 = bottom
		trail.Color = equipped.Trail == "RainbowTrail" and ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 93, 124)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 219, 64)),
			ColorSequenceKeypoint.new(0.67, Color3.fromRGB(75, 213, 178)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(118, 126, 255)),
		}) or ColorSequence.new(trailItem.color, Color3.fromRGB(255, 94, 139))
		trail.Lifetime = 0.55
		trail.MinLength = 0.2
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.FaceCamera = true
		trail.Enabled = profile.player:GetAttribute("HSParticipating") ~= true
		trail.Parent = root
	end
end

function Economy:_bindPlayer(player)
	if self.profiles[player] then return end
	local profile = { player = player, data = cleanData(nil), ready = false, version = 0, pickups = {}, connections = {}, lastMutation = -math.huge, lastStatus = -math.huge, lastExpression = -math.huge }
	self.profiles[player] = profile
	local board = player:FindFirstChild("leaderstats")
	if not board then board = Instance.new("Folder") board.Name = "leaderstats" board.Parent = player end
	for _, name in ipairs({ "Wins", "Level", "Coins" }) do
		if not board:FindFirstChild(name) then local counter = Instance.new("IntValue") counter.Name = name counter.Parent = board end
	end
	self:_sync(profile)
	for _, attribute in ipairs({ "BBParticipating", "TGParticipating", "MDParticipating", "HSParticipating", "DGParticipating", "DGEliminated", "SKParticipating", "SKEliminated" }) do
		table.insert(profile.connections, player:GetAttributeChangedSignal(attribute):Connect(function()
			if inGame(player) then stopEmote(player) end
		end))
	end
	table.insert(profile.connections, player.CharacterAdded:Connect(function(character)
		stopEmote(player)
		task.spawn(function()
			character:WaitForChild("HumanoidRootPart", 10)
			if self.profiles[player] == profile and character == player.Character and not profile.closed then self:_applyAppearance(profile) end
		end)
	end))
	task.spawn(function()
		while self.running and self.profiles[player] == profile and player.Parent == Players and not profile.ready do
			if self:_claim(profile) then
				if self.profiles[player] == profile and player.Parent == Players and not profile.closed then
					self:_touch(profile)
					self:_applyAppearance(profile)
				else
					self:_save(profile, true)
				end
				break
			end
			task.wait(10)
		end
	end)
end

function Economy:Status(player, ok, message)
	local profile = self.profiles[player]
	local xp = profile and integer(profile.data.XP, 0) or 0
	local level, levelXP, requiredXP = self:LevelProgress(xp)
	local ready = profile ~= nil and profile.ready == true and not profile.closed and not profile.released
	local data = profile and profile.data or cleanData(nil)
	local loadout = self:GetToyLoadout(player)
	local equipped = table.clone(data.Equipped)
	equipped.Toys, equipped.ToyIndex = table.clone(loadout.items), loadout.activeIndex
	equipped.Gear, equipped.Toy = loadout.activeId, loadout.activeId
	local unlocks = {}
	for _, item in ipairs(Catalog.Items) do
		local status = unlockStatus(data, item, level, self:_entitlements(player))
		status.purchasable = ready and status.purchasable or false
		unlocks[item.id] = status
	end
	return {
		ok = ok, message = message or "", coins = data.Coins, wins = data.Wins,
		xp = xp, level = level, levelXP = levelXP, levelXPRequired = requiredXP,
		owned = table.clone(data.Owned), equipped = equipped, toyLoadout = loadout, ready = ready,
		entitlements = self:_entitlements(player),
		gameWins = table.clone(data.GameWins), winsByGame = table.clone(data.GameWins), unlocks = unlocks,
		newlyUnlocked = profile and table.clone(profile.newlyUnlocked or {}) or {},
		unlockSerial = profile and profile.unlockSerial or 0,
		inventoryVersion = profile and profile.version or 0,
	}
end

function Economy:Handle(player, action, id)
	local profile = self.profiles[player]
	if not profile or profile.closed or profile.released or not profile.ready then return self:Status(player, false, "Your items are still loading.") end
	if typeof(action) ~= "string" or not actions[action] then return self:Status(player, false, "Unknown shop control.") end
	if action == "RedeemCode" then
		local redeemed, message = self:RedeemCode(player, id)
		return self:Status(player, redeemed, message)
	end
	if action == "StopEmote" then
		stopEmote(player)
		return self:Status(player, true, "Dance stopped.")
	end
	local now = os.clock()
	local key = action == "GetStatus" and "lastStatus" or "lastMutation"
	if now - profile[key] < (action == "GetStatus" and 0.1 or 0.35) then return self:Status(player, false, "Please wait a moment.") end
	profile[key] = now
	if action == "GetStatus" then return self:Status(player, true) end
	if action == "SelectToy" then
		local selected, message = self:SelectToySlot(player, id)
		return self:Status(player, selected, message)
	end
	if action == "Unequip" then
		local toy = typeof(id) == "string" and Catalog.ById[id]
		if id == "Gear" or id == "Toy" or isToy(toy) then
			if inGame(player) then return self:Status(player, false, "Toys are available in the lobby between rounds.") end
			local toyId = isToy(toy) and id or self:GetToyLoadout(player).activeId
			local removed, reason = unequipToy(profile.data, toyId)
			if not removed then return self:Status(player, false, reason) end
			self:_touch(profile)
			return self:Status(player, true, "Toy removed from your loadout.")
		end
		if typeof(id) ~= "string" or not slots[id] then return self:Status(player, false, "Choose an item first.") end
		if id == "Emote" then stopEmote(player) end
		profile.data.Equipped[id] = nil
		self:_touch(profile)
		self:_applyAppearance(profile)
		return self:Status(player, true, "Unequipped.")
	end
	local item = typeof(id) == "string" and Catalog.ById[id]
	if not item or item.available == false then return self:Status(player, false, "This item is unavailable.") end
	if item.slot == "Emote" and (item.playable ~= true or not Catalog.EmoteAnimations[id]) then return self:Status(player, false, "This emote is not available to play.") end
	if action == "Buy" then
		if profile.data.Owned[id] then return self:Status(player, false, "You already own this.") end
		if item.unlock.kind ~= "Coins" then
			local status = unlockStatus(profile.data, item, self:LevelProgress(profile.data.XP), self:_entitlements(player))
			return self:Status(player, false, "Earn this reward: " .. status.label .. ".")
		end
		if profile.data.Coins < item.price then return self:Status(player, false, "Collect a few more coins first.") end
		profile.data.Coins -= item.price
		profile.data.Owned[id] = true
		local equipped, reason = true, nil
		if isToy(item) then
			if inGame(player) then equipped, reason = false, "Equip it in the lobby between rounds."
			else equipped, reason = equipToy(profile.data, id) end
		else profile.data.Equipped[item.slot] = id end
		self:_touch(profile)
		self:_applyAppearance(profile)
		return self:Status(player, true, item.name .. " is yours!" .. (not equipped and " " .. reason or ""))
	end
	if not profile.data.Owned[id] then return self:Status(player, false, "You don't own this yet.") end
	if action == "Equip" then
		if item.slot == "Emote" then stopEmote(player) end
		if isToy(item) then
			if inGame(player) then return self:Status(player, false, "Toys are available in the lobby between rounds.") end
			local equipped, reason = equipToy(profile.data, id)
			if not equipped then return self:Status(player, false, reason) end
		else profile.data.Equipped[item.slot] = id end
		self:_touch(profile)
		self:_applyAppearance(profile)
		return self:Status(player, true, "Equipped " .. item.name .. ".")
	end
	if action == "UseEmote" or action == "UseEmoji" then
		if now - profile.lastExpression < 4 then return self:Status(player, false, "Give it a moment.") end
		if inGame(player) then return self:Status(player, false, "Try this between rounds.") end
		if action == "UseEmote" then
			if item.slot ~= "Emote" then return self:Status(player, false, "Choose an emote.") end
			local character = player.Character
			if character and ((character:GetAttribute("PCToyHeld") or "") ~= "" or character:GetAttribute("PCBatHeld") == true) then
				return self:Status(player, false, "Put your toy away to dance.")
			end
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			if not humanoid or not rootPart or humanoid.Health <= 0 then return self:Status(player, false, "Your character is not ready.") end
			if humanoid.RigType ~= Enum.HumanoidRigType.R15 then return self:Status(player, false, "These dances need an R15 avatar.") end
			if not self:_inside(rootPart.Position) then return self:Status(player, false, "Dance in the lobby between rounds.") end
			if humanoid.MoveDirection.Magnitude > 0.1 or humanoid.Sit or humanoid.FloorMaterial == Enum.Material.Air then
				return self:Status(player, false, "Stand still on the ground to dance.")
			end
			local animation = Catalog.EmoteAnimations[id]
			if not animation or not boundedInteger(animation.R15AnimationId, 1, 9007199254740991) then return self:Status(player, false, "This emote is unavailable.") end
			local startedAt = workspace:GetServerTimeNow()
			profile.lastExpression = now
			player:SetAttribute("PCEmoteAction", id)
			player:SetAttribute("PCEmoteAnimationId", "rbxassetid://" .. string.format("%.0f", animation.R15AnimationId))
			player:SetAttribute("PCEmoteRigType", "R15")
			player:SetAttribute("PCEmoteStartedAt", startedAt)
			player:SetAttribute("PCEmoteUntil", startedAt + 30)
			player:SetAttribute("PCEmoteSerial", integer(player:GetAttribute("PCEmoteSerial"), 0) + 1)
			return self:Status(player, true, "Move or jump to stop dancing.")
		end
		profile.lastExpression = now
		if item.slot ~= "Emoji" then return self:Status(player, false, "Choose an emoji.") end
		local head = player.Character and player.Character:FindFirstChild("Head")
		if not head then return self:Status(player, false, "Your character is loading.") end
		local bubble = Instance.new("BillboardGui")
		bubble.Name = "PCEmojiBubble"
		bubble.Size = UDim2.fromOffset(80, 80)
		bubble.StudsOffset = Vector3.new(0, 3.5, 0)
		bubble.AlwaysOnTop = false
		bubble.Adornee = head
		bubble.Parent = head
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Text = item.emoji
		text.TextColor3 = item.color
		text.TextStrokeColor3 = ink
		text.TextStrokeTransparency = 0
		text.TextScaled = true
		text.Parent = bubble
		Debris:AddItem(bubble, 2.5)
		return self:Status(player, true)
	end
	return self:Status(player, false, "Unknown shop control.")
end

function Economy:_publishReward(profile, coins, xp, won, roundReward)
	local player = profile.player
	profile.rewardSerial = (profile.rewardSerial or 0) + 1
	player:SetAttribute("PCRewardCoins", coins)
	player:SetAttribute("PCRewardXP", xp)
	player:SetAttribute("PCRewardWon", won == true)
	local message = "+" .. coins .. " coins"
	if roundReward then message ..= " · +" .. xp .. " XP · " .. (won and "Round won!" or "Round complete") end
	player:SetAttribute("PCRewardText", message)
	player:SetAttribute("PCRewardSerial", profile.rewardSerial)
	player:SetAttribute("PCRewardAt", workspace:GetServerTimeNow())
end

function Economy:GetPodiumEmote(userId)
	if not boundedInteger(userId, 1, 1000000000000) then return nil end
	local profile = self:_profileByUserId(userId)
	if profile then
		return profile.ready and not profile.closed and not profile.released and emoteDetails(profile.data) or nil
	end
	local cached = self.podiumEmotes[userId]
	local now = os.clock()
	if cached and (cached.busy or cached.expires > now) then return cached.value end
	if self.isStudio or not self.store or self.podiumEmoteReads >= 2 then return cached and cached.value end
	local record = cached or {}
	record.busy = true
	self.podiumEmotes[userId] = record
	self.podiumEmoteReads += 1
	task.spawn(function()
		local ok, data = pcall(function() return self.store:GetAsync("u:" .. userId) end)
		self.podiumEmoteReads -= 1
		record.busy = false
		record.expires = os.clock() + (ok and 120 or 30)
		if ok then record.value = emoteDetails(data) end
	end)
	return record.value
end

function Economy:_profileByUserId(id)
	for player, profile in pairs(self.profiles) do
		if player.UserId == id and player.Parent == Players then return profile end
	end
	return nil
end

function Economy:_adminProfile(player)
	if not player or player.Parent ~= Players then return nil, "That player is no longer in this server." end
	local profile = self.profiles[player]
	if not profile or not profile.ready or profile.closed or profile.released then return nil, "That player's data is not ready." end
	return profile
end

function Economy:AdminGrantItem(player, id, equip)
	local profile, reason = self:_adminProfile(player)
	if not profile then return false, reason end
	local item = typeof(id) == "string" and #id <= 48 and Catalog.ById[id]
	if not item or item.available == false or not slots[item.slot] then return false, "Choose an available catalog item." end
	if equip ~= nil and typeof(equip) ~= "boolean" then return false, "Equip must be on or off." end
	local alreadyOwned = profile.data.Owned[id] == true
	if alreadyOwned and not equip then return false, "That player already owns " .. item.name .. "." end
	profile.data.Owned[id] = true
	local didEquip, equipReason = equip, nil
	if equip then
		if isToy(item) then
			if inGame(player) then didEquip, equipReason = false, "Equip it in the lobby between rounds."
			else didEquip, equipReason = equipToy(profile.data, id) end
		else profile.data.Equipped[item.slot] = id end
	end
	if alreadyOwned and equip and not didEquip then return false, equipReason end
	self:_touch(profile)
	if didEquip then self:_applyAppearance(profile) end
	return true, (alreadyOwned and "Equipped " or didEquip and "Granted and equipped " or "Granted ") .. item.name .. "." .. (equipReason and " " .. equipReason or "")
end

local function fishingMultiplier(profile, field, now)
	return profile and profile.ready and not profile.closed and not profile.released
		and timestamp(profile.data[field]) > now and 2 or 1
end

function Economy:_syncFishing(profile, now)
	now = now or os.time()
	local data, player = profile.data, profile.player
	local ready = profile.ready and not profile.closed and not profile.released
	local today = math.floor(now / 86400)
	local used = integer(data.FishingDay, 0) >= today and integer(data.FishingUsed, 0) or 0
	player:SetAttribute("PCFishingCatchesLeft", ready and math.max(0, fishingCatchesPerDay - used) or 0)
	player:SetAttribute("PCFishingCoinsExpires", ready and timestamp(data.FishingCoinsExpires) > now and data.FishingCoinsExpires or 0)
	player:SetAttribute("PCFishingXPExpires", ready and timestamp(data.FishingXPExpires) > now and data.FishingXPExpires or 0)
end

function Economy:_entitlements(player)
	local profile = self.profiles[player]
	local manual = profile and profile.ready and not profile.closed and not profile.released and profile.data.Entitlements or {}
	local passes = self.passBenefits[player] or {}
	return { VIP = passes.vip == true or manual.VIP == true, BetaTester = manual.BetaTester == true }
end

function Economy:_syncPassBenefits(player)
	local benefits = self.passBenefits[player] or {}
	local profile, now = self.profiles[player], os.time()
	local entitlements = self:_entitlements(player)
	player:SetAttribute("PCVIP", entitlements.VIP)
	player:SetAttribute("PCBetaTester", entitlements.BetaTester)
	player:SetAttribute("PCDoubleCoins", benefits.doubleCoins == true)
	player:SetAttribute("PCDoubleXP", benefits.doubleXP == true)
	player:SetAttribute("PCCoinMultiplier", (entitlements.VIP and 3 or benefits.doubleCoins and 2 or 1) * fishingMultiplier(profile, "FishingCoinsExpires", now))
	player:SetAttribute("PCXPMultiplier", ((entitlements.VIP or benefits.doubleXP) and 2 or 1) * fishingMultiplier(profile, "FishingXPExpires", now))
end

function Economy:SetPassBenefits(player, vip, doubleCoins, doubleXP)
	if not player or player.Parent ~= Players then return false end
	self.passBenefits[player] = { vip = vip == true, doubleCoins = doubleCoins == true, doubleXP = doubleXP == true }
	local profile = self.profiles[player]
	if profile and profile.ready and not profile.closed and not profile.released then self:_touch(profile)
	else self:_syncPassBenefits(player) end
	return true
end

function Economy:_earnedCoins(profile, amount)
	local benefits = self.passBenefits[profile.player] or {}
	return integer(amount, 0) * (self:_entitlements(profile.player).VIP and 3 or benefits.doubleCoins and 2 or 1) * fishingMultiplier(profile, "FishingCoinsExpires", os.time())
end

function Economy:_earnedXP(profile, amount)
	local benefits = self.passBenefits[profile.player] or {}
	return integer(amount, 0) * ((self:_entitlements(profile.player).VIP or benefits.doubleXP) and 2 or 1) * fishingMultiplier(profile, "FishingXPExpires", os.time())
end

function Economy:GrantCoinPurchase(player, receipt, coins)
	if self.isStudio or self.sessionOnly or not self.store then return false end
	if not player or player.Parent ~= Players or typeof(receipt) ~= "table"
		or receipt.PlayerId ~= player.UserId or not boundedInteger(receipt.ProductId, 1, 9007199254740991)
		or typeof(receipt.PurchaseId) ~= "string" or #receipt.PurchaseId == 0 or #receipt.PurchaseId > 128
		or not boundedInteger(coins, 1, 100000) then return false end
	local profile = self.profiles[player]
	if not profile or not profile.ready or profile.closed or profile.released then return false end
	local purchaseId = receipt.PurchaseId
	local purchase = profile.data.CoinPurchases[purchaseId]
	if purchase then
		if purchase.ProductId ~= receipt.ProductId or purchase.Coins ~= coins then return false end
	else
		if profile.data.Coins > adminLimits.maxCoins - coins then return false end
		profile.data.CoinPurchases[purchaseId] = { ProductId = receipt.ProductId, Coins = coins }
		profile.data.Coins += coins
		self:_touch(profile)
	end
	local confirmed = profile.savedPurchases and profile.savedPurchases[purchaseId]
	if not confirmed then
		self:_save(profile, false)
		confirmed = profile.savedPurchases and profile.savedPurchases[purchaseId]
	end
	return confirmed ~= nil and confirmed.ProductId == receipt.ProductId and confirmed.Coins == coins
end

function Economy:CanFish(player)
	local profile = self.profiles[player]
	if not player or player.Parent ~= Players or not profile or not profile.ready or profile.closed or profile.released then
		return false, "Your fishing rewards are still loading. Try again in a moment."
	end
	if self.sessionOnly and not self.isStudio then return false, "Fishing is unavailable while player data is offline. Try again shortly." end
	if inGame(player) then return false, "Fishing is available in the lobby between rounds." end
	if profile.fishingSaving then return false, "Your last catch is still saving. Please wait a moment." end
	if profile.fishingPending then return true end
	local day = math.floor(os.time() / 86400)
	if integer(profile.data.FishingDay, 0) >= day and integer(profile.data.FishingUsed, 0) >= fishingCatchesPerDay then
		return false, "You've used today's three catches. Come back tomorrow!"
	end
	return true
end

function Economy:ClaimFishingReward(player)
	local allowed, reason = self:CanFish(player)
	if not allowed then return false, reason end
	local profile = self.profiles[player]
	local data, now = profile.data, os.time()
	if not profile.fishingPending then
		local day = math.floor(now / 86400)
		if integer(data.FishingDay, 0) < day then data.FishingUsed = 0 end
		local kind = self.fishingRandom:NextInteger(1, 2) == 1 and "Coins" or "XP"
		local field = kind == "Coins" and "FishingCoinsExpires" or "FishingXPExpires"
		data.FishingDay = day
		data.FishingUsed = integer(data.FishingUsed, 0) + 1
		data[field] = math.max(now, timestamp(data[field])) + fishingBoostSeconds
		profile.fishingPending = { kind = kind, expires = data[field] }
		self:_touch(profile)
	end
	profile.fishingSaving = true
	local saveOK, saved = pcall(self._save, self, profile, false)
	profile.fishingSaving = false
	if not saveOK or not saved then return false, "Your catch is waiting to save. Try this rod again; it won't use another catch." end
	local reward = profile.fishingPending
	profile.fishingPending = nil
	local remaining = math.max(0, fishingCatchesPerDay - integer(data.FishingUsed, 0))
	return true, "+5 minutes of 2x " .. (reward.kind == "Coins" and "coins" or "XP") .. "! " .. remaining .. " catches left today.", reward.kind, reward.expires
end

function Economy:ClaimSecretObbyReward(player)
	local profile = self.profiles[player]
	if player.Parent ~= Players or not profile or not profile.ready or profile.closed or profile.released then
		return false, "Your coins are still loading. Try again in a moment."
	end
	if inGame(player) then return false, "Finish your round first." end
	local day = math.floor(os.time() / 86400)
	if integer(profile.data.SecretObbyClaimDay, 0) >= day then
		return false, "Trail complete! Today's prize is already collected. Come back tomorrow."
	end
	local coins = self:_earnedCoins(profile, 1000)
	if profile.data.Coins > adminLimits.maxCoins - coins then return false, "Your coin balance is full." end
	profile.data.SecretObbyClaimDay = day
	profile.data.Coins += coins
	self:_touch(profile)
	self:_publishReward(profile, coins, 0, false, false)
	task.spawn(function() self:_save(profile, false) end)
	return true, "Secret Steps complete! +" .. coins .. " coins."
end

function Economy:AdminGrantEntitlement(player, entitlement)
	local profile, reason = self:_adminProfile(player)
	if not profile then return false, reason end
	if entitlement ~= "VIP" and entitlement ~= "BetaTester" then return false, "Choose VIP or Beta Tester." end
	if self.sessionOnly and not self.isStudio then return false, "Grants are unavailable while player data is offline." end
	if profile.entitlementSaving then return false, "That player's previous grant is still saving." end
	local label = entitlement == "VIP" and "VIP" or "Beta Tester"
	if profile.savedEntitlements and profile.savedEntitlements[entitlement] then return true, label .. " is already granted." end
	if not profile.data.Entitlements[entitlement] then
		profile.data.Entitlements[entitlement] = true
		self:_touch(profile)
	end
	profile.entitlementSaving = true
	local ok, saved = pcall(self._save, self, profile, false)
	profile.entitlementSaving = false
	local confirmed = self.isStudio or (profile.savedEntitlements and profile.savedEntitlements[entitlement] == true)
	if not ok or not saved or not confirmed then return false, label .. " is pending a save. Retry the grant to confirm it." end
	return true, "Granted " .. label .. "." .. (self.isStudio and " This Studio test does not save player data." or "")
end

function Economy:RedeemCode(player, payload)
	local profile, reason = self:_adminProfile(player)
	if not profile then return false, reason end
	local now = os.clock()
	if now - (profile.lastRedeem or -math.huge) < 2 then return false, "Wait two seconds before trying another code." end
	profile.lastRedeem = now
	if profile.codeSaving then return false, "Your previous code is still saving." end
	if self.sessionOnly and not self.isStudio then return false, "Codes are unavailable while player data is offline." end
	local text = typeof(payload) == "table" and payload.code
	if typeof(text) ~= "string" or #text > 64 then return false, "Enter a valid code of up to 32 characters." end
	local code = string.upper(text:match("^%s*(.-)%s*$"))
	if #code == 0 or #code > 32 or not code:match("^[A-Z0-9_%-]+$") then return false, "Enter a valid code of up to 32 characters." end
	if profile.savedCodes and profile.savedCodes[code] then return false, "You have already redeemed this code." end
	if not profile.data.RedeemedCodes[code] then
		local reward = typeof(self.redemptionCodes) == "table" and self.redemptionCodes[code]
		if typeof(reward) ~= "table" or reward.Enabled ~= true then return false, "This code is invalid or unavailable." end
		if reward.ExpiresAt ~= nil and (not boundedInteger(reward.ExpiresAt, 0, 1000000000000) or (reward.ExpiresAt > 0 and os.time() >= reward.ExpiresAt)) then
			return false, "This code has expired."
		end
		if reward.Kind == "Coins" then
			if not boundedInteger(reward.Amount, 1, adminLimits.coinsPerGrant) then return false, "This code is unavailable." end
			if profile.data.Coins > adminLimits.maxCoins - reward.Amount then return false, "Your coin balance is full. Use some coins before redeeming this code." end
			profile.data.Coins += reward.Amount
		elseif reward.Kind == "VIP" or reward.Kind == "BetaTester" then
			profile.data.Entitlements[reward.Kind] = true
		else return false, "This code is unavailable." end
		profile.data.RedeemedCodes[code] = os.time()
		self:_touch(profile)
	end
	profile.codeSaving = true
	local ok, saved = pcall(self._save, self, profile, false)
	profile.codeSaving = false
	local confirmed = self.isStudio or (profile.savedCodes and profile.savedCodes[code] ~= nil)
	if not ok or not saved or not confirmed then return false, "Your reward is waiting to save. Try this code again; it will not grant twice." end
	if self.isStudio then
		profile.savedCodes = profile.savedCodes or {}
		profile.savedCodes[code] = profile.data.RedeemedCodes[code]
	end
	return true, "Code redeemed! Your reward is active." .. (self.isStudio and " This Studio test does not save player data." or "")
end

function Economy:AdminGrantCoins(player, amount)
	local profile, reason = self:_adminProfile(player)
	if not profile then return false, reason end
	if not boundedInteger(amount, 1, adminLimits.coinsPerGrant) then return false, "Add a whole number from 1 to " .. adminLimits.coinsPerGrant .. " coins." end
	local balance = integer(profile.data.Coins, 0)
	if balance + amount > adminLimits.maxCoins then return false, "That grant would exceed the coin balance limit." end
	profile.data.Coins = balance + amount
	self:_touch(profile)
	self:_publishReward(profile, amount, 0, false, false)
	return true, "Added " .. amount .. " coins."
end

function Economy:AdminAddLevels(player, amount)
	local profile, reason = self:_adminProfile(player)
	if not profile then return false, reason end
	if not boundedInteger(amount, 1, adminLimits.levelsPerGrant) then return false, "Add a whole number from 1 to " .. adminLimits.levelsPerGrant .. " levels." end
	local level, progress = self:LevelProgress(profile.data.XP)
	local targetLevel = level + amount
	if targetLevel > adminLimits.maxLevel then return false, "Admin level grants can reach level " .. adminLimits.maxLevel .. " at most." end
	local completed = targetLevel - 1
	local base = math.max(1, self:_setting("BaseLevelXP", 200))
	local step = self:_setting("LevelXPStep", 50)
	local targetXP = completed * base + step * completed * (completed - 1) / 2 + progress
	if not boundedInteger(targetXP, 0, 1000000000) then return false, "That grant would exceed the XP limit." end
	profile.data.XP = targetXP
	self:_touch(profile)
	return true, "Added " .. amount .. " " .. (amount == 1 and "level" or "levels") .. ". Now level " .. targetLevel .. "."
end

function Economy:AwardRound(key, winnerIds, practice, participantIds, rewardOptions)
	if practice or typeof(key) ~= "string" or #key > 96 or self.awarded[key] or typeof(winnerIds) ~= "table" or typeof(participantIds) ~= "table" then return 0 end
	local participants, winners = {}, {}
	local function validId(id) return typeof(id) == "number" and id == id and id % 1 == 0 and math.abs(id) <= 1000000000000 end
	for _, id in ipairs(participantIds) do if validId(id) then participants[id] = true end end
	for _, id in ipairs(winnerIds) do if validId(id) and participants[id] then winners[id] = true end end
	if next(participants) == nil then return 0 end
	self.awarded[key] = true
	local gameId = typeof(rewardOptions) == "table" and rewardOptions.gameId or nil
	if not games[gameId] then gameId = gamePrefixes[string.match(key, "^(%a+):")] end
	local rewarded = 0
	for id in pairs(participants) do
		local profile = self:_profileByUserId(id)
		if profile and profile.ready and not profile.closed and not profile.released then
			local won = winners[id] == true
			local coins = self:_setting(won and "WinnerCoins" or "LoserCoins", won and 150 or 50)
			local xp = self:_setting(won and "WinnerXP" or "LoserXP", 50)
			if typeof(rewardOptions) == "table" then xp = integer(won and rewardOptions.winnerXP or rewardOptions.loserXP, xp) end
			coins = self:_earnedCoins(profile, coins)
			xp = self:_earnedXP(profile, xp)
			local beforeCoins = integer(profile.data.Coins, 0)
			local beforeXP = integer(profile.data.XP, 0)
			profile.data.Coins = integer(beforeCoins + coins, 0)
			profile.data.XP = integer(beforeXP + xp, 0)
			if won then
				profile.data.Wins = integer(profile.data.Wins + 1, 0)
				if games[gameId] then profile.data.GameWins[gameId] = integer(profile.data.GameWins[gameId] + 1, 0) end
			end
			self:_touch(profile)
			self:_publishReward(profile, profile.data.Coins - beforeCoins, profile.data.XP - beforeXP, won, true)
			rewarded += 1
		end
	end
	return rewarded
end

function Economy:_inside(position)
	local point = self.bounds.CFrame:PointToObjectSpace(position)
	local half = self.bounds.Size / 2
	return math.abs(point.X) <= half.X and math.abs(point.Y) <= half.Y and math.abs(point.Z) <= half.Z
end

function Economy:_buildCoins()
	local template = self.assets:FindFirstChild("C01")
	for _, marker in ipairs(self.lobby.Gameplay.CoinSpawns:GetChildren()) do
		if marker:IsA("BasePart") then
			local coin
			if template and (template:IsA("Model") or template:IsA("BasePart")) then
				coin = template:Clone()
				if coin:IsA("Model") then
					local _, size = coin:GetBoundingBox()
					local extent = math.max(size.X, size.Y, size.Z)
					if extent > 0 then coin:ScaleTo(coin:GetScale() * 2.8 / extent) end
				else
					coin.Size *= 2.8 / math.max(coin.Size.X, coin.Size.Y, coin.Size.Z)
				end
			else
				coin = Instance.new("Part")
				coin.Shape = Enum.PartType.Cylinder
				coin.Size = Vector3.new(0.65, 2.8, 2.8)
				coin.Color = Color3.fromRGB(255, 207, 59)
				coin.Material = Enum.Material.SmoothPlastic
			end
			coin.Name = "Coin_" .. marker.Name
			local parts = coin:GetDescendants()
			table.insert(parts, coin)
			for _, object in ipairs(parts) do
				if object:IsA("BasePart") then
					object.Anchored = true
					object.CanCollide = false
					object.CanTouch = false
					object.CanQuery = false
				elseif object:IsA("LuaSourceContainer") then object:Destroy() end
			end
			coin:PivotTo(marker.CFrame)
			coin.Parent = self.effects
			table.insert(self.coins, {
				id = marker:GetAttribute("PickupId") or marker.Name,
				value = coinPickupAmount,
				cooldown = math.clamp(integer(marker:GetAttribute("RespawnSeconds"), 45), 15, 300),
				marker = marker, visual = coin, availableAt = 0,
			})
		end
	end
end

function Economy:_collectCoin(profile, coin, now)
	local player = profile.player
	if self.profiles[player] ~= profile or player.Parent ~= Players or not profile.ready or profile.closed or profile.released
		or now < coin.availableAt or coin.visual.Parent ~= self.effects or not coin.marker.Parent then return false end
	if player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true
		or ( player:GetAttribute("MDParticipating") == true or player:GetAttribute("HSParticipating") == true or player:GetAttribute("DGParticipating") == true or player:GetAttribute("DGEliminated") == true or player:GetAttribute("SKParticipating") == true or player:GetAttribute("SKEliminated") == true ) then return false end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 or not self:_inside(root.Position)
		or (root.Position - coin.marker.Position).Magnitude > 5.5 then return false end
	local beforeCoins = integer(profile.data.Coins, 0)
	local coins = self:_earnedCoins(profile, coinPickupAmount)
	if beforeCoins > adminLimits.maxCoins - coins then return false end
	local position = coin.visual:GetPivot().Position
	coin.availableAt = now + coin.cooldown
	coin.visual.Parent = self.hiddenCoins
	profile.data.Coins = beforeCoins + coins
	self:_touch(profile)
	profile.pickupSerial = math.max(profile.pickupSerial or 0, integer(player:GetAttribute("PCCoinPickupSerial"), 0)) + 1
	player:SetAttribute("PCCoinPickupAmount", coins)
	player:SetAttribute("PCCoinPickupPosition", position)
	player:SetAttribute("PCCoinPickupSerial", profile.pickupSerial)
	return true
end

function Economy:_tick(dt)
	self.elapsed += dt
	if self.elapsed < 0.15 then return end
	self.elapsed = 0
	local now = workspace:GetServerTimeNow()
	local fishingNow = os.time()
	if fishingNow ~= self.lastFishingSecond then
		self.lastFishingSecond = fishingNow
		for _, profile in pairs(self.profiles) do
			self:_syncFishing(profile, fishingNow)
			self:_syncPassBenefits(profile.player)
		end
	end
	for _, coin in ipairs(self.coins) do
		if coin.marker.Parent and coin.visual.Parent and now >= coin.availableAt then
			coin.visual:PivotTo(coin.marker.CFrame * CFrame.new(0, math.sin(now * 2 + #tostring(coin.id)) * 0.3, 0) * CFrame.Angles(0, now, 0))
			coin.visual.Parent = self.effects
		end
	end
	for player, profile in pairs(self.profiles) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and profile.ready and not profile.closed and not profile.released then
			local participating = player:GetAttribute("BBParticipating") == true or (player:GetAttribute("TGParticipating") == true or ( player:GetAttribute("MDParticipating") == true or player:GetAttribute("HSParticipating") == true or player:GetAttribute("DGParticipating") == true or player:GetAttribute("DGEliminated") == true or player:GetAttribute("SKParticipating") == true or player:GetAttribute("SKEliminated") == true ))
			local trail = character:FindFirstChild("PCTrail", true)
			if trail then trail.Enabled = player:GetAttribute("HSParticipating") ~= true end
			local outline = character:FindFirstChild("PCOutline")
			if outline then
				outline.Enabled = not participating
				if profile.data.Equipped.Highlight == "RainbowOutline" then outline.OutlineColor = Color3.fromHSV(now * 0.12 % 1, 0.72, 1) end
			end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not participating and humanoid and humanoid.Health > 0 and self:_inside(root.Position) then
				for _, coin in ipairs(self.coins) do
					self:_collectCoin(profile, coin, now)
				end
			end
		end
	end
	if os.clock() - self.lastSave >= 60 then
		self.lastSave = os.clock()
		for _, profile in pairs(self.profiles) do task.spawn(function() self:_save(profile, false) end) end
	end
end

function Economy:Start()
	if self.running then return end
	self.running = true
	self:_buildCoins()
	local remote = ReplicatedStorage:WaitForChild("PlaygroundShopRequest")
	remote.OnServerInvoke = function(player, action, id) return self:Handle(player, action, id) end
	self.remote = remote
	table.insert(self.connections, Players.PlayerAdded:Connect(function(player) self:_bindPlayer(player) end))
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player)
		local profile = self.profiles[player]
		if not profile then return end
		profile.closed = true
		for _, connection in ipairs(profile.connections) do connection:Disconnect() end
		self:_clearAppearance(profile)
		self:_save(profile, true)
		self.profiles[player] = nil
		self.passBenefits[player] = nil
	end))
	for _, player in ipairs(Players:GetPlayers()) do self:_bindPlayer(player) end
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt) self:_tick(dt) end))
	for _, attributeName in ipairs({"BaseLevelXP", "LevelXPStep"}) do
		table.insert(self.connections, self.lobby:GetAttributeChangedSignal(attributeName):Connect(function()
			for _, profile in pairs(self.profiles) do if profile.ready and not profile.closed then self:_touch(profile) end end
		end))
	end
	game:BindToClose(function()
		local pending = 0
		for _, profile in pairs(self.profiles) do
			profile.closed = true
			pending += 1
			task.spawn(function() self:_save(profile, true) pending -= 1 end)
		end
		local untilTime = os.clock() + 25
		while pending > 0 and os.clock() < untilTime do task.wait(0.1) end
		if pending == 0 and self.leaderboards then
			pcall(function() self.leaderboards:Flush(2) end)
		end
	end)
end

function Economy:Stop()
	self.running = false
	for _, connection in ipairs(self.connections) do connection:Disconnect() end
	if self.remote then self.remote.OnServerInvoke = nil end
	for _, profile in pairs(self.profiles) do profile.closed = true end
	for _, profile in pairs(self.profiles) do
		for _, connection in ipairs(profile.connections) do connection:Disconnect() end
		self:_clearAppearance(profile)
		self:_save(profile, true)
	end
	self.effects:Destroy()
	self.hiddenCoins:Destroy()
	table.clear(self.profiles)
	table.clear(self.passBenefits)
end

Economy.CleanData = cleanData
Economy.CalculateLevelProgress = levelProgress
Economy.EvaluateUnlock = unlockStatus
Economy.AdminLimits = adminLimits
return {Economy=Economy,CleanData=cleanData}
]======]
EconomyFixtureModule.Parent=fixture
local EconomyFixture=require(EconomyFixtureModule)
local count=0
local function check(value,message) assert(value,message) count+=1 end
local objects={}
local function folder()
 local x=Instance.new("Folder") table.insert(objects,x) return x
end
local playerList={}
local players={}
function players:GetPlayers() return playerList end
function players:GetPlayerByUserId(id) for _,p in ipairs(playerList) do if p.UserId==id then return p end end end
local function player(id)
 local root={Position=Vector3.zero}
 local p={UserId=id,Name="Fixture"..id,DisplayName="Fixture "..id,Parent=players,attributes={PCDataReady=true}}
 local humanoid={Health=100}
 p.Character={FindFirstChildOfClass=function()return humanoid end,FindFirstChild=function(_,name)return name=="HumanoidRootPart" and root or nil end}
 function p:GetAttribute(name)return self.attributes[name]end
 function p:SetAttribute(name,value)self.attributes[name]=value end
 return p
end
CoordinatorFixture.SetPlayers(players)
local Coordinator=CoordinatorFixture.Coordinator
local function fresh(n)
 playerList={} for id=1,n do table.insert(playerList,player(id)) end
 local service={arena=folder(),state=folder(),running=true,active=false,starts=0}
 service.arena:SetAttribute("MinimumPlayers",2)
 function service:StartRound(selected)
  self.starts+=1 self.selected=selected self.active=true self.phase="Countdown" self.state:SetAttribute("Phase","Countdown")
  for _,p in ipairs(selected)do p:SetAttribute("SKParticipating",true) p:SetAttribute("SKRole","Jumper")end
  return true
 end
 function service:StopRound()
  self.active=false self.state:SetAttribute("Phase","Waiting")
  for _,p in ipairs(self.selected or {})do p:SetAttribute("SKParticipating",false) p:SetAttribute("SKEliminated",false) end
 end
 local c=setmetatable({services={SkippingRope=service},lobby={Gameplay={FindFirstChild=function()return nil end}},state=folder(),votes={},lastVote={},spectators={},lastSessionRequest={},lastSpectateStamp={},lastSpectateRequest={},autoEnabled=true,votingEndsAt=0,startRetryAt=0,random=Random.new(1)},Coordinator)
 return c,service
end
local c,service=fresh(4)
playerList[3]:SetAttribute("PCAFKRequested",true)
playerList[4]:SetAttribute("PCDataReady",false)
c:_step(100)
check(c.state:GetAttribute("Phase")=="Voting","SK available to automatic voting")
check(c.state:GetAttribute("AvailableSkippingRope")==true,"SK availability published")
check(c.state:GetAttribute("VotingEndsAt")==135,"35-second intermission")
check(c.state:GetAttribute("ReadyPlayerCount")==2,"AFK and unloaded profiles excluded")
c:_step(134.99)
check(not service.active,"No early round")
c:_step(135)
check(service.active and service.starts==1 and #service.selected==2,"Automatic SK starts eligible roster once")
check(c.state:GetAttribute("ActiveGame")=="SkippingRope" and c.state:GetAttribute("GameTitle")=="Skipping Rope","SK session title")
c:_step(140)
check(service.starts==1,"Running SK not restarted")
local jumper=playerList[1]
check(c:_participating(jumper),"SK participant recognized")
jumper:SetAttribute("PCAFKRequested",true) c:_syncAFK(jumper)
check(jumper:GetAttribute("PCAFKQueued")==true and jumper:GetAttribute("PCAFK")==false,"AFK queues during SK")
jumper:SetAttribute("SKParticipating",false) jumper:SetAttribute("SKEliminated",true)
check(c:_participating(jumper),"SK eliminated remains in round")
c:_syncAFK(jumper)
check(jumper:GetAttribute("PCAFKQueued")==true,"Eliminated SK AFK stays queued")
jumper:SetAttribute("SKParticipating",true) jumper:SetAttribute("SKEliminated",false)
service.state:SetAttribute("Phase","Playing")
local target=c:_spectateTarget(playerList[3],jumper.UserId)
check(target==jumper,"Lobby spectator can follow SK jumper")
jumper:SetAttribute("SKEliminated",true)
check(c:_spectateTarget(playerList[3],jumper.UserId)==nil,"Out SK jumper not a spectate target")
check(c:_spectateTarget(playerList[2],jumper.UserId)==nil,"Active SK player cannot spectate to escape")
service:StopRound() c:_syncAFK(jumper)
check(jumper:GetAttribute("PCAFK")==true and jumper:GetAttribute("PCAFKQueued")==false,"AFK applies after cleanup")
jumper:SetAttribute("PCAFKRequested",false) c:_syncAFK(jumper)
c:_step(250)
check(c.state:GetAttribute("VotingEndsAt")==285,"Next 35-second intermission")
local reported={}
c.economy={AwardRound=function(_,...) table.insert(reported,table.pack(...))end}
service.state:SetAttribute("LastResultWinnerIds","1,2")
service.state:SetAttribute("LastResultParticipantIds","1,2,3")
service.state:SetAttribute("LastResultRound",7)
service.state:SetAttribute("LastResultPractice",false)
c:_rewardSkippingRope()
local reward=reported[1]
check(reward[1]=="SK:7" and reward[5].gameId=="SkippingRope","SK reward identity")
check(#reward[2]==2 and #reward[4]==3 and reward[3]==false,"Survivors and eliminated reward rosters distinct")
service.state:SetAttribute("LastResultPractice",true) c:_rewardSkippingRope()
check(reported[2][3]==true,"Cancelled round suppressed by reward gate")
c,service=fresh(2)
local config=folder() config:SetAttribute("AdminUserId",1)
local admin=Admin.new(c,config,true,players)
local rejected=admin:Handle(playerList[2],"SKStart")
check(not rejected.ok and not service.active,"Unauthorized SK start blocked")
local accepted=admin:Handle(playerList[1],"SKStart")
check(accepted.ok and service.active and accepted.game=="SkippingRope" and accepted.role=="Jumper","Authorized SK start dispatch and status")
admin.lastRequest[playerList[1]]=nil
local stopped=admin:Handle(playerList[1],"StopRound")
check(stopped.ok and not service.active and not c.autoEnabled,"Existing admin stop handles SK")
local Economy=EconomyFixture.Economy
local profiles={}
local economy=setmetatable({awarded={}},Economy)
for id=1,3 do profiles[id]={ready=true,data=EconomyFixture.CleanData({Coins=100,XP=0,Wins=0,GameWins={DuckDuckGoose=2}})} end
function economy:_profileByUserId(id)return profiles[id]end
function economy:_setting(_,fallback)return fallback end
function economy:_earnedCoins(_,amount)return amount end
function economy:_earnedXP(_,amount)return amount end
function economy:_touch()end
function economy:_publishReward(profile,coins,xp,won)profile.notice={coins,xp,won}end
check(profiles[1].data.GameWins.SkippingRope==0 and profiles[1].data.GameWins.DuckDuckGoose==2,"Existing saves gain SK zero wins without losing old wins")
local awarded=economy:AwardRound("SK:1",{1,2,999},false,{1,2,3},{gameId="SkippingRope"})
check(awarded==3,"Every connected participant rewarded exactly once")
check(profiles[1].data.Coins==250 and profiles[1].data.Wins==1 and profiles[1].data.GameWins.SkippingRope==1,"Survivor earns winner reward and SK win")
check(profiles[3].data.Coins==150 and profiles[3].data.Wins==0 and profiles[3].data.GameWins.SkippingRope==0,"Eliminated gets participation reward only")
check(economy:AwardRound("SK:1",{1,2},false,{1,2,3})==0,"Duplicate result cannot duplicate rewards")
check(economy:AwardRound("SK:2",{1,2},true,{1,2,3})==0,"Cancelled round gives no rewards")
check(economy:AwardRound("SK:3",{3},false,{3})==1 and profiles[3].data.GameWins.SkippingRope==1,"SK key prefix fallback works")
local candidates={"BritishBulldog","TagYoureIt","StuckInTheMud","HideAndSeek","DuckDuckGoose","SkippingRope"}
c,service=fresh(2)
for _,id in ipairs(candidates)do
 local entry={arena=folder(),state=folder(),running=true,active=false}
 entry.arena:SetAttribute("MinimumPlayers",2)
 c.services[id]=entry
end
c.lastGame="TagYoureIt"
local seen={}
for index=1,5 do
 c.random={NextInteger=function(_,minimum,maximum)check(maximum==5,"Previous game excluded from unvoted pool")return index end}
 seen[c:_chooseGame()]=true
end
check(seen.SkippingRope and seen.DuckDuckGoose and seen.HideAndSeek and seen.StuckInTheMud and seen.BritishBulldog and not seen.TagYoureIt,"All other eligible games reachable without votes")
c.lastGame="SkippingRope" c.votes[playerList[1]]="SkippingRope"
c.random=Random.new(1)
check(c:_chooseGame()=="SkippingRope","Player votes can still choose previous game")

for _,x in ipairs(objects)do x:Destroy()end
return {passed=true,checks=count,scope="Native isolated coordinator/admin/economy execution; no live players or persistent rewards"}

end,debug.traceback)
fixture:Destroy()
assert(ok,result)
return result
