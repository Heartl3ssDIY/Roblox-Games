-- Isolated tests: mock profiles, mock ownership, mock saves. No game records or purchases.
local PlayerData={}
local profiles={}
local saved={}
local failSave=false
local ownership={}
local failOwnership=false
local game={GetService=function(_,name)
 assert(name=="MarketplaceService")
 return {UserOwnsGamePassAsync=function(_,uid,id) if failOwnership then error("offline") end return ownership[id]==true end}
end}
local function sync(_) end
function PlayerData.Save(player)
 if failSave then return false end
 local p=profiles[player]
 saved[player]={Cash=p.Cash,TotalCashEarned=p.TotalCashEarned,ProductReceipts=table.clone(p.ProductReceipts)}
 return true
end

-- Server-owned cash purchase catalog. Amounts never come from the client.
local CashProducts={
 [3713203989]=1000,[3713204079]=5000,[3713204982]=25000,
 [3713205097]=100000,[3713205149]=1000000,
}
local CashPasses={[1981874715]=2,[1981928696]=5}
function PlayerData.GetCashMultiplier(player)
 local p=profiles[player];local multiplier=1
 if p then for id,value in CashPasses do if p.CashPasses[tostring(id)]==true then multiplier=math.max(multiplier,value) end end end
 return multiplier
end
local function syncPasses(player)
 local p=profiles[player];if not p then return end
 for id in CashPasses do player:SetAttribute("GBloxOwnsPass_"..id,p.CashPasses[tostring(id)]==true) end
 player:SetAttribute("GBloxCashMultiplier",PlayerData.GetCashMultiplier(player))
end
function PlayerData.RefreshCashPasses(player)
 local p=profiles[player];if not p then return false end
 local checked=true;local changed=false
 for id in CashPasses do
  if p.CashPasses[tostring(id)]~=true then
   local ok,owned=pcall(function() return game:GetService("MarketplaceService"):UserOwnsGamePassAsync(player.UserId,id) end)
   if not ok then checked=false
   elseif owned then p.CashPasses[tostring(id)]=true;changed=true end
  end
 end
 syncPasses(player)
 player:SetAttribute("GBloxPassesReady",checked)
 if changed and p.CanSave then PlayerData.Save(player) end
 return checked
end
function PlayerData.RecordCashPass(player,id)
 local p=profiles[player];if not p or not CashPasses[id] then return false end
 p.CashPasses[tostring(id)]=true;syncPasses(player)
 return PlayerData.Save(player)
end
function PlayerData.CanPromptPurchase(player,kind,id)
 local p=profiles[player]
 if not p or not p.CanSave or os.time()>=(p.LeaseUntil or 0) then return false,"Your save is reconnecting. Please try shortly." end
 if kind=="Product" and CashProducts[id] then return true end
 if kind=="GamePass" and CashPasses[id] then
  if not PlayerData.RefreshCashPasses(player) then return false,"Could not check ownership. Please try again." end
  if PlayerData.GetCashMultiplier(player)>=CashPasses[id] then return false,"You already have this cash boost or a stronger one." end
  return true
 end
 return false,"This item is coming soon."
end
function PlayerData.GrantCashReceipt(player,receipt)
 local p=profiles[player]
 if not p or not p.CanSave or type(receipt)~="table" or receipt.PlayerId~=player.UserId then return false end
 local amount=CashProducts[receipt.ProductId]
 local purchaseId=receipt.PurchaseId
 if not amount or type(purchaseId)~="string" or #purchaseId==0 or #purchaseId>128 then return false end
 if os.time()>=(p.LeaseUntil or 0) then return false end
 if not p.ProductReceipts[purchaseId] then
  -- Cash and its durable receipt share one profile snapshot / UpdateAsync.
  p.Cash+=amount;p.TotalCashEarned+=amount
  p.ProductReceipts[purchaseId]=os.time()
  sync(player)
 end
 -- Even a retry must confirm persistence; an in-memory marker is not an acknowledgement.
 return PlayerData.Save(player)
end

local player={UserId=123,attrs={}}
function player:SetAttribute(k,v) self.attrs[k]=v end
local function seed()
 profiles[player]={CanSave=true,LeaseUntil=os.time()+180,Cash=0,TotalCashEarned=0,ProductReceipts={},CashPasses={}}
 ownership={};failSave=false;failOwnership=false
end
local passed={}
local function test(name,fn) seed();fn();table.insert(passed,name) end
local function receipt(id,product) return {PlayerId=123,PurchaseId=id,ProductId=product or 3713203989} end
test("All five product amounts",function()
 local expected=0
 for id,amount in {[3713203989]=1000,[3713204079]=5000,[3713204982]=25000,[3713205097]=100000,[3713205149]=1000000} do
  assert(PlayerData.GrantCashReceipt(player,receipt(tostring(id),id)));expected+=amount
 end
 assert(profiles[player].Cash==expected and saved[player].Cash==1131000)
end)
test("Duplicate receipt grants once",function()
 assert(PlayerData.GrantCashReceipt(player,receipt("same")));assert(PlayerData.GrantCashReceipt(player,receipt("same")))
 assert(profiles[player].Cash==1000)
end)
test("Failed save is not acknowledged; retry saves once",function()
 failSave=true;assert(not PlayerData.GrantCashReceipt(player,receipt("retry")))
 assert(profiles[player].Cash==1000)
 failSave=false;assert(PlayerData.GrantCashReceipt(player,receipt("retry")))
 assert(profiles[player].Cash==1000 and saved[player].ProductReceipts.retry)
end)
test("Persisted receipt survives reload",function()
 assert(PlayerData.GrantCashReceipt(player,receipt("reload")))
 local old=saved[player];profiles[player].Cash=old.Cash;profiles[player].ProductReceipts=table.clone(old.ProductReceipts)
 assert(PlayerData.GrantCashReceipt(player,receipt("reload")));assert(profiles[player].Cash==1000)
end)
test("Unknown product / wrong player / invalid receipt rejected",function()
 assert(not PlayerData.GrantCashReceipt(player,receipt("unknown",1)))
 local r=receipt("wrong");r.PlayerId=124;assert(not PlayerData.GrantCashReceipt(player,r))
 assert(not PlayerData.GrantCashReceipt(player,receipt("")));assert(profiles[player].Cash==0)
end)
test("Expired lease and unsavable profile rejected",function()
 profiles[player].LeaseUntil=0;assert(not PlayerData.GrantCashReceipt(player,receipt("expired")))
 profiles[player].LeaseUntil=os.time()+180;profiles[player].CanSave=false
 assert(not PlayerData.GrantCashReceipt(player,receipt("readonly")));assert(profiles[player].Cash==0)
end)
test("5x wins over 2x; purchased packs stay exact",function()
 ownership[1981874715]=true;ownership[1981928696]=true
 assert(PlayerData.RefreshCashPasses(player));assert(PlayerData.GetCashMultiplier(player)==5)
 assert(PlayerData.GrantCashReceipt(player,receipt("pack")));assert(profiles[player].Cash==1000)
 assert(not PlayerData.CanPromptPurchase(player,"GamePass",1981874715))
end)
test("Owned pass survives ownership service outage",function()
 ownership[1981928696]=true;PlayerData.RefreshCashPasses(player)
 failOwnership=true;PlayerData.RefreshCashPasses(player);assert(PlayerData.GetCashMultiplier(player)==5)
end)
test("New ownership check failures block checkout",function()
 failOwnership=true;assert(not PlayerData.CanPromptPurchase(player,"GamePass",1981928696))
end)
test("Only configured items can open checkout",function()
 assert(PlayerData.CanPromptPurchase(player,"Product",3713203989))
 assert(not PlayerData.CanPromptPurchase(player,"Product",1))
 assert(PlayerData.CanPromptPurchase(player,"GamePass",1981874715))
end)
return passed
