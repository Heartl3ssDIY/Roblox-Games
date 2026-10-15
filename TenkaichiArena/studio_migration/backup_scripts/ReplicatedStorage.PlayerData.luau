--!strict
-- PlayerData: client-side source of truth for player progression.
-- (Not persisted to a DataStore yet — resets on rejoin. Save layer comes later.)
-- Holds currencies, account level/XP, per-arena win counts + unlock thresholds,
-- per-unit level/XP, and per-unit mastery points.

local PlayerData = {}

local changed = Instance.new("BindableEvent")
PlayerData.Changed = changed.Event
local function fire() changed:Fire() end

-- ── Currencies ────────────────────────────────────────────────────────────────
local state = {
	coins = 1000,          -- spent to upgrade unit levels (cost rises per level)
	gems = 100,            -- diamonds: spent on packs in the shop
	masteryChips = 0,      -- earned per match; spent in the Mastery tab

	-- Account level / progress "pass"
	level = 1,
	xp = 0,

	-- Per-arena progress (point system). +10 per win, -4 per loss (floored at 0).
	-- arenaProgress[arena] = { points, wins, losses }
	arenaProgress = {
		["West City"] = { points = 0, wins = 0, losses = 0 },
	},
	-- Which arena point-milestones have had their reward claimed (per arena).
	-- claimedMilestones[arena][points] = true
	claimedMilestones = { ["West City"] = {} },
	-- Unit unlock state: unitUnlock[id] = "locked" | "unlockable" | "owned".
	-- Units not present here are treated as already owned (the starter units).
	-- The two West City unlockables start locked.
	unitUnlock = {
		Bluma = "locked",
		Pikkolo = "locked",
	},

	-- Per-unit progression: unitLevels[id] = level, unitXp[id] = dupe-driven xp
	unitLevels = {},       -- defaults to 1 when missing
	unitXp = {},

	-- Per-unit mastery points: masteryPoints[id] = number
	masteryPoints = {},

	-- Which account-level rewards have been CLAIMED. claimedLevels[level] = true
	claimedLevels = {},

	-- Owned (unopened) packs the player can open later. packInventory[packId] = count
	packInventory = { bronze = 0, silver = 0, gold = 0 },

	-- Daily free-pack tracking. The first 4 WINS in a rolling 24h window each
	-- grant a pack (wins 1-3 = bronze, win 4 = silver). Window is anchored to
	-- the first win; after 24h elapses from that win, the next win re-arms it.
	dailyWin = { windowStart = 0, winsThisWindow = 0 },
}

-- ── Tunable curves / thresholds ───────────────────────────────────────────────
-- Arena milestone track. Each arena: currency rewards + 2 unit unlocks.
-- Milestones are checked against total points. unlockUnit ties a point total
-- to a specific unit id becoming "unlockable" (then pullable in packs).
local POINTS_PER_WIN = 10
local POINTS_PER_LOSS = -4
-- Mastery points needed to unlock a unit's FIRST mastery level, by rarity.
-- (Further levels / the mastery tree come later.)
local MASTERY_THRESHOLD = { Common = 40, Rare = 60, Epic = 80, Legendary = 100 }
local MASTERY_PER_MATCH = 10
local ARENA_MILESTONES = {
	["West City"] = {
		{ points = 25,  reward = { coins = 1000 } },
		{ points = 50,  unlockUnit = "Bluma" },
		{ points = 75,  reward = { gems = 10 } },
		{ points = 100, unlockUnit = "Pikkolo" },
	},
}

-- Account level XP requirement: gentle exponential (~1.25x per level).
function PlayerData.xpForLevel(level: number): number
	-- L1->2 needs 100; each subsequent level needs ~1.25x the previous.
	return math.floor(100 * (1.25 ^ (level - 1)) + 0.5)
end

-- ── Getters ───────────────────────────────────────────────────────────────────
function PlayerData.get(key: string) return state[key] end
function PlayerData.coins() return state.coins end
function PlayerData.gems() return state.gems end
function PlayerData.masteryChips() return state.masteryChips end
function PlayerData.level() return state.level end
function PlayerData.xp() return state.xp end
function PlayerData.xpNeeded() return PlayerData.xpForLevel(state.level) end

function PlayerData.unitLevel(id: string): number
	return state.unitLevels[id] or 1
end
function PlayerData.unitXp(id: string): number
	return state.unitXp[id] or 0
end
function PlayerData.masteryFor(id: string): number
	return state.masteryPoints[id] or 0
end
function PlayerData.arenaWins(arena: string): number
	local prog = state.arenaProgress[arena]
	return prog and prog.wins or 0
end

-- ── Currency mutators ─────────────────────────────────────────────────────────
function PlayerData.addCoins(n: number) state.coins = math.max(0, state.coins + n); fire() end
function PlayerData.addGems(n: number) state.gems = math.max(0, state.gems + n); fire() end
function PlayerData.addMasteryChips(n: number) state.masteryChips = math.max(0, state.masteryChips + n); fire() end
function PlayerData.spendCoins(n: number): boolean
	if state.coins < n then return false end
	state.coins -= n; fire(); return true
end
function PlayerData.spendGems(n: number): boolean
	if state.gems < n then return false end
	state.gems -= n; fire(); return true
end

-- ── Account XP / leveling ─────────────────────────────────────────────────────
-- Adds account XP, rolling over into levels. Returns how many levels gained.
function PlayerData.addXp(n: number): number
	state.xp += n
	local gained = 0
	while state.xp >= PlayerData.xpForLevel(state.level) do
		state.xp -= PlayerData.xpForLevel(state.level)
		state.level += 1
		gained += 1
	end
	fire()
	return gained
end

-- ── Arena points / milestones / unit unlocks ─────────────────────────────────
-- Record a match result in an arena. won=true -> +10pts, false -> -4pts (floored).
-- Grants any newly-crossed milestone rewards and flips units to "unlockable".
-- Returns a summary table for the UI.
function PlayerData.recordResult(arena: string, won: boolean)
	local prog = state.arenaProgress[arena]
	if not prog then prog = { points = 0, wins = 0, losses = 0 }; state.arenaProgress[arena] = prog end
	local claimed = state.claimedMilestones[arena]
	if not claimed then claimed = {}; state.claimedMilestones[arena] = claimed end

	local before = prog.points
	if won then prog.wins += 1 else prog.losses += 1 end
	prog.points = math.max(0, prog.points + (won and POINTS_PER_WIN or POINTS_PER_LOSS))
	local after = prog.points

	local result = {
		points = after, delta = after - before, won = won,
		wins = prog.wins, losses = prog.losses,
		coinsAwarded = 0, gemsAwarded = 0, unlockedUnits = {},
	}

	-- Only award milestones when crossing upward (points increased past them)
	-- and not already claimed. Losses never "unclaim" a milestone.
	local milestones = ARENA_MILESTONES[arena]
	if milestones and after > before then
		for _, ms in ipairs(milestones) do
			if after >= ms.points and not claimed[ms.points] then
				claimed[ms.points] = true
				if ms.reward then
					if ms.reward.coins then state.coins += ms.reward.coins; result.coinsAwarded += ms.reward.coins end
					if ms.reward.gems then state.gems += ms.reward.gems; result.gemsAwarded += ms.reward.gems end
				end
				if ms.unlockUnit then
					-- flip locked -> unlockable (don't downgrade an owned unit)
					if state.unitUnlock[ms.unlockUnit] ~= "owned" then
						state.unitUnlock[ms.unlockUnit] = "unlockable"
					end
					table.insert(result.unlockedUnits, ms.unlockUnit)
				end
			end
		end
	end

	fire()
	return result
end

-- Read arena progress for the UI: points, wins, losses, and the milestone track.
function PlayerData.arenaProgress(arena: string)
	local prog = state.arenaProgress[arena] or { points = 0, wins = 0, losses = 0 }
	return {
		points = prog.points, wins = prog.wins, losses = prog.losses,
		milestones = ARENA_MILESTONES[arena] or {},
	}
end

-- Unit unlock state helpers.
-- States: "locked" (not in pack pool), "unlockable" (pullable; first pull = own),
-- "owned" (in collection; further pulls = dupe xp). Unknown id = owned (starters).
function PlayerData.unitUnlockState(id: string): string
	return state.unitUnlock[id] or "owned"
end
function PlayerData.setUnitUnlockState(id: string, st: string)
	state.unitUnlock[id] = st
	fire()
end
-- Called when a unit is pulled from a pack the first time: own it.
function PlayerData.ownUnit(id: string)
	state.unitUnlock[id] = "owned"
	if (state.unitLevels[id] or 0) < 1 then state.unitLevels[id] = 1 end
	fire()
end

-- ── Unit mastery / level (dupe-driven) ────────────────────────────────────────
function PlayerData.addMasteryPoints(id: string, n: number)
	state.masteryPoints[id] = (state.masteryPoints[id] or 0) + n
	fire()
end
-- Mastery points required for a unit's first mastery level (by its rarity).
function PlayerData.masteryThreshold(rarity: string): number
	return MASTERY_THRESHOLD[rarity] or 40
end
-- Has this unit reached its first mastery level yet?
function PlayerData.masteryUnlocked(id: string, rarity: string): boolean
	return (state.masteryPoints[id] or 0) >= PlayerData.masteryThreshold(rarity)
end
PlayerData.MASTERY_PER_MATCH = MASTERY_PER_MATCH

-- ── Unit leveling (XP-card driven) ───────────────────────────────────────────
-- Cards add unit-specific XP (1 card = 1 XP). A unit auto-levels when it has
-- enough XP for the next level. XP carries over (counts from 0 toward the next).
-- Base XP to reach L2 by rarity; each subsequent level needs DOUBLE the last.
-- Max level 15 (then prestige, later).
local UNIT_BASE_XP = { Common = 5, Rare = 10, Epic = 20, Legendary = 25 }
local UNIT_MAX_LEVEL = 15

-- XP required to go from `level` to `level+1` for a unit of `rarity`.
-- base * 2^(level-1): Common L1->2 = 5, L2->3 = 10, L3->4 = 20, ...
function PlayerData.unitXpForLevel(rarity: string, level: number): number
	local base = UNIT_BASE_XP[rarity] or 5
	return base * (2 ^ (level - 1))
end

-- On level-up: HP and damage each compound +10% off the CURRENT stat, rounded
-- to the nearest whole number. Returns the new stat.
function PlayerData.boostStat(current: number): number
	return math.floor(current * 1.10 + 0.5)
end

-- Effective HP/damage for a unit at its current level (compounded from base).
function PlayerData.unitStats(id: string, baseHealth: number, baseDamage: number)
	local lvl = PlayerData.unitLevel(id)
	local hp, dmg = baseHealth, baseDamage
	for _ = 2, lvl do
		hp = PlayerData.boostStat(hp)
		dmg = PlayerData.boostStat(dmg)
	end
	return hp, dmg
end

-- Add unit-specific XP (from cards). Fills the meter; does NOT auto-level.
-- The meter can overfill (excess banks for the next level after upgrading).
function PlayerData.addUnitXp(id: string, n: number)
	state.unitXp[id] = (state.unitXp[id] or 0) + n
	fire()
end

-- XP progress toward the next level: returns current, needed (or nil if maxed).
function PlayerData.unitXpProgress(id: string, rarity: string)
	local lvl = PlayerData.unitLevel(id)
	if lvl >= UNIT_MAX_LEVEL then return state.unitXp[id] or 0, nil end
	return state.unitXp[id] or 0, PlayerData.unitXpForLevel(rarity, lvl)
end

-- Is the unit's meter full enough to level up (and not maxed)?
function PlayerData.unitReadyToLevel(id: string, rarity: string): boolean
	local lvl = PlayerData.unitLevel(id)
	if lvl >= UNIT_MAX_LEVEL then return false end
	return (state.unitXp[id] or 0) >= PlayerData.unitXpForLevel(rarity, lvl)
end

-- Coin cost to apply a level-up. Same across all rarities. Moderate curve:
-- ~1000 at L1->2 rising to ~15000 at L14->15 (gentle exponential).
function PlayerData.unitLevelCost(currentLevel: number): number
	-- 1000 * 1.226^(level-1): L1≈1000 ... L14≈15000. Rounded to nearest 50.
	local raw = 1000 * (1.226 ^ (currentLevel - 1))
	return math.floor(raw / 50 + 0.5) * 50
end

-- Apply a level-up: requires the meter full AND enough coins. Spends the XP
-- for this level (leftover carries) and the coins. Returns true on success.
function PlayerData.tryLevelUnit(id: string, rarity: string): boolean
	rarity = rarity or "Common"
	if not PlayerData.unitReadyToLevel(id, rarity) then return false end
	local lvl = PlayerData.unitLevel(id)
	local cost = PlayerData.unitLevelCost(lvl)
	if state.coins < cost then return false end
	state.coins -= cost
	state.unitXp[id] = (state.unitXp[id] or 0) - PlayerData.unitXpForLevel(rarity, lvl)
	state.unitLevels[id] = lvl + 1
	fire()
	return true
end

PlayerData.UNIT_MAX_LEVEL = UNIT_MAX_LEVEL

-- ── Account level rewards (the "pass" track) ─────────────────────────────────
-- Per-level reward table. PLACEHOLDER values — edit freely later.
-- Each entry: rewards granted when the player CLAIMS that level (after reaching it).
-- Supported reward keys: coins, gems, masteryChips. (Packs/units added later.)
local LEVEL_REWARDS = {
	[2]  = { coins = 200 },
	[3]  = { coins = 300 },
	[4]  = { gems = 15 },
	[5]  = { coins = 500, masteryChips = 5 },
	[6]  = { coins = 600 },
	[7]  = { gems = 20 },
	[8]  = { coins = 800 },
	[9]  = { coins = 1000 },
	[10] = { gems = 50, masteryChips = 10 },
}
-- Default reward for any level not explicitly listed (so the track never has gaps).
local function defaultLevelReward(level: number)
	return { coins = 100 + level * 50 }
end

-- The reward for a given level (table of currency keys).
function PlayerData.levelReward(level: number)
	return LEVEL_REWARDS[level] or defaultLevelReward(level)
end

-- Claim state for a level: "claimed" | "claimable" | "locked".
function PlayerData.levelRewardState(level: number): string
	if state.claimedLevels[level] then return "claimed" end
	-- a level's reward is claimable once you've REACHED that level (level >= it).
	-- Level 1 is the start and has no reward.
	if level >= 2 and state.level >= level then return "claimable" end
	return "locked"
end

-- Claim a level's reward (if claimable). Returns the granted reward table or nil.
function PlayerData.claimLevelReward(level: number)
	if PlayerData.levelRewardState(level) ~= "claimable" then return nil end
	local reward = PlayerData.levelReward(level)
	if reward.coins then state.coins += reward.coins end
	if reward.gems then state.gems += reward.gems end
	if reward.masteryChips then state.masteryChips += reward.masteryChips end
	state.claimedLevels[level] = true
	fire()
	return reward
end

-- How many levels have unclaimed rewards waiting (for a lobby badge count).
function PlayerData.unclaimedLevelCount(): number
	local n = 0
	for lvl = 2, state.level do
		if not state.claimedLevels[lvl] then n += 1 end
	end
	return n
end

-- ── Pack inventory ───────────────────────────────────────────────────────────
-- Banked (unopened) packs the player can open later.
function PlayerData.packCount(packId: string): number
	return (state.packInventory and state.packInventory[packId]) or 0
end
function PlayerData.allPackCounts()
	local t = {}
	for id, n in pairs(state.packInventory or {}) do t[id] = n end
	return t
end
function PlayerData.addPack(packId: string, n: number)
	state.packInventory[packId] = math.max(0, (state.packInventory[packId] or 0) + (n or 1))
	fire()
end
-- Consume one pack (when the player opens it). Returns true if one was available.
function PlayerData.consumePack(packId: string): boolean
	if (state.packInventory[packId] or 0) <= 0 then return false end
	state.packInventory[packId] -= 1
	fire()
	return true
end

-- Total unopened banked packs across all types.
function PlayerData.totalBankedPacks(): number
	local n = 0
	for _, c in pairs(state.packInventory or {}) do n += c end
	return n
end

-- ── Daily free win-packs ─────────────────────────────────────────────────────
-- Call on each WIN. Grants a pack for the first 4 wins in a rolling 24h window
-- (wins 1-3 = bronze, win 4 = silver). Returns the packId granted, or nil.
local DAILY_WIN_DAY = 24 * 60 * 60
local DAILY_WIN_PACKS = { "bronze", "bronze", "bronze", "silver" }  -- wins 1,2,3,4

function PlayerData.grantDailyWinPack(): string?
	local dw = state.dailyWin
	local now = os.time()
	-- A fresh set of 4 spawns only when BOTH: 24h has elapsed from the window
	-- start AND the player has opened all previously-banked packs (0 banked).
	local elapsed = (dw.windowStart == 0) or ((now - dw.windowStart) >= DAILY_WIN_DAY)
	if elapsed and PlayerData.totalBankedPacks() == 0 then
		dw.windowStart = now
		dw.winsThisWindow = 0
	end
	if dw.winsThisWindow >= #DAILY_WIN_PACKS then
		return nil   -- already earned all 4 this window
	end
	dw.winsThisWindow += 1
	local packId = DAILY_WIN_PACKS[dw.winsThisWindow]
	PlayerData.addPack(packId, 1)   -- fires
	return packId
end

-- How many daily win-packs remain available in the current window (0-4).
function PlayerData.dailyWinPacksRemaining(): number
	local dw = state.dailyWin
	local now = os.time()
	local elapsed = (dw.windowStart == 0) or ((now - dw.windowStart) >= DAILY_WIN_DAY)
	if elapsed and PlayerData.totalBankedPacks() == 0 then
		return #DAILY_WIN_PACKS   -- a fresh set is available to earn
	end
	return math.max(0, #DAILY_WIN_PACKS - dw.winsThisWindow)
end

-- Seconds until the current daily window resets (0 if no active window).
function PlayerData.dailyWinResetIn(): number
	local dw = state.dailyWin
	if dw.windowStart == 0 then return 0 end
	return math.max(0, DAILY_WIN_DAY - (os.time() - dw.windowStart))
end

-- ── Daily claim timers ────────────────────────────────────────────────────────
-- dailyClaims[key] = os.time() of last claim. 24h cooldown.
state.dailyClaims = {}
local DAY = 24 * 60 * 60

function PlayerData.canClaimDaily(key: string): boolean
	local last = state.dailyClaims[key]
	if not last then return true end
	return (os.time() - last) >= DAY
end

function PlayerData.secondsUntilDaily(key: string): number
	local last = state.dailyClaims[key]
	if not last then return 0 end
	return math.max(0, DAY - (os.time() - last))
end

-- Marks a daily as claimed now. Returns false if still on cooldown.
function PlayerData.claimDaily(key: string): boolean
	if not PlayerData.canClaimDaily(key) then return false end
	state.dailyClaims[key] = os.time()
	fire()
	return true
end

PlayerData.POINTS_PER_WIN = POINTS_PER_WIN
PlayerData.POINTS_PER_LOSS = POINTS_PER_LOSS

return PlayerData

