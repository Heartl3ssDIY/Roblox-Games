local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local cleanups, results = {}, {}
local function fresh(name)
	local original = ServerScriptService:FindFirstChild(name)
	assert(original and original:IsA("ModuleScript"), name .. " must be installed first")
	local value = original:Clone()
	value.Name = name .. "Fixture"
	value.Parent = ServerScriptService
	table.insert(cleanups, value)
	return require(value)
end
local Coordinator = fresh("PlaygroundCoordinator")
local Admin = fresh("PlaygroundAdminService")
local lobby = workspace:FindFirstChild("Playground Lobby")
assert(lobby and lobby.Gameplay.VoteZone)

local function check(name, condition, details)
	assert(condition, name .. " failed: " .. tostring(details))
	table.insert(results, {name = name, ok = true, details = details})
end
local function state()
	local value = Instance.new("Folder")
	table.insert(cleanups, value)
	return value
end
local function player(id, position)
	local attrs = {PCDataReady = true, BBRole = "Spectator", TGRole = "Spectator"}
	local rootPart = Instance.new("Part")
	rootPart.Anchored = true
	rootPart.Position = position or lobby.Gameplay.VoteZone.Position
	table.insert(cleanups, rootPart)
	local humanoid = {Health = 100}
	local value = {UserId = id, DisplayName = "Fixture" .. id, Parent = Players, root = rootPart, humanoid = humanoid}
	value.Character = {
		FindFirstChild = function(_, name) return name == "HumanoidRootPart" and rootPart or nil end,
		FindFirstChildOfClass = function(_, name) return name == "Humanoid" and humanoid or nil end,
	}
	function value:GetAttribute(name) return attrs[name] end
	function value:SetAttribute(name, data) attrs[name] = data end
	return value
end
local function service(id)
	local value = {id = id, active = false, phase = "Waiting", state = state(), records = {}, starts = 0, practiceStarts = 0, stops = 0}
	function value:StartRound(selected)
		if #selected < 2 then return false, "Not enough ready players" end
		self.starts += 1
		self.active = true
		self.phase = "Countdown"
		self.lastPlayers = selected
		self.state:SetAttribute("Mode", "Round")
		return true
	end
	function value:StartPractice(adapter, role)
		self.practiceStarts += 1
		self.active = true
		self.phase = "Countdown"
		self.lastOwner = adapter
		self.lastRole = role
		self.state:SetAttribute("Mode", "Practice" .. role)
		return true
	end
	function value:StopRound()
		self.stops += 1
		self.active = false
		self.phase = "Waiting"
		return true
	end
	return value
end
local first = player(810100)
local second = player(810101)
local services = {BritishBulldog = service("BritishBulldog"), TagYoureIt = service("TagYoureIt")}
local awards = {}
local fakeEconomy = {AwardRound = function(_, key, ids, practice, participants) table.insert(awards, {key = key, ids = ids, practice = practice, participants = participants}) end}
local coordinator = Coordinator.new(services, lobby, fakeEconomy)
coordinator.state = state()
coordinator._readyPlayers = function() return {first, second} end
coordinator.random = {NextInteger = function(_, minimum) return minimum end}

local success, failure = xpcall(function()
	coordinator.state:SetAttribute("Phase", "Voting")
	check("Available vote accepted inside zone", coordinator:Vote(first, "BritishBulldog").ok)
	check("Vote is one per player", coordinator.state:GetAttribute("VotesBritishBulldog") == 1 and first:GetAttribute("PCVote") == "BritishBulldog")
	check("Unknown game vote rejected", not coordinator:Vote(second, "UnreleasedGame").ok)
	check("Nonstring vote rejected", not coordinator:Vote(second, {}).ok)
	check("Repeated vote cooldown", not coordinator:Vote(first, "TagYoureIt").ok)
	coordinator.lastVote[first] = -math.huge
	check("Changing vote replaces previous vote", coordinator:Vote(first, "TagYoureIt").ok and coordinator.state:GetAttribute("VotesBritishBulldog") == 0 and coordinator.state:GetAttribute("VotesTagYoureIt") == 1)
	second.root.Position = Vector3.new(0, 7, 0)
	check("Voting requires spatial zone", not coordinator:Vote(second, "BritishBulldog").ok)
	second.root.Position = lobby.Gameplay.VoteZone.Position
	second.humanoid.Health = 0
	check("Dead players cannot vote", not coordinator:Vote(second, "BritishBulldog").ok)
	second.humanoid.Health = 100
	second:SetAttribute("PCDataReady", false)
	check("Unloaded profile cannot vote", not coordinator:Vote(second, "BritishBulldog").ok)
	second:SetAttribute("PCDataReady", true)
	second:SetAttribute("TGParticipating", true)
	check("Active participants cannot vote", not coordinator:Vote(second, "BritishBulldog").ok)
	second:SetAttribute("TGParticipating", false)
	coordinator.state:SetAttribute("Phase", "Playing")
	check("Votes closed during game", not coordinator:Vote(second, "BritishBulldog").ok)
	coordinator.state:SetAttribute("Phase", "Voting")
	coordinator:SetAutoEnabled(false)
	check("Pausing closes vote and clears counts", coordinator.state:GetAttribute("Phase") == "Paused" and coordinator.state:GetAttribute("VotesTagYoureIt") == 0 and first:GetAttribute("PCVote") == "")
	check("Paused automatic rounds reject vote", not coordinator:Vote(second, "BritishBulldog").ok)
	coordinator:SetAutoEnabled(true)
	coordinator.state:SetAttribute("Phase", "Voting")
	coordinator.lastVote[first] = -math.huge
	check("Votes resume when automatic rounds on", coordinator:Vote(first, "BritishBulldog").ok)
	check("Highest vote chosen", coordinator:_chooseGame() == "BritishBulldog")
	coordinator:_clearVotes()
	coordinator.lastGame = "BritishBulldog"
	check("Zero votes alternate last game", coordinator:_chooseGame() == "TagYoureIt")
	coordinator.votes[first] = "BritishBulldog"
	coordinator.votes[second] = "TagYoureIt"
	check("Tied votes choose an available game", coordinator:_chooseGame() == "BritishBulldog")
	first.Parent = nil
	coordinator:_counts()
	check("Departed voters excluded", coordinator.state:GetAttribute("VotesBritishBulldog") == 0 and coordinator.state:GetAttribute("VotesTagYoureIt") == 1)
	first.Parent = Players
	coordinator:_clearVotes()
	check("Unknown game cannot start", not coordinator:StartGame("UnknownGame", first))
	check("Normal start passes ready roster", coordinator:StartGame("TagYoureIt", first, nil, false) and services.TagYoureIt.lastPlayers[1] == first and #services.TagYoureIt.lastPlayers == 2)
	check("Manual start pauses automatic rounds", not coordinator.autoEnabled)
	check("Started game state published", coordinator.state:GetAttribute("ActiveGame") == "TagYoureIt" and coordinator.state:GetAttribute("Phase") == "Playing")
	check("Second game blocked while one active", not coordinator:StartGame("BritishBulldog", first, "Runner", false) and services.BritishBulldog.practiceStarts == 0)
	check("Stop returns active game to lobby", coordinator:StopGame() and not services.TagYoureIt.active and services.TagYoureIt.stops == 1)
	check("Stop clears displayed game", coordinator.state:GetAttribute("ActiveGame") == "" and coordinator.state:GetAttribute("GameTitle") == "")
	check("Practice start passes owner and role", coordinator:StartGame("BritishBulldog", first, "Runner", false) and services.BritishBulldog.lastOwner == first and services.BritishBulldog.lastRole == "Runner")
	coordinator:StopGame()

	local config = state()
	config:SetAttribute("AdminUserId", first.UserId)
	config:SetAttribute("ExtraAdminUserIds", "810102, 810103")
	local admin = Admin.new(coordinator, config, false)
	local outsider = player(810199)
	local extraAdmin = player(810102)
	check("Configured admin authorized", admin:IsAuthorized(first))
	check("Additional configured admin authorized", admin:IsAuthorized(extraAdmin))
	check("Unconfigured player denied", not admin:IsAuthorized(outsider))
	check("Unauthorized command cannot start game", not admin:Handle(outsider, "TagTagger").ok and not services.TagYoureIt.active)
	check("Unknown admin action denied", not admin:Handle(first, "GiveCoins").ok)
	check("Malformed admin action denied", not admin:Handle(first, {}).ok)
	check("Status does not throttle next mutation", admin:Handle(first, "GetStatus").ok and admin:Handle(first, "TagTagger").ok)
	check("Tag practice role fixed on server", services.TagYoureIt.lastOwner == first and services.TagYoureIt.lastRole == "Tagger")
	check("Admin mutation rate limit", not admin:Handle(first, "StopRound").ok and services.TagYoureIt.active)
	admin.lastRequest[first] = -math.huge
	check("Admin stop works", admin:Handle(first, "StopRound").ok and not services.TagYoureIt.active)
	admin.lastRequest[first] = -math.huge
	check("Legacy Bulldog alias remains supported", admin:Handle(first, "PracticeBulldog").ok and services.BritishBulldog.lastRole == "Bulldog")
	coordinator:StopGame()
	admin.lastRequest[first] = -math.huge
	admin.busy = true
	check("Busy admin control serializes mutations", not admin:Handle(first, "TagRunner").ok and not services.TagYoureIt.active)
	admin.busy = false
	admin.lastRequest[first] = -math.huge
	check("Automatic toggle requires authorized admin", admin:Handle(first, "ToggleAutomatic").ok and coordinator.autoEnabled)
	local studioAdmin = Admin.new(coordinator, config, true)
	check("Studio test players can use panel", studioAdmin:IsAuthorized(outsider))

	services.BritishBulldog.phase = "Results"
	services.BritishBulldog.state:SetAttribute("WinnerTeam", "Runners")
	services.BritishBulldog.state:SetAttribute("RoundNumber", 7)
	services.BritishBulldog.state:SetAttribute("Mode", "Round")
	services.BritishBulldog.records = {
		[first] = {participating = true, role = "Runner"},
		[second] = {participating = true, role = "Bulldog"},
		[outsider] = {participating = true, role = "Runner", isBot = true},
	}
	coordinator:_rewardBulldog()
	local bbAward = awards[#awards]
	check("Bulldog winner ids filter losing team and bots", bbAward.key == "BB:7" and #bbAward.ids == 1 and bbAward.ids[1] == first.UserId and not bbAward.practice)
	check("Bulldog forwards winner and loser final participants", #bbAward.participants == 2 and bbAward.participants[1] == first.UserId and bbAward.participants[2] == second.UserId)
	local awardCount = #awards
	services.BritishBulldog.state:SetAttribute("WinnerTeam", "None")
	coordinator:_rewardBulldog()
	check("Cancelled Bulldog round does not reward anyone", #awards == awardCount)
	services.BritishBulldog.state:SetAttribute("WinnerTeam", "Runners")
	first.Parent = nil
	coordinator:_rewardBulldog()
	check("Disconnected Bulldog participant excluded", #awards[#awards].participants == 1 and awards[#awards].participants[1] == second.UserId and #awards[#awards].ids == 0)
	first.Parent = Players
	services.BritishBulldog.state:SetAttribute("Mode", "PracticeRunner")
	coordinator:_rewardBulldog()
	check("Bulldog practice flagged for no reward", awards[#awards].practice == true)
	services.TagYoureIt.state:SetAttribute("LastResultWinnerIds", "810100,810101")
	services.TagYoureIt.state:SetAttribute("LastResultParticipantIds", "810100,810101,810199")
	services.TagYoureIt.state:SetAttribute("LastResultRound", 3)
	services.TagYoureIt.state:SetAttribute("LastResultPractice", false)
	coordinator:_rewardTag()
	local tagAward = awards[#awards]
	check("Tag result ids forwarded with unique round key", tagAward.key == "TAG:3" and #tagAward.ids == 2 and tagAward.ids[1] == 810100 and tagAward.ids[2] == 810101 and not tagAward.practice)
	check("Tag final roster includes its losing participant", #tagAward.participants == 3 and tagAward.participants[3] == 810199)
	services.TagYoureIt.state:SetAttribute("LastResultParticipantIds", "")
	coordinator:_rewardTag()
	check("Tag missing roster does not fall back to winner list", #awards[#awards].participants == 0)
end, debug.traceback)

for _, object in ipairs(cleanups) do pcall(function() object:Destroy() end) end
if not success then error(failure) end
return {passed = #results, results = results, externalWrites = 0, createdRealPlayers = false}
