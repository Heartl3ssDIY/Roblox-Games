from pathlib import Path
root = Path(__file__).resolve().parent
source = (root / "Before/PlaygroundCoordinator.luau").read_text()
source = source.replace('local titles = {', 'local INTERMISSION_SECONDS = 35\nlocal START_RETRY_SECONDS = 5\nlocal titles = {', 1)
source = source.replace('self.votingEndsAt = 0\n\tself.random', 'self.votingEndsAt = 0\n\tself.startRetryAt = 0\n\tself.random', 1)
source = source.replace('if not service then return false end\n\tif id==', 'if not service or service.running == false then return false end\n\tif id==', 1)
source = source.replace('self.autoEnabled = enabled == true\n\tself.votingEndsAt = 0', 'self.autoEnabled = enabled == true\n\tself.votingEndsAt = 0\n\tself.startRetryAt = 0\n\tself.state:SetAttribute("LastRoundStartError", "")\n\tself.state:SetAttribute("IntermissionStatus", self.autoEnabled and "Waiting for ready players" or "Automatic rounds paused by an admin")', 1)
source = source.replace('\tif not automatic then self:SetAutoEnabled(false) end\n\tself.votingEndsAt = 0\n\tself.state:SetAttribute("VotingEndsAt", 0)\n\tself:_clearVotes()\n\tlocal started, reason', '\tlocal started, reason', 1)
source = source.replace('\tif started then\n\t\tself.lastGame = id', '\tif started then\n\t\tself.votingEndsAt = 0\n\t\tself.startRetryAt = 0\n\t\tself.state:SetAttribute("VotingEndsAt", 0)\n\t\tself.state:SetAttribute("LastRoundStartError", "")\n\t\tself.state:SetAttribute("IntermissionStatus", "")\n\t\tself:_clearVotes()\n\t\tself.lastGame = id', 1)
start = source.index('function Coordinator:_loop()')
end = source.index('function Coordinator:Start()', start)
source = source[:start] + '''function Coordinator:_step(now)
\tself:_updateSpectators()
\tlocal active = self:ActiveGame()
\tlocal readyCount = #self:_readyPlayers()
\tself:_availability(readyCount)
\tlocal minimum, available = math.huge, false
\tfor _, id in ipairs(games) do
\t\tlocal service = self.services[id]
\t\tif service and service.running ~= false and not (id == "StuckInTheMud" and service.state:GetAttribute("GunAccessReady") == false) then
\t\t\tminimum = math.min(minimum, self:MinimumPlayers(id))
\t\t\tavailable = available or self:GameAvailable(id, readyCount)
\t\tend
\tend
\tif minimum == math.huge then minimum = 2 end
\tself.state:SetAttribute("MinimumReadyPlayers", minimum)
\tif active then
\t\tself.votingEndsAt, self.startRetryAt = 0, 0
\t\tself.state:SetAttribute("Phase", "Playing")
\t\tself.state:SetAttribute("ActiveGame", active)
\t\tself.state:SetAttribute("GameTitle", titles[active])
\t\tself.state:SetAttribute("VotingEndsAt", 0)
\t\tself.state:SetAttribute("IntermissionStatus", "")
\telseif not self.autoEnabled then
\t\tself.state:SetAttribute("Phase", "Paused")
\t\tself.state:SetAttribute("ActiveGame", "")
\t\tself.state:SetAttribute("GameTitle", "")
\t\tself.state:SetAttribute("IntermissionStatus", "Automatic rounds paused by an admin")
\telseif not available then
\t\tself.votingEndsAt, self.startRetryAt = 0, 0
\t\tself.state:SetAttribute("Phase", "Waiting")
\t\tself.state:SetAttribute("ActiveGame", "")
\t\tself.state:SetAttribute("GameTitle", "")
\t\tself.state:SetAttribute("VotingEndsAt", 0)
\t\tself.state:SetAttribute("IntermissionStatus", readyCount < minimum
\t\t\tand string.format("Waiting for ready players (%d/%d)", readyCount, minimum)
\t\t\tor "Waiting for an available game")
\t\tself:_clearVotes()
\telseif self.votingEndsAt == 0 then
\t\tself:_clearVotes()
\t\tself.votingEndsAt = now + INTERMISSION_SECONDS
\t\tself.state:SetAttribute("Phase", "Voting")
\t\tself.state:SetAttribute("ActiveGame", "")
\t\tself.state:SetAttribute("GameTitle", "")
\t\tself.state:SetAttribute("VotingEndsAt", self.votingEndsAt)
\t\tself.state:SetAttribute("IntermissionStatus", "Next round starts in")
\t\tself.state:SetAttribute("LastRoundStartError", "")
\telseif now >= self.votingEndsAt and now >= self.startRetryAt then
\t\tlocal selected = self:_chooseGame()
\t\tlocal ok, started, reason = pcall(self.StartGame, self, selected, nil, nil, true)
\t\tif not ok or not started then
\t\t\tlocal failure = tostring(ok and reason or started)
\t\t\tself.startRetryAt = now + START_RETRY_SECONDS
\t\t\tself.state:SetAttribute("IntermissionStatus", "Preparing the next round - retrying")
\t\t\tself.state:SetAttribute("LastRoundStartError", failure)
\t\t\twarn("Automatic round could not start: " .. failure)
\t\tend
\tend
\tself:_padVoting()
end

function Coordinator:_loop()
\twhile self.running do
\t\tself:_step(workspace:GetServerTimeNow())
\t\ttask.wait(0.25)
\tend
end

''' + source[end:]
source = source.replace('self.state:SetAttribute("AutomaticRounds", true)', 'self.state:SetAttribute("AutomaticRounds", self.autoEnabled)\n\tself.state:SetAttribute("IntermissionSeconds", INTERMISSION_SECONDS)\n\tself.state:SetAttribute("MinimumReadyPlayers", 2)\n\tself.state:SetAttribute("IntermissionStatus", "Waiting for ready players")\n\tself.state:SetAttribute("LastRoundStartError", "")', 1)
(root / "After").mkdir(exist_ok=True)
(root / "After/PlaygroundCoordinator.luau").write_text(source)
