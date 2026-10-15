-- CurrencyService: server-authoritative Cash/Crypto + lifetime Xp/Level, with DataStore save/load.
local DataStoreService=game:GetService("DataStoreService"); local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Progression=require(RS.Configs.ProgressionConfig)
local SessionLockService=require(script.Parent.SessionLockService)

local CurrencyService={}
local DEFAULTS={Cash=2500, Crypto=0, Xp=0, Deliveries=0, investorSummonDay=0}
local store=DataStoreService:GetDataStore("WarehouseSim_v1")
local cache={}
local loadedOK={}   -- [UserId]=true only when this player's data read OK (or they're brand new). Gates saving per-player.
local function notify(plr,text,kind)
	local R=RS:FindFirstChild("Remotes"); local n=R and R:FindFirstChild("Notify")
	if n then n:FireClient(plr,{text=text,kind=kind or "success"}) end
end

local function keyFor(plr) return "Player_"..plr.UserId end
local function loadProfile(plr)
	local data, gotData
	for attempt=1,5 do
		local success,err=pcall(function() data=store:GetAsync(keyFor(plr)) end)
		if success then gotData=true; break end
		warn("[CurrencyService] load attempt "..attempt.." failed for "..plr.Name..": "..tostring(err))
		task.wait(2*attempt)
	end
	-- Only treat this server as save-authoritative if BOTH the read succeeded AND we hold the session lock.
	local lockHeld=SessionLockService.wait(plr)
	loadedOK[plr.UserId]=(gotData and lockHeld) or false
	if not gotData then
		warn("[CurrencyService] LOAD FAILED for "..plr.Name.." after retries -- saving DISABLED for them this session to protect their data")
	elseif not lockHeld then
		warn("[CurrencyService] no session lock for "..plr.Name.." -- READ-ONLY this session (saving disabled)")
	end
	if type(data)~="table" then data={} end
	return {Cash=data.Cash or DEFAULTS.Cash, Crypto=data.Crypto or DEFAULTS.Crypto, Xp=data.Xp or DEFAULTS.Xp, Deliveries=data.Deliveries or DEFAULTS.Deliveries, tutorialDone=(data.tutorialDone==true), investorSummonDay=data.investorSummonDay or 0}
end
local function buildFolder(plr,profile)
	local f=Instance.new("Folder"); f.Name="Currency"
	for _,k in ipairs({"Cash","Crypto","Xp","Level","Deliveries"}) do
		local v=Instance.new("IntValue"); v.Name=k; v.Parent=f
	end
	f.Cash.Value=profile.Cash; f.Crypto.Value=profile.Crypto; f.Xp.Value=profile.Xp
	f.Deliveries.Value=profile.Deliveries
	f.Level.Value=(Progression.levelForXp(profile.Xp))
	f.Parent=plr
end
local function onAdded(plr)
	local profile=loadProfile(plr); cache[plr.UserId]=profile; buildFolder(plr,profile)
	plr:SetAttribute("InvestorSummonDay", profile.investorSummonDay or 0)   -- once/day gate for the summon product
end

function CurrencyService.Get(plr,kind) local p=cache[plr.UserId]; return p and (p[kind] or 0) or 0 end
function CurrencyService.Add(plr,kind,amount)
	local p=cache[plr.UserId]; if not p then return false end
	p[kind]=(p[kind] or 0)+amount
	local f=plr:FindFirstChild("Currency"); if f and f:FindFirstChild(kind) then f[kind].Value=p[kind] end
	return true
end
function CurrencyService.CanAfford(plr,kind,cost) return CurrencyService.Get(plr,kind)>=cost end
function CurrencyService.Spend(plr,kind,cost)
	if not CurrencyService.CanAfford(plr,kind,cost) then return false end
	CurrencyService.Add(plr,kind,-cost); return true
end
function CurrencyService.AddDelivery(plr,n)
	local p=cache[plr.UserId]; if not p then return end
	p.Deliveries=(p.Deliveries or 0)+(n or 1)
	local f=plr:FindFirstChild("Currency")
	if f and f:FindFirstChild("Deliveries") then f.Deliveries.Value=p.Deliveries end
end
function CurrencyService.AddXp(plr,amount)
	local p=cache[plr.UserId]; if not p then return end
	if (plr:GetAttribute("XpBoostUntil") or 0) > os.time() then amount=amount*2 end   -- x2 XP boost
	local oldLevel=Progression.levelForXp(p.Xp or 0)
	p.Xp=(p.Xp or 0)+amount
	local newLevel=Progression.levelForXp(p.Xp)
	local f=plr:FindFirstChild("Currency")
	if f then f.Xp.Value=p.Xp; f.Level.Value=newLevel end
	if newLevel>oldLevel then CurrencyService.grantLevelRewards(plr, oldLevel, newLevel) end
end

local function save(plr)
	if not loadedOK[plr.UserId] then return end   -- never overwrite data we couldn't load
	local p=cache[plr.UserId]; if not p then return end
	for attempt=1,4 do
		local ok=pcall(function() store:SetAsync(keyFor(plr),{Cash=p.Cash,Crypto=p.Crypto,Xp=p.Xp,Deliveries=p.Deliveries,tutorialDone=p.tutorialDone,investorSummonDay=p.investorSummonDay}) end)
		if ok then return end
		task.wait(attempt)
	end
	warn("[CurrencyService] SAVE FAILED for "..plr.Name.." after retries")
end

-- Public force-save: used right after a Robux purchase grants currency so it persists immediately.
function CurrencyService.SaveNow(plr) save(plr) end
function CurrencyService.setInvestorDay(plr, day)
	local p=cache[plr.UserId]; if p then p.investorSummonDay=day end
	plr:SetAttribute("InvestorSummonDay", day)
end
-- Level-up reward SCHEDULE: not every level has a reward, and each rewarded level grants exactly
-- ONE reward. Rotates cash / crypto / x2 XP potion / x2 parcel-cash potion, scaling with level.
-- Tune freely -- add/remove [level]=reward entries; levels without an entry give nothing.
local LEVEL_REWARDS = {
	[2]  = {kind="cash",      amount=3000},
	[3]  = {kind="crypto",    amount=5},
	[5]  = {kind="xpboost",   mins=5},
	[7]  = {kind="cash",      amount=10000},
	[9]  = {kind="crypto",    amount=10},
	[11] = {kind="cashboost", mins=5},
	[13] = {kind="cash",      amount=20000},
	[15] = {kind="xpboost",   mins=8},
	[18] = {kind="crypto",    amount=18},
	[21] = {kind="cash",      amount=40000},
	[24] = {kind="cashboost", mins=8},
	[27] = {kind="crypto",    amount=28},
	[30] = {kind="xpboost",   mins=10},
	[34] = {kind="cash",      amount=75000},
	[38] = {kind="crypto",    amount=40},
	[42] = {kind="cashboost", mins=10},
	[46] = {kind="cash",      amount=120000},
	[50] = {kind="xpboost",   mins=12},
	[55] = {kind="crypto",    amount=60},
	[60] = {kind="cash",      amount=220000},
	[65] = {kind="cashboost", mins=12},
	[70] = {kind="crypto",    amount=90},
	[75] = {kind="xpboost",   mins=15},
	[80] = {kind="cash",      amount=400000},
	[85] = {kind="crypto",    amount=130},
	[90] = {kind="cash",      amount=750000},
}
-- Grant the single scheduled reward for each newly-reached level (handles multi-level jumps).
function CurrencyService.grantLevelRewards(plr, fromLevel, toLevel)
	local granted=false
	for lvl=fromLevel+1, toLevel do
		local r=LEVEL_REWARDS[lvl]
		if r then
			granted=true
			if r.kind=="cash" then
				CurrencyService.Add(plr,"Cash",r.amount)
				notify(plr, ("Level %d! Reward: +$%d"):format(lvl, r.amount), "success")
			elseif r.kind=="crypto" then
				CurrencyService.Add(plr,"Crypto",r.amount)
				notify(plr, ("Level %d! Reward: +%d Crypto"):format(lvl, r.amount), "success")
			elseif r.kind=="xpboost" then
				local secs=(r.mins or 5)*60
				plr:SetAttribute("XpBoostUntil", math.max(os.time(), plr:GetAttribute("XpBoostUntil") or 0)+secs)
				notify(plr, ("Level %d! Reward: x2 XP for %d min"):format(lvl, r.mins or 5), "success")
			elseif r.kind=="cashboost" then
				local secs=(r.mins or 5)*60
				plr:SetAttribute("CashBoostUntil", math.max(os.time(), plr:GetAttribute("CashBoostUntil") or 0)+secs)
				notify(plr, ("Level %d! Reward: x2 Parcel Cash for %d min"):format(lvl, r.mins or 5), "success")
			end
		end
	end
	if not granted then notify(plr, ("Reached Level %d!"):format(toLevel), "info") end  -- acknowledge once, no spam
	if granted then save(plr) end
end
-- first-time tutorial flag (persisted in the Player_ save)
function CurrencyService.isTutorialDone(plr) local p=cache[plr.UserId]; return (p and p.tutorialDone)==true end
function CurrencyService.markTutorialDone(plr) local p=cache[plr.UserId]; if p and not p.tutorialDone then p.tutorialDone=true; save(plr) end end

function CurrencyService.Start()
	Players.PlayerAdded:Connect(onAdded)
	for _,plr in ipairs(Players:GetPlayers()) do onAdded(plr) end
	Players.PlayerRemoving:Connect(function(plr) save(plr); cache[plr.UserId]=nil; loadedOK[plr.UserId]=nil end)
	game:BindToClose(function()
		local pending=0
		for _,plr in ipairs(Players:GetPlayers()) do pending+=1; task.spawn(function() save(plr); pending-=1 end) end
		local t=0; while pending>0 and t<25 do task.wait(0.2); t+=0.2 end
	end)
	task.spawn(function() while true do task.wait(30) for _,plr in ipairs(Players:GetPlayers()) do save(plr) end end end)
	print("[CurrencyService] started (per-player save protection on)")
end
return CurrencyService

