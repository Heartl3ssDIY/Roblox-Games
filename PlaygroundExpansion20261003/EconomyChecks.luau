local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local source = ServerScriptService:FindFirstChild("PlaygroundEconomyService")
assert(source and source:IsA("ModuleScript"), "Economy module must be installed first")
local copy = source:Clone()
copy.Name = "PlaygroundEconomyFixtureModule"
copy.Parent = ServerScriptService
local Economy = require(copy)
local Catalog = require(ReplicatedStorage:WaitForChild("PlaygroundCatalog"))
local lobby = workspace:FindFirstChild("Playground Lobby")
assert(lobby and lobby.Gameplay.LobbyBounds, "Lobby must be installed first")

local results, cleanups = {}, {copy}
local function check(name, condition, details)
	assert(condition, name .. " failed: " .. tostring(details))
	table.insert(results, {name = name, ok = true, details = details})
end

local function clone(value)
	if typeof(value) ~= "table" then return value end
	local result = {}
	for key, entry in pairs(value) do result[key] = clone(entry) end
	return result
end

local function store(initial)
	local fake = {values = clone(initial or {}), writes = 0, transforms = 0}
	function fake:UpdateAsync(key, transform)
		self.transforms += 1
		local value = transform(clone(self.values[key]))
		if value == nil then return nil end
		self.writes += 1
		self.values[key] = clone(value)
		if self.afterWrite then self.afterWrite(key, value) end
		return clone(value)
	end
	return fake
end

local function player(id)
	local attrs = {}
	local board = Instance.new("Folder")
	board.Name = "leaderstats"
	table.insert(cleanups, board)
	local added = Instance.new("BindableEvent")
	table.insert(cleanups, added)
	local adapter = {UserId = id, Name = "EconomyFixture" .. id, DisplayName = "Fixture", Parent = Players, CharacterAdded = added.Event}
	function adapter:SetAttribute(name, value) attrs[name] = value end
	function adapter:GetAttribute(name) return attrs[name] end
	function adapter:FindFirstChild(name) return name == "leaderstats" and board or nil end
	return adapter
end

local function service(fakeStore, id)
	local value = Economy.new(lobby, fakeStore, false)
	value.sessionId = "FixtureSession" .. id
	table.insert(cleanups, value.effects)
	return value
end

local function profile(value, adapter, data)
	local result = {player = adapter, data = Economy.CleanData(data), ready = true, version = 0, dirty = false, pickups = {}, connections = {}, lastMutation = -math.huge, lastStatus = -math.huge, lastExpression = -math.huge}
	value.profiles[adapter] = result
	return result
end

local function action(value, record, actionName, id)
	record.lastMutation = -math.huge
	record.lastStatus = -math.huge
	return value:Handle(record.player, actionName, id)
end

local success, failure = xpcall(function()
	check("Exactly 12 authored catalog items", #Catalog.Items == 12, #Catalog.Items)
	local ids = {}
	for _, item in ipairs(Catalog.Items) do
		check(item.id .. " unique server catalog entry", not ids[item.id] and Catalog.ById[item.id] == item)
		ids[item.id] = true
		check(item.id .. " price is a nonnegative integer", typeof(item.price) == "number" and item.price >= 0 and item.price % 1 == 0)
	end
	check("Unimplemented gear unavailable", Catalog.ById.SnowPotion.available == false and Catalog.ById.StarWand.available == false)
	local sanitized = Economy.CleanData({Coins = 0 / 0, Wins = -50, XP = math.huge, Owned = {Wave = true, Heart = 1, [12] = true, [string.rep("x", 49)] = true}, Equipped = {Emote = "Wave", Pet = "Wave", Highlight = "SkyOutline"}})
	check("Invalid balances and XP sanitized", sanitized.Coins == 0 and sanitized.Wins == 0 and sanitized.XP == 0)
	check("Legacy profile migration defaults XP", Economy.CleanData({Coins = 42, Wins = 2, Version = 1}).XP == 0 and Economy.CleanData({Coins = 42, Wins = 2}).Version == 2)
	check("XP integer and upper bound", Economy.CleanData({XP = 120.8}).XP == 120 and Economy.CleanData({XP = 1e20}).XP == 1000000000)
	check("Ownership booleans validated", sanitized.Owned.Wave and not sanitized.Owned.Heart and not sanitized.Owned[12] and not sanitized.Owned[string.rep("x", 49)])
	check("Equipped slot and ownership validated", sanitized.Equipped.Emote == "Wave" and not sanitized.Equipped.Pet and not sanitized.Equipped.Highlight)
	check("Balance cap", Economy.CleanData({Coins = math.huge, Wins = 1e20}).Coins == 0 and Economy.CleanData({Wins = 1e20}).Wins == 1000000000)
	local function levelCase(name, xp, base, step, expectedLevel, expectedWithin, expectedRequired)
		local level, within, required = Economy.CalculateLevelProgress(xp, base, step)
		check(name, level == expectedLevel and within == expectedWithin and required == expectedRequired, {level = level, within = within, required = required})
	end
	levelCase("Zero XP begins at level one", 0, 100, 50, 1, 0, 100)
	levelCase("First threshold minus one", 99, 100, 50, 1, 99, 100)
	levelCase("First exact threshold levels up", 100, 100, 50, 2, 0, 150)
	levelCase("Second threshold minus one", 249, 100, 50, 2, 149, 150)
	levelCase("Second exact threshold levels up", 250, 100, 50, 3, 0, 200)
	levelCase("Third threshold minus one", 449, 100, 50, 3, 199, 200)
	levelCase("Third exact threshold levels up", 450, 100, 50, 4, 0, 250)
	levelCase("Large XP calculates without a linear loop", 1000000000, 100, 50, 6324, 17550, 316250)
	levelCase("Flat XP curve supported", 250, 100, 0, 3, 50, 100)
	levelCase("Flat one-XP curve remains bounded", 1000000000, 1, 0, 1000000001, 0, 1)
	levelCase("Extreme step boundary supported", 1, 1, 1000000000, 2, 0, 1000000001)
	levelCase("Invalid XP and curve values sanitized", math.huge, 0 / 0, math.huge, 1, 0, 100)
	local cumulative = 0
	for index = 1, 20 do
		local required = 100 + 50 * (index - 1)
		cumulative += required
		levelCase("Summed exact threshold " .. index, cumulative, 100, 50, index + 1, 0, required + 50)
		levelCase("Summed threshold minus one " .. index, cumulative - 1, 100, 50, index, required - 1, required)
	end

	local liveStore = store({["u:810001"] = {Coins = 84, Wins = 3, Owned = {Wave = true}, Equipped = {Emote = "Wave"}, Session = {Id = "AnotherLiveServer", Expires = os.time() + 120}}})
	local liveService = service(liveStore, "LiveLease")
	local livePlayer = player(810001)
	local liveProfile = profile(liveService, livePlayer, nil)
	liveProfile.ready = false
	check("Active foreign lease blocks claim", not liveService:_claim(liveProfile))
	check("Blocked claim preserves profile and lease", liveStore.writes == 0 and liveStore.values["u:810001"].Coins == 84 and liveStore.values["u:810001"].Session.Id == "AnotherLiveServer")
	check("Blocked claim remains unready", not liveProfile.ready)

	local expiredStore = store({["u:810002"] = {Coins = 84, Wins = 3, XP = 175, Owned = {Wave = true}, Equipped = {Emote = "Wave"}, Session = {Id = "ExpiredServer", Expires = os.time() - 10}}})
	local expiredService = service(expiredStore, "ExpiredLease")
	local expiredPlayer = player(810002)
	local expiredProfile = profile(expiredService, expiredPlayer, nil)
	expiredProfile.ready = false
	check("Expired lease can be claimed", expiredService:_claim(expiredProfile))
	check("Claim preserves saved currency XP and ownership", expiredProfile.ready and expiredProfile.data.Coins == 84 and expiredProfile.data.Wins == 3 and expiredProfile.data.XP == 175 and expiredProfile.data.Owned.Wave and expiredProfile.data.Equipped.Emote == "Wave")
	check("Claim writes future lease", expiredStore.values["u:810002"].Session.Id == expiredService.sessionId and expiredStore.values["u:810002"].Session.Expires > os.time())
	expiredProfile.data.Coins = 120
	expiredProfile.version = 1
	expiredProfile.dirty = true
	check("Own lease saves", expiredService:_save(expiredProfile, false))
	check("Save renews own lease", expiredStore.values["u:810002"].Coins == 120 and expiredStore.values["u:810002"].Session.Id == expiredService.sessionId)
	check("XP persists in mocked profile save", expiredStore.values["u:810002"].XP == 175 and expiredStore.values["u:810002"].Version == 2)
	check("Unchanged saved version clears dirty", expiredProfile.dirty == false)
	check("Release saves and removes lease", expiredService:_save(expiredProfile, true) and expiredStore.values["u:810002"].Session == nil)

	local lostStore = store({["u:810003"] = {Coins = 600, Wins = 8, Owned = {}, Equipped = {}, Session = {Id = "NewOwnerServer", Expires = os.time() + 120}}})
	local lostService = service(lostStore, "LostLease")
	local lostPlayer = player(810003)
	local lostProfile = profile(lostService, lostPlayer, {Coins = 1})
	check("Save cannot overwrite another lease", not lostService:_save(lostProfile, false))
	check("Lease loss preserves external data", lostStore.writes == 0 and lostStore.values["u:810003"].Coins == 600)
	check("Lease loss disables mutation", not lostProfile.ready and not lostService:Handle(lostPlayer, "Buy", "Wave").ok)

	local departedStore = store()
	local departedService = service(departedStore, "DepartedClaim")
	local departedPlayer = player(810006)
	departedService.running = true
	departedStore.afterWrite = function()
		departedStore.afterWrite = nil
		local leaving = departedService.profiles[departedPlayer]
		leaving.closed = true
		departedPlayer.Parent = nil
		departedService.profiles[departedPlayer] = nil
	end
	departedService:_bindPlayer(departedPlayer)
	task.wait(0.02)
	check("Claim finishing after departure releases lease", departedStore.values["u:810006"] and departedStore.values["u:810006"].Session == nil)
	check("Stale claim cannot reinsert a removed profile", departedService.profiles[departedPlayer] == nil)
	departedService.running = false

	local duplicatePlayer = player(810007)
	local duplicateService = service(store(), "DuplicateBind")
	local originalProfile = profile(duplicateService, duplicatePlayer, {Coins = 99})
	duplicateService:_bindPlayer(duplicatePlayer)
	check("Duplicate bind preserves current profile", duplicateService.profiles[duplicatePlayer] == originalProfile and originalProfile.data.Coins == 99)

	local rewardService = service(store(), "RoundRewards")
	local settings = {WinnerCoins = 150, LoserCoins = 50, WinnerXP = 100, LoserXP = 25, BaseLevelXP = 100, LevelXPStep = 50}
	rewardService.lobby = {GetAttribute = function(_, name) return settings[name] end}
	local winner, loser, nonparticipant = player(810201), player(810202), player(810203)
	local disconnected, closed, unloaded, released = player(810204), player(810205), player(810206), player(810207)
	local winnerProfile = profile(rewardService, winner, {Coins = 10, Wins = 3, XP = 90})
	local loserProfile = profile(rewardService, loser, {Coins = 10, Wins = 3, XP = 90})
	local otherProfile = profile(rewardService, nonparticipant, {Coins = 10, Wins = 3, XP = 90})
	local disconnectedProfile = profile(rewardService, disconnected, {Coins = 10, Wins = 3, XP = 90})
	local closedProfile = profile(rewardService, closed, {Coins = 10, Wins = 3, XP = 90})
	local unloadedProfile = profile(rewardService, unloaded, {Coins = 10, Wins = 3, XP = 90})
	local releasedProfile = profile(rewardService, released, {Coins = 10, Wins = 3, XP = 90})
	disconnected.Parent = nil
	closedProfile.closed = true
	unloadedProfile.ready = false
	releasedProfile.released = true
	local paid = rewardService:AwardRound("Fixture:Completed", {winner.UserId, winner.UserId, nonparticipant.UserId}, false, {winner.UserId, loser.UserId, winner.UserId, disconnected.UserId, closed.UserId, unloaded.UserId, released.UserId, 1.5, math.huge, "810201"})
	check("Only eligible final participants rewarded", paid == 2)
	check("Winner receives coins win and XP", winnerProfile.data.Coins == 160 and winnerProfile.data.Wins == 4 and winnerProfile.data.XP == 190)
	check("Loser receives coins and XP without a win", loserProfile.data.Coins == 60 and loserProfile.data.Wins == 3 and loserProfile.data.XP == 115)
	check("Bogus nonparticipant winner cannot be rewarded", otherProfile.data.Coins == 10 and otherProfile.data.Wins == 3 and otherProfile.data.XP == 90)
	check("Disconnected profiles not rewarded", disconnectedProfile.data.Coins == 10 and disconnectedProfile.data.XP == 90)
	check("Closed unloaded and released profiles not rewarded", closedProfile.data.Coins == 10 and unloadedProfile.data.Coins == 10 and releasedProfile.data.Coins == 10)
	check("XP sync publishes level attributes", winner:GetAttribute("PCXP") == 190 and winner:GetAttribute("PCLevel") == 2 and winner:GetAttribute("PCLevelXP") == 90 and winner:GetAttribute("PCLevelXPRequired") == 150)
	check("Winner reward metadata accurate", winner:GetAttribute("PCRewardCoins") == 150 and winner:GetAttribute("PCRewardXP") == 100 and winner:GetAttribute("PCRewardWon") and winner:GetAttribute("PCRewardSerial") == 1)
	check("Loser reward metadata accurate", loser:GetAttribute("PCRewardCoins") == 50 and loser:GetAttribute("PCRewardXP") == 25 and not loser:GetAttribute("PCRewardWon") and loser:GetAttribute("PCRewardSerial") == 1)
	check("Completed round cannot pay twice", rewardService:AwardRound("Fixture:Completed", {winner.UserId}, false, {winner.UserId, loser.UserId}) == 0 and winnerProfile.data.Coins == 160 and loserProfile.data.Coins == 60)
	check("Duplicate payout does not publish new toast", winner:GetAttribute("PCRewardSerial") == 1 and loser:GetAttribute("PCRewardSerial") == 1)
	check("Practice awards no progression", rewardService:AwardRound("Fixture:Practice", {winner.UserId}, true, {winner.UserId, loser.UserId}) == 0 and winnerProfile.data.XP == 190 and loserProfile.data.XP == 115)
	check("Missing final roster cannot pay winners", rewardService:AwardRound("Fixture:MissingRoster", {winner.UserId}, false) == 0 and winnerProfile.data.Coins == 160)
	check("Empty final roster cannot pay", rewardService:AwardRound("Fixture:EmptyRoster", {winner.UserId}, false, {}) == 0)
	check("Invalid winner list cannot pay", rewardService:AwardRound("Fixture:InvalidWinners", nil, false, {winner.UserId}) == 0)
	check("Winner ids must intersect participants", rewardService:AwardRound("Fixture:InvalidWinner", {nonparticipant.UserId}, false, {winner.UserId, loser.UserId}) == 2 and winnerProfile.data.Coins == 210 and winnerProfile.data.Wins == 4 and loserProfile.data.Coins == 110 and otherProfile.data.Coins == 10)
	check("Every completed loser receives XP", winnerProfile.data.XP == 215 and loserProfile.data.XP == 140)
	settings.WinnerCoins, settings.LoserCoins = 170, 40
	settings.WinnerXP, settings.LoserXP = 80, 10
	settings.BaseLevelXP, settings.LevelXPStep = 80, 20
	check("Editable reward settings applied", rewardService:AwardRound("Fixture:Configured", {winner.UserId}, false, {winner.UserId, loser.UserId}) == 2 and winnerProfile.data.Coins == 380 and loserProfile.data.Coins == 150 and winnerProfile.data.XP == 295 and loserProfile.data.XP == 150)
	check("Editable level curve reflected in sync", winner:GetAttribute("PCLevel") == 3 and winner:GetAttribute("PCLevelXP") == 115 and winner:GetAttribute("PCLevelXPRequired") == 120)
	winnerProfile.data.Coins, winnerProfile.data.XP, winnerProfile.data.Wins = 999999990, 999999980, 1000000000
	check("Reward balances stay bounded", rewardService:AwardRound("Fixture:Cap", {winner.UserId}, false, {winner.UserId}) == 1 and winnerProfile.data.Coins == 1000000000 and winnerProfile.data.XP == 1000000000 and winnerProfile.data.Wins == 1000000000)
	check("Capped reward toast reports actual delta", winner:GetAttribute("PCRewardCoins") == 10 and winner:GetAttribute("PCRewardXP") == 20)

	local shopStore = store()
	local shopService = service(shopStore, "Shop")
	local shopper = player(810004)
	local record = profile(shopService, shopper, {Coins = 200})
	shopService._applyAppearance = function() end
	check("Unknown command rejected", not action(shopService, record, "GiveCoins", "Wave").ok and record.data.Coins == 200)
	check("Nonstrings rejected", not action(shopService, record, {}, "Wave").ok)
	check("Unknown item rejected", not action(shopService, record, "Buy", "UnknownItem").ok and record.data.Coins == 200)
	check("Nonstring item rejected", not action(shopService, record, "Buy", {}).ok and record.data.Coins == 200)
	check("Unavailable gear cannot be bought", not action(shopService, record, "Buy", "SnowPotion").ok and not record.data.Owned.SnowPotion)
	check("Unowned item cannot be equipped", not action(shopService, record, "Equip", "Wave").ok)
	check("Buy deducts server price and equips matching slot", action(shopService, record, "Buy", "Wave").ok and record.data.Coins == 170 and record.data.Owned.Wave and record.data.Equipped.Emote == "Wave")
	check("Duplicate purchase does not deduct coins", not action(shopService, record, "Buy", "Wave").ok and record.data.Coins == 170)
	record.lastMutation = -math.huge
	local first = shopService:Handle(shopper, "Buy", "Heart")
	local second = shopService:Handle(shopper, "Buy", "Star")
	check("Mutation cooldown prevents immediate repeated buy", first.ok and not second.ok and record.data.Coins == 145 and not record.data.Owned.Star)
	check("Status does not consume mutation cooldown", action(shopService, record, "GetStatus").ok and shopService:Handle(shopper, "Buy", "Star").ok)
	check("Status tables are copies", (function()
		local response = shopService:Status(shopper, true)
		response.owned.Wave = nil
		response.equipped.Emote = "Cheer"
		return record.data.Owned.Wave and record.data.Equipped.Emote == "Wave"
	end)())
	record.data.Coins = 0
	check("Insufficient funds cannot go negative", not action(shopService, record, "Buy", "Cheer").ok and record.data.Coins == 0 and not record.data.Owned.Cheer)
	check("Unequip validates category", not action(shopService, record, "Unequip", "Coins").ok)
	check("Unequip only removes selected slot", action(shopService, record, "Unequip", "Emoji").ok and record.data.Equipped.Emoji == nil and record.data.Equipped.Emote == "Wave")
	shopper:SetAttribute("BBParticipating", true)
	check("Emotes blocked during Bulldog", not action(shopService, record, "UseEmote", "Wave").ok)
	shopper:SetAttribute("BBParticipating", false)
	shopper:SetAttribute("TGParticipating", true)
	check("Emotes blocked during Tag", not action(shopService, record, "UseEmote", "Wave").ok)
	shopper:SetAttribute("TGParticipating", false)
	record.lastExpression = -math.huge
	check("Owned emote usable between rounds", action(shopService, record, "UseEmote", "Wave").ok and shopper:GetAttribute("PCEmoteAction") == "Wave" and shopper:GetAttribute("PCEmoteUntil") > workspace:GetServerTimeNow())
	check("Expression cooldown enforced", not action(shopService, record, "UseEmote", "Wave").ok)
	record.closed = true
	check("Closed profiles reject shopping", not action(shopService, record, "Equip", "Wave").ok)

	local coinsService = service(store(), "Coins")
	coinsService:_buildCoins()
	check("Coins created from ten markers", #coinsService.coins == 10)
	local collector = player(810005)
	local collectProfile = profile(coinsService, collector, {Coins = 0})
	local character = Instance.new("Model")
	character.Name = "EconomyFixtureCharacter"
	character.Parent = workspace
	table.insert(cleanups, character)
	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Anchored = true
	rootPart.CanCollide = false
	rootPart.Parent = character
	local humanoid = {Health = 100}
	collector.Character = {
		FindFirstChild = function(_, name) return name == "HumanoidRootPart" and rootPart or nil end,
		FindFirstChildOfClass = function(_, class) return class == "Humanoid" and humanoid or nil end,
	}
	local coin = coinsService.coins[1]
	local value = coin.marker:GetAttribute("Value")
	local cooldown = coin.marker:GetAttribute("RespawnSeconds")
	check("Coin metadata has positive integer value and cooldown", typeof(value) == "number" and value >= 1 and value % 1 == 0 and typeof(cooldown) == "number" and cooldown > 0)
	rootPart.Position = coin.marker.Position + Vector3.new(6, 0, 0)
	coinsService:_tick(0.16)
	check("Distant coin cannot be claimed", collectProfile.data.Coins == 0)
	rootPart.Position = coin.marker.Position
	collector:SetAttribute("TGParticipating", true)
	coinsService:_tick(0.16)
	check("Active round cannot farm lobby coins", collectProfile.data.Coins == 0)
	collector:SetAttribute("TGParticipating", false)
	humanoid.Health = 0
	coinsService:_tick(0.16)
	check("Dead characters cannot collect", collectProfile.data.Coins == 0)
	humanoid.Health = 100
	coinsService:_tick(0.16)
	check("Coin awards authored server value", collectProfile.data.Coins == value, collectProfile.data.Coins)
	check("Coin pickup does not grant XP", collectProfile.data.XP == 0 and collector:GetAttribute("PCRewardXP") == 0 and collector:GetAttribute("PCRewardCoins") == value)
	coinsService:_tick(0.16)
	check("Coin cannot be collected every heartbeat", collectProfile.data.Coins == value)
	collectProfile.pickups[coin.id] = workspace:GetServerTimeNow() - cooldown + 0.5
	coinsService:_tick(0.16)
	check("Coin cooldown not yet elapsed", collectProfile.data.Coins == value)
	collectProfile.pickups[coin.id] = workspace:GetServerTimeNow() - cooldown - 0.5
	coinsService:_tick(0.16)
	check("Coin becomes available after cooldown", collectProfile.data.Coins == value * 2)
	local outside = lobby.Gameplay.LobbyBounds.Position + Vector3.new(500, 0, 0)
	check("Lobby bounds reject distant positions", not coinsService:_inside(outside))

	local assets = ReplicatedStorage:WaitForChild("PlaygroundCosmeticAssets")
	for _, name in ipairs({"BubbleBee", "CloudPup"}) do
		local asset = assets:FindFirstChild(name)
		check(name .. " authored pet model", asset and asset:IsA("Model"))
		for _, descendant in ipairs(asset:GetDescendants()) do
			if descendant:IsA("BasePart") then
				check(name .. "/" .. descendant.Name .. " harmless cosmetic", descendant.Anchored and not descendant.CanCollide and not descendant.CanTouch and not descendant.CanQuery)
			elseif descendant:IsA("LuaSourceContainer") then
				error("Cosmetic assets must not contain executable scripts")
			end
		end
	end
	local appearanceService = service(store(), "Appearance")
	local appearancePlayer = player(810008)
	local appearanceProfile = profile(appearanceService, appearancePlayer, {Owned = {SkyOutline = true}, Equipped = {Highlight = "SkyOutline"}})
	local avatar = Instance.new("Model")
	avatar.Name = "EconomyFixtureAppearance"
	avatar.Parent = workspace
	table.insert(cleanups, avatar)
	local avatarRoot = Instance.new("Part")
	avatarRoot.Name = "HumanoidRootPart"
	avatarRoot.Anchored = true
	avatarRoot.Parent = avatar
	appearancePlayer.Character = avatar
	local roleOutline = Instance.new("Highlight")
	roleOutline.Name = "BritishBulldogHighlight"
	roleOutline.OutlineColor = Color3.fromRGB(255, 80, 80)
	roleOutline.Parent = avatar
	appearancePlayer:SetAttribute("BBParticipating", true)
	appearanceService:_applyAppearance(appearanceProfile)
	check("Cosmetic outline starts disabled during a game", avatar:FindFirstChild("PCOutline") and not avatar.PCOutline.Enabled)
	check("Cosmetic application preserves gameplay outline", roleOutline.Parent == avatar and roleOutline.Enabled)
	appearancePlayer:SetAttribute("BBParticipating", false)
	appearanceService:_tick(0.16)
	check("Cosmetic outline visible between rounds", avatar.PCOutline.Enabled)
	appearanceProfile.closed = true
	appearanceService:_clearAppearance(appearanceProfile)
	appearanceService:_applyAppearance(appearanceProfile)
	check("Closed profiles cannot recreate cosmetics", avatar:FindFirstChild("PCOutline") == nil)
end, debug.traceback)
for _, object in ipairs(cleanups) do
	pcall(function() object:Destroy() end)
end
if not success then error(failure) end
return {passed = #results, results = results, usedMockDataStoreOnly = true, externalProfileWrites = 0}
