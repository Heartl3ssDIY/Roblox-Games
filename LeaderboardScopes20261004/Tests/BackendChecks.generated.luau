local clock = 1000
local jobs = {}
local inJob = false
local task = {}
local os = { clock = function() return clock end }
local function advance(seconds)
	local deadline = clock + seconds
	local steps = 0
	while true do
		local index, nextJob
		for i, job in ipairs(jobs) do if job.at <= deadline and (not nextJob or job.at < nextJob.at) then index, nextJob = i, job end end
		if not nextJob then break end
		table.remove(jobs, index)
		clock = math.max(clock, nextJob.at)
		inJob = true
		local ok, wait = coroutine.resume(nextJob.thread)
		inJob = false
		assert(ok, wait)
		if coroutine.status(nextJob.thread) ~= "dead" then nextJob.at = clock + math.max(0.001, wait or 0.03) table.insert(jobs, nextJob) end
		steps += 1 assert(steps < 10000, "Scheduler did not settle")
	end
	clock = deadline
end
function task.spawn(callback) table.insert(jobs, { thread = coroutine.create(callback), at = clock }) end
function task.wait(seconds)
	seconds = seconds or 0.03
	if inJob then return coroutine.yield(seconds) end
	advance(math.max(0.001, seconds))
	return seconds
end
local function signal()
	local listeners = {}
	return { Connect = function(_, callback)
		local entry = { callback = callback, connected = true }
		table.insert(listeners, entry)
		return { Disconnect = function() entry.connected = false end }
	end, Fire = function(_, ...) for _, entry in ipairs(listeners) do if entry.connected then entry.callback(...) end end end }
end
local players = {}
local identityCalls, reads, writes, connects = 0, 0, 0, 0
local studio = false
local Players = { PlayerAdded = signal() }
function Players:GetPlayers() return table.clone(players) end
function Players:GetPlayerByUserId(id) for _, player in ipairs(players) do if player.UserId == id then return player end end end
function Players:GetNameFromUserIdAsync(id) identityCalls += 1 return "Remote" .. id end
function Players:GetUserThumbnailAsync(id) identityCalls += 1 return "avatar:" .. id, true end
local stores = {}
local DataStoreService = {}
function DataStoreService:GetOrderedDataStore(name)
	connects += 1
	if not stores[name] then
		local store = { name = name, values = {} }
		function store:UpdateAsync(key, transform)
			writes += 1
			if self.failWrites then error("offline write") end
			if self.onWrite then local callback = self.onWrite self.onWrite = nil callback() end
			self.values[key] = transform(self.values[key])
			return self.values[key]
		end
		function store:GetSortedAsync(descending, count, minimum)
			reads += 1
			assert(descending == false and count == 10 and minimum == 1)
			if self.failReads then error("offline read") end
			local page = self.pageOverride and table.clone(self.pageOverride) or {}
			if not self.pageOverride then
				for key, value in pairs(self.values) do if value >= minimum then table.insert(page, { key = key, value = value }) end end
				table.sort(page, function(a, b) return a.value > b.value or a.value == b.value and tonumber(a.key) < tonumber(b.key) end)
				while #page > count do table.remove(page) end
			end
			return { GetCurrentPage = function() return page end }
		end
		stores[name] = store
	end
	return stores[name]
end
local RunService = { IsStudio = function() return studio end }
local services = { Players = Players, DataStoreService = DataStoreService, RunService = RunService }
local game = { GetService = function(_, name) return assert(services[name], name) end }
local Enum = { ThumbnailType = { HeadShot = 1 }, ThumbnailSize = { Size100x100 = 1 } }
local function loadService()
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Service = {}
Service.__index = Service
local definitions = {
	{ name = "HighestLevel", stat = "XP", store = "PlaygroundClassics_TopXP_v1" },
	{ name = "MostWins", stat = "Wins", store = "PlaygroundClassics_TopWins_v1" },
}
local regionNames = { Europe = "Europe", NorthAmerica = "North America", SouthAmerica = "South America", Africa = "Africa", Asia = "Asia", Oceania = "Oceania" }
local states = { ready = 1, loading = 2, stale = 3, unavailable = 4 }

local function integer(value, fallback)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return fallback end
	return math.clamp(math.floor(value), 0, 1000000000)
end

local function validUserId(value)
	return typeof(value) == "number" and value == value and value > 0 and value < 1000000000000 and value % 1 == 0
end

local function ranked(a, b)
	return a.value > b.value or (a.value == b.value and a.userId < b.userId)
end

local function child(parent, name, className)
	local object = assert(parent:FindFirstChild(name), parent:GetFullName() .. "." .. name .. " is missing")
	assert(object:IsA(className), object:GetFullName() .. " must be a " .. className)
	return object
end

function Service.new(lobby, dependencies)
	local root = child(lobby, "Leaderboards", "Model")
	dependencies = dependencies or {}
	local self = setmetatable({ lobby = lobby, root = root, boards = {}, queue = {}, published = {}, identities = {}, identityBusy = {}, running = false, isStudio = RunService:IsStudio(), writeBusy = false, generation = 0, nextWriteAt = 0, nextReadAt = 0, flushDeadline = 0, regions = {}, regionLookups = {}, saved = {}, connections = {}, resolveRegion = dependencies.resolveRegion }, Service)
	for _, definition in ipairs(definitions) do
		local model = child(root, definition.name, "Model")
		local gui = child(child(model, "Face", "BasePart"), "Display", "SurfaceGui")
		local body = child(gui, "Body", "Frame")
		child(gui, "Empty", "TextLabel")
		child(gui, "Status", "TextLabel")
		local board = { definition = definition, gui = gui, rows = {}, entries = {}, state = "loading", status = "GLOBAL · CONNECTING", emptyText = "Scores are loading", refreshAt = 0 }
		for index = 1, 10 do
			local row = child(body, string.format("Row%02d", index), "Frame")
			for _, name in ipairs({ "Rank", "PlayerName", "Value" }) do child(row, name, "TextLabel") end
			child(child(row, "Avatar", "ImageLabel"), "Placeholder", "TextLabel")
			board.rows[index] = row
		end
		table.insert(self.boards, board)
	end
	self.global = { id = "global", label = "GLOBAL", boards = self.boards, queue = self.queue, published = self.published }
	return self
end

function Service:_level(xp)
	xp = integer(xp, 0)
	local base = math.max(1, integer(self.lobby:GetAttribute("BaseLevelXP"), 200))
	local step = integer(self.lobby:GetAttribute("LevelXPStep"), 50)
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
	return completed + 1
end

function Service:_identity(userId)
	local cached = self.identities[userId]
	if cached and cached.expires > os.clock() then return cached end
	local player = Players:GetPlayerByUserId(userId)
	local name = player and player.Name or (cached and cached.name) or "Player " .. userId
	if self.identityBusy[userId] then return cached or { name = name, image = "" } end
	self.identityBusy[userId] = true
	local nameOk = player ~= nil
	if not nameOk then
		local ok, value = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
		if ok and typeof(value) == "string" then name, nameOk = value, true end
	end
	local image = cached and cached.image or ""
	local ok, value, ready = pcall(function() return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100) end)
	if ok and ready and typeof(value) == "string" then image = value end
	cached = { name = name, image = image, expires = os.clock() + (nameOk and ok and ready and 600 or 30) }
	self.identities[userId] = cached
	self.identityBusy[userId] = nil
	return cached
end

function Service:_render(board, entries, status, state, emptyText)
	board.entries = entries
	board.status = status
	board.state = state or "ready"
	board.emptyText = emptyText or (self.isStudio and "No players yet" or "Your next win could put you here!")
	if not board.gui then return end
	for index, row in ipairs(board.rows) do
		local entry = entries[index]
		row.Visible = entry ~= nil
		if entry then
			row:SetAttribute("UserId", entry.userId)
			row.Rank.Text = tostring(index)
			row.PlayerName.Text = entry.name or ("Player " .. entry.userId)
			row.Avatar.Image = entry.image or ""
			row.Avatar.Placeholder.Visible = row.Avatar.Image == ""
			row.Value.Text = board.definition.stat == "XP" and ("LV " .. self:_level(entry.value)) or tostring(entry.value)
		end
	end
	board.gui.Empty.Visible = #entries == 0
	board.gui.Empty.Text = board.emptyText
	board.gui.Status.Text = status
end

function Service:_scopes()
	local result = { self.global }
	for _, region in pairs(self.regions) do table.insert(result, region) end
	return result
end

function Service:_connectStores()
	if self.isStudio then return end
	for _, scope in ipairs(self:_scopes()) do
		for _, board in ipairs(scope.boards) do
			if not board.store and os.clock() >= (board.connectAt or 0) then
				board.connectAt = os.clock() + 30
				local ok, store = pcall(function() return DataStoreService:GetOrderedDataStore(board.definition.store) end)
				if ok then board.store = store end
			end
		end
	end
end

function Service:_serverEntries(stat, regionId)
	local entries = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local region = self.regionLookups[player.UserId]
		if validUserId(player.UserId) and player:GetAttribute("PCDataReady") == true
			and (not regionId or (region and region.id == regionId)) then
			local cached = self.identities[player.UserId]
			table.insert(entries, { userId = player.UserId, value = integer(player:GetAttribute("PC" .. stat), 0), name = player.Name, image = cached and cached.image or "" })
		end
	end
	table.sort(entries, ranked)
	while #entries > 10 do table.remove(entries) end
	return entries
end

function Service:_refresh(board, generation, scope)
	scope = scope or self.global
	local entries = {}
	if self.isStudio then
		entries = self:_serverEntries(board.definition.stat, scope.id ~= "global" and scope.id or nil)
	else
		local ok, page = pcall(function()
			assert(board.store, "Leaderboard store unavailable")
			return board.store:GetSortedAsync(false, 10, 1):GetCurrentPage()
		end)
		if not self.running or self.generation ~= generation then return end
		if not ok then
			self:_render(board, board.entries, scope.label .. (#board.entries > 0 and " · RECONNECTING" or " · UNAVAILABLE RIGHT NOW"), #board.entries > 0 and "stale" or "unavailable", "Scores will appear when connected")
			return
		end
		for _, entry in ipairs(page) do
			local userId, value = tonumber(entry.key), integer(entry.value, nil)
			if validUserId(userId) and value then table.insert(entries, { userId = userId, value = value }) end
		end
	end
	table.sort(entries, ranked)
	while #entries > 10 do table.remove(entries) end
	for _, entry in ipairs(entries) do
		local identity = self:_identity(entry.userId)
		if not self.running or self.generation ~= generation then return end
		entry.name, entry.image = identity.name, identity.image
	end
	if not self.running or self.generation ~= generation then return end
	self:_render(board, entries, self.isStudio and (scope.id == "global" and "THIS SERVER · STUDIO PREVIEW" or scope.label .. " · STUDIO PREVIEW") or scope.label .. " · UPDATES EVERY MINUTE", "ready", self.isStudio and "No players yet" or scope.id ~= "global" and "Regional scores appear as players play and save" or nil)
end

function Service:_queueScores(scope, userId, scores)
	local xp, wins = scores.XP, scores.Wins
	local published = scope.published[userId] or { XP = 0, Wins = 0 }
	if xp <= published.XP and wins <= published.Wins then return true end
	local pending = scope.queue[userId]
	if pending then
		pending.XP, pending.Wins = math.max(pending.XP, xp), math.max(pending.Wins, wins)
	else
		scope.queue[userId] = { XP = xp, Wins = wins, due = os.clock(), attempts = 0 }
	end
	return true
end

function Service:_region(id)
	local region = self.regions[id]
	if region then return region end
	region = { id = id, label = "REGION · " .. string.upper(regionNames[id]), boards = {}, queue = {}, published = {} }
	for _, definition in ipairs(definitions) do
		table.insert(region.boards, {
			definition = { name = definition.name, stat = definition.stat, store = definition.store .. "_Region_" .. id },
			rows = {}, entries = {}, refreshAt = 0, state = "loading", status = region.label .. " · CONNECTING", emptyText = "Regional scores are loading",
		})
	end
	self.regions[id] = region
	return region
end

function Service:_resolvePlayer(player, generation)
	local userId = player.UserId
	if not validUserId(userId) then return end
	local lookup = self.regionLookups[userId]
	if not lookup then
		lookup = { state = "loading", attempts = 0, retryAt = 0 }
		self.regionLookups[userId] = lookup
	end
	if lookup.id or lookup.busy or lookup.state == "unavailable" or os.clock() < lookup.retryAt then return end
	if typeof(self.resolveRegion) ~= "function" then lookup.state = "unavailable" return end
	lookup.busy = true
	lookup.attempts += 1
	task.spawn(function()
		local ok, region = pcall(self.resolveRegion, player)
		lookup.busy = false
		if not self.running or self.generation ~= generation then return end
		if ok and typeof(region) == "table" and regionNames[region.id] then
			lookup.id, lookup.state = region.id, "ready"
			local scope = self:_region(region.id)
			if not self.isStudio and self.saved[userId] then self:_queueScores(scope, userId, self.saved[userId]) end
		elseif ok or lookup.attempts >= 3 then
			lookup.state = "unavailable"
		else
			lookup.retryAt = os.clock() + 15 * lookup.attempts
		end
	end)
end

function Service:PublishSaved(userId, profile)
	if self.isStudio or not validUserId(userId) or typeof(profile) ~= "table" then return false end
	local xp, wins = integer(profile.XP, nil), integer(profile.Wins, nil)
	if xp == nil or wins == nil then return false end
	local saved = self.saved[userId]
	self.saved[userId] = { XP = math.max(saved and saved.XP or 0, xp), Wins = math.max(saved and saved.Wins or 0, wins) }
	self:_queueScores(self.global, userId, self.saved[userId])
	local lookup = self.regionLookups[userId]
	if lookup and lookup.id then
		self:_queueScores(self:_region(lookup.id), userId, self.saved[userId])
	elseif self.running then
		local player = Players:GetPlayerByUserId(userId)
		if player then self:_resolvePlayer(player, self.generation) end
	end
	return true
end

function Service:_writeOne(generation, deadline)
	if self.writeBusy or self.isStudio or self.generation ~= generation or os.clock() < self.nextWriteAt then return end
	local userId, pending, scope
	for _, bucket in ipairs(self:_scopes()) do
		for id, candidate in pairs(bucket.queue) do
			if candidate.due <= os.clock() and (not pending or candidate.due < pending.due) then userId, pending, scope = id, candidate, bucket end
		end
	end
	if not pending then return end
	self.writeBusy = true
	self.nextWriteAt = os.clock() + 3
	local published = scope.published[userId] or { XP = 0, Wins = 0 }
	scope.published[userId] = published
	local success = true
	local interrupted = false
	for _, board in ipairs(scope.boards) do
		if self.generation ~= generation or (deadline and os.clock() >= deadline) then interrupted = true break end
		local stat = board.definition.stat
		local snapshot = pending[stat]
		if snapshot > published[stat] then
			local ok = pcall(function()
				assert(board.store, "Leaderboard store unavailable")
				board.store:UpdateAsync(tostring(userId), function(old) return math.max(integer(old, 0), snapshot) end)
			end)
			if self.generation ~= generation then interrupted = true break end
			if ok then published[stat] = snapshot else success = false end
		end
	end
	if success and not interrupted and published.XP >= pending.XP and published.Wins >= pending.Wins then
		scope.queue[userId] = nil
	elseif success and not interrupted then
		pending.due = os.clock()
	elseif not interrupted then
		pending.attempts += 1
		pending.due = os.clock() + math.min(120, 5 * 2 ^ math.min(pending.attempts, 5))
	end
	self.writeBusy = false
end

function Service:_activeRegions()
	local result = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local lookup = self.regionLookups[player.UserId]
		if lookup and lookup.id then result[lookup.id] = true end
	end
	return result
end

function Service:_refreshNext(generation)
	if os.clock() < self.nextReadAt then return end
	local active = self:_activeRegions()
	local chosen, chosenScope
	for _, scope in ipairs(self:_scopes()) do
		if scope.id == "global" or active[scope.id] then
			for _, board in ipairs(scope.boards) do
				if board.refreshAt <= os.clock() and (not chosen or board.refreshAt < chosen.refreshAt) then chosen, chosenScope = board, scope end
			end
		end
	end
	if not chosen then return end
	self.nextReadAt = os.clock() + (self.isStudio and 0.5 or 2)
	chosen.refreshAt = os.clock() + (self.isStudio and 5 or 60)
	local ok = pcall(function() self:_refresh(chosen, generation, chosenScope) end)
	if not ok and self.running and self.generation == generation then
		self:_render(chosen, chosen.entries, chosenScope.label .. " · UNAVAILABLE RIGHT NOW", #chosen.entries > 0 and "stale" or "unavailable", "Scores will appear when connected")
	end
end

function Service:_displayEntries(entries, stat)
	local result = {}
	for _, entry in ipairs(entries) do
		local cached = self.identities[entry.userId]
		table.insert(result, { userId = entry.userId, name = entry.name or (cached and cached.name) or "Player " .. entry.userId, image = cached and cached.image or entry.image or "", value = stat == "XP" and "LV " .. self:_level(entry.value) or tostring(entry.value) })
	end
	return result
end

function Service:GetSnapshot(player, requested)
	local scope = requested == "server" and "server" or requested == "region" and "region" or "global"
	local lookup = player and self.regionLookups[player.UserId]
	local regionId = lookup and lookup.id
	local response = { scope = scope, region = regionId and regionNames[regionId] or nil, regionId = regionId, boards = {}, state = "ready", retryAfter = 30 }
	if scope == "server" then
		response.status = self.isStudio and "THIS SERVER · STUDIO PREVIEW" or "THIS SERVER · CURRENT PLAYERS"
		for _, definition in ipairs(definitions) do
			response.boards[definition.name] = { entries = self:_displayEntries(self:_serverEntries(definition.stat), definition.stat), state = "ready", status = response.status, emptyText = "No players with loaded scores yet" }
		end
		return response
	end
	if scope == "region" and not regionId then
		response.state = lookup and lookup.state or (self.running and "loading" or "unavailable")
		response.status = response.state == "loading" and "REGION · FINDING YOUR REGION" or "REGION · LOCATION UNAVAILABLE"
		response.retryAfter = response.state == "loading" and 5 or 60
		for _, definition in ipairs(definitions) do
			response.boards[definition.name] = { entries = {}, state = response.state, status = response.status, emptyText = response.state == "loading" and "Finding your broad region" or "Your region could not be determined" }
		end
		return response
	end
	local bucket = scope == "global" and self.global or self.regions[regionId]
	for _, board in ipairs(bucket.boards) do
		response.boards[board.definition.name] = { entries = self:_displayEntries(board.entries, board.definition.stat), state = board.state, status = board.status, emptyText = board.emptyText }
		if states[board.state] > states[response.state] then response.state = board.state end
	end
	local suffix = response.state == "loading" and "CONNECTING" or response.state == "stale" and "RECONNECTING · SHOWING SAVED SCORES" or response.state == "unavailable" and "UNAVAILABLE RIGHT NOW" or "UPDATES EVERY MINUTE"
	response.status = self.isStudio and (scope == "global" and "THIS SERVER · STUDIO PREVIEW" or bucket.label .. " · STUDIO PREVIEW") or bucket.label .. " · " .. suffix
	response.retryAfter = response.state == "loading" and 5 or 30
	return response
end

function Service:Start()
	if self.running then return self end
	for _, board in ipairs(self.boards) do self:_render(board, board.entries, self.isStudio and "THIS SERVER · STUDIO PREVIEW" or "GLOBAL · CONNECTING", #board.entries > 0 and "stale" or "loading", "Scores are loading") end
	self.generation += 1
	local generation = self.generation
	self.running = true
	local function added(player)
		self:_resolvePlayer(player, generation)
		if validUserId(player.UserId) then task.spawn(function() if self.running and self.generation == generation then self:_identity(player.UserId) end end) end
	end
	table.insert(self.connections, Players.PlayerAdded:Connect(added))
	for _, player in ipairs(Players:GetPlayers()) do added(player) end
	task.spawn(function()
		while self.running and self.generation == generation do
			self:_connectStores()
			for _, player in ipairs(Players:GetPlayers()) do self:_resolvePlayer(player, generation) end
			self:_refreshNext(generation)
			task.wait(1)
		end
	end)
	task.spawn(function()
		while self.running and self.generation == generation do
			self:_writeOne(generation)
			task.wait(3)
		end
	end)
	return self
end

function Service:_pending()
	if self.writeBusy then return true end
	for _, scope in ipairs(self:_scopes()) do if next(scope.queue) then return true end end
	for userId, lookup in pairs(self.regionLookups) do
		if self.saved[userId] and lookup.state == "loading" then return true end
	end
	return false
end

function Service:Flush(seconds)
	if self.isStudio then return true end
	if typeof(seconds) ~= "number" or seconds ~= seconds or math.abs(seconds) == math.huge then seconds = 3 end
	local deadline = os.clock() + math.clamp(seconds, 0, 5)
	local generation = self.generation
	self.flushDeadline = math.max(self.flushDeadline, deadline)
	if self.flushWorkerGeneration ~= generation then
		self.flushWorkerGeneration = generation
		task.spawn(function()
			while self.generation == generation and os.clock() < self.flushDeadline and self:_pending() do
				self:_writeOne(generation, self.flushDeadline)
				task.wait(0.05)
			end
			if self.flushWorkerGeneration == generation then self.flushWorkerGeneration = nil end
		end)
	end
	while self.generation == generation and os.clock() < deadline and self:_pending() do task.wait(math.max(0, math.min(0.05, deadline - os.clock()))) end
	return not self:_pending()
end

function Service:Stop()
	self.running = false
	self.generation += 1
	self.flushDeadline = 0
	for _, connection in ipairs(self.connections) do connection:Disconnect() end
	table.clear(self.connections)
end

return Service


end
local Service = loadService()
local passed = {}
local function check(name, value) assert(value, name) table.insert(passed, name) end
local function object(name, class)
	local value = { Name = name, class = class, attributes = {}, children = {} }
	function value:FindFirstChild(childName) return self.children[childName] end
	function value:GetFullName() return self.Name end
	function value:IsA(wanted) return self.class == wanted end
	function value:SetAttribute(key, v) self.attributes[key] = v end
	function value:GetAttribute(key) return self.attributes[key] end
	return value
end
local function child(parent, name, class)
	local value = object(name, class)
	parent.children[name], parent[name] = value, value
	return value
end
local function lobby()
	local value = object("Lobby", "Model")
	local root = child(value, "Leaderboards", "Model")
	for _, name in ipairs({ "HighestLevel", "MostWins" }) do
		local gui = child(child(child(root, name, "Model"), "Face", "BasePart"), "Display", "SurfaceGui")
		child(gui, "Empty", "TextLabel") child(gui, "Status", "TextLabel")
		local body = child(gui, "Body", "Frame")
		for index = 1, 10 do
			local row = child(body, string.format("Row%02d", index), "Frame")
			child(row, "Rank", "TextLabel") child(row, "PlayerName", "TextLabel") child(row, "Value", "TextLabel")
			child(child(row, "Avatar", "ImageLabel"), "Placeholder", "TextLabel")
		end
	end
	return value
end
local function player(id, xp, wins, ready)
	local value = object("User" .. id, "Player")
	value.UserId, value.Parent = id, Players
	value.attributes = { PCXP = xp, PCWins = wins, PCDataReady = ready ~= false }
	return value
end
local function fresh(resolve)
	local value = Service.new(lobby(), { resolveRegion = resolve })
	value.running, value.generation = true, 1
	return value
end
local function reset()
	players, stores, jobs = {}, {}, {}
	reads, writes, connects, identityCalls = 0, 0, 0, 0
	studio = false
	clock += 1000
end
local function drain(service)
	for _ = 1, 20 do
		service:_connectStores()
		service:_writeOne(service.generation)
		advance(3)
		local pending = false
		for _, scope in ipairs(service:_scopes()) do if next(scope.queue) then pending = true end end
		if not pending then return end
	end
	error("Write queue did not drain")
end
reset()
local first, second, loading = player(101, 450, 5), player(102, 200, 9), player(103, 99999, 999, false)
players = { first, second, loading }
local service = fresh(function(p) return p == first and { id = "Europe", name = "Europe" } or nil end)
local snap = service:GetSnapshot(first, "server")
check("server sorts wins and formats values as strings", snap.boards.MostWins.entries[1].userId == 102 and snap.boards.MostWins.entries[1].value == "9")
check("server sorts XP and formats display levels", snap.boards.HighestLevel.entries[1].userId == 101 and snap.boards.HighestLevel.entries[1].value == "LV 3")
check("unready players excluded from server rankings", #snap.boards.MostWins.entries == 2)
check("all snapshots avoid datastore and identity requests", reads == 0 and writes == 0 and connects == 0 and identityCalls == 0)
players = { first, loading }
check("departed player disappears immediately", #service:GetSnapshot(first, "server").boards.MostWins.entries == 1)
first.attributes.PCWins = 15
check("server reflects current score without saved-profile publication", service:GetSnapshot(first, "server").boards.MostWins.entries[1].value == "15")
check("invalid scope safely defaults global", service:GetSnapshot(first, "unsupported").scope == "global")
check("global begins honestly loading", service:GetSnapshot(first, "global").state == "loading")
check("unresolved region begins honestly loading", service:GetSnapshot(first, "region").state == "loading")
check("only valid saved profiles accepted", not service:PublishSaved(0, { XP = 2, Wins = 1 }) and not service:PublishSaved(101, { XP = 0 / 0, Wins = 1 }))
check("saved profile queues global publication", service:PublishSaved(101, { XP = 450, Wins = 5 }) and service.queue[101].XP == 450)
check("saved profile retained before resolution", service.saved[101].Wins == 5 and next(service.regions) == nil)
service:PublishSaved(101, { XP = 900, Wins = 7 })
advance(0)
check("resolution queues latest saved snapshot for region", service.regions.Europe.queue[101].XP == 900 and service.regions.Europe.queue[101].Wins == 7)
check("regional creation alone never writes or reads datastore", writes == 0 and reads == 0)
local regionReply = service:GetSnapshot(first, "region")
check("region metadata uses validated canonical display name", regionReply.region == "Europe" and regionReply.regionId == "Europe" and regionReply.scope == "region")
service:_connectStores()
check("original global datastore names preserved", stores.PlaygroundClassics_TopXP_v1 ~= nil and stores.PlaygroundClassics_TopWins_v1 ~= nil)
check("regional stores have deterministic isolated names", stores.PlaygroundClassics_TopXP_v1_Region_Europe ~= nil and stores.PlaygroundClassics_TopWins_v1_Region_Europe ~= nil)
drain(service)
check("both global and regional scores persist", stores.PlaygroundClassics_TopXP_v1.values["101"] == 900 and stores.PlaygroundClassics_TopWins_v1_Region_Europe.values["101"] == 7)
check("successful queues drain independently", next(service.queue) == nil and next(service.regions.Europe.queue) == nil)
local writeCount = writes
service:PublishSaved(101, { XP = 1, Wins = 1 })
drain(service)
check("lower saved values never lower high scores", writes == writeCount and service.saved[101].XP == 900)
for _, board in ipairs(service.boards) do service:_refresh(board, service.generation) end
for _, board in ipairs(service.regions.Europe.boards) do service:_refresh(board, service.generation, service.regions.Europe) end
snap = service:GetSnapshot(first, "global")
check("persistent global cache displays saved score rather than live attributes", snap.boards.MostWins.entries[1].value == "7")
check("live world board renders same cached global values", service.boards[2].rows[1].Value.Text == "7" and service.boards[1].rows[1].Value.Text == "LV 4")
check("offline name/avatar identity is cached", snap.boards.MostWins.entries[1].name == "User101" and snap.boards.MostWins.entries[1].image == "avatar:101")
local readCount, identityCount = reads, identityCalls
for _ = 1, 100 do service:GetSnapshot(first, "global") service:GetSnapshot(first, "region") service:GetSnapshot(first, "server") end
check("300 cached requests cause zero new service reads", reads == readCount and identityCalls == identityCount)
snap.boards.MostWins.entries[1].name = "tampered"
check("snapshot tables cannot mutate cached entries", service:GetSnapshot(first, "global").boards.MostWins.entries[1].name == "User101")
stores.PlaygroundClassics_TopWins_v1.failReads = true
service:_refresh(service.boards[2], service.generation)
snap = service:GetSnapshot(first, "global")
check("failed read keeps cached scores with stale status", snap.state == "stale" and snap.boards.MostWins.entries[1].value == "7" and snap.boards.MostWins.status:find("RECONNECTING") ~= nil)
stores.PlaygroundClassics_TopWins_v1.failReads = nil
service:_refresh(service.boards[2], service.generation)
check("successful retry clears stale status", service:GetSnapshot(first, "global").state == "ready")
service:_resolvePlayer(second, service.generation)
advance(0)
check("unknown location is honestly unavailable", service:GetSnapshot(second, "region").state == "unavailable" and service:GetSnapshot(second, "region").region == nil)
service:PublishSaved(second.UserId, { XP = 300, Wins = 2 })
check("unknown region saves global only", service.queue[102] ~= nil and service.regions.Europe.queue[102] == nil)
local invalid = player(104, 200, 1)
players = { invalid }
service.resolveRegion = function() return { id = "arbitrary/store", name = "Fake" } end
service:_resolvePlayer(invalid, service.generation) advance(0)
check("invalid resolver region never creates arbitrary datastore", service:GetSnapshot(invalid, "region").state == "unavailable" and service.regions["arbitrary/store"] == nil)
reset()
first = player(201, 250, 3)
players = { first }
local attempts = 0
service = fresh(function() attempts += 1 error("localization temporarily offline") end)
service:_resolvePlayer(first, 1) advance(0)
service:_resolvePlayer(first, 1) advance(0)
check("transient location lookup is bounded by retry delay", attempts == 1)
advance(15) service:_resolvePlayer(first, 1) advance(0)
advance(30) service:_resolvePlayer(first, 1) advance(0)
advance(200) service:_resolvePlayer(first, 1) advance(0)
check("lookup stops after three transient failures", attempts == 3 and service:GetSnapshot(first, "region").state == "unavailable")
reset()
first = player(301, 250, 3)
players = { first }
service = fresh(function() return { id = "Europe" } end)
service:_resolvePlayer(first, 1) advance(0)
service:PublishSaved(301, { XP = 250, Wins = 3 })
service:_connectStores()
stores.PlaygroundClassics_TopXP_v1_Region_Europe.failWrites = true
service:_writeOne(1)
advance(3) service:_writeOne(1)
check("regional failure does not erase successful global publication", service.published[301].XP == 250 and next(service.queue) == nil and service.regions.Europe.queue[301] ~= nil)
check("partial regional success retained", service.regions.Europe.published[301].Wins == 3 and service.regions.Europe.published[301].XP == 0)
check("regional failure gets bounded backoff", service.regions.Europe.queue[301].due > clock and service.regions.Europe.queue[301].attempts == 1)
service:PublishSaved(302, { XP = 500, Wins = 8 })
advance(3) service:_writeOne(1)
check("ready global writes proceed while region is retrying", service.published[302].XP == 500)
stores.PlaygroundClassics_TopXP_v1_Region_Europe.failWrites = nil
advance(10) drain(service)
check("regional retry eventually persists missing stat", stores.PlaygroundClassics_TopXP_v1_Region_Europe.values["301"] == 250 and next(service.regions.Europe.queue) == nil)
service:PublishSaved(301, { XP = 600, Wins = 4 })
stores.PlaygroundClassics_TopXP_v1.onWrite = function() service:PublishSaved(301, { XP = 900, Wins = 6 }) end
drain(service)
check("newer saved scores during write are not lost", stores.PlaygroundClassics_TopXP_v1.values["301"] == 900 and stores.PlaygroundClassics_TopXP_v1_Region_Europe.values["301"] == 900)
service:PublishSaved(303, { XP = 300, Wins = 3 })
local beforeThrottle = writes
service.nextWriteAt = clock + 3 service:_writeOne(1)
check("shared write throttle is enforced", writes == beforeThrottle)
advance(3) service:_writeOne(1, clock)
check("expired flush deadline leaves pending scores intact", writes == beforeThrottle and service.queue[303] ~= nil and not service.writeBusy)
service.nextWriteAt = clock
drain(service)
check("empty flush succeeds", service:Flush(0))
service:PublishSaved(304, { XP = 300, Wins = 1 })
check("zero deadline flush honestly reports pending work", not service:Flush(0))
service.nextWriteAt = clock
check("bounded flush drains global pending writes", service:Flush(5) and next(service.queue) == nil)
reset()
first = player(401, 600, 4)
players = { first }
service = fresh(function() return { id = "Europe" } end)
service:_resolvePlayer(first, 1) advance(0)
for _, id in ipairs({ "Asia", "Africa", "Oceania", "NorthAmerica", "SouthAmerica" }) do service:_region(id) end
service:_connectStores()
for _ = 1, 4 do service:_refreshNext(1) advance(2) end
check("refresh only reads global plus current active region", reads == 4)
for _, scope in pairs(service.regions) do if scope.id ~= "Europe" then check("inactive " .. scope.id .. " cache is not fetched", scope.boards[1].state == "loading" and scope.boards[2].state == "loading") end end
players = {}
for _, board in ipairs(service.boards) do board.refreshAt = clock + 100 end
for _, board in ipairs(service.regions.Europe.boards) do board.refreshAt = 0 end
local beforeDeparted = reads
service:_refreshNext(1)
check("departed region stops refreshing immediately", reads == beforeDeparted)
reset()
studio = true
first, second = player(501, 450, 2), player(502, 200, 7)
players = { first, second }
service = fresh(function(p) return p == first and { id = "Europe" } or { id = "Asia" } end)
service:_resolvePlayer(first, 1) service:_resolvePlayer(second, 1) advance(0)
service:_connectStores()
for _, board in ipairs(service.boards) do service:_refresh(board, 1) end
for _, scope in pairs(service.regions) do for _, board in ipairs(scope.boards) do service:_refresh(board, 1, scope) end end
check("Studio never connects reads or writes external datastores", connects == 0 and reads == 0 and writes == 0 and not service:PublishSaved(501, { XP = 1, Wins = 1 }))
check("Studio global explicitly labels local preview", service:GetSnapshot(first, "global").status:find("STUDIO PREVIEW") ~= nil)
snap = service:GetSnapshot(first, "region")
check("Studio region preview filters by actual resolved region", #snap.boards.MostWins.entries == 1 and snap.boards.MostWins.entries[1].userId == 501 and snap.status:find("STUDIO PREVIEW") ~= nil)
reset()
first = player(601, 300, 2)
players = { first }
service = Service.new(lobby(), { resolveRegion = function() return { id = "Europe" } end })
service:Start()
check("Start keeps uncached global boards in loading state", service:GetSnapshot(first, "global").state == "loading")
advance(0)
check("Start resolves current players in background", service.regionLookups[601].id == "Europe")
local extra = player(602, 600, 3)
table.insert(players, extra) Players.PlayerAdded:Fire(extra) advance(0)
check("new arrivals resolve without snapshot side effects", service.regionLookups[602].id == "Europe")
service:Stop()
local readsAtStop, writesAtStop = reads, writes
advance(65)
check("Stop halts background reads and writes", reads == readsAtStop and writes == writesAtStop)
local departed = player(603, 0, 0)
table.insert(players, departed) Players.PlayerAdded:Fire(departed) advance(0)
check("Stop disconnects player lifecycle subscription", service.regionLookups[603] == nil)
reset()
first = player(701, 400, 5)
players = { first }
service = fresh(function() task.wait(2) return { id = "Europe" } end)
service:PublishSaved(701, { XP = 400, Wins = 5 })
advance(0)
check("Flush tracks unresolved saved regional work", service:_pending())
service:Stop()
advance(3)
check("stale resolver completion cannot queue after Stop", service.regions.Europe == nil)
print("PASS " .. #passed .. " backend checks; mocked services only, zero live datastore calls, no Studio mutations")
for _, name in ipairs(passed) do print("PASS " .. name) end
