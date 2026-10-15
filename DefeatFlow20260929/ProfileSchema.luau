-- Pure, versioned shape for the one per-player DataStore record. No Roblox
-- services are used here so the normalizer also works with an offline mock.
local Schema = {}
Schema.VERSION = 1
Schema.SEASON_ID = "season-1" -- change only when a new pass is deliberately launched
Schema.MASTERY_LEVEL_THRESHOLDS = {0, 40, 80, 150, 300, 500, 750, 1000, 1500, 2000}

local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in pairs(value) do result[key] = copy(child) end
	return result
end
Schema.copy = copy

local function finite(value, fallback, low, high)
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return fallback end
	return math.clamp(math.floor(value), low, high)
end
Schema.int = finite

local function safeId(value)
	return type(value) == "string" and #value > 0 and #value <= 80 and value:match("^[%w_%-]+$") ~= nil
end

local function counts(raw, maxValue)
	local result = {}
	if type(raw) ~= "table" then return result end
	for key, value in pairs(raw) do
		if safeId(key) then result[key] = finite(value, 0, 0, maxValue or 1000000000) end
	end
	return result
end

local function flags(raw)
	local result = {}
	if type(raw) ~= "table" then return result end
	for key, value in pairs(raw) do
		local normalized = tostring(key)
		if #normalized <= 80 and (value == true or value == 1) then result[normalized] = true end
	end
	return result
end

local function flagGroups(raw)
	local result = {}
	if type(raw) ~= "table" then return result end
	for key, value in pairs(raw) do
		if safeId(key) then result[key] = flags(value) end
	end
	return result
end

local function timestamps(raw)
	local result = {}
	if type(raw) ~= "table" then return result end
	for key, value in pairs(raw) do
		if safeId(key) then result[key] = finite(value, 0, 0, 4102444800) end
	end
	return result
end

function Schema.default(now)
	now = now or os.time()
	return {
		schemaVersion = Schema.VERSION,
		revision = 0,
		createdAt = now,
		updatedAt = now,
		playerData = {
			coins = 1000, gems = 100, masteryChips = 0,
			level = 1, xp = 0,
			arenaProgress = {Tenkaichi = {points = 0, wins = 0, losses = 0}},
			claimedMilestones = {Tenkaichi = {}},
			unitUnlock = {Bluma = "locked", Pikkolo = "locked", Beeras = "locked"},
			pvpTrophyRequirements = {Beeras = 500},
			unitLevels = {}, unitXp = {}, unitLocks = {}, masteryPoints = {},
			claimedLevels = {},
			packInventory = {bronze = 0, silver = 0, gold = 0, diamond = 0},
			dailyWin = {day = 0, windowStart = 0, winsThisWindow = 0, claimed = {}, pending = {}},
			dailyClaims = {},
		},
		seasonPass = {
			seasonId = Schema.SEASON_ID, completed = 0, currentXp = 0,
			trophies = 0, premiumPreview = false, premiumEntitled = false,
			creditedFreeThrough = 0,
			freeCreditTotals = {coins = 0, gems = 0, masteryChips = 0, packs = {}},
			creditedPaidThrough = 0,
			paidCreditTotals = {coins = 0, gems = 0, masteryChips = 0, packs = {}, unitXp = {}},
			claimed = {free = {}, paid = {}},
		},
		loadout = {"Yumcha", "Goku", "Krillen", "Tein"},
		shopClaims = {},
		rank = {seasonId = Schema.SEASON_ID, league = "Bronze", highestRank = "Bronze", wins = 0, losses = 0, viewers = 0},
		matchStats = {wins = 0, losses = 0, forfeits = 0},
		awardedMatches = {},
		awardedMatchOrder = {},
		processedActions = {},
		processedActionOrder = {},
	}
end

function Schema.normalize(raw, now)
	now = now or os.time()
	if raw ~= nil and type(raw) ~= "table" then return nil, "corrupt profile" end
	if type(raw) == "table" and type(raw.schemaVersion) == "number" and raw.schemaVersion > Schema.VERSION then
		return nil, "future profile version"
	end
	local result = Schema.default(now)
	if type(raw) ~= "table" then return result end
	-- Keep unknown fields of the current version so a staged feature is not erased.
	for key, value in pairs(raw) do if result[key] == nil then result[key] = copy(value) end end
	result.revision = finite(raw.revision, 0, 0, 2000000000)
	result.createdAt = finite(raw.createdAt, now, 0, 4102444800)
	result.updatedAt = finite(raw.updatedAt, now, 0, 4102444800)
	if type(raw.session) == "table" then
		local jobId = raw.session.jobId
		if type(jobId) == "string" and #jobId <= 128 then
			result.session = {jobId = jobId, leaseUntil = finite(raw.session.leaseUntil, 0, 0, 4102444800)}
		end
	end

	local p = type(raw.playerData) == "table" and raw.playerData or {}
	for key, value in pairs(p) do if result.playerData[key] == nil then result.playerData[key] = copy(value) end end
	for _, key in ipairs({"coins", "gems", "masteryChips"}) do
		result.playerData[key] = finite(p[key], result.playerData[key], 0, 1000000000)
	end
	result.playerData.level = finite(p.level, 1, 1, 10000)
	result.playerData.xp = finite(p.xp, 0, 0, 1000000000)
	local arenaProgress = {}
	if type(p.arenaProgress) == "table" then
		for arena, progress in pairs(p.arenaProgress) do
			if safeId(arena) and type(progress) == "table" then
				arenaProgress[arena] = {
					points = finite(progress.points, 0, 0, 100),
					wins = finite(progress.wins, 0, 0, 1000000000),
					losses = finite(progress.losses, 0, 0, 1000000000),
					completed = progress.completed == true,
				}
			end
		end
	end
	if not arenaProgress.Tenkaichi then arenaProgress.Tenkaichi = {points = 0, wins = 0, losses = 0} end
	result.playerData.arenaProgress = arenaProgress
	result.playerData.claimedMilestones = flagGroups(p.claimedMilestones)
	if not result.playerData.claimedMilestones.Tenkaichi then result.playerData.claimedMilestones.Tenkaichi = {} end
	local unlock = {Bluma = "locked", Pikkolo = "locked", Beeras = "locked"}
	if type(p.unitUnlock) == "table" then
		for id, state in pairs(p.unitUnlock) do
			if safeId(id) and (state == "locked" or state == "unlockable" or state == "owned") then unlock[id] = state end
		end
	end
	result.playerData.unitUnlock = unlock
	result.playerData.pvpTrophyRequirements = {Beeras = 500}
	result.playerData.unitLevels = counts(p.unitLevels, 15)
	result.playerData.unitXp = counts(p.unitXp)
	result.playerData.masteryPoints = counts(p.masteryPoints, 2000)
	result.playerData.unitLocks = flags(p.unitLocks)
	result.playerData.claimedLevels = flags(p.claimedLevels)
	result.playerData.packInventory = counts(p.packInventory)
	for _, id in ipairs({"bronze", "silver", "gold", "diamond"}) do
		result.playerData.packInventory[id] = result.playerData.packInventory[id] or 0
	end
	result.playerData.dailyClaims = timestamps(p.dailyClaims)
	local dw = type(p.dailyWin) == "table" and p.dailyWin or {}
	local dailyWin = result.playerData.dailyWin
	dailyWin.day = finite(dw.day, 0, 0, 10000000)
	dailyWin.windowStart = finite(dw.windowStart, 0, 0, 4102444800)
	dailyWin.winsThisWindow = finite(dw.winsThisWindow, 0, 0, 4)
	dailyWin.claimed = flags(dw.claimed)
	dailyWin.pending = {}
	if type(dw.pending) == "table" then
		for _, item in ipairs(dw.pending) do
			if type(item) == "table" and safeId(item.packId) and #dailyWin.pending < 32 then
				table.insert(dailyWin.pending, {
					packId = item.packId,
					day = finite(item.day, 0, 0, 10000000),
					slot = finite(item.slot, 0, 0, 4),
				})
			end
		end
	end

	local s = type(raw.seasonPass) == "table" and raw.seasonPass or {}
	for key, value in pairs(s) do if result.seasonPass[key] == nil then result.seasonPass[key] = copy(value) end end
	result.seasonPass.seasonId = safeId(s.seasonId) and s.seasonId or Schema.SEASON_ID
	result.seasonPass.completed = finite(s.completed, 0, 0, 50)
	result.seasonPass.currentXp = finite(s.currentXp, 0, 0, 14)
	result.seasonPass.trophies = finite(s.trophies, 0, 0, 1000000000)
	result.seasonPass.premiumPreview = s.premiumPreview == true
	result.seasonPass.premiumEntitled = s.premiumEntitled == true
	result.seasonPass.creditedFreeThrough = finite(s.creditedFreeThrough, 0, 0, 50)
	result.seasonPass.creditedPaidThrough = finite(s.creditedPaidThrough, 0, 0, 50)
	local totals = type(s.freeCreditTotals) == "table" and s.freeCreditTotals or {}
	result.seasonPass.freeCreditTotals = {
		coins = finite(totals.coins, 0, 0, 1000000000),
		gems = finite(totals.gems, 0, 0, 1000000000),
		masteryChips = finite(totals.masteryChips, 0, 0, 1000000000),
		packs = counts(totals.packs),
	}
	local paidTotals = type(s.paidCreditTotals) == "table" and s.paidCreditTotals or {}
	result.seasonPass.paidCreditTotals = {
		coins = finite(paidTotals.coins, 0, 0, 1000000000),
		gems = finite(paidTotals.gems, 0, 0, 1000000000),
		masteryChips = finite(paidTotals.masteryChips, 0, 0, 1000000000),
		packs = counts(paidTotals.packs),
		unitXp = counts(paidTotals.unitXp),
	}
	local claimed = type(s.claimed) == "table" and s.claimed or {}
	result.seasonPass.claimed = {free = flags(claimed.free), paid = flags(claimed.paid)}
	result.shopClaims = timestamps(raw.shopClaims)
	local loadout = {}
	local seen = {}
	if type(raw.loadout) == "table" then
		for _, id in ipairs(raw.loadout) do
			if safeId(id) and not seen[id] and #loadout < 4 then
				seen[id] = true
				table.insert(loadout, id)
			end
		end
	else
		loadout = copy(result.loadout)
	end
	result.loadout = loadout
	local rank = type(raw.rank) == "table" and raw.rank or {}
	result.rank = {
		seasonId = safeId(rank.seasonId) and rank.seasonId or Schema.SEASON_ID,
		league = type(rank.league) == "string" and rank.league ~= "" and rank.league:sub(1, 64) or "Bronze",
		highestRank = type(rank.highestRank) == "string" and rank.highestRank ~= "" and rank.highestRank:sub(1, 64) or "Bronze",
		wins = finite(rank.wins, 0, 0, 1000000000),
		losses = finite(rank.losses, 0, 0, 1000000000),
		viewers = finite(rank.viewers, 0, 0, 1000000000),
	}
	result.pendingPity = nil
    local pending = type(raw.pendingPity) == "table" and raw.pendingPity or nil
    if pending and safeId(pending.ticket) then
        local units, seen = {}, {}
        if type(pending.unitIds) == "table" then
            for _, id in ipairs(pending.unitIds) do
                if safeId(id) and not seen[id] and #units < 4 then
                    seen[id] = true
                    table.insert(units, id)
                end
            end
        end
        if #units > 0 then result.pendingPity = {ticket = pending.ticket, unitIds = units} end
    end
	result.awardedMatches = type(raw.awardedMatches) == "table" and copy(raw.awardedMatches) or {}
	result.awardedMatchOrder = type(raw.awardedMatchOrder) == "table" and copy(raw.awardedMatchOrder) or {}
	result.processedActions = type(raw.processedActions) == "table" and copy(raw.processedActions) or {}
	result.processedActionOrder = type(raw.processedActionOrder) == "table" and copy(raw.processedActionOrder) or {}
	local stats = type(raw.matchStats) == "table" and raw.matchStats or {}
	result.matchStats = {
		wins = finite(stats.wins, 0, 0, 1000000000),
		losses = finite(stats.losses, 0, 0, 1000000000),
		forfeits = finite(stats.forfeits, 0, 0, 1000000000),
	}
	return result
end

function Schema.clientSnapshot(profile)
	return {
		revision = profile.revision,
		playerData = copy(profile.playerData),
		seasonPass = copy(profile.seasonPass),
		loadout = copy(profile.loadout),
		shopClaims = copy(profile.shopClaims),
		rank = copy(profile.rank),
		matchStats = copy(profile.matchStats),
        pendingPity = copy(profile.pendingPity),
	}
end

return Schema


