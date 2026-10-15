-- SpecialConfig: the special gift-truck event. Tunable data only.
local SpecialConfig={}

SpecialConfig.BaseChance   = 0.25   -- chance per GLOBAL in-game day the truck appears (resets weekly, halves per appearance)
SpecialConfig.WindowHours  = 3      -- in-game hours the gifts stay before they clear (1 in-game hr = 1 real min)
-- The truck now arrives at a RANDOM in-game hour during the DAY (seeded per global day, so it's not always at midnight/night).
SpecialConfig.EarliestHour = 7      -- earliest in-game hour the truck can arrive
SpecialConfig.LatestHour   = 17     -- latest in-game hour it can arrive (window ends before night)
SpecialConfig.MinPackages  = 5
SpecialConfig.MaxPackages  = 25
SpecialConfig.TownCentre   = Vector3.new(20, 0.2, -450)   -- where the gifts drop (matches the plaza)
SpecialConfig.ScatterRadius= 26

-- Black-market carry upgrades: crypto cost for each +1 (base carry = 1, max 5).
SpecialConfig.CarryUpgrades = {50, 150, 250, 500}

-- Reward table for opening a gift (each `w` is the % chance per package; weights sum to exactly 100,
-- so every parcel rolls these odds independently). Each entry's `kind` drives RewardService.
SpecialConfig.Rewards = {
	{w=0.03, kind="cashMultCurrent",   mult=2,               label="x2 your current Cash!"},
	{w=0.07, kind="cryptoMultCurrent", mult=2,               label="x2 your current Crypto!"},
	{w=0.1,  kind="mutatePackages",    to="Rainbow",          label="All your staged packages turned RAINBOW!"},
	{w=1.0,  kind="mutatePackages",    to="Gold",             label="All your staged packages turned GOLD!"},
	{w=2.0,  kind="forceWeather",      weather="Rainbow",     label="Tomorrow's weather: RAINBOW!"},
	{w=5.0,  kind="forceWeather",      weather="Thunderstorm",label="Tomorrow's weather: Thunderstorm!"},
	{w=7.0,  kind="forceWeather",      weather="Snow",        label="Tomorrow's weather: Snow!"},
	{w=10.0, kind="forceWeather",      weather="Rain",        label="Tomorrow's weather: Rain!"},
	{w=0.6,  kind="cash",   amount=1000000, label="+$1,000,000!"},
	{w=5.0,  kind="cash",   amount=400000,  label="+$400,000!"},
	{w=40.0, kind="cash",   amount=10000,   label="+$10,000"},
	{w=0.2,  kind="crypto", amount=650,     label="+650 Crypto"},
	{w=2.0,  kind="crypto", amount=200,     label="+200 Crypto"},
	{w=7.0,  kind="crypto", amount=40,      label="+40 Crypto"},
	{w=10.0, kind="boost",  boost="xp",   mins=15, label="x2 XP for 15 minutes!"},
	{w=10.0, kind="boost",  boost="cash", mins=15, label="x2 parcel Cash for 15 minutes!"},
}

return SpecialConfig

