local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local fixture = Instance.new("Folder")
fixture.Name, fixture.Parent = "CommerceEconomyVerification", ServerStorage
local module = game.ServerScriptService.PlaygroundEconomyService:Clone()
module.Parent = fixture
local economy
local checks = 0
local function check(value, message) assert(value, message); checks += 1 end
local function copy(value) return value and HttpService:JSONDecode(HttpService:JSONEncode(value)) end
local result
local ok, err = xpcall(function()
 local Economy = require(module)
 local data, mode, pendingDelay = nil, nil, 0
 local store = {}
 function store:UpdateAsync(_, transform)
  if mode == "delay" then
   pendingDelay += 1
   task.wait(.15)
   pendingDelay -= 1
  end
  if mode == "fail" then error("Expected fixture storage failure") end
  local nextValue = transform(copy(data))
  if nextValue then data = copy(nextValue) end
  if mode == "commitThenFail" then error("Expected ambiguous commit result") end
  return copy(nextValue)
 end
 economy = Economy.new(workspace["Playground Lobby"], store, false)
 local attrs = {}
 local player = { Parent=Players, UserId=987654321, Name="CommerceFixture" }
 function player:GetAttribute(name) return attrs[name] end
 function player:SetAttribute(name,value) attrs[name]=value end
 function player:FindFirstChild() return nil end
 local function profileNew()
  local p = {player=player,ready=false,version=0,connections={},pickups={}}
  economy.profiles[player] = p
  check(economy:_claim(p), "Could not acquire mock profile lease")
  return p
 end
 local function receipt(id,product) return {PurchaseId=id,ProductId=product or 111,PlayerId=player.UserId} end
 check(economy:SetPassBenefits(player,true,true,true), "Passes rejected before profile load")
 local profile = profileNew()
 check(next(profile.data.CoinPurchases)==nil, "Old profile receipts did not initialize")
 check(attrs.PCCoinMultiplier==3 and attrs.PCXPMultiplier==2, "VIP benefits did not cap stacking")
 check(economy:_earnedCoins(profile,5)==15 and economy:_earnedXP(profile,50)==100, "VIP multipliers wrong")
 check(economy:GrantCoinPurchase(player,receipt("initial"),5000), "Paid grant not acknowledged after save")
 check(profile.data.Coins==5000 and data.Coins==5000, "Purchased coins were multiplied or not saved")
 check(data.CoinPurchases.initial.Coins==5000, "Receipt marker not stored with balance")
 check(economy:GrantCoinPurchase(player,receipt("initial"),5000) and profile.data.Coins==5000, "Duplicate receipt credited again")
 check(not economy:GrantCoinPurchase(player,receipt("initial",112),5000), "Conflicting product acknowledged")
 check(not economy:GrantCoinPurchase(player,receipt("initial"),10000), "Conflicting amount acknowledged")
 check(not economy:GrantCoinPurchase(player,{PurchaseId="bad",ProductId=111,PlayerId=2},5000), "Wrong player receipt allowed")
 check(not economy:GrantCoinPurchase(player,receipt("nan"),0/0), "Invalid coin amount allowed")
 check(economy:AdminGrantCoins(player,10) and profile.data.Coins==5010, "Admin coins were multiplied")
 local beforeXP=profile.data.XP
 check(economy:AdminAddLevels(player,1) and profile.data.XP-beforeXP==200, "Admin XP affected by multipliers")
 local roundXP, roundCoins = profile.data.XP, profile.data.Coins
 check(economy:AwardRound("BB:commerce-vip",{player.UserId},false,{player.UserId},{gameId="BritishBulldog",winnerXP=50})==1, "Round reward failed")
 check(profile.data.Coins-roundCoins==450 and profile.data.XP-roundXP==100, "VIP round multipliers incorrect")
 local prior=profile.data.Coins
 check(economy:ClaimSecretObbyReward(player) and profile.data.Coins-prior==3000, "VIP daily earned reward incorrect")
 task.wait(.1)
 check(data.PCVIP==nil and data.doubleCoins==nil and data.vip==nil, "Pass benefits persisted into profile")
 economy:SetPassBenefits(player,false,true,false)
 check(attrs.PCCoinMultiplier==2 and attrs.PCXPMultiplier==1 and attrs.PCVIP==false, "Coin-only pass benefits incorrect")
 economy:SetPassBenefits(player,false,false,true)
 check(attrs.PCCoinMultiplier==1 and attrs.PCXPMultiplier==2, "XP-only benefits incorrect")
 economy:SetPassBenefits(player,false,false,false)
 attrs.PCCoinMultiplier,attrs.PCXPMultiplier,attrs.PCVIP=999,999,true
 check(economy:_earnedCoins(profile,5)==5 and economy:_earnedXP(profile,50)==50, "Public attributes trusted for rewards")
 economy:_sync(profile)
 check(attrs.PCCoinMultiplier==1 and attrs.PCXPMultiplier==1 and not attrs.PCVIP, "Public attributes not corrected")

 prior=profile.data.Coins
 mode="fail"
 check(not economy:GrantCoinPurchase(player,receipt("retry"),5000), "Failed persistence incorrectly acknowledged")
 check(profile.data.Coins==prior+5000 and data.CoinPurchases.retry==nil, "Pending grant bookkeeping incorrect")
 mode=nil
 check(economy:GrantCoinPurchase(player,receipt("retry"),5000), "Retry did not persist")
 check(profile.data.Coins==prior+5000 and data.Coins==profile.data.Coins, "Retry duplicated credit")

 prior=profile.data.Coins
 mode="commitThenFail"
 check(not economy:GrantCoinPurchase(player,receipt("ambiguous"),5000), "Ambiguous commit incorrectly acknowledged")
 check(data.Coins==prior+5000 and data.CoinPurchases.ambiguous~=nil, "Ambiguous commit failed to store pair")
 mode=nil
 check(economy:GrantCoinPurchase(player,receipt("ambiguous"),5000) and profile.data.Coins==prior+5000, "Ambiguous retry duplicated or lost credit")

 prior=profile.data.Coins
 mode="delay"
 local answers={}
 task.spawn(function() answers.a=economy:GrantCoinPurchase(player,receipt("parallelA"),5000) end)
 while pendingDelay==0 do task.wait() end
 task.spawn(function() answers.same=economy:GrantCoinPurchase(player,receipt("parallelA"),5000) end)
 task.spawn(function() answers.b=economy:GrantCoinPurchase(player,receipt("parallelB"),10000) end)
 local deadline=os.clock()+5
 while (answers.a==nil or answers.same==nil or answers.b==nil) and os.clock()<deadline do task.wait(.05) end
 check(answers.a and answers.same and answers.b, "Concurrent receipts did not finish")
 check(profile.data.Coins==prior+15000 and data.Coins==profile.data.Coins, "Concurrent receipts lost or duplicated coins")
 check(data.CoinPurchases.parallelA and data.CoinPurchases.parallelB, "Concurrent markers not both durable")

 prior=profile.data.Coins
 local saveFinished=false
 task.spawn(function() economy:_save(profile,false);saveFinished=true end)
 while pendingDelay==0 do task.wait() end
 check(economy:GrantCoinPurchase(player,receipt("afterSnapshot"),5000), "Grant behind old autosave failed")
 check(saveFinished and data.Coins==prior+5000 and data.CoinPurchases.afterSnapshot, "Old autosave acknowledged absent receipt")
 mode=nil
 check(economy:_save(profile,true), "Release failed")
 profile=profileNew()
 check(economy:GrantCoinPurchase(player,receipt("initial"),5000), "Loaded receipt not recognized")
 check(profile.data.Coins==data.Coins and profile.data.Coins==prior+5000, "Rejoin duplicate added coins")
 profile.closed=true
 check(not economy:GrantCoinPurchase(player,receipt("closed"),5000), "Closed profile accepted purchase")
 profile.closed=false

 local initialReady = profile.ready
 profile.ready=false
 check(not economy:GrantCoinPurchase(player,receipt("notready"),5000), "Unloaded profile accepted purchase")
 profile.ready=initialReady
 economy.isStudio=true
 check(not economy:GrantCoinPurchase(player,receipt("studio"),5000), "Studio paid receipt incorrectly acknowledged")
 economy.isStudio=false
 economy.sessionOnly=true
 check(not economy:GrantCoinPurchase(player,receipt("session"),5000), "Nondurable session incorrectly acknowledged")
 economy.sessionOnly=false
 local balance=profile.data.Coins
 profile.data.Coins=1000000000
 check(not economy:GrantCoinPurchase(player,receipt("cap"),5000), "Over-cap purchase acknowledged without full amount")
 profile.data.Coins=balance
 check(Economy.CleanData({CoinPurchases={wrong={ProductId=1,Coins=math.huge},valid={ProductId=2,Coins=5000}}}).CoinPurchases.wrong==nil, "Malformed saved receipt retained")
 local cleaned=Economy.CleanData(data)
 check(cleaned.CoinPurchases.initial.Coins==5000 and cleaned.CoinPurchases.parallelB.Coins==10000, "Receipt schema not preserved")
 result={passed=true,checks=checks,realDataStoreUsed=false,playStarted=false}
end,debug.traceback)
if economy then
 for _, p in pairs(economy.profiles) do p.released=true end
 economy:Stop()
end
fixture:Destroy()
if not ok then error(err) end
return HttpService:JSONEncode(result)

