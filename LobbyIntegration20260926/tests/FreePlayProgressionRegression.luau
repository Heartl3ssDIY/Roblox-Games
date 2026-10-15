local function loadData(source)
    local module, message = loadstring(source, "IsolatedPlayerData")
    assert(module, message)
    local environment = setmetatable({
        Instance = {new = function(className)
            assert(className == "BindableEvent", "Unexpected engine dependency")
            return {Event = {Connect = function() return {Disconnect = function() end} end}, Fire = function() end}
        end},
        os = setmetatable({time = function() return 1700000000 end}, {__index = os}),
    }, {__index = getfenv()})
    setfenv(module, environment)
    return module()
end

local function equal(a, b, label)
    assert(type(a) == type(b), label .. ": type changed")
    if type(a) ~= "table" then
        assert(a == b, label .. ": value changed")
        return
    end
    for key, value in pairs(a) do equal(value, b[key], label .. "." .. tostring(key)) end
    for key in pairs(b) do assert(a[key] ~= nil, label .. ": extra field " .. tostring(key)) end
end

return function(sources)
    local old, current = loadData(sources.before), loadData(sources.after)
    assert(not current.isArenaCompleted("Tenkaichi"), "Fresh arena starts unlocked")
    for count = 1, 9 do
        equal(old.recordResult("Tenkaichi", true), current.recordResult("Tenkaichi", true), "Story rewards")
        assert(not current.isArenaCompleted("Tenkaichi"), "Arena unlocked before reaching 100 points")
    end
    equal(old.recordResult("Tenkaichi", true), current.recordResult("Tenkaichi", true), "Completion rewards")
    assert(current.isArenaCompleted("Tenkaichi"), "100 points did not unlock arena")
    assert(not current.isArenaCompleted("Wano"), "Tenkaichi completion unlocked a different arena")
    for _ = 1, 12 do
        equal(old.recordResult("Tenkaichi", false), current.recordResult("Tenkaichi", false), "Loss rewards")
        assert(current.isArenaCompleted("Tenkaichi"), "Loss removed completion")
    end
    for _, key in ipairs({"coins", "gems", "masteryChips", "level", "xp", "arenaProgress", "claimedMilestones", "unitUnlock", "unitLevels", "unitXp", "unitLocks", "masteryPoints", "claimedLevels", "packInventory", "dailyWin", "dailyClaims"}) do
        equal(old.get(key), current.get(key), "Unchanged game data." .. key)
    end
    for _ = 1, 10 do current.recordResult("Wano", true); current.recordResult("Wano", false) end
    assert(current.arenaWins("Wano") == 10, "Fixture total wins wrong")
    assert(not current.isArenaCompleted("Wano"), "Raw lifetime wins bypassed point completion threshold")
    for _ = 1, 10 do current.recordResult("Wano", true) end
    assert(current.isArenaCompleted("Wano"), "Same-arena completion did not unlock Wano")
    assert(not current.isArenaCompleted("Marineford"), "Wano completion unlocked Marineford")

    local migration = loadData(sources.after)
    migration.get("arenaProgress").Tenkaichi = {points = 40, wins = 12, losses = 8}
    migration.get("claimedMilestones").Tenkaichi[100] = true
    local coins, gems = migration.coins(), migration.gems()
    assert(migration.isArenaCompleted("Tenkaichi"), "Claimed final milestone did not migrate completion")
    assert(migration.get("arenaProgress").Tenkaichi.completed == true, "Migration did not store sticky completion")
    assert(migration.arenaProgress("Tenkaichi").completed, "arenaProgress omitted migrated completion")
    assert(migration.coins() == coins and migration.gems() == gems, "Completion migration awarded currency again")
    assert(migration.arenaProgress("Tenkaichi").points == 40, "Migration changed points")
    migration.get("arenaProgress").Wano = {points = 100, wins = 10, losses = 0}
    migration.recordResult("Wano", false)
    assert(migration.isArenaCompleted("Wano"), "First legacy loss discarded previous 100-point completion")
    assert(migration.arenaProgress("Wano").points == 90, "Migration changed loss scoring")
    migration.get("arenaProgress").Marineford = {points = 90, wins = 9, losses = 0}
    migration.get("claimedMilestones").Marineford = {[40] = true}
    assert(not migration.isArenaCompleted("Marineford"), "Earlier milestone counted as completion")
    migration.get("claimedMilestones").Marineford["100"] = true
    assert(migration.isArenaCompleted("Marineford"), "Serialized final milestone key failed migration")

    local claimsOld, claimsNew = loadData(sources.before), loadData(sources.after)
    for _ = 1, 4 do equal(claimsOld.grantDailyWinPack(), claimsNew.grantDailyWinPack(), "Daily grant") end
    equal(claimsOld.pendingDailyPack(), claimsNew.pendingDailyPack(), "Pending daily pack")
    for _ = 1, 4 do equal(claimsOld.consumeDailyPack(), claimsNew.consumeDailyPack(), "Daily claim") end
    equal(claimsOld.get("packInventory"), claimsNew.get("packInventory"), "Pack balances")
    equal(claimsOld.get("dailyWin"), claimsNew.get("dailyWin"), "Daily claim state")
    return {passed = true, cases = 10, threshold = 100, sameArenaOnly = true, remainsCompletedAfterLoss = true,
        legacyMigration = true, currenciesAndRewardsUnchanged = true, dailyPackFlowUnchanged = true,
        scope = "Offline isolated local-state regression; this is session-only progress, not server-authoritative persistence."}
end
