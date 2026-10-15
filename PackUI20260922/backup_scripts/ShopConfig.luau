--!strict
-- ShopConfig: all shop items, prices, and daily-claim state.
local ShopConfig = {}

ShopConfig.packs = {
	{ id = "silver",  name = "Silver Pack",  cost = 100, currency = "gems", color = Color3.fromRGB(180,190,205) },
	{ id = "gold",    name = "Gold Pack",    cost = 200, currency = "gems", color = Color3.fromRGB(245,205,90) },
	{ id = "diamond", name = "Diamond Pack", cost = 500, currency = "gems", color = Color3.fromRGB(110,220,255) },
}
ShopConfig.bitPacks = {
	{ id = "bit1", name = "Common Bit Pack", cost = 15, currency = "robux", daily = true },
	{ id = "bit2", name = "Common Bit Pack", cost = 15, currency = "robux", daily = true },
}
ShopConfig.dropRates = {
	silver  = { Common = 80, Rare = 18, Epic = 2 },
	gold    = { Common = 60, Rare = 32, Epic = 8 },
	diamond = { Common = 40, Rare = 42, Epic = 18 },
}
ShopConfig.packXp = { silver = 20, gold = 50, diamond = 120 }

ShopConfig.gemBundles = {
	{ id = "gems_free", name = "Daily Gems",    amount = 5,     cost = 0,     currency = "free",  daily = true },
	{ id = "gems_200",  name = "Pouch of Gems", amount = 200,   cost = 150,   currency = "robux" },
	{ id = "gems_1000", name = "Sack of Gems",  amount = 1000,  cost = 750,   currency = "robux" },
	{ id = "gems_4200", name = "Chest of Gems", amount = 4200,  cost = 3000,  currency = "robux" },
	{ id = "gems_11000",name = "Vault of Gems", amount = 11000, cost = 7500,  currency = "robux" },
	{ id = "gems_24000",name = "Hoard of Gems", amount = 24000, cost = 11000, currency = "robux" },
}
ShopConfig.coinBundles = {
	{ id = "coins_free", name = "Daily Coins",     amount = 500,    cost = 0,    currency = "free",  daily = true },
	{ id = "coins_1500", name = "Handful of Coins",amount = 1500,   cost = 9,    currency = "robux", daily = true },
	{ id = "coins_5k",   name = "Bag of Coins",    amount = 5000,   cost = 400,  currency = "gems" },
	{ id = "coins_25k",  name = "Crate of Coins",  amount = 25000,  cost = 1400, currency = "gems" },
	{ id = "coins_100k", name = "Vault of Coins",  amount = 100000, cost = 4000, currency = "gems" },
	{ id = "coins_250k", name = "Fortune of Coins",amount = 250000, cost = 7200, currency = "gems" },
}
ShopConfig.chipBundles = {
	{ id = "chips_5",    name = "Chip Handful", amount = 5,    cost = 9,    currency = "robux", daily = true },
	{ id = "chips_200",  name = "Chip Stack",   amount = 200,  cost = 1000, currency = "gems" },
	{ id = "chips_1100", name = "Chip Trove",   amount = 1100, cost = 4800, currency = "gems" },
}
ShopConfig.dailyDeals = {
	{ id = "deal_gems25", name = "25 Gems",          giveGems = 25,     cost = 19,   currency = "robux", daily = true },
	{ id = "deal_xpcard", name = "Random XP Card",   randomCard = true, cost = 9,    currency = "robux", daily = true },
	{ id = "deal_4units", name = "4 Unit XP Bundle", fourCards = true,  cost = 1000, currency = "coins", daily = true },
}

local claims = {}
local DAY = 24 * 60 * 60
function ShopConfig.canClaim(id) local l = claims[id]; if not l then return true end return (os.time()-l) >= DAY end
function ShopConfig.secondsUntilClaim(id) local l = claims[id]; if not l then return 0 end return math.max(0, DAY-(os.time()-l)) end
function ShopConfig.markClaimed(id) claims[id] = os.time() end
ShopConfig.DAY = DAY
return ShopConfig
