-- RewardService: rolls + applies a special-gift reward from SpecialConfig.Rewards.
local RS=game:GetService("ReplicatedStorage")
local CurrencyService=require(script.Parent.CurrencyService)
local WeatherService=require(script.Parent.WeatherService)
local PlotService=require(script.Parent.PlotService)
local PackageService=require(script.Parent.PackageService)
local SpecialConfig=require(RS.Configs.SpecialConfig)

local RewardService={}
local function notify(plr,text,kind)
	local rem=RS:FindFirstChild("Remotes"); local n=rem and rem:FindFirstChild("Notify")
	if n then n:FireClient(plr,{text=text,kind=kind or "success"}) end
end

-- weighted pick (table sums ~99%; the ~1% remainder falls through to the last small reward)
function RewardService.roll()
	local total=0; for _,r in ipairs(SpecialConfig.Rewards) do total+=r.w end
	local x=math.random()*math.max(total,100)
	local acc=0
	for _,r in ipairs(SpecialConfig.Rewards) do acc+=r.w; if x<=acc then return r end end
	return SpecialConfig.Rewards[#SpecialConfig.Rewards]
end

function RewardService.apply(plr, r)
	-- weather mutations + timed XP/Cash boosts go to the player's INVENTORY to activate on demand
	-- (they don't auto-apply; everything else below still applies immediately on delivery)
	if r.kind=="forceWeather" then require(script.Parent.InventoryService).add(plr, {kind="weather", weather=r.weather, label=r.label}); return end
	if r.kind=="boost" then require(script.Parent.InventoryService).add(plr, {kind="boost", boost=r.boost, mins=r.mins, label=r.label}); return end
	if r.kind=="cash" then CurrencyService.Add(plr,"Cash",r.amount)
	elseif r.kind=="crypto" then CurrencyService.Add(plr,"Crypto",r.amount)
	elseif r.kind=="cashMultCurrent" then CurrencyService.Add(plr,"Cash", math.floor(CurrencyService.Get(plr,"Cash")*(r.mult-1)))
	elseif r.kind=="cryptoMultCurrent" then CurrencyService.Add(plr,"Crypto", math.floor(CurrencyService.Get(plr,"Crypto")*(r.mult-1)))
	elseif r.kind=="mutatePackages" then
		local plot=PlotService.forPlayer(plr)
		if plot then for _,pkg in ipairs(plot.stagedPackages or {}) do if pkg and pkg.Parent then pcall(function() PackageService.setRarity(pkg, r.to) end) end end end
	end
	pcall(function() CurrencyService.SaveNow(plr) end)
	notify(plr, "Gift opened: "..(r.label or "a reward"), "success")
end

function RewardService.give(plr)
	local r=RewardService.roll(); RewardService.apply(plr, r); return r
end

-- weighted pick that returns the INDEX into SpecialConfig.Rewards. Each gift package rolls its own
-- index at spawn (stored as a RewardIdx attribute) so every parcel is independently determined --
-- a 10-package haul is 10 separate rolls, not one roll applied to the whole haul.
function RewardService.rollIndex()
	local total=0; for _,r in ipairs(SpecialConfig.Rewards) do total+=r.w end
	local x=math.random()*math.max(total,100)
	local acc=0
	for i,r in ipairs(SpecialConfig.Rewards) do acc+=r.w; if x<=acc then return i end end
	return #SpecialConfig.Rewards
end

-- apply the reward a package was assigned at spawn (falls back to a fresh roll if missing)
function RewardService.giveByIndex(plr, idx)
	local r=idx and SpecialConfig.Rewards[idx]
	if not r then return RewardService.give(plr) end
	RewardService.apply(plr, r); return r
end

-- Apply (and STACK) a timed boost: extends the remaining time rather than overwriting, so buying/
-- winning multiple x2 XP or x2 Cash boosts adds up. Used by gift rewards AND the Robux potions.
function RewardService.addBoost(plr, kind, seconds)
	local attr=(kind=="xp") and "XpBoostUntil" or "CashBoostUntil"
	local base=math.max(os.time(), plr:GetAttribute(attr) or 0)
	plr:SetAttribute(attr, base + (seconds or 900))
	return plr:GetAttribute(attr)
end
return RewardService

