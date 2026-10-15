-- BlackMarketConfig: black-market catalogue. Tunable data only.
--   kind     : "tool" (persistent weapon you own + equip), "potion" (persistent self-buff active
--              during events), "sabotage" (pay-per-use, targeted at another player)
--   eventOnly: usable only during a special gift-truck event (slap is the exception)
local BlackMarketConfig={}

BlackMarketConfig.Items={
	{key="slap",     name="Slap Tool",       currency="Cash",   cost=100000, kind="tool",     eventOnly=false, blurb="Ragdoll a player for 5s. Usable anytime."},
	{key="freeze",   name="Freeze Ray",      currency="Cash",   cost=200000, kind="tool",     eventOnly=true,  blurb="Freeze a player for 15s. Event only."},
	{key="bat",      name="Bat",             currency="Cash",   cost=500000, kind="tool",     eventOnly=true,  blurb="Knock gifts out of a player's hands + ragdoll 5s. Event only."},
	{key="speed",    name="Speed Potion",    currency="Cash",   cost=250000, kind="potion",   eventOnly=true,  blurb="Drink during an event: x2 walk/run speed for 30s. Single use."},
	{key="immunity", name="Immunity Potion", currency="Cash",   cost=750000, kind="potion",   eventOnly=true,  blurb="Drink during an event: immune to all attacks for 30s. Single use."},
	{key="carpet",   name="Magic Carpet",    currency="Crypto", cost=240,    kind="tool",     eventOnly=true,  blurb="Ride your own magic carpet during a gift-truck event. Lost when the event ends \u{2014} rebuy each event."},
	{key="gun",      name="Gun",             currency="Crypto", cost=400,    kind="tool",     eventOnly=true,  blurb="Send a player back to their warehouse (15s cooldown). Event only."},
	{key="spikes",   name="Road Spikes",     currency="Crypto", cost=250,    kind="sabotage", eventOnly=false, blurb="Halve a target's next filled-truck payout."},
	{key="sabotage2",name="Major Sabotage",  currency="Crypto", cost=1000,   kind="sabotage", eventOnly=false, subs={"resetTrucks","breakPackages","unequipShift"}, blurb="Pick one: reset a target's truck fills, break their fragile packages, or unequip their active shift."},
}
BlackMarketConfig.ByKey={}
for _,it in ipairs(BlackMarketConfig.Items) do BlackMarketConfig.ByKey[it.key]=it end

BlackMarketConfig.SpeedMultiplier=2.5

return BlackMarketConfig

