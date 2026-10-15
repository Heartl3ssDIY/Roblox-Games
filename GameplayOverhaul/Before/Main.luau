-- Main: boots services and wires validated economy remotes.
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

-- Session locking MUST start first so it connects PlayerAdded before any save service,
-- guaranteeing the lock is being acquired before Currency/Save decide save-authority.
local SessionLockService = require(SSS.Services.SessionLockService)
SessionLockService.Start()

local CurrencyService = require(SSS.Services.CurrencyService)
CurrencyService.Start()

local Configs  = RS:WaitForChild("Configs")
local Remotes  = RS:WaitForChild("Remotes")
local EmployeeConfig = require(Configs.EmployeeConfig)
local ContractConfig = require(Configs.ContractConfig)
local TruckConfig    = require(Configs.TruckConfig)

local function notify(plr, text, kind)
	Remotes.Notify:FireClient(plr, {text = text, kind = kind or "info"})
end

-- Hire an employee of a given rarity (spends Cash). NPC spawning comes in Phase 2.
Remotes.HireEmployee.OnServerInvoke = function(plr, rarity)
	local def = EmployeeConfig.Rarities[tostring(rarity)]
	if not def then return {ok=false, msg="Unknown rarity"} end
	if not CurrencyService.Spend(plr, "Cash", def.hireCost) then
		notify(plr, "Not enough Cash to hire "..rarity, "error")
		return {ok=false, msg="Not enough Cash"}
	end
	notify(plr, "Hired a "..rarity.." employee", "success")
	return {ok=true, msg="Hired "..rarity, rarity=rarity, stats=def}
end

-- Buy a contract tier (spends Crypto). Bay assignment comes in Phase 3.
Remotes.BuyContract.OnServerInvoke = function(plr, tier)
	local def = ContractConfig.Tiers[tostring(tier)]
	if not def then return {ok=false, msg="Unknown contract tier"} end
	if not CurrencyService.Spend(plr, "Crypto", def.cryptoCost) then
		notify(plr, "Not enough Crypto for "..tier.." contract", "error")
		return {ok=false, msg="Not enough Crypto"}
	end
	notify(plr, "Signed a "..tier.." contract", "success")
	return {ok=true, msg="Bought "..tier.." contract", tier=tier}
end

-- Buy/upgrade a truck tier (spends Cash).
Remotes.UpgradeTruck.OnServerInvoke = function(plr, tier)
	local def = TruckConfig.Tiers[tostring(tier)]
	if not def then return {ok=false, msg="Unknown truck tier"} end
	if not CurrencyService.Spend(plr, "Cash", def.cost) then
		notify(plr, "Not enough Cash for "..(def.display or tier), "error")
		return {ok=false, msg="Not enough Cash"}
	end
	notify(plr, "Purchased "..(def.display or tier), "success")
	return {ok=true, msg="Bought "..tier.." truck", tier=tier}
end

-- Plots first: PlotService adopts the existing warehouse as Plot 1, and the warehouse
-- services operate on that plot record. It MUST start before TruckService.
local PlotService = require(SSS.Services.PlotService)
PlotService.Start()

-- Phase 1: start the warehouse loop + temporary auto-labor (stand-in for employees)
local TruckService = require(SSS.Services.TruckService)
TruckService.Start()
local TimeService = require(SSS.Services.TimeService)
TimeService.Start()
-- Weather: rolls a daily event whose multiplier TruckService applies to truck-fill payouts.
local WeatherService = require(SSS.Services.WeatherService)
WeatherService.Start()
local WorkerService = require(SSS.Services.WorkerService)
WorkerService.Start()
local BillingService = require(SSS.Services.BillingService)
BillingService.Start()
local InvestorService = require(SSS.Services.InvestorService)
InvestorService.Start()
local InventoryService = require(SSS.Services.InventoryService)
InventoryService.Start()
-- Daily login rewards (14-day streak, resets on a missed day).
local DailyRewardService = require(SSS.Services.DailyRewardService)
DailyRewardService.Start()
-- Warehouse security + armoury (CCTV, guards, guns). Backend + purchase remote.
local SecurityService = require(SSS.Services.SecurityService)
SecurityService.Start()
-- Real-damage layer: night HP-500, WASTED death + timeout.
local SecurityCombatService = require(SSS.Services.SecurityCombatService)
SecurityCombatService.Start()
local CCTVService = require(SSS.Services.CCTVService)
CCTVService.Start()
local GuardService = require(SSS.Services.GuardService)
GuardService.Start()
local SecurityArmouryService = require(SSS.Services.SecurityArmouryService)
SecurityArmouryService.Start()
local TrophyService = require(SSS.Services.TrophyService)
TrophyService.Start()
-- Office furniture: upgradeable desk laptop + office chairs (Customise tab), placed per office.
local FurnitureService = require(SSS.Services.FurnitureService)
FurnitureService.Start()
local SecurityGunService = require(SSS.Services.SecurityGunService)
SecurityGunService.Start()
local SaveService = require(SSS.Services.SaveService)
SaveService.Start()
local ManualLoadService = require(SSS.Services.ManualLoadService)
ManualLoadService.Start()
local TeleporterService = require(SSS.Services.TeleporterService)
TeleporterService.Start()
local StoreService = require(SSS.Services.StoreService)
StoreService.Start()
-- Mirror Cash/Crypto/Level onto the native Roblox leaderboard (visible to other players).
local LeaderboardService = require(SSS.Services.LeaderboardService)
LeaderboardService.Start()
-- Cross-server Top-10 by Cash on the town-centre board.
local GlobalLeaderboardService = require(SSS.Services.GlobalLeaderboardService)
GlobalLeaderboardService.Start()
-- Special gift-truck event (global daily roll; gifts drop at the town centre).
local SpecialTruckService = require(SSS.Services.SpecialTruckService)
SpecialTruckService.Start()
-- Black-market weapon/combat layer.
local CombatService = require(SSS.Services.CombatService)
CombatService.Start()

print("[Main] economy remotes ready")


-- Agency hiring (overrides earlier stub)
Remotes.HireEmployee.OnServerInvoke = function(plr, agencyId)
	return WorkerService.hire(plr, tonumber(agencyId) or 1)
end


-- Truck shop + contract rolls (override stubs)
Remotes.UpgradeTruck.OnServerInvoke = function(plr, bayName, truckId) return TruckService.buyTruck(plr, tostring(bayName), tostring(truckId)) end
Remotes.BuyContract.OnServerInvoke = function(plr, req)
	if type(req)~="table" then return {ok=false,msg="Bad request"} end
	if req.action=="roll" then return TruckService.rollContract(plr, tonumber(req.rollId) or 1)
	elseif req.action=="confirm" then return TruckService.confirmContract(plr, tostring(req.company), tostring(req.bay))
	elseif req.action=="swap" then return TruckService.swapBays(plr, tostring(req.bayA), tostring(req.bayB))
	elseif req.action=="clear" then return TruckService.clearBay(plr, tostring(req.bay))
	elseif req.action=="pending" then return {ok=true, pending=TruckService.getPending(plr)}
	end
	return {ok=false, msg="Unknown contract action"}
end


-- Warehouse customisation (wall/roof/office-wall colours)
local CustomisationService = require(SSS.Services.CustomisationService)
local WarehouseNameService = require(SSS.Services.WarehouseNameService)
Remotes.Customise.OnServerInvoke = function(plr, req)
	if type(req)~="table" then return {ok=false,msg="bad request"} end
	if req.action=="setColor" then return CustomisationService.setColor(plr, tostring(req.group), req.r, req.g, req.b) end
	if req.action=="setName" then return WarehouseNameService.setName(plr, req.name) end
	if req.action=="setAccess" then return require(SSS.Services.AccessService).setMode(plr, tostring(req.mode)) end
	if req.action=="getAccess" then return {ok=true, mode=require(SSS.Services.AccessService).getMode(plr)} end
	if req.action=="buyCarry" then return require(SSS.Services.SpecialTruckService).buyCarryUpgrade(plr) end
	if req.action=="getCarry" then return {ok=true, carry=require(SSS.Services.SpecialTruckService).getCarryCap(plr)} end
	return {ok=false,msg="unknown action"}
end

-- Black market
local BlackMarketService = require(SSS.Services.BlackMarketService)
Remotes.BlackMarket.OnServerInvoke = function(plr, req)
	if type(req)~="table" then return {ok=false,msg="bad request"} end
	if req.action=="buy" then local r=BlackMarketService.buy(plr, tostring(req.key)); if r and r.ok then pcall(function() require(SSS.Services.CombatService).refreshTools(plr) end) end; return r end
	if req.action=="sabotage" then return BlackMarketService.useSabotage(plr, tostring(req.key), req.target, req.sub) end
	if req.action=="owned" then return {ok=true, owned=BlackMarketService.owned(plr)} end
	if req.action=="targets" then
		local list={}
		for _,p in ipairs(game:GetService("Players"):GetPlayers()) do if p~=plr then list[#list+1]={id=p.UserId, name=p.DisplayName} end end
		return {ok=true, targets=list}
	end
	return {ok=false,msg="unknown action"}
end

-- First-time tutorial flag
Remotes.Tutorial.OnServerInvoke = function(plr, action)
	if action=="check" then return {done=CurrencyService.isTutorialDone(plr)} end
	if action=="complete" then CurrencyService.markTutorialDone(plr); return {ok=true} end
	return {ok=false}
end

-- Worker roster UI
Remotes.GetRoster.OnServerInvoke = function(plr) return WorkerService.getRosterData(plr) end
Remotes.ToggleEquip.OnServerInvoke = function(plr, shift, empName, equipped) return WorkerService.toggleEquip(plr, tostring(shift), tostring(empName), equipped and true or false) end
Remotes.FireWorker.OnServerInvoke = function(plr, shift, empName) return WorkerService.fire(plr, tostring(shift), tostring(empName)) end
Remotes.WorkerSettings.OnServerInvoke = function(plr, req)
	if type(req)~="table" then return {ok=false,msg="bad request"} end
	if req.action=="setAutoDismiss" then return WorkerService.setAutoDismiss(plr, tostring(req.tier), req.enabled and true or false) end
	if req.action=="getAutoDismiss" then return {ok=true, set=WorkerService.getAutoDismiss(plr)} end
	return {ok=false,msg="unknown action"}
end

