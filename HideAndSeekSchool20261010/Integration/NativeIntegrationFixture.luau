assert(not game:GetService("RunService"):IsRunning(), "Native fixtures require Edit mode.")
local checks = 0
local function check(value,message)
 assert(value,message)
 checks += 1
end
local storage = game:GetService("ServerStorage")
local fixture = Instance.new("Folder")
fixture.Name = "HideAndSeekIntegrationFixture"
fixture.Parent = storage
local function signal()
 local event = Instance.new("BindableEvent")
 event.Parent = fixture
 return event
end
local function moduleFrom(source,capabilities)
 local module = Instance.new("ModuleScript")
 module.Name, module.Source, module.Capabilities, module.Parent = "FixtureModule",source,capabilities,fixture
 return require(module)
end
local coordinatorFactory = moduleFrom([==[return function(game, workspace)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Coordinator = {}
Coordinator.__index = Coordinator
local games = { "BritishBulldog", "TagYoureIt", "StuckInTheMud", "HideAndSeek" }
local INTERMISSION_SECONDS = 35
local START_RETRY_SECONDS = 5
local titles = { BritishBulldog = "British Bulldog", TagYoureIt = "Tag You're It", StuckInTheMud = "Stuck in the Mud", HideAndSeek = "Hide and Seek" }

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
	return player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or player:GetAttribute("MDParticipating") == true or player:GetAttribute("HSParticipating") == true
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
	local attribute = ({ BritishBulldog = "BBParticipating", TagYoureIt = "TGParticipating", StuckInTheMud = "MDParticipating", HideAndSeek = "HSParticipating" })[active]
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
	for _, name in ipairs({ "BBParticipating", "TGParticipating", "MDParticipating", "HSParticipating" }) do
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
	local counts = { BritishBulldog = 0, TagYoureIt = 0, StuckInTheMud = 0, HideAndSeek = 0 }
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

function Coordinator:_rewardHideAndSeek()
 local service = self.services.HideAndSeek
 if not service then return end
 local state = service.state
 local ids, participants = {}, {}
 for value in string.gmatch(state:GetAttribute("LastResultWinnerIds") or "", "%-?%d+") do table.insert(ids, tonumber(value)) end
 for value in string.gmatch(state:GetAttribute("LastResultParticipantIds") or "", "%-?%d+") do table.insert(participants, tonumber(value)) end
 self.economy:AwardRound("HS:" .. tostring(state:GetAttribute("LastResultRound")), ids, state:GetAttribute("LastResultPractice") == true, participants, { gameId = "HideAndSeek" })
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

end]==],game:GetService("ServerScriptService").PlaygroundCoordinator.Capabilities)
local players = {}
local roster = {}
function players:GetPlayers() return roster end
function players:GetPlayerByUserId(id) for _,p in roster do if p.UserId == id then return p end end end
local function makePlayer(id,ready)
 local attrs = Instance.new("Folder") attrs.Parent = fixture
 local character = Instance.new("Model") character.Parent = fixture
 local humanoid = Instance.new("Humanoid") humanoid.Parent = character
 local root = Instance.new("Part") root.Name,root.Position,root.Parent = "HumanoidRootPart",Vector3.new(0,0,0),character
 local p = { UserId = id, Name = "Fixture"..id, Parent = players, Character = character }
 function p:GetAttribute(name) return attrs:GetAttribute(name) end
 function p:SetAttribute(name,value) attrs:SetAttribute(name,value) end
 function p:GetAttributeChangedSignal(name) return attrs:GetAttributeChangedSignal(name) end
 function p:RemoveReplicationFocus() end
 function p:AddReplicationFocus() end
 p:SetAttribute("PCDataReady",ready)
 table.insert(roster,p)
 return p
end
local a,b,observer = makePlayer(1,true),makePlayer(2,true),makePlayer(3,false)
local state = Instance.new("Folder") state.Parent = fixture
local replicated = {}
function replicated:WaitForChild(name) assert(name=="PlaygroundState") return state end
local mockGame = {}
function mockGame:GetService(name) return ({Players=players,ReplicatedStorage=replicated,RunService={}})[name] end
local mockWorkspace = {}
function mockWorkspace:GetServerTimeNow() return 100 end
local Coordinator = coordinatorFactory(mockGame,mockWorkspace)
local lobby = { Gameplay = { VoteZone = {CFrame=CFrame.new(),Size=Vector3.new(100,100,100)} } }
function lobby.Gameplay:FindFirstChild() return nil end
local services = {}
for _,id in {"BritishBulldog","TagYoureIt","StuckInTheMud","HideAndSeek"}do
 local service = {active=false,running=true,state=Instance.new("Folder"),arena=Instance.new("Folder")}
 service.state.Parent,service.arena.Parent = fixture,fixture
 service.arena:SetAttribute("MinimumPlayers",2)
 function service:StartRound(selected)
  self.selected,self.active = selected,true
  self.state:SetAttribute("Phase","Seeking")
  if id=="HideAndSeek" then for _,p in selected do p:SetAttribute("HSParticipating",true) end end
  return true
 end
 function service:StopRound() self.active=false for _,p in roster do p:SetAttribute("HSParticipating",false) end end
 services[id] = service
end
local rewards = {}
local economy = {}
function economy:AwardRound(...) table.insert(rewards,{...}) end
local coordinator = Coordinator.new(services,lobby,economy)
check(#coordinator:_readyPlayers()==2,"Data-ready players remain the only round candidates")
check(coordinator:MinimumPlayers("HideAndSeek")==2,"School minimum is two")
check(coordinator:GameAvailable("HideAndSeek",2),"School is available with two ready players")
check(not coordinator:GameAvailable("HideAndSeek",1),"One player cannot start school")
coordinator:_availability(2)
check(state:GetAttribute("AvailableHideAndSeek")==true,"School availability reaches voting UI")
coordinator:_step(100)
check(state:GetAttribute("Phase")=="Voting","35-second vote phase starts")
check(state:GetAttribute("VotingEndsAt")==135,"Existing 35-second intermission is preserved")
check(coordinator:Vote(a,"HideAndSeek").ok,"School can receive a vote")
check(coordinator:Vote(b,"HideAndSeek").ok,"Both players can vote for school")
check(state:GetAttribute("VotesHideAndSeek")==2,"School vote count is published")
check(coordinator:_chooseGame()=="HideAndSeek","School wins the vote")
coordinator:_step(134)
check(not services.HideAndSeek.active,"School does not start early")
coordinator:_step(135)
check(services.HideAndSeek.active,"School starts after intermission")
check(coordinator:ActiveGame()=="HideAndSeek","Coordinator recognizes the fourth game")
check(state:GetAttribute("GameTitle")=="Hide and Seek","Shared current-game title is updated")
check(#services.HideAndSeek.selected==2,"Ready-player array reaches the service")
check(coordinator:_participating(a),"School participation gates all coordinator actions")
check(#coordinator:_readyPlayers()==0,"School players cannot enter another round")
a:SetAttribute("PCAFKRequested",true)
coordinator:_syncAFK(a)
check(a:GetAttribute("PCAFKQueued")==true and a:GetAttribute("PCAFK")==false,"AFK queues until the school round ends")
local target, root = coordinator:_spectateTarget(observer,a.UserId)
check(target==a and root==a.Character.HumanoidRootPart,"Lobby spectator can target a school participant")
check(coordinator:_spectateTarget(a,b.UserId)==nil,"Active school players cannot spectate")
check(not coordinator:Vote(a,"HideAndSeek").ok,"School participants cannot vote in their round")
services.HideAndSeek.state:SetAttribute("LastResultWinnerIds","1")
services.HideAndSeek.state:SetAttribute("LastResultParticipantIds","1,2")
services.HideAndSeek.state:SetAttribute("LastResultRound",7)
coordinator:_rewardHideAndSeek()
check(#rewards==1 and rewards[1][1]=="HS:7","School results use their own receipt key")
check(rewards[1][2][1]==1 and rewards[1][4][2]==2,"Winner and participant lists reach the economy")
check(rewards[1][5].gameId=="HideAndSeek","School rewards are counted under the fourth game")
coordinator:StopGame()
check(not services.HideAndSeek.active,"Stop round handles school")
check(state:GetAttribute("Phase")=="Paused","Explicit admin stop still pauses automatic rounds")
check(not coordinator:_participating(a),"School cleanup returns players to the lobby")
coordinator:SetAutoEnabled(true)
a:SetAttribute("PCAFKRequested",false)
local ok,reason = coordinator:StartGame("HideAndSeek",a,"Seeker",false)
check(not ok and reason=="This game requires a normal round.","Unsupported practice request fails safely")
local StarterGui = game:GetService("StarterGui")
local shell = StarterGui.PlaygroundShell
local navy = Color3.fromRGB(24,35,62)
local cream = Color3.fromRGB(255,249,224)
local function caption(parent, name, text, position, size, maxSize, color, stroke)
	local label = Instance.new("TextLabel")
	label.Name, label.BackgroundTransparency, label.Text = name, 1, text
	label.Position, label.Size = position, size
	label.Font, label.TextScaled, label.TextColor3 = Enum.Font.FredokaOne, true, color or navy
	label.TextWrapped, label.ZIndex, label.TextTruncate = false, 5, Enum.TextTruncate.AtEnd
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize, limit.MaxTextSize, limit.Parent = 8, maxSize, label
	if stroke then
		local outline = Instance.new("UIStroke")
		outline.Color, outline.Thickness, outline.Parent = navy, 1.2, label
	end
	label.Parent = parent
	return label
end
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.IgnoreGuiInset = "HideAndSeekHUD", false, false
gui.DisplayOrder, gui.ZIndexBehavior = 25, Enum.ZIndexBehavior.Sibling
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.ClipToDeviceSafeArea = false
gui:SetAttribute("EditableGameHUD", true)
gui:SetAttribute("GameId", "HideAndSeek")
local function header(name, width, height, maxTitle, maxHint)
	local root = Instance.new("Frame")
	root.Name, root.BackgroundTransparency, root.Visible = name, 1, false
	root.AnchorPoint, root.Position, root.Size = Vector2.new(.5,0), UDim2.new(.5,0,0,8), UDim2.fromOffset(width,height)
	local fallback = Instance.new("Frame")
	fallback.Name, fallback.Size, fallback.BackgroundColor3 = "Fallback", UDim2.fromScale(1,1), cream
	fallback.BorderSizePixel, fallback.ZIndex = 0, 1
	local corner = Instance.new("UICorner")
	corner.CornerRadius, corner.Parent = UDim.new(0,12), fallback
	local outline = Instance.new("UIStroke")
	outline.Color, outline.Thickness, outline.Parent = navy, 2, fallback
	fallback.Parent = root
	local skin = shell.Wallet.ReusableSkin:Clone()
	skin.Name, skin.AnchorPoint, skin.Position, skin.Size = "ReusableSkin", Vector2.zero, UDim2.fromScale(0,0), UDim2.fromScale(1,1)
	skin.ZIndex, skin.Parent = 2, root
	caption(root,"Title","HIDE & SEEK",UDim2.fromScale(.045,.06),UDim2.fromScale(.66,.26),maxTitle,cream,true)
	caption(root,"Timer","3:00",UDim2.fromScale(.72,.04),UDim2.fromScale(.24,.32),maxTitle+5,Color3.fromRGB(255,211,78),true)
	caption(root,"Role","HIDER",UDim2.fromScale(.045,.37),UDim2.fromScale(.24,.21),maxHint,Color3.fromRGB(68,163,245))
	caption(root,"Counts","15 hiders • 1 seeker",UDim2.fromScale(.32,.37),UDim2.fromScale(.63,.21),maxHint)
	caption(root,"Hint","Hide before the seeker is released",UDim2.fromScale(.04,.65),UDim2.fromScale(.92,.21),maxHint)
	root.Parent = gui
end
header("DesktopHeader",340,94,22,14)
header("CompactHeader",260,70,18,11)
header("PortraitHeader",240,74,17,10)
local blindfold = Instance.new("Frame")
blindfold.Name, blindfold.Size, blindfold.BackgroundColor3 = "SeekerBlindfold", UDim2.fromScale(1,1), navy
blindfold.Position, blindfold.Size = UDim2.fromOffset(-256,-256), UDim2.new(1,512,1,512)
blindfold.BorderSizePixel, blindfold.ZIndex, blindfold.Visible = 0, 100, false
local waitCard = Instance.new("Frame")
waitCard.Name, waitCard.AnchorPoint, waitCard.Position = "WaitingCard", Vector2.new(.5,.5), UDim2.fromScale(.5,.5)
waitCard.Size, waitCard.BackgroundColor3, waitCard.BorderSizePixel, waitCard.ZIndex = UDim2.fromOffset(280,150), cream, 0, 101
local waitLimit = Instance.new("UISizeConstraint")
waitLimit.MaxSize, waitLimit.Parent = Vector2.new(420,150), waitCard
local waitCorner = Instance.new("UICorner")
waitCorner.CornerRadius, waitCorner.Parent = UDim.new(0,18), waitCard
local waitTitle = caption(waitCard,"Title","EVERYONE IS HIDING",UDim2.fromScale(.06,.10),UDim2.fromScale(.88,.22),24,navy)
waitTitle.ZIndex = 110
local waitTimer = caption(waitCard,"Countdown","0:20",UDim2.fromScale(.15,.37),UDim2.fromScale(.70,.35),42,Color3.fromRGB(245,83,117),true)
waitTimer.ZIndex = 110
local waitHint = caption(waitCard,"Hint","The search begins when this timer ends",UDim2.fromScale(.06,.79),UDim2.fromScale(.88,.11),13,navy)
waitHint.ZIndex = 110
waitCard.Parent, blindfold.Parent = blindfold, gui
local function sprint(name, position, size, touch)
	local button = StarterGui.TagHUD.MobileSprint:Clone()
	button.Name, button.Position, button.Size, button.AnchorPoint = name, position, size, Vector2.new(.5,1)
	if touch then button.AnchorPoint = Vector2.new(1,1) end
	button.Visible, button.Active = false, false
	for _, child in button:GetChildren() do
		if child:IsA("GuiObject") and child.Name ~= "ReusableSkin" and child.Name ~= "ArtFallback" and child.Name ~= "Fallback" then child:Destroy() end
	end
	button.Text = ""
	caption(button,"LiveCaption","SPRINT",UDim2.fromScale(.08,.08),UDim2.fromScale(.84,.48),touch and 18 or 20,cream,true)
	caption(button,"StaminaText",touch and "10.0 / 10" or "SHIFT / L3",UDim2.fromScale(.08,.56),UDim2.fromScale(.84,.20),9,cream,true)
	local track = Instance.new("Frame")
	track.Name, track.Position, track.Size = "StaminaTrack", UDim2.fromScale(.12,.82), UDim2.fromScale(.76,.07)
	track.BorderSizePixel, track.BackgroundColor3, track.ZIndex = 0, navy, 6
	local fill = Instance.new("Frame")
	fill.Name, fill.Size, fill.BackgroundColor3 = "StaminaFill", UDim2.fromScale(1,1), Color3.fromRGB(137,241,238)
	fill.BorderSizePixel, fill.ZIndex, fill.Parent = 0, 7, track
	track.Parent, button.Parent = button, gui
end
sprint("DesktopSprint",UDim2.new(.5,0,1,-18),UDim2.fromOffset(152,48),false)
sprint("MobileSprint",UDim2.new(1,-18,1,-124),UDim2.fromOffset(100,44),true)
local exit = StarterGui.PlaygroundBatControls.Swing:Clone()
exit.Name, exit.Position, exit.Size = "LeaveLocker", UDim2.new(1,-24,1,-192), UDim2.fromOffset(100,44)
exit.Visible, exit.Active = false, true
local exitCaption = exit:FindFirstChild("Caption") or exit:FindFirstChild("LiveCaption") or exit:FindFirstChild("Label")
if exitCaption then exitCaption.Text = "LEAVE" end
if exit:FindFirstChild("Hint") then exit.Hint.Text = "E / Y" end
exit.Text, exit.TextTransparency = "LEAVE", 1
exit.Parent = gui
gui.Parent = fixture

local player = a
player.PlayerGui = fixture
player:SetAttribute("HSParticipating",false)
player:SetAttribute("HSRole","Hider")
player:SetAttribute("HSStamina",10)
player:SetAttribute("HSMaxStamina",10)
local hsState = Instance.new("Folder") hsState.Name,hsState.Parent = "MockState",fixture
local heartbeat = signal()
local released,focused = signal(),signal()
local inputEnded = signal()
local charRemoving = signal()
player.CharacterRemoving = charRemoving.Event
local actions = {}
local context = {}
function context:BindAction(name,callback) actions[name]=callback end
function context:UnbindAction(name) actions[name]=nil end
local input = { TouchEnabled=true,WindowFocusReleased=released.Event,WindowFocused=focused.Event,InputEnded=inputEnded.Event }
function input:GetFocusedTextBox() return nil end
local requests,exits = {},{}
local sprintRemote = {} function sprintRemote:FireServer(value)table.insert(requests,value)end
local actionRemote = {} function actionRemote:FireServer(value)table.insert(exits,value)end
local rs = {}
function rs:WaitForChild(name) return ({HideAndSeekState=hsState,HideAndSeekSprintRequest=sprintRemote,HideAndSeekActionRequest=actionRemote})[name] end
function rs:FindFirstChild(name) if name=="PlaygroundState"then return state end end
local uiGame = {}
function uiGame:GetService(name) return ({Players={LocalPlayer=player},ReplicatedStorage=rs,UserInputService=input,ContextActionService=context,GuiService={MenuIsOpen=false},RunService={Heartbeat=heartbeat.Event}})[name] end
local now = 100
local camera = {ViewportSize=Vector2.new(852,393)}
local uiWorkspace = {CurrentCamera=camera}
function uiWorkspace:GetServerTimeNow()return now end
local destroyed=signal()
local scriptMock={Parent=gui,Destroying=destroyed.Event}
local hudFactory = moduleFrom([==[return function(game,workspace,script)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local gui = script.Parent
local state = ReplicatedStorage:WaitForChild("HideAndSeekState")
local sprintRemote = ReplicatedStorage:WaitForChild("HideAndSeekSprintRequest")
local actionRemote = ReplicatedStorage:WaitForChild("HideAndSeekActionRequest")
local headers = { gui.DesktopHeader, gui.CompactHeader, gui.PortraitHeader }
local sprintButtons = { gui.DesktopSprint, gui.MobileSprint }
local connections = {}
local sprintRequested = false
local keysHeld = {}
local touchHeld = {}
local focused = true
local elapsed = 0
local nextLockerExit = 0
local function clock(seconds)
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end
local function canSprint()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local phase = state:GetAttribute("Phase")
	return focused and not GuiService.MenuIsOpen and not UserInputService:GetFocusedTextBox()
		and gui.Enabled and player:GetAttribute("HSParticipating") == true
		and (phase == "Hiding" or phase == "Seeking") and player:GetAttribute("HSHiding") ~= true
		and not (phase == "Hiding" and player:GetAttribute("HSRole") == "Seeker")
		and player:GetAttribute("HSRagdolled") ~= true and humanoid and humanoid.Health > 0
end
local function requestSprint(value)
	value = value == true and canSprint() == true
	if value == sprintRequested then return end
	sprintRequested = value
	sprintRemote:FireServer(value)
end
local function clearInputs()
	table.clear(keysHeld)
	table.clear(touchHeld)
	requestSprint(false)
end
local function leaveLocker()
	if not focused or GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox()
		or player:GetAttribute("HSParticipating") ~= true or player:GetAttribute("HSHiding") ~= true
		or os.clock() < nextLockerExit then return end
	nextLockerExit = os.clock() + 0.3
	actionRemote:FireServer("LeaveLocker")
end
local function refresh()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local short = math.min(viewport.X, viewport.Y)
	local compact = viewport.X <= 900 or short <= 600 or (short <= 1024 and math.max(viewport.X, viewport.Y) <= 1400)
	local selectedHeader = not compact and gui.DesktopHeader or viewport.Y > viewport.X and gui.PortraitHeader or gui.CompactHeader
	local session = gui.Parent:FindFirstChild("PlaygroundSessionControls")
	local muted = session and (session:GetAttribute("UIHidden") == true or session:GetAttribute("SessionMenuOpen") == true)
	local participating = player:GetAttribute("HSParticipating") == true
	local roundState = ReplicatedStorage:FindFirstChild("PlaygroundState")
	local watching = session and session:GetAttribute("Spectating") == true and roundState and roundState:GetAttribute("ActiveGame") == "HideAndSeek"
	local shown = (participating or watching) and not muted
	local phase = state:GetAttribute("Phase")
	local role = player:GetAttribute("HSRole")
	local now = workspace:GetServerTimeNow()
	local ending = phase == "Hiding" and state:GetAttribute("HidingEndsAt") or state:GetAttribute("EndsAt")
	local seconds = typeof(ending) == "number" and ending == ending and math.abs(ending) ~= math.huge and math.max(0, math.ceil(ending - now)) or 0
	local blindfold = participating and role == "Seeker" and phase == "Hiding"
	gui.SeekerBlindfold.Visible = blindfold
	gui.SeekerBlindfold.WaitingCard.Countdown.Text = clock(seconds)
	local instruction = "Find a hiding spot!"
	if phase == "Countdown" then instruction = "Get ready!"
	elseif phase == "Hiding" then instruction = role == "Seeker" and "Wait while players hide" or "Hide before the seeker is released"
	elseif phase == "Seeking" then instruction = role == "Seeker" and "Swing your bat to find hiders" or "Stay hidden or run from seekers"
	elseif phase == "Results" then instruction = state:GetAttribute("WinnersText") or "Round finished" end
	if player:GetAttribute("HSHiding") == true then instruction = "Hiding in a locker • Leave to run" end
	for _, header in headers do
		header.Visible = shown and not blindfold and header == selectedHeader
		header.Title.Text = phase == "Results" and "ROUND FINISHED" or "HIDE & SEEK"
		header.Timer.Text = phase == "Countdown" and tostring(state:GetAttribute("CountdownValue") or 3) or phase == "Results" and "" or clock(seconds)
		header.Role.Text = watching and "WATCHING" or role == "Seeker" and "SEEKER" or "HIDER"
		header.Role.TextColor3 = role == "Seeker" and Color3.fromRGB(245,83,117) or Color3.fromRGB(68,163,245)
		local hiders, seekers = state:GetAttribute("HiderCount") or 0, state:GetAttribute("SeekerCount") or 0
		header.Counts.Text = string.format("%d %s • %d %s", hiders, hiders == 1 and "hider" or "hiders", seekers, seekers == 1 and "seeker" or "seekers")
		header.Hint.Text = watching and "Watching the school round" or instruction
		header.Fallback.Visible = not header.ReusableSkin.IsLoaded
	end
	local active = canSprint() == true
	if not active then clearInputs() end
	for _, button in sprintButtons do
		button.Visible = participating and shown and (phase == "Hiding" or phase == "Seeking") and button == (UserInputService.TouchEnabled and gui.MobileSprint or gui.DesktopSprint)
		button.Active = active
		button.Selectable = not UserInputService.TouchEnabled and active
		local stamina = math.clamp((player:GetAttribute("HSStamina") or 0) / math.max(1, player:GetAttribute("HSMaxStamina") or 10), 0, 1)
		button.StaminaTrack.StaminaFill.Size = UDim2.fromScale(stamina, 1)
		button.StaminaText.Text = string.format("%.1f / 10", player:GetAttribute("HSStamina") or 0)
		button.ReusableSkin.ImageColor3 = active and Color3.new(1,1,1) or Color3.fromRGB(150,157,170)
		local fallback = button:FindFirstChild("ArtFallback") or button:FindFirstChild("Fallback")
		if fallback then fallback.Visible = not button.ReusableSkin.IsLoaded end
	end
	gui.LeaveLocker.Visible = shown and player:GetAttribute("HSHiding") == true
end
local function connect(signal, callback)
	table.insert(connections, signal:Connect(callback))
end
for _, button in sprintButtons do
	connect(button.InputBegan, function(input)
		if not button.Visible or not button.Active then return end
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			touchHeld[input] = true
			requestSprint(true)
		end
	end)
end
connect(UserInputService.InputEnded, function(input)
	if touchHeld[input] then touchHeld[input] = nil requestSprint(next(touchHeld) ~= nil or next(keysHeld) ~= nil) end
end)
connect(UserInputService.WindowFocusReleased, function() focused = false clearInputs() end)
connect(UserInputService.WindowFocused, function() focused = true refresh() end)
connect(gui.LeaveLocker.Activated, leaveLocker)
ContextActionService:BindAction("HideAndSeekSprint", function(_, inputState, input)
	if player:GetAttribute("HSParticipating") ~= true then return Enum.ContextActionResult.Pass end
	if inputState == Enum.UserInputState.Begin then keysHeld[input.KeyCode] = true requestSprint(true)
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then keysHeld[input.KeyCode] = nil requestSprint(next(keysHeld) ~= nil or next(touchHeld) ~= nil) end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL3)
ContextActionService:BindAction("HideAndSeekLeaveLocker", function(_, inputState)
	if player:GetAttribute("HSHiding") ~= true then return Enum.ContextActionResult.Pass end
	if inputState == Enum.UserInputState.Begin then leaveLocker() end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.E, Enum.KeyCode.ButtonY)
connect(state.AttributeChanged, refresh)
for _, name in { "HSParticipating", "HSRole", "HSHiding", "HSRagdolled", "HSStamina", "HSMaxStamina" } do connect(player:GetAttributeChangedSignal(name), refresh) end
connect(player.CharacterRemoving, clearInputs)
connect(RunService.Heartbeat, function(delta)
	elapsed += delta
	if elapsed >= 0.1 then elapsed = 0 refresh() end
end)
connect(script.Destroying, function()
	clearInputs()
	ContextActionService:UnbindAction("HideAndSeekSprint")
	ContextActionService:UnbindAction("HideAndSeekLeaveLocker")
	for _, connection in connections do connection:Disconnect() end
end)
refresh()

end]==],SecurityCapabilities.new(Enum.SecurityCapability.RunServerScript,Enum.SecurityCapability.AccessOutsideWrite,Enum.SecurityCapability.CreateInstances,Enum.SecurityCapability.Basic,Enum.SecurityCapability.Physics,Enum.SecurityCapability.UI,Enum.SecurityCapability.Input,Enum.SecurityCapability.RemoteEvent,Enum.SecurityCapability.Players,Enum.SecurityCapability.AvatarBehavior))
hudFactory(uiGame,uiWorkspace,scriptMock)
local function refresh()heartbeat:Fire(.2)task.wait()end
check(not gui.CompactHeader.Visible and not gui.MobileSprint.Visible,"School HUD stays out of the lobby")
hsState:SetAttribute("Phase","Hiding")
hsState:SetAttribute("HidingEndsAt",120)
hsState:SetAttribute("EndsAt",120)
hsState:SetAttribute("HiderCount",15)
hsState:SetAttribute("SeekerCount",1)
player:SetAttribute("HSParticipating",true)
refresh()
check(gui.CompactHeader.Visible and not gui.DesktopHeader.Visible,"Landscape phone receives compact header")
check(gui.CompactHeader.Timer.Text=="0:20","20-second hiding timer is displayed")
check(gui.CompactHeader.Counts.Text=="15 hiders • 1 seeker","Counts use singular and plural correctly")
check(gui.MobileSprint.Visible and not gui.DesktopSprint.Visible,"Phone uses the small right sprint button")
check(gui.MobileSprint.AnchorPoint==Vector2.new(1,1) and gui.MobileSprint.Position.X.Scale==1,"Phone sprint remains anchored on the right")
check(gui.MobileSprint.Size.X.Offset==100 and gui.MobileSprint.Size.Y.Offset==44,"Phone sprint preserves a practical touch target")
actions.HideAndSeekSprint(nil,Enum.UserInputState.Begin,{KeyCode=Enum.KeyCode.LeftShift})
check(requests[#requests]==true,"Keyboard sprint requests the server action")
actions.HideAndSeekSprint(nil,Enum.UserInputState.End,{KeyCode=Enum.KeyCode.LeftShift})
check(requests[#requests]==false,"Release stops sprinting")
player:SetAttribute("HSRole","Seeker")refresh()
check(not gui.MobileSprint.Active,"Seeker waits during the hiding period")
check(gui.SeekerBlindfold.Visible and gui.SeekerBlindfold.WaitingCard.Countdown.Text=="0:20","Seeker cannot watch hiders find their spots")
local session = Instance.new("Folder") session.Name,session.Parent = "PlaygroundSessionControls",fixture
session:SetAttribute("UIHidden",true)refresh()
check(gui.SeekerBlindfold.Visible,"Hide UI cannot remove the seeker blindfold")
session:SetAttribute("UIHidden",false)session:SetAttribute("SessionMenuOpen",true)refresh()
check(gui.SeekerBlindfold.Visible,"Settings cannot remove the seeker blindfold")
check(gui.SeekerBlindfold.Position==UDim2.fromOffset(-256,-256) and gui.SeekerBlindfold.Size==UDim2.new(1,512,1,512),"Blindfold covers all safe-area edges")
session:SetAttribute("SessionMenuOpen",false)refresh()
hsState:SetAttribute("Phase","Seeking") hsState:SetAttribute("EndsAt",280)refresh()
check(not gui.SeekerBlindfold.Visible,"Seeker view returns when searching starts")
check(gui.CompactHeader.Timer.Text=="3:00" and gui.MobileSprint.Active,"Three-minute search enables seeker sprint")
player:SetAttribute("HSHiding",true)refresh()
check(gui.LeaveLocker.Visible and not gui.MobileSprint.Active,"Locker hiding supplies a reliable exit button")
check(gui.LeaveLocker.Caption.Text=="LEAVE","Locker button displays the correct action")
actions.HideAndSeekLeaveLocker(nil,Enum.UserInputState.Begin)
check(exits[#exits]=="LeaveLocker","Exit action does not target other players")
player:SetAttribute("HSHiding",false)refresh()
camera.ViewportSize=Vector2.new(390,844)refresh()
check(gui.PortraitHeader.Visible and not gui.CompactHeader.Visible,"Portrait phone selects its authored header")
camera.ViewportSize=Vector2.new(1024,768)refresh()
check(gui.CompactHeader.Visible,"Tablet uses compact authored header")
camera.ViewportSize=Vector2.new(1920,1080)input.TouchEnabled=false refresh()
check(gui.DesktopHeader.Visible and gui.DesktopSprint.Visible,"Desktop selects desktop header and controls")
check(gui.DesktopHeader.Size==UDim2.fromOffset(340,94),"Runtime keeps the authored desktop geometry")
hsState:SetAttribute("Phase","Results")hsState:SetAttribute("WinnersText","Hiders win!")refresh()
check(not gui.MobileSprint.Visible and not gui.DesktopSprint.Visible,"Controls disappear during results")
check(gui.DesktopHeader.Hint.Text=="Hiders win!","Result message replaces instructions")
for _,viewport in {Vector2.new(568,320),Vector2.new(667,375),Vector2.new(852,393),Vector2.new(390,844),Vector2.new(375,667),Vector2.new(768,1024),Vector2.new(1024,768)}do
 local header = viewport.Y>viewport.X and gui.PortraitHeader or gui.CompactHeader
 check(header.Size.X.Offset<viewport.X-24 and header.Size.Y.Offset<viewport.Y*.25,"Header remains small and unclipped: "..tostring(viewport))
 local sprint = gui.MobileSprint
 local left=viewport.X+sprint.Position.X.Offset-sprint.Size.X.Offset
 local top=viewport.Y+sprint.Position.Y.Offset-sprint.Size.Y.Offset
 check(left>viewport.X*.5 and top>100,"Mobile sprint keeps the joystick and header clear: "..tostring(viewport))
end
destroyed:Fire()task.wait()
check(actions.HideAndSeekSprint==nil and actions.HideAndSeekLeaveLocker==nil,"Destroyed HUD removes its input bindings")
fixture:Destroy()
return {checks=checks,passed=true,livePlayersUnaffected=true,playStarted=false}
