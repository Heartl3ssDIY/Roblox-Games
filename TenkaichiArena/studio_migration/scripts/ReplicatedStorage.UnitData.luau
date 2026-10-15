export type Range = {
	category: string,
	value: number,
}

export type Unit = {
	id: string,
	name: string,
	rarity: string,
	type: string,
	mobile: boolean,
	lines: { string },
	health: number,
	damage: number,
	range: Range,
	hitSpeed: number,
	damagePattern: string,
	ability: string?,
	model: string,
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
		mobile = false,
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
		mobile = true,
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
		mobile = true,
		lines = { "mid" },
		health = 93,
		damage = 100,
		range = { category = "Short", value = 2 },
		hitSpeed = 1.0,
		damagePattern = "AoE",
		ability = nil,
		model = "Tein",
	},

	MasterRoshu = {
		id = "MasterRoshu",
		name = "Master Roshu",
		rarity = "Common",
		type = "Tank",
		mobile = false,
		lines = { "back" },

		health = 190,
		damage = 133,
		range = { category = "Long", value = 5 },
		hitSpeed = 5.3,
		damagePattern = "Blast Single",
		ability = nil,
		model = "Master Roshu",
	},

	Bluma = {
		id = "Bluma",
		name = "Bluma",
		rarity = "Common",
		type = "Artillery",
		mobile = true,
		lines = { "front" },
		health = 79,
		damage = 18,
		range = { category = "Short", value = 1 },
		hitSpeed = 0.5,
		damagePattern = "Artillery Single",
		ability = nil,
		model = "Bluma",

		unlockable = true,
		unlockArena = "Tenkaichi",
		unlockPoints = 50,
	},

	Pikkolo = {
		id = "Pikkolo",
		name = "Pikkolo",
		rarity = "Rare",
		type = "Energy",
		mobile = true,
		lines = { "mid" },
		health = 161,
		damage = 24,
		range = { category = "Short", value = 1 },
		hitSpeed = 0.3,
		damagePattern = "Blast Single",
		ability = "Nameekian Split",

		model = "Pikkolo",
		unlockable = true,
		unlockArena = "Tenkaichi",
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

