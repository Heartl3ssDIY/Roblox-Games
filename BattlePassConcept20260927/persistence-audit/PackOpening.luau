local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnitData = require(ReplicatedStorage:WaitForChild("UnitData"))
local PlayerData = require(ReplicatedStorage:WaitForChild("PlayerData"))

local PackOpening = {}

local PACKS = {
	bronze = {
		name = "Common Pack",
		cap = 8,
		newUnit = { Common = 0.15, Rare = 0.10, Epic = 0.05 },
		xpAvg   = { Common = 4,    Rare = 4,    Epic = 2 },
	},
	silver = {
		name = "Silver Pack",
		cap = 33,
		newUnit = { Common = 0.17, Rare = 0.12, Epic = 0.07 },
		xpAvg   = { Common = 10,   Rare = 10,   Epic = 5 },
	},
	gold = {
		name = "Gold Pack",
		cap = 64,

		newUnit = { Rare = 0.25, Epic = 0.15, Legendary = 0.10 },
		xpAvg   = { Rare = 16,   Epic = 15,   Legendary = 14 },
	},
	diamond = {
		name = "Diamond Pack",
		cap = 160,

		newUnit = { Rare = 0.25, Epic = 0.20, Legendary = 0.15 },
		xpAvg   = { Rare = 36,   Epic = 30,   Legendary = 27 },
	},
}

PackOpening.PACKS = PACKS

local function unitsOfRarity(rarity: string)
	local t = {}
	for id, u in pairs(UnitData.all()) do
		if u.rarity == rarity and u.packEligible ~= false then table.insert(t, id) end
	end
	return t
end

local function ownedUnitsOfRarity(rarity: string)
	local t = {}
	for _, id in ipairs(unitsOfRarity(rarity)) do
		if PlayerData.unitUnlockState(id) == "owned" then table.insert(t, id) end
	end
	return t
end

local function unlockableUnitsOfRarity(rarity: string)
	local t = {}
	for _, id in ipairs(unitsOfRarity(rarity)) do
		if PlayerData.unitUnlockState(id) == "unlockable" then table.insert(t, id) end
	end
	return t
end

local function vary(avg: number): number
	if avg <= 0 then return 0 end
	local lo = avg * 0.75
	local hi = avg * 1.25
	local v = lo + math.random() * (hi - lo)
	return math.max(0, math.floor(v + 0.5))
end

function PackOpening.roll(packId: string)
	local def = PACKS[packId]
	if not def then return nil end

	local result = {
		packId = packId, packName = def.name,
		newUnits = {}, cards = {}, cardsByRarity = {}, totalCards = 0,
	}

	for rarity, chance in pairs(def.newUnit) do
		if math.random() < chance then
			local pool = unlockableUnitsOfRarity(rarity)
			if #pool > 0 then
				local pick = pool[math.random(1, #pool)]
				table.insert(result.newUnits, pick)
			end
		end
	end

	local order = { "Common", "Rare", "Epic", "Legendary" }
	for _, rarity in ipairs(order) do
		local avg = def.xpAvg[rarity]
		if avg and avg > 0 then
			local owned = ownedUnitsOfRarity(rarity)

			for _, nid in ipairs(result.newUnits) do
				local u = UnitData.get(nid)
				if u and u.rarity == rarity then
					local already = false
					for _, o in ipairs(owned) do if o == nid then already = true end end
					if not already then table.insert(owned, nid) end
				end
			end
			if #owned > 0 then
				local count = vary(avg)

				count = math.min(count, def.cap - result.totalCards)
				for _ = 1, count do
					local uid = owned[math.random(1, #owned)]
					result.cards[uid] = (result.cards[uid] or 0) + 1
					result.cardsByRarity[rarity] = (result.cardsByRarity[rarity] or 0) + 1
					result.totalCards += 1
				end
			end
		end
	end

	return result
end

function PackOpening.apply(result)
    if not result or result.applied then return end
    result.progress = {}
    for _, id in ipairs(result.newUnits) do
        local unit = UnitData.get(id)
        if unit and unit.packEligible ~= false then PlayerData.ownUnit(id) end
    end
    for unitId, count in pairs(result.cards) do
        local unit = UnitData.get(unitId)
        if unit and unit.packEligible ~= false then
            local before, needed = PlayerData.unitXpProgress(unitId, unit.rarity)
            local level = PlayerData.unitLevel(unitId)
            PlayerData.addUnitXp(unitId, count)
            local after = PlayerData.unitXp(unitId)
            result.progress[unitId] = {before = before, after = after, needed = needed, level = level}
        end
    end
    result.applied = true
end

function PackOpening.info(packId)
    local definition = PACKS[packId]
    if not definition then return nil end
    local info = {name = definition.name, cap = definition.cap, tiers = {}, guaranteed = 0, eligible = false}
    for _, rarity in ipairs({"Common", "Rare", "Epic", "Legendary", "Mythic"}) do
        local average = definition.xpAvg[rarity] or 0
        local chance = definition.newUnit[rarity] or 0
        if average > 0 or chance > 0 then
            local owned = #ownedUnitsOfRarity(rarity)
            local unlockable = #unlockableUnitsOfRarity(rarity)
            local minimum = math.max(0, math.floor(average * 0.75 + 0.5))
            local maximum = math.max(0, math.floor(average * 1.25 + 0.5))
            table.insert(info.tiers, {
                rarity = rarity, average = average, minimum = minimum, maximum = maximum,
                chance = chance, owned = owned, unlockable = unlockable,
            })
            if owned > 0 and average > 0 then
                info.guaranteed = math.min(info.cap, info.guaranteed + minimum)
                info.eligible = true
            end
            if unlockable > 0 and chance > 0 then info.eligible = true end
        end
    end
    return info
end

function PackOpening.open(packId: string)
	local result = PackOpening.roll(packId)
	PackOpening.apply(result)
	return result
end

return PackOpening
