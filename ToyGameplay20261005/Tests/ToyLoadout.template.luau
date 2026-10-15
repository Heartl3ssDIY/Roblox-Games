local clock = 100
local os = { clock = function() return clock end, time = function() return 1000 end }
local Color3 = { fromRGB = function(r, g, b) return { r, g, b } end }
local Catalog = (function()
-- CATALOG_SOURCE
end)()
local Players, ReplicatedStorage = {}, {}
local catalogModule = {}
function ReplicatedStorage:WaitForChild(name) assert(name == "PlaygroundCatalog") return catalogModule end
local services = { Players = Players, ReplicatedStorage = ReplicatedStorage, ServerStorage = {}, RunService = {}, DataStoreService = {}, HttpService = {}, Debris = {} }
local game = { GetService = function(_, name) return assert(services[name], name) end }
local workspace = { GetServerTimeNow = function() return clock end }
local require = function(module) assert(module == catalogModule) return Catalog end
local task = { wait = function(seconds) clock += seconds or 0 end }
local warn = function() end
local Economy = (function()
-- ECONOMY_SOURCE
end)()
local checks = {}
local function check(name, condition) assert(condition, name) table.insert(checks, name) end
local function same(actual, expected)
	if #actual ~= #expected then return false end
	for index, value in ipairs(expected) do if actual[index] ~= value then return false end end
	return true
end
local function owned(...)
	local result = {}
	for _, id in ipairs({ ... }) do result[id] = true end
	return result
end
local function clean(equipped, ownership, version)
	return Economy.CleanData({ Coins = 1200, Wins = 11, XP = 650, Owned = ownership or owned("M01", "M02", "M03", "M04", "M05", "M06", "B01", "P01"), Equipped = equipped, GameWins = { BritishBulldog = 7 }, Version = version or 3 })
end
check("catalog keeps fifty existing items", #Catalog.Items == 50)
check("catalog declares four toy slots", Catalog.MaxToySlots == 4)
check("pending launcher remains ownable and available", Catalog.ById.M09.toyActionPending == true and Catalog.ById.M09.available == true and Catalog.ById.M09.price == 4000)
check("all fifteen toys retain Gear slot and lobby descriptions", (function()
	for index = 1, 15 do
		local item = Catalog.ById[string.format("M%02d", index)]
		if not item or item.slot ~= "Gear" or item.category ~= "Toys" or item.description:find("Lobby", 1, true) ~= 1 then return false end
	end
	return true
end)())
local migrated = clean({ Gear = "M02", Bat = "B01", Pet = "P01" })
check("legacy Gear migrates into one active toy slot", same(migrated.Equipped.Toys, { "M02" }) and migrated.Equipped.ToyIndex == 1 and migrated.Equipped.Gear == "M02" and migrated.Equipped.Toy == "M02")
check("migration preserves balances progression and other equipment", migrated.Coins == 1200 and migrated.Wins == 11 and migrated.XP == 650 and migrated.GameWins.BritishBulldog == 7 and migrated.Equipped.Bat == "B01" and migrated.Equipped.Pet == "P01")
check("schema advances to version four", migrated.Version == 4)
check("legacy Toy alias migrates", clean({ Toy = "M03" }).Equipped.Gear == "M03")
check("valid Toy alias recovers invalid legacy Gear", clean({ Gear = "M99", Toy = "M03" }).Equipped.Gear == "M03")
check("unknown owned items remain owned for later migration", clean({}, { LegacyItem = true }).Owned.LegacyItem == true)
local invalid = clean({ Toys = { "M01", "M01", "P01", "B01", "M99", false, {}, "M02", "M03", "M04", "M05" }, ToyIndex = 8 })
check("loadout strips duplicates invalid IDs and cross-category items", same(invalid.Equipped.Toys, { "M01", "M02", "M03", "M04" }))
check("active ID survives compaction", invalid.Equipped.ToyIndex == 2 and invalid.Equipped.Gear == "M02")
check("unowned toy never migrates", #clean({ Gear = "M01" }, {}).Equipped.Toys == 0)
Catalog.ById.M02.available = false
check("unavailable toy never migrates", #clean({ Gear = "M02" }).Equipped.Toys == 0)
Catalog.ById.M02.available = true
check("explicit empty array stays empty despite stale Gear", #clean({ Toys = {}, Gear = "M01", ToyIndex = 1 }).Equipped.Toys == 0)
check("sparse saved slots compact safely", same(clean({ Toys = { [1] = "M01", [3] = "M03" }, ToyIndex = 3 }).Equipped.Toys, { "M01", "M03" }))
check("invalid active index falls back to first valid toy", clean({ Toys = { "M01", "M02" }, ToyIndex = math.huge }).Equipped.ToyIndex == 1)
check("empty data starts without a fabricated toy", #Economy.CleanData(nil).Equipped.Toys == 0 and Economy.CleanData(nil).Equipped.ToyIndex == 0)
check("existing bat migration still applies only to older profiles", Economy.CleanData({ Version = 2 }).Equipped.Bat == "B01" and Economy.CleanData({ Version = 3 }).Equipped.Bat == nil)
local twice = Economy.CleanData(migrated)
check("migration is idempotent", same(twice.Equipped.Toys, migrated.Equipped.Toys) and twice.Equipped.Gear == migrated.Equipped.Gear and twice.Equipped.ToyIndex == migrated.Equipped.ToyIndex)

local attributes, attributeWrites = {}, {}
local board = { Wins = { Value = 0 }, Level = { Value = 0 }, Coins = { Value = 0 } }
function board:FindFirstChild(name) return self[name] end
local player = { UserId = 123, Parent = Players }
function player:GetAttribute(name) return attributes[name] end
function player:SetAttribute(name, value) attributes[name] = value table.insert(attributeWrites, name) end
function player:FindFirstChild(name) return name == "leaderstats" and board or nil end
local lobby = { GetAttribute = function(_, name) return name == "BaseLevelXP" and 200 or name == "LevelXPStep" and 50 or nil end }
local economy = setmetatable({ lobby = lobby, profiles = {}, isStudio = false, sessionOnly = false, sessionId = "toy-test", awarded = {} }, Economy)
local profile = { player = player, data = clean({ Bat = "B01", Pet = "P01" }), ready = true, version = 0, lastMutation = -math.huge, lastStatus = -math.huge, lastExpression = -math.huge }
profile.data.Coins = 10000
economy.profiles[player] = profile
local function handle(action, id, wait)
	clock += wait == nil and 0.5 or wait
	return economy:Handle(player, action, id)
end
for index = 1, 4 do
	local id = string.format("M%02d", index)
	local response = handle("Equip", id)
	check("owned toy fills free slot " .. index, response.ok and #response.equipped.Toys == index and response.equipped.Toys[index] == id and response.equipped.ToyIndex == index and response.equipped.Gear == id)
end
check("toy slots never replace equipped Bat or Pet", profile.data.Equipped.Bat == "B01" and profile.data.Equipped.Pet == "P01")
local versionBefore = profile.version
local full = handle("Equip", "M05")
check("fifth equip fails without changing inventory or selection", not full.ok and full.message:find("full") ~= nil and #profile.data.Equipped.Toys == 4 and profile.data.Equipped.Gear == "M04" and profile.version == versionBefore)
local existing = handle("Equip", "M02")
check("equipping loaded toy selects it without duplication", existing.ok and #existing.equipped.Toys == 4 and existing.equipped.ToyIndex == 2)
local selected = handle("SelectToy", 4)
check("SelectToy action updates active Gear and Toy aliases", selected.ok and selected.equipped.Gear == "M04" and selected.equipped.Toy == "M04" and selected.toyLoadout.activeId == "M04")
check("server getters return validated active toy", economy:GetEquipped(player, "Toy") == "M04" and economy:GetEquipped(player, "Gear") == "M04" and economy:GetEquipped(player, "Bat") == "B01")
local snapshot = economy:Status(player, true)
snapshot.equipped.Toys[1] = "M15"
snapshot.toyLoadout.items[2] = "M14"
check("status arrays do not alias profile or each other", profile.data.Equipped.Toys[1] == "M01" and profile.data.Equipped.Toys[2] == "M02" and snapshot.toyLoadout.items[1] == "M01" and snapshot.equipped.Toys[2] == "M02")
local getter = economy:GetToyLoadout(player)
getter.items[1] = "M15"
check("loadout getter returns an independent array", profile.data.Equipped.Toys[1] == "M01")
check("server attributes expose all slots and active index", attributes.PCToySlot1 == "M01" and attributes.PCToySlot4 == "M04" and attributes.PCToyIndex == 4 and attributes.PCGear == "M04" and attributes.PCToy == "M04")
local serialPosition = table.find(attributeWrites, "PCToyLoadoutVersion")
check("loadout version publishes after slot and selection attrs", serialPosition > table.find(attributeWrites, "PCToySlot4") and serialPosition > table.find(attributeWrites, "PCToyIndex"))
for _, index in ipairs({ 0, 5, -1, 1.5, math.huge, 0 / 0, "1", false, {} }) do
	check("reject malformed selection " .. tostring(index), not handle("SelectToy", index).ok and profile.data.Equipped.Gear == "M04")
end
check("selection has existing remote mutation throttle", not handle("SelectToy", 1, 0).ok)
handle("SelectToy", 4)
local removed = handle("Unequip", "M02")
check("remove exact non-active toy keeps current active ID", removed.ok and same(removed.equipped.Toys, { "M01", "M03", "M04" }) and removed.equipped.Gear == "M04" and removed.equipped.ToyIndex == 3)
removed = handle("Unequip", "Gear")
check("legacy Gear unequip removes only active toy", removed.ok and same(removed.equipped.Toys, { "M01", "M03" }) and removed.equipped.Gear == "M03" and removed.equipped.ToyIndex == 2)
removed = handle("Unequip", "Toy")
check("Toy alias unequip removes only active toy", removed.ok and same(removed.equipped.Toys, { "M01" }) and removed.equipped.Gear == "M01")
removed = handle("Unequip", "M01")
check("removing last toy clears active aliases and attrs", removed.ok and #removed.equipped.Toys == 0 and removed.equipped.ToyIndex == 0 and removed.equipped.Gear == nil and attributes.PCGear == "" and attributes.PCToySlot1 == "")
check("empty slot cannot be selected", not handle("SelectToy", 1).ok)
check("unequipping missing toy does not fabricate slots", not handle("Unequip", "M02").ok and #profile.data.Equipped.Toys == 0)
check("unowned Equip is rejected", not handle("Equip", "M07").ok)
for index = 1, 4 do handle("Equip", string.format("M%02d", index)) end
local coinsBefore = profile.data.Coins
local bought = handle("Buy", "M07")
check("buy at full loadout grants ownership and debits exactly price", bought.ok and profile.data.Owned.M07 and profile.data.Coins == coinsBefore - Catalog.ById.M07.price)
check("full-loadout purchase leaves selection intact and explains next step", #bought.equipped.Toys == 4 and bought.equipped.Gear == "M04" and bought.message:find("full") ~= nil)
local again = handle("Buy", "M07")
check("repeat purchase cannot charge twice", not again.ok and profile.data.Coins == coinsBefore - Catalog.ById.M07.price)
for _, flag in ipairs({ "BBParticipating", "TGParticipating", "MDParticipating" }) do
	attributes[flag] = true
	check(flag .. " blocks selection equip and unequip", not handle("SelectToy", 1).ok and not handle("Equip", "M01").ok and not handle("Unequip", "M01").ok)
	attributes[flag] = nil
end
attributes.BBParticipating = true
handle("Unequip", "Pet")
check("lobby toy guard does not block other equipment changes", profile.data.Equipped.Pet == nil)
local lobbyPurchase = handle("Buy", "M08")
check("purchase during game grants ownership without activating toy", lobbyPurchase.ok and profile.data.Owned.M08 and profile.data.Equipped.Gear == "M04" and lobbyPurchase.message:find("lobby") ~= nil)
attributes.BBParticipating = nil
local okAdmin, adminMessage = economy:AdminGrantItem(player, "M09", true)
check("admin grant at full loadout succeeds honestly without replacing toy", okAdmin and profile.data.Owned.M09 and profile.data.Equipped.Gear == "M04" and adminMessage:find("full") ~= nil)
local adminVersion = profile.version
okAdmin = economy:AdminGrantItem(player, "M09", true)
check("existing admin item at full loadout reports failed equip without dirtying", not okAdmin and profile.version == adminVersion)
handle("Unequip", "M02")
okAdmin = economy:AdminGrantItem(player, "M09", true)
check("admin grant equip fills available slot", okAdmin and profile.data.Equipped.Gear == "M09" and #profile.data.Equipped.Toys == 4)
for _, state in ipairs({ "closed", "released" }) do
	profile[state] = true
	check(state .. " profile denies selection and returns no usable toys", not handle("SelectToy", 1).ok and not economy:SelectToySlot(player, 1) and economy:GetEquipped(player, "Toy") == nil and #economy:GetToyLoadout(player).items == 0 and not economy:Status(player, true).ready)
	profile[state] = nil
end
profile.ready = false
check("not-ready profile cannot select toy", not handle("SelectToy", 1).ok and not economy:SelectToySlot(player, 1))
economy:_sync(profile)
check("not-ready sync clears usable attributes", attributes.PCGear == "" and attributes.PCToyIndex == 0 and attributes.PCToySlot1 == "")
profile.ready = true
economy:_sync(profile)
local removedOwned = profile.data.Equipped.Toys[1]
profile.data.Owned[removedOwned] = nil
economy:_sync(profile)
check("ownership removal sanitizes live loadout", not table.find(profile.data.Equipped.Toys, removedOwned) and #profile.data.Equipped.Toys == 3)

local writes, row = 0, { Session = { Id = economy.sessionId, Expires = 1180 } }
economy.store = { UpdateAsync = function(_, key, transform)
	assert(key == "u:123")
	writes += 1
	local result = transform(row)
	if result then row = result end
	return result
end }
check("valid lease persists four-slot schema", economy:_save(profile, false) and row.Version == 4 and same(row.Equipped.Toys, profile.data.Equipped.Toys) and row.Equipped.Gear == profile.data.Equipped.Gear and row.Equipped.ToyIndex == profile.data.Equipped.ToyIndex)
local reloaded = { player = player, ready = false, data = Economy.CleanData(nil) }
check("claim loads saved toy slots and selection", economy:_claim(reloaded) and same(reloaded.data.Equipped.Toys, profile.data.Equipped.Toys) and reloaded.data.Equipped.Gear == profile.data.Equipped.Gear)
local rowBefore = row
row.Session = { Id = "other-session", Expires = 1180 }
check("foreign lease still prevents toy profile overwrite", not economy:_save(profile, false) and row == rowBefore and row.Session.Id == "other-session" and not profile.ready)
local foreign = { player = player, ready = false, data = Economy.CleanData(nil) }
check("claim does not fabricate loadout when foreign lease active", not economy:_claim(foreign) and not foreign.ready and #foreign.data.Equipped.Toys == 0)
local beforeNotReady = writes
check("failed-load profile never saves", economy:_save(foreign, false) and writes == beforeNotReady)
check("data-store tests use only in-memory adapter", writes == 4)
print("PASS " .. #checks .. " toy migration/loadout checks; local Luau, no Studio mutations or external data-store calls")
for _, name in ipairs(checks) do print("PASS " .. name) end
