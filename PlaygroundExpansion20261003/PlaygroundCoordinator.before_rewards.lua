local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Coordinator = {}
Coordinator.__index = Coordinator
local games = { "BritishBulldog", "TagYoureIt" }
local titles = { BritishBulldog = "British Bulldog", TagYoureIt = "Tag You're It" }

function Coordinator.new(services, lobby, economy)
	local self = setmetatable({}, Coordinator)
	self.services = services
	self.lobby = lobby
	self.economy = economy
	self.zone = lobby.Gameplay.VoteZone
	self.state = ReplicatedStorage:WaitForChild("PlaygroundState")
	self.votes = {}
	self.lastVote = {}
	self.connections = {}
	self.running = false
	self.autoEnabled = true
	self.votingEndsAt = 0
	self.random = Random.new()
	self.lastGame = nil
	return self
end

function Coordinator:ActiveGame()
	for _, id in ipairs(games) do if self.services[id].active then return id end end
	return nil
end

function Coordinator:_readyPlayers()
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and not player:GetAttribute("BBParticipating") and not player:GetAttribute("TGParticipating") and player:GetAttribute("PCDataReady") == true then
			table.insert(list, player)
		end
	end
	return list
end

function Coordinator:_insideZone(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local point = self.zone.CFrame:PointToObjectSpace(root.Position)
	local half = self.zone.Size / 2
	return math.abs(point.X) <= half.X and math.abs(point.Y) <= half.Y and math.abs(point.Z) <= half.Z
end

function Coordinator:_counts()
	local counts = { BritishBulldog = 0, TagYoureIt = 0 }
	for player, id in pairs(self.votes) do
		if player.Parent == Players and counts[id] then counts[id] += 1 end
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
	if player:GetAttribute("PCDataReady") ~= true then return { ok = false, message = "Your player data is loading." } end
	if player:GetAttribute("BBParticipating") or player:GetAttribute("TGParticipating") or not self:_insideZone(player) then return { ok = false, message = "Walk into the voting area first." } end
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
		if self.services[id].active then self.services[id]:StopRound() stopped = true end
	end
	self:SetAutoEnabled(false)
	self.state:SetAttribute("ActiveGame", "")
	self.state:SetAttribute("GameTitle", "")
	return true, stopped and "Back in the lobby." or "Ready in the lobby."
end

function Coordinator:_chooseGame()
	local counts = self:_counts()
	local maximum = math.max(counts.BritishBulldog, counts.TagYoureIt)
	local tied = {}
	for _, id in ipairs(games) do if counts[id] == maximum then table.insert(tied, id) end end
	if maximum == 0 and self.lastGame then
		for _, id in ipairs(tied) do if id ~= self.lastGame then return id end end
	end
	return tied[self.random:NextInteger(1, #tied)]
end

function Coordinator:_rewardBulldog()
	local service = self.services.BritishBulldog
	if service.phase ~= "Results" then return end
	local state = service.state
	local team = state:GetAttribute("WinnerTeam")
	local winnerIds = {}
	for player, record in pairs(service.records) do
		if not record.isBot and record.participating and ((team == "Runners" and record.role == "Runner") or (team == "Bulldogs" and record.role == "Bulldog")) then
			table.insert(winnerIds, player.UserId)
		end
	end
	self.economy:AwardRound("BB:" .. tostring(state:GetAttribute("RoundNumber")), winnerIds, string.find(state:GetAttribute("Mode") or "", "Practice", 1, true) ~= nil)
end

function Coordinator:_rewardTag()
	local state = self.services.TagYoureIt.state
	local ids = {}
	for value in string.gmatch(state:GetAttribute("LastResultWinnerIds") or "", "%-?%d+") do table.insert(ids, tonumber(value)) end
	self.economy:AwardRound("TAG:" .. tostring(state:GetAttribute("LastResultRound")), ids, state:GetAttribute("LastResultPractice") == true)
end

function Coordinator:_loop()
	while self.running do
		local active = self:ActiveGame()
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
		elseif #self:_readyPlayers() < 2 then
			self.votingEndsAt = 0
			self.state:SetAttribute("Phase", "Waiting")
			self.state:SetAttribute("ActiveGame", "")
			self.state:SetAttribute("GameTitle", "")
			self.state:SetAttribute("VotingEndsAt", 0)
			self:_clearVotes()
		elseif self.votingEndsAt == 0 then
			self:_clearVotes()
			self.votingEndsAt = now + 20
			self.state:SetAttribute("Phase", "Voting")
			self.state:SetAttribute("ActiveGame", "")
			self.state:SetAttribute("VotingEndsAt", self.votingEndsAt)
		elseif now >= self.votingEndsAt then
			local selected = self:_chooseGame()
			self.votingEndsAt = 0
			local started = self:StartGame(selected, nil, nil, true)
			if not started then self.state:SetAttribute("Phase", "Waiting") end
		end
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
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player)
		self.votes[player] = nil
		self.lastVote[player] = nil
		self:_counts()
	end))
	table.insert(self.connections, self.services.BritishBulldog.state:GetAttributeChangedSignal("Phase"):Connect(function() self:_rewardBulldog() end))
	table.insert(self.connections, self.services.TagYoureIt.state:GetAttributeChangedSignal("LastResultRound"):Connect(function() self:_rewardTag() end))
	task.spawn(function() self:_loop() end)
end

function Coordinator:Stop()
	self.running = false
	self:StopGame()
	for _, connection in ipairs(self.connections) do connection:Disconnect() end
	if self.remote then self.remote.OnServerInvoke = nil end
end

return Coordinator
