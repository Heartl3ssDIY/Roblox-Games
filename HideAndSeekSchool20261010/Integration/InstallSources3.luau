assert(not game:GetService("RunService"):IsRunning(), "Stop Play before integrating Hide and Seek.")
assert(game.PlaceId == 95034648955135, "Wrong experience.")
local entries = {
 { path = "ServerScriptService.PlaygroundEconomyService", expected = 565414992, source = [==[local Players = game:GetService("Players")
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
]==] },
 { path = "ReplicatedStorage.PlaygroundCatalog", expected = 325191128, source = [==[local COIN_PRICE_MULTIPLIER = 3
local COIN_PRICE_CAP = 100000

local function item(id, name, category, slot, kind, amount, gameId, description, color, finalCoinPrice)
	if kind == "Coins" and not finalCoinPrice then amount = amount * COIN_PRICE_MULTIPLIER end
	return {
		id = id,
		name = name,
		category = category,
		slot = slot,
		available = true,
		price = kind == "Coins" and amount or 0,
		unlock = { kind = kind, amount = amount, gameId = gameId },
		description = description,
		color = Color3.fromRGB(color[1], color[2], color[3]),
		assetId = id,
	}
end

local items = {
	item("B01", "Starter Slugger", "Bats", "Bat", "Starter", 0, nil, "Your first Bulldog bat. Ready from the start.", {218, 155, 76}),
	item("B02", "Schoolyard Alloy", "Bats", "Bat", "Coins", 750, nil, "A silver schoolyard classic with a blue grip.", {139, 185, 224}),
	item("B03", "Varsity Victory", "Bats", "Bat", "Level", 5, nil, "Earn your varsity colours by reaching level 5.", {241, 91, 101}),
	item("B04", "Street Cone", "Bats", "Bat", "Coins", 1250, nil, "Bold orange with bright playground stripes.", {255, 147, 57}),
	item("B05", "Bubblegum Bonker", "Bats", "Bat", "Level", 10, nil, "A sweet reward for reaching level 10.", {244, 113, 184}),
	item("B06", "Mudslinger", "Bats", "Bat", "Wins", 25, "StuckInTheMud", "Win 25 rounds of Stuck in the Mud.", {142, 126, 73}),
	item("B07", "Heat Coil", "Bats", "Bat", "Wins", 50, "StuckInTheMud", "A heated trophy for 50 Stuck in the Mud wins.", {255, 152, 67}),
	item("B08", "Frostbite", "Bats", "Bat", "Coins", 4000, nil, "A chunky ice-blue barrel and a deep blue grip.", {116, 225, 245}),
	item("B09", "Thunder Circuit", "Bats", "Bat", "Wins", 25, "TagYoureIt", "Win 25 rounds of Tag You're It.", {67, 143, 243}),
	item("B10", "Pixel Party", "Bats", "Bat", "Level", 20, nil, "Reach level 20 for this bright arcade bat.", {213, 97, 228}),
	item("B11", "Cosmic Orbit", "Bats", "Bat", "Coins", 10000, nil, "A violet barrel with a silver orbit ring.", {153, 120, 235}),
	item("B12", "Royal Champion", "Bats", "Bat", "Wins", 50, "BritishBulldog", "A crown for 50 British Bulldog wins.", {248, 209, 92}),
	item("B13", "Skatepark Stripe", "Bats", "Bat", "Coins", 2500, nil, "Blue, mint and coral playground style.", {82, 176, 226}),
	item("B14", "Deep Sea", "Bats", "Bat", "Coins", 6000, nil, "Ocean waves on a navy and turquoise barrel.", {71, 193, 191}),
	item("B15", "Sunburst", "Bats", "Bat", "Level", 30, nil, "A sunny reward for reaching level 30.", {255, 180, 63}),
	item("P01", "Pocket Bulldog", "Pets", "Pet", "Coins", 500, nil, "A cheerful little schoolyard companion.", {224, 184, 131}),
	item("P02", "Toast Capybara", "Pets", "Pet", "Level", 3, nil, "Reach level 3 for this sleepy toast-shaped friend.", {209, 153, 86}),
	item("P03", "Pancake Penguin", "Pets", "Pet", "Coins", 1000, nil, "A happy penguin with a pancake hat.", {118, 160, 214}),
	item("P04", "Jelly Axolotl", "Pets", "Pet", "Wins", 10, "StuckInTheMud", "Win 10 rounds of Stuck in the Mud.", {103, 221, 219}),
	item("P05", "Rocket Snail", "Pets", "Pet", "Level", 8, nil, "Reach level 8 for this tiny rocket rider.", {142, 224, 172}),
	item("P06", "Traffic Crab", "Pets", "Pet", "Coins", 1750, nil, "A blue crab wearing a bright traffic-cone hat.", {83, 176, 232}),
	item("P07", "Teapot Frog", "Pets", "Pet", "Coins", 2000, nil, "A little green frog with teapot charm.", {170, 208, 91}),
	item("P08", "Skater Shark", "Pets", "Pet", "Wins", 10, "TagYoureIt", "Win 10 rounds of Tag You're It.", {78, 203, 224}),
	item("P09", "Disco Duck", "Pets", "Pet", "Coins", 3000, nil, "A sunny duck that brings its own disco backpack.", {255, 216, 70}),
	item("P10", "Cloud Sheep", "Pets", "Pet", "Level", 12, nil, "A fluffy reward for reaching level 12.", {174, 216, 245}),
	item("P11", "Cactus Cat", "Pets", "Pet", "Coins", 4000, nil, "A cuddly cactus kitten with a pink flower.", {115, 202, 113}),
	item("P12", "UFO Jelly", "Pets", "Pet", "Level", 18, nil, "Reach level 18 for a visitor from the playground stars.", {185, 156, 233}),
	item("P13", "Pumpkin Bunny", "Pets", "Pet", "Coins", 5000, nil, "A pumpkin-shaped bunny with leafy ears.", {244, 156, 63}),
	item("P14", "Hoodie Ghost", "Pets", "Pet", "Wins", 25, "TagYoureIt", "Win 25 rounds of Tag You're It.", {174, 142, 224}),
	item("P15", "Marshmallow Dragon", "Pets", "Pet", "Coins", 7500, nil, "A soft-coloured little dragon with pink wings.", {247, 179, 205}),
	item("P16", "Banana Gorilla", "Pets", "Pet", "Wins", 25, "BritishBulldog", "Win 25 rounds of British Bulldog.", {238, 200, 65}),
	item("P17", "Gummy Rex", "Pets", "Pet", "Level", 25, nil, "Reach level 25 for a cheerful gummy dinosaur.", {163, 222, 88}),
	item("P18", "Lava Toaster", "Pets", "Pet", "Wins", 50, "StuckInTheMud", "Win 50 rounds of Stuck in the Mud.", {248, 134, 64}),
	item("P19", "Moon Moth", "Pets", "Pet", "Coins", 10000, nil, "A cream and violet companion with crescent wings.", {177, 160, 239}),
	item("P20", "Royal Slime", "Pets", "Pet", "Wins", 100, "All", "Win 100 rounds across all games.", {100, 148, 237}),
	item("M01", "Playground Football", "Toys", "Gear", "Coins", 250, nil, "Lobby only. Kick a football that bounces for up to 5 seconds. Recharges in 5 seconds.", {224, 224, 208}),
	item("M02", "Playground Basketball", "Toys", "Gear", "Coins", 350, nil, "Lobby only. Lob a basketball high into the air. It lasts up to 5 seconds and recharges in 5 seconds.", {249, 147, 65}),
	item("M03", "Foam Bonker", "Toys", "Gear", "Coins", 500, nil, "Lobby only. Swing a harmless foam bonker with a star burst on contact. Recharges in 0.8 seconds.", {233, 129, 208}),
	item("M04", "Tumble Barrel", "Toys", "Gear", "Coins", 1000, nil, "Lobby only. Throw a tumbling barrel that bounces for up to 5 seconds. Recharges in 5 seconds.", {191, 139, 84}),
	item("M05", "Zoom Juice", "Toys", "Gear", "Coins", 750, nil, "Lobby only. Drink for 3 times your normal walking speed for 25 seconds. Recharges when the boost ends.", {69, 205, 220}),
	item("M06", "Spring Sip", "Toys", "Gear", "Coins", 750, nil, "Lobby only. Drink to jump 5 times your normal height for 10 seconds. Recharges when the boost ends.", {176, 221, 76}),
	item("M07", "Ember Elixir", "Toys", "Gear", "Coins", 1250, nil, "Lobby only. Drink, then tap to breathe fire for 10 seconds. Hits burn for 1 damage a second for 10 seconds.", {250, 136, 63}),
	item("M08", "Surprise Present", "Toys", "Gear", "Coins", 500, nil, "Lobby only. Shake a present to release colourful confetti. Recharges in 3 seconds.", {103, 207, 208}),
	item("M09", "Plunger Popper", "Toys", "Gear", "Coins", 4000, nil, "Lobby collectible. You can own and equip this launcher; its action is on hold until the plunger model is ready.", {85, 191, 187}),
	item("M10", "Frost Ray", "Toys", "Gear", "Coins", 5000, nil, "Lobby only. Freeze another player for 2.5 seconds with an icy ray. Recharges in 5 seconds.", {107, 216, 239}),
	item("M11", "Paint Splash", "Toys", "Gear", "Coins", 1500, nil, "Lobby only. Throw colourful paint that leaves a splash for 10 seconds. Recharges in 2 seconds.", {225, 118, 204}),
	item("M12", "Eggsploit", "Toys", "Gear", "Coins", 300, nil, "Lobby only. Throw an egg that shakes on impact and pops into confetti. Recharges in 3 seconds.", {238, 226, 184}),
	item("M13", "Cake Toss", "Toys", "Gear", "Coins", 600, nil, "Lobby only. Throw a cake that leaves frosting for 5 seconds. Recharges in 3 seconds.", {204, 157, 122}),
	item("M14", "Camp Torch", "Toys", "Gear", "Coins", 2500, nil, "Lobby only. Touch another player with the held torch to burn for 1 damage a second for 10 seconds.", {253, 168, 64}),
	item("M15", "Bounce Pad", "Toys", "Gear", "Coins", 3000, nil, "Lobby only. Place a shared bounce pad for 15 seconds before it bursts into sparkles. Recharges when the pad expires.", {97, 210, 224}),
	item("B16", "Fossil Slugger", "Bats", "Bat", "Coins", 36000, nil, "A recognisable long tapered baseball bat with a broad ivory fossil-bone barrel, three chunky tan rib-like rings fused around the upper barrel, dark navy collar and a dark brown wrapped grip.", {232, 213, 163}, true),
	item("B17", "Dragon Scale", "Bats", "Bat", "Level", 100, nil, "A long tapered baseball bat with a glossy emerald barrel clad in four broad overlapping rounded dragon-scale bands, golden end cap and collar, plum-purple grip and gold knob.", {71, 180, 119}),
	item("B18", "Breakfast Bonker", "Bats", "Bat", "Coins", 42000, nil, "A long baseball bat with a golden toasted waffle-patterned barrel, broad shallow 3-by-5 waffle grid following its rounded cylinder, a glossy caramel cap dripping a little onto the top third, cream butter-coloured rim.", {232, 170, 75}, true),
	item("B19", "Cloud Nine", "Bats", "Bat", "Level", 75, nil, "An elegant chunky baseball bat with a pearl-white rounded barrel, sky-blue lower taper, two broad embossed feather panels wrapping along the barrel and a lavender collar.", {225, 226, 255}),
	item("B20", "Bamboo Bruiser", "Bats", "Bat", "Wins", 100, "StuckInTheMud", "A recognisable baseball bat made of glossy jade-green bamboo-like segments, thick broad upper barrel and smoothly narrowing shaft, pale cream node bands, dark navy collar, tan rope-textured handgrip rendered as four simple broad wraps and flat green knob.", {121, 181, 93}),
	item("B21", "Arcade Combo", "Bats", "Bat", "Coins", 55000, nil, "A chunky baseball bat with a dark violet elongated cylindrical barrel with broad cyan edge rails and exactly three large glossy arcade buttons arranged lengthwise, red yellow and mint.", {90, 188, 247}, true),
	item("B22", "Honeycomb Hitter", "Bats", "Bat", "Coins", 70000, nil, "A warm amber baseball bat with a rounded barrel wrapped in five large golden hexagonal honeycomb panels, a few broad opaque golden honey drips moulded against its surface, cream tip cap, navy collar and black-and-yellow striped rubber grip.", {250, 196, 57}, true),
	item("B23", "Clockwork Clobber", "Bats", "Bat", "Coins", 85000, nil, "A copper and cream baseball bat with a long thick tapered barrel, two broad navy collars and one LARGE simple brass gear inset into the barrel side.", {192, 145, 85}, true),
	item("B24", "Patchwork Popper", "Bats", "Bat", "Level", 250, nil, "A long rounded baseball bat with purple and mint-green broad stitched fabric-like panels, simple cream cross stitches and one large round orange button mounted near the upper barrel.", {217, 122, 204}),
	item("B25", "Prism Champion", "Bats", "Bat", "Coins", 100000, nil, "A spectacular long baseball bat with an opaque faceted royal-purple and cyan crystal barrel, six broad flat facets, a blunt chamfered tip and two thick cream-and-gold reinforcing collars.", {119, 193, 243}, true),
	item("M16", "Snowglobe Sip", "Toys", "Gear", "Coins", 18000, nil, "Lobby only. Take a sip and release a cheerful flurry of snow sparkles. Cosmetic effect.", {127, 214, 245}, true),
	item("M17", "Snowball Lobber", "Toys", "Gear", "Coins", 33000, nil, "Lobby only. Fire a playful snowball with a throwing pose. Cosmetic shot; no freeze or damage.", {93, 162, 229}, true),
	item("M18", "Bubble Blower", "Toys", "Gear", "Coins", 22500, nil, "Lobby only. Blow a stream of floating cartoon bubbles. Cosmetic effect.", {246, 142, 196}, true),
	item("M19", "Slippy Banana", "Toys", "Gear", "Coins", 20000, nil, "Lobby only. Place a banana prop that disappears after 5 seconds. Cosmetic prop; no slipping.", {255, 216, 85}, true),
	item("M20", "Spring Glove", "Toys", "Gear", "Coins", 28000, nil, "Lobby only. Swing a spring glove with a sparkling bonk. Cosmetic effect; no damage or knockback.", {241, 112, 96}, true),
	item("M21", "Sticky Honey", "Toys", "Gear", "Coins", 30000, nil, "Lobby only. Toss a honey pot with a golden splat. Cosmetic effect; no slowing players.", {240, 180, 73}, true),
	item("M22", "Whoopee Whump", "Toys", "Gear", "Coins", 24000, nil, "Lobby only. Squeeze and shake a whoopee cushion with a playful puff. Cosmetic effect.", {242, 99, 103}, true),
	item("M23", "Magnet Mover", "Toys", "Gear", "Coins", 45000, nil, "Lobby only. Aim a chunky magnet and create a sparkling arc. Cosmetic effect; no pulling players.", {234, 94, 93}, true),
	item("M24", "Ricochet Flyer", "Toys", "Gear", "Coins", 60000, nil, "Lobby only. Throw a flyer that curves back toward you. Cosmetic effect.", {89, 211, 234}, true),
	item("M25", "Pop-Up Surprise", "Toys", "Gear", "Coins", 75000, nil, "Lobby only. Shake a surprise box to release colourful confetti. Cosmetic effect.", {237, 126, 105}, true),
	item("P21", "Crystal Drake", "Pets", "Pet", "Coins", 100000, nil, "A chubby sapphire-blue baby dragon with an oversized friendly head, two short ivory horns, lavender wing membranes, a pale blue belly, four sturdy little feet and a curled tail.", {89, 170, 239}, true),
	item("P22", "Ember Wyrmling", "Pets", "Pet", "Wins", 150, "StuckInTheMud", "A squat brick-red baby dragon with broad orange folded wings, cream segmented belly, rounded charcoal horns and a short tail with a solid orange flame-shaped fin.", {233, 111, 69}),
	item("P23", "Cloud Pegasus", "Pets", "Pet", "Level", 150, nil, "An adorable pearl-white miniature winged horse, rounded lavender mane and curled tail, sky-blue hooves, two thick feathered white wings attached at the shoulders and a small gold collar.", {223, 210, 248}),
	item("P24", "Suncrest Griffin", "Pets", "Pet", "Wins", 200, "BritishBulldog", "A chubby baby griffin with a cream eagle head, chunky golden beak, small swept-back gold head feathers, caramel lion body, stout golden front talons and rounded lion rear paws.", {237, 186, 85}),
	item("P25", "Halo Cherub", "Pets", "Pet", "Level", 250, nil, "One tiny angel companion pet with a round cream face, two shiny navy eyes, a tiny smiling mouth, a simple pale-blue bell-shaped robe/body, stubby hands and feet, and two attached layered ivory wings.", {254, 225, 157}),
	item("P26", "Pebble Triceratops", "Pets", "Pet", "Coins", 36000, nil, "A chubby turquoise baby triceratops with a huge rounded head frill edged in chunky cream knobs, two short blunt cream brow horns and one smaller nose horn, four squat legs and a short tail.", {184, 206, 126}, true),
	item("P27", "Fern Stegosaurus", "Pets", "Pet", "Coins", 42000, nil, "A cheerful moss-green baby stegosaurus with a plump low body, small round head, four squat cream-toed legs and two rows of five broad orange leaf-shaped dorsal plates attached to its back.", {109, 184, 108}, true),
	item("P28", "Sky Pterodactyl", "Pets", "Pet", "Level", 100, nil, "A cute lavender baby pterosaur standing with two little feet and compact partially open wings, a long rounded peach beak, a small backward swept head crest and shiny navy eyes.", {156, 187, 231}),
	item("P29", "Tundra Mammoth", "Pets", "Pet", "Coins", 75000, nil, "A tiny shaggy cinnamon-brown woolly mammoth with a huge round head, short lifted trunk, two short curved ivory tusks, small caramel ears and four stubby feet.", {187, 150, 118}, true),
	item("P30", "Crowned Pig", "Pets", "Pet", "Coins", 90000, nil, "A lovable plump PINK PIG wearing a prominent GOLD CROWN with three broad points and one red square jewel, a playful Minecraft king-pig homage interpreted as an original rounded cartoon pet.", {247, 173, 191}, true),
	item("P31", "Waffle Tortoise", "Pets", "Pet", "Coins", 48000, nil, "One adorable little golden tortoise whose thick square-rounded shell is a golden waffle with a very clear simple 3-by-3 grid of recessed pockets, a glossy caramel syrup patch and one thick pale-yellow butter square attached on top.", {224, 177, 87}, true),
	item("P32", "Pancake Pal", "Pets", "Pet", "Level", 75, nil, "A cute living stack of THREE thick fluffy golden pancakes as one compact pet, glossy caramel syrup draped over the top edge and a pale-yellow butter cube fixed on top.", {234, 182, 101}),
	item("P33", "Velvet Jumper", "Pets", "Pet", "Coins", 60000, nil, "One cute plush-like jumping spider, a single round plum-purple body and smaller attached head with two oversized glossy navy front eyes plus two tiny eyes above.", {155, 113, 200}, true),
	item("P34", "Patchwork Zombie", "Pets", "Pet", "Wins", 150, "TagYoureIt", "A silly friendly chibi zombie companion with a large square-rounded mint-green head, one button-shaped eye and one shiny navy eye, a big goofy smile with two chunky teeth.", {139, 189, 112}),
	item("P35", "Sunfeather Phoenix", "Pets", "Pet", "Level", 500, nil, "One adorable baby phoenix with a rounded orange body, huge expressive navy eyes, short gold beak and feet, three broad swept orange-and-yellow crest feathers, attached compact red wings, and a dramatic fan of THREE thick layered flame-shaped tail feathers in yellow, orange and red.", {249, 170, 55}),
}

local emoteAnimations = {}
for _, dance in ipairs({
	{ id = "E01", name = "Dougie", kind = "Coins", amount = 500, catalogId = 114756515400742, animationId = 93650537970037 },
	{ id = "E02", name = "Street Glide", kind = "Coins", amount = 750, catalogId = 137284968787523, animationId = 82378883639086 },
	{ id = "E03", name = "Money Hop Switch", kind = "Coins", amount = 1000, catalogId = 134222090358172, animationId = 132555082396072 },
	{ id = "E04", name = "Coffin Walkout", kind = "Level", amount = 5, catalogId = 117302755748327, animationId = 126771729094882 },
	{ id = "E05", name = "The Tylil Dance", kind = "Coins", amount = 1500, catalogId = 107010273569673, animationId = 110494040742516 },
	{ id = "E06", name = "Scuba Trend", kind = "Level", amount = 8, catalogId = 135211326811898, animationId = 140349022227594 },
	{ id = "E08", name = "Rollie", kind = "Coins", amount = 2000, catalogId = 110827382619943, animationId = 117558759116256 },
	{ id = "E09", name = "Out West", kind = "Coins", amount = 2500, catalogId = 133595410032960, animationId = 103687288237641 },
	{ id = "E10", name = "Four Lokos Dance", kind = "Level", amount = 12, catalogId = 115906496196760, animationId = 105190540415890 },
	{ id = "E11", name = "Griddy", kind = "Coins", amount = 5000, catalogId = 77017926307035, animationId = 81913798511136 },
	{ id = "E12", name = "Gangstar Dance", kind = "Coins", amount = 3000, catalogId = 84110142550799, animationId = 93941266454007 },
	{ id = "E13", name = "Keep It Gangsta", kind = "Level", amount = 16, catalogId = 100951835636163, animationId = 92659655601730 },
	{ id = "E14", name = "Jabba Switchway", kind = "Coins", amount = 3500, catalogId = 104940682593173, animationId = 78280967285254 },
	{ id = "E15", name = "Billy Bounce", kind = "Level", amount = 20, catalogId = 93450937830334, animationId = 119280135350752 },
	{ id = "E16", name = "Jamal Brazil Groove", kind = "Coins", amount = 4000, catalogId = 117119421748582, animationId = 106865236633450 },
	{ id = "E17", name = "67", kind = "Level", amount = 25, catalogId = 100498935359536, animationId = 108639244526475 },
	{ id = "E18", name = "Orange Justice", kind = "Coins", amount = 6500, catalogId = 110064349530772, animationId = 95127716920692 },
	{ id = "E19", name = "Dab Steps", kind = "Coins", amount = 4500, catalogId = 126353729413555, animationId = 104609460346094 },
	{ id = "E20", name = "Creepin Dance", kind = "Coins", amount = 5000, catalogId = 80985588930231, animationId = 95428460379424 },
	{ id = "E21", name = "Nervy Dance", kind = "Level", amount = 30, catalogId = 125328720114284, animationId = 90018336892195 },
	{ id = "E22", name = "Pretty Young Thing", kind = "Coins", amount = 7500, catalogId = 137234266130963, animationId = 108374677470972 },
	{ id = "E23", name = "Party Rock Anthem", kind = "Coins", amount = 10000, catalogId = 105248382902194, animationId = 134459607456762 },
	{ id = "E24", name = "Passinho do Jamal", kind = "Level", amount = 35, catalogId = 137057022541237, animationId = 100468196980144 },
	{ id = "E25", name = "Camden Bop", kind = "Coins", amount = 6000, catalogId = 86411651121424, animationId = 134644266320983 },
	{ id = "E26", name = "Every Beat", kind = "Level", amount = 40, catalogId = 134311528115559, animationId = 136095999219650 },
	{ id = "E27", name = "One Hand Push Ups", kind = "Coins", amount = 8000, catalogId = 121644855433565, animationId = 74800678690946 },
	{ id = "E28", name = "Gangnam Style", kind = "Coins", amount = 12500, catalogId = 80923445784018, animationId = 131104967711844 },
	{ id = "E29", name = "Murda Bend", kind = "Coins", amount = 9000, catalogId = 96843993997234, animationId = 90158235751747 },
	{ id = "E30", name = "Monkey", kind = "Level", amount = 3, catalogId = 3716636630, animationId = 10714388352 },
	{ id = "E31", name = "NLE Choppa Demon", kind = "Coins", amount = 15000, catalogId = 96181123599016, animationId = 133898543831391 },
	{ id = "E32", name = "Brazilian Dance", kind = "Level", amount = 50, catalogId = 76636280785091, animationId = 138980897636026 },
}) do
	local description = "Dance in the lobby. Move or jump to stop. Equip for your winner podium."
	local entry = item(dance.id, dance.name, "Emotes", "Emote", dance.kind, dance.amount, nil, description, {120, 193, 244})
	entry.catalogId = dance.catalogId
	entry.thumbnail = "rbxthumb://type=Asset&id=" .. string.format("%.0f", dance.catalogId) .. "&w=420&h=420"
	entry.playable = true
	entry.rigType = "R15"
	emoteAnimations[dance.id] = { R15AnimationId = dance.animationId }
	table.insert(items, entry)
end

table.insert(items, item("P36", "VIP Royal Dragon", "Pets", "Pet", "VIP", 0, nil,
	"A crowned golden dragon with ruby wings. Flies beside VIP players.", {255, 195, 53}))

local suppliedThumbnails = {
	["B16"] = "rbxassetid://93718576682762",
	["B17"] = "rbxassetid://90690876218946",
	["B18"] = "rbxassetid://136532648735315",
	["B19"] = "rbxassetid://74566241696564",
	["B20"] = "rbxassetid://89577365506241",
	["B21"] = "rbxassetid://87448555104310",
	["B22"] = "rbxassetid://121107988866639",
	["B23"] = "rbxassetid://124353995030650",
	["B24"] = "rbxassetid://122610247795492",
	["B25"] = "rbxassetid://84320288725225",
	["M16"] = "rbxassetid://137233677326237",
	["M17"] = "rbxassetid://100196340349310",
	["M18"] = "rbxassetid://108922005145390",
	["M19"] = "rbxassetid://138594944253005",
	["M20"] = "rbxassetid://113055348827876",
	["M21"] = "rbxassetid://87962378887990",
	["M22"] = "rbxassetid://87262880627267",
	["M23"] = "rbxassetid://72259913966212",
	["M24"] = "rbxassetid://71753510653959",
	["M25"] = "rbxassetid://70446171295062",
	["P21"] = "rbxassetid://102415565658167",
	["P22"] = "rbxassetid://124542948595389",
	["P23"] = "rbxassetid://136302530480282",
	["P24"] = "rbxassetid://83083028780532",
	["P25"] = "rbxassetid://112851232107682",
	["P26"] = "rbxassetid://106054275413428",
	["P27"] = "rbxassetid://98519809843976",
	["P28"] = "rbxassetid://83779715530699",
	["P29"] = "rbxassetid://92025994579959",
	["P30"] = "rbxassetid://134613010096847",
	["P31"] = "rbxassetid://119087155825550",
	["P32"] = "rbxassetid://133184161504265",
	["P33"] = "rbxassetid://77099692424415",
	["P34"] = "rbxassetid://139150635065122",
	["P35"] = "rbxassetid://124088547333228",
	["B01"] = "rbxassetid://103030924200276",
	["B02"] = "rbxassetid://113172886921867",
	["B03"] = "rbxassetid://125747852383163",
	["B04"] = "rbxassetid://127202176052176",
	["B05"] = "rbxassetid://96016591192959",
	["B06"] = "rbxassetid://128970507196840",
	["B07"] = "rbxassetid://108736504252281",
	["B08"] = "rbxassetid://89882889964123",
	["B09"] = "rbxassetid://77618462621016",
	["B10"] = "rbxassetid://132453529736998",
	["B11"] = "rbxassetid://77939197144871",
	["B12"] = "rbxassetid://125123911675366",
	["B13"] = "rbxassetid://103460237585059",
	["B14"] = "rbxassetid://123941198531759",
	["B15"] = "rbxassetid://103777401073836",
	["P01"] = "rbxassetid://111151667063771",
	["P02"] = "rbxassetid://74489993061441",
	["P03"] = "rbxassetid://79432424395104",
	["P04"] = "rbxassetid://84237840954591",
	["P05"] = "rbxassetid://76813277166260",
	["P06"] = "rbxassetid://128747986158558",
	["P07"] = "rbxassetid://130019925281001",
	["P08"] = "rbxassetid://122488839946964",
	["P09"] = "rbxassetid://72876142531984",
	["P10"] = "rbxassetid://83399670130730",
	["P11"] = "rbxassetid://138937113451446",
	["P12"] = "rbxassetid://91507747886254",
	["P13"] = "rbxassetid://76111324896677",
	["P14"] = "rbxassetid://74049460609660",
	["P15"] = "rbxassetid://71646045256380",
	["P16"] = "rbxassetid://74938519999469",
	["P17"] = "rbxassetid://74706180338952",
	["P18"] = "rbxassetid://115725394692957",
	["P19"] = "rbxassetid://117853703978463",
	["P20"] = "rbxassetid://113206048566146",
	["M01"] = "rbxassetid://76461123342040",
	["M02"] = "rbxassetid://87689116244271",
	["M03"] = "rbxassetid://102723663713155",
	["M04"] = "rbxassetid://108236395872604",
	["M05"] = "rbxassetid://135585921369557",
	["M06"] = "rbxassetid://100391547251774",
	["M07"] = "rbxassetid://114996802464499",
	["M08"] = "rbxassetid://93885559186954",
	["M09"] = "rbxassetid://95787089363505",
	["M10"] = "rbxassetid://86928317634247",
	["M11"] = "rbxassetid://78326564646666",
	["M12"] = "rbxassetid://108447275819300",
	["M13"] = "rbxassetid://115194745550655",
	["M14"] = "rbxassetid://120473663146818",
	["M15"] = "rbxassetid://91563971609941",
}
for _, entry in ipairs(items) do
	if suppliedThumbnails[entry.id] then
		entry.thumbnail = suppliedThumbnails[entry.id]
		entry.thumbnailSource = "UI-512"
	end
end

local byId = {}
for _, entry in ipairs(items) do
	assert(byId[entry.id] == nil, "Duplicate catalog ID: " .. entry.id)
	assert(entry.price >= 0 and entry.price <= COIN_PRICE_CAP, "Catalog price exceeds the coin cap")
	byId[entry.id] = entry
end

byId.M09.toyActionPending = true
for index = 16, 25 do
	byId[string.format("M%02d", index)].cosmeticOnly = true
end

return {
	Items = items,
	ById = byId,
	Categories = { "All", "Bats", "Pets", "Toys", "Emotes" },
	EmoteAnimations = emoteAnimations,
	StarterBat = "B01",
	MaxCoinPrice = COIN_PRICE_CAP,
	MaxEquipmentCoinPrice = COIN_PRICE_CAP,
	MaxToySlots = 4,
	GameNames = { BritishBulldog = "British Bulldog", TagYoureIt = "Tag You're It", StuckInTheMud = "Stuck in the Mud", HideAndSeek = "Hide and Seek", All = "total" },
}
]==] },
}
local function fingerprint(source)
 source = string.gsub(source, "\r\n", "\n")
 local value = 0
 for index = 1, #source do value = (value * 31 + string.byte(source,index)) % 2147483647 end
 return value
end
local objects = {}
for _, entry in entries do
 local object = game
 for name in string.gmatch(entry.path, "[^.]+") do object = object:FindFirstChild(name) assert(object, "Missing " .. entry.path) end
 assert(object:IsA("LuaSourceContainer"), "Invalid script " .. entry.path)
 assert(fingerprint(object.Source) == entry.expected, "Source changed: " .. entry.path)
 objects[entry.path] = object
end
local storage = game:GetService("ServerStorage")
local backup = storage:FindFirstChild("HideAndSeekIntegrationBackup20261010")
if not backup then backup = Instance.new("Folder") backup.Name, backup.Parent = "HideAndSeekIntegrationBackup20261010",storage end
for _, entry in entries do
 local object = objects[entry.path]
 local snapshot = object:Clone()
 snapshot.Name = entry.path
 if snapshot:IsA("BaseScript") then snapshot.Enabled = false end
 snapshot.Parent = backup
 object.Source = entry.source
 object:SetAttribute("HideAndSeekIntegrated20261010",true)
end
return { patched = #entries, capabilitiesPreserved = true, backup = backup:GetFullName() }

