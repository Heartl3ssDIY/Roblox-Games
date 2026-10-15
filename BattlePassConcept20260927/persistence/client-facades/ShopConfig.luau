local ShopConfig = {}
local changed = Instance.new("BindableEvent")
ShopConfig.Changed = changed.Event

ShopConfig.packs = {
	{ id = "silver",  name = "Silver Pack",  cost = 100, currency = "gems", color = Color3.fromRGB(180,190,205) },
	{ id = "gold",    name = "Gold Pack",    cost = 200, currency = "gems", color = Color3.fromRGB(245,205,90) },
	{ id = "diamond", name = "Diamond Pack", cost = 500, currency = "gems", color = Color3.fromRGB(110,220,255) },
}
ShopConfig.bitPacks = {
	{ id = "bit1", name = "Common Pack", cost = 9, currency = "robux", daily = true },
	{ id = "bit2", name = "Common Pack", cost = 9, currency = "robux", daily = true },
}
ShopConfig.commonPack = { id = "bronze", name = "Common Pack", cost = 9, limit = 2 }
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
local commonIds = {}
for _, pack in ipairs(ShopConfig.bitPacks) do commonIds[pack.id] = true end
function ShopConfig.commonResetSeconds(now)
    now = now or os.time()
    return DAY - now % DAY
end
function ShopConfig.canClaim(id, now)
    local last = claims[id]
    if not last then return true end
    now = now or os.time()
    if commonIds[id] then return math.floor(now / DAY) > math.floor(last / DAY) end
    return now - last >= DAY
end
function ShopConfig.secondsUntilClaim(id, now)
    local last = claims[id]
    if not last or ShopConfig.canClaim(id, now) then return 0 end
    now = now or os.time()
    if commonIds[id] then return ShopConfig.commonResetSeconds(now) end
    return math.max(0, DAY - (now - last))
end
function ShopConfig.markClaimed(id) claims[id] = os.time(); changed:Fire() end
function ShopConfig.commonRemaining()
    local remaining = 0
    for _, pack in ipairs(ShopConfig.bitPacks) do
        if ShopConfig.canClaim(pack.id) then remaining += 1 end
    end
    return remaining
end
ShopConfig.DAY = DAY

local function profileCopy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = profileCopy(child) end
    return result
end

function ShopConfig._profileExport()
    return profileCopy(claims)
end

function ShopConfig._profileHydrate(snapshot)
    assert(type(snapshot) == "table", "shopClaims snapshot required")
    claims = profileCopy(snapshot)
    changed:Fire()
end

return ShopConfig
