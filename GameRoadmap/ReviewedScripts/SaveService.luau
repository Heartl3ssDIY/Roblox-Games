-- SaveService: persists worker roster, per-bay trucks, and unlocked-bay contracts to DataStore.
local DataStoreService=game:GetService("DataStoreService"); local Players=game:GetService("Players"); local WS=game:GetService("Workspace")
local WorkerService=require(script.Parent.WorkerService)
local TruckService=require(script.Parent.TruckService)
local TimeService=require(script.Parent.TimeService)
local PlotService=require(script.Parent.PlotService)
local SessionLockService=require(script.Parent.SessionLockService)
local CustomisationService=require(script.Parent.CustomisationService)
local WarehouseNameService=require(script.Parent.WarehouseNameService)
local AccessService=require(script.Parent.AccessService)
local SpecialTruckService=require(script.Parent.SpecialTruckService)
local BlackMarketService=require(script.Parent.BlackMarketService)
local InventoryService=require(script.Parent.InventoryService)
local SecurityService=require(script.Parent.SecurityService)
local TrophyService=require(script.Parent.TrophyService)
local FurnitureService=require(script.Parent.FurnitureService)
local DailyRewardService=require(script.Parent.DailyRewardService)
local StoreService=require(script.Parent.StoreService)
local RS=game:GetService("ReplicatedStorage")
local CompanyConfig=require(RS.Configs.CompanyConfig); local TruckConfig=require(RS.Configs.TruckConfig)
local MarketplaceService=game:GetService("MarketplaceService")
local ProductConfig=require(RS.Configs.ProductConfig)

local store=DataStoreService:GetDataStore("WarehouseSim_v1")
local SaveService={}; local loadedOK={}   -- per-player gate: only save econ data we actually loaded
local function key(plr) return "Econ_"..plr.UserId end

local function serialize(plr)
	local roster=WorkerService.roster[plr.UserId] or {Morning={},Afternoon={},Night={}}
	local contracts={}; local trucks={}
	local plot=PlotService.forPlayer(plr)
	for _,bay in ipairs(plot.loadBays or {}) do
		local ow={}; for id in pairs(bay.owned or {}) do table.insert(ow,id) end
		trucks[bay.pad.Name]={truckId=bay.truckId, owned=ow, fill=bay.count or 0, fillValue=bay.loadedValue or 0}
		local c=bay.pad:GetAttribute("Company"); if c then contracts[#contracts+1]={bay=bay.pad.Name, company=c} end
	end
	return {roster=roster, trucks=trucks, contracts=contracts, custom=CustomisationService.getSaved(plr), name=WarehouseNameService.getSaved(plr), access=AccessService.getSaved(plr), autoDismiss=WorkerService.getAutoDismiss(plr), carry=SpecialTruckService.getSavedCarry(plr), bm=BlackMarketService.getSaved(plr), inv=InventoryService.getSaved(plr), sec=SecurityService.getSaved(plr), trophy=TrophyService.getSaved(plr), furniture=FurnitureService.getSaved(plr), daily=DailyRewardService.getSaved(plr), passes=StoreService.getSaved(plr)}
end

-- The Golden Hauler is a Robux game pass. Re-validate ownership on EVERY restore so a saved gold
-- truck can't outlive the pass. (Anti-exploit: previously any saved GoldenHauler was restored for
-- free -- a player who ever had one kept it forever, pass or not.)
local function ownsGoldPass(plr)
	if plr:GetAttribute("OwnsGoldTruck")==true then return true end   -- already confirmed by StoreService
	local pass=ProductConfig.byKey("gold_truck"); local id=pass and pass.gamePassId
	if not id or id<=0 then return false end
	local ok,res=pcall(function() return MarketplaceService:UserOwnsGamePassAsync(plr.UserId, id) end)
	return ok and res==true
end
local function applyTrucks(plr, data, plot)
	if not data.trucks then return end
	local goldOk=ownsGoldPass(plr)
	for _,bay in ipairs(plot.loadBays or {}) do
		local td=data.trucks[bay.pad.Name]
		if td then
			local owned={Starter=true}; if td.owned then for _,id in ipairs(td.owned) do owned[id]=true end end
			local tid=td.truckId or "Starter"
			if not goldOk then owned.GoldenHauler=nil; if tid=="GoldenHauler" then tid="Starter" end end   -- strip ungated gold truck
			bay.truckId=tid
			bay.owned=owned
			bay.pad:SetAttribute("TruckId", bay.truckId)
			local t=TruckConfig.getTruck(bay.truckId)
			if t then bay.capacity=t.capacity; if bay.truck and not bay.leaving then bay.truck:Destroy(); bay:spawnTruck() end end
			if (td.fill or 0)>0 then pcall(function() TruckService.restoreFill(bay, td.fill, td.fillValue) end) end   -- persist current truck fill
		end
	end
end

local function restore(plr, data)
	local plot=PlotService.forPlayer(plr)
	if not data then return end
	if data.roster then WorkerService.roster[plr.UserId]=data.roster end
	-- contracts: the SAVE is authoritative for a RETURNING player (data~=nil; new players returned
	-- early above and keep the baked starter contract). Reconcile EVERY load bay to the save: clear a
	-- pre-active bay the player dropped or changed (e.g. LoadBay1's Solstice starter) so it never comes
	-- back on rejoin, and (re)activate exactly the bays they actually hold.
	do
		local saved={}
		for _,ct in ipairs(data.contracts or {}) do saved[ct.bay]=ct.company end
		for _,pad in ipairs(plot.LoadBays:GetChildren()) do
			if pad:IsA("BasePart") and pad:GetAttribute("Kind")=="Load" then
				local want=saved[pad.Name]
				local have=pad:GetAttribute("Company")
				if have and have~=want then
					TruckService.clearBay(plr, pad.Name)   -- drop starter / stale / changed contract
				end
				if want and not pad:GetAttribute("Company") then
					local comp=CompanyConfig.get(want)
					if comp then TruckService.activateBay(pad, comp) end
				end
			end
		end
	end
	-- per-bay trucks (after bays exist)
	applyTrucks(plr, data, plot)
	pcall(function() CustomisationService.loadSaved(plr, data.custom) end)
	pcall(function() WarehouseNameService.loadSaved(plr, data.name) end)
	pcall(function() AccessService.loadSaved(plr, data.access) end)
	pcall(function() WorkerService.loadAutoDismiss(plr, data.autoDismiss) end)
	pcall(function() SpecialTruckService.loadCarry(plr, data.carry) end)
	pcall(function() BlackMarketService.loadSaved(plr, data.bm) end)
	pcall(function() InventoryService.loadSaved(plr, data.inv) end)
	pcall(function() SecurityService.loadSaved(plr, data.sec) end)
	pcall(function() TrophyService.loadSaved(plr, data.trophy) end)
	pcall(function() FurnitureService.loadSaved(plr, data.furniture) end)
	pcall(function() DailyRewardService.loadSaved(plr, data.daily) end)
	pcall(function() FurnitureService.placeFor(plr) end)
	-- restore confirmed game-pass ownership + apply perks (ExtraEquipSlots etc.) BEFORE the shift spawns,
	-- so previously-equipped extra-slot workers come back instead of being clamped off by the base cap.
	pcall(function() StoreService.loadSaved(plr, data.passes) end)
	pcall(function() StoreService.applyPasses(plr) end)
	WorkerService.spawnShiftForPlot(plot, TimeService.getShift())
	pcall(function() WorkerService.refreshExceptional(plr) end)   -- mirror Exceptional count for the store UI
	pcall(function() require(script.Parent.BillingService).recompute(plr) end)
end

function SaveService.save(plr)
	if not loadedOK[plr.UserId] then return end   -- never overwrite econ data we couldn't load
	for attempt=1,4 do
		local ok=pcall(function() store:SetAsync(key(plr), serialize(plr)) end)
		if ok then return end
		task.wait(attempt)
	end
	warn("[SaveService] SAVE FAILED for "..plr.Name.." after retries")
end

function SaveService.Start()
	local function onAdd(plr)
		local data, gotData
		for attempt=1,5 do
			local success=pcall(function() data=store:GetAsync(key(plr)) end)
			if success then gotData=true; break end
			warn("[SaveService] load attempt "..attempt.." failed for "..plr.Name)
			task.wait(2*attempt)
		end
		-- Save-authoritative only if the read succeeded AND we hold the session lock (mirrors CurrencyService).
		local lockHeld=SessionLockService.wait(plr)
		loadedOK[plr.UserId]=(gotData and lockHeld) or false
		if not gotData then warn("[SaveService] LOAD FAILED for "..plr.Name.." after retries -- saving DISABLED for them this session to protect their data")
		elseif not lockHeld then warn("[SaveService] no session lock for "..plr.Name.." -- READ-ONLY this session (saving disabled)") end
		task.spawn(function()
			local tries=0
			local plot=PlotService.forPlayer(plr)
			while (not plot.loadBays or #plot.loadBays==0) and tries<100 do task.wait(0.1); tries+=1; plot=PlotService.forPlayer(plr) end
			restore(plr, data)
		end)
	end
	Players.PlayerAdded:Connect(onAdd)
	for _,plr in ipairs(Players:GetPlayers()) do onAdd(plr) end
	-- NOTE: the leave-save is done in PlotService.releasePlayer (before the plot is torn down) so it
	-- serializes the correct plot. Here we only clear the per-player save gate.
	Players.PlayerRemoving:Connect(function(plr) loadedOK[plr.UserId]=nil; CustomisationService.clear(plr); WarehouseNameService.clear(plr); AccessService.clear(plr); WorkerService.clearAutoDismiss(plr); SpecialTruckService.clearPlayer(plr); BlackMarketService.clear(plr); SecurityService.clear(plr); TrophyService.clear(plr); FurnitureService.clear(plr); DailyRewardService.clear(plr) end)
	game:BindToClose(function()
		local pending=0
		for _,plr in ipairs(Players:GetPlayers()) do pending+=1; task.spawn(function() SaveService.save(plr); pending-=1 end) end
		local t=0; while pending>0 and t<25 do task.wait(0.2); t+=0.2 end
	end)
	task.spawn(function() while true do task.wait(30) for _,plr in ipairs(Players:GetPlayers()) do SaveService.save(plr) end end end)
	print("[SaveService] started")
end
return SaveService

