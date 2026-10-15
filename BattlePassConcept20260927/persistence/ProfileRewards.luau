-- Fixed server-side Battle Pass grants. The reward lookup must come from the
-- developer's SeasonPassData table, never from a client request.
local Rewards = {}

local function addCurrency(profile, key, amount)
	if key == "diamonds" then key = "gems" end
	if key ~= "coins" and key ~= "gems" and key ~= "masteryChips" then return false end
	profile.playerData[key] += amount
	profile.seasonPass.freeCreditTotals[key] += amount
	return true
end

function Rewards.creditFreeThrough(profile, rewardForLevel)
	local pass = profile.seasonPass
	local stop = math.min(50, pass.completed)
	for level = pass.creditedFreeThrough + 1, stop do
		local reward = rewardForLevel(level, "free")
		if type(reward) ~= "table" then return false, "missing free reward at level " .. level end
		local amount = reward.amount
		if type(amount) ~= "number" or amount ~= math.floor(amount) or amount < 1 or amount > 1000000 then
			return false, "invalid free reward amount"
		end
		if reward.kind == "pack" then
			local id = reward.rarity
			if id ~= "bronze" and id ~= "silver" and id ~= "gold" and id ~= "diamond" then
				return false, "invalid free pack"
			end
			profile.playerData.packInventory[id] = (profile.playerData.packInventory[id] or 0) + amount
			local totals = profile.seasonPass.freeCreditTotals.packs
			totals[id] = (totals[id] or 0) + amount
		elseif not addCurrency(profile, reward.currency, amount) then
			return false, "invalid free currency"
		end
		pass.creditedFreeThrough = level
		pass.claimed.free[tostring(level)] = true
	end
	return true
end

local function refreshBeerasAvailability(profile)
	local pass = profile.seasonPass
	if pass.premiumEntitled and pass.creditedPaidThrough >= 1 then
		if profile.playerData.unitUnlock.Beeras ~= "owned" then
			profile.playerData.unitUnlock.Beeras = "unlockable"
		end
	end
end

function Rewards.creditPaidThrough(profile, rewardForLevel)
	local pass = profile.seasonPass
	if not pass.premiumEntitled then return true end
	local totals = pass.paidCreditTotals
	local stop = math.min(50, pass.completed)
	for level = pass.creditedPaidThrough + 1, stop do
		local reward = rewardForLevel(level, "paid")
		if type(reward) ~= "table" then return false, "missing paid reward at level " .. level end
		if reward.kind == "packPoolUnlock" then
			if level ~= 1 or reward.unitId ~= "Beeras" then return false, "invalid paid unit unlock" end
		else
			local amount = reward.amount
			if type(amount) ~= "number" or amount ~= math.floor(amount) or amount < 1 or amount > 1000000 then
				return false, "invalid paid reward amount"
			end
			if reward.kind == "pack" then
				local id = reward.rarity
				if id ~= "bronze" and id ~= "silver" and id ~= "gold" and id ~= "diamond" then
					return false, "invalid paid pack"
				end
				profile.playerData.packInventory[id] = (profile.playerData.packInventory[id] or 0) + amount
				totals.packs[id] = (totals.packs[id] or 0) + amount
			elseif reward.kind == "unitXp" then
				if reward.unitId ~= "Beeras" then return false, "invalid paid unit XP" end
				profile.playerData.unitXp.Beeras = (profile.playerData.unitXp.Beeras or 0) + amount
				totals.unitXp.Beeras = (totals.unitXp.Beeras or 0) + amount
			else
				local currency = reward.currency == "diamonds" and "gems" or reward.currency
				if currency ~= "coins" and currency ~= "gems" and currency ~= "masteryChips" then return false, "invalid paid currency" end
				profile.playerData[currency] += amount
				totals[currency] += amount
			end
		end
		pass.creditedPaidThrough = level
		pass.claimed.paid[tostring(level)] = true
	end
	refreshBeerasAvailability(profile)
	return true
end

function Rewards.applyPassOutcome(profile, outcome, rewardForLevel)
	local pass = profile.seasonPass
	if outcome == "win" then
		pass.currentXp += 5
		pass.trophies += 10
	elseif outcome == "loss" then
		pass.currentXp += 2
		pass.trophies = math.max(0, pass.trophies - 4)
	elseif outcome == "forfeit" then
		-- A forfeit never removes a completed tier.
		pass.currentXp = math.max(0, pass.currentXp - 3)
	else
		return false, "unknown outcome"
	end
	while pass.currentXp >= 15 and pass.completed < 50 do
		pass.currentXp -= 15
		pass.completed += 1
	end
	if pass.completed >= 50 then pass.currentXp = 0 end
	local credited, reason = Rewards.creditFreeThrough(profile, rewardForLevel)
	if not credited then return false, reason end
	return Rewards.creditPaidThrough(profile, rewardForLevel)
end

return Rewards
