-- Server-only game actions. Call `awardMatch` only after the server has issued
-- and accepted a unique match ticket. Current combat is client-simulated, so
-- the winner still cannot be independently verified until combat moves server-side.
local Rewards = require(script.Parent.ProfileRewards)
local PityConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("PityRewardConfig"))

local Actions = {}
local MAX_MASTERY = 2000
local WIN_DAILY_PACKS = {"bronze", "bronze", "bronze", "silver"}
local MILESTONES = {
	Tenkaichi = {
		{points = 20, coins = 1000},
		{points = 40, unit = "Bluma"},
		{points = 80, gems = 10},
		{points = 100, unit = "Pikkolo"},
	},
}

local function xpForLevel(level)
	return math.floor(100 * (1.25 ^ (level - 1)) + 0.5)
end

local function addAccountXp(playerData, amount)
	playerData.xp += amount
	local gained = 0
	while playerData.xp >= xpForLevel(playerData.level) and gained < 100 do
		playerData.xp -= xpForLevel(playerData.level)
		playerData.level += 1
		gained += 1
	end
	return gained
end

local function refreshDaily(dayData, now)
	local day = math.floor(now / 86400)
	dayData.pending = dayData.pending or {}
	if dayData.day ~= day then
		dayData.day = day
		dayData.windowStart = day * 86400
		dayData.winsThisWindow = 0
		dayData.claimed = {}
	end
	return day
end

local function grantDailyPack(playerData, now)
	local dw = playerData.dailyWin
	local day = refreshDaily(dw, now)
	if dw.winsThisWindow >= #WIN_DAILY_PACKS then return nil end
	dw.winsThisWindow += 1
	local packId = WIN_DAILY_PACKS[dw.winsThisWindow]
	if #dw.pending < 32 then
		table.insert(dw.pending, {packId = packId, day = day, slot = dw.winsThisWindow})
		playerData.packInventory[packId] = (playerData.packInventory[packId] or 0) + 1
		return packId
	end
	return nil
end

local function recordArena(playerData, arena, outcome)
	local progress = playerData.arenaProgress[arena]
	if not progress then
		progress = {points = 0, wins = 0, losses = 0}
		playerData.arenaProgress[arena] = progress
	end
	local claimed = playerData.claimedMilestones[arena]
	if not claimed then claimed = {}; playerData.claimedMilestones[arena] = claimed end
	local before = progress.points
	if outcome == "win" then
		progress.wins += 1
		progress.points = math.min(100, progress.points + 10)
	elseif outcome == "loss" then
		progress.losses += 1
		progress.points = math.max(0, progress.points - 10)
	end
	if progress.points >= 100 then progress.completed = true end
	local result = {delta = progress.points - before, points = progress.points, coinsAwarded = 0, gemsAwarded = 0, unlockedUnits = {}}
	if progress.points > before then
		for _, milestone in ipairs(MILESTONES[arena] or {}) do
			local key = tostring(milestone.points)
			if progress.points >= milestone.points and not claimed[key] then
				claimed[key] = true
				if milestone.coins then
					playerData.coins += milestone.coins
					result.coinsAwarded += milestone.coins
				end
				if milestone.gems then
					playerData.gems += milestone.gems
					result.gemsAwarded += milestone.gems
				end
				if milestone.unit then
					if playerData.unitUnlock[milestone.unit] ~= "owned" then playerData.unitUnlock[milestone.unit] = "unlockable" end
					table.insert(result.unlockedUnits, milestone.unit)
				end
			end
		end
	end
	return result
end

local function rememberMatch(profile, ticket, result)
	profile.awardedMatches[ticket] = result
	table.insert(profile.awardedMatchOrder, ticket)
	while #profile.awardedMatchOrder > 256 do
		local expired = table.remove(profile.awardedMatchOrder, 1)
		profile.awardedMatches[expired] = nil
	end
end

local function validatePity(profile,pending,choice,unitData)
    if type(choice) ~= "table" then return false,"invalid pity pick" end
    local kind=choice.kind
    if kind=="unitXp" then
        local id=choice.unitId
        if type(id)~="string" then return false,"invalid pity unit" end
        local inTeam=false
        for _,teamId in ipairs(pending.unitIds) do
            if teamId==id then inTeam=true;break end
        end
        local unit=unitData.get(id)
        if not inTeam or not unit then return false,"pity unit was not on the match team" end
        local ownership=profile.playerData.unitUnlock[id]
        if ownership~="owned" and (ownership~=nil or unit.unlockable==true) then
            return false,"pity unit is not owned"
        end
        local amount=PityConfig.unitXp
        if type(amount)~="number" or amount<1 or amount~=math.floor(amount) then
            return false,"pity reward is not configured"
        end
        return true,{kind=kind,unitId=id,amount=amount}
    end
    if kind~="masteryChips" and kind~="coins" then return false,"invalid pity pick" end
    local amount=PityConfig[kind]
    if type(amount)~="number" or amount<1 or amount~=math.floor(amount) then
        return false,"pity reward is not configured"
    end
    return true,{kind=kind,amount=amount}
end

function Actions.awardMatch(profile, args, rewardForLevel, unitData, now)
	if type(args) ~= "table" or type(args.ticket) ~= "string" or #args.ticket < 8 or #args.ticket > 128 then
		return false, "invalid match ticket"
	end
	local old = profile.awardedMatches[args.ticket]
	if old then return "unchanged", old end
	local outcome = args.outcome
	if outcome ~= "win" and outcome ~= "loss" and outcome ~= "forfeit" then return false, "invalid match outcome" end
	if type(args.arena) ~= "string" or not MILESTONES[args.arena] then return false, "unknown arena" end
	if outcome == "loss" and profile.pendingPity then return false, "claim the previous pity reward first" end
	local playerData = profile.playerData
	local result = {playerWon = outcome == "win", outcome = outcome, unitMastery = {}, unlockedUnits = {}}
	local arena = recordArena(playerData, args.arena, outcome)
	result.arenaDelta = arena.delta
	result.arenaPoints = arena.points
	result.milestoneCoins = arena.coinsAwarded
	result.milestoneGems = arena.gemsAwarded
	result.unlockedUnits = arena.unlockedUnits
	if outcome ~= "forfeit" then
		result.coins = outcome == "win" and 100 or 35
		result.accountXp = outcome == "win" and 50 or 18
		result.masteryChips = outcome == "win" and 10 or 4
		playerData.coins += result.coins
		playerData.masteryChips += result.masteryChips
		if addAccountXp(playerData, result.accountXp) > 0 then result.leveledTo = playerData.level end
		if outcome == "win" then result.dailyPack = grantDailyPack(playerData, now) end
		local seen = {}
		for _, id in ipairs(args.unitIds or {}) do
			if type(id) == "string" and not seen[id] and #result.unitMastery < 4 then
				local unit = unitData.get(id)
				if unit then
					seen[id] = true
					local gained = outcome == "win" and 10 or 4
					local beforePoints = playerData.masteryPoints[id] or 0
					local afterPoints = math.min(MAX_MASTERY, beforePoints + gained)
					playerData.masteryPoints[id] = afterPoints
					table.insert(result.unitMastery, {id = id, name = unit.name, rarity = unit.rarity,
						gained = afterPoints - beforePoints, beforePoints = beforePoints, afterPoints = afterPoints})
				end
			end
		end
	end
	local ok, reason = Rewards.applyPassOutcome(profile, outcome, rewardForLevel)
	if not ok then return false, reason end
	result.passXp = outcome == "win" and 5 or outcome == "loss" and 2 or -3
	result.trophyDelta = outcome == "win" and 10 or outcome == "loss" and -4 or 0
	if outcome == "win" then profile.matchStats.wins += 1
	elseif outcome == "loss" then profile.matchStats.losses += 1
	else profile.matchStats.forfeits += 1 end
	if outcome == "loss" then
        profile.pendingPity = {ticket = args.ticket, unitIds = table.clone(args.unitIds or {})}
        result.pityPending = true
    end
	rememberMatch(profile, args.ticket, result)
	return true, result
end

function Actions.claimPity(profile,choice,unitData)
    if type(choice)~="table" or type(choice.ticket)~="string" then return false,"invalid pity claim" end
    local match=profile.awardedMatches[choice.ticket]
    if not match or match.outcome~="loss" then return false,"no saved defeat for this ticket" end
    if match.pityReward then
        if match.pityReward.kind==choice.kind and (choice.kind~="unitXp" or match.pityReward.unitId==choice.unitId) then
            return true,{pityReward=match.pityReward,matchResult=match}
        end
        return false,"pity reward already claimed"
    end
    local pending=profile.pendingPity
    if not pending or pending.ticket~=choice.ticket then return false,"no pending pity reward" end
    local ok,reward=validatePity(profile,pending,choice,unitData)
    if not ok then return false,reward end
    local data=profile.playerData
    if reward.kind=="unitXp" then
        data.unitXp[reward.unitId]=(data.unitXp[reward.unitId] or 0)+reward.amount
    elseif reward.kind=="masteryChips" then
        data.masteryChips+=reward.amount
    else
        data.coins+=reward.amount
    end
    match.pityReward=reward
    match.pityPending=false
    profile.pendingPity=nil
    return true,{pityReward=reward,matchResult=match}
end

local function isOwned(profile, id, unit)
	local state = profile.playerData.unitUnlock[id]
	if state then return state == "owned" end
	return unit and unit.unlockable ~= true
end
function Actions.levelUnit(profile, id, unitData)
	local unit = type(id) == "string" and unitData.get(id) or nil
	if not unit or not isOwned(profile, id, unit) then return false, "unit unavailable" end
	local data = profile.playerData
	local level = data.unitLevels[id] or 1
	if level >= 15 then return false, "unit at max level" end
	local base = ({Common = 5, Rare = 10, Epic = 20, Legendary = 25, Mythic = 25})[unit.rarity] or 5
	local needed = base * 2 ^ (level - 1)
	local cost = math.floor((1000 * 1.226 ^ (level - 1)) / 50 + 0.5) * 50
	if (data.unitXp[id] or 0) < needed or data.coins < cost then return false, "requirements not met" end
	data.unitXp[id] -= needed
	data.coins -= cost
	data.unitLevels[id] = level + 1
	return true, {level = level + 1, coinsSpent = cost}
end

function Actions.setUnitLock(profile, id, locked, unitData)
	local unit = type(id) == "string" and unitData.get(id) or nil
	if type(locked) ~= "boolean" or not unit then return false, "invalid unit" end
	if not isOwned(profile, id, unit) then return false, "unit unavailable" end
	profile.playerData.unitLocks[id] = locked
	return true, locked
end

function Actions.setLoadout(profile, ids, unitData)
	if type(ids) ~= "table" or #ids > 4 then return false, "invalid loadout" end
	local seen, copy = {}, {}
	for _, id in ipairs(ids) do
		local unit = type(id) == "string" and unitData.get(id) or nil
		if not unit or seen[id] then return false, "invalid unit" end
		if not isOwned(profile, id, unit) then return false, "unit unavailable" end
		seen[id] = true
		table.insert(copy, id)
	end
	profile.loadout = copy
	return true, copy
end

function Actions.consumeDailyPack(profile)
	local data = profile.playerData
	local daily = data.dailyWin
	local pending = daily.pending[1]
	if not pending then return false, "no pending daily pack" end
	if (data.packInventory[pending.packId] or 0) < 1 then return false, "daily pack unavailable" end
	table.remove(daily.pending, 1)
	data.packInventory[pending.packId] -= 1
	if pending.day == daily.day then daily.claimed[tostring(pending.slot)] = true end
	return true, pending.packId
end

function Actions.boostMastery(profile, id, unitData)
	local unit = type(id) == "string" and unitData.get(id) or nil
	if not unit or not isOwned(profile, id, unit) then return false, "unit unavailable" end
	local data = profile.playerData
	if data.masteryChips < 1 then return false, "not enough mastery chips" end
	local beforePoints = data.masteryPoints[id] or 0
	if beforePoints >= MAX_MASTERY then return false, "mastery is at maximum" end
	local afterPoints = math.min(MAX_MASTERY, beforePoints + 10)
	data.masteryChips -= 1
	data.masteryPoints[id] = afterPoints
	return true, {id = id, beforePoints = beforePoints, afterPoints = afterPoints,
		gained = afterPoints - beforePoints, masteryChips = data.masteryChips}
end

function Actions.applyUnique(profile, actionId, name, operation)
	if type(actionId) ~= "string" or #actionId < 8 or #actionId > 128 then return false, "invalid action ID" end
	local cached = profile.processedActions[actionId]
	if cached then
		if cached.name ~= name then return false, "action ID reused" end
		return "unchanged", cached.result
	end
	local accepted, receipt = operation(profile)
	if not accepted then return false, receipt end
	profile.processedActions[actionId] = {name = name, result = receipt}
	table.insert(profile.processedActionOrder, actionId)
	while #profile.processedActionOrder > 256 do
		local expired = table.remove(profile.processedActionOrder, 1)
		profile.processedActions[expired] = nil
	end
	return true, receipt
end
return Actions



