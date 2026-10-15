local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Debris = game:GetService("Debris")
local Catalog = require(ReplicatedStorage:WaitForChild("PlaygroundCatalog"))

local Economy = {}
Economy.__index = Economy
local slots = { Bat = true, Pet = true, Emote = true, Emoji = true, Trail = true, Highlight = true, Gear = true }
local actions = { RedeemCode = true, GetStatus = true, Buy = true, Equip = true, Unequip = true, SelectToy = true, UseEmote = true, StopEmote = true, UseEmoji = true }
local ink = Color3.fromRGB(24, 35, 62)
local games = { BritishBulldog = true, TagYoureIt = true, StuckInTheMud = true, HideAndSeek = true }
local gamePrefixes = { BB = "BritishBulldog", TAG = "TagYoureIt", MUD = "StuckInTheMud", HS = "HideAndSeek" }
local adminLimits = table.freeze({ coinsPerGrant = 1000000, levelsPerGrant = 100, maxLevel = 1000, maxCoins = 1000000000 })
local coinPickupAmount = 5
local maxToySlots = 4
local fishingCatchesPerDay = 3
local fishingBoostSeconds = 300

local function boundedInteger(value, minimum, maximum)
	return typeof(value) == "number" and value == value and value % 1 == 0 and value >= minimum and value <= maximum
end

local function integer(value, fallback)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return fallback end
	return math.clamp(math.floor(value), 0, 1000000000)
end

local function timestamp(value)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return 0 end
	return math.clamp(math.floor(value), 0, 1000000000000)
end

local function isToy(item)
	return typeof(item) == "table" and item.category == "Toys" and item.slot == "Gear"
end

local function inGame(player)
	return player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or ( player:GetAttribute("MDParticipating") == true or player:GetAttribute("HSParticipating") == true )
end

local function emoteDetails(data)
	if typeof(data) ~= "table" or typeof(data.Equipped) ~= "table" or typeof(data.Owned) ~= "table" then return nil end
	local id = data.Equipped.Emote
	local item = id and Catalog.ById[id]
	local animation = item and Catalog.EmoteAnimations[id]
	local animationId = animation and animation.R15AnimationId
	if not item or item.slot ~= "Emote" or item.available == false or item.playable ~= true
		or not data.Owned or data.Owned[id] ~= true or not boundedInteger(animationId, 1, 9007199254740991) then return nil end
	return { emoteId = id, emoteAnimationId = "rbxassetid://" .. string.format("%.0f", animationId), emoteRigType = "R15" }
end

local function stopEmote(player)
	player:SetAttribute("PCEmoteUntil", 0)
	player:SetAttribute("PCEmoteAction", "")
	player:SetAttribute("PCEmoteAnimationId", "")
end

local function cleanToyLoadout(equipped, owned)
	equipped = typeof(equipped) == "table" and equipped or {}
	local toys, seen = {}, {}
	local function add(id)
		local item = typeof(id) == "string" and Catalog.ById[id]
		if #toys < maxToySlots and isToy(item) and item.available ~= false and owned[id] == true and not seen[id] then
			seen[id] = true
			table.insert(toys, id)
		end
	end
	local active = typeof(equipped.Gear) == "string" and equipped.Gear or equipped.Toy
	if typeof(equipped.Toys) == "table" then
		if boundedInteger(equipped.ToyIndex, 1, 64) then active = equipped.Toys[equipped.ToyIndex] end
		for index = 1, 64 do
			add(equipped.Toys[index])
			if #toys == maxToySlots then break end
		end
	else
		add(equipped.Gear)
		if #toys == 0 then add(equipped.Toy) end
	end
	return toys, table.find(toys, active) or (#toys > 0 and 1 or 0)
end

local function setToyLoadout(data, toys, index)
	data.Equipped.Toys = toys
	data.Equipped.ToyIndex = index
	data.Equipped.Gear = toys[index]
	data.Equipped.Toy = toys[index]
end

local function equipToy(data, id)
	local toys = cleanToyLoadout(data.Equipped, data.Owned)
	local selected = table.find(toys, id)
	if not selected then
		if #toys >= maxToySlots then return false, "Your four toy slots are full. Unequip a toy first." end
		table.insert(toys, id)
		selected = #toys
	end
	setToyLoadout(data, toys, selected)
	return true
end

local function unequipToy(data, id)
	local toys, index = cleanToyLoadout(data.Equipped, data.Owned)
	local active = toys[index]
	local removed = table.find(toys, id)
	if not removed then return false, "That toy is not in your loadout." end
	table.remove(toys, removed)
	setToyLoadout(data, toys, table.find(toys, active) or math.min(index, #toys))
	return true
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
	local result = { Coins = integer(value.Coins, 0), Wins = integer(value.Wins, 0), XP = integer(value.XP, 0), Owned = {}, Equipped = {}, GameWins = {}, CoinPurchases = {}, Entitlements = {}, RedeemedCodes = {}, Version = 6 }
	local entitlements = typeof(value.Entitlements) == "table" and value.Entitlements or {}
	result.Entitlements.VIP = entitlements.VIP == true
	result.Entitlements.BetaTester = entitlements.BetaTester == true
	if typeof(value.RedeemedCodes) == "table" then
		for code, redeemedAt in pairs(value.RedeemedCodes) do
			if typeof(code) == "string" and #code > 0 and #code <= 32 and code:match("^[A-Z0-9_%-]+$") and timestamp(redeemedAt) > 0 then
				result.RedeemedCodes[code] = timestamp(redeemedAt)
			end
		end
	end
	result.SecretObbyClaimDay = integer(value.SecretObbyClaimDay, 0)
	result.FishingDay = integer(value.FishingDay, 0)
	result.FishingUsed = math.min(fishingCatchesPerDay, integer(value.FishingUsed, 0))
	result.FishingCoinsExpires = timestamp(value.FishingCoinsExpires)
	result.FishingXPExpires = timestamp(value.FishingXPExpires)
	if typeof(value.CoinPurchases) == "table" then
		for purchaseId, purchase in pairs(value.CoinPurchases) do
			if typeof(purchaseId) == "string" and #purchaseId > 0 and #purchaseId <= 128 and typeof(purchase) == "table"
				and boundedInteger(purchase.ProductId, 1, 9007199254740991) and boundedInteger(purchase.Coins, 1, 100000) then
				result.CoinPurchases[purchaseId] = { ProductId = purchase.ProductId, Coins = purchase.Coins }
			end
		end
	end
	for gameId in pairs(games) do
		result.GameWins[gameId] = integer(typeof(value.GameWins) == "table" and value.GameWins[gameId] or nil, 0)
	end
	if typeof(value.Owned) == "table" then
		for id, owned in pairs(value.Owned) do
			if typeof(id) == "string" and #id <= 48 and owned == true then result.Owned[id] = true end
		end
	end
	result.Owned[Catalog.StarterBat] = true
	if typeof(value.Equipped) == "table" then
		for slot, id in pairs(value.Equipped) do
			local item = typeof(id) == "string" and Catalog.ById[id]
			if slot ~= "Gear" and slots[slot] and typeof(id) == "string" and #id <= 48 and result.Owned[id] and (not item or item.slot == slot) then
				result.Equipped[slot] = id
			end
		end
	end
	local toys, toyIndex = cleanToyLoadout(value.Equipped, result.Owned)
	setToyLoadout(result, toys, toyIndex)
	if integer(value.Version, 0) < 3 and not result.Equipped.Bat then result.Equipped.Bat = Catalog.StarterBat end
	return result
end

local function unlockStatus(data, item, level, entitlements)
	local rule = item.unlock or {}
	local kind = rule.kind
	local target = integer(rule.amount, 0)
	local owned = data.Owned[item.id] == true
	local progress, unlocked, label = 0, false, "Unavailable"
	if kind == "Starter" then
		unlocked, label = true, "Starter reward"
	elseif kind == "Coins" then
		progress, unlocked, label = integer(data.Coins, 0), true, tostring(item.price) .. " coins"
	elseif kind == "VIP" or kind == "BetaTester" then
		local granted = entitlements or data.Entitlements or {}
		unlocked, label = granted[kind] == true, kind == "VIP" and "VIP reward" or "Beta Tester reward"
	elseif kind == "Level" then
		progress, label = level, "Level " .. target
		unlocked = progress >= target
	elseif kind == "Wins" and (rule.gameId == "All" or games[rule.gameId]) then
		progress = rule.gameId == "All" and integer(data.Wins, 0) or integer(data.GameWins and data.GameWins[rule.gameId], 0)
		label = target .. " " .. Catalog.GameNames[rule.gameId] .. " wins"
		unlocked = progress >= target
	end
	return {
		kind = kind, progress = progress, target = target, required = target,
		available = item.available ~= false and (owned or unlocked), unlocked = owned or unlocked,
		owned = owned, label = label,
		purchasable = kind == "Coins" and item.available ~= false and not owned and integer(data.Coins, 0) >= item.price,
	}
end

function Economy:_unlockRewards(profile)
	local level = self:LevelProgress(profile.data.XP)
	local awarded = {}
	for _, item in ipairs(Catalog.Items) do
		if item.available ~= false and item.unlock.kind ~= "Coins" and not profile.data.Owned[item.id] and unlockStatus(profile.data, item, level, self:_entitlements(profile.player)).unlocked then
			profile.data.Owned[item.id] = true
			table.insert(awarded, item.id)
		end
	end
	if #awarded > 0 then
		profile.newlyUnlocked = awarded
		profile.unlockSerial = (profile.unlockSerial or 0) + 1
	end
	return awarded
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
	self.passBenefits = {}
	self.redemptionCodes = require(script.Parent:WaitForChild("PlaygroundRedemptionCodes"))
	self.fishingRandom = Random.new()
	self.lastFishingSecond = 0
	self.connections = {}
	self.awarded = {}
	self.podiumEmotes = {}
	self.podiumEmoteReads = 0
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
	self.hiddenCoins = Instance.new("Folder")
	self.hiddenCoins.Name = "PlaygroundCoinRespawns"
	self.hiddenCoins.Parent = ServerStorage
	self.coins = {}
	self.running = false
	self.elapsed = 0
	self.lastSave = os.clock()
	return self
end

function Economy:_sync(profile)
	local player = profile.player
	local toys, toyIndex = cleanToyLoadout(profile.data.Equipped, profile.data.Owned)
	setToyLoadout(profile.data, toys, toyIndex)
	profile.data.XP = integer(profile.data.XP, 0)
	local level, levelXP, requiredXP = self:LevelProgress(profile.data.XP)
	self:_syncPassBenefits(player)
	self:_syncFishing(profile)
	player:SetAttribute("PCCoins", profile.data.Coins)
	player:SetAttribute("PCSecretObbyClaimDay", profile.data.SecretObbyClaimDay)
	player:SetAttribute("PCWins", profile.data.Wins)
	player:SetAttribute("PCXP", profile.data.XP)
	player:SetAttribute("PCLevel", level)
	player:SetAttribute("PCLevelXP", levelXP)
	player:SetAttribute("PCLevelXPRequired", requiredXP)
	player:SetAttribute("PCInventoryVersion", profile.version or 0)
	player:SetAttribute("PCUnlockSerial", profile.unlockSerial or 0)
	for gameId in pairs(games) do player:SetAttribute("PCWins" .. gameId, profile.data.GameWins[gameId]) end
	player:SetAttribute("PCDataReady", profile.ready == true)
	player:SetAttribute("PCDataMode", self.isStudio and "Studio" or self.sessionOnly and "Session" or "Persistent")
	for slot in pairs(slots) do
		local id = profile.data.Equipped[slot]
		local item = id and Catalog.ById[id]
		player:SetAttribute("PC" .. slot, profile.ready == true and item and item.available ~= false and item.slot == slot and profile.data.Owned[id] == true and id or "")
	end
	local emote = profile.ready and emoteDetails(profile.data)
	player:SetAttribute("PCEquippedEmoteAnimationId", emote and emote.emoteAnimationId or "")
	player:SetAttribute("PCEquippedEmoteRigType", emote and emote.emoteRigType or "")
	for index = 1, maxToySlots do player:SetAttribute("PCToySlot" .. index, profile.ready == true and toys[index] or "") end
	player:SetAttribute("PCToy", profile.ready == true and toys[toyIndex] or "")
	player:SetAttribute("PCToyIndex", profile.ready == true and toyIndex or 0)
	player:SetAttribute("PCToyLoadoutVersion", profile.version or 0)
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

function Economy:GetToyLoadout(player)
	local profile = self.profiles[player]
	if not profile or not profile.ready or profile.closed or profile.released then
		return { items = {}, activeIndex = 0, maxSlots = maxToySlots }
	end
	local toys, index = cleanToyLoadout(profile.data.Equipped, profile.data.Owned)
	return { items = toys, activeIndex = index, activeId = toys[index], maxSlots = maxToySlots }
end

function Economy:GetEquipped(player, slot)
	local profile = self.profiles[player]
	if not profile or not profile.ready or profile.closed or profile.released then return nil end
	if slot == "Gear" or slot == "Toy" then return self:GetToyLoadout(player).activeId end
	if typeof(slot) ~= "string" or not slots[slot] then return nil end
	local id = profile.data.Equipped[slot]
	local item = typeof(id) == "string" and Catalog.ById[id]
	return item and item.available ~= false and item.slot == slot and profile.data.Owned[id] == true and id or nil
end

function Economy:SelectToySlot(player, index)
	local profile = self.profiles[player]
	if not profile or not profile.ready or profile.closed or profile.released then return false, "Your items are still loading." end
	if inGame(player) then return false, "Toys are available in the lobby between rounds." end
	local toys, current = cleanToyLoadout(profile.data.Equipped, profile.data.Owned)
	if not boundedInteger(index, 1, maxToySlots) or not toys[index] then return false, "Choose a filled toy slot from 1 to 4." end
	if current ~= index then setToyLoadout(profile.data, toys, index) self:_touch(profile) end
	return true, "Selected " .. Catalog.ById[toys[index]].name .. "."
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
		profile.savedPurchases = table.clone(profile.data.CoinPurchases)
		profile.savedEntitlements = table.clone(profile.data.Entitlements)
		profile.savedCodes = table.clone(profile.data.RedeemedCodes)
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
	if saved then
		profile.savedPurchases = snapshot.CoinPurchases
		profile.savedEntitlements = snapshot.Entitlements
		profile.savedCodes = snapshot.RedeemedCodes
		self:_publishLeaderboard(profile.player.UserId, snapshot)
	end
	if not saved then warn("Playground profile save is pending for user " .. profile.player.UserId) end
	return saved
end

function Economy:_touch(profile)
	if profile.ready then self:_unlockRewards(profile) end
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
	local equipped = {}
	for slot, id in pairs(profile.data.Equipped) do
		local item = Catalog.ById[id]
		if item and item.available ~= false and item.slot == slot and profile.data.Owned[id] then equipped[slot] = id end
	end
	local outlineItem = Catalog.ById[equipped.Highlight]
	if outlineItem then
		local outline = Instance.new("Highlight")
		outline.Name = "PCOutline"
		outline.Adornee = character
		outline.FillTransparency = 1
		outline.OutlineTransparency = 0
		outline.OutlineColor = outlineItem.color
		outline.Enabled = not (profile.player:GetAttribute("BBParticipating") == true or (profile.player:GetAttribute("TGParticipating") == true or ( profile.player:GetAttribute("MDParticipating") == true or profile.player:GetAttribute("HSParticipating") == true )))
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
		trail.Enabled = profile.player:GetAttribute("HSParticipating") ~= true
		trail.Parent = root
	end
end

function Economy:_bindPlayer(player)
	if self.profiles[player] then return end
	local profile = { player = player, data = cleanData(nil), ready = false, version = 0, pickups = {}, connections = {}, lastMutation = -math.huge, lastStatus = -math.huge, lastExpression = -math.huge }
	self.profiles[player] = profile
	local board = player:FindFirstChild("leaderstats")
	if not board then board = Instance.new("Folder") board.Name = "leaderstats" board.Parent = player end
	for _, name in ipairs({ "Wins", "Level", "Coins" }) do
		if not board:FindFirstChild(name) then local counter = Instance.new("IntValue") counter.Name = name counter.Parent = board end
	end
	self:_sync(profile)
	for _, attribute in ipairs({ "BBParticipating", "TGParticipating", "MDParticipating", "HSParticipating" }) do
		table.insert(profile.connections, player:GetAttributeChangedSignal(attribute):Connect(function()
			if inGame(player) then stopEmote(player) end
		end))
	end
	table.insert(profile.connections, player.CharacterAdded:Connect(function(character)
		stopEmote(player)
		task.spawn(function()
			character:WaitForChild("HumanoidRootPart", 10)
			if self.profiles[player] == profile and character == player.Character and not profile.closed then self:_applyAppearance(profile) end
		end)
	end))
	task.spawn(function()
		while self.running and self.profiles[player] == profile and player.Parent == Players and not profile.ready do
			if self:_claim(profile) then
				if self.profiles[player] == profile and player.Parent == Players and not profile.closed then
					self:_touch(profile)
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
	local ready = profile ~= nil and profile.ready == true and not profile.closed and not profile.released
	local data = profile and profile.data or cleanData(nil)
	local loadout = self:GetToyLoadout(player)
	local equipped = table.clone(data.Equipped)
	equipped.Toys, equipped.ToyIndex = table.clone(loadout.items), loadout.activeIndex
	equipped.Gear, equipped.Toy = loadout.activeId, loadout.activeId
	local unlocks = {}
	for _, item in ipairs(Catalog.Items) do
		local status = unlockStatus(data, item, level, self:_entitlements(player))
		status.purchasable = ready and status.purchasable or false
		unlocks[item.id] = status
	end
	return {
		ok = ok, message = message or "", coins = data.Coins, wins = data.Wins,
		xp = xp, level = level, levelXP = levelXP, levelXPRequired = requiredXP,
		owned = table.clone(data.Owned), equipped = equipped, toyLoadout = loadout, ready = ready,
		entitlements = self:_entitlements(player),
		gameWins = table.clone(data.GameWins), winsByGame = table.clone(data.GameWins), unlocks = unlocks,
		newlyUnlocked = profile and table.clone(profile.newlyUnlocked or {}) or {},
		unlockSerial = profile and profile.unlockSerial or 0,
		inventoryVersion = profile and profile.version or 0,
	}
end

function Economy:Handle(player, action, id)
	local profile = self.profiles[player]
	if not profile or profile.closed or profile.released or not profile.ready then return self:Status(player, false, "Your items are still loading.") end
	if typeof(action) ~= "string" or not actions[action] then return self:Status(player, false, "Unknown shop control.") end
	if action == "RedeemCode" then
		local redeemed, message = self:RedeemCode(player, id)
		return self:Status(player, redeemed, message)
	end
	if action == "StopEmote" then
		stopEmote(player)
		return self:Status(player, true, "Dance stopped.")
	end
	local now = os.clock()
	local key = action == "GetStatus" and "lastStatus" or "lastMutation"
	if now - profile[key] < (action == "GetStatus" and 0.1 or 0.35) then return self:Status(player, false, "Please wait a moment.") end
	profile[key] = now
	if action == "GetStatus" then return self:Status(player, true) end
	if action == "SelectToy" then
		local selected, message = self:SelectToySlot(player, id)
		return self:Status(player, selected, message)
	end
	if action == "Unequip" then
		local toy = typeof(id) == "string" and Catalog.ById[id]
		if id == "Gear" or id == "Toy" or isToy(toy) then
			if inGame(player) then return self:Status(player, false, "Toys are available in the lobby between rounds.") end
			local toyId = isToy(toy) and id or self:GetToyLoadout(player).activeId
			local removed, reason = unequipToy(profile.data, toyId)
			if not removed then return self:Status(player, false, reason) end
			self:_touch(profile)
			return self:Status(player, true, "Toy removed from your loadout.")
		end
		if typeof(id) ~= "string" or not slots[id] then return self:Status(player, false, "Choose an item first.") end
		if id == "Emote" then stopEmote(player) end
		profile.data.Equipped[id] = nil
		self:_touch(profile)
		self:_applyAppearance(profile)
		return self:Status(player, true, "Unequipped.")
	end
	local item = typeof(id) == "string" and Catalog.ById[id]
	if not item or item.available == false then return self:Status(player, false, "This item is unavailable.") end
	if item.slot == "Emote" and (item.playable ~= true or not Catalog.EmoteAnimations[id]) then return self:Status(player, false, "This emote is not available to play.") end
	if action == "Buy" then
		if profile.data.Owned[id] then return self:Status(player, false, "You already own this.") end
		if item.unlock.kind ~= "Coins" then
			local status = unlockStatus(profile.data, item, self:LevelProgress(profile.data.XP), self:_entitlements(player))
			return self:Status(player, false, "Earn this reward: " .. status.label .. ".")
		end
		if profile.data.Coins < item.price then return self:Status(player, false, "Collect a few more coins first.") end
		profile.data.Coins -= item.price
		profile.data.Owned[id] = true
		local equipped, reason = true, nil
		if isToy(item) then
			if inGame(player) then equipped, reason = false, "Equip it in the lobby between rounds."
			else equipped, reason = equipToy(profile.data, id) end
		else profile.data.Equipped[item.slot] = id end
		self:_touch(profile)
		self:_applyAppearance(profile)
		return self:Status(player, true, item.name .. " is yours!" .. (not equipped and " " .. reason or ""))
	end
	if not profile.data.Owned[id] then return self:Status(player, false, "You don't own this yet.") end
	if action == "Equip" then
		if item.slot == "Emote" then stopEmote(player) end
		if isToy(item) then
			if inGame(player) then return self:Status(player, false, "Toys are available in the lobby between rounds.") end
			local equipped, reason = equipToy(profile.data, id)
			if not equipped then return self:Status(player, false, reason) end
		else profile.data.Equipped[item.slot] = id end
		self:_touch(profile)
		self:_applyAppearance(profile)
		return self:Status(player, true, "Equipped " .. item.name .. ".")
	end
	if action == "UseEmote" or action == "UseEmoji" then
		if now - profile.lastExpression < 4 then return self:Status(player, false, "Give it a moment.") end
		if inGame(player) then return self:Status(player, false, "Try this between rounds.") end
		if action == "UseEmote" then
			if item.slot ~= "Emote" then return self:Status(player, false, "Choose an emote.") end
			local character = player.Character
			if character and ((character:GetAttribute("PCToyHeld") or "") ~= "" or character:GetAttribute("PCBatHeld") == true) then
				return self:Status(player, false, "Put your toy away to dance.")
			end
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			if not humanoid or not rootPart or humanoid.Health <= 0 then return self:Status(player, false, "Your character is not ready.") end
			if humanoid.RigType ~= Enum.HumanoidRigType.R15 then return self:Status(player, false, "These dances need an R15 avatar.") end
			if not self:_inside(rootPart.Position) then return self:Status(player, false, "Dance in the lobby between rounds.") end
			if humanoid.MoveDirection.Magnitude > 0.1 or humanoid.Sit or humanoid.FloorMaterial == Enum.Material.Air then
				return self:Status(player, false, "Stand still on the ground to dance.")
			end
			local animation = Catalog.EmoteAnimations[id]
			if not animation or not boundedInteger(animation.R15AnimationId, 1, 9007199254740991) then return self:Status(player, false, "This emote is unavailable.") end
			local startedAt = workspace:GetServerTimeNow()
			profile.lastExpression = now
			player:SetAttribute("PCEmoteAction", id)
			player:SetAttribute("PCEmoteAnimationId", "rbxassetid://" .. string.format("%.0f", animation.R15AnimationId))
			player:SetAttribute("PCEmoteRigType", "R15")
			player:SetAttribute("PCEmoteStartedAt", startedAt)
			player:SetAttribute("PCEmoteUntil", startedAt + 30)
			player:SetAttribute("PCEmoteSerial", integer(player:GetAttribute("PCEmoteSerial"), 0) + 1)
			return self:Status(player, true, "Move or jump to stop dancing.")
		end
		profile.lastExpression = now
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

function Economy:GetPodiumEmote(userId)
	if not boundedInteger(userId, 1, 1000000000000) then return nil end
	local profile = self:_profileByUserId(userId)
	if profile then
		return profile.ready and not profile.closed and not profile.released and emoteDetails(profile.data) or nil
	end
	local cached = self.podiumEmotes[userId]
	local now = os.clock()
	if cached and (cached.busy or cached.expires > now) then return cached.value end
	if self.isStudio or not self.store or self.podiumEmoteReads >= 2 then return cached and cached.value end
	local record = cached or {}
	record.busy = true
	self.podiumEmotes[userId] = record
	self.podiumEmoteReads += 1
	task.spawn(function()
		local ok, data = pcall(function() return self.store:GetAsync("u:" .. userId) end)
		self.podiumEmoteReads -= 1
		record.busy = false
		record.expires = os.clock() + (ok and 120 or 30)
		if ok then record.value = emoteDetails(data) end
	end)
	return record.value
end

function Economy:_profileByUserId(id)
	for player, profile in pairs(self.profiles) do
		if player.UserId == id and player.Parent == Players then return profile end
	end
	return nil
end

function Economy:_adminProfile(player)
	if not player or player.Parent ~= Players then return nil, "That player is no longer in this server." end
	local profile = self.profiles[player]
	if not profile or not profile.ready or profile.closed or profile.released then return nil, "That player's data is not ready." end
	return profile
end

function Economy:AdminGrantItem(player, id, equip)
	local profile, reason = self:_adminProfile(player)
	if not profile then return false, reason end
	local item = typeof(id) == "string" and #id <= 48 and Catalog.ById[id]
	if not item or item.available == false or not slots[item.slot] then return false, "Choose an available catalog item." end
	if equip ~= nil and typeof(equip) ~= "boolean" then return false, "Equip must be on or off." end
	local alreadyOwned = profile.data.Owned[id] == true
	if alreadyOwned and not equip then return false, "That player already owns " .. item.name .. "." end
	profile.data.Owned[id] = true
	local didEquip, equipReason = equip, nil
	if equip then
		if isToy(item) then
			if inGame(player) then didEquip, equipReason = false, "Equip it in the lobby between rounds."
			else didEquip, equipReason = equipToy(profile.data, id) end
		else profile.data.Equipped[item.slot] = id end
	end
	if alreadyOwned and equip and not didEquip then return false, equipReason end
	self:_touch(profile)
	if didEquip then self:_applyAppearance(profile) end
	return true, (alreadyOwned and "Equipped " or didEquip and "Granted and equipped " or "Granted ") .. item.name .. "." .. (equipReason and " " .. equipReason or "")
end

local function fishingMultiplier(profile, field, now)
	return profile and profile.ready and not profile.closed and not profile.released
		and timestamp(profile.data[field]) > now and 2 or 1
end

function Economy:_syncFishing(profile, now)
	now = now or os.time()
	local data, player = profile.data, profile.player
	local ready = profile.ready and not profile.closed and not profile.released
	local today = math.floor(now / 86400)
	local used = integer(data.FishingDay, 0) >= today and integer(data.FishingUsed, 0) or 0
	player:SetAttribute("PCFishingCatchesLeft", ready and math.max(0, fishingCatchesPerDay - used) or 0)
	player:SetAttribute("PCFishingCoinsExpires", ready and timestamp(data.FishingCoinsExpires) > now and data.FishingCoinsExpires or 0)
	player:SetAttribute("PCFishingXPExpires", ready and timestamp(data.FishingXPExpires) > now and data.FishingXPExpires or 0)
end

function Economy:_entitlements(player)
	local profile = self.profiles[player]
	local manual = profile and profile.ready and not profile.closed and not profile.released and profile.data.Entitlements or {}
	local passes = self.passBenefits[player] or {}
	return { VIP = passes.vip == true or manual.VIP == true, BetaTester = manual.BetaTester == true }
end

function Economy:_syncPassBenefits(player)
	local benefits = self.passBenefits[player] or {}
	local profile, now = self.profiles[player], os.time()
	local entitlements = self:_entitlements(player)
	player:SetAttribute("PCVIP", entitlements.VIP)
	player:SetAttribute("PCBetaTester", entitlements.BetaTester)
	player:SetAttribute("PCDoubleCoins", benefits.doubleCoins == true)
	player:SetAttribute("PCDoubleXP", benefits.doubleXP == true)
	player:SetAttribute("PCCoinMultiplier", (entitlements.VIP and 3 or benefits.doubleCoins and 2 or 1) * fishingMultiplier(profile, "FishingCoinsExpires", now))
	player:SetAttribute("PCXPMultiplier", ((entitlements.VIP or benefits.doubleXP) and 2 or 1) * fishingMultiplier(profile, "FishingXPExpires", now))
end

function Economy:SetPassBenefits(player, vip, doubleCoins, doubleXP)
	if not player or player.Parent ~= Players then return false end
	self.passBenefits[player] = { vip = vip == true, doubleCoins = doubleCoins == true, doubleXP = doubleXP == true }
	local profile = self.profiles[player]
	if profile and profile.ready and not profile.closed and not profile.released then self:_touch(profile)
	else self:_syncPassBenefits(player) end
	return true
end

function Economy:_earnedCoins(profile, amount)
	local benefits = self.passBenefits[profile.player] or {}
	return integer(amount, 0) * (self:_entitlements(profile.player).VIP and 3 or benefits.doubleCoins and 2 or 1) * fishingMultiplier(profile, "FishingCoinsExpires", os.time())
end

function Economy:_earnedXP(profile, amount)
	local benefits = self.passBenefits[profile.player] or {}
	return integer(amount, 0) * ((self:_entitlements(profile.player).VIP or benefits.doubleXP) and 2 or 1) * fishingMultiplier(profile, "FishingXPExpires", os.time())
end

function Economy:GrantCoinPurchase(player, receipt, coins)
	if self.isStudio or self.sessionOnly or not self.store then return false end
	if not player or player.Parent ~= Players or typeof(receipt) ~= "table"
		or receipt.PlayerId ~= player.UserId or not boundedInteger(receipt.ProductId, 1, 9007199254740991)
		or typeof(receipt.PurchaseId) ~= "string" or #receipt.PurchaseId == 0 or #receipt.PurchaseId > 128
		or not boundedInteger(coins, 1, 100000) then return false end
	local profile = self.profiles[player]
	if not profile or not profile.ready or profile.closed or profile.released then return false end
	local purchaseId = receipt.PurchaseId
	local purchase = profile.data.CoinPurchases[purchaseId]
	if purchase then
		if purchase.ProductId ~= receipt.ProductId or purchase.Coins ~= coins then return false end
	else
		if profile.data.Coins > adminLimits.maxCoins - coins then return false end
		profile.data.CoinPurchases[purchaseId] = { ProductId = receipt.ProductId, Coins = coins }
		profile.data.Coins += coins
		self:_touch(profile)
	end
	local confirmed = profile.savedPurchases and profile.savedPurchases[purchaseId]
	if not confirmed then
		self:_save(profile, false)
		confirmed = profile.savedPurchases and profile.savedPurchases[purchaseId]
	end
	return confirmed ~= nil and confirmed.ProductId == receipt.ProductId and confirmed.Coins == coins
end

function Economy:CanFish(player)
	local profile = self.profiles[player]
	if not player or player.Parent ~= Players or not profile or not profile.ready or profile.closed or profile.released then
		return false, "Your fishing rewards are still loading. Try again in a moment."
	end
	if self.sessionOnly and not self.isStudio then return false, "Fishing is unavailable while player data is offline. Try again shortly." end
	if inGame(player) then return false, "Fishing is available in the lobby between rounds." end
	if profile.fishingSaving then return false, "Your last catch is still saving. Please wait a moment." end
	if profile.fishingPending then return true end
	local day = math.floor(os.time() / 86400)
	if integer(profile.data.FishingDay, 0) >= day and integer(profile.data.FishingUsed, 0) >= fishingCatchesPerDay then
		return false, "You've used today's three catches. Come back tomorrow!"
	end
	return true
end

function Economy:ClaimFishingReward(player)
	local allowed, reason = self:CanFish(player)
	if not allowed then return false, reason end
	local profile = self.profiles[player]
	local data, now = profile.data, os.time()
	if not profile.fishingPending then
		local day = math.floor(now / 86400)
		if integer(data.FishingDay, 0) < day then data.FishingUsed = 0 end
		local kind = self.fishingRandom:NextInteger(1, 2) == 1 and "Coins" or "XP"
		local field = kind == "Coins" and "FishingCoinsExpires" or "FishingXPExpires"
		data.FishingDay = day
		data.FishingUsed = integer(data.FishingUsed, 0) + 1
		data[field] = math.max(now, timestamp(data[field])) + fishingBoostSeconds
		profile.fishingPending = { kind = kind, expires = data[field] }
		self:_touch(profile)
	end
	profile.fishingSaving = true
	local saveOK, saved = pcall(self._save, self, profile, false)
	profile.fishingSaving = false
	if not saveOK or not saved then return false, "Your catch is waiting to save. Try this rod again; it won't use another catch." end
	local reward = profile.fishingPending
	profile.fishingPending = nil
	local remaining = math.max(0, fishingCatchesPerDay - integer(data.FishingUsed, 0))
	return true, "+5 minutes of 2x " .. (reward.kind == "Coins" and "coins" or "XP") .. "! " .. remaining .. " catches left today.", reward.kind, reward.expires
end

function Economy:ClaimSecretObbyReward(player)
	local profile = self.profiles[player]
	if player.Parent ~= Players or not profile or not profile.ready or profile.closed or profile.released then
		return false, "Your coins are still loading. Try again in a moment."
	end
	if inGame(player) then return false, "Finish your round first." end
	local day = math.floor(os.time() / 86400)
	if integer(profile.data.SecretObbyClaimDay, 0) >= day then
		return false, "Trail complete! Today's prize is already collected. Come back tomorrow."
	end
	local coins = self:_earnedCoins(profile, 1000)
	if profile.data.Coins > adminLimits.maxCoins - coins then return false, "Your coin balance is full." end
	profile.data.SecretObbyClaimDay = day
	profile.data.Coins += coins
	self:_touch(profile)
	self:_publishReward(profile, coins, 0, false, false)
	task.spawn(function() self:_save(profile, false) end)
	return true, "Secret Steps complete! +" .. coins .. " coins."
end

function Economy:AdminGrantEntitlement(player, entitlement)
	local profile, reason = self:_adminProfile(player)
	if not profile then return false, reason end
	if entitlement ~= "VIP" and entitlement ~= "BetaTester" then return false, "Choose VIP or Beta Tester." end
	if self.sessionOnly and not self.isStudio then return false, "Grants are unavailable while player data is offline." end
	if profile.entitlementSaving then return false, "That player's previous grant is still saving." end
	local label = entitlement == "VIP" and "VIP" or "Beta Tester"
	if profile.savedEntitlements and profile.savedEntitlements[entitlement] then return true, label .. " is already granted." end
	if not profile.data.Entitlements[entitlement] then
		profile.data.Entitlements[entitlement] = true
		self:_touch(profile)
	end
	profile.entitlementSaving = true
	local ok, saved = pcall(self._save, self, profile, false)
	profile.entitlementSaving = false
	local confirmed = self.isStudio or (profile.savedEntitlements and profile.savedEntitlements[entitlement] == true)
	if not ok or not saved or not confirmed then return false, label .. " is pending a save. Retry the grant to confirm it." end
	return true, "Granted " .. label .. "." .. (self.isStudio and " This Studio test does not save player data." or "")
end

function Economy:RedeemCode(player, payload)
	local profile, reason = self:_adminProfile(player)
	if not profile then return false, reason end
	local now = os.clock()
	if now - (profile.lastRedeem or -math.huge) < 2 then return false, "Wait two seconds before trying another code." end
	profile.lastRedeem = now
	if profile.codeSaving then return false, "Your previous code is still saving." end
	if self.sessionOnly and not self.isStudio then return false, "Codes are unavailable while player data is offline." end
	local text = typeof(payload) == "table" and payload.code
	if typeof(text) ~= "string" or #text > 64 then return false, "Enter a valid code of up to 32 characters." end
	local code = string.upper(text:match("^%s*(.-)%s*$"))
	if #code == 0 or #code > 32 or not code:match("^[A-Z0-9_%-]+$") then return false, "Enter a valid code of up to 32 characters." end
	if profile.savedCodes and profile.savedCodes[code] then return false, "You have already redeemed this code." end
	if not profile.data.RedeemedCodes[code] then
		local reward = typeof(self.redemptionCodes) == "table" and self.redemptionCodes[code]
		if typeof(reward) ~= "table" or reward.Enabled ~= true then return false, "This code is invalid or unavailable." end
		if reward.ExpiresAt ~= nil and (not boundedInteger(reward.ExpiresAt, 0, 1000000000000) or (reward.ExpiresAt > 0 and os.time() >= reward.ExpiresAt)) then
			return false, "This code has expired."
		end
		if reward.Kind == "Coins" then
			if not boundedInteger(reward.Amount, 1, adminLimits.coinsPerGrant) then return false, "This code is unavailable." end
			if profile.data.Coins > adminLimits.maxCoins - reward.Amount then return false, "Your coin balance is full. Use some coins before redeeming this code." end
			profile.data.Coins += reward.Amount
		elseif reward.Kind == "VIP" or reward.Kind == "BetaTester" then
			profile.data.Entitlements[reward.Kind] = true
		else return false, "This code is unavailable." end
		profile.data.RedeemedCodes[code] = os.time()
		self:_touch(profile)
	end
	profile.codeSaving = true
	local ok, saved = pcall(self._save, self, profile, false)
	profile.codeSaving = false
	local confirmed = self.isStudio or (profile.savedCodes and profile.savedCodes[code] ~= nil)
	if not ok or not saved or not confirmed then return false, "Your reward is waiting to save. Try this code again; it will not grant twice." end
	if self.isStudio then
		profile.savedCodes = profile.savedCodes or {}
		profile.savedCodes[code] = profile.data.RedeemedCodes[code]
	end
	return true, "Code redeemed! Your reward is active." .. (self.isStudio and " This Studio test does not save player data." or "")
end

function Economy:AdminGrantCoins(player, amount)
	local profile, reason = self:_adminProfile(player)
	if not profile then return false, reason end
	if not boundedInteger(amount, 1, adminLimits.coinsPerGrant) then return false, "Add a whole number from 1 to " .. adminLimits.coinsPerGrant .. " coins." end
	local balance = integer(profile.data.Coins, 0)
	if balance + amount > adminLimits.maxCoins then return false, "That grant would exceed the coin balance limit." end
	profile.data.Coins = balance + amount
	self:_touch(profile)
	self:_publishReward(profile, amount, 0, false, false)
	return true, "Added " .. amount .. " coins."
end

function Economy:AdminAddLevels(player, amount)
	local profile, reason = self:_adminProfile(player)
	if not profile then return false, reason end
	if not boundedInteger(amount, 1, adminLimits.levelsPerGrant) then return false, "Add a whole number from 1 to " .. adminLimits.levelsPerGrant .. " levels." end
	local level, progress = self:LevelProgress(profile.data.XP)
	local targetLevel = level + amount
	if targetLevel > adminLimits.maxLevel then return false, "Admin level grants can reach level " .. adminLimits.maxLevel .. " at most." end
	local completed = targetLevel - 1
	local base = math.max(1, self:_setting("BaseLevelXP", 200))
	local step = self:_setting("LevelXPStep", 50)
	local targetXP = completed * base + step * completed * (completed - 1) / 2 + progress
	if not boundedInteger(targetXP, 0, 1000000000) then return false, "That grant would exceed the XP limit." end
	profile.data.XP = targetXP
	self:_touch(profile)
	return true, "Added " .. amount .. " " .. (amount == 1 and "level" or "levels") .. ". Now level " .. targetLevel .. "."
end

function Economy:AwardRound(key, winnerIds, practice, participantIds, rewardOptions)
	if practice or typeof(key) ~= "string" or #key > 96 or self.awarded[key] or typeof(winnerIds) ~= "table" or typeof(participantIds) ~= "table" then return 0 end
	local participants, winners = {}, {}
	local function validId(id) return typeof(id) == "number" and id == id and id % 1 == 0 and math.abs(id) <= 1000000000000 end
	for _, id in ipairs(participantIds) do if validId(id) then participants[id] = true end end
	for _, id in ipairs(winnerIds) do if validId(id) and participants[id] then winners[id] = true end end
	if next(participants) == nil then return 0 end
	self.awarded[key] = true
	local gameId = typeof(rewardOptions) == "table" and rewardOptions.gameId or nil
	if not games[gameId] then gameId = gamePrefixes[string.match(key, "^(%a+):")] end
	local rewarded = 0
	for id in pairs(participants) do
		local profile = self:_profileByUserId(id)
		if profile and profile.ready and not profile.closed and not profile.released then
			local won = winners[id] == true
			local coins = self:_setting(won and "WinnerCoins" or "LoserCoins", won and 150 or 50)
			local xp = self:_setting(won and "WinnerXP" or "LoserXP", 50)
			if typeof(rewardOptions) == "table" then xp = integer(won and rewardOptions.winnerXP or rewardOptions.loserXP, xp) end
			coins = self:_earnedCoins(profile, coins)
			xp = self:_earnedXP(profile, xp)
			local beforeCoins = integer(profile.data.Coins, 0)
			local beforeXP = integer(profile.data.XP, 0)
			profile.data.Coins = integer(beforeCoins + coins, 0)
			profile.data.XP = integer(beforeXP + xp, 0)
			if won then
				profile.data.Wins = integer(profile.data.Wins + 1, 0)
				if games[gameId] then profile.data.GameWins[gameId] = integer(profile.data.GameWins[gameId] + 1, 0) end
			end
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
	local template = self.assets:FindFirstChild("C01")
	for _, marker in ipairs(self.lobby.Gameplay.CoinSpawns:GetChildren()) do
		if marker:IsA("BasePart") then
			local coin
			if template and (template:IsA("Model") or template:IsA("BasePart")) then
				coin = template:Clone()
				if coin:IsA("Model") then
					local _, size = coin:GetBoundingBox()
					local extent = math.max(size.X, size.Y, size.Z)
					if extent > 0 then coin:ScaleTo(coin:GetScale() * 2.8 / extent) end
				else
					coin.Size *= 2.8 / math.max(coin.Size.X, coin.Size.Y, coin.Size.Z)
				end
			else
				coin = Instance.new("Part")
				coin.Shape = Enum.PartType.Cylinder
				coin.Size = Vector3.new(0.65, 2.8, 2.8)
				coin.Color = Color3.fromRGB(255, 207, 59)
				coin.Material = Enum.Material.SmoothPlastic
			end
			coin.Name = "Coin_" .. marker.Name
			local parts = coin:GetDescendants()
			table.insert(parts, coin)
			for _, object in ipairs(parts) do
				if object:IsA("BasePart") then
					object.Anchored = true
					object.CanCollide = false
					object.CanTouch = false
					object.CanQuery = false
				elseif object:IsA("LuaSourceContainer") then object:Destroy() end
			end
			coin:PivotTo(marker.CFrame)
			coin.Parent = self.effects
			table.insert(self.coins, {
				id = marker:GetAttribute("PickupId") or marker.Name,
				value = coinPickupAmount,
				cooldown = math.clamp(integer(marker:GetAttribute("RespawnSeconds"), 45), 15, 300),
				marker = marker, visual = coin, availableAt = 0,
			})
		end
	end
end

function Economy:_collectCoin(profile, coin, now)
	local player = profile.player
	if self.profiles[player] ~= profile or player.Parent ~= Players or not profile.ready or profile.closed or profile.released
		or now < coin.availableAt or coin.visual.Parent ~= self.effects or not coin.marker.Parent then return false end
	if player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true
		or ( player:GetAttribute("MDParticipating") == true or player:GetAttribute("HSParticipating") == true ) then return false end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 or not self:_inside(root.Position)
		or (root.Position - coin.marker.Position).Magnitude > 5.5 then return false end
	local beforeCoins = integer(profile.data.Coins, 0)
	local coins = self:_earnedCoins(profile, coinPickupAmount)
	if beforeCoins > adminLimits.maxCoins - coins then return false end
	local position = coin.visual:GetPivot().Position
	coin.availableAt = now + coin.cooldown
	coin.visual.Parent = self.hiddenCoins
	profile.data.Coins = beforeCoins + coins
	self:_touch(profile)
	profile.pickupSerial = math.max(profile.pickupSerial or 0, integer(player:GetAttribute("PCCoinPickupSerial"), 0)) + 1
	player:SetAttribute("PCCoinPickupAmount", coins)
	player:SetAttribute("PCCoinPickupPosition", position)
	player:SetAttribute("PCCoinPickupSerial", profile.pickupSerial)
	return true
end

function Economy:_tick(dt)
	self.elapsed += dt
	if self.elapsed < 0.15 then return end
	self.elapsed = 0
	local now = workspace:GetServerTimeNow()
	local fishingNow = os.time()
	if fishingNow ~= self.lastFishingSecond then
		self.lastFishingSecond = fishingNow
		for _, profile in pairs(self.profiles) do
			self:_syncFishing(profile, fishingNow)
			self:_syncPassBenefits(profile.player)
		end
	end
	for _, coin in ipairs(self.coins) do
		if coin.marker.Parent and coin.visual.Parent and now >= coin.availableAt then
			coin.visual:PivotTo(coin.marker.CFrame * CFrame.new(0, math.sin(now * 2 + #tostring(coin.id)) * 0.3, 0) * CFrame.Angles(0, now, 0))
			coin.visual.Parent = self.effects
		end
	end
	for player, profile in pairs(self.profiles) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and profile.ready and not profile.closed and not profile.released then
			local participating = player:GetAttribute("BBParticipating") == true or (player:GetAttribute("TGParticipating") == true or ( player:GetAttribute("MDParticipating") == true or player:GetAttribute("HSParticipating") == true ))
			local trail = character:FindFirstChild("PCTrail", true)
			if trail then trail.Enabled = player:GetAttribute("HSParticipating") ~= true end
			local outline = character:FindFirstChild("PCOutline")
			if outline then
				outline.Enabled = not participating
				if profile.data.Equipped.Highlight == "RainbowOutline" then outline.OutlineColor = Color3.fromHSV(now * 0.12 % 1, 0.72, 1) end
			end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not participating and humanoid and humanoid.Health > 0 and self:_inside(root.Position) then
				for _, coin in ipairs(self.coins) do
					self:_collectCoin(profile, coin, now)
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
		self.passBenefits[player] = nil
	end))
	for _, player in ipairs(Players:GetPlayers()) do self:_bindPlayer(player) end
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt) self:_tick(dt) end))
	for _, attributeName in ipairs({"BaseLevelXP", "LevelXPStep"}) do
		table.insert(self.connections, self.lobby:GetAttributeChangedSignal(attributeName):Connect(function()
			for _, profile in pairs(self.profiles) do if profile.ready and not profile.closed then self:_touch(profile) end end
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
	self.hiddenCoins:Destroy()
	table.clear(self.profiles)
	table.clear(self.passBenefits)
end

Economy.CleanData = cleanData
Economy.CalculateLevelProgress = levelProgress
Economy.EvaluateUnlock = unlockStatus
Economy.AdminLimits = adminLimits
return Economy

