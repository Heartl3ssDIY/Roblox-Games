local PlayerData = {}

local changed = Instance.new("BindableEvent")
PlayerData.Changed = changed.Event
local function fire() changed:Fire() end

local state = {
	coins = 1000,
	gems = 100,
	masteryChips = 0,

	level = 1,
	xp = 0,

	arenaProgress = {
		["Tenkaichi"] = { points = 0, wins = 0, losses = 0 },
	},

	claimedMilestones = { ["Tenkaichi"] = {} },

	unitUnlock = {
		Bluma = "locked",
		Pikkolo = "locked",
	},

	unitLevels = {},
	unitXp = {},
	unitLocks = {},

	masteryPoints = {},

	claimedLevels = {},

	packInventory = { bronze = 0, silver = 0, gold = 0 },

	dailyWin = { windowStart = 0, winsThisWindow = 0 },
}

local POINTS_PER_WIN = 10
local POINTS_PER_LOSS = -10

local MASTERY_THRESHOLD = { Common = 40, Rare = 60, Epic = 80, Legendary = 100 }
local MASTERY_PER_MATCH = 10
local ARENA_MILESTONES = {
	["Tenkaichi"] = {
		{ points = 20,  reward = { coins = 1000 } },
		{ points = 40,  unlockUnit = "Bluma" },
		{ points = 80,  reward = { gems = 10 } },
		{ points = 100, unlockUnit = "Pikkolo" },
	},
}

function PlayerData.xpForLevel(level: number): number

	return math.floor(100 * (1.25 ^ (level - 1)) + 0.5)
end

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

function PlayerData.isArenaCompleted(arena: string): boolean
    local prog = state.arenaProgress[arena]
    local claimed = state.claimedMilestones[arena]
    local completed = (prog and (prog.completed == true or (tonumber(prog.points) or 0) >= 100))
        or (claimed and (claimed[100] == true or claimed["100"] == true))
    if not completed then return false end
    if not prog then
        prog = { points = 0, wins = 0, losses = 0 }
        state.arenaProgress[arena] = prog
    end
    prog.completed = true
    return true
end

function PlayerData.recordResult(arena: string, won: boolean)
	local prog = state.arenaProgress[arena]
	if not prog then prog = { points = 0, wins = 0, losses = 0 }; state.arenaProgress[arena] = prog end
	local claimed = state.claimedMilestones[arena]
	if not claimed then claimed = {}; state.claimedMilestones[arena] = claimed end

	PlayerData.isArenaCompleted(arena)
    local before = prog.points
	if won then prog.wins += 1 else prog.losses += 1 end
	prog.points = math.clamp(prog.points + (won and POINTS_PER_WIN or POINTS_PER_LOSS), 0, 100)
	if prog.points >= 100 then prog.completed = true end
	local after = prog.points

	local result = {
		points = after, delta = after - before, won = won,
		wins = prog.wins, losses = prog.losses,
		coinsAwarded = 0, gemsAwarded = 0, unlockedUnits = {},
	}

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

function PlayerData.arenaProgress(arena: string)
	local prog = state.arenaProgress[arena] or { points = 0, wins = 0, losses = 0 }
	return {
		points = prog.points, wins = prog.wins, losses = prog.losses,
		milestones = ARENA_MILESTONES[arena] or {},
        progressWins = prog.points / POINTS_PER_WIN,
        completed = PlayerData.isArenaCompleted(arena),
        claimed = table.clone(state.claimedMilestones[arena] or {}),
	}
end

function PlayerData.unitUnlockState(id: string): string
	return state.unitUnlock[id] or "owned"
end
function PlayerData.isUnitLocked(id: string): boolean
	return state.unitLocks[id] == true
end

function PlayerData.setUnitLocked(id: string, locked: boolean): boolean
	if PlayerData.unitUnlockState(id) ~= "owned" then return false end
	state.unitLocks[id] = locked == true
	fire()
	return true
end

function PlayerData.setUnitUnlockState(id: string, st: string): boolean
	if st ~= "owned" and PlayerData.isUnitLocked(id) then return false end
	state.unitUnlock[id] = st
	fire()
	return true
end

function PlayerData.ownUnit(id: string)
	state.unitUnlock[id] = "owned"
	if (state.unitLevels[id] or 0) < 1 then state.unitLevels[id] = 1 end
	fire()
end

function PlayerData.addMasteryPoints(id: string, n: number)
	state.masteryPoints[id] = (state.masteryPoints[id] or 0) + n
	fire()
end

function PlayerData.masteryThreshold(rarity: string): number
	return MASTERY_THRESHOLD[rarity] or 40
end

function PlayerData.masteryLevel(id: string, rarity: string): number
    return 1 + math.floor(math.max(0, PlayerData.masteryFor(id)) / PlayerData.masteryThreshold(rarity))
end

function PlayerData.masteryUnlocked(id: string, rarity: string): boolean
	return (state.masteryPoints[id] or 0) >= PlayerData.masteryThreshold(rarity)
end
PlayerData.MASTERY_PER_MATCH = MASTERY_PER_MATCH

local UNIT_BASE_XP = { Common = 5, Rare = 10, Epic = 20, Legendary = 25 }
local UNIT_MAX_LEVEL = 15

function PlayerData.unitXpForLevel(rarity: string, level: number): number
	local base = UNIT_BASE_XP[rarity] or 5
	return base * (2 ^ (level - 1))
end

function PlayerData.boostStat(current: number): number
	return math.floor(current * 1.10 + 0.5)
end

function PlayerData.unitStats(id: string, baseHealth: number, baseDamage: number)
	local lvl = PlayerData.unitLevel(id)
	local hp, dmg = baseHealth, baseDamage
	for _ = 2, lvl do
		hp = PlayerData.boostStat(hp)
		dmg = PlayerData.boostStat(dmg)
	end
	return hp, dmg
end

function PlayerData.addUnitXp(id: string, n: number)
	state.unitXp[id] = (state.unitXp[id] or 0) + n
	fire()
end

function PlayerData.unitXpProgress(id: string, rarity: string)
	local lvl = PlayerData.unitLevel(id)
	if lvl >= UNIT_MAX_LEVEL then return state.unitXp[id] or 0, nil end
	return state.unitXp[id] or 0, PlayerData.unitXpForLevel(rarity, lvl)
end

function PlayerData.unitReadyToLevel(id: string, rarity: string): boolean
	local lvl = PlayerData.unitLevel(id)
	if lvl >= UNIT_MAX_LEVEL then return false end
	return (state.unitXp[id] or 0) >= PlayerData.unitXpForLevel(rarity, lvl)
end

function PlayerData.unitLevelCost(currentLevel: number): number

	local raw = 1000 * (1.226 ^ (currentLevel - 1))
	return math.floor(raw / 50 + 0.5) * 50
end

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

local function defaultLevelReward(level: number)
	return { coins = 100 + level * 50 }
end

function PlayerData.levelReward(level: number)
	return LEVEL_REWARDS[level] or defaultLevelReward(level)
end

function PlayerData.levelRewardState(level: number): string
	if state.claimedLevels[level] then return "claimed" end

	if level >= 2 and state.level >= level then return "claimable" end
	return "locked"
end

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

function PlayerData.unclaimedLevelCount(): number
	local n = 0
	for lvl = 2, state.level do
		if not state.claimedLevels[lvl] then n += 1 end
	end
	return n
end

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

function PlayerData.consumePack(packId: string): boolean
	if (state.packInventory[packId] or 0) <= 0 then return false end
	state.packInventory[packId] -= 1
	fire()
	return true
end

function PlayerData.totalBankedPacks(): number
	local n = 0
	for _, c in pairs(state.packInventory or {}) do n += c end
	return n
end

local DAILY_WIN_DAY = 24 * 60 * 60
local DAILY_WIN_PACKS = { "bronze", "bronze", "bronze", "silver" }

local function dailyState(now)
    now = now or os.time()
    local dw = state.dailyWin
    local day = math.floor(now / DAILY_WIN_DAY)
    dw.pending = dw.pending or {}
    if dw.day ~= day then
        dw.day = day
        dw.windowStart = day * DAILY_WIN_DAY
        dw.winsThisWindow = 0
        dw.claimed = {}
    end
    return dw
end

function PlayerData.grantDailyWinPack(): string?
    local dw = dailyState()
    if dw.winsThisWindow >= #DAILY_WIN_PACKS then return nil end
    dw.winsThisWindow += 1
    local packId = DAILY_WIN_PACKS[dw.winsThisWindow]
    table.insert(dw.pending, {packId = packId, day = dw.day, slot = dw.winsThisWindow})
    PlayerData.addPack(packId, 1)
    return packId
end

function PlayerData.pendingDailyPack()
    local pending = dailyState().pending
    return pending[1] and table.clone(pending[1]) or nil
end

function PlayerData.consumeDailyPack(): string?
    local dw = dailyState()
    local reward = dw.pending[1]
    if not reward or PlayerData.packCount(reward.packId) < 1 then return nil end
    table.remove(dw.pending, 1)
    state.packInventory[reward.packId] -= 1
    if reward.day == dw.day then dw.claimed[reward.slot] = true end
    fire()
    return reward.packId
end

function PlayerData.dailyWinRewards()
    local dw = dailyState()
    local result = {}
    for index, packId in ipairs(DAILY_WIN_PACKS) do
        result[index] = {
            packId = packId,
            earned = index <= dw.winsThisWindow,
            claimed = dw.claimed[index] == true,
        }
    end
    return result
end

function PlayerData.dailyWinPacksRemaining(): number
    return math.max(0, #DAILY_WIN_PACKS - dailyState().winsThisWindow)
end

function PlayerData.dailyWinResetIn(): number
    local dw = dailyState()
    return math.max(0, (dw.day + 1) * DAILY_WIN_DAY - os.time())
end

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

function PlayerData.claimDaily(key: string): boolean
	if not PlayerData.canClaimDaily(key) then return false end
	state.dailyClaims[key] = os.time()
	fire()
	return true
end

PlayerData.POINTS_PER_WIN = POINTS_PER_WIN
PlayerData.POINTS_PER_LOSS = POINTS_PER_LOSS

return PlayerData


