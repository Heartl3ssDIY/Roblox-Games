--!strict
-- PackOpening: the roll logic for opening packs. Returns a structured result
-- describing newly-unlocked units and the unit-specific XP cards granted.
-- The opening ANIMATION and the granting-to-state are handled by callers/UI;
-- this module just decides WHAT a pack gives, then can apply it.
--
-- Pack-open algorithm (per the design):
--  1) New-unit step: roll EACH rarity independently vs its unlock chance.
--     Each success unlocks one unit of that rarity from the player's
--     unlockable-but-not-owned pool (units unlocked via gameplay milestones).
--  2) XP-card step: for each rarity, generate ~avg cards (±25%), capped at the
--     pack max total. Each card is a dupe (+1 XP) assigned to a RANDOM owned
--     unit of that rarity. If no owned units of a rarity, skip that tier.
--  XP cards only ever target the player's UNLOCKED unit pool.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnitData = require(ReplicatedStorage:WaitForChild("UnitData"))
local PlayerData = require(ReplicatedStorage:WaitForChild("PlayerData"))

local PackOpening = {}

-- ── Pack definitions ─────────────────────────────────────────────────────────
-- newUnit: chance (0-1) to unlock a new unit of each rarity (independent rolls).
-- xpAvg:   average number of XP cards per rarity (actual = avg ±25%).
-- cap:     max total XP cards the pack can give.
local PACKS = {
	bronze = {
		name = "Bronze Pack",
		cap = 8,
		newUnit = { Common = 0.15, Rare = 0.10, Epic = 0.05 },   -- no Legendary
		xpAvg   = { Common = 4,    Rare = 4,    Epic = 2 },
	},
	silver = {
		name = "Silver Pack",
		cap = 33,
		newUnit = { Common = 0.17, Rare = 0.12, Epic = 0.07 },   -- no Legendary
		xpAvg   = { Common = 10,   Rare = 10,   Epic = 5 },
	},
	gold = {
		name = "Gold Pack",
		cap = 64,
		-- no Common tier; Legendary appears here for the first time
		newUnit = { Rare = 0.25, Epic = 0.15, Legendary = 0.10 },
		xpAvg   = { Rare = 16,   Epic = 15,   Legendary = 14 },
	},
	diamond = {
		name = "Diamond Pack",
		cap = 160,
		-- no Common tier
		newUnit = { Rare = 0.25, Epic = 0.20, Legendary = 0.15 },
		xpAvg   = { Rare = 36,   Epic = 30,   Legendary = 27 },
	},
}

PackOpening.PACKS = PACKS

-- ── Helpers ──────────────────────────────────────────────────────────────────
-- All unit ids of a given rarity.
local function unitsOfRarity(rarity: string)
	local t = {}
	for id, u in pairs(UnitData.all()) do
		if u.rarity == rarity then table.insert(t, id) end
	end
	return t
end

-- Units the player OWNS (in collection) of a rarity — eligible to receive XP cards.
local function ownedUnitsOfRarity(rarity: string)
	local t = {}
	for _, id in ipairs(unitsOfRarity(rarity)) do
		if PlayerData.unitUnlockState(id) == "owned" then table.insert(t, id) end
	end
	return t
end

-- Units the player has UNLOCKED ("unlockable") but doesn't yet OWN — eligible to
-- be granted as a NEW unit from a pack.
local function unlockableUnitsOfRarity(rarity: string)
	local t = {}
	for _, id in ipairs(unitsOfRarity(rarity)) do
		if PlayerData.unitUnlockState(id) == "unlockable" then table.insert(t, id) end
	end
	return t
end

-- Vary a value by ±25%, rounded, min 0.
local function vary(avg: number): number
	if avg <= 0 then return 0 end
	local lo = avg * 0.75
	local hi = avg * 1.25
	local v = lo + math.random() * (hi - lo)
	return math.max(0, math.floor(v + 0.5))
end

-- ── Roll a pack (decide what it gives, without applying) ─────────────────────
-- Returns: {
--   packId, packName,
--   newUnits = { ids... },                    -- units to add to collection
--   cards = { [unitId] = count, ... },        -- dupe XP per unit
--   cardsByRarity = { [rarity] = totalCount }, -- summary for display
--   totalCards,
-- }
function PackOpening.roll(packId: string)
	local def = PACKS[packId]
	if not def then return nil end

	local result = {
		packId = packId, packName = def.name,
		newUnits = {}, cards = {}, cardsByRarity = {}, totalCards = 0,
	}

	-- 1) New-unit step: roll each rarity independently.
	for rarity, chance in pairs(def.newUnit) do
		if math.random() < chance then
			local pool = unlockableUnitsOfRarity(rarity)
			if #pool > 0 then
				local pick = pool[math.random(1, #pool)]
				table.insert(result.newUnits, pick)
			end
		end
	end

	-- 2) XP-card step: per rarity, ~avg cards (±25%), assigned to random owned units.
	local order = { "Common", "Rare", "Epic", "Legendary" }
	for _, rarity in ipairs(order) do
		local avg = def.xpAvg[rarity]
		if avg and avg > 0 then
			local owned = ownedUnitsOfRarity(rarity)
			-- a unit just granted as new this open counts as owned for receiving cards
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
				-- respect the pack cap on total cards
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

-- ── Apply a rolled result to PlayerData (grants units + XP) ───────────────────
function PackOpening.apply(result)
	if not result then return end
	-- own new units first
	for _, id in ipairs(result.newUnits) do
		PlayerData.ownUnit(id)
	end
	-- then add the dupe XP per unit
	for unitId, count in pairs(result.cards) do
		PlayerData.addUnitXp(unitId, count)
	end
end

-- Convenience: roll + apply in one call. Returns the result for display.
function PackOpening.open(packId: string)
	local result = PackOpening.roll(packId)
	PackOpening.apply(result)
	return result
end

return PackOpening
