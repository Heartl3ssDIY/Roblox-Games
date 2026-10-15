local SeasonPassData = {}
local changed = Instance.new("BindableEvent")
SeasonPassData.Changed = changed.Event

SeasonPassData.LEVEL_COUNT = 50
SeasonPassData.XP_PER_LEVEL = 15
SeasonPassData.WIN_XP = 5
SeasonPassData.LOSS_XP = 2
SeasonPassData.FORFEIT_XP = -3
SeasonPassData.WIN_TROPHIES = 10
SeasonPassData.LOSS_TROPHIES = -4

local state = {
	completed = 0,
	currentXp = 0,
	trophies = 0,
	premiumPreview = false,
	claimed = { free = {}, paid = {} },
}
local rewards = {
	free = {
		[1] = { kind = "pack", rarity = "bronze", amount = 1 },
		[2] = { currency = "coins", amount = 125 },
		[3] = { currency = "coins", amount = 125 },
		[4] = { currency = "coins", amount = 250 },
		[5] = { kind = "pack", rarity = "bronze", amount = 1 },
		[6] = { currency = "coins", amount = 125 },
		[7] = { currency = "coins", amount = 125 },
		[8] = { kind = "pack", rarity = "gold", amount = 1 },
		[9] = { currency = "coins", amount = 250 },
		[10] = { kind = "pack", rarity = "silver", amount = 1 },
		[11] = { currency = "coins", amount = 125 },
		[12] = { currency = "coins", amount = 250 },
		[13] = { currency = "coins", amount = 250 },
		[14] = { currency = "coins", amount = 375 },
		[15] = { kind = "pack", rarity = "bronze", amount = 1 },
		[16] = { currency = "diamonds", amount = 25 },
		[17] = { currency = "coins", amount = 250 },
		[18] = { kind = "pack", rarity = "bronze", amount = 1 },
		[19] = { currency = "coins", amount = 375 },
		[20] = { kind = "pack", rarity = "silver", amount = 1 },
		[21] = { currency = "coins", amount = 1250 },
		[22] = { currency = "coins", amount = 250 },
		[23] = { currency = "coins", amount = 250 },
		[24] = { currency = "coins", amount = 375 },
		[25] = { kind = "pack", rarity = "bronze", amount = 1 },
		[26] = { currency = "coins", amount = 125 },
		[27] = { currency = "coins", amount = 250 },
		[28] = { kind = "pack", rarity = "bronze", amount = 1 },
		[29] = { currency = "coins", amount = 375 },
		[30] = { kind = "pack", rarity = "silver", amount = 1 },
		[31] = { currency = "masteryChips", amount = 75 },
		[32] = { currency = "coins", amount = 250 },
		[33] = { currency = "coins", amount = 250 },
		[34] = { currency = "coins", amount = 375 },
		[35] = { kind = "pack", rarity = "bronze", amount = 1 },
		[36] = { currency = "coins", amount = 1250 },
		[37] = { currency = "coins", amount = 2500 },
		[38] = { kind = "pack", rarity = "bronze", amount = 1 },
		[39] = { currency = "coins", amount = 3750 },
		[40] = { kind = "pack", rarity = "silver", amount = 1 },
		[41] = { currency = "coins", amount = 1250 },
		[42] = { currency = "coins", amount = 2500 },
		[43] = { currency = "coins", amount = 2500 },
		[44] = { currency = "coins", amount = 3750 },
		[45] = { kind = "pack", rarity = "bronze", amount = 1 },
		[46] = { currency = "coins", amount = 1250 },
		[47] = { currency = "coins", amount = 2500 },
		[48] = { kind = "pack", rarity = "bronze", amount = 1 },
		[49] = { currency = "coins", amount = 3750 },
		[50] = { kind = "pack", rarity = "diamond", amount = 1 },
	},
	paid = {
		[1] = { kind = "packPoolUnlock", unitId = "Beeras", rarity = "Mythic", pvpTrophiesRequired = 500 },
		[2] = { kind = "pack", rarity = "bronze", amount = 2 },
		[3] = { currency = "coins", amount = 2500 },
		[4] = { currency = "diamonds", amount = 25 },
		[5] = { kind = "pack", rarity = "gold", amount = 2 },
		[6] = { currency = "coins", amount = 2500 },
		[7] = { kind = "pack", rarity = "bronze", amount = 2 },
		[8] = { currency = "masteryChips", amount = 25 },
		[9] = { kind = "pack", rarity = "silver", amount = 2 },
		[10] = { kind = "pack", rarity = "diamond", amount = 1 },
		[11] = { kind = "unitXp", unitId = "Beeras", amount = 10 },
		[12] = { currency = "coins", amount = 5000 },
		[13] = { currency = "diamonds", amount = 25 },
		[14] = { kind = "pack", rarity = "gold", amount = 2 },
		[15] = { currency = "coins", amount = 10000 },
		[16] = { kind = "unitXp", unitId = "Beeras", amount = 10 },
		[17] = { currency = "masteryChips", amount = 25 },
		[18] = { kind = "pack", rarity = "bronze", amount = 2 },
		[19] = { kind = "pack", rarity = "gold", amount = 2 },
		[20] = { kind = "pack", rarity = "diamond", amount = 1 },
		[21] = { kind = "unitXp", unitId = "Beeras", amount = 5 },
		[22] = { currency = "coins", amount = 5000 },
		[23] = { currency = "diamonds", amount = 25 },
		[24] = { kind = "pack", rarity = "silver", amount = 2 },
		[25] = { currency = "coins", amount = 10000 },
		[26] = { kind = "pack", rarity = "bronze", amount = 2 },
		[27] = { currency = "masteryChips", amount = 25 },
		[28] = { kind = "pack", rarity = "bronze", amount = 2 },
		[29] = { kind = "pack", rarity = "silver", amount = 2 },
		[30] = { kind = "pack", rarity = "diamond", amount = 1 },
		[31] = { kind = "unitXp", unitId = "Beeras", amount = 5 },
		[32] = { currency = "coins", amount = 7500 },
		[33] = { currency = "diamonds", amount = 50 },
		[34] = { kind = "pack", rarity = "gold", amount = 2 },
		[35] = { currency = "coins", amount = 15000 },
		[36] = { kind = "pack", rarity = "bronze", amount = 2 },
		[37] = { currency = "masteryChips", amount = 25 },
		[38] = { kind = "pack", rarity = "bronze", amount = 2 },
		[39] = { kind = "pack", rarity = "silver", amount = 2 },
		[40] = { kind = "pack", rarity = "diamond", amount = 1 },
		[41] = { kind = "unitXp", unitId = "Beeras", amount = 10 },
		[42] = { currency = "coins", amount = 7500 },
		[43] = { currency = "diamonds", amount = 50 },
		[44] = { kind = "pack", rarity = "gold", amount = 2 },
		[45] = { currency = "coins", amount = 15000 },
		[46] = { kind = "pack", rarity = "bronze", amount = 2 },
		[47] = { currency = "masteryChips", amount = 25 },
		[48] = { kind = "pack", rarity = "bronze", amount = 2 },
		[49] = { kind = "pack", rarity = "diamond", amount = 1 },
		[50] = { kind = "unitXp", unitId = "Beeras", amount = 10 },
	},
}

local function copyState()
	return {
		completed = state.completed,
		level = math.min(state.completed + 1, SeasonPassData.LEVEL_COUNT),
		currentXp = state.currentXp,
		trophies = state.trophies,
		premiumPreview = state.premiumPreview,
	}
end

function SeasonPassData.snapshot()
	return copyState()
end

function SeasonPassData.completed()
	return state.completed
end

function SeasonPassData.level()
	return math.min(state.completed + 1, SeasonPassData.LEVEL_COUNT)
end

function SeasonPassData.xp()
	return state.currentXp
end

function SeasonPassData.xpNeeded()
	return SeasonPassData.XP_PER_LEVEL
end

function SeasonPassData.trophies()
	return state.trophies
end

function SeasonPassData.isPremium()
	return state.premiumPreview
end

function SeasonPassData.setPremiumPreview(enabled)
	state.premiumPreview = enabled == true
	changed:Fire(copyState())
end

function SeasonPassData.reward(level, lane)
	if lane ~= "free" and lane ~= "paid" then return nil end
	return rewards[lane][level]
end

function SeasonPassData.rewardState(lane, level)
	if lane ~= "free" and lane ~= "paid" then return "invalid" end
	if type(level) ~= "number" or level < 1 or level > SeasonPassData.LEVEL_COUNT then return "invalid" end
	if not rewards[lane][level] then return "empty" end
	if state.claimed[lane][tostring(level)] or state.claimed[lane][level] then return "claimed" end
	if state.completed < level then return "locked" end
	if lane == "paid" and not state.premiumEntitled then return "premium" end
	return "unconfigured"
end

function SeasonPassData.claimReward(lane, level)
	local status = SeasonPassData.rewardState(lane, level)
	if status ~= "unconfigured" then return false, status end
	return false, "Reward claiming is not active yet"
end

function SeasonPassData.applyMatchOutcome(outcome)
	if outcome == "win" then
		state.currentXp += SeasonPassData.WIN_XP
		state.trophies += SeasonPassData.WIN_TROPHIES
	elseif outcome == "loss" then
		state.currentXp += SeasonPassData.LOSS_XP
		state.trophies = math.max(0, state.trophies + SeasonPassData.LOSS_TROPHIES)
	elseif outcome == "forfeit" then
		state.currentXp = math.max(0, state.currentXp + SeasonPassData.FORFEIT_XP)
	else
		return nil, "Unknown match outcome"
	end

	while state.currentXp >= SeasonPassData.XP_PER_LEVEL and state.completed < SeasonPassData.LEVEL_COUNT do
		state.currentXp -= SeasonPassData.XP_PER_LEVEL
		state.completed += 1
	end
	if state.completed >= SeasonPassData.LEVEL_COUNT then state.currentXp = 0 end
	changed:Fire(copyState())
	return copyState()
end


local function profileCopy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = profileCopy(child) end
    return result
end

function SeasonPassData._profileExport()
    return profileCopy(state)
end

function SeasonPassData._profileHydrate(snapshot)
    assert(type(snapshot) == "table", "seasonPass snapshot required")
    state = profileCopy(snapshot)
    changed:Fire(copyState())
end

return SeasonPassData
