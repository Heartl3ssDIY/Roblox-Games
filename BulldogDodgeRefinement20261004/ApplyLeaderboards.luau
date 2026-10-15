assert(not game:GetService("RunService"):IsRunning(),"Edit mode only")
assert(game.PlaceId==95034648955135,"Wrong place")
local server=game:GetService("ServerScriptService")
local storage=game:GetService("ServerStorage")
local lobby=workspace:FindFirstChild("Playground Lobby")
assert(lobby and not lobby:FindFirstChild("Leaderboards"),"Inspect existing leaderboards first")
assert(not server:FindFirstChild("PlaygroundLeaderboardService"),"Inspect existing leaderboard service first")
local entries={{name=[====[PlaygroundEconomyService]====],before=[====[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Debris = game:GetService("Debris")
local Catalog = require(ReplicatedStorage:WaitForChild("PlaygroundCatalog"))

local Economy = {}
Economy.__index = Economy
local slots = { Pet = true, Emote = true, Emoji = true, Trail = true, Highlight = true, Gear = true }
local actions = { GetStatus = true, Buy = true, Equip = true, Unequip = true, UseEmote = true, UseEmoji = true }
local ink = Color3.fromRGB(24, 35, 62)

local function integer(value, fallback)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return fallback end
	return math.clamp(math.floor(value), 0, 1000000000)
end

local function timestamp(value)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return 0 end
	return math.clamp(math.floor(value), 0, 1000000000000)
end

local function levelProgress(xp, base, step)
	xp = integer(xp, 0)
	base = math.max(1, integer(base, 100))
	step = integer(step, 50)
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
	return completed + 1, xp - cost(completed), base + step * completed
end

local function cleanData(value)
	value = typeof(value) == "table" and value or {}
	local result = { Coins = integer(value.Coins, 0), Wins = integer(value.Wins, 0), XP = integer(value.XP, 0), Owned = {}, Equipped = {}, Version = 2 }
	if typeof(value.Owned) == "table" then
		for id, owned in pairs(value.Owned) do
			if typeof(id) == "string" and #id <= 48 and owned == true then result.Owned[id] = true end
		end
	end
	if typeof(value.Equipped) == "table" then
		for slot, id in pairs(value.Equipped) do
			local item = Catalog.ById[id]
			if slots[slot] and item and item.slot == slot and result.Owned[id] then result.Equipped[slot] = id end
		end
	end
	return result
end

function Economy:_setting(name, fallback)
	return integer(self.lobby:GetAttribute(name), fallback)
end

function Economy:LevelProgress(xp)
	return levelProgress(xp, self:_setting("BaseLevelXP", 200), self:_setting("LevelXPStep", 50))
end

function Economy.new(lobby, storeOverride, studioOverride)
	local self = setmetatable({}, Economy)
	self.lobby = lobby
	self.bounds = lobby.Gameplay.LobbyBounds
	self.profiles = {}
	self.connections = {}
	self.awarded = {}
	self.isStudio = studioOverride == nil and RunService:IsStudio() or studioOverride
	self.sessionId = game.JobId .. ":" .. HttpService:GenerateGUID(false)
	self.store = storeOverride
	if not self.isStudio and not self.store then
		local ok, store = pcall(function() return DataStoreService:GetDataStore("PlaygroundClassics_Profiles_v1") end)
		if ok then self.store = store end
	end
	self.sessionOnly = not self.isStudio and self.store == nil
	self.assets = ReplicatedStorage:WaitForChild("PlaygroundCosmeticAssets")
	self.effects = Instance.new("Folder")
	self.effects.Name = "PlaygroundCosmeticEffects"
	self.effects.Parent = workspace
	self.coins = {}
	self.running = false
	self.elapsed = 0
	self.lastSave = os.clock()
	return self
end

function Economy:_sync(profile)
	local player = profile.player
	profile.data.XP = integer(profile.data.XP, 0)
	local level, levelXP, requiredXP = self:LevelProgress(profile.data.XP)
	player:SetAttribute("PCCoins", profile.data.Coins)
	player:SetAttribute("PCWins", profile.data.Wins)
	player:SetAttribute("PCXP", profile.data.XP)
	player:SetAttribute("PCLevel", level)
	player:SetAttribute("PCLevelXP", levelXP)
	player:SetAttribute("PCLevelXPRequired", requiredXP)
	player:SetAttribute("PCDataReady", profile.ready == true)
	player:SetAttribute("PCDataMode", self.isStudio and "Studio" or self.sessionOnly and "Session" or "Persistent")
	for slot in pairs(slots) do player:SetAttribute("PC" .. slot, profile.data.Equipped[slot] or "") end
	local board = player:FindFirstChild("leaderstats")
	if board then
		local wins = board:FindFirstChild("Wins")
		local coins = board:FindFirstChild("Coins")
		local levelCounter = board:FindFirstChild("Level")
		if wins then wins.Value = profile.data.Wins end
		if coins then coins.Value = profile.data.Coins end
		if levelCounter then levelCounter.Value = level end
	end
end

function Economy:_claim(profile)
	if self.isStudio or self.sessionOnly then
		profile.data = cleanData({ Coins = self.isStudio and 150 or 0 })
		profile.ready = true
		return true
	end
	local ok, value = pcall(function()
		return self.store:UpdateAsync("u:" .. profile.player.UserId, function(old)
			old = typeof(old) == "table" and old or {}
			local lease = old.Session
			if typeof(lease) == "table" and lease.Id ~= self.sessionId and timestamp(lease.Expires) > os.time() then return nil end
			local data = cleanData(old)
			data.Session = { Id = self.sessionId, Expires = os.time() + 180 }
			return data
		end)
	end)
	if ok and typeof(value) == "table" and value.Session and value.Session.Id == self.sessionId then
		profile.data = cleanData(value)
		profile.ready = true
		return true
	end
	return false
end

function Economy:_save(profile, release)
	if self.isStudio or self.sessionOnly or not profile.ready or profile.released then return true end
	local untilTime = os.clock() + 8
	while profile.saving and os.clock() < untilTime do task.wait(0.1) end
	if profile.released then return true end
	if profile.saving then return false end
	profile.saving = true
	local version = profile.version
	local snapshot = cleanData(profile.data)
	local saved = false
	for attempt = 1, 3 do
		local ok, value = pcall(function()
			return self.store:UpdateAsync("u:" .. profile.player.UserId, function(old)
				if typeof(old) ~= "table" or typeof(old.Session) ~= "table" or old.Session.Id ~= self.sessionId then return nil end
				local data = cleanData(snapshot)
				if not release then data.Session = { Id = self.sessionId, Expires = os.time() + 180 } end
				return data
			end)
		end)
		if ok and typeof(value) == "table" then saved = true break end
		if ok and value == nil then
			profile.ready = false
			self:_sync(profile)
			break
		end
		if attempt < 3 then task.wait(attempt) end
	end
	profile.saving = false
	if saved and release then profile.released = true end
	if saved and version == profile.version then profile.dirty = false end
	if not saved then warn("Playground profile save is pending for user " .. profile.player.UserId) end
	return saved
end

function Economy:_touch(profile)
	profile.version += 1
	profile.dirty = true
	self:_sync(profile)
end

function Economy:_clearAppearance(profile)
	if profile.pet then profile.pet:Destroy() profile.pet = nil end
	local character = profile.player.Character
	if character then
		for _, name in ipairs({ "PCOutline", "PCTrail", "PCTrailTop", "PCTrailBottom" }) do
			local object = character:FindFirstChild(name, true)
			if object then object:Destroy() end
		end
	end
end

function Economy:_applyAppearance(profile)
	self:_clearAppearance(profile)
	local character = profile.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not profile.ready or profile.closed then return end
	local equipped = profile.data.Equipped
	if equipped.Pet then
		local asset = self.assets:FindFirstChild(equipped.Pet)
		if asset then
			profile.pet = asset:Clone()
			profile.pet.Name = "Pet_" .. profile.player.UserId
			profile.pet.Parent = self.effects
			profile.pet:PivotTo(root.CFrame * CFrame.new(3, 0.5, 3))
		end
	end
	local outlineItem = Catalog.ById[equipped.Highlight]
	if outlineItem then
		local outline = Instance.new("Highlight")
		outline.Name = "PCOutline"
		outline.Adornee = character
		outline.FillTransparency = 1
		outline.OutlineTransparency = 0
		outline.OutlineColor = outlineItem.color
		outline.Enabled = not (profile.player:GetAttribute("BBParticipating") == true or (profile.player:GetAttribute("TGParticipating") == true or profile.player:GetAttribute("MDParticipating") == true))
		outline.DepthMode = Enum.HighlightDepthMode.Occluded
		outline.Parent = character
	end
	local trailItem = Catalog.ById[equipped.Trail]
	if trailItem then
		local top = Instance.new("Attachment")
		top.Name = "PCTrailTop"
		top.Position = Vector3.new(0, 0.6, 1)
		top.Parent = root
		local bottom = Instance.new("Attachment")
		bottom.Name = "PCTrailBottom"
		bottom.Position = Vector3.new(0, -0.8, 1)
		bottom.Parent = root
		local trail = Instance.new("Trail")
		trail.Name = "PCTrail"
		trail.Attachment0 = top
		trail.Attachment1 = bottom
		trail.Color = equipped.Trail == "RainbowTrail" and ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 93, 124)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 219, 64)),
			ColorSequenceKeypoint.new(0.67, Color3.fromRGB(75, 213, 178)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(118, 126, 255)),
		}) or ColorSequence.new(trailItem.color, Color3.fromRGB(255, 94, 139))
		trail.Lifetime = 0.55
		trail.MinLength = 0.2
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.FaceCamera = true
		trail.Parent = root
	end
end

function Economy:_bindPlayer(player)
	if self.profiles[player] then return end
	local profile = { player = player, data = cleanData(nil), ready = false, version = 0, pickups = {}, connections = {}, lastMutation = -math.huge, lastStatus = -math.huge, lastExpression = -math.huge }
	self.profiles[player] = profile
	local board = player:FindFirstChild("leaderstats")
	if not board then board = Instance.new("Folder") board.Name = "leaderstats" board.Parent = player end
	for _, name in ipairs({ "Wins", "Coins", "Level" }) do
		if not board:FindFirstChild(name) then local counter = Instance.new("IntValue") counter.Name = name counter.Parent = board end
	end
	self:_sync(profile)
	table.insert(profile.connections, player.CharacterAdded:Connect(function(character)
		task.spawn(function()
			character:WaitForChild("HumanoidRootPart", 10)
			if self.profiles[player] == profile and character == player.Character and not profile.closed then self:_applyAppearance(profile) end
		end)
	end))
	task.spawn(function()
		while self.running and self.profiles[player] == profile and player.Parent == Players and not profile.ready do
			if self:_claim(profile) then
				if self.profiles[player] == profile and player.Parent == Players and not profile.closed then
					self:_sync(profile)
					self:_applyAppearance(profile)
				else
					self:_save(profile, true)
				end
				break
			end
			task.wait(10)
		end
	end)
end

function Economy:Status(player, ok, message)
	local profile = self.profiles[player]
	local xp = profile and integer(profile.data.XP, 0) or 0
	local level, levelXP, requiredXP = self:LevelProgress(xp)
	return { ok = ok, message = message or "", coins = profile and profile.data.Coins or 0, xp = xp, level = level, levelXP = levelXP, levelXPRequired = requiredXP, owned = profile and table.clone(profile.data.Owned) or {}, equipped = profile and table.clone(profile.data.Equipped) or {}, ready = profile and profile.ready == true }
end

function Economy:Handle(player, action, id)
	local profile = self.profiles[player]
	if not profile or profile.closed or not profile.ready then return self:Status(player, false, "Your items are still loading.") end
	if typeof(action) ~= "string" or not actions[action] then return self:Status(player, false, "Unknown shop control.") end
	local now = os.clock()
	local key = action == "GetStatus" and "lastStatus" or "lastMutation"
	if now - profile[key] < (action == "GetStatus" and 0.1 or 0.35) then return self:Status(player, false, "Please wait a moment.") end
	profile[key] = now
	if action == "GetStatus" then return self:Status(player, true) end
	if action == "Unequip" then
		if typeof(id) ~= "string" or not slots[id] then return self:Status(player, false, "Choose an item first.") end
		profile.data.Equipped[id] = nil
		self:_touch(profile)
		self:_applyAppearance(profile)
		return self:Status(player, true, "Unequipped.")
	end
	local item = typeof(id) == "string" and Catalog.ById[id]
	if not item or item.available == false then return self:Status(player, false, "This item is coming soon.") end
	if action == "Buy" then
		if profile.data.Owned[id] then return self:Status(player, false, "You already own this.") end
		if profile.data.Coins < item.price then return self:Status(player, false, "Collect a few more coins first.") end
		profile.data.Coins -= item.price
		profile.data.Owned[id] = true
		profile.data.Equipped[item.slot] = id
		self:_touch(profile)
		self:_applyAppearance(profile)
		return self:Status(player, true, item.name .. " is yours!")
	end
	if not profile.data.Owned[id] then return self:Status(player, false, "You don't own this yet.") end
	if action == "Equip" then
		profile.data.Equipped[item.slot] = id
		self:_touch(profile)
		self:_applyAppearance(profile)
		return self:Status(player, true, "Equipped " .. item.name .. ".")
	end
	if action == "UseEmote" or action == "UseEmoji" then
		if now - profile.lastExpression < 4 then return self:Status(player, false, "Give it a moment.") end
		if player:GetAttribute("BBParticipating") or (player:GetAttribute("TGParticipating") or player:GetAttribute("MDParticipating")) then return self:Status(player, false, "Try this between rounds.") end
		profile.lastExpression = now
		if action == "UseEmote" then
			if item.slot ~= "Emote" then return self:Status(player, false, "Choose an emote.") end
			player:SetAttribute("PCEmoteAction", id)
			player:SetAttribute("PCEmoteUntil", workspace:GetServerTimeNow() + 2.4)
			local response = self:Status(player, true)
			return response
		end
		if item.slot ~= "Emoji" then return self:Status(player, false, "Choose an emoji.") end
		local head = player.Character and player.Character:FindFirstChild("Head")
		if not head then return self:Status(player, false, "Your character is loading.") end
		local bubble = Instance.new("BillboardGui")
		bubble.Name = "PCEmojiBubble"
		bubble.Size = UDim2.fromOffset(80, 80)
		bubble.StudsOffset = Vector3.new(0, 3.5, 0)
		bubble.AlwaysOnTop = false
		bubble.Adornee = head
		bubble.Parent = head
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Text = item.emoji
		text.TextColor3 = item.color
		text.TextStrokeColor3 = ink
		text.TextStrokeTransparency = 0
		text.TextScaled = true
		text.Parent = bubble
		Debris:AddItem(bubble, 2.5)
		return self:Status(player, true)
	end
	return self:Status(player, false, "Unknown shop control.")
end

function Economy:_publishReward(profile, coins, xp, won, roundReward)
	local player = profile.player
	profile.rewardSerial = (profile.rewardSerial or 0) + 1
	player:SetAttribute("PCRewardCoins", coins)
	player:SetAttribute("PCRewardXP", xp)
	player:SetAttribute("PCRewardWon", won == true)
	local message = "+" .. coins .. " coins"
	if roundReward then message ..= " · +" .. xp .. " XP · " .. (won and "Round won!" or "Round complete") end
	player:SetAttribute("PCRewardText", message)
	player:SetAttribute("PCRewardSerial", profile.rewardSerial)
	player:SetAttribute("PCRewardAt", workspace:GetServerTimeNow())
end

function Economy:_profileByUserId(id)
	for player, profile in pairs(self.profiles) do
		if player.UserId == id and player.Parent == Players then return profile end
	end
	return nil
end

function Economy:AwardRound(key, winnerIds, practice, participantIds, rewardOptions)
	if practice or typeof(key) ~= "string" or #key > 96 or self.awarded[key] or typeof(winnerIds) ~= "table" or typeof(participantIds) ~= "table" then return 0 end
	local participants, winners = {}, {}
	local function validId(id) return typeof(id) == "number" and id == id and id % 1 == 0 and math.abs(id) <= 1000000000000 end
	for _, id in ipairs(participantIds) do if validId(id) then participants[id] = true end end
	for _, id in ipairs(winnerIds) do if validId(id) and participants[id] then winners[id] = true end end
	if next(participants) == nil then return 0 end
	self.awarded[key] = true
	local rewarded = 0
	for id in pairs(participants) do
		local profile = self:_profileByUserId(id)
		if profile and profile.ready and not profile.closed and not profile.released then
			local won = winners[id] == true
			local coins = self:_setting(won and "WinnerCoins" or "LoserCoins", won and 150 or 50)
			local xp = self:_setting(won and "WinnerXP" or "LoserXP", 50)
			if typeof(rewardOptions) == "table" then xp = integer(won and rewardOptions.winnerXP or rewardOptions.loserXP, xp) end
			local beforeCoins = integer(profile.data.Coins, 0)
			local beforeXP = integer(profile.data.XP, 0)
			profile.data.Coins = integer(beforeCoins + coins, 0)
			profile.data.XP = integer(beforeXP + xp, 0)
			if won then profile.data.Wins = integer(profile.data.Wins + 1, 0) end
			self:_touch(profile)
			self:_publishReward(profile, profile.data.Coins - beforeCoins, profile.data.XP - beforeXP, won, true)
			rewarded += 1
		end
	end
	return rewarded
end

function Economy:_inside(position)
	local point = self.bounds.CFrame:PointToObjectSpace(position)
	local half = self.bounds.Size / 2
	return math.abs(point.X) <= half.X and math.abs(point.Y) <= half.Y and math.abs(point.Z) <= half.Z
end

function Economy:_buildCoins()
	for _, marker in ipairs(self.lobby.Gameplay.CoinSpawns:GetChildren()) do
		if marker:IsA("BasePart") then
			local coin = Instance.new("Part")
			coin.Name = "Coin_" .. marker.Name
			coin.Shape = Enum.PartType.Cylinder
			coin.Size = Vector3.new(0.65, 2.8, 2.8)
			coin.Color = Color3.fromRGB(255, 207, 59)
			coin.Material = Enum.Material.SmoothPlastic
			coin.Anchored = true
			coin.CanCollide = false
			coin.CanTouch = false
			coin.CanQuery = false
			coin.CFrame = marker.CFrame
			coin.Parent = self.effects
			table.insert(self.coins, {
				id = marker:GetAttribute("PickupId") or marker.Name,
				value = math.clamp(integer(marker:GetAttribute("Value"), 2), 1, 10),
				cooldown = math.clamp(integer(marker:GetAttribute("RespawnSeconds"), 45), 15, 300),
				marker = marker, visual = coin,
			})
		end
	end
end

function Economy:_tick(dt)
	self.elapsed += dt
	if self.elapsed < 0.15 then return end
	self.elapsed = 0
	local now = workspace:GetServerTimeNow()
	for _, coin in ipairs(self.coins) do
		coin.visual.CFrame = coin.marker.CFrame * CFrame.new(0, math.sin(now * 2 + #coin.id) * 0.3, 0) * CFrame.Angles(0, now, 0)
	end
	for player, profile in pairs(self.profiles) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and profile.ready and not profile.closed then
			local participating = player:GetAttribute("BBParticipating") == true or (player:GetAttribute("TGParticipating") == true or player:GetAttribute("MDParticipating") == true)
			local outline = character:FindFirstChild("PCOutline")
			if outline then
				outline.Enabled = not participating
				if profile.data.Equipped.Highlight == "RainbowOutline" then outline.OutlineColor = Color3.fromHSV(now * 0.12 % 1, 0.72, 1) end
			end
			if profile.pet and profile.pet.Parent then
				local target = root.CFrame * CFrame.new(3.4, math.sin(now * 3) * 0.3, 3)
				profile.pet:PivotTo(profile.pet:GetPivot():Lerp(target, 0.55))
			end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not participating and humanoid and humanoid.Health > 0 and self:_inside(root.Position) then
				for _, coin in ipairs(self.coins) do
					if (root.Position - coin.marker.Position).Magnitude <= 5.5 and now - (profile.pickups[coin.id] or -math.huge) >= coin.cooldown then
						profile.pickups[coin.id] = now
						local beforeCoins = profile.data.Coins
						profile.data.Coins = integer(beforeCoins + coin.value, 0)
						self:_touch(profile)
						self:_publishReward(profile, profile.data.Coins - beforeCoins, 0, false, false)
					end
				end
			end
		end
	end
	if os.clock() - self.lastSave >= 60 then
		self.lastSave = os.clock()
		for _, profile in pairs(self.profiles) do task.spawn(function() self:_save(profile, false) end) end
	end
end

function Economy:Start()
	if self.running then return end
	self.running = true
	self:_buildCoins()
	local remote = ReplicatedStorage:WaitForChild("PlaygroundShopRequest")
	remote.OnServerInvoke = function(player, action, id) return self:Handle(player, action, id) end
	self.remote = remote
	table.insert(self.connections, Players.PlayerAdded:Connect(function(player) self:_bindPlayer(player) end))
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player)
		local profile = self.profiles[player]
		if not profile then return end
		profile.closed = true
		for _, connection in ipairs(profile.connections) do connection:Disconnect() end
		self:_clearAppearance(profile)
		self:_save(profile, true)
		self.profiles[player] = nil
	end))
	for _, player in ipairs(Players:GetPlayers()) do self:_bindPlayer(player) end
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt) self:_tick(dt) end))
	for _, attributeName in ipairs({"BaseLevelXP", "LevelXPStep"}) do
		table.insert(self.connections, self.lobby:GetAttributeChangedSignal(attributeName):Connect(function()
			for _, profile in pairs(self.profiles) do if not profile.closed then self:_sync(profile) end end
		end))
	end
	game:BindToClose(function()
		local pending = 0
		for _, profile in pairs(self.profiles) do
			profile.closed = true
			pending += 1
			task.spawn(function() self:_save(profile, true) pending -= 1 end)
		end
		local untilTime = os.clock() + 25
		while pending > 0 and os.clock() < untilTime do task.wait(0.1) end
	end)
end

function Economy:Stop()
	self.running = false
	for _, connection in ipairs(self.connections) do connection:Disconnect() end
	if self.remote then self.remote.OnServerInvoke = nil end
	for _, profile in pairs(self.profiles) do profile.closed = true end
	for _, profile in pairs(self.profiles) do
		for _, connection in ipairs(profile.connections) do connection:Disconnect() end
		self:_clearAppearance(profile)
		self:_save(profile, true)
	end
	self.effects:Destroy()
	table.clear(self.profiles)
end

Economy.CleanData = cleanData
Economy.CalculateLevelProgress = levelProgress
return Economy]====],after=[====[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Debris = game:GetService("Debris")
local Catalog = require(ReplicatedStorage:WaitForChild("PlaygroundCatalog"))

local Economy = {}
Economy.__index = Economy
local slots = { Pet = true, Emote = true, Emoji = true, Trail = true, Highlight = true, Gear = true }
local actions = { GetStatus = true, Buy = true, Equip = true, Unequip = true, UseEmote = true, UseEmoji = true }
local ink = Color3.fromRGB(24, 35, 62)

local function integer(value, fallback)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return fallback end
	return math.clamp(math.floor(value), 0, 1000000000)
end

local function timestamp(value)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return 0 end
	return math.clamp(math.floor(value), 0, 1000000000000)
end

local function levelProgress(xp, base, step)
	xp = integer(xp, 0)
	base = math.max(1, integer(base, 100))
	step = integer(step, 50)
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
	return completed + 1, xp - cost(completed), base + step * completed
end

local function cleanData(value)
	value = typeof(value) == "table" and value or {}
	local result = { Coins = integer(value.Coins, 0), Wins = integer(value.Wins, 0), XP = integer(value.XP, 0), Owned = {}, Equipped = {}, Version = 2 }
	if typeof(value.Owned) == "table" then
		for id, owned in pairs(value.Owned) do
			if typeof(id) == "string" and #id <= 48 and owned == true then result.Owned[id] = true end
		end
	end
	if typeof(value.Equipped) == "table" then
		for slot, id in pairs(value.Equipped) do
			local item = Catalog.ById[id]
			if slots[slot] and item and item.slot == slot and result.Owned[id] then result.Equipped[slot] = id end
		end
	end
	return result
end

function Economy:_setting(name, fallback)
	return integer(self.lobby:GetAttribute(name), fallback)
end

function Economy:LevelProgress(xp)
	return levelProgress(xp, self:_setting("BaseLevelXP", 200), self:_setting("LevelXPStep", 50))
end

function Economy.new(lobby, storeOverride, studioOverride)
	local self = setmetatable({}, Economy)
	self.lobby = lobby
	self.bounds = lobby.Gameplay.LobbyBounds
	self.profiles = {}
	self.connections = {}
	self.awarded = {}
	self.isStudio = studioOverride == nil and RunService:IsStudio() or studioOverride
	self.sessionId = game.JobId .. ":" .. HttpService:GenerateGUID(false)
	self.store = storeOverride
	if not self.isStudio and not self.store then
		local ok, store = pcall(function() return DataStoreService:GetDataStore("PlaygroundClassics_Profiles_v1") end)
		if ok then self.store = store end
	end
	self.sessionOnly = not self.isStudio and self.store == nil
	self.assets = ReplicatedStorage:WaitForChild("PlaygroundCosmeticAssets")
	self.effects = Instance.new("Folder")
	self.effects.Name = "PlaygroundCosmeticEffects"
	self.effects.Parent = workspace
	self.coins = {}
	self.running = false
	self.elapsed = 0
	self.lastSave = os.clock()
	return self
end

function Economy:_sync(profile)
	local player = profile.player
	profile.data.XP = integer(profile.data.XP, 0)
	local level, levelXP, requiredXP = self:LevelProgress(profile.data.XP)
	player:SetAttribute("PCCoins", profile.data.Coins)
	player:SetAttribute("PCWins", profile.data.Wins)
	player:SetAttribute("PCXP", profile.data.XP)
	player:SetAttribute("PCLevel", level)
	player:SetAttribute("PCLevelXP", levelXP)
	player:SetAttribute("PCLevelXPRequired", requiredXP)
	player:SetAttribute("PCDataReady", profile.ready == true)
	player:SetAttribute("PCDataMode", self.isStudio and "Studio" or self.sessionOnly and "Session" or "Persistent")
	for slot in pairs(slots) do player:SetAttribute("PC" .. slot, profile.data.Equipped[slot] or "") end
	local board = player:FindFirstChild("leaderstats")
	if board then
		local wins = board:FindFirstChild("Wins")
		local coins = board:FindFirstChild("Coins")
		local levelCounter = board:FindFirstChild("Level")
		if wins then wins.Value = profile.data.Wins end
		if coins then coins.Value = profile.data.Coins end
		if levelCounter then levelCounter.Value = level end
	end
end

function Economy:_publishLeaderboard(userId, snapshot)
	if not self.leaderboards then return end
	local ok, err = pcall(function() self.leaderboards:PublishSaved(userId, snapshot) end)
	if not ok then warn("Leaderboard update delayed: " .. tostring(err)) end
end

function Economy:_claim(profile)
	if self.isStudio or self.sessionOnly then
		profile.data = cleanData({ Coins = self.isStudio and 150 or 0 })
		profile.ready = true
		return true
	end
	local ok, value = pcall(function()
		return self.store:UpdateAsync("u:" .. profile.player.UserId, function(old)
			old = typeof(old) == "table" and old or {}
			local lease = old.Session
			if typeof(lease) == "table" and lease.Id ~= self.sessionId and timestamp(lease.Expires) > os.time() then return nil end
			local data = cleanData(old)
			data.Session = { Id = self.sessionId, Expires = os.time() + 180 }
			return data
		end)
	end)
	if ok and typeof(value) == "table" and value.Session and value.Session.Id == self.sessionId then
		profile.data = cleanData(value)
		profile.ready = true
		self:_publishLeaderboard(profile.player.UserId, profile.data)
		return true
	end
	return false
end

function Economy:_save(profile, release)
	if self.isStudio or self.sessionOnly or not profile.ready or profile.released then return true end
	local untilTime = os.clock() + 8
	while profile.saving and os.clock() < untilTime do task.wait(0.1) end
	if profile.released then return true end
	if profile.saving then return false end
	profile.saving = true
	local version = profile.version
	local snapshot = cleanData(profile.data)
	local saved = false
	for attempt = 1, 3 do
		local ok, value = pcall(function()
			return self.store:UpdateAsync("u:" .. profile.player.UserId, function(old)
				if typeof(old) ~= "table" or typeof(old.Session) ~= "table" or old.Session.Id ~= self.sessionId then return nil end
				local data = cleanData(snapshot)
				if not release then data.Session = { Id = self.sessionId, Expires = os.time() + 180 } end
				return data
			end)
		end)
		if ok and typeof(value) == "table" then saved = true break end
		if ok and value == nil then
			profile.ready = false
			self:_sync(profile)
			break
		end
		if attempt < 3 then task.wait(attempt) end
	end
	profile.saving = false
	if saved and release then profile.released = true end
	if saved and version == profile.version then profile.dirty = false end
	if saved then self:_publishLeaderboard(profile.player.UserId, snapshot) end
	if not saved then warn("Playground profile save is pending for user " .. profile.player.UserId) end
	return saved
end

function Economy:_touch(profile)
	profile.version += 1
	profile.dirty = true
	self:_sync(profile)
end

function Economy:_clearAppearance(profile)
	if profile.pet then profile.pet:Destroy() profile.pet = nil end
	local character = profile.player.Character
	if character then
		for _, name in ipairs({ "PCOutline", "PCTrail", "PCTrailTop", "PCTrailBottom" }) do
			local object = character:FindFirstChild(name, true)
			if object then object:Destroy() end
		end
	end
end

function Economy:_applyAppearance(profile)
	self:_clearAppearance(profile)
	local character = profile.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not profile.ready or profile.closed then return end
	local equipped = profile.data.Equipped
	if equipped.Pet then
		local asset = self.assets:FindFirstChild(equipped.Pet)
		if asset then
			profile.pet = asset:Clone()
			profile.pet.Name = "Pet_" .. profile.player.UserId
			profile.pet.Parent = self.effects
			profile.pet:PivotTo(root.CFrame * CFrame.new(3, 0.5, 3))
		end
	end
	local outlineItem = Catalog.ById[equipped.Highlight]
	if outlineItem then
		local outline = Instance.new("Highlight")
		outline.Name = "PCOutline"
		outline.Adornee = character
		outline.FillTransparency = 1
		outline.OutlineTransparency = 0
		outline.OutlineColor = outlineItem.color
		outline.Enabled = not (profile.player:GetAttribute("BBParticipating") == true or (profile.player:GetAttribute("TGParticipating") == true or profile.player:GetAttribute("MDParticipating") == true))
		outline.DepthMode = Enum.HighlightDepthMode.Occluded
		outline.Parent = character
	end
	local trailItem = Catalog.ById[equipped.Trail]
	if trailItem then
		local top = Instance.new("Attachment")
		top.Name = "PCTrailTop"
		top.Position = Vector3.new(0, 0.6, 1)
		top.Parent = root
		local bottom = Instance.new("Attachment")
		bottom.Name = "PCTrailBottom"
		bottom.Position = Vector3.new(0, -0.8, 1)
		bottom.Parent = root
		local trail = Instance.new("Trail")
		trail.Name = "PCTrail"
		trail.Attachment0 = top
		trail.Attachment1 = bottom
		trail.Color = equipped.Trail == "RainbowTrail" and ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 93, 124)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 219, 64)),
			ColorSequenceKeypoint.new(0.67, Color3.fromRGB(75, 213, 178)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(118, 126, 255)),
		}) or ColorSequence.new(trailItem.color, Color3.fromRGB(255, 94, 139))
		trail.Lifetime = 0.55
		trail.MinLength = 0.2
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.FaceCamera = true
		trail.Parent = root
	end
end

function Economy:_bindPlayer(player)
	if self.profiles[player] then return end
	local profile = { player = player, data = cleanData(nil), ready = false, version = 0, pickups = {}, connections = {}, lastMutation = -math.huge, lastStatus = -math.huge, lastExpression = -math.huge }
	self.profiles[player] = profile
	local board = player:FindFirstChild("leaderstats")
	if not board then board = Instance.new("Folder") board.Name = "leaderstats" board.Parent = player end
	for _, name in ipairs({ "Wins", "Coins", "Level" }) do
		if not board:FindFirstChild(name) then local counter = Instance.new("IntValue") counter.Name = name counter.Parent = board end
	end
	self:_sync(profile)
	table.insert(profile.connections, player.CharacterAdded:Connect(function(character)
		task.spawn(function()
			character:WaitForChild("HumanoidRootPart", 10)
			if self.profiles[player] == profile and character == player.Character and not profile.closed then self:_applyAppearance(profile) end
		end)
	end))
	task.spawn(function()
		while self.running and self.profiles[player] == profile and player.Parent == Players and not profile.ready do
			if self:_claim(profile) then
				if self.profiles[player] == profile and player.Parent == Players and not profile.closed then
					self:_sync(profile)
					self:_applyAppearance(profile)
				else
					self:_save(profile, true)
				end
				break
			end
			task.wait(10)
		end
	end)
end

function Economy:Status(player, ok, message)
	local profile = self.profiles[player]
	local xp = profile and integer(profile.data.XP, 0) or 0
	local level, levelXP, requiredXP = self:LevelProgress(xp)
	return { ok = ok, message = message or "", coins = profile and profile.data.Coins or 0, xp = xp, level = level, levelXP = levelXP, levelXPRequired = requiredXP, owned = profile and table.clone(profile.data.Owned) or {}, equipped = profile and table.clone(profile.data.Equipped) or {}, ready = profile and profile.ready == true }
end

function Economy:Handle(player, action, id)
	local profile = self.profiles[player]
	if not profile or profile.closed or not profile.ready then return self:Status(player, false, "Your items are still loading.") end
	if typeof(action) ~= "string" or not actions[action] then return self:Status(player, false, "Unknown shop control.") end
	local now = os.clock()
	local key = action == "GetStatus" and "lastStatus" or "lastMutation"
	if now - profile[key] < (action == "GetStatus" and 0.1 or 0.35) then return self:Status(player, false, "Please wait a moment.") end
	profile[key] = now
	if action == "GetStatus" then return self:Status(player, true) end
	if action == "Unequip" then
		if typeof(id) ~= "string" or not slots[id] then return self:Status(player, false, "Choose an item first.") end
		profile.data.Equipped[id] = nil
		self:_touch(profile)
		self:_applyAppearance(profile)
		return self:Status(player, true, "Unequipped.")
	end
	local item = typeof(id) == "string" and Catalog.ById[id]
	if not item or item.available == false then return self:Status(player, false, "This item is coming soon.") end
	if action == "Buy" then
		if profile.data.Owned[id] then return self:Status(player, false, "You already own this.") end
		if profile.data.Coins < item.price then return self:Status(player, false, "Collect a few more coins first.") end
		profile.data.Coins -= item.price
		profile.data.Owned[id] = true
		profile.data.Equipped[item.slot] = id
		self:_touch(profile)
		self:_applyAppearance(profile)
		return self:Status(player, true, item.name .. " is yours!")
	end
	if not profile.data.Owned[id] then return self:Status(player, false, "You don't own this yet.") end
	if action == "Equip" then
		profile.data.Equipped[item.slot] = id
		self:_touch(profile)
		self:_applyAppearance(profile)
		return self:Status(player, true, "Equipped " .. item.name .. ".")
	end
	if action == "UseEmote" or action == "UseEmoji" then
		if now - profile.lastExpression < 4 then return self:Status(player, false, "Give it a moment.") end
		if player:GetAttribute("BBParticipating") or (player:GetAttribute("TGParticipating") or player:GetAttribute("MDParticipating")) then return self:Status(player, false, "Try this between rounds.") end
		profile.lastExpression = now
		if action == "UseEmote" then
			if item.slot ~= "Emote" then return self:Status(player, false, "Choose an emote.") end
			player:SetAttribute("PCEmoteAction", id)
			player:SetAttribute("PCEmoteUntil", workspace:GetServerTimeNow() + 2.4)
			local response = self:Status(player, true)
			return response
		end
		if item.slot ~= "Emoji" then return self:Status(player, false, "Choose an emoji.") end
		local head = player.Character and player.Character:FindFirstChild("Head")
		if not head then return self:Status(player, false, "Your character is loading.") end
		local bubble = Instance.new("BillboardGui")
		bubble.Name = "PCEmojiBubble"
		bubble.Size = UDim2.fromOffset(80, 80)
		bubble.StudsOffset = Vector3.new(0, 3.5, 0)
		bubble.AlwaysOnTop = false
		bubble.Adornee = head
		bubble.Parent = head
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Text = item.emoji
		text.TextColor3 = item.color
		text.TextStrokeColor3 = ink
		text.TextStrokeTransparency = 0
		text.TextScaled = true
		text.Parent = bubble
		Debris:AddItem(bubble, 2.5)
		return self:Status(player, true)
	end
	return self:Status(player, false, "Unknown shop control.")
end

function Economy:_publishReward(profile, coins, xp, won, roundReward)
	local player = profile.player
	profile.rewardSerial = (profile.rewardSerial or 0) + 1
	player:SetAttribute("PCRewardCoins", coins)
	player:SetAttribute("PCRewardXP", xp)
	player:SetAttribute("PCRewardWon", won == true)
	local message = "+" .. coins .. " coins"
	if roundReward then message ..= " · +" .. xp .. " XP · " .. (won and "Round won!" or "Round complete") end
	player:SetAttribute("PCRewardText", message)
	player:SetAttribute("PCRewardSerial", profile.rewardSerial)
	player:SetAttribute("PCRewardAt", workspace:GetServerTimeNow())
end

function Economy:_profileByUserId(id)
	for player, profile in pairs(self.profiles) do
		if player.UserId == id and player.Parent == Players then return profile end
	end
	return nil
end

function Economy:AwardRound(key, winnerIds, practice, participantIds, rewardOptions)
	if practice or typeof(key) ~= "string" or #key > 96 or self.awarded[key] or typeof(winnerIds) ~= "table" or typeof(participantIds) ~= "table" then return 0 end
	local participants, winners = {}, {}
	local function validId(id) return typeof(id) == "number" and id == id and id % 1 == 0 and math.abs(id) <= 1000000000000 end
	for _, id in ipairs(participantIds) do if validId(id) then participants[id] = true end end
	for _, id in ipairs(winnerIds) do if validId(id) and participants[id] then winners[id] = true end end
	if next(participants) == nil then return 0 end
	self.awarded[key] = true
	local rewarded = 0
	for id in pairs(participants) do
		local profile = self:_profileByUserId(id)
		if profile and profile.ready and not profile.closed and not profile.released then
			local won = winners[id] == true
			local coins = self:_setting(won and "WinnerCoins" or "LoserCoins", won and 150 or 50)
			local xp = self:_setting(won and "WinnerXP" or "LoserXP", 50)
			if typeof(rewardOptions) == "table" then xp = integer(won and rewardOptions.winnerXP or rewardOptions.loserXP, xp) end
			local beforeCoins = integer(profile.data.Coins, 0)
			local beforeXP = integer(profile.data.XP, 0)
			profile.data.Coins = integer(beforeCoins + coins, 0)
			profile.data.XP = integer(beforeXP + xp, 0)
			if won then profile.data.Wins = integer(profile.data.Wins + 1, 0) end
			self:_touch(profile)
			self:_publishReward(profile, profile.data.Coins - beforeCoins, profile.data.XP - beforeXP, won, true)
			rewarded += 1
		end
	end
	return rewarded
end

function Economy:_inside(position)
	local point = self.bounds.CFrame:PointToObjectSpace(position)
	local half = self.bounds.Size / 2
	return math.abs(point.X) <= half.X and math.abs(point.Y) <= half.Y and math.abs(point.Z) <= half.Z
end

function Economy:_buildCoins()
	for _, marker in ipairs(self.lobby.Gameplay.CoinSpawns:GetChildren()) do
		if marker:IsA("BasePart") then
			local coin = Instance.new("Part")
			coin.Name = "Coin_" .. marker.Name
			coin.Shape = Enum.PartType.Cylinder
			coin.Size = Vector3.new(0.65, 2.8, 2.8)
			coin.Color = Color3.fromRGB(255, 207, 59)
			coin.Material = Enum.Material.SmoothPlastic
			coin.Anchored = true
			coin.CanCollide = false
			coin.CanTouch = false
			coin.CanQuery = false
			coin.CFrame = marker.CFrame
			coin.Parent = self.effects
			table.insert(self.coins, {
				id = marker:GetAttribute("PickupId") or marker.Name,
				value = math.clamp(integer(marker:GetAttribute("Value"), 2), 1, 10),
				cooldown = math.clamp(integer(marker:GetAttribute("RespawnSeconds"), 45), 15, 300),
				marker = marker, visual = coin,
			})
		end
	end
end

function Economy:_tick(dt)
	self.elapsed += dt
	if self.elapsed < 0.15 then return end
	self.elapsed = 0
	local now = workspace:GetServerTimeNow()
	for _, coin in ipairs(self.coins) do
		coin.visual.CFrame = coin.marker.CFrame * CFrame.new(0, math.sin(now * 2 + #coin.id) * 0.3, 0) * CFrame.Angles(0, now, 0)
	end
	for player, profile in pairs(self.profiles) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and profile.ready and not profile.closed then
			local participating = player:GetAttribute("BBParticipating") == true or (player:GetAttribute("TGParticipating") == true or player:GetAttribute("MDParticipating") == true)
			local outline = character:FindFirstChild("PCOutline")
			if outline then
				outline.Enabled = not participating
				if profile.data.Equipped.Highlight == "RainbowOutline" then outline.OutlineColor = Color3.fromHSV(now * 0.12 % 1, 0.72, 1) end
			end
			if profile.pet and profile.pet.Parent then
				local target = root.CFrame * CFrame.new(3.4, math.sin(now * 3) * 0.3, 3)
				profile.pet:PivotTo(profile.pet:GetPivot():Lerp(target, 0.55))
			end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not participating and humanoid and humanoid.Health > 0 and self:_inside(root.Position) then
				for _, coin in ipairs(self.coins) do
					if (root.Position - coin.marker.Position).Magnitude <= 5.5 and now - (profile.pickups[coin.id] or -math.huge) >= coin.cooldown then
						profile.pickups[coin.id] = now
						local beforeCoins = profile.data.Coins
						profile.data.Coins = integer(beforeCoins + coin.value, 0)
						self:_touch(profile)
						self:_publishReward(profile, profile.data.Coins - beforeCoins, 0, false, false)
					end
				end
			end
		end
	end
	if os.clock() - self.lastSave >= 60 then
		self.lastSave = os.clock()
		for _, profile in pairs(self.profiles) do task.spawn(function() self:_save(profile, false) end) end
	end
end

function Economy:Start()
	if self.running then return end
	self.running = true
	self:_buildCoins()
	local remote = ReplicatedStorage:WaitForChild("PlaygroundShopRequest")
	remote.OnServerInvoke = function(player, action, id) return self:Handle(player, action, id) end
	self.remote = remote
	table.insert(self.connections, Players.PlayerAdded:Connect(function(player) self:_bindPlayer(player) end))
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player)
		local profile = self.profiles[player]
		if not profile then return end
		profile.closed = true
		for _, connection in ipairs(profile.connections) do connection:Disconnect() end
		self:_clearAppearance(profile)
		self:_save(profile, true)
		self.profiles[player] = nil
	end))
	for _, player in ipairs(Players:GetPlayers()) do self:_bindPlayer(player) end
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt) self:_tick(dt) end))
	for _, attributeName in ipairs({"BaseLevelXP", "LevelXPStep"}) do
		table.insert(self.connections, self.lobby:GetAttributeChangedSignal(attributeName):Connect(function()
			for _, profile in pairs(self.profiles) do if not profile.closed then self:_sync(profile) end end
		end))
	end
	game:BindToClose(function()
		local pending = 0
		for _, profile in pairs(self.profiles) do
			profile.closed = true
			pending += 1
			task.spawn(function() self:_save(profile, true) pending -= 1 end)
		end
		local untilTime = os.clock() + 25
		while pending > 0 and os.clock() < untilTime do task.wait(0.1) end
		if pending == 0 and self.leaderboards then
			pcall(function() self.leaderboards:Flush(2) end)
		end
	end)
end

function Economy:Stop()
	self.running = false
	for _, connection in ipairs(self.connections) do connection:Disconnect() end
	if self.remote then self.remote.OnServerInvoke = nil end
	for _, profile in pairs(self.profiles) do profile.closed = true end
	for _, profile in pairs(self.profiles) do
		for _, connection in ipairs(profile.connections) do connection:Disconnect() end
		self:_clearAppearance(profile)
		self:_save(profile, true)
	end
	self.effects:Destroy()
	table.clear(self.profiles)
end

Economy.CleanData = cleanData
Economy.CalculateLevelProgress = levelProgress
return Economy
]====]},
{name=[====[PlaygroundBootstrap]====],before=[====[local ServerScriptService = game:GetService("ServerScriptService")
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
economy:Start()
local coordinator = Coordinator.new({ BritishBulldog = britishBulldog, TagYoureIt = tag, StuckInTheMud = mud }, lobby, economy)
coordinator:Start()
local admin = Admin.Start(coordinator)
script:SetAttribute("Ready", true)]====],after=[====[local ServerScriptService = game:GetService("ServerScriptService")
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
		return Leaderboards.new(lobby):Start()
	end)
	if ok then
		economy.leaderboards = result
		script.Destroying:Connect(function() result:Stop() end)
	else
		warn("Lobby leaderboards could not start: " .. tostring(result))
	end
end
economy:Start()
local coordinator = Coordinator.new({ BritishBulldog = britishBulldog, TagYoureIt = tag, StuckInTheMud = mud }, lobby, economy)
coordinator:Start()
local admin = Admin.Start(coordinator)
script:SetAttribute("Ready", true)
]====]}}
local moduleSource=[====[local Players = game:GetService("Players")
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
]====]
local builderSource=[====[return function(parent, baseCFrame)
	assert(typeof(parent) == "Instance" and typeof(baseCFrame) == "CFrame", "Provide a lobby parent and floor CFrame")
	local existing = parent:FindFirstChild("Leaderboards")
	if existing then
		assert(existing:GetAttribute("PlaygroundLeaderboardVersion") == 1, "An unrelated Leaderboards object already exists")
		return existing
	end
	local ink = Color3.fromRGB(27, 42, 65)
	local cream = Color3.fromRGB(255, 246, 220)
	local gold = Color3.fromRGB(255, 202, 69)
	local cyan = Color3.fromRGB(67, 192, 242)
	local muted = Color3.fromRGB(91, 109, 125)
	local root = Instance.new("Model")
	root.Name = "Leaderboards"
	root:SetAttribute("PlaygroundLeaderboardVersion", 1)
	root:SetAttribute("PlaygroundManaged", true)
	root:SetAttribute("FrontDirection", "Local negative Z")

	local function make(class, name, owner, properties)
		local item = Instance.new(class)
		item.Name = name
		for key, value in pairs(properties or {}) do item[key] = value end
		item.Parent = owner
		return item
	end
	local function corner(owner, radius)
		make("UICorner", "Corner", owner, { CornerRadius = UDim.new(0, radius) })
	end
	local function stroke(owner, width, color)
		make("UIStroke", "Outline", owner, { Thickness = width, Color = color or ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	end
	local function label(owner, name, text, position, size, textSize, color)
		return make("TextLabel", name, owner, { Position = position, Size = size, BackgroundTransparency = 1, BorderSizePixel = 0, Font = Enum.Font.FredokaOne, Text = text, TextSize = textSize, TextColor3 = color or ink, TextTruncate = Enum.TextTruncate.AtEnd })
	end
	local function part(owner, name, size, frame, color)
		return make("Part", name, owner, { Size = size, CFrame = frame, Color = color, Anchored = true, CanCollide = true, CanTouch = false, CanQuery = true, Material = Enum.Material.SmoothPlastic, TopSurface = Enum.SurfaceType.Studs, BottomSurface = Enum.SurfaceType.Smooth })
	end
	for index, info in ipairs({
		{ name = "HighestLevel", title = "HIGHEST LEVEL", accent = cyan, stat = "XP", note = "LEVEL · TOTAL XP BREAKS TIES", symbol = "★" },
		{ name = "MostWins", title = "MOST WINS", accent = gold, stat = "Wins", note = "WINS ACROSS ALL THREE GAMES", symbol = "★" },
	}) do
		local model = make("Model", info.name, root)
		model:SetAttribute("LeaderboardStat", info.stat)
		local frame = baseCFrame * CFrame.new((index == 1 and -1 or 1) * 8.9, 0, 0)
		part(model, "BaseOutline", Vector3.new(17, 0.7, 5.2), frame * CFrame.new(0, 0.35, 0), ink)
		part(model, "Base", Vector3.new(16.4, 0.6, 4.6), frame * CFrame.new(0, 0.85, 0), info.accent)
		for _, side in ipairs({-1, 1}) do
			part(model, "Post" .. side, Vector3.new(1.1, 8.6, 1.3), frame * CFrame.new(side * 5.8, 5.1, 0.4), ink)
			part(model, "PostInset" .. side, Vector3.new(0.55, 7.6, 0.16), frame * CFrame.new(side * 5.8, 5.2, -0.35), info.accent)
		end
		part(model, "BoardOutline", Vector3.new(15.8, 21.1, 1.25), frame * CFrame.new(0, 14.15, 0), ink)
		part(model, "BoardInset", Vector3.new(15.25, 20.55, 0.5), frame * CFrame.new(0, 14.15, -0.66), info.accent)
		local face = part(model, "Face", Vector3.new(14.7, 20.05, 0.18), frame * CFrame.new(0, 14.15, -0.99), cream)
		part(model, "TopLip", Vector3.new(16.25, 0.55, 1.7), frame * CFrame.new(0, 24.9, -0.15), ink)
		part(model, "TopHighlight", Vector3.new(15.75, 0.22, 1.25), frame * CFrame.new(0, 25.27, -0.15), info.accent)
		for _, side in ipairs({-1, 1}) do
			local pin = part(model, "CornerPin" .. side, Vector3.new(0.34, 0.34, 0.18), frame * CFrame.new(side * 7.35, 24.1, -1.16), ink)
			pin.Shape = Enum.PartType.Ball
		end
		local gui = make("SurfaceGui", "Display", face, { Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.FixedSize, CanvasSize = Vector2.new(720, 1000), LightInfluence = 0, AlwaysOnTop = false, MaxDistance = 180, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
		local header = make("Frame", "Header", gui, { Position = UDim2.fromOffset(18, 18), Size = UDim2.fromOffset(684, 128), BackgroundColor3 = info.accent, BorderSizePixel = 0 })
		corner(header, 22)
		stroke(header, 4)
		label(header, "Star", info.symbol, UDim2.fromOffset(16, 14), UDim2.fromOffset(62, 62), 58, ink)
		label(header, "Title", info.title, UDim2.fromOffset(79, 14), UDim2.fromOffset(585, 62), 46, ink)
		label(header, "Subtitle", "ALL TIME · TOP 10", UDim2.fromOffset(20, 82), UDim2.fromOffset(644, 28), 23, ink)
		local body = make("Frame", "Body", gui, { Position = UDim2.fromOffset(24, 174), Size = UDim2.fromOffset(672, 742), BackgroundTransparency = 1, BorderSizePixel = 0 })
		local templates = make("Folder", "Templates", gui)
		local row = make("Frame", "RowTemplate", templates, { Size = UDim2.fromOffset(672, 67), BackgroundColor3 = Color3.fromRGB(248, 236, 207), BorderSizePixel = 0, Visible = false })
		corner(row, 13)
		stroke(row, 2, Color3.fromRGB(209, 197, 177))
		local badge = make("Frame", "RankBadge", row, { Position = UDim2.fromOffset(8, 10), Size = UDim2.fromOffset(47, 47), BackgroundColor3 = ink, BorderSizePixel = 0 })
		corner(badge, 12)
		label(row, "Rank", "1", UDim2.fromOffset(8, 10), UDim2.fromOffset(47, 47), 30, cream)
		local avatar = make("ImageLabel", "Avatar", row, { Position = UDim2.fromOffset(69, 7), Size = UDim2.fromOffset(53, 53), BackgroundColor3 = Color3.fromRGB(227, 232, 226), BorderSizePixel = 0, Image = "", ScaleType = Enum.ScaleType.Crop })
		corner(avatar, 13)
		stroke(avatar, 2, ink)
		label(avatar, "Placeholder", "?", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 29, muted)
		local name = label(row, "PlayerName", "Player", UDim2.fromOffset(137, 6), UDim2.fromOffset(331, 55), 30, ink)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local value = label(row, "Value", "—", UDim2.fromOffset(476, 6), UDim2.fromOffset(178, 55), 32, ink)
		value.TextXAlignment = Enum.TextXAlignment.Right
		value.TextScaled = true
		make("UITextSizeConstraint", "TextSize", value, { MinTextSize = 14, MaxTextSize = 32 })
		for rank = 1, 10 do
			local copy = row:Clone()
			copy.Name = string.format("Row%02d", rank)
			copy.Position = UDim2.fromOffset(0, (rank - 1) * 74)
			copy.Rank.Text = tostring(rank)
			if rank <= 3 then
				copy.RankBadge.BackgroundColor3 = rank == 1 and gold or rank == 2 and Color3.fromRGB(190, 214, 228) or Color3.fromRGB(218, 158, 113)
				copy.Rank.TextColor3 = ink
			end
			copy.Parent = body
		end
		local empty = label(gui, "Empty", "Scores appear when the game starts", UDim2.fromOffset(60, 405), UDim2.fromOffset(600, 150), 36, muted)
		empty.TextWrapped = true
		label(gui, "Status", "GLOBAL · ALL TIME", UDim2.fromOffset(24, 927), UDim2.fromOffset(672, 25), 23, ink)
		label(gui, "Footnote", info.note, UDim2.fromOffset(24, 960), UDim2.fromOffset(672, 22), 18, muted)
	end
	root.Parent = parent
	return root
end
]====]
local function normalize(s) return (s:gsub("\r\n","\n"):gsub("\n+$","")) end
for _,entry in ipairs(entries) do
 entry.target=assert(server:FindFirstChild(entry.name),entry.name)
 assert(normalize(entry.target.Source)==normalize(entry.before),"Source changed since snapshot: "..entry.name)
 local compiled,err=loadstring(entry.after,entry.name)
 assert(compiled,err)
 entry.capabilities=entry.target.Capabilities
end
local compiledModule,moduleError=loadstring(moduleSource,"PlaygroundLeaderboardService")
assert(compiledModule,moduleError)
local builder,builderError=loadstring(builderSource,"BuildLeaderboards")
assert(builder,builderError)
local stage=Instance.new("Folder")
local boards=builder()(stage,CFrame.new(-12,4,-82)*CFrame.Angles(0,math.pi,0))
assert(#boards:GetChildren()==2,"Expected two authored boards")
local backupName="PlaygroundLeaderboardsBackup20261004"
assert(not storage:FindFirstChild(backupName),"Backup already exists")
local backup=Instance.new("Folder")
backup.Name=backupName
backup.Parent=storage
for _,entry in ipairs(entries) do
 local copy=entry.target:Clone()
 copy.Name=entry.name
 if copy:IsA("BaseScript") then copy.Disabled=true end
 copy.Parent=backup
end
local function addCapabilities(object, extra)
 local list={}
 for _,cap in ipairs(Enum.SecurityCapability:GetEnumItems()) do
  if object.Capabilities:Contains(SecurityCapabilities.new(cap)) or extra[cap.Name] then table.insert(list,cap) end
 end
 object.Capabilities=SecurityCapabilities.new(table.unpack(list))
end
local module=Instance.new("ModuleScript")
module.Name="PlaygroundLeaderboardService"
module.Sandboxed=true
module.Capabilities=SecurityCapabilities.new(Enum.SecurityCapability.RunServerScript,Enum.SecurityCapability.AccessOutsideWrite,Enum.SecurityCapability.Basic,Enum.SecurityCapability.DataStore,Enum.SecurityCapability.UI,Enum.SecurityCapability.Players)
module.Source=moduleSource
local editor=game:GetService("ScriptEditorService")
local written={}
local ok,err=pcall(function()
 addCapabilities(server.PlaygroundEconomyService,{DataStore=true})
 addCapabilities(server.PlaygroundBootstrap,{DataStore=true})
 for _,entry in ipairs(entries) do
  editor:UpdateSourceAsync(entry.target,function(current)
   assert(normalize(current)==normalize(entry.before),"Editor changed since snapshot: "..entry.name)
   return entry.after
  end)
  table.insert(written,entry)
 end
 module.Parent=server
 boards.Parent=lobby
end)
if not ok then
 for _,entry in ipairs(written) do editor:UpdateSourceAsync(entry.target,function() return entry.before end) end
 for _,entry in ipairs(entries) do entry.target.Capabilities=entry.capabilities end
 module:Destroy()
 boards:Destroy()
 stage:Destroy()
 error(err)
end
stage:Destroy()
local rows=0
for _,board in ipairs(boards:GetChildren()) do
 local gui=board.Face.Display
 for _,row in ipairs(gui.Body:GetChildren()) do if row:IsA("Frame") then rows+=1 end end
 assert(gui.Templates.RowTemplate.Visible==false,"Template should remain hidden")
end
for _,entry in ipairs(entries) do assert(normalize(entry.target.Source)==normalize(entry.after),"Readback mismatch") end
backup:SetAttribute("Purpose","Before lobby leaderboard persistence integration")
return game:GetService("HttpService"):JSONEncode({boards=boards:GetFullName(),rows=rows,newService=module:GetFullName(),backup=backup:GetFullName(),position={-12,4,-82},mode="Edit",playStarted=false,datastoreRequests=0,capabilities={economy=tostring(server.PlaygroundEconomyService.Capabilities),bootstrap=tostring(server.PlaygroundBootstrap.Capabilities),leaderboards=tostring(module.Capabilities)}})
