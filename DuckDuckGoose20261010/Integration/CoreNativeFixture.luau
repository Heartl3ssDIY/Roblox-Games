assert(not game:GetService("RunService"):IsRunning(),"Edit mode required")
local fixture=Instance.new("Folder")
fixture.Name,fixture.Parent="DuckDuckGooseIntegrationFixture",game:GetService("ServerStorage")
local checks=0
local function check(value,message) checks+=1 assert(value,message) end
local function event() local e=Instance.new("BindableEvent")e.Parent=fixture return e end
local function moduleFrom(source,original)
 local m=Instance.new("ModuleScript")
 m.Name,m.Source,m.Capabilities,m.Sandboxed,m.Parent="FixtureModule",source,original.Capabilities,original.Sandboxed,fixture
 return require(m)
end
local players,roster={},{}
players.PlayerAdded,players.PlayerRemoving=event().Event,event().Event
function players:GetPlayers()return roster end
function players:GetPlayerByUserId(id)for _,p in roster do if p.UserId==id then return p end end end
local function makePlayer(id,ready)
 local attrs=Instance.new("Folder")attrs.Parent=fixture
 local char=Instance.new("Model")char.Name,char.Parent="FixtureRig"..id,fixture
 local h=Instance.new("Humanoid")h.Parent=char
 for _,name in {"HumanoidRootPart","Head","RightHand","UpperTorso"}do
  local p=Instance.new("Part")p.Name,p.Size,p.Anchored,p.CanCollide,p.Parent=name,Vector3.new(1,1,1),true,false,char
 end
 local backpack=Instance.new("Backpack")backpack.Parent=attrs
 local p={UserId=id,Name="Fixture"..id,Parent=players,Character=char}
 p.CharacterAdded,p.CharacterRemoving=event().Event,event().Event
 p.ChildAdded=attrs.ChildAdded
 function p:GetAttribute(name)return attrs:GetAttribute(name)end
 function p:SetAttribute(name,value)attrs:SetAttribute(name,value)end
 function p:GetAttributeChangedSignal(name)return attrs:GetAttributeChangedSignal(name)end
 function p:FindFirstChildOfClass(name)if name=="Backpack"then return backpack end end
 function p:FindFirstChild(name)return attrs:FindFirstChild(name)end
 function p:AddReplicationFocus()end
 function p:RemoveReplicationFocus()end
 p:SetAttribute("PCDataReady",ready)
 p:SetAttribute("PCBat","B01")
 table.insert(roster,p)
 return p
end
local a,b,observer=makePlayer(1,true),makePlayer(2,true),makePlayer(3,false)
local replicated,states={},{}
for _,name in {"PlaygroundState","BritishBulldogState","TagState","MudState","HideAndSeekState","DuckDuckGooseState"}do
 local state=Instance.new("Folder")state.Name,state.Parent=name,fixture states[name]=state
end
local assets=game:GetService("ReplicatedStorage"):FindFirstChild("PlaygroundCosmeticAssets")
function replicated:WaitForChild(name)
 if name=="PlaygroundCatalog"then return game:GetService("ReplicatedStorage").PlaygroundCatalog end
 return assert(states[name],name)
end
function replicated:FindFirstChild(name)if name=="PlaygroundCosmeticAssets"then return assets end return states[name]end
local heartbeat=event()
local mockGame={}
function mockGame:GetService(name)return ({Players=players,ReplicatedStorage=replicated,RunService={Heartbeat=heartbeat.Event}})[name]end
local clock=100
local mockWorld={}
function mockWorld:GetServerTimeNow()return clock end
local Coordinator=moduleFrom([==[return function(game,workspace)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Coordinator = {}
Coordinator.__index = Coordinator
local games = { "BritishBulldog", "TagYoureIt", "StuckInTheMud", "HideAndSeek", "DuckDuckGoose" }
local INTERMISSION_SECONDS = 35
local START_RETRY_SECONDS = 5
local titles = { BritishBulldog = "British Bulldog", TagYoureIt = "Tag You're It", StuckInTheMud = "Stuck in the Mud", HideAndSeek = "Hide and Seek", DuckDuckGoose = "Duck Duck Goose" }

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
	return player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or player:GetAttribute("MDParticipating") == true or player:GetAttribute("HSParticipating") == true or player:GetAttribute("DGParticipating") == true
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
	local attribute = ({ BritishBulldog = "BBParticipating", TagYoureIt = "TGParticipating", StuckInTheMud = "MDParticipating", HideAndSeek = "HSParticipating", DuckDuckGoose = "DGParticipating" })[active]
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
	for _, name in ipairs({ "BBParticipating", "TGParticipating", "MDParticipating", "HSParticipating", "DGParticipating" }) do
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
	local counts = { BritishBulldog = 0, TagYoureIt = 0, StuckInTheMud = 0, HideAndSeek = 0, DuckDuckGoose = 0 }
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

function Coordinator:_rewardDuckDuckGoose()
 local service = self.services.DuckDuckGoose
 if not service then return end
 local state = service.state
 local ids, participants = {}, {}
 for value in string.gmatch(state:GetAttribute("LastResultWinnerIds") or "", "%-?%d+") do table.insert(ids, tonumber(value)) end
 for value in string.gmatch(state:GetAttribute("LastResultParticipantIds") or "", "%-?%d+") do table.insert(participants, tonumber(value)) end
 self.economy:AwardRound("DG:" .. tostring(state:GetAttribute("LastResultRound")), ids, state:GetAttribute("LastResultPractice") == true, participants, { gameId = "DuckDuckGoose" })
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
end]==],game:GetService("ServerScriptService").PlaygroundCoordinator)(mockGame,mockWorld)
local services={}
local stateNames={BritishBulldog="BritishBulldogState",TagYoureIt="TagState",StuckInTheMud="MudState",HideAndSeek="HideAndSeekState",DuckDuckGoose="DuckDuckGooseState"}
for id,name in stateNames do
 local s={active=false,running=true,state=states[name],arena=Instance.new("Folder")}
 s.arena.Parent=fixture s.arena:SetAttribute("MinimumPlayers",2)
 function s:StartRound(selected)
  self.active,self.selected=true,selected
  self.state:SetAttribute("Phase",id=="HideAndSeek" and "Seeking" or "Playing")
  if id=="DuckDuckGoose"then
   self.state:SetAttribute("TurnPhase","Choosing")
   for _,p in selected do p:SetAttribute("DGParticipating",true)p:SetAttribute("DGRole","Duck")end
  end
  return true
 end
 function s:StopRound()
  self.active=false self.state:SetAttribute("Phase","Waiting")
  if id=="DuckDuckGoose"then for _,p in roster do p:SetAttribute("DGParticipating",false)p:SetAttribute("DGEliminated",false)p:SetAttribute("DGRole","")end end
 end
 services[id]=s
end
local rewards={}
local economy={}function economy:AwardRound(...)table.insert(rewards,{...})end
local lobby={Gameplay={VoteZone={CFrame=CFrame.new(),Size=Vector3.new(100,100,100)}}}
function lobby.Gameplay:FindFirstChild()return nil end
local coordinator=Coordinator.new(services,lobby,economy)
check(#coordinator:_readyPlayers()==2,"Only data-ready candidates start rounds")
check(coordinator:MinimumPlayers("DuckDuckGoose")==2,"Goose minimum is two")
check(coordinator:GameAvailable("DuckDuckGoose",2),"Two players can vote for Goose")
check(not coordinator:GameAvailable("DuckDuckGoose",1),"Solo Goose is unavailable")
coordinator:_step(100)
check(states.PlaygroundState:GetAttribute("Phase")=="Voting","Voting starts normally")
check(states.PlaygroundState:GetAttribute("VotingEndsAt")==135,"35 second intermission preserved")
check(states.PlaygroundState:GetAttribute("AvailableDuckDuckGoose")==true,"Fifth-game availability published")
check(coordinator:Vote(a,"DuckDuckGoose").ok and coordinator:Vote(b,"DuckDuckGoose").ok,"Both players can vote Goose")
check(states.PlaygroundState:GetAttribute("VotesDuckDuckGoose")==2,"Fifth-game votes counted")
check(coordinator:_chooseGame()=="DuckDuckGoose","Fifth game can win vote")
clock=134 coordinator:_step(clock)
check(not services.DuckDuckGoose.active,"Game cannot start before timer ends")
clock=135 coordinator:_step(clock)
check(services.DuckDuckGoose.active,"Goose starts when intermission ends")
check(coordinator:ActiveGame()=="DuckDuckGoose","Fifth game recognized as active")
check(states.PlaygroundState:GetAttribute("GameTitle")=="Duck Duck Goose","Fifth title is correct")
check(#services.DuckDuckGoose.selected==2,"Ready roster reaches service")
check(coordinator:_participating(a) and #coordinator:_readyPlayers()==0,"Goose players excluded from other rounds")
a:SetAttribute("PCAFKRequested",true)coordinator:_syncAFK(a)
check(a:GetAttribute("PCAFKQueued")==true and a:GetAttribute("PCAFK")==false,"AFK queues while playing")
local target=coordinator:_spectateTarget(observer,a.UserId)
check(target==a,"Lobby spectator sees active Goose players")
check(coordinator:_spectateTarget(a,b.UserId)==nil,"Active Goose cannot spectate")
local Equipment=moduleFrom([==[return function(game,workspace)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage:WaitForChild("PlaygroundCatalog"))
local Equipment = {}
Equipment.__index = Equipment

local sparkTexture = "rbxasset://textures/particles/sparkles_main.dds"
local smokeTexture = "rbxasset://textures/particles/smoke_main.dds"
local fireTexture = "rbxasset://textures/particles/fire_main.dds"
local starTexture = sparkTexture
local heartTexture = smokeTexture

local batEffects = {
	B01 = { name = "Sawdust Swirl", color = Color3.fromRGB(227, 169, 91), accent = Color3.fromRGB(255, 233, 185), texture = smokeTexture, rate = 5, speed = 0.55, size = 0.12, gravity = -0.8, spin = 75, glow = 0, squash = 0.6, trail = 0.12 },
	B02 = { name = "Alloy Glints", color = Color3.fromRGB(186, 231, 255), accent = Color3.new(1, 1, 1), texture = sparkTexture, rate = 3, speed = 0.12, size = 0.23, gravity = 0.1, spin = 15, glow = 0.55, lines = "alloy", trail = 0.14 },
	B03 = { name = "Varsity Confetti", color = Color3.fromRGB(255, 85, 105), accent = Color3.fromRGB(112, 195, 255), texture = sparkTexture, rate = 7, speed = 1, size = 0.16, gravity = -2.2, spin = 180, glow = 0, squash = 1.3, secondary = true, trail = 0.15 },
	B04 = { name = "Hazard Beacon", color = Color3.fromRGB(255, 153, 36), accent = Color3.fromRGB(255, 244, 172), texture = sparkTexture, rate = 3, speed = 0.2, size = 0.2, gravity = 0.2, spin = 0, glow = 0.65, lines = "hazard", trail = 0.14 },
	B05 = { name = "Bubblegum Hearts", color = Color3.fromRGB(255, 136, 209), accent = Color3.fromRGB(255, 226, 250), texture = heartTexture, rate = 3, speed = 0.7, size = 0.26, gravity = 0.3, spin = 20, glow = 0.1, secondary = true, lines = "heart", trail = 0.19 },
	B06 = { name = "Muddy Droplets", color = Color3.fromRGB(139, 90, 45), accent = Color3.fromRGB(191, 156, 83), texture = smokeTexture, rate = 6, speed = 0.6, size = 0.22, gravity = -3, spin = 45, glow = 0, squash = 0.3, trail = 0.12 },
	B07 = { name = "Coil Embers", color = Color3.fromRGB(255, 97, 25), accent = Color3.fromRGB(255, 217, 70), texture = fireTexture, rate = 6, speed = 0.65, size = 0.29, gravity = 0.9, spin = 20, glow = 0.75, secondary = true, trail = 0.18 },
	B08 = { name = "Frost Crystals", color = Color3.fromRGB(124, 229, 255), accent = Color3.fromRGB(232, 255, 255), texture = sparkTexture, rate = 4, speed = 0.25, size = 0.24, gravity = -0.3, spin = 40, glow = 0.35, mist = true, trail = 0.22 },
	B09 = { name = "Circuit Arcs", color = Color3.fromRGB(77, 139, 255), accent = Color3.fromRGB(199, 253, 255), texture = sparkTexture, rate = 7, speed = 1, size = 0.12, gravity = 0, spin = 120, glow = 0.8, lines = "lightning", trail = 0.12 },
	B10 = { name = "Arcade Pixels", color = Color3.fromRGB(248, 89, 235), accent = Color3.fromRGB(87, 247, 219), texture = sparkTexture, rate = 6, speed = 0.55, size = 0.16, gravity = 0.35, spin = 0, glow = 0.5, squash = -0.4, lines = "pixels", trail = 0.1 },
	B11 = { name = "Orbit Stardust", color = Color3.fromRGB(176, 126, 255), accent = Color3.fromRGB(134, 222, 255), texture = starTexture, rate = 3, speed = 0.3, size = 0.19, gravity = 0.25, spin = 65, glow = 0.6, lines = "orbit", trail = 0.25 },
	B12 = { name = "Champion Stars", color = Color3.fromRGB(255, 213, 64), accent = Color3.fromRGB(255, 247, 180), texture = starTexture, rate = 4, speed = 0.55, size = 0.26, gravity = 0.45, spin = 30, glow = 0.45, lines = "crown", trail = 0.2 },
	B13 = { name = "Skatepark Ribbons", color = Color3.fromRGB(78, 228, 206), accent = Color3.fromRGB(255, 133, 140), texture = sparkTexture, rate = 3, speed = 0.35, size = 0.12, gravity = 0, spin = 80, glow = 0.25, ribbons = true, trail = 0.23 },
	B14 = { name = "Ocean Spray", color = Color3.fromRGB(62, 218, 214), accent = Color3.fromRGB(161, 247, 255), texture = smokeTexture, rate = 5, speed = 0.7, size = 0.19, gravity = 0.6, spin = 35, glow = 0.15, mist = true, lines = "wave", trail = 0.23 },
	B15 = { name = "Sunburst Rays", color = Color3.fromRGB(255, 175, 35), accent = Color3.fromRGB(255, 246, 112), texture = sparkTexture, rate = 5, speed = 0.6, size = 0.16, gravity = 0.45, spin = 60, glow = 0.65, lines = "sun", trail = 0.21 },
	B16 = { name = "Fossil Dust", color = Color3.fromRGB(218, 190, 134), accent = Color3.fromRGB(255, 240, 196), texture = smokeTexture, rate = 4, speed = 0.4, size = 0.14, gravity = -0.7, spin = 35, glow = 0, trail = 0.18, lines = "alloy" },
	B17 = { name = "Dragon Scales", color = Color3.fromRGB(65, 199, 116), accent = Color3.fromRGB(251, 213, 105), texture = sparkTexture, rate = 5, speed = 0.5, size = 0.18, gravity = 0.3, spin = 45, glow = 0.3, trail = 0.18, lines = "wave" },
	B18 = { name = "Breakfast Crumbs", color = Color3.fromRGB(229, 165, 75), accent = Color3.fromRGB(255, 233, 158), texture = smokeTexture, rate = 4, speed = 0.6, size = 0.11, gravity = -1.2, spin = 95, glow = 0, trail = 0.18 },
	B19 = { name = "Cloud Wisps", color = Color3.fromRGB(197, 209, 253), accent = Color3.fromRGB(255, 249, 233), texture = smokeTexture, rate = 3, speed = 0.4, size = 0.25, gravity = 0.65, spin = 20, glow = 0.1, trail = 0.18, lines = "orbit" },
	B20 = { name = "Bamboo Leaves", color = Color3.fromRGB(130, 203, 103), accent = Color3.fromRGB(230, 236, 148), texture = sparkTexture, rate = 5, speed = 0.45, size = 0.14, gravity = -0.25, spin = 110, glow = 0.1, trail = 0.18, lines = "wave" },
	B21 = { name = "Combo Pixels", color = Color3.fromRGB(96, 202, 245), accent = Color3.fromRGB(254, 115, 174), texture = sparkTexture, rate = 6, speed = 0.55, size = 0.16, gravity = 0.2, spin = 0, glow = 0.45, trail = 0.18, lines = "pixels" },
	B22 = { name = "Honey Sparks", color = Color3.fromRGB(249, 191, 63), accent = Color3.fromRGB(255, 232, 142), texture = sparkTexture, rate = 4, speed = 0.4, size = 0.15, gravity = -0.15, spin = 35, glow = 0.35, trail = 0.18, lines = "hazard" },
	B23 = { name = "Clockwork Glints", color = Color3.fromRGB(202, 159, 90), accent = Color3.fromRGB(255, 230, 176), texture = sparkTexture, rate = 3, speed = 0.2, size = 0.19, gravity = 0.05, spin = 65, glow = 0.3, trail = 0.18, lines = "orbit" },
	B24 = { name = "Patchwork Confetti", color = Color3.fromRGB(225, 133, 212), accent = Color3.fromRGB(108, 223, 226), texture = sparkTexture, rate = 6, speed = 0.7, size = 0.15, gravity = -0.5, spin = 180, glow = 0.2, trail = 0.18, lines = "pixels" },
	B25 = { name = "Prism Gleam", color = Color3.fromRGB(121, 199, 255), accent = Color3.fromRGB(252, 178, 250), texture = sparkTexture, rate = 5, speed = 0.5, size = 0.19, gravity = 0.35, spin = 50, glow = 0.6, trail = 0.18, lines = "sun" },
}

local function effectAttachment(anchor, name, position)
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Position = position
	attachment.Parent = anchor
	return attachment
end

local function effectEmitter(parent, name, effect, secondary)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	emitter.Texture = effect.texture
	emitter.Color = ColorSequence.new(secondary and effect.accent or effect.color, effect.accent)
	emitter.Rate = secondary and 2 or effect.rate
	emitter.Lifetime = NumberRange.new(0.45, 0.95)
	emitter.Speed = NumberRange.new(effect.speed * 0.5, effect.speed)
	emitter.Acceleration = Vector3.new(0, effect.gravity, 0)
	emitter.Drag = 1.5
	emitter.SpreadAngle = Vector2.new(70, 70)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-effect.spin, effect.spin)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, effect.size * 0.3), NumberSequenceKeypoint.new(0.2, effect.size), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.15, 0.12), NumberSequenceKeypoint.new(0.75, 0.3), NumberSequenceKeypoint.new(1, 1) })
	emitter.LightEmission = effect.glow
	emitter.LightInfluence = 0.2
	emitter.VelocityInheritance = 0.15
	emitter.Squash = NumberSequence.new(effect.squash or 0)
	emitter:SetAttribute("BatHitBurst", secondary and 4 or 8)
	emitter.Parent = parent
	return emitter
end

local function effectLine(anchor, folder, name, first, last, color, width)
	local beam = Instance.new("Beam")
	beam.Name = name
	beam.Attachment0 = effectAttachment(anchor, name .. "A", first)
	beam.Attachment1 = effectAttachment(anchor, name .. "B", last)
	beam.Width0 = width or 0.035
	beam.Width1 = width or 0.035
	beam.Color = ColorSequence.new(color)
	beam.Transparency = NumberSequence.new(0.22)
	beam.LightEmission = 0.65
	beam.LightInfluence = 0.1
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Parent = folder
	return beam
end

local function effectTrail(anchor, folder, name, first, last, color, lifetime)
	local trail = Instance.new("Trail")
	trail.Name = name
	trail.Attachment0 = effectAttachment(anchor, name .. "A", first)
	trail.Attachment1 = effectAttachment(anchor, name .. "B", last)
	trail.Color = ColorSequence.new(color)
	trail.Lifetime = lifetime
	trail.MinLength = 0.06
	trail.FaceCamera = true
	trail.LightEmission = 0.35
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
	trail.Parent = folder
end

function Equipment:_attachBatEffects(carrier, anchor, item, sourceSize, gripHeight)
	local effect = batEffects[item.id]
	if not effect then return end
	carrier:SetAttribute("HeldEffect", effect.name)
	local folder = Instance.new("Folder")
	folder.Name = "HeldVFX"
	folder.Parent = carrier
	local top = sourceSize.Y - gripHeight
	local middle = top * 0.68
	local radius = math.clamp(math.max(sourceSize.X, sourceSize.Z) * 0.55, 0.18, 0.48)
	local tip = effectAttachment(anchor, "BatEffectTip", Vector3.new(0, top, 0))
	local barrel = effectAttachment(anchor, "BatEffectBarrel", Vector3.new(0, middle, 0))
	effectEmitter(tip, effect.name, effect, false)
	if effect.secondary then effectEmitter(barrel, effect.name .. "Accent", effect, true) end
	if effect.mist then
		local mist = effectEmitter(barrel, "SoftMist", effect, true)
		mist.Texture = smokeTexture
		mist.Size = NumberSequence.new(0.13, 0.4)
		mist.Transparency = NumberSequence.new(0.82, 1)
	end
	effectTrail(anchor, folder, "MotionRibbon", Vector3.new(-radius * 0.7, top, 0), Vector3.new(radius * 0.7, top, 0), effect.color, effect.trail)
	if effect.ribbons then
		for i = -1, 1, 2 do
			local point = Vector3.new(radius * i, middle, 0)
			effectTrail(anchor, folder, "SkateRibbon" .. i, point, point + Vector3.new(0, 0.14, 0), i == -1 and effect.accent or effect.color, 0.3)
		end
	end
	local style = effect.lines
	if style == "orbit" or style == "hazard" then
		local count = style == "orbit" and 16 or 8
		for i = 1, count do
			local a, b = (i - 1) / count * math.pi * 2, i / count * math.pi * 2
			local tilt = style == "orbit" and 0.22 or 0
			local p = Vector3.new(math.cos(a) * radius * 1.3, middle + math.sin(a) * tilt, math.sin(a) * radius * 1.3)
			local q = Vector3.new(math.cos(b) * radius * 1.3, middle + math.sin(b) * tilt, math.sin(b) * radius * 1.3)
			effectLine(anchor, folder, "Ring" .. i, p, q, i % 2 == 0 and effect.color or effect.accent)
		end
	elseif style == "heart" then
		local function point(angle)
			local x = 16 * math.sin(angle) ^ 3
			local y = 13 * math.cos(angle) - 5 * math.cos(2 * angle) - 2 * math.cos(3 * angle) - math.cos(4 * angle)
			return Vector3.new(x / 16 * radius, top * 0.8 + y / 16 * radius, -radius * 1.25)
		end
		for i = 1, 20 do
			effectLine(anchor, folder, "Heart" .. i, point((i - 1) / 20 * math.pi * 2), point(i / 20 * math.pi * 2), effect.accent, 0.028)
		end
	elseif style == "lightning" then
		for side = -1, 1, 2 do
			local previous = Vector3.new(radius * side, middle * 0.55, 0)
			for i = 1, 5 do
				local nextPoint = Vector3.new((radius + (i % 2) * 0.1) * side, middle * 0.55 + i * top * 0.09, (i % 2 - 0.5) * 0.2)
				effectLine(anchor, folder, "Arc" .. side .. "_" .. i, previous, nextPoint, effect.accent, 0.028)
				previous = nextPoint
			end
		end
	elseif style == "sun" then
		for i = 1, 8 do
			local angle = i / 8 * math.pi * 2
			local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
			effectLine(anchor, folder, "Ray" .. i, Vector3.new(0, top * 0.87, 0) + direction * radius, Vector3.new(0, top * 0.87, 0) + direction * radius * 1.5, effect.accent, 0.04)
		end
	elseif style == "pixels" then
		for i = 1, 4 do
			local center = Vector3.new((i % 2 == 0 and -1 or 1) * radius * 1.3, middle + (i - 2.5) * 0.2, 0)
			local color = i % 2 == 0 and effect.color or effect.accent
			effectLine(anchor, folder, "Pixel" .. i, center, center + Vector3.new(0.07, 0, 0), color, 0.07)
		end
	elseif style == "wave" then
		for side = -1, 1, 2 do
			local previous = Vector3.new(radius * side, middle * 0.55, 0)
			for i = 1, 8 do
				local point = Vector3.new((radius + math.sin(i * 0.8) * 0.1) * side, middle * 0.55 + top * i * 0.06, 0)
				effectLine(anchor, folder, "Wave" .. side .. "_" .. i, previous, point, effect.accent, 0.025)
				previous = point
			end
		end
	elseif style == "alloy" then
		for side = -1, 1, 2 do
			effectLine(anchor, folder, "ChromeEdge" .. side, Vector3.new(radius * side, middle, 0), Vector3.new(radius * side * 0.8, top * 0.91, 0), effect.accent, 0.02)
		end
	elseif style == "crown" then
		local previous = Vector3.new(-radius, top * 0.85, -radius)
		for i = 1, 4 do
			local point = Vector3.new(-radius + i * radius * 0.5, top * 0.85 + (i % 2) * 0.15, -radius)
			effectLine(anchor, folder, "Crown" .. i, previous, point, effect.accent, 0.035)
			previous = point
		end
	end
end

function Equipment:_batHitEffect(record)
	if not record.bat or not record.bat.Parent then return end
	for _, emitter in ipairs(record.bat:GetDescendants()) do
		if emitter:IsA("ParticleEmitter") then emitter:Emit(emitter:GetAttribute("BatHitBurst") or 6) end
	end
end


local function disconnect(connections)
	for _, connection in ipairs(connections) do connection:Disconnect() end
	table.clear(connections)
end

local function participating(player)
	return player:GetAttribute("BBParticipating") == true
		or player:GetAttribute("TGParticipating") == true
		or player:GetAttribute("MDParticipating") == true
		or player:GetAttribute("HSParticipating") == true or player:GetAttribute("DGParticipating") == true or player:GetAttribute("DGEliminated") == true
end

local function visibleBounds(model)
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 1 and part:GetAttribute("PCStudLayer") ~= true then
			for x = -1, 1, 2 do for y = -1, 1, 2 do for z = -1, 1, 2 do
				local point = part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z) * 0.5)
				low = low:Min(point)
				high = high:Max(point)
			end end end
		end
	end
	if low.X == math.huge then return nil end
	return low, high
end

local function anchorPart(name)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(0.15, 0.15, 0.15)
	part.Transparency = 1
	part.Massless = true
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	return part
end

local function weldModel(model, anchor)
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("LuaSourceContainer") then child:Destroy()
		elseif child:IsA("BasePart") then
			child.Anchored = false
			child.Massless = true
			child.CanCollide = false
			child.CanTouch = false
			child.CanQuery = false
			local coatingWeld = child:GetAttribute("PCStudLayer") == true and child:FindFirstChild("StudFinishWeld")
			if not coatingWeld or not coatingWeld:IsA("WeldConstraint") or not coatingWeld.Part0 or not coatingWeld.Part1 then
				local weld = Instance.new("WeldConstraint")
				weld.Name = "CosmeticGripWeld"
				weld.Part0 = anchor
				weld.Part1 = child
				weld.Parent = child
			end
		elseif child:IsA("Highlight") then child.Adornee = model end
	end
end

function Equipment.new(batServices, toys)
	return setmetatable({ running = false, records = {}, connections = {}, batServices = batServices or {}, toys = toys }, Equipment)
end

function Equipment:_weaponGame(player)
	if player:GetAttribute("MDParticipating") == true then return nil end
	if player:GetAttribute("BBParticipating") == true and player:GetAttribute("BBRole") == "Bulldog" then
		local state = ReplicatedStorage:FindFirstChild("BritishBulldogState")
		if state and state:GetAttribute("Phase") == "Crossing" then return "BritishBulldog" end
	elseif player:GetAttribute("TGParticipating") == true and player:GetAttribute("TGRole") == "Tagger" then
		local state = ReplicatedStorage:FindFirstChild("TagState")
		if state and state:GetAttribute("Phase") == "Playing" then return "TagYoureIt" end
	elseif player:GetAttribute("HSParticipating") == true and player:GetAttribute("HSRole") == "Seeker" then
		local state = ReplicatedStorage:FindFirstChild("HideAndSeekState")
		if state and state:GetAttribute("Phase") == "Seeking" then return "HideAndSeek" end
	elseif player:GetAttribute("DGParticipating") == true and player:GetAttribute("DGRole") == "Goose" then
		local state = ReplicatedStorage:FindFirstChild("DuckDuckGooseState")
		if state and state:GetAttribute("Phase") == "Playing" and state:GetAttribute("TurnPhase") == "Chasing" then return "DuckDuckGoose" end
	end
	return nil
end

function Equipment:_batService(gameId)
	return self.batServices[gameId]
end

function Equipment:_cancelBatHit(record)
	if not record.batGame then return end
	local service = self:_batService(record.batGame)
	if service and service.CancelBatSwing then service:CancelBatSwing(record.player) end
end

function Equipment:_activateBat(record)
	local tool = record.bat
	local gameId = self:_weaponGame(record.player)
	if not tool or not tool.Enabled or tool.Parent ~= record.character or record.player.Character ~= record.character
		or not gameId or record.batGame ~= gameId or record.player:GetAttribute("PCDataReady") ~= true
		or record.player:GetAttribute("BBRagdolled") == true or record.player:GetAttribute("TGRagdolled") == true or record.player:GetAttribute("HSRagdolled") == true or record.player:GetAttribute("DGRagdolled") == true then return false end
	local service = self:_batService(gameId)
	if not service or not service.TryBatSwing then return false end
	local accepted = service:TryBatSwing(record.player)
	if accepted then
		tool:SetAttribute("BatSwingAt", workspace:GetServerTimeNow())
		task.delay(0.5, function() if not record.closed then self:_queue(record) end end)
	end
	return accepted == true
end

function Equipment:_clearBat(record)
	if record.character then
		record.character:SetAttribute("PCBatHeld", false)
		record.character:SetAttribute("PCBatGame", nil)
	end
	self:_cancelBatHit(record)
	if record.batConnections then disconnect(record.batConnections) end
	local model = record.bat
	record.bat = nil
	record.batId = nil
	record.batGame = nil
	if model then model:Destroy() end
end

function Equipment:_reconcileToys(record, keep)
	local containers = { record.character, record.player.Character, record.player:FindFirstChildOfClass("Backpack"), record.player:FindFirstChild("StarterGear") }
	local seen = {}
	for _, container in pairs(containers) do
		if container and not seen[container] then
			seen[container] = true
			for _, child in ipairs(container:GetChildren()) do
				local item = Catalog.ById[child:GetAttribute("CatalogId")]
				local toy = child:IsA("Tool") and (child:GetAttribute("PCToy") == true
					or child:GetAttribute("PCCosmeticEquipment") == true and item and item.slot == "Gear")
				if toy and child ~= keep then child:Destroy() end
			end
		end
	end
end

function Equipment:_toyAllowed(record)
	return not record.roundPreparing and not participating(record.player) and self.toys and self.toys:CanHold(record.player) == true
end

function Equipment:_clearGear(record)
	if self.toys then self.toys:CancelAction(record.player) end
	if record.character then record.character:SetAttribute("PCToyHeld", nil) end
	disconnect(record.gearConnections)
	local tool = record.gear
	record.gear = nil
	record.gearId = nil
	if tool then tool:Destroy() end
	self:_reconcileToys(record, nil)
end

function Equipment:_queue(record)
	if not self.running or record.closed or record.queued then return end
	record.queued = true
	task.defer(function()
		record.queued = false
		if self.running and not record.closed then self:_refresh(record) end
	end)
end

function Equipment:_makeBat(record, item, hand, original, gameId)
	local visual = original:Clone()
	local low, high = visibleBounds(visual)
	if not low then visual:Destroy() return end
	local size = high - low
	local grip = Vector3.new((low.X + high.X) * 0.5, low.Y + math.min(size.Y * 0.14, 0.42), (low.Z + high.Z) * 0.5)
	local carrier = Instance.new("Tool")
	carrier.Name = item.name
	carrier.ToolTip = "Click / tap to swing"
	carrier.RequiresHandle = true
	carrier.CanBeDropped = false
	carrier.ManualActivationOnly = false
	carrier.Grip = CFrame.identity
	carrier:SetAttribute("PCCosmeticEquipment", true)
	carrier:SetAttribute("PCBatWeapon", true)
	carrier:SetAttribute("WeaponGame", gameId)
	carrier:SetAttribute("BatSwingAt", 0)
	carrier:SetAttribute("CatalogId", item.id)
	local anchor = anchorPart("Handle")
	anchor.Parent = carrier
	local palm = Instance.new("Attachment")
	palm.Name = "RightGripAttachment"
	palm.CFrame = carrier.Grip
	palm.Parent = anchor
	visual.Name = "Visual"
	visual:PivotTo(CFrame.new(-grip) * visual:GetPivot())
	visual.Parent = carrier
	weldModel(visual, anchor)
	self:_attachBatEffects(carrier, anchor, item, size, math.min(size.Y * 0.14, 0.42))
	record.bat = carrier
	record.batId = item.id
	record.batGame = gameId
	record.batConnections = record.batConnections or {}
	local function mirrorHeld(held)
		if record.bat ~= carrier or not record.character then return end
		record.character:SetAttribute("PCBatHeld", held)
		record.character:SetAttribute("PCBatGame", held and gameId or nil)
	end
	table.insert(record.batConnections, carrier.Equipped:Connect(function() mirrorHeld(true) end))
	table.insert(record.batConnections, carrier.Activated:Connect(function() self:_activateBat(record) end))
	table.insert(record.batConnections, carrier.Unequipped:Connect(function()
		mirrorHeld(false)
		self:_cancelBatHit(record)
		self:_queue(record)
	end))
	table.insert(record.batConnections, carrier.Destroying:Connect(function() mirrorHeld(false) self:_cancelBatHit(record) end))
	local humanoid = record.character:FindFirstChildOfClass("Humanoid")
	carrier.Parent = record.player:FindFirstChildOfClass("Backpack") or record.character
	if humanoid then humanoid:EquipTool(carrier) end
	mirrorHeld(carrier.Parent == record.character)
end

function Equipment:_makeGear(record, item, backpack, original)
	local visual = original:Clone()
	local low, high = visibleBounds(visual)
	if not low then visual:Destroy() return end
	local center = (low + high) * 0.5
	local size = high - low
	local grip = Vector3.new(center.X, low.Y + math.min(size.Y * 0.25, 0.45), center.Z + size.Z * 0.2)
	visual:PivotTo(CFrame.new(-grip) * visual:GetPivot())
	local tool = Instance.new("Tool")
	tool.Name = item.name
	tool.ToolTip = item.name .. " · lobby toy"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.Enabled = true
	tool.ManualActivationOnly = true
	tool.Grip = CFrame.new(0, -0.15, 0)
	tool:SetAttribute("PCCosmeticEquipment", true)
	tool:SetAttribute("CatalogId", item.id)
	tool:SetAttribute("PCToy", true)
	local handle = anchorPart("Handle")
	handle.Parent = tool
	visual.Name = "Visual"
	visual.Parent = tool
	weldModel(visual, handle)
	record.gear = tool
	record.gearId = item.id
	local function mirrorHeld(held)
		if record.gear ~= tool or not record.character then return end
		record.character:SetAttribute("PCToyHeld", held and item.id or nil)
		if self.toys then
			if held then self.toys:Hold(record.player) else self.toys:CancelAction(record.player) end
		end
	end
	table.insert(record.gearConnections, tool.Equipped:Connect(function()
		if not self:_toyAllowed(record) then self:_clearGear(record) self:_queue(record) else mirrorHeld(true) end
	end))
	table.insert(record.gearConnections, tool.Unequipped:Connect(function() mirrorHeld(false) end))
	if item.id == "M14" then
		local flame = anchorPart("TorchFlame")
		flame.CFrame = CFrame.new(0, size.Y - math.min(size.Y * 0.25, 0.45), -size.Z * 0.2)
		flame.Parent = tool
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = handle, flame, flame
		local fire = Instance.new("Fire")
		fire.Name, fire.Size, fire.Heat, fire.Parent = "CampFlame", 2.4, 3, flame
		local light = Instance.new("PointLight")
		light.Color, light.Brightness, light.Range, light.Parent = Color3.fromRGB(255, 170, 70), 0.6, 9, flame
	end
	table.insert(record.gearConnections, tool.AncestryChanged:Connect(function() self:_queue(record) end))
	tool.Parent = backpack
	local humanoid = record.character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid:EquipTool(tool) end
	mirrorHeld(tool.Parent == record.character)
end

function Equipment:_refresh(record)
	if participating(record.player) then
		record.roundPreparing = false
		record.player:SetAttribute("PCToyRoundPreparing", false)
	end
	self:_reconcileToys(record, record.gear)
	local player = record.player
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local ready = player:GetAttribute("PCDataReady") == true
	if character ~= record.character or not ready or not humanoid or humanoid.Health <= 0 then
		if self.toys then self.toys:ClearPlayer(player) end
		self:_clearBat(record)
		self:_clearGear(record)
		return
	end
	local assets = ReplicatedStorage:FindFirstChild("PlaygroundCosmeticAssets")
	local batId = player:GetAttribute("PCBat")
	local bat = (typeof(batId) == "string" and Catalog.ById[batId]) or Catalog.ById.B01
	local gameId = self:_weaponGame(player)
	local ragdolled = player:GetAttribute("BBRagdolled") == true or player:GetAttribute("TGRagdolled") == true or player:GetAttribute("HSRagdolled") == true or player:GetAttribute("DGRagdolled") == true
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local batAsset = bat and assets and assets:FindFirstChild(bat.id)
	if not gameId or ragdolled or not bat or bat.slot ~= "Bat" or bat.available == false or not hand or not hand:IsA("BasePart") or not batAsset or not batAsset:IsA("Model") then
		local at = record.bat and record.bat:GetAttribute("BatSwingAt")
		local tagState = ReplicatedStorage:FindFirstChild("TagState")
		local finishing = record.batGame == "TagYoureIt" and player:GetAttribute("TGParticipating") == true and player:GetAttribute("TGRole") == "Runner"
			and not ragdolled and tagState and tagState:GetAttribute("Phase") == "Playing" and typeof(at) == "number" and workspace:GetServerTimeNow() - at < 0.48
		if finishing then record.bat.Enabled = false self:_cancelBatHit(record) else self:_clearBat(record) end
	elseif record.batId ~= bat.id or record.batGame ~= gameId or not record.bat or record.bat.Parent ~= character then
		self:_clearBat(record)
		self:_makeBat(record, bat, hand, batAsset, gameId)
	else
		record.bat.Enabled = true
		character:SetAttribute("PCBatHeld", true)
		character:SetAttribute("PCBatGame", gameId)
	end
	local toyAllowed = self:_toyAllowed(record)
	if not toyAllowed and self.toys then self.toys:ClearPlayer(player) end
	local gearId = player:GetAttribute("PCGear")
	local gear = typeof(gearId) == "string" and Catalog.ById[gearId]
	local backpack = player:FindFirstChildOfClass("Backpack")
	local gearAsset = gear and assets and assets:FindFirstChild(gear.id)
	if not toyAllowed or not gear or gear.slot ~= "Gear" or gear.available == false or not backpack or not gearAsset or not gearAsset:IsA("Model") then
		self:_clearGear(record)
	elseif record.gearId ~= gear.id or not record.gear or (record.gear.Parent ~= backpack and record.gear.Parent ~= character) then
		self:_clearGear(record)
		self:_makeGear(record, gear, backpack, gearAsset)
	elseif record.gear.Parent ~= character then
		humanoid:EquipTool(record.gear)
		character:SetAttribute("PCToyHeld", gear.id)
		if self.toys then self.toys:Hold(player) end
	end
end

function Equipment:_bindCharacter(record, character)
	disconnect(record.characterConnections)
	if self.toys then self.toys:ClearPlayer(record.player) end
	self:_clearBat(record)
	self:_clearGear(record)
	record.character = character
	character:SetAttribute("PCBatHeld", false)
	character:SetAttribute("PCBatGame", nil)
	record.humanoid = nil
	local function bindHumanoid()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and record.humanoid ~= humanoid then
			record.humanoid = humanoid
			table.insert(record.characterConnections, humanoid.Died:Connect(function()
				if self.toys then self.toys:ClearPlayer(record.player) end
				self:_clearBat(record)
				self:_clearGear(record)
			end))
		end
	end
	bindHumanoid()
	table.insert(record.characterConnections, character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child:GetAttribute("PCToy") == true and not self:_toyAllowed(record) then self:_clearGear(record) end
		bindHumanoid()
		self:_queue(record)
	end))
	table.insert(record.characterConnections, character.ChildRemoved:Connect(function()
		self:_queue(record)
	end))
	self:_queue(record)
end

function Equipment:_bindBackpack(record, backpack)
	disconnect(record.backpackConnections)
	record.backpack = backpack
	if not backpack then return end
	table.insert(record.backpackConnections, backpack.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child:GetAttribute("PCToy") == true and not self:_toyAllowed(record) then self:_clearGear(record) end
		self:_queue(record)
	end))
	table.insert(record.backpackConnections, backpack.ChildRemoved:Connect(function() self:_queue(record) end))
	self:_reconcileToys(record, record.gear)
	self:_queue(record)
end

function Equipment:_addPlayer(player)
	if self.records[player] then return end
	local record = { player = player, connections = {}, characterConnections = {}, gearConnections = {}, batConnections = {}, backpackConnections = {}, closed = false }
	self.records[player] = record
	table.insert(record.connections, player:GetAttributeChangedSignal("PCBatHitSerial"):Connect(function() self:_batHitEffect(record) end))
	for _, attribute in ipairs({ "PCBat", "PCGear", "PCDataReady", "BBRole", "BBParticipating", "TGRole", "TGParticipating", "MDParticipating", "BBRagdolled", "TGRagdolled", "HSParticipating", "DGParticipating", "DGEliminated", "HSRole", "HSRagdolled", "DGRole", "DGRagdolled" }) do
		table.insert(record.connections, player:GetAttributeChangedSignal(attribute):Connect(function()
			if participating(player) then
				record.roundPreparing = false
				player:SetAttribute("PCToyRoundPreparing", false)
				if self.toys then self.toys:ClearPlayer(player) end
				self:_clearGear(record)
			end
			self:_queue(record)
		end))
	end
	table.insert(record.connections, player.CharacterAdded:Connect(function(character) self:_bindCharacter(record, character) end))
	table.insert(record.connections, player.CharacterRemoving:Connect(function(character)
		if character == record.character then
			if self.toys then self.toys:ClearPlayer(record.player) end
			disconnect(record.characterConnections)
			self:_clearBat(record)
			self:_clearGear(record)
			record.character = nil
		end
	end))
	table.insert(record.connections, player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then self:_bindBackpack(record, child) end
	end))
	self:_bindBackpack(record, player:FindFirstChildOfClass("Backpack"))
	if player.Character then self:_bindCharacter(record, player.Character) end
end

function Equipment:_removePlayer(player)
	local record = self.records[player]
	if not record then return end
	record.closed = true
	if self.toys then self.toys:ClearPlayer(player) end
	disconnect(record.connections)
	disconnect(record.characterConnections)
	disconnect(record.backpackConnections)
	player:SetAttribute("PCToyRoundPreparing", false)
	self:_clearBat(record)
	self:_clearGear(record)
	self.records[player] = nil
end

function Equipment:UseToy(player, aim)
	local record = self.records[player]
	if not self.running or not record or record.closed or not self.toys then return { ok = false, message = "Toys are loading." } end
	if not self:_toyAllowed(record) then
		self.toys:ClearPlayer(player)
		self:_clearGear(record)
		return { ok = false, message = "Toys are for the lobby." }
	end
	return self.toys:Use(player, record.gear, aim)
end

function Equipment:PrepareRound(selected)
	local players = typeof(selected) == "Instance" and { selected } or selected or Players:GetPlayers()
	for _, player in ipairs(players) do
		if player.Parent == Players then
			local record = self.records[player]
			if record then
				record.roundPreparing = true
				record.prepareSerial = (record.prepareSerial or 0) + 1
				local serial = record.prepareSerial
				player:SetAttribute("PCToyRoundPreparing", true)
				self:_clearGear(record)
				task.delay(3, function()
					if self.running and not record.closed and record.prepareSerial == serial and not participating(player) then
						record.roundPreparing = false
						player:SetAttribute("PCToyRoundPreparing", false)
						self:_queue(record)
					end
				end)
			end
			if self.toys then self.toys:ClearPlayer(player) end
		end
	end
end

function Equipment:Start()
	if self.running then return self end
	self.running = true
	for _, name in ipairs({ "BritishBulldogState", "TagState", "HideAndSeekState", "DuckDuckGooseState" }) do
		local state = ReplicatedStorage:FindFirstChild(name)
		if state then
			for _, attribute in { "Phase", "TurnPhase" } do
				table.insert(self.connections, state:GetAttributeChangedSignal(attribute):Connect(function()
					for _, record in pairs(self.records) do self:_queue(record) end
				end))
			end
		end
	end
	table.insert(self.connections, Players.PlayerAdded:Connect(function(player) self:_addPlayer(player) end))
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player) self:_removePlayer(player) end))
	local assets = ReplicatedStorage:FindFirstChild("PlaygroundCosmeticAssets")
	if assets then
		table.insert(self.connections, assets.ChildAdded:Connect(function()
			for _, record in pairs(self.records) do self:_queue(record) end
		end))
	end
	local elapsed = 0
	table.insert(self.connections, game:GetService("RunService").Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.25 then return end
		elapsed = 0
		for _, record in pairs(self.records) do
			local allowed = self:_toyAllowed(record) == true
			if record.toyAllowed ~= allowed then
				record.toyAllowed = allowed
				if not allowed then
					if self.toys then self.toys:ClearPlayer(record.player) end
					self:_clearGear(record)
				end
				self:_queue(record)
			end
		end
	end))
	for _, player in ipairs(Players:GetPlayers()) do self:_addPlayer(player) end
	return self
end

function Equipment:Stop()
	self.running = false
	disconnect(self.connections)
	local players = {}
	for player in pairs(self.records) do table.insert(players, player) end
	for _, player in ipairs(players) do self:_removePlayer(player) end
end

return Equipment







end]==],game:GetService("ServerScriptService").PlaygroundEquipmentService)(mockGame,mockWorld)
local toys={clears=0,cancels=0}
function toys:CanHold()return true end
function toys:ClearPlayer()self.clears+=1 end
function toys:CancelAction()self.cancels+=1 end
local dg=services.DuckDuckGoose
dg.swings=0
function dg:TryBatSwing()self.swings+=1 return true end
function dg:CancelBatSwing()end
local equipment=Equipment.new({DuckDuckGoose=dg},toys):Start()
local function settle()task.wait()task.wait()end
settle()
local record=equipment.records[a]
check(record~=nil,"Equipment watches Goose player")
check(record.bat==nil,"Seated Duck receives no bat")
a:SetAttribute("DGRole","Picker")settle()
check(record.bat==nil,"Picker receives no bat")
a:SetAttribute("DGRole","Runner")settle()
check(record.bat==nil,"Runner receives no bat")
a:SetAttribute("DGRole","Goose")settle()
check(record.bat==nil,"Goose receives no bat during Choosing")
dg.state:SetAttribute("TurnPhase","Chasing")settle()
check(record.bat~=nil and record.bat:IsA("Tool"),"TurnPhase watcher equips chasing Goose")
check(record.bat:GetAttribute("WeaponGame")=="DuckDuckGoose","Equipped Tool routes to fifth game")
check(record.bat.Parent==a.Character and a.Character:GetAttribute("PCBatHeld")==true,"Bat is held by character")
check(equipment:_activateBat(record) and dg.swings==1,"Equipped bat activates DG service once")
check(not equipment:_toyAllowed(record),"Active Goose cannot hold lobby toys")
a:SetAttribute("DGRagdolled",true)settle()
check(record.bat==nil,"Ragdoll temporarily removes Goose bat")
a:SetAttribute("DGRagdolled",false)settle()
check(record.bat~=nil,"Bat returns after ragdoll")
dg.state:SetAttribute("TurnPhase","Choosing")settle()
check(record.bat==nil,"Bat disappears immediately after chasing")
dg.state:SetAttribute("TurnPhase","Chasing")settle()
check(record.bat~=nil,"Next chasing phase restores bat")
a:SetAttribute("DGRole","Duck")settle()
check(record.bat==nil,"Successful Runner back in seat has no bat")
a:SetAttribute("DGParticipating",false)a:SetAttribute("DGEliminated",true)a:SetAttribute("DGRole","Spectator")settle()
check(not equipment:_toyAllowed(record),"Eliminated arena spectator cannot use lobby toys")
check(not coordinator:_participating(a),"Eliminated player may spectate")
coordinator:_syncAFK(a)
check(a:GetAttribute("PCAFK")==true and a:GetAttribute("PCAFKQueued")==false,"Eliminated AFK request no longer queues")
check(coordinator:_spectateTarget(a,b.UserId)==b,"Eliminated player can spectate alive Goose participant")
check(coordinator:_spectateTarget(observer,a.UserId)==nil,"Eliminated players are not spectator targets")
dg.state:SetAttribute("LastResultWinnerIds","2")
dg.state:SetAttribute("LastResultParticipantIds","1,2")
dg.state:SetAttribute("LastResultRound",8)
coordinator:_rewardDuckDuckGoose()
check(#rewards==1 and rewards[1][1]=="DG:8","Goose receipt key is unique")
check(rewards[1][2][1]==2 and rewards[1][4][1]==1,"Winner and eliminated participant reach economy")
check(rewards[1][5].gameId=="DuckDuckGoose","Wins assigned to fifth game")
equipment:Stop()
coordinator:StopGame()
check(not dg.active and states.PlaygroundState:GetAttribute("Phase")=="Paused","Admin stop handles fifth game")
check(a:GetAttribute("DGEliminated")==false,"Round cleanup restores lobby presence")
fixture:Destroy()
return {passed=true,checks=checks,actualBatToolTested=true,permissionsPreserved=true,playStarted=false}
