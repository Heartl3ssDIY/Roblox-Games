local now = 0
local os = { clock = function() return now end }
local jobs, created, calls = {}, {}, {}
local function signal()
	local entries = {}
	return { Connect = function(_, fn)
		local entry = { fn = fn, active = true }
		table.insert(entries, entry)
		return { Disconnect = function() entry.active = false end }
	end, Fire = function(_, ...)
		for _, entry in ipairs(table.clone(entries)) do if entry.active then entry.fn(...) end end
	end }
end
local function node(name, class)
	local value = { Name = name, class = class, attributes = {}, children = {}, signals = {}, Enabled = true, Destroying = signal() }
	function value:IsA(wanted) return self.class == wanted end
	function value:FindFirstChild(wanted, recursive)
		if self.children[wanted] then return self.children[wanted] end
		if recursive then for _, child in pairs(self.children) do local found = child:FindFirstChild(wanted, true) if found then return found end end end
	end
	function value:WaitForChild(wanted) return assert(self:FindFirstChild(wanted), self.Name .. "." .. wanted) end
	function value:GetAttribute(key) return self.attributes[key] end
	function value:GetAttributeChangedSignal(key) if not self.signals[key] then self.signals[key] = signal() end return self.signals[key] end
	function value:SetAttribute(key, item) self.attributes[key] = item if self.signals[key] then self.signals[key]:Fire() end end
	function value:GetPropertyChangedSignal(key) return self:GetAttributeChangedSignal("prop:" .. key) end
	function value:IsDescendantOf() return self.available ~= false end
	function value:Destroy() self.destroyed = true self.Parent = nil self.Destroying:Fire() end
	return value
end
local function child(parent, name, class)
	local value = node(name, class)
	value.Parent = parent
	parent.children[name], parent[name] = value, value
	return value
end
local Instance = { new = function(class) return node(class, class) end }
local workspace = node("Workspace", "Workspace")
local testLobby = child(workspace, "Playground Lobby", "Model")
local testPodium = child(testLobby, "WinnerPodium", "Model")
child(testPodium, "HeaderFace", "BasePart")
for index = 1, 3 do
	local podium = child(testPodium, "Rank" .. index, "Model")
	child(child(podium, "Top", "BasePart"), "StandingPoint", "Attachment")
	child(podium, "Face", "BasePart")
end
local playerGuiMock = node("PlayerGui", "PlayerGui")
local leaderboardMock = child(playerGuiMock, "PlaygroundLeaderboards", "ScreenGui")
leaderboardMock.attributes = { PodiumScope = "global", PodiumBoard = "MostWins" }
local guiMock = child(playerGuiMock, "PlaygroundPodium", "ScreenGui")
local headerMock = child(guiMock, "Header", "SurfaceGui")
child(headerMock, "Title", "TextLabel") child(headerMock, "Subtitle", "TextLabel")
for index = 1, 3 do
	local rank = child(guiMock, "Rank" .. index, "SurfaceGui")
	child(rank, "NameLabel", "TextLabel") child(rank, "ScoreLabel", "TextLabel") child(rank, "StatusLabel", "TextLabel")
end
local script = node("Controller", "LocalScript")
script.Parent = guiMock
local task = {}
function task.spawn(fn) table.insert(jobs, { thread = coroutine.create(fn), at = now }) end
function task.wait(seconds) return coroutine.yield(seconds) end
local function advance(seconds)
	local deadline = now + seconds
	while true do
		local index, job
		for i, entry in ipairs(jobs) do if entry.at <= deadline and (not job or entry.at < job.at) then index, job = i, entry end end
		if not job then break end
		table.remove(jobs, index)
		now = job.at
		local ok, delay = coroutine.resume(job.thread)
		assert(ok, delay)
		if coroutine.status(job.thread) ~= "dead" then job.at = now + delay table.insert(jobs, job) end
	end
	now = deadline
end
local Players = {}
function Players:CreateHumanoidModelFromUserIdAsync(id)
	table.insert(calls, id)
	task.wait(2)
	if id == 99 then error("Avatar unavailable") end
	local model = node("Avatar" .. id, "Model")
	model.userId = id
	table.insert(created, model)
	return model
end
local RunService = { Heartbeat = signal(), PreAnimation = signal(), PreSimulation = signal() }
local packets = {}
local HttpService = { JSONDecode = function(_, encoded) return assert(packets[encoded], "Invalid JSON") end }
local nativeTypeof = typeof
local function typeof(value) if type(value) == "table" and value.class then return "Instance" end return nativeTypeof(value) end
local function finite(value) return type(value) == "number" and value == value and math.abs(value) < math.huge end
local function prepareModel(model) return { model = model, joints = {} } end
local function restorePose() end
local function animateModel() end
local function animationId() return nil end
-- RUNTIME_SOURCE
local checked = {}
local function check(name, condition) assert(condition, name) table.insert(checked, name) end
local function tick() RunService.Heartbeat:Fire(0.3) advance(0) end
local function packet(key, scope, board, ids, state)
	local entries = {}
	for _, id in ipairs(ids) do table.insert(entries, { userId = id, name = "User" .. id, value = tostring(id) }) end
	packets[key] = { scope = scope, board = board, entries = entries, state = state or "ready", region = scope == "region" and "Europe" or nil }
	leaderboardMock:SetAttribute("PodiumSnapshot", key)
end
tick()
check("no avatar fetch before a matching snapshot", #calls == 0 and slots[1].entry == nil)
packet("wrong", "server", "MostWins", { 1, 2, 3 })
tick()
check("wrong scope snapshot is ignored", #calls == 0 and slots[1].entry == nil)
packet("first", "global", "MostWins", { 1, 2, 3 })
tick()
check("avatar loads are capped at two concurrent calls", #calls == 2 and activeLoads == 2 and slots[3].loadToken == nil)
packet("refresh", "global", "MostWins", { 1, 2, 3 })
tick()
check("same pending winners do not duplicate requests", #calls == 2)
advance(2) tick() advance(2)
check("all three genuine requested winners render", #calls == 3 and slots[1].avatar.model.userId == 1 and slots[2].avatar.model.userId == 2 and slots[3].avatar.model.userId == 3)
packet("same", "global", "MostWins", { 1, 2, 3 }) tick()
check("same winner refresh keeps existing models", #calls == 3 and not created[1].destroyed)
leaderboardMock:SetAttribute("PodiumScope", "server")
check("selection change clears all previous winner models", created[1].destroyed and created[2].destroyed and created[3].destroyed and slots[1].entry == nil)
packet("old", "global", "MostWins", { 1, 2, 3 }) tick()
check("late old scope packet cannot restore old winners", slots[1].entry == nil and #calls == 3)
packet("server", "server", "MostWins", { 4, 5, 6 }) tick()
leaderboardMock:SetAttribute("PodiumScope", "region")
packet("region", "region", "MostWins", { 7, 8, 9 }) tick()
check("selection changes do not exceed active avatar load cap", #calls == 5 and activeLoads == 2)
advance(2)
check("stale avatar API results are destroyed", created[4].userId == 4 and created[4].destroyed and created[5].userId == 5 and created[5].destroyed)
tick() advance(2) tick() advance(2)
check("latest scope winners replace stale loads", slots[1].avatar.model.userId == 7 and slots[3].avatar.model.userId == 9)
check("region heading identifies current scope", headerMock.Subtitle.Text:find("EUROPE") ~= nil)
leaderboardMock:SetAttribute("PodiumBoard", "HighestLevel")
packet("wrongboard", "region", "MostWins", { 7, 8, 9 }) tick()
check("wrong leaderboard metric is ignored", slots[1].entry == nil)
packet("empty", "region", "HighestLevel", {}, "unavailable")
check("unavailable scores do not invent winners", slots[1].entry == nil and guiMock.Rank1.StatusLabel.Text == "Rankings unavailable")
guiMock.Enabled = false guiMock:GetPropertyChangedSignal("Enabled"):Fire()
packet("hidden", "region", "HighestLevel", { 10, 11, 12 }) tick()
local beforeHidden = #calls
check("disabled podium stays hidden without fetching avatars", folder.Parent == nil and activeLoads == 0)
guiMock.Enabled = true guiMock:GetPropertyChangedSignal("Enabled"):Fire() tick()
check("enabling podium resumes queued winners", folder.Parent == workspace and #calls == beforeHidden + 2)
advance(2) tick() advance(2)
testPodium.Rank1.Top.children.StandingPoint = nil
tick()
check("streamed out pedestal clears its local avatar", slots[1].avatar == nil and not guiMock.Rank1.Enabled)
leaderboardMock:SetAttribute("PodiumScope", "global")
leaderboardMock:SetAttribute("PodiumBoard", "MostWins")
packet("beforeRemoved", "global", "MostWins", { 20, 21, 22 }) tick()
advance(2) tick() advance(2)
local removedAvatar = slots[2].avatar.model
playerGuiMock.children.PlaygroundLeaderboards = nil
tick()
check("removing default-scope source clears old winners", removedAvatar.destroyed and slots[2].entry == nil and slots[2].avatar == nil and packetState == "loading")
packet("detached", "global", "MostWins", { 23, 24, 25 }) tick()
check("detached source cannot repopulate winners", slots[2].entry == nil)
leaderboardMock = child(playerGuiMock, "PlaygroundLeaderboards", "ScreenGui")
leaderboardMock.attributes = { PodiumScope = "global", PodiumBoard = "MostWins" }
packet("replacement", "global", "MostWins", { 26, 27, 28 }) tick()
advance(2) tick() advance(2)
check("replacement source with identical selection loads its own winners", slots[2].avatar.model.userId == 27 and slots[3].avatar.model.userId == 28)
local replacedAvatar = slots[2].avatar.model
leaderboardMock = child(playerGuiMock, "PlaygroundLeaderboards", "ScreenGui")
leaderboardMock.attributes = { PodiumScope = "global", PodiumBoard = "MostWins" }
tick()
check("same-selection replacement without snapshot clears stale winners", replacedAvatar.destroyed and slots[2].entry == nil and packetState == "loading")
leaderboardMock:SetAttribute("PodiumScope", "global")
leaderboardMock:SetAttribute("PodiumBoard", "HighestLevel")
packet("closing", "global", "HighestLevel", { 13, 14, 15 }) tick()
script.Destroying:Fire()
advance(3)
check("cleanup destroys existing and late arriving avatars", folder.destroyed and not alive and activeLoads == 0)
for _, model in ipairs(created) do assert(model.destroyed, "Leaked avatar " .. model.Name) end
check("all created avatar models were reclaimed", true)
print("PASS " .. #checked .. " podium lifecycle checks; mocked avatar API, zero real avatar/network requests")
for _, name in ipairs(checked) do print("PASS " .. name) end
