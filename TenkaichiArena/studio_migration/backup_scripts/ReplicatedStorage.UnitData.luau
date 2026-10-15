--!strict
-- UnitData: central registry of all unit definitions.
-- Add a new unit by adding an entry to Units keyed by its id.
-- The visual model lives in ReplicatedStorage.UnitModels keyed by `model`.

export type Range = {
	category: string, -- "Short" | "Medium" | "Long"
	value: number,    -- reach on a 1..5 scale
}

export type Unit = {
	id: string,
	name: string,
	rarity: string,          -- "Common" | "Rare" | ...
	type: string,            -- combat role: "Melee" | "Ranged" | "Support" | "Tank"
	mobile: boolean,         -- true = advances toward enemies when none in range
	lines: { string },       -- allowed placement lines: "front" | "mid" | "back"
	health: number,
	damage: number,
	range: Range,
	hitSpeed: number,        -- seconds between attacks (lower = faster)
	damagePattern: string,   -- how damage is packaged per cooldown: "Single" | "Burst" | "AoE"
	ability: string?,        -- nil if none
	model: string,           -- key into ReplicatedStorage.UnitModels
}

local Units: { [string]: Unit } = {
	Yumcha = {
		id = "Yumcha",
		name = "Yumcha",
		rarity = "Common",
		type = "Melee",
		mobile = true,
		lines = { "front" },
		health = 126,
		damage = 13,
		range = { category = "Short", value = 1 },
		hitSpeed = 0.3,
		damagePattern = "Single",
		ability = nil,
		model = "Yumcha",
	},

	Goku = {
		id = "Goku",
		name = "Goku",
		rarity = "Common",
		type = "Ranged",
		mobile = false,                -- fixed: holds position and shoots, slow-creeps only when nothing in range
		lines = { "back" },
		health = 152,
		damage = 26,
		range = { category = "Long", value = 4 },
		hitSpeed = 1.0,
		damagePattern = "Single",
		ability = nil,
		model = "Guku",
	},

	Krillen = {
		id = "Krillen",
		name = "Krillen",
		rarity = "Common",
		type = "Melee",
		mobile = true,                 -- PLACEHOLDER pending confirmation (melee frontline)
		lines = { "front" },
		health = 67,
		damage = 13,
		range = { category = "Short", value = 1 },
		hitSpeed = 0.3,
		damagePattern = "Single",
		ability = nil,
		model = "Krillen",
	},

	Tein = {
		id = "Tein",
		name = "Tein",
		rarity = "Common",
		type = "Energy",
		mobile = true,                 -- advances toward enemies; AoE laser bounded by range (Short/2)
		lines = { "mid" },
		health = 93,
		damage = 100,
		range = { category = "Short", value = 2 },
		hitSpeed = 1.0,
		damagePattern = "AoE",          -- laser from third eye, hits multiple units in an area (not scripted yet)
		ability = nil,
		model = "Tein",
	},

	MasterRoshu = {
		id = "MasterRoshu",
		name = "Master Roshu",
		rarity = "Common",
		type = "Tank",
		mobile = false,                -- tank backline: holds position, slow-creeps only when idle
		lines = { "back" },
		-- Tank backline behaviour (for later combat scripting): starts BEHIND ranged
		-- backlines, and targets the FURTHEST enemy in range, working inward.
		health = 190,
		damage = 133,
		range = { category = "Long", value = 5 },
		hitSpeed = 5.3,
		damagePattern = "Blast Single", -- single-target Kamehameha every 5.3s (not scripted yet)
		ability = nil,
		model = "Master Roshu",
	},

	Bluma = {
		id = "Bluma",
		name = "Bluma",
		rarity = "Common",
		type = "Artillery",
		mobile = true,                 -- artillery frontline (advances); confirm if it should hold
		lines = { "front" },
		health = 79,
		damage = 18,
		range = { category = "Short", value = 1 },
		hitSpeed = 0.5,
		damagePattern = "Artillery Single",  -- fires her gun once per attack, single target
		ability = nil,
		model = "Bluma",
		-- Unlockable: not owned at start. Becomes pullable in packs at the
		-- arena milestone below; first pull adds her to the collection.
		unlockable = true,
		unlockArena = "West City",
		unlockPoints = 50,
	},

	Pikkolo = {
		id = "Pikkolo",
		name = "Pikkolo",
		rarity = "Rare",                -- the game's first Rare unit
		type = "Energy",
		mobile = true,                 -- energy midline; confirm mobility
		lines = { "mid" },
		health = 161,
		damage = 24,
		range = { category = "Short", value = 1 },
		hitSpeed = 0.3,
		damagePattern = "Blast Single",
		ability = "Nameekian Split",   -- (not scripted yet) Rules:
		                               -- • 10s after Pikkolo is on the field, spawn a clone:
		                               --   half HP & half damage, all else same, no ability,
		                               --   fires the same energy blasts.
		                               -- • Clone is tethered to Pikkolo: if Pikkolo dies, the
		                               --   clone dies instantly; otherwise it fights until the
		                               --   round ends.
		                               -- • Clone does NOT count toward the deployed-unit total
		                               --   for the win/loss wiped-out check.
		                               -- • Clone is NOT recorded in army history: it does not
		                               --   respawn next round. Each round the 10s timer restarts
		                               --   and a fresh clone spawns.
		model = "Pikkolo",
		unlockable = true,
		unlockArena = "West City",
		unlockPoints = 100,
	},
}

local UnitData = {}
UnitData.Units = Units

function UnitData.get(id: string): Unit?
	return Units[id]
end

function UnitData.all(): { [string]: Unit }
	return Units
end

return UnitData

