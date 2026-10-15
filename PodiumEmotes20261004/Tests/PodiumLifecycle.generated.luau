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
local gui = script.Parent
local playerGui = gui.Parent
local header = gui:WaitForChild("Header")
local slots, connections, selectionConnections = {}, {}, {}
local folder = Instance.new("Folder")
folder.Name = "PlaygroundPodiumAvatars"
folder.Parent = workspace
local alive, activeLoads = true, 0
local selectionGui
local selectedScope, selectedBoard = "global", "MostWins"
local scopes = { global = true, server = true, region = true }
local boardNames = { MostWins = "MOST WINS", HighestLevel = "HIGHEST LEVEL" }
local packetState, packetStatus, packetRegion = "loading", "Loading winners...", nil

local function disconnect(list)
	for _, connection in ipairs(list) do connection:Disconnect() end
	table.clear(list)
end

local function stopTrack(avatar)
	if avatar.track then avatar.track:Stop(0) avatar.track:Destroy() avatar.track = nil end
	if avatar.animation then avatar.animation:Destroy() avatar.animation = nil end
	avatar.animationAsset = nil
	restorePose(avatar)
end

local function clearAvatar(slot)
	if slot.loadToken then slot.loadToken.expired = true slot.loadToken = nil end
	if slot.avatar then stopTrack(slot.avatar) slot.avatar.model:Destroy() slot.avatar = nil end
end

local function setEntry(slot, entry)
	local id = entry and entry.userId
	if slot.userId ~= id then
		clearAvatar(slot)
		slot.userId, slot.attempts, slot.retryAt = id, 0, 0
	end
	slot.entry = entry
	slot.display.NameLabel.Text = entry and entry.name or (packetState == "loading" and "Loading..." or "No winner yet")
	slot.display.ScoreLabel.Text = entry and (selectedBoard == "MostWins" and entry.value .. " WINS" or entry.value) or "—"
	if entry then
		slot.display.StatusLabel.Text = slot.avatar and (packetState == "stale" and "Saved ranking" or "") or (slot.attempts >= 3 and "Avatar unavailable" or "Loading avatar...")
	else
		slot.display.StatusLabel.Text = packetState == "loading" and "Waiting for rankings" or packetState == "unavailable" and "Rankings unavailable" or "Your next win could put you here"
	end
end

local function refreshHeading()
	header.Title.Text = boardNames[selectedBoard] .. " · TOP 3"
	local label = selectedScope == "region" and (packetRegion or "REGION") or selectedScope == "server" and "THIS SERVER" or "GLOBAL"
	header.Subtitle.Text = string.upper(label) .. (packetState == "loading" and " · LOADING" or packetState == "unavailable" and " · UNAVAILABLE" or packetState == "stale" and " · SAVED RANKINGS" or " · WINNERS")
end

local function readPacket()
	local encoded = selectionGui and selectionGui:GetAttribute("PodiumSnapshot")
	if typeof(encoded) ~= "string" or #encoded > 32768 then return end
	local ok, packet = pcall(function() return HttpService:JSONDecode(encoded) end)
	if not ok or typeof(packet) ~= "table" or packet.scope ~= selectedScope or packet.board ~= selectedBoard or typeof(packet.entries) ~= "table" then return end
	packetState = packet.state == "loading" and "loading" or packet.state == "unavailable" and "unavailable" or packet.state == "stale" and "stale" or "ready"
	packetStatus = typeof(packet.status) == "string" and packet.status or ""
	packetRegion = typeof(packet.region) == "string" and packet.region or nil
	local seen = {}
	for index, slot in ipairs(slots) do
		local entry = packet.entries[index]
		if typeof(entry) ~= "table" or not finite(entry.userId) or entry.userId <= 0 or entry.userId % 1 ~= 0 or seen[entry.userId]
			or typeof(entry.name) ~= "string" or typeof(entry.value) ~= "string" then entry = nil end
		if entry then seen[entry.userId] = true end
		setEntry(slot, entry)
	end
	refreshHeading()
end

local function readSelection()
	local scope = selectionGui and selectionGui:GetAttribute("PodiumScope")
	local board = selectionGui and selectionGui:GetAttribute("PodiumBoard")
	scope = scopes[scope] and scope or "global"
	board = boardNames[board] and board or "MostWins"
	if scope ~= selectedScope or board ~= selectedBoard then
		selectedScope, selectedBoard = scope, board
		packetState, packetStatus, packetRegion = "loading", "Loading winners...", nil
		for _, slot in ipairs(slots) do setEntry(slot, nil) end
		refreshHeading()
	end
	readPacket()
end

local function bindSelection()
	local source = playerGui:FindFirstChild("PlaygroundLeaderboards")
	if source == selectionGui then return end
	disconnect(selectionConnections)
	selectionGui = source
	packetState, packetStatus, packetRegion = "loading", "Loading winners...", nil
	for _, slot in ipairs(slots) do setEntry(slot, nil) end
	refreshHeading()
	if source then
		for _, attribute in ipairs({ "PodiumScope", "PodiumBoard", "PodiumSnapshot" }) do
			table.insert(selectionConnections, source:GetAttributeChangedSignal(attribute):Connect(attribute == "PodiumSnapshot" and readPacket or readSelection))
		end
	end
	readSelection()
end

local function bindPedestals()
	local lobby = workspace:FindFirstChild("Playground Lobby")
	local podium = lobby and lobby:FindFirstChild("WinnerPodium")
	local headerFace = podium and podium:FindFirstChild("HeaderFace")
	if headerFace and headerFace:IsA("BasePart") then header.Adornee = headerFace end
	header.Enabled = gui.Enabled and headerFace ~= nil
	for index, slot in ipairs(slots) do
		local pedestal = podium and podium:FindFirstChild("Rank" .. index)
		local point = pedestal and pedestal:FindFirstChild("StandingPoint", true)
		local face = pedestal and pedestal:FindFirstChild("Face")
		slot.point = point and point:IsA("Attachment") and point or nil
		if face and face:IsA("BasePart") then slot.display.Adornee = face end
		slot.display.Enabled = gui.Enabled and slot.point ~= nil and face ~= nil
		if not slot.point and slot.avatar then clearAvatar(slot) end
	end
end

local function beginAvatar(slot)
	local token = { userId = slot.userId, startedAt = os.clock() }
	slot.loadToken = token
	slot.attempts += 1
	activeLoads += 1
	task.spawn(function()
		local ok, model = pcall(function() return Players:CreateHumanoidModelFromUserIdAsync(token.userId) end)
		activeLoads -= 1
		local current = alive and not token.expired and slot.loadToken == token and slot.userId == token.userId and slot.point and slot.point:IsDescendantOf(workspace)
		if slot.loadToken == token then slot.loadToken = nil end
		if not current then if ok and typeof(model) == "Instance" then model:Destroy() end return end
		local prepared, avatar = false, nil
		if ok and typeof(model) == "Instance" then prepared, avatar = pcall(prepareModel, model) end
		if not prepared then
			if ok and typeof(model) == "Instance" then model:Destroy() end
			slot.retryAt = os.clock() + math.min(60, slot.attempts * 15)
			slot.display.StatusLabel.Text = "Avatar unavailable"
			return
		end
		avatar.startedAt = os.clock()
		model.Name = "Rank" .. slot.rank .. "_" .. token.userId
		model:SetAttribute("PodiumUserId", token.userId)
		model.Parent = folder
		slot.avatar = avatar
		animateModel(avatar, slot.point, slot.rank, 0, false)
		slot.display.StatusLabel.Text = packetState == "stale" and "Saved ranking" or ""
	end)
end

local function updateAnimation(avatar)
	local requested = animationId(gui:GetAttribute("PodiumAnimationId"))
	if avatar.animationAsset == requested then return end
	stopTrack(avatar)
	avatar.animationAsset = requested
	if not requested then return end
	local animation = Instance.new("Animation")
	animation.AnimationId = requested
	avatar.animation = animation
	local ok, track = pcall(function() return avatar.animator:LoadAnimation(animation) end)
	if ok then
		avatar.track = track
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = true
		track:Play(0.25)
	end
end

for index = 1, 3 do
	slots[index] = { rank = index, display = gui:WaitForChild("Rank" .. index), attempts = 0, retryAt = 0 }
	setEntry(slots[index], nil)
end
refreshHeading()
bindSelection()
readPacket()
bindPedestals()

local function cleanup()
	if not alive then return end
	alive = false
	disconnect(connections)
	disconnect(selectionConnections)
	for _, slot in ipairs(slots) do clearAvatar(slot) slot.display.Enabled = false end
	folder:Destroy()
end

table.insert(connections, gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if gui.Enabled then folder.Parent = workspace else folder.Parent = nil end
	bindPedestals()
end))
table.insert(connections, gui.Destroying:Connect(cleanup))
table.insert(connections, script.Destroying:Connect(cleanup))
local elapsed = 0
table.insert(connections, RunService.Heartbeat:Connect(function(dt)
	if not alive then return end
	elapsed += dt
	if elapsed < 0.25 then return end
	elapsed = 0
	bindSelection()
	bindPedestals()
	if not gui.Enabled then return end
	local now = os.clock()
	for _, slot in ipairs(slots) do
		if slot.loadToken and now - slot.loadToken.startedAt > 20 then slot.display.StatusLabel.Text = "Avatar is taking longer to load" end
		if slot.userId and slot.point and not slot.avatar and not slot.loadToken and slot.attempts < 3 and now >= slot.retryAt and activeLoads < 2 then beginAvatar(slot) end
	end
end))
table.insert(connections, RunService.PreAnimation:Connect(function()
	if not alive then return end
	for _, slot in ipairs(slots) do if slot.avatar then restorePose(slot.avatar) end end
end))
table.insert(connections, RunService.PreSimulation:Connect(function()
	if not alive or not gui.Enabled then return end
	local now = os.clock()
	for _, slot in ipairs(slots) do
		local avatar = slot.avatar
		if avatar and slot.point and slot.point:IsDescendantOf(workspace) then
			updateAnimation(avatar)
			local authored = avatar.track and avatar.track.IsPlaying and avatar.track.Length > 0
			animateModel(avatar, slot.point, slot.rank, now - avatar.startedAt, authored)
		end
	end
end))

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
