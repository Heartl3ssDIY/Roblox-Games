local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Service = {}
Service.__index = Service
local definitions = {
	{ name = "HighestLevel", stat = "XP", store = "PlaygroundClassics_TopXP_v1" },
	{ name = "MostWins", stat = "Wins", store = "PlaygroundClassics_TopWins_v1" },
}

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

function Service.new(lobby)
	local root = child(lobby, "Leaderboards", "Model")
	local self = setmetatable({ lobby = lobby, root = root, boards = {}, queue = {}, published = {}, identities = {}, running = false, isStudio = RunService:IsStudio(), writeBusy = false, generation = 0, nextWriteAt = 0, flushDeadline = 0 }, Service)
	for _, definition in ipairs(definitions) do
		local model = child(root, definition.name, "Model")
		local gui = child(child(model, "Face", "BasePart"), "Display", "SurfaceGui")
		local body = child(gui, "Body", "Frame")
		child(gui, "Empty", "TextLabel")
		child(gui, "Status", "TextLabel")
		local board = { definition = definition, gui = gui, rows = {}, entries = {} }
		for index = 1, 10 do
			local row = child(body, string.format("Row%02d", index), "Frame")
			for _, name in ipairs({ "Rank", "PlayerName", "Value" }) do child(row, name, "TextLabel") end
			child(child(row, "Avatar", "ImageLabel"), "Placeholder", "TextLabel")
			board.rows[index] = row
		end
		table.insert(self.boards, board)
	end
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
	return cached
end

function Service:_render(board, entries, status)
	board.entries = entries
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
	board.gui.Empty.Text = self.isStudio and "No players yet" or "Your next win could put you here!"
	board.gui.Status.Text = status
end

function Service:_connectStores()
	for _, board in ipairs(self.boards) do
		if not board.store then
			local ok, store = pcall(function() return DataStoreService:GetOrderedDataStore(board.definition.store) end)
			if ok then board.store = store end
		end
	end
end

function Service:_refresh(board, generation)
	local entries = {}
	if self.isStudio then
		for _, player in ipairs(Players:GetPlayers()) do
			if validUserId(player.UserId) and player:GetAttribute("PCDataReady") == true then
				table.insert(entries, { userId = player.UserId, value = integer(player:GetAttribute("PC" .. board.definition.stat), 0) })
			end
		end
	else
		local ok, page = pcall(function()
			assert(board.store, "Leaderboard store unavailable")
			return board.store:GetSortedAsync(false, 10, 1):GetCurrentPage()
		end)
		if not self.running or self.generation ~= generation then return end
		if not ok then
			board.gui.Status.Text = #board.entries > 0 and "GLOBAL · RECONNECTING" or "GLOBAL · UNAVAILABLE RIGHT NOW"
			if #board.entries == 0 then board.gui.Empty.Text = "Scores will appear when connected" end
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
	self:_render(board, entries, self.isStudio and "THIS SERVER · STUDIO PREVIEW" or "GLOBAL · UPDATES EVERY MINUTE")
end

function Service:PublishSaved(userId, profile)
	if self.isStudio or not validUserId(userId) or typeof(profile) ~= "table" then return false end
	local xp, wins = integer(profile.XP, nil), integer(profile.Wins, nil)
	if xp == nil or wins == nil then return false end
	local published = self.published[userId] or { XP = 0, Wins = 0 }
	if xp <= published.XP and wins <= published.Wins then return true end
	local pending = self.queue[userId]
	if pending then
		pending.XP, pending.Wins = math.max(pending.XP, xp), math.max(pending.Wins, wins)
	else
		self.queue[userId] = { XP = xp, Wins = wins, due = os.clock(), attempts = 0 }
	end
	return true
end

function Service:_writeOne(generation, deadline)
	if self.writeBusy or self.isStudio or self.generation ~= generation or os.clock() < self.nextWriteAt then return end
	local userId, pending
	for id, candidate in pairs(self.queue) do
		if candidate.due <= os.clock() and (not pending or candidate.due < pending.due) then userId, pending = id, candidate end
	end
	if not pending then return end
	self.writeBusy = true
	self.nextWriteAt = os.clock() + 3
	local published = self.published[userId] or { XP = 0, Wins = 0 }
	self.published[userId] = published
	local success = true
	local interrupted = false
	for _, board in ipairs(self.boards) do
		if self.generation ~= generation or (deadline and os.clock() >= deadline) then interrupted = true break end
		local stat = board.definition.stat
		local snapshot = pending[stat]
		if snapshot > published[stat] then
			local ok = pcall(function()
				assert(board.store, "Leaderboard store unavailable")
				board.store:UpdateAsync(tostring(userId), function(old) return math.max(integer(old, 0), snapshot) end)
			end)
			if ok then published[stat] = snapshot else success = false end
		end
	end
	if success and not interrupted and published.XP >= pending.XP and published.Wins >= pending.Wins then
		self.queue[userId] = nil
	elseif not interrupted then
		pending.attempts += 1
		pending.due = os.clock() + math.min(120, 5 * 2 ^ math.min(pending.attempts, 5))
	end
	self.writeBusy = false
end

function Service:Start()
	if self.running then return self end
	for _, board in ipairs(self.boards) do self:_render(board, board.entries, self.isStudio and "THIS SERVER · STUDIO PREVIEW" or "GLOBAL · CONNECTING") end
	self.generation += 1
	local generation = self.generation
	self.running = true
	task.spawn(function()
		while self.running and self.generation == generation do
			if not self.isStudio then self:_connectStores() end
			for _, board in ipairs(self.boards) do
				if not self.running or self.generation ~= generation then break end
				local ok = pcall(function() self:_refresh(board, generation) end)
				if not ok and self.running and self.generation == generation then board.gui.Status.Text = "SCORES TEMPORARILY UNAVAILABLE" end
			end
			for _ = 1, (self.isStudio and 5 or 60) do if not self.running or self.generation ~= generation then break end task.wait(1) end
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

function Service:Flush(seconds)
	if self.isStudio then return true end
	if typeof(seconds) ~= "number" or seconds ~= seconds or math.abs(seconds) == math.huge then seconds = 3 end
	local deadline = os.clock() + math.clamp(seconds, 0, 5)
	local generation = self.generation
	self.flushDeadline = math.max(self.flushDeadline, deadline)
	if self.flushWorkerGeneration ~= generation then
		self.flushWorkerGeneration = generation
		task.spawn(function()
			while self.generation == generation and os.clock() < self.flushDeadline and (next(self.queue) ~= nil or self.writeBusy) do
				self:_writeOne(generation, self.flushDeadline)
				task.wait(0.05)
			end
			if self.flushWorkerGeneration == generation then self.flushWorkerGeneration = nil end
		end)
	end
	while self.generation == generation and os.clock() < deadline and (next(self.queue) ~= nil or self.writeBusy) do task.wait(math.max(0, math.min(0.05, deadline - os.clock()))) end
	return next(self.queue) == nil and not self.writeBusy
end

function Service:Stop()
	self.running = false
	self.generation += 1
	self.flushDeadline = 0
end

return Service
