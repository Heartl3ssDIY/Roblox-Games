-- StoreService: the Robux store. Processes Developer Product receipts (cash / crypto / luck /
-- exceptional employee) idempotently, and (later) Game Pass ownership for the Golden Hauler truck.
-- Product IDs live in ReplicatedStorage.Configs.ProductConfig -- fill them from the Creator Dashboard.
local MarketplaceService=game:GetService("MarketplaceService")
local DataStoreService=game:GetService("DataStoreService")
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local ProductConfig=require(RS.Configs.ProductConfig)
local CurrencyService=require(script.Parent.CurrencyService)

local StoreService={}
local receiptStore=DataStoreService:GetDataStore("PurchaseHistory_v1")
local pendingEmployee={}   -- userId -> {name=, shift=} set by the client just before prompting the buy
local adminGrants={}       -- userId -> {passKey=true} : admin/test-granted gamepass perks (treated as owned)
local ownedCache={}        -- userId -> {passKey=true} : passes CONFIRMED owned (cached + persisted in Econ.passes) so a rejoin never loses a perk to a flaky web call

local function notify(plr,text,kind)
	local R=RS:FindFirstChild("Remotes"); local n=R and R:FindFirstChild("Notify")
	if n then n:FireClient(plr,{text=text,kind=kind or "info"}) end
end

local function productById(id)
	for _,p in ipairs(ProductConfig.Products) do if (p.productId or 0)==id and id>0 then return p end end
	return nil
end

-- ===== grants (return true on success) =====
local grants={}
grants.cash=function(plr,p)
	if not CurrencyService.Add(plr,"Cash",p.amount) then return false end
	CurrencyService.SaveNow(plr)
	notify(plr,"Added "..p.amount.." Cash!","success")
	return true
end
grants.crypto=function(plr,p)
	if not CurrencyService.Add(plr,"Crypto",p.amount) then return false end
	CurrencyService.SaveNow(plr)
	notify(plr,"Added "..p.amount.." Crypto!","success")
	return true
end
grants.employee=function(plr,p)
	local pend=pendingEmployee[plr.UserId] or {}
	pendingEmployee[plr.UserId]=nil
	local WorkerService=require(script.Parent.WorkerService)
	local maxOwned=p.maxOwned or 6
	local count,reason=WorkerService.addExceptional(plr, pend.name, pend.shift or "Morning", maxOwned)
	if not count then
		if reason=="max" then
			-- Cap is enforced in the store UI (button disables at X/maxOwned); reaching here is an edge
			-- case. Robux can't be refunded, so consume the receipt and tell the player.
			notify(plr,"You already own the max of "..maxOwned.." Exceptional Workers.","error")
			return true
		end
		return false  -- bad shift etc: let Roblox retry rather than silently swallow the purchase
	end
	pcall(function() require(script.Parent.SaveService).save(plr) end)   -- persist immediately
	notify(plr,(pend.name or "Your Exceptional Worker").." joined the "..(pend.shift or "Morning").." shift!  ("..count.."/"..maxOwned..")","success")
	return true
end

grants.xpboost=function(plr,p)
	require(script.Parent.RewardService).addBoost(plr, "xp", (p.mins or 15)*60)   -- stacks (extends remaining time)
	notify(plr,"x2 XP active for "..(p.mins or 15).." min (stacks)!","success")
	return true
end
grants.cashboost=function(plr,p)
	require(script.Parent.RewardService).addBoost(plr, "cash", (p.mins or 15)*60)
	notify(plr,"x2 Parcel Cash active for "..(p.mins or 15).." min (stacks)!","success")
	return true
end
grants.forceweather=function(plr,p)
	-- LOCAL to this server (forceNextDay sets a per-server pending). Client blocks buying while active.
	require(script.Parent.WeatherService).forceNextDay(p.weather)
	notify(plr,"Next day's weather forced to "..tostring(p.weather).." on THIS server!","success")
	return true
end
grants.forcetruck=function(plr,p)
	local S=require(script.Parent.SpecialTruckService)
	if S.isActive() then notify(plr,"A gift truck is already here!","error"); return true end  -- consume receipt, no double-spawn
	S.force()   -- LOCAL to this server
	notify(plr,"You summoned a special gift truck on this server!","success")
	return true
end
grants.forceinvestor=function(plr,p)
	require(script.Parent.InvestorService).summon(plr, 600)   -- 25% Cash for Crypto at 600:1
	return true   -- consume receipt (summon notifies; Robux can't refund the low-cash edge)
end
grants.instantload=function(plr,p)
	local plot=require(script.Parent.PlotService).forPlayer(plr)
	if not plot then return false end
	local n=require(script.Parent.TruckService).instantLoadAll(plot)
	notify(plr,"Rush load: "..n.." parcels loaded onto your trucks!","success")
	return true
end

local function grant(plr,product)
	local fn=grants[product.kind]; if not fn then return false end
	local ok,res=pcall(fn,plr,product)
	if not ok then warn("[StoreService] grant error: "..tostring(res)) end
	return ok and res==true
end

-- ===== receipt processing (idempotent via a dedicated history store) =====
local function processReceipt(info)
	local plr=Players:GetPlayerByUserId(info.PlayerId)
	if not plr then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local product=productById(info.ProductId)
	if not product then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local key="receipts_"..info.PlayerId
	local pid=tostring(info.PurchaseId)
	local already=false
	local ok=pcall(function()
		receiptStore:UpdateAsync(key,function(old)
			old=old or {}
			if old[pid] then already=true; return old end
			old[pid]=os.time(); return old
		end)
	end)
	if not ok then return Enum.ProductPurchaseDecision.NotProcessedYet end
	if already then return Enum.ProductPurchaseDecision.PurchaseGranted end
	if grant(plr,product) then return Enum.ProductPurchaseDecision.PurchaseGranted end
	-- grant failed (e.g. player left): unmark so Roblox retries, no double-charge / no double-grant
	pcall(function() receiptStore:UpdateAsync(key,function(old) if old then old[pid]=nil end return old end) end)
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- ===== Game Pass ownership (equip-slot passes + the gold truck) =====
-- Perks are exposed as player ATTRIBUTES so other services read them with zero coupling:
--   ExtraEquipSlots (number) -> WorkerService adds this to the per-shift equip cap
--   OwnsGoldTruck   (bool)   -> the truck shop will unlock the Golden Hauler
-- Robust ownership: a game pass is permanent, so once we've CONFIRMED a player owns one (this session
-- or restored from their save) we trust it forever -- a flaky UserOwnsGamePassAsync on a later join can
-- then never strip a perk they paid for. Un-confirmed passes are queried with a few retries.
local function ownsPass(plr, pass)
	local uid=plr.UserId
	if adminGrants[uid] and adminGrants[uid][pass.key] then return true end
	if ownedCache[uid] and ownedCache[uid][pass.key] then return true end
	if (pass.gamePassId or 0)<=0 then return false end
	for attempt=1,3 do
		local ok2,res=pcall(function() return MarketplaceService:UserOwnsGamePassAsync(uid, pass.gamePassId) end)
		if ok2 then
			if res then ownedCache[uid]=ownedCache[uid] or {}; ownedCache[uid][pass.key]=true; return true end
			return false   -- definitively NOT owned
		end
		task.wait(0.4*attempt)   -- web call failed; back off and retry
	end
	return false   -- all retries failed and we never confirmed it before
end

local function refreshPasses(plr)
	local extraSlots, ownsTruck = 0, false
	local luckMult, cashMult = 1, 1
	local workerCarry = 0
	for _,p in ipairs(ProductConfig.Passes) do
		local owns=ownsPass(plr, p)
		if owns then
			if p.kind=="slots" then extraSlots+=(p.bonus or 0)
			elseif p.kind=="truck" then ownsTruck=true
			elseif p.kind=="luck" then luckMult=math.max(luckMult, p.mult or 1)
			elseif p.kind=="cashmult" then cashMult=math.max(cashMult, p.mult or 1)
			elseif p.kind=="workercarry" then workerCarry+=(p.bonus or 1) end
		end
		plr:SetAttribute("Owns_"..p.key, owns)   -- per-pass flag so the store can show owned slot passes
	end
	plr:SetAttribute("ExtraEquipSlots", extraSlots)
	plr:SetAttribute("OwnsGoldTruck", ownsTruck)
	plr:SetAttribute("LuckMult", luckMult)
	plr:SetAttribute("CashMult", cashMult)
	plr:SetAttribute("WorkerCarryPlus", workerCarry)
	return extraSlots, ownsTruck
end

-- re-deploy the player's current shift so a freshly-bought slot takes effect immediately
local function respawnOwnShift(plr)
	pcall(function()
		local PlotService=require(script.Parent.PlotService)
		local WorkerService=require(script.Parent.WorkerService)
		local TimeService=require(script.Parent.TimeService)
		local plot=PlotService.forPlayer(plr)
		if plot then WorkerService.spawnShiftForPlot(plot, TimeService.getShift()) end
	end)
end

-- ===== client remote: stash the chosen name + shift before the employee purchase prompt =====
-- ADMIN: grant (simulate ownership of) a gamepass perk to a player, for testing.
function StoreService.grantPass(plr, passKey)
	if not (plr and passKey) then return false end
	local pass=ProductConfig.byKey(passKey); if not pass or not pass.gamePassId then return false end
	adminGrants[plr.UserId]=adminGrants[plr.UserId] or {}
	adminGrants[plr.UserId][passKey]=true
	refreshPasses(plr); respawnOwnShift(plr)
	return true
end

-- persistence of confirmed pass ownership (SaveService aggregates into Econ.passes)
function StoreService.getSaved(plr) return ownedCache[plr.UserId] or {} end
function StoreService.loadSaved(plr, data)
	if type(data)~="table" then return end
	local t=ownedCache[plr.UserId] or {}
	for k,v in pairs(data) do if v then t[tostring(k)]=true end end
	ownedCache[plr.UserId]=t
end
-- (re)apply perks; SaveService calls this AFTER restoring the cache and BEFORE spawning the shift so
-- the equip cap is correct when previously-equipped workers come back.
function StoreService.applyPasses(plr) return refreshPasses(plr) end
function StoreService.clear(plr) ownedCache[plr.UserId]=nil end

function StoreService.handle(plr, req)
	if type(req)~="table" then return {ok=false} end
	if req.action=="setEmployee" then
		local name=tostring(req.name or ""):gsub("%s+"," "):gsub("^%s+",""):gsub("%s+$",""):sub(1,18)
		if name=="" then name="Ace" end
		local shift=tostring(req.shift or "Morning")
		if shift~="Morning" and shift~="Afternoon" and shift~="Night" then shift="Morning" end
		pendingEmployee[plr.UserId]={name=name, shift=shift}
		return {ok=true, name=name, shift=shift}
	end
	return {ok=false, msg="Unknown store action"}
end

-- Which passes to OFFER a given player (the client store uses this to show/hide buttons).
-- Luck + cash multipliers are UPGRADE-ONLY and resolve to the highest owned (never stack): a luck
-- pass is only offered if its multiplier beats what the player already has -- so owning x5 hides
-- both luck buttons, owning x3 shows only x5, owning neither shows both. The gold truck hides once
-- owned. Slot passes stay available (they're additive). Roblox itself also blocks re-buying a pass.
function StoreService.isPassOffered(plr, pass)
	if (pass.gamePassId or 0)<=0 then return false end
	if pass.kind=="luck" then return (pass.mult or 1) > (plr:GetAttribute("LuckMult") or 1) end
	if pass.kind=="cashmult" then return (pass.mult or 1) > (plr:GetAttribute("CashMult") or 1) end
	if pass.kind=="truck" then return not plr:GetAttribute("OwnsGoldTruck") end
	return true
end

function StoreService.Start()
	local Remotes=RS:WaitForChild("Remotes")
	local store=Remotes:FindFirstChild("Store")
	if not store then store=Instance.new("RemoteFunction"); store.Name="Store"; store.Parent=Remotes end
	store.OnServerInvoke=function(plr,req) return StoreService.handle(plr,req) end
	MarketplaceService.ProcessReceipt=processReceipt

	-- apply game-pass perks on join (and to anyone already in-server), then live on each purchase
	local function onPlayer(plr)
		task.spawn(function()
			local extra=refreshPasses(plr)
			if extra>0 then task.wait(1); respawnOwnShift(plr) end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _,plr in ipairs(Players:GetPlayers()) do onPlayer(plr) end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr, gamePassId, wasPurchased)
		if not wasPurchased then return end
		refreshPasses(plr)
		respawnOwnShift(plr)
		notify(plr, "Game Pass unlocked -- thanks for the support!", "success")
	end)

	Players.PlayerRemoving:Connect(function(plr) pendingEmployee[plr.UserId]=nil; adminGrants[plr.UserId]=nil; ownedCache[plr.UserId]=nil end)
	local soon=0; for _,p in ipairs(ProductConfig.Products) do if (p.productId or 0)<=0 then soon+=1 end end
	print("[StoreService] started (Robux store ready; "..soon.." product(s) still without IDs)")
end
return StoreService

