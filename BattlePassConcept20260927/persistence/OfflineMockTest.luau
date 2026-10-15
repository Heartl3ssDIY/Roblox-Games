-- Run as a Script with this folder in a blank Studio place. No API Services needed.
local Schema = require(script.Parent.ProfileSchema)
local Store = require(script.Parent.ProfileStore)
local Rewards = require(script.Parent.ProfileRewards)
local Actions = require(script.Parent.ProfileActions)
local MockBackend = require(script.Parent.MockBackend)

local function check(value, message)
    if not value then error(message, 2) end
end
local now = 1790540000
local backend = MockBackend.new()
local rewardTable = {
    [1] = {currency = "coins", amount = 125},
    [2] = {kind = "pack", rarity = "silver", amount = 1},
}
local function rewardAt(level, lane)
    if lane == "free" then return rewardTable[level] end
end
local unitData = {
    get = function(id)
        if id == "Yumcha" then return {id = id, name = "Yumcha", rarity = "Common"} end
    end,
}
local function makeStore(jobId, attempts)
    return Store.new(backend, {
        jobId = jobId,
        clock = function() return now end,
        sleep = function() end,
        maxAttempts = attempts or 3,
    })
end

-- New join, mutation, leave, rejoin.
local first = makeStore("first")
local ok = first:load(101)
check(ok, "new profile should load")
local before = first:snapshot(101)
check(before.playerData.coins == 1000, "new default coins")
check(before.seasonPass.completed == 0, "new pass default")
ok = first:mutate(101, function(profile)
    profile.playerData.unitXp.Yumcha = 17
    profile.playerData.arenaProgress.Tenkaichi.points = 20
    profile.playerData.masteryPoints.Yumcha = 45
    profile.rank.highestRank = "Gold"
    profile.rank.viewers = 7
    return true
end)
check(ok, "local mutation")
ok = first:close(101)
check(ok, "save on leave")
local second = makeStore("second")
ok = second:load(101)
check(ok, "rejoin should load")
local restored = second:snapshot(101)
check(restored.playerData.unitXp.Yumcha == 17, "unit XP survived")
check(restored.playerData.masteryPoints.Yumcha == 45, "mastery survived")
check(restored.playerData.arenaProgress.Tenkaichi.points == 20, "story survived")
check(restored.rank.highestRank == "Gold" and restored.rank.viewers == 7, "reserved stats survived")
ok = second:mutate(101, function(profile)
    profile.playerData.dailyWin.day = math.floor(now / 86400)
    profile.playerData.dailyWin.windowStart = profile.playerData.dailyWin.day * 86400
    profile.playerData.dailyWin.claimed[1] = true
    profile.playerData.claimedMilestones.Tenkaichi[20] = true
    return true
end)
check(ok, "claim flags updated")
ok = second:save(101, false)
check(ok, "claim flags saved")
check(second:snapshot(101).playerData.dailyWin.claimed["1"] == true, "daily claim normalized")
check(second:snapshot(101).playerData.claimedMilestones.Tenkaichi["20"] == true, "milestone claim normalized")

-- Three verified wins reach the first free tier exactly once.
for number = 1, 3 do
    local ticket = "test-ticket-" .. number
    local awarded, result = second:mutate(101, function(profile)
        return Actions.awardMatch(profile, {
            ticket = ticket, arena = "Tenkaichi", unitIds = {"Yumcha"}, outcome = "win",
        }, rewardAt, unitData, now)
    end)
    check(awarded and result.outcome == "win", "match reward " .. number)
end
local afterWins = second:snapshot(101)
check(afterWins.seasonPass.completed == 1, "three wins complete tier 1")
check(afterWins.seasonPass.creditedFreeThrough == 1, "free credit ledger")
check(afterWins.seasonPass.claimed.free["1"] == true, "claimed tier saved in profile")
local coins = afterWins.playerData.coins
check(afterWins.playerData.masteryPoints.Yumcha == 75, "match mastery added once per win")
local awarded = second:mutate(101, function(profile)
    return Actions.awardMatch(profile, {
        ticket = "test-ticket-3", arena = "Tenkaichi", unitIds = {"Yumcha"}, outcome = "win",
    }, rewardAt, unitData, now)
end)
check(awarded, "duplicate delivery should return recorded result")
check(second:snapshot(101).playerData.coins == coins, "duplicate delivery did not pay twice")

-- A forfeit removes only current tier XP, never the completed tier.
local storyBeforeForfeit = second:snapshot(101).playerData.arenaProgress.Tenkaichi.points
awarded = second:mutate(101, function(profile)
    return Actions.awardMatch(profile, {
        ticket = "test-ticket-forfeit", arena = "Tenkaichi", unitIds = {"Yumcha"}, outcome = "forfeit",
    }, rewardAt, unitData, now)
end)
check(awarded, "forfeit accepted")
check(second:snapshot(101).seasonPass.completed == 1, "forfeit did not delevel")
check(second:snapshot(101).playerData.arenaProgress.Tenkaichi.points == storyBeforeForfeit, "forfeit did not change story points")

-- An error after a successful UpdateAsync commit is recovered by write ID.
backend.afterCommitFailures = 1
ok = second:save(101, false)
check(ok, "ambiguous committed write should reconcile")
ok = second:close(101)
check(ok, "final close")
local third = makeStore("third")
ok = third:load(101)
check(ok, "second rejoin")
check(third:snapshot(101).seasonPass.claimed.free["1"] == true, "free reward ledger survived rejoin")
check(third:snapshot(101).playerData.coins == coins, "free reward not duplicated on rejoin")
check(third:snapshot(101).playerData.dailyWin.claimed["1"] == true, "daily claim survived rejoin")
check(third:snapshot(101).playerData.claimedMilestones.Tenkaichi["20"] == true, "milestone claim survived rejoin")

-- A failed load cannot create defaults or overwrite an existing profile.
backend.failures = 4
local failed = makeStore("failure", 2)
local loaded = failed:load(202)
check(not loaded and not failed:isReady(202), "failed load must fail closed")
check(backend.values["user:202"] == nil, "failed load must not save defaults")
backend.failures = 0

-- A second server cannot take an active session.
local rival = makeStore("rival")
loaded = rival:load(101)
check(not loaded, "active session lock")
ok = third:close(101)
check(ok, "release session")
loaded = rival:load(101)
check(loaded, "take over released session")
-- PlayerRemoving waits for an in-flight autosave before releasing the lease.
local racing
local waits = 0
racing = Store.new(backend, {
    jobId = "racing",
    clock = function() return now end,
    sleep = function()
        waits += 1
        racing.entries[303].saving = false
    end,
    maxAttempts = 2,
})
ok = racing:load(303)
check(ok, "racing profile load")
ok = racing:mutate(303, function(profile)
    profile.playerData.coins += 55
    return true
end)
check(ok, "racing profile mutation")
racing.entries[303].saving = true
ok = racing:close(303)
check(ok and waits > 0, "close waited for autosave")
check(backend.values["user:303"].playerData.coins == 1055, "close saved dirty value")
local held = Store.new(backend, {
    jobId = "held-close",
    clock = function() return now end,
    sleep = function() end,
    maxAttempts = 2,
})
ok = held:load(505)
check(ok, "held-close profile load")
ok = held:mutate(505, function(profile) profile.playerData.coins += 9; return true end)
check(ok, "held-close dirty profile")
held.entries[505].saving = true
local released = held:close(505)
check(not released and held.entries[505].closing == true, "close timeout retains profile")
local joinedDuringClose = held:load(505)
check(not joinedDuringClose, "same-server rejoin cannot receive a closing profile")
ok = held:saveAll(false)
check(ok and backend.values["user:505"].playerData.coins == 1000, "autosave skipped closing profile")
held.entries[505].saving = false
released = held:close(505)
check(released, "background retry can release held profile")
local heldRejoin = makeStore("held-rejoin")
ok = heldRejoin:load(505)
check(ok and heldRejoin:snapshot(505).playerData.coins == 1009, "held profile rejoined without lease delay")
-- All replies to a committed write may fail. Reconcile that exact write
-- before saving a newer mutation or releasing the session.
local uncertain = makeStore("uncertain", 2)
ok = uncertain:load(707)
check(ok, "uncertain profile load")
ok = uncertain:mutate(707, function(profile) profile.playerData.coins += 11; return true end)
check(ok, "uncertain first mutation")
backend.afterCommitFailures = 2
local firstWrite = uncertain:save(707, false)
check(not firstWrite and uncertain.entries[707].uncertainWrite ~= nil, "committed write left uncertain")
ok = uncertain:mutate(707, function(profile) profile.playerData.coins += 7; return true end)
check(ok, "new mutation after uncertain write")
ok = uncertain:close(707)
check(ok, "close reconciled committed write then saved newer state")
local recovered = makeStore("recovered")
ok = recovered:load(707)
check(ok and recovered:snapshot(707).playerData.coins == 1018, "uncertain write recovered without loss or duplicate")

local actions = makeStore("actions")
ok = actions:load(808)
check(ok, "action profile load")
ok = actions:mutate(808, function(profile)
    profile.playerData.masteryChips = 2
    profile.playerData.unitXp.Yumcha = 5
    profile.playerData.dailyWin.day = math.floor(now / 86400)
    profile.playerData.dailyWin.pending = {{packId = "bronze", day = profile.playerData.dailyWin.day, slot = 1}}
    profile.playerData.packInventory.bronze = 1
    return true
end)
check(ok, "action fixtures")
for _ = 1, 2 do
    ok = actions:mutate(808, function(profile)
        return Actions.applyUnique(profile, "boost-action-1", "BoostMastery", function(current)
            return Actions.boostMastery(current, "Yumcha", unitData)
        end)
    end)
    check(ok, "boost action or replay")
end
check(actions:snapshot(808).playerData.masteryChips == 1 and actions:snapshot(808).playerData.masteryPoints.Yumcha == 10, "boost replay charged once")
for _ = 1, 2 do
    ok = actions:mutate(808, function(profile)
        return Actions.applyUnique(profile, "daily-action-1", "ConsumeDailyPack", Actions.consumeDailyPack)
    end)
    check(ok, "daily action or replay")
end
local dailyAction = actions:snapshot(808).playerData
check(dailyAction.packInventory.bronze == 0 and #dailyAction.dailyWin.pending == 0 and dailyAction.dailyWin.claimed["1"] == true, "daily replay consumed once")
for _ = 1, 2 do
    ok = actions:mutate(808, function(profile)
        return Actions.applyUnique(profile, "level-action-1", "LevelUnit", function(current)
            return Actions.levelUnit(current, "Yumcha", unitData)
        end)
    end)
    check(ok, "level action or replay")
end
local levelAction = actions:snapshot(808).playerData
check(levelAction.unitLevels.Yumcha == 2 and levelAction.coins == 0 and levelAction.unitXp.Yumcha == 0, "level replay spent once")

-- Complete the live 50-tier free schedule, then rejoin and retry the last
-- match ticket. All credits are recorded in one atomic profile ledger.
local livePass = game:GetService("ReplicatedStorage"):WaitForChild("SeasonPassData"):Clone()
livePass.Parent = script.Parent
local productionPass = require(livePass)
local full = makeStore("full-season")
ok = full:load(404)
check(ok, "full-season profile load")
for number = 1, 150 do
    local issued, receipt = full:mutate(404, function(profile)
        return Actions.awardMatch(profile, {
            ticket = "season-ticket-" .. number, arena = "Tenkaichi", unitIds = {"Yumcha"}, outcome = "win",
        }, productionPass.reward, unitData, now)
    end)
    check(issued and receipt.outcome == "win", "full-season match " .. number .. ": " .. tostring(receipt))
end
local finished = full:snapshot(404)
local free = finished.seasonPass.freeCreditTotals
check(finished.seasonPass.completed == 50 and finished.seasonPass.creditedFreeThrough == 50, "all free tiers completed")
check(free.coins == 31375 and free.gems == 25 and free.masteryChips == 75, "free currency checksum")
check(free.packs.bronze == 10 and free.packs.silver == 4 and free.packs.gold == 1 and free.packs.diamond == 1, "free pack checksum")
check(finished.seasonPass.claimed.free["50"] == true, "last tier claimed")
ok = full:close(404)
check(ok, "full-season save and release")
local rejoined = makeStore("full-season-rejoin")
ok = rejoined:load(404)
check(ok, "full-season rejoin")
local beforeDuplicate = rejoined:snapshot(404)
local duplicate, duplicateReceipt = rejoined:mutate(404, function(profile)
    return Actions.awardMatch(profile, {
        ticket = "season-ticket-150", arena = "Tenkaichi", unitIds = {"Yumcha"}, outcome = "win",
    }, productionPass.reward, unitData, now)
end)
check(duplicate and duplicateReceipt.outcome == "win", "last match replay recognized")
local afterDuplicate = rejoined:snapshot(404)
check(afterDuplicate.playerData.coins == beforeDuplicate.playerData.coins, "duplicate match did not mint coins")
check(afterDuplicate.seasonPass.creditedFreeThrough == 50 and afterDuplicate.seasonPass.freeCreditTotals.coins == 31375, "free credits remained exact")
-- A verified server-side entitlement can retroactively credit the completed
-- paid track. No client action can set this flag in the production service.
ok = rejoined:mutate(404, function(profile) profile.seasonPass.premiumEntitled = true; return true end)
check(ok, "server entitlement set")
local paidAward, paidReceipt = rejoined:mutate(404, function(profile)
    return Actions.awardMatch(profile, {
        ticket = "season-ticket-paid", arena = "Tenkaichi", unitIds = {"Yumcha"}, outcome = "win",
    }, productionPass.reward, unitData, now)
end)
check(paidAward and paidReceipt.outcome == "win", "paid retroactive grant")
local paidSnapshot = rejoined:snapshot(404)
local paid = paidSnapshot.seasonPass.paidCreditTotals
check(paidSnapshot.seasonPass.creditedPaidThrough == 50 and paidSnapshot.seasonPass.claimed.paid["50"] == true, "paid ledger completed")
check(paid.coins == 80000 and paid.gems == 175 and paid.masteryChips == 125, "paid currency checksum")
check(paid.unitXp.Beeras == 50 and paidSnapshot.playerData.unitXp.Beeras == 50, "paid Beeras XP")
check(paid.packs.bronze == 18 and paid.packs.silver == 8 and paid.packs.gold == 10 and paid.packs.diamond == 5, "paid pack checksum")
check(paidSnapshot.playerData.unitUnlock.Beeras == "unlockable", "Beeras available in packs, not owned")
ok = rejoined:close(404)
check(ok, "paid save and release")
local paidRejoin = makeStore("paid-rejoin")
ok = paidRejoin:load(404)
check(ok, "paid rejoin")
local beforePaidReplay = paidRejoin:snapshot(404)
local replayed = paidRejoin:mutate(404, function(profile)
    return Actions.awardMatch(profile, {
        ticket = "season-ticket-paid", arena = "Tenkaichi", unitIds = {"Yumcha"}, outcome = "win",
    }, productionPass.reward, unitData, now)
end)
check(replayed, "paid match replay recognized")
local afterPaidReplay = paidRejoin:snapshot(404)
check(afterPaidReplay.playerData.coins == beforePaidReplay.playerData.coins, "paid duplicate did not mint coins")
check(afterPaidReplay.seasonPass.creditedPaidThrough == 50 and afterPaidReplay.seasonPass.paidCreditTotals.unitXp.Beeras == 50, "paid ledger unchanged after rejoin")

print("[ProfileMockTest] all checks passed")
