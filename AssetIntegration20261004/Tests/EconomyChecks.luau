local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
assert(not game:GetService("RunService"):IsRunning(), "Run these checks in edit mode only")

local folder = Instance.new("Folder")
folder.Name = "PlaygroundEconomyChecks_" .. game:GetService("HttpService"):GenerateGUID(false)
folder.Parent = ServerStorage
local catalogCopy = ReplicatedStorage.PlaygroundCatalog:Clone()
catalogCopy.Name = "Catalog"
catalogCopy.Parent = folder
local economyCopy = ServerScriptService.PlaygroundEconomyService:Clone()
economyCopy.Name = "Economy"
economyCopy.Source = economyCopy.Source:gsub('local Catalog = require%(ReplicatedStorage:WaitForChild%("PlaygroundCatalog"%)%)', 'local Catalog = require(script.Parent.Catalog)', 1)
economyCopy.Parent = folder

local passed = {}
local success, result = xpcall(function()
	local Catalog = require(catalogCopy)
	local Economy = require(economyCopy)
	local function check(name, condition)
		assert(condition, name)
		table.insert(passed, name)
	end
	local function fakePlayer(id)
		local player = { UserId = id, Parent = Players, Attributes = {} }
		function player:SetAttribute(key, value) self.Attributes[key] = value end
		function player:GetAttribute(key) return self.Attributes[key] end
		function player:FindFirstChild() return nil end
		return player
	end
	local function service()
		local lobby = {}
		function lobby:GetAttribute(name)
			return ({ BaseLevelXP = 200, LevelXPStep = 50, WinnerCoins = 150, LoserCoins = 50, WinnerXP = 50, LoserXP = 50 })[name]
		end
		local economy = setmetatable({ lobby = lobby, profiles = {}, awarded = {}, isStudio = true, sessionOnly = false, sessionId = "economy-check" }, Economy)
		function economy:_applyAppearance() end
		return economy
	end
	local function profile(economy, id, saved)
		local player = fakePlayer(id)
		local data = { player = player, data = Economy.CleanData(saved), ready = true, version = 0, lastStatus = -math.huge, lastMutation = -math.huge, lastExpression = -math.huge }
		economy.profiles[player] = data
		return player, data
	end
	local function request(economy, player, action, id)
		economy.profiles[player].lastMutation = -math.huge
		economy.profiles[player].lastStatus = -math.huge
		return economy:Handle(player, action, id)
	end

	check("50 imported items in catalog", #Catalog.Items == 50)
	local counts, seen = {}, {}
	for _, item in ipairs(Catalog.Items) do
		check("unique ID " .. item.id, not seen[item.id])
		seen[item.id] = true
		counts[item.category] = (counts[item.category] or 0) + 1
		assert(item.price >= 0 and item.price <= 10000 and item.price % 1 == 0, item.id .. " coin price")
		assert(item.unlock.kind == "Coins" or item.price == 0, item.id .. " reward price")
		if item.category == "Toys" then assert(item.unlock.kind == "Coins" and item.slot == "Gear", item.id .. " toy rule") end
	end
	check("15 bats, 20 pets, 15 coin toys", counts.Bats == 15 and counts.Pets == 20 and counts.Toys == 15)
	check("Mudslinger requires exactly 25 Mud wins", Catalog.ById.B06.unlock.kind == "Wins" and Catalog.ById.B06.unlock.amount == 25 and Catalog.ById.B06.unlock.gameId == "StuckInTheMud")
	local clean = Economy.CleanData({ Version = 2, Coins = 321, XP = 1100, Wins = 42, Owned = { OldPet = true }, Equipped = { Pet = "OldPet" } })
	check("migration preserves balance, XP and total wins", clean.Coins == 321 and clean.XP == 1100 and clean.Wins == 42)
	check("migration preserves old owned and equipped IDs", clean.Owned.OldPet == true and clean.Equipped.Pet == "OldPet")
	check("migration gives starter bat", clean.Owned.B01 and clean.Equipped.Bat == "B01")
	check("migration does not invent per-game wins", clean.GameWins.BritishBulldog == 0 and clean.GameWins.TagYoureIt == 0 and clean.GameWins.StuckInTheMud == 0)
	check("explicit bat unequip survives v3 save", Economy.CleanData({ Version = 3, Owned = { B01 = true }, Equipped = {} }).Equipped.Bat == nil)
	local corrupt = Economy.CleanData({ Coins = math.huge, XP = 0 / 0, Wins = -8, GameWins = { StuckInTheMud = "999", TagYoureIt = 7.8 } })
	check("malformed numeric values are sanitized", corrupt.Coins == 0 and corrupt.XP == 0 and corrupt.Wins == 0 and corrupt.GameWins.StuckInTheMud == 0 and corrupt.GameWins.TagYoureIt == 7)
	local level, progress, required = Economy.CalculateLevelProgress(199, 200, 50)
	check("level 1 requires 200 XP", level == 1 and progress == 199 and required == 200)
	level, progress, required = Economy.CalculateLevelProgress(200, 200, 50)
	check("200 XP reaches level 2", level == 2 and progress == 0 and required == 250)
	level, progress, required = Economy.CalculateLevelProgress(450, 200, 50)
	check("450 XP reaches level 3", level == 3 and progress == 0 and required == 300)
	level, progress, required = Economy.CalculateLevelProgress(3600, 200, 50)
	check("3600 XP reaches level 10", level == 10 and progress == 0 and required == 650)

	local economy = service()
	local player, data = profile(economy, 1001, { Coins = 10000, XP = 0, Wins = 24, GameWins = { StuckInTheMud = 24 } })
	local reply = request(economy, player, "Buy", "B06")
	check("coins cannot bypass a win reward", not reply.ok and data.data.Coins == 10000 and not data.data.Owned.B06)
	reply = request(economy, player, "Buy", "B03")
	check("coins cannot bypass a level reward", not reply.ok and not data.data.Owned.B03)
	reply = request(economy, player, "Equip", "B12")
	check("unowned item cannot be equipped", not reply.ok and data.data.Equipped.Bat == "B01")
	reply = request(economy, player, "Buy", "B11")
	check("maximum-price purchase charges exactly 10000", reply.ok and data.data.Coins == 0 and data.data.Owned.B11 and data.data.Equipped.Bat == "B11")
	reply = request(economy, player, "Buy", "B11")
	check("duplicate purchase cannot charge again", not reply.ok and data.data.Coins == 0)
	reply = request(economy, player, "Buy", "M01")
	check("insufficient funds cannot purchase", not reply.ok and not data.data.Owned.M01 and data.data.Coins == 0)
	local player2, data2 = profile(economy, 1002, { Coins = 0 })
	local player3, data3 = profile(economy, 1003, { Coins = 0 })
	local count = economy:AwardRound("MUD:100", { 1001, 1001, 1003 }, false, { 1001, 1001, 1002 }, { gameId = "StuckInTheMud" })
	check("unique participants rewarded once", count == 2 and data.data.Coins == 150 and data2.data.Coins == 50)
	check("winner gains 50 XP and a Mud win", data.data.XP == 50 and data.data.Wins == 25 and data.data.GameWins.StuckInTheMud == 25)
	check("loser gains XP but no win", data2.data.XP == 50 and data2.data.Wins == 0 and data2.data.GameWins.StuckInTheMud == 0)
	check("nonparticipant cannot receive a winner reward", data3.data.Coins == 0 and data3.data.Wins == 0)
	check("25th Mud win auto-grants Mudslinger", data.data.Owned.B06 == true)
	check("progression reward does not replace equipped choice", data.data.Equipped.Bat == "B11")
	check("reward publishes authoritative inventory revision", player.Attributes.PCInventoryVersion == data.version and player.Attributes.PCWinsStuckInTheMud == 25)
	check("duplicate round cannot pay again", economy:AwardRound("MUD:100", { 1001 }, false, { 1001 }, { gameId = "StuckInTheMud" }) == 0 and data.data.Coins == 150)
	check("practice rounds do not grant progression", economy:AwardRound("MUD:101", { 1001 }, true, { 1001 }, { gameId = "StuckInTheMud" }) == 0 and data.data.GameWins.StuckInTheMud == 25)
	economy:AwardRound("TAG:102", { 1001 }, false, { 1001 })
	check("legacy trusted prefix records Tag wins", data.data.GameWins.TagYoureIt == 1 and data.data.GameWins.StuckInTheMud == 25)
	local status = economy:Status(player, true)
	check("status exposes accurate unlock progress", status.unlocks.B06.owned and status.unlocks.B06.progress == 25 and status.unlocks.B06.target == 25 and status.unlocks.B03.progress == 1)
	check("status tables do not alias saved data", status.owned ~= data.data.Owned and status.gameWins ~= data.data.GameWins)
	local levelPlayer, levelData = profile(economy, 1004, { XP = 1050 })
	economy:AwardRound("BB:200", { 1004 }, false, { 1004 }, { gameId = "BritishBulldog" })
	check("level boundary grants earned bat and pet rewards", levelData.data.XP == 1100 and levelData.data.Owned.B03 and levelData.data.Owned.P02)
	check("Bulldog wins update only their game counter", levelData.data.GameWins.BritishBulldog == 1 and levelData.data.GameWins.StuckInTheMud == 0)
	local _, veteran = profile(economy, 1005, { Wins = 100, XP = 3600 })
	economy:_touch(veteran)
	check("existing total wins and levels unlock earned rewards", veteran.data.Owned.P20 and veteran.data.Owned.B03 and veteran.data.Owned.B05)
	check("historical total wins cannot grant Mud reward", not veteran.data.Owned.B06)

	local persistent = service()
	persistent.isStudio = false
	local saved = { Version = 2, Coins = 900, Wins = 12, XP = 450, Owned = { LegacyToy = true }, Equipped = {}, GameWins = { StuckInTheMud = 7 } }
	persistent.store = {}
	function persistent.store:UpdateAsync(_, callback)
		local nextValue = callback(saved)
		if nextValue ~= nil then saved = nextValue end
		return nextValue
	end
	local savedPlayer, savedProfile = profile(persistent, 1010)
	savedProfile.ready = false
	check("claim uses existing datastore profile", persistent:_claim(savedProfile) and savedProfile.data.Coins == 900 and savedProfile.data.Owned.LegacyToy)
	check("claim installs current session lease", saved.Session.Id == persistent.sessionId and saved.Session.Expires > os.time())
	savedProfile.data.GameWins.StuckInTheMud = 25
	persistent:_touch(savedProfile)
	check("save persists game wins and unlocks", persistent:_save(savedProfile, false) and saved.GameWins.StuckInTheMud == 25 and saved.Owned.B06 and saved.Owned.LegacyToy)
	check("save retains session lease", saved.Session.Id == persistent.sessionId)
	check("release saves and clears its own lease", persistent:_save(savedProfile, true) and saved.Session == nil and savedProfile.released == true)
	saved.Session = { Id = "another-server", Expires = os.time() + 180 }
	local _, contested = profile(persistent, 1011)
	contested.ready = false
	check("unexpired foreign lease blocks profile claim", not persistent:_claim(contested) and not contested.ready and saved.Session.Id == "another-server")
	local calls = 0
	function persistent.store:UpdateAsync() calls += 1 error("Unready profile attempted a datastore write") end
	check("failed load cannot save starter defaults", persistent:_save(contested, false) and calls == 0)
	check("failed load cannot release another lease", persistent:_save(contested, true) and calls == 0)
	persistent:_sync(contested)
	check("unready profile cannot publish equipped cosmetics", contested.player.Attributes.PCBat == "" and contested.player.Attributes.PCPet == "" and contested.player.Attributes.PCGear == "")
	local _, tampered = profile(economy, 1012)
	tampered.data.Equipped.Bat = "B12"
	economy:_sync(tampered)
	check("unowned equipped entry is not published", tampered.player.Attributes.PCBat == "")
	return { passed = #passed, checks = passed, catalogItems = #Catalog.Items, playStarted = false }
end, debug.traceback)

folder:Destroy()
assert(success, result)
return result
