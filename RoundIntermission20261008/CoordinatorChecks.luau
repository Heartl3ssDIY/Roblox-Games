local checks = 0
local function check(condition, label)
    assert(condition, label)
    checks += 1
end
local playerList = {}
local testPlayers = {}
function testPlayers:GetPlayers() return playerList end
local function player(id, attributes, healthy)
    local p = { UserId = id, Parent = testPlayers, attributes = attributes or { PCDataReady = true } }
    local humanoid = { Health = healthy == false and 0 or 100 }
    p.Character = { FindFirstChildOfClass = function() return humanoid end }
    function p:GetAttribute(name) return self.attributes[name] end
    function p:SetAttribute(name, value) self.attributes[name] = value end
    return p
end
local Coordinator = (function()
    -- COORDINATOR_SOURCE
end)()
local objects = {}
local function folder()
    local object = Instance.new("Folder")
    table.insert(objects, object)
    return object
end
local function service(minimum)
    local s = { arena = folder(), state = folder(), running = true, active = false, starts = 0 }
    s.arena:SetAttribute("MinimumPlayers", minimum)
    function s:StartRound(selected)
        self.starts += 1
        self.selected = selected
        if self.throw then error("Fixture transient failure") end
        if self.reject then return false, "Fixture not ready" end
        self.active = true
        return true
    end
    function s:StartPractice(p)
        self.starts += 1
        if self.reject then return false, "Fixture not ready" end
        self.active = true
        return true
    end
    function s:StopRound() self.active = false end
    return s
end
local function fresh(count, ids)
    playerList = {}
    for i = 1, count do table.insert(playerList, player(i)) end
    local services = {}
    for _, id in ipairs(ids or { "BritishBulldog", "TagYoureIt", "StuckInTheMud" }) do
        services[id] = service(id == "StuckInTheMud" and 4 or 2)
    end
    local c = setmetatable({
        services = services, lobby = { Gameplay = { FindFirstChild = function() return nil end } }, state = folder(),
        votes = {}, lastVote = {}, spectators = {}, autoEnabled = true,
        votingEndsAt = 0, startRetryAt = 0, random = Random.new(1),
    }, Coordinator)
    return c, services
end
local c, services = fresh(2)
c:_step(100)
check(c.state:GetAttribute("Phase") == "Voting", "Eligible players begin intermission")
check(c.state:GetAttribute("VotingEndsAt") == 135, "Exactly 35 seconds")
check(c.state:GetAttribute("ReadyPlayerCount") == 2, "Ready count published")
check(c.state:GetAttribute("MinimumReadyPlayers") == 2, "Two-player minimum preserved")
check(c.state:GetAttribute("AvailableStuckInTheMud") == false, "Mud retains four-player minimum")
c:_step(134.99)
check(not c:ActiveGame(), "No early start")
c:_step(135)
check(c:ActiveGame() ~= nil, "Automatic round starts at deadline without votes")
check(c.state:GetAttribute("Phase") == "Playing", "Playing status published")
check(c.state:GetAttribute("VotingEndsAt") == 0, "Countdown cleared after start")
local active = services[c:ActiveGame()]
check(#active.selected == 2, "All ready players selected")
local started = active.starts
c:_step(200)
check(active.starts == started, "Active round is not restarted")
active.active = false
c:_step(201)
check(c.votingEndsAt == 236, "Next intermission starts after round ends")

c, services = fresh(2, { "BritishBulldog" })
local ok = c:StartGame("BritishBulldog", playerList[1], "Runner", false)
check(ok and c.autoEnabled, "Admin practice no longer disables automatic rounds")
services.BritishBulldog.active = false
c:_step(100)
check(c.votingEndsAt == 135, "Automatic rounds resume after practice")
c:SetAutoEnabled(false)
ok = c:StartGame("BritishBulldog", playerList[1], "Runner", false)
check(ok and not c.autoEnabled, "Explicit admin pause remains in effect during practice")
services.BritishBulldog.active = false
c:_step(200)
check(c.state:GetAttribute("Phase") == "Paused", "Explicit admin pause remains after practice")
check(c.state:GetAttribute("IntermissionStatus") == "Automatic rounds paused by an admin", "Paused reason exposed")
c:SetAutoEnabled(true)
c:_step(201)
check(c.votingEndsAt == 236, "Admin can re-enable automatic rounds")
c:StopGame()
check(not c.autoEnabled, "Explicit StopRound retains pause behavior")

c, services = fresh(2, { "BritishBulldog" })
services.BritishBulldog.reject = true
ok = c:StartGame("BritishBulldog", nil, nil, false)
check(not ok and c.autoEnabled, "Failed manual start cannot silently pause public rounds")
c:_step(100)
c.votes[playerList[1]] = "BritishBulldog"
c:_step(135)
check(c.votingEndsAt == 135, "Rejected round preserves elapsed intermission")
check(c.startRetryAt == 140, "Rejected round retries in five seconds")
check(c.votes[playerList[1]] == "BritishBulldog", "Votes survive temporary rejection")
check(c.state:GetAttribute("LastRoundStartError") == "Fixture not ready", "Rejection reason recorded")
local attempts = services.BritishBulldog.starts
c:_step(139.9)
check(services.BritishBulldog.starts == attempts, "Retry cannot spam round starts")
services.BritishBulldog.reject = false
c:_step(140)
check(c:ActiveGame() == "BritishBulldog", "Transient rejection recovers without another 35 seconds")
check(c.state:GetAttribute("LastRoundStartError") == "", "Failure cleared after success")

c, services = fresh(2, { "BritishBulldog" })
services.BritishBulldog.throw = true
c:_step(100)
local survived = pcall(function() c:_step(135) end)
check(survived and c.startRetryAt == 140, "Thrown round-start error cannot kill coordinator")
services.BritishBulldog.throw = false
c:_step(140)
check(c:ActiveGame() == "BritishBulldog", "Exception recovers on retry")

c, services = fresh(1)
c:_step(100)
check(c.state:GetAttribute("Phase") == "Waiting" and c.votingEndsAt == 0, "Solo public server waits instead of starting bots")
check(c.state:GetAttribute("IntermissionStatus") == "Waiting for ready players (1/2)", "Wait reason exposes missing player")
table.insert(playerList, player(2, { PCDataReady = false }))
c:_step(200)
check(c.state:GetAttribute("ReadyPlayerCount") == 1, "Loading data excluded")
playerList[2].attributes.PCDataReady = true
playerList[2].attributes.PCAFK = true
c:_step(201)
check(c.state:GetAttribute("ReadyPlayerCount") == 1, "AFK excluded")
playerList[2].attributes.PCAFK = false
playerList[2].attributes.PCAFKRequested = true
c:_step(202)
check(c.state:GetAttribute("ReadyPlayerCount") == 1, "Queued AFK excluded")
playerList[2].attributes.PCAFKRequested = false
playerList[2].attributes.BBParticipating = true
c:_step(203)
check(c.state:GetAttribute("ReadyPlayerCount") == 1, "Active participants excluded")
playerList[2].attributes.BBParticipating = false
playerList[2].Character = nil
c:_step(204)
check(c.state:GetAttribute("ReadyPlayerCount") == 1, "Missing avatar excluded")
playerList[2] = player(2)
c:_step(205)
check(c.votingEndsAt == 240, "Countdown begins when player is ready")
table.remove(playerList, 2)
c:_step(220)
check(c.votingEndsAt == 0 and c.state:GetAttribute("Phase") == "Waiting", "Leaving below minimum cancels countdown")
table.insert(playerList, player(3))
c:_step(221)
check(c.votingEndsAt == 256, "Returning to minimum begins a fresh valid intermission")

c, services = fresh(3, { "StuckInTheMud" })
c:_step(100)
check(c.state:GetAttribute("MinimumReadyPlayers") == 4 and c.votingEndsAt == 0, "Minimum follows available service configuration")
table.insert(playerList, player(4))
c:_step(101)
check(c.votingEndsAt == 136, "Mud starts voting with four players")
c:_step(136)
check(c:ActiveGame() == "StuckInTheMud", "Mud starts with eligible four")
c, services = fresh(4, { "StuckInTheMud" })
services.StuckInTheMud.state:SetAttribute("GunAccessReady", false)
c:_step(100)
check(c.votingEndsAt == 0, "Unavailable gun service cannot cause repeated countdown")
check(c.state:GetAttribute("IntermissionStatus") == "Waiting for an available game", "Unavailable service reason published")
c, services = fresh(2, { "BritishBulldog" })
services.BritishBulldog.running = false
c:_step(100)
check(c.votingEndsAt == 0, "Unstarted service excluded")
for _, object in objects do object:Destroy() end
return { passed = checks, scope = "Coordinator state transitions with actual authored server source and mock round services; no play session or real rewards" }
