assert(not game:GetService("RunService"):IsRunning(),"Edit mode only")
local ss=game:GetService("ServerScriptService")
local storage=game:GetService("ServerStorage")
local originals=assert(storage:FindFirstChild("LeaderboardScopesBackup20261004"))
local pairsToSet={
{target=ss.PlaygroundLeaderboardService,source=[========[local Players = game:GetService("Players")
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

]========]},
{target=ss.PlaygroundBootstrap,source=[========[local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalizationService = game:GetService("LocalizationService")
local BritishBulldog = require(ServerScriptService:WaitForChild("BritishBulldogService"))
local Tag = require(ServerScriptService:WaitForChild("TagService"))
local Mud = require(ServerScriptService:WaitForChild("StuckInTheMudService"))
local TagSprint = require(ServerScriptService:WaitForChild("TagSprintService"))
local Economy = require(ServerScriptService:WaitForChild("PlaygroundEconomyService"))
local Coordinator = require(ServerScriptService:WaitForChild("PlaygroundCoordinator"))
local Admin = require(ServerScriptService:WaitForChild("PlaygroundAdminService"))

local lobby = workspace:WaitForChild("Playground Lobby")
local britishBulldog = BritishBulldog.new(workspace:WaitForChild("British Bulldog game"))
local tag = Tag.new(workspace:WaitForChild("Tag You're It"))
local mud = Mud.new(workspace:WaitForChild("Stuck in the Mud"))
local tagSprint = TagSprint.new(tag)
local spawn = lobby.Gameplay.LobbySpawn
britishBulldog.lobbySpawn = spawn
tag.lobbySpawn = spawn
mud.lobbySpawn = spawn
britishBulldog:Start()
tag:Start()
mud:Start()
tagSprint:Start()
local economy = Economy.new(lobby)
local leaderboardModule = ServerScriptService:FindFirstChild("PlaygroundLeaderboardService")
if leaderboardModule and lobby:FindFirstChild("Leaderboards") then
	local ok, result = pcall(function()
		local Leaderboards = require(leaderboardModule)
		local Regions = require(ServerScriptService:WaitForChild("PlaygroundRegions"))
		return Leaderboards.new(lobby, {
			resolveRegion = function(player)
				return Regions.Resolve(LocalizationService:GetCountryRegionForPlayerAsync(player))
			end,
		}):Start()
	end)
	if ok then
		economy.leaderboards = result
		local request = ReplicatedStorage:WaitForChild("PlaygroundLeaderboardRequest")
		local requests = {}
		local scopes = { global = true, server = true, region = true }
		request.OnServerInvoke = function(player, scope)
			if player.Parent ~= Players or type(scope) ~= "string" or not scopes[scope] then
				return { state = "unavailable", status = "INVALID REQUEST" }
			end
			local now = os.clock()
			local rate = requests[player]
			if not rate or now - rate.started >= 5 then
				rate = { started = now, count = 0 }
				requests[player] = rate
			end
			if rate.count >= 10 then
				return { scope = scope, state = "loading", status = "PLEASE WAIT", retryAfter = 5 }
			end
			rate.count += 1
			local succeeded, snapshot = pcall(result.GetSnapshot, result, player, scope)
			if succeeded then return snapshot end
			warn("Leaderboard request failed: " .. tostring(snapshot))
			return { scope = scope, state = "unavailable", status = "RANKINGS UNAVAILABLE", retryAfter = 10 }
		end
		local leaving = Players.PlayerRemoving:Connect(function(player)
			requests[player] = nil
		end)
		script.Destroying:Connect(function()
			request.OnServerInvoke = nil
			leaving:Disconnect()
			table.clear(requests)
			result:Stop()
		end)
	else
		warn("Lobby leaderboards could not start: " .. tostring(result))
	end
end
economy:Start()
local Equipment = require(ServerScriptService:WaitForChild("PlaygroundEquipmentService"))
local equipment = Equipment.new({ BritishBulldog = britishBulldog, TagYoureIt = tag }):Start()
script.Destroying:Connect(function() equipment:Stop() end)
local coordinator = Coordinator.new({ BritishBulldog = britishBulldog, TagYoureIt = tag, StuckInTheMud = mud }, lobby, economy)
coordinator:Start()
local admin = Admin.Start(coordinator)
script:SetAttribute("Ready", true)

]========]}
}
for _,entry in ipairs(pairsToSet)do
 if not originals:FindFirstChild(entry.target.Name)then local saved=entry.target:Clone() if saved:IsA("BaseScript")then saved.Disabled=true end saved.Parent=originals end
end
for _,entry in ipairs(pairsToSet)do
 game:GetService("ScriptEditorService"):UpdateSourceAsync(entry.target,function()return entry.source end)
end
local regions=ss:FindFirstChild("PlaygroundRegions")
if not regions then regions=ss.PlaygroundLeaderboardService:Clone() regions.Name="PlaygroundRegions" regions.Source=[========[--!strict
-- Geographic grouping: https://unstats.un.org/unsd/methodology/m49/overview/
-- Roblox country codes: https://create.roblox.com/docs/reference/engine/classes/LocalizationService

export type Region = { id: string, name: string }

local regions: { [string]: Region } = {
	Europe = table.freeze({ id = "Europe", name = "Europe" }),
	NorthAmerica = table.freeze({ id = "NorthAmerica", name = "North America" }),
	SouthAmerica = table.freeze({ id = "SouthAmerica", name = "South America" }),
	Africa = table.freeze({ id = "Africa", name = "Africa" }),
	Asia = table.freeze({ id = "Asia", name = "Asia" }),
	Oceania = table.freeze({ id = "Oceania", name = "Oceania" }),
}
table.freeze(regions)

local countries = {
	Europe = "AD AL AT AX BA BE BG BY CH CZ DE DK EE ES FI FO FR GB GG GI GR HR HU IE IM IS IT JE LI LT LU LV MC MD ME MK MT NL NO PL PT RO RS RU SE SI SJ SK SM UA VA",
	NorthAmerica = "AG AI AN AW BB BL BM BQ BS BZ CA CR CU CW DM DO GD GL GP GT HN HT JM KN KY LC MF MQ MS MX NI PA PM PR SV SX TC TT US VC VG VI",
	SouthAmerica = "AR BO BR BV CL CO EC FK GF GS GY PE PY SR UY VE",
	Africa = "AO BF BI BJ BW CD CF CG CI CM CV DJ DZ EG EH ER ET GA GH GM GN GQ GW IO KE KM LR LS LY MA MG ML MR MU MW MZ NA NE NG RE RW SC SD SH SL SN SO SS ST SZ TD TF TG TN TZ UG YT ZA ZM ZW",
	Asia = "AE AF AM AZ BD BH BN BT CN CY GE HK ID IL IN IQ IR JO JP KG KH KP KR KW KZ LA LB LK MM MN MO MV MY NP OM PH PK PS QA SA SG SY TH TJ TL TM TR TW UZ VN YE",
	Oceania = "AS AU CC CK CX FJ FM GU HM KI MH MP NC NF NR NU NZ PF PG PN PW SB TK TO TV UM VU WF WS",
}
local byCountry: { [string]: Region } = {}
for id, codes in countries do
	for code in string.gmatch(codes, "%u%u") do
		byCountry[code] = regions[id]
	end
end
-- AN remains a documented Roblox return code; TW belongs to geographic Asia.
-- AQ has no requested region; XX is Roblox's unknown-country response.
table.freeze(byCountry)

local PlaygroundRegions = {}

function PlaygroundRegions.Resolve(countryCode: unknown): Region?
	if type(countryCode) ~= "string" or #countryCode ~= 2 then
		return nil
	end
	if not string.match(countryCode, "^[A-Za-z][A-Za-z]$") then
		return nil
	end
	return byCountry[string.upper(countryCode)]
end

return table.freeze(PlaygroundRegions)
]========] regions.Parent=ss else regions.Source=[========[--!strict
-- Geographic grouping: https://unstats.un.org/unsd/methodology/m49/overview/
-- Roblox country codes: https://create.roblox.com/docs/reference/engine/classes/LocalizationService

export type Region = { id: string, name: string }

local regions: { [string]: Region } = {
	Europe = table.freeze({ id = "Europe", name = "Europe" }),
	NorthAmerica = table.freeze({ id = "NorthAmerica", name = "North America" }),
	SouthAmerica = table.freeze({ id = "SouthAmerica", name = "South America" }),
	Africa = table.freeze({ id = "Africa", name = "Africa" }),
	Asia = table.freeze({ id = "Asia", name = "Asia" }),
	Oceania = table.freeze({ id = "Oceania", name = "Oceania" }),
}
table.freeze(regions)

local countries = {
	Europe = "AD AL AT AX BA BE BG BY CH CZ DE DK EE ES FI FO FR GB GG GI GR HR HU IE IM IS IT JE LI LT LU LV MC MD ME MK MT NL NO PL PT RO RS RU SE SI SJ SK SM UA VA",
	NorthAmerica = "AG AI AN AW BB BL BM BQ BS BZ CA CR CU CW DM DO GD GL GP GT HN HT JM KN KY LC MF MQ MS MX NI PA PM PR SV SX TC TT US VC VG VI",
	SouthAmerica = "AR BO BR BV CL CO EC FK GF GS GY PE PY SR UY VE",
	Africa = "AO BF BI BJ BW CD CF CG CI CM CV DJ DZ EG EH ER ET GA GH GM GN GQ GW IO KE KM LR LS LY MA MG ML MR MU MW MZ NA NE NG RE RW SC SD SH SL SN SO SS ST SZ TD TF TG TN TZ UG YT ZA ZM ZW",
	Asia = "AE AF AM AZ BD BH BN BT CN CY GE HK ID IL IN IQ IR JO JP KG KH KP KR KW KZ LA LB LK MM MN MO MV MY NP OM PH PK PS QA SA SG SY TH TJ TL TM TR TW UZ VN YE",
	Oceania = "AS AU CC CK CX FJ FM GU HM KI MH MP NC NF NR NU NZ PF PG PN PW SB TK TO TV UM VU WF WS",
}
local byCountry: { [string]: Region } = {}
for id, codes in countries do
	for code in string.gmatch(codes, "%u%u") do
		byCountry[code] = regions[id]
	end
end
-- AN remains a documented Roblox return code; TW belongs to geographic Asia.
-- AQ has no requested region; XX is Roblox's unknown-country response.
table.freeze(byCountry)

local PlaygroundRegions = {}

function PlaygroundRegions.Resolve(countryCode: unknown): Region?
	if type(countryCode) ~= "string" or #countryCode ~= 2 then
		return nil
	end
	if not string.match(countryCode, "^[A-Za-z][A-Za-z]$") then
		return nil
	end
	return byCountry[string.upper(countryCode)]
end

return table.freeze(PlaygroundRegions)
]========] end
local rs=game:GetService("ReplicatedStorage")
local remote=rs:FindFirstChild("PlaygroundLeaderboardRequest")
if not remote then remote=Instance.new("RemoteFunction") remote.Name="PlaygroundLeaderboardRequest" remote.Parent=rs end
assert(remote:IsA("RemoteFunction"))
return {serverInstalled=true,permissionsUnchanged=true,remote=remote:GetFullName(),backup=originals:GetFullName()}
