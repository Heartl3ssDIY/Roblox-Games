local DSS=game:GetService("DataStoreService")
local Http=game:GetService("HttpService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Catalog=require(ReplicatedStorage:WaitForChild("GBloxPetCatalog"))
local DailyRules=require(ReplicatedStorage:WaitForChild("GBloxDailyRewardRules"))
local CommunityRules=require(ReplicatedStorage:WaitForChild("GBloxCommunityRewardRules"))
local PlayerData={}
local profiles,loading,saving,petSaveQueued={},{},{},{}
local store=DSS:GetDataStore("GBlox_PlayerData_v1")
local session=game.JobId..Http:GenerateGUID(false)
local ordered={Wins=DSS:GetOrderedDataStore("GBlox_Wins_v1"),TotalCash=DSS:GetOrderedDataStore("GBlox_TotalCashEarned_v1"),FastestTime=DSS:GetOrderedDataStore("GBlox_FiveRoundTimeMs_v1")}
local function number(v) return typeof(v)=="number" and v==v and v<math.huge and math.max(0,math.floor(v)) or 0 end
local function sanitize(raw)
 local p=typeof(raw)=="table" and table.clone(raw) or {}
 for _,k in {"Cash","Wins","FastestTimeMs","TotalCashEarned"} do p[k]=number(p[k]) end
 p.LegacyCourseFastestTimeMs=p.LegacyCourseFastestTimeMs or p.FastestTimeMs
 p.FastestTimeMs=number(p.MatchFastestTimeMs)
 p.Trophies=number(p.Trophies==nil and p.Wins or p.Trophies)
 p.Abilities=typeof(p.Abilities)=="table" and p.Abilities or {}
 p.DailyRewards=DailyRules.Sanitize(p.DailyRewards)
 p.CommunityRewards=CommunityRules.Sanitize(p.CommunityRewards)
 p.EquippedAbility=typeof(p.EquippedAbility)=="string" and p.EquippedAbility or ""
 p.MatchReceipts=typeof(p.MatchReceipts)=="table" and p.MatchReceipts or {}
 p.ProductReceipts=typeof(p.ProductReceipts)=="table" and p.ProductReceipts or {}
 local pets={}
 if typeof(p.Pets)=="table" then
  for id,count in p.Pets do
   if typeof(id)=="string" and #id<=64 then
    local clean=number(count)
    if clean>0 then pets[id]=clean end
   end
  end
 end
 p.Pets=pets
 p.EquippedPet=typeof(p.EquippedPet)=="string" and p.EquippedPet or ""
 return p
end
local function sync(player)
 local p=profiles[player] if not p or not player.Parent then return end
 local stats=player:FindFirstChild("leaderstats") or Instance.new("Folder") stats.Name="leaderstats" stats.Parent=player
 for _,k in {"Cash","Trophies","Wins","TotalCashEarned","FastestTimeMs"} do
  player:SetAttribute(k,p[k])
  if k=="Cash" or k=="Trophies" or k=="Wins" then
   local v=stats:FindFirstChild(k) or Instance.new("IntValue") v.Name=k v.Value=p[k] v.Parent=stats
  end
 end
 player:SetAttribute("PlayerDataReady",p.CanSave==true or p.StudioTemporary==true)
 player:SetAttribute("StudioTemporaryData",p.StudioTemporary==true)
 player:SetAttribute("GBloxEquippedAbility",p.EquippedAbility~="" and p.EquippedAbility or nil)
 for id,a in p.Abilities do if typeof(a)=="table" then
  player:SetAttribute("AbilityOwned_"..id,a.Owned==true)
  player:SetAttribute("AbilityUses_"..id,number(a.Uses))
 end end
 local pets=player:FindFirstChild("GBloxPets") or Instance.new("Folder")
 pets.Name="GBloxPets" pets.Parent=player
 for _,value in pets:GetChildren() do
  if value:IsA("IntValue") and not p.Pets[value.Name] then value:Destroy() end
 end
 for id,count in p.Pets do
  local value=pets:FindFirstChild(id) or Instance.new("IntValue")
  value.Name=id value.Value=count value.Parent=pets
 end
 player:SetAttribute("GBloxEquippedPet",p.EquippedPet~="" and p.EquippedPet or nil)
end
local function snapshot(p,release)
 local s=sanitize(p) s.CanSave=nil s.PurchasePending=nil
 s.FastestTimeMs=p.FastestTimeMs s.MatchFastestTimeMs=p.FastestTimeMs
 s.Abilities=Http:JSONDecode(Http:JSONEncode(p.Abilities))
 s.Pets=table.clone(p.Pets)
 s.EquippedPet=p.EquippedPet
 s.MatchReceipts=table.clone(p.MatchReceipts)
 s.ProductReceipts=table.clone(p.ProductReceipts)
 s.Session=session if release then s.Session=nil end
 s.LeaseUntil=release and 0 or os.time()+180
 s.SaveId=Http:GenerateGUID(false)
 return s
end
function PlayerData.Load(player)
 if profiles[player] then return profiles[player] end
 while loading[player] do task.wait(.1) end
 if profiles[player] then return profiles[player] end
 loading[player]=true
 local result
 for attempt=1,10 do
  local ok,raw=pcall(function()
   return store:UpdateAsync("Player_"..player.UserId,function(old)
    if old and old.Session and old.Session~=session and (old.LeaseUntil or 0)>os.time() then return nil end
    local p=sanitize(old) p.Session=session p.LeaseUntil=os.time()+180 return p
   end)
  end)
  if ok and raw and raw.Session==session then result=sanitize(raw) break end
  if not ok then
   warn("[PlayerData] Load failed:",tostring(raw))
   local denied=tostring(raw):find("StudioAccessToApisNotAllowed",1,true) or tostring(raw):find("API access is not enabled",1,true)
   if game:GetService("RunService"):IsStudio() and denied then
    local temporary=sanitize(nil)
    temporary.CanSave=false temporary.StudioTemporary=true
    profiles[player]=temporary loading[player]=nil sync(player)
    warn("[PlayerData] TEMPORARY STUDIO BALANCE: API access is disabled. This test session will NOT save.")
    return temporary
   end
  end
  if not player.Parent then break end
  task.wait(3)
 end
 loading[player]=nil
 if not result then
  player:SetAttribute("PlayerDataReady",false)
  if player.Parent then player:Kick("Your save could not be loaded safely. Please rejoin; your data has not been reset.") end
  return nil
 end
 result.CanSave=true profiles[player]=result sync(player)
 if not player.Parent then PlayerData.Remove(player) end
 return result
end
function PlayerData.Get(player) return profiles[player] end
local function rank(storeObject,id,value,ascending)
 local ok,err=pcall(function()
  storeObject:UpdateAsync(tostring(id),function(old)
   if ascending then return old and math.min(old,value) or value end
   return math.max(old or 0,value)
  end)
 end)
 if not ok then warn("[Rankings]",err) end
end
function PlayerData.Save(player,release)
 while saving[player] do task.wait(.05) end
 local p=profiles[player] if not p or not p.CanSave then return false end
 saving[player]=true
 local s=snapshot(p,release) local success=false
 for attempt=1,3 do
  local ok,result=pcall(function()
   return store:UpdateAsync("Player_"..player.UserId,function(old)
    if old and old.SaveId==s.SaveId then return old end
    if not old or old.Session~=session then return nil end
    return s
   end)
  end)
  if ok and result then success=true break end
  task.wait(attempt)
 end
 saving[player]=nil
 if success then
  p.LeaseUntil=s.LeaseUntil p.PurchasePending=nil
  task.spawn(function()
   rank(ordered.Wins,player.UserId,s.Wins)
   rank(ordered.TotalCash,player.UserId,s.TotalCashEarned)
   if s.FastestTimeMs>0 then rank(ordered.FastestTime,player.UserId,s.FastestTimeMs,true) end
  end)
 else warn("[PlayerData] Save pending for",player.UserId) end
 return success
end
local function queuePetSave(player)
 if petSaveQueued[player] then return end
 petSaveQueued[player]=true
 task.delay(5,function()
  petSaveQueued[player]=nil
  if profiles[player] then PlayerData.Save(player) end
 end)
end
function PlayerData.AddCash(player,amount)
 local p=profiles[player] if not p or (not p.CanSave and not p.StudioTemporary) then return nil end
 if typeof(amount)~="number" or amount~=amount or math.abs(amount)==math.huge then return nil end
 amount=math.floor(amount) p.Cash=math.max(0,p.Cash+amount)
 if amount>0 then p.TotalCashEarned+=amount end sync(player) return p.Cash
end
function PlayerData.AddTrophies(player,amount)
 local p=profiles[player] if not p or (not p.CanSave and not p.StudioTemporary) then return nil end
 if typeof(amount)~="number" or amount~=amount or math.abs(amount)==math.huge then return nil end
 amount=math.floor(amount) p.Trophies=math.max(0,p.Trophies+amount)
 sync(player) return p.Trophies
end
local function petMultipliers(p)
 local pet=p.EquippedPet~="" and Catalog.GetPet(p.EquippedPet)
 return pet and pet.CashMultiplier or 1,pet and pet.TrophyMultiplier or 1
end
function PlayerData.GetPetMultipliers(player)
 local p=profiles[player]
 if not p then return 1,1 end
 return petMultipliers(p)
end
function PlayerData.AddEarnedCash(player,baseAmount)
 local p=profiles[player]
 if not p or typeof(baseAmount)~="number" then return nil end
 local cashMultiplier=petMultipliers(p)
 local awarded=math.max(0,math.floor(baseAmount*cashMultiplier+.5))
 return PlayerData.AddCash(player,awarded),awarded
end
function PlayerData.TrySpendCash(player,amount)
 local p=profiles[player] amount=number(amount)
 if not p or (not p.CanSave and not p.StudioTemporary) or amount<=0 or p.Cash<amount then return false end
 p.Cash-=amount sync(player) return true
end
function PlayerData.TrySpendTrophies(player,amount)
 local p=profiles[player] amount=number(amount)
 if not p or (not p.CanSave and not p.StudioTemporary) or p.PurchasePending or amount<=0 or p.Trophies<amount then return false end
 p.Trophies-=amount sync(player) return true
end
function PlayerData.AddPets(player,petIds,equippedId)
 local p=profiles[player]
 if not p or (not p.CanSave and not p.StudioTemporary) or typeof(petIds)~="table" then return false end
 for _,id in petIds do
  if typeof(id)~="string" or #id>64 then return false end
 end
 for _,id in petIds do p.Pets[id]=(p.Pets[id] or 0)+1 end
 if typeof(equippedId)=="string" and p.Pets[equippedId] then p.EquippedPet=equippedId end
 sync(player)
 queuePetSave(player)
 return true
end
function PlayerData.SetEquippedPet(player,id)
 local p=profiles[player]
 if not p or typeof(id)~="string" then return false end
 if id~="" and not p.Pets[id] then return false end
 p.EquippedPet=id sync(player) queuePetSave(player) return true
end
function PlayerData.GrantProductPet(player,purchaseId,petId)
 local p=profiles[player]
 if not p or not p.CanSave or typeof(purchaseId)~="string" or typeof(petId)~="string" then return false end
 if p.ProductReceipts[purchaseId] then return true end
 p.ProductReceipts[purchaseId]=os.time()
 for id,time in p.ProductReceipts do if time<os.time()-7776000 then p.ProductReceipts[id]=nil end end
 p.Pets[petId]=(p.Pets[petId] or 0)+1
 p.EquippedPet=petId
 sync(player)
 return PlayerData.Save(player)
end
function PlayerData.BuyAbility(player,id,price)
 if id=="Kong" then return false,"Kong is unavailable for now." end
 local p=profiles[player]
 if not p or not p.CanSave or saving[player] or p.PurchasePending or os.time()>=(p.LeaseUntil or 0) then return false,"Save busy; try again shortly." end
 local a=p.Abilities[id] local owned=a and a.Owned==true
 if owned and number(a.Uses)>0 then return false,"You still have uses remaining." end
 local cost=owned and math.floor(price*.1) or price
 if p.Cash<cost then return false,"Not enough cash." end
 p.PurchasePending=true
 p.Cash-=cost
 -- Initial unlock grants three games; cash refill grants one game.
 p.Abilities[id]={Owned=true,Uses=owned and 1 or 3}
 sync(player)
 local ok=PlayerData.Save(player)
 return true,ok and (owned and "Refilled: 1 game." or "Unlocked: 3 games.") or "Purchase recorded locally; save retry pending."
end

function PlayerData.CommunityRewardStatus(player)
 local p=profiles[player]
 if not p or (not p.CanSave and not p.StudioTemporary) then return nil end
 return CommunityRules.Sanitize(p.CommunityRewards)
end
function PlayerData.ClaimLikeThankYou(player)
 local p=profiles[player]
 if not p or (not p.CanSave and not p.StudioTemporary) then return false,"Your save is still loading." end
 if saving[player] or p.PurchasePending or (p.CanSave and os.time()>=(p.LeaseUntil or 0)) then return false,"Save busy; try the heart again shortly." end
 local ok,message=CommunityRules.ApplyLike(p)
 if not ok then return false,message end
 sync(player)
 if p.StudioTemporary then return true,message.." (Studio preview; not saved.)" end
 local saved=PlayerData.Save(player)
 return true,saved and message or message.." Save pending; please stay connected."
end
function PlayerData.ClaimCommunityReward(player,verifiedMember)
 local p=profiles[player]
 if not p or (not p.CanSave and not p.StudioTemporary) then return false,"Your save is still loading." end
 if saving[player] or p.PurchasePending or (p.CanSave and os.time()>=(p.LeaseUntil or 0)) then return false,"Save busy; try the community button again shortly." end
 local ok,message=CommunityRules.ApplyCommunity(p,verifiedMember)
 if not ok then return false,message end
 sync(player)
 if p.StudioTemporary then return true,message.." (Studio preview; not saved.)" end
 local saved=PlayerData.Save(player)
 return true,saved and message or message.." Save pending; please stay connected."
end

function PlayerData.DailyRewardStatus(player,offset)
 local p=profiles[player]
 if not p or (not p.CanSave and not p.StudioTemporary) then return nil,"Your save is still loading." end
 local status,state=DailyRules.Status(p.DailyRewards,os.time(),offset)
 p.DailyRewards=state
 status.Temporary=p.StudioTemporary==true
 return status
end
function PlayerData.ClaimDailyReward(player,offset)
 local p=profiles[player]
 if not p or (not p.CanSave and not p.StudioTemporary) then return false,"Your save is still loading." end
 if saving[player] or p.PurchasePending or (p.CanSave and os.time()>=(p.LeaseUntil or 0)) then return false,"Save busy; try again shortly." end
 local ok,message=DailyRules.Apply(p,os.time(),offset)
 if not ok then return false,message end
 sync(player)
 if p.StudioTemporary then return true,message.." (Studio preview only; not saved.)" end
 local saved=PlayerData.Save(player)
 return true,saved and message or message.." Save pending; do not leave yet."
end
function PlayerData.SetEquippedAbility(player,id)
 local p=profiles[player]
 if not p or (not p.CanSave and not p.StudioTemporary) then return false,"Your save is still loading." end
 if saving[player] or p.PurchasePending then return false,"Save busy; try again shortly." end
 if id=="Kong" then return false,"Kong is unavailable for now." end
 if id~="" and (not DailyRules.Abilities[id] or not p.Abilities[id] or p.Abilities[id].Owned~=true) then return false,"You do not own this ability." end
 p.EquippedAbility=id sync(player)
 if p.StudioTemporary then return true,"Equipped for this Studio preview." end
 local saved=PlayerData.Save(player)
 return true,saved and (id=="" and "Ability unequipped." or "Ability equipped.") or "Equipped; save retry pending."
end

function PlayerData.RecordTime(player,seconds)
 local p=profiles[player] local ms=number(seconds*1000+.5)
 if not p or not p.CanSave or ms<=0 then return end
 if p.FastestTimeMs==0 or ms<p.FastestTimeMs then p.FastestTimeMs=ms sync(player) task.spawn(PlayerData.Save,player) end
end
function PlayerData.AwardMatch(player,matchId,place,cash,trophies)
 local p=profiles[player]
 if not p or not p.CanSave or p.MatchReceipts[matchId] then return false end
 p.MatchReceipts[matchId]=os.time()
 for id,time in p.MatchReceipts do if time<os.time()-604800 then p.MatchReceipts[id]=nil end end
 if place==1 then p.Wins+=1 end
 local cashMultiplier,trophyMultiplier=petMultipliers(p)
 local awardedCash=number(cash*cashMultiplier)
 local awardedTrophies=number(trophies*trophyMultiplier)
 p.Cash+=awardedCash p.TotalCashEarned+=awardedCash p.Trophies+=awardedTrophies
 sync(player) return PlayerData.Save(player),awardedCash,awardedTrophies
end
function PlayerData.AwardWin() error("Use AwardMatch after all five rounds; course finishes are not match wins.") end
function PlayerData.Remove(player)
 if loading[player] then return end
 if profiles[player] and profiles[player].StudioTemporary then profiles[player]=nil return end
 if PlayerData.Save(player,true) then profiles[player]=nil end
end
PlayerData.OrderedStores=ordered
return PlayerData
