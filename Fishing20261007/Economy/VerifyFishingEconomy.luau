local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
assert(not game:GetService("RunService"):IsRunning(), "No Play")
local fixture = Instance.new("Folder")
fixture.Name, fixture.Parent = "FishingEconomyVerification", ServerStorage
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
  if mode == "delay" then pendingDelay += 1 task.wait(.15) pendingDelay -= 1 end
  if mode == "fail" then error("Expected mock storage failure") end
  local value = transform(copy(data))
  if value then data = copy(value) end
  if mode == "commitThenFail" then error("Expected ambiguous save") end
  return copy(value)
 end
 economy = Economy.new(workspace["Playground Lobby"], store, false)
 local attrs = {}
 local player = { Parent=Players, UserId=987654321, Name="FishingFixture" }
 function player:GetAttribute(name) return attrs[name] end
 function player:SetAttribute(name,value) attrs[name]=value end
 function player:FindFirstChild() return nil end
 local function profileNew()
  local p = {player=player,ready=false,version=0,connections={},pickups={}}
  economy.profiles[player] = p
  check(economy:_claim(p), "Could not acquire mock profile lease")
  economy:_sync(p)
  return p
 end
 local profile = profileNew()
 local draws = {1,1,2,2,1,2}
 local draw = 0
 economy.fishingRandom = {NextInteger=function(_,minimum,maximum)
  check(minimum==1 and maximum==2,"Fishing odds must be equally likely two values")
  draw += 1
  return draws[draw] or 1
 end}
 local now,day = os.time(),math.floor(os.time()/86400)
 check(profile.data.FishingDay==0 and profile.data.FishingUsed==0 and profile.data.FishingCoinsExpires==0 and profile.data.FishingXPExpires==0, "Old schema not safely initialized")
 check(attrs.PCFishingCatchesLeft==3 and attrs.PCFishingCoinsExpires==0 and attrs.PCFishingXPExpires==0, "Initial UI attributes wrong")
 check(economy:CanFish(player),"First catch unavailable")
 local caught,message,kind,expiry=economy:ClaimFishingReward(player)
 check(caught and kind=="Coins" and expiry>=now+300 and expiry<=os.time()+300, "First catch not 300-second Coins")
 check(message:find("2 catches left today",1,true),"Remaining catches missing from toast")
 check(profile.data.FishingUsed==1 and profile.data.FishingDay==day, "First catch quota wrong")
 check(data.FishingUsed==1 and data.FishingCoinsExpires==expiry,"First catch and timer not saved together")
 check(economy:_earnedCoins(profile,5)==10 and economy:_earnedXP(profile,50)==50,"Fishing Coins boost incorrect")
 check(attrs.PCCoinMultiplier==2 and attrs.PCXPMultiplier==1, "Boost multiplier HUD wrong")
 local firstExpiry=expiry
 caught,message,kind,expiry=economy:ClaimFishingReward(player)
 check(caught and kind=="Coins" and expiry==firstExpiry+300,"Same reward did not extend by exactly 300 seconds")
 check(economy:CanFish(player),"Active boost blocked another catch")
 caught,message,kind,expiry=economy:ClaimFishingReward(player)
 check(caught and kind=="XP" and expiry>=now+300 and expiry<=os.time()+300,"XP catch did not start independent timer")
 check(profile.data.FishingCoinsExpires==firstExpiry+300,"XP reward changed coin timer")
 check(attrs.PCFishingCatchesLeft==0 and attrs.PCFishingCoinsExpires==firstExpiry+300 and attrs.PCFishingXPExpires==expiry,"Parallel timers or quota incorrect")
 check(not economy:CanFish(player) and not economy:ClaimFishingReward(player) and draw==3,"Fourth catch allowed or rerolled")
 check(economy:_earnedCoins(profile,5)==10 and economy:_earnedXP(profile,50)==100,"Concurrent boosts incorrect")
 check(economy:SetPassBenefits(player,true,true,true),"VIP benefit setup failed")
 check(economy:_earnedCoins(profile,5)==30 and economy:_earnedXP(profile,50)==200,"VIP boosts should yield 6x coins / 4x XP")
 check(attrs.PCCoinMultiplier==6 and attrs.PCXPMultiplier==4,"VIP temporary multipliers not shown")
 economy:SetPassBenefits(player,false,true,true)
 check(economy:_earnedCoins(profile,5)==20 and economy:_earnedXP(profile,50)==200,"Pass boosts should yield 4x")
 attrs.PCCoinMultiplier,attrs.PCXPMultiplier,attrs.PCFishingCoinsExpires=999,999,1e12
 check(economy:_earnedCoins(profile,5)==20 and economy:_earnedXP(profile,50)==200,"Public attributes trusted")
 economy:_sync(profile)
 local prior=profile.data.Coins
 check(economy:GrantCoinPurchase(player,{PurchaseId="fish-purchase",ProductId=123,PlayerId=player.UserId},5000),"Purchase failed")
 check(profile.data.Coins==prior+5000,"Purchased coins multiplied by fishing")
 check(economy:AdminGrantCoins(player,10) and profile.data.Coins==prior+5010,"Admin coins multiplied by fishing")
 local level=economy:LevelProgress(profile.data.XP)
 check(economy:AdminAddLevels(player,1) and economy:LevelProgress(profile.data.XP)==level+1,"Admin levels multiplied")
 check(economy:_save(profile,true),"Mock profile release failed")
 profile=profileNew()
 check(profile.data.FishingUsed==3 and not economy:CanFish(player),"Rejoin reset quota")
 check(profile.data.FishingCoinsExpires==firstExpiry+300 and profile.data.FishingXPExpires==expiry,"Rejoin lost timers")
 check(data.CoinPurchases["fish-purchase"].Coins==5000,"Fishing persistence erased receipt")
 profile.data.FishingDay=day-1
 economy:_sync(profile)
 check(attrs.PCFishingCatchesLeft==3 and economy:CanFish(player),"New UTC day did not reset allowance")
 local prevXP=profile.data.FishingXPExpires
 caught,message,kind,expiry=economy:ClaimFishingReward(player)
 check(caught and kind=="XP" and profile.data.FishingUsed==1 and profile.data.FishingDay==day and expiry==prevXP+300,"New day first catch reset or stack failed")
 profile.data.FishingCoinsExpires=os.time()-1
 economy.lastFishingSecond=0
 economy:_tick(.2)
 check(attrs.PCFishingCoinsExpires==0 and attrs.PCCoinMultiplier==2 and attrs.PCXPMultiplier==4,"Coins expiration did not clear HUD and retain XP")
 check(economy:_earnedCoins(profile,5)==10,"Expired Coins timer still granting bonus")
 profile.data.FishingXPExpires=os.time()-1
 economy.lastFishingSecond=0
 economy:_tick(.2)
 check(attrs.PCFishingXPExpires==0 and attrs.PCXPMultiplier==2 and economy:_earnedXP(profile,50)==100,"XP expiration not cleaned")
 profile.ready=false
 check(not economy:CanFish(player),"Unready profile can fish")
 profile.ready=true
 profile.closed=true
 check(not economy:CanFish(player),"Closed profile can fish")
 profile.closed=false
 profile.released=true
 check(not economy:CanFish(player),"Released profile can fish")
 profile.released=false
 player.Parent=nil
 check(not economy:CanFish(player),"Departed player can fish")
 player.Parent=Players
 for _, key in ipairs({"BBParticipating","TGParticipating","MDParticipating"}) do
  attrs[key]=true
  check(not economy:CanFish(player),key.." allowed fishing during a round")
  attrs[key]=false
 end
 economy.sessionOnly=true
 check(not economy:CanFish(player),"Nondurable production profile can fish")
 economy.sessionOnly=false
 mode="fail"
 local used,rolls=profile.data.FishingUsed,draw
 caught=economy:ClaimFishingReward(player)
 check(not caught and profile.fishingPending and profile.data.FishingUsed==used+1 and draw==rolls+1,"Failed save did not retain exactly one pending catch")
 local pendingKind,pendingExpiry=profile.fishingPending.kind,profile.fishingPending.expires
 mode=nil
 caught,message,kind,expiry=economy:ClaimFishingReward(player)
 check(caught and kind==pendingKind and expiry==pendingExpiry and profile.data.FishingUsed==used+1 and draw==rolls+1,"Retry consumed another catch or rerolled")
 check(not profile.fishingPending and data.FishingUsed==profile.data.FishingUsed,"Retried catch not durably saved")
 mode="commitThenFail"
 used,rolls=profile.data.FishingUsed,draw
 caught=economy:ClaimFishingReward(player)
 check(not caught and data.FishingUsed==used+1,"Ambiguous commit state unexpected")
 pendingKind,pendingExpiry=profile.fishingPending.kind,profile.fishingPending.expires
 mode=nil
 caught,message,kind,expiry=economy:ClaimFishingReward(player)
 check(caught and kind==pendingKind and expiry==pendingExpiry and profile.data.FishingUsed==used+1 and draw==rolls+1,"Ambiguous retry duplicated reward")
 profile.data.FishingDay=day-1
 profile.data.FishingUsed=3
 mode="delay"
 local answer
 task.spawn(function() answer=economy:ClaimFishingReward(player) end)
 while pendingDelay==0 do task.wait() end
 check(not economy:CanFish(player) and not economy:ClaimFishingReward(player),"Concurrent saving allowed new catch")
 local deadline=os.clock()+5
 while answer==nil and os.clock()<deadline do task.wait(.02) end
 check(answer and profile.data.FishingUsed==1,"Concurrent save consumed extra allowance")
 mode=nil
 local originalSave=economy._save
 economy._save=function() error("Expected unexpected save error") end
 used,rolls=profile.data.FishingUsed,draw
 caught=economy:ClaimFishingReward(player)
 check(not caught and not profile.fishingSaving and profile.fishingPending,"Unexpected save error left fishing locked")
 economy._save=originalSave
 check(economy:CanFish(player),"Failed save permanently blocked fishing")
 caught=economy:ClaimFishingReward(player)
 check(caught and profile.data.FishingUsed==used+1 and draw==rolls+1,"Unexpected error retry consumed extra catch")
 local clean=Economy.CleanData({FishingDay=0/0,FishingUsed=999,FishingCoinsExpires=math.huge,FishingXPExpires=-1})
 check(clean.FishingDay==0 and clean.FishingUsed==3 and clean.FishingCoinsExpires==0 and clean.FishingXPExpires==0,"Malformed fishing data unsafe")
 result={passed=true,checks=checks,realDataStoreUsed=false,playStarted=false}
end,debug.traceback)
if economy then
 for _, p in pairs(economy.profiles) do p.released=true end
 economy:Stop()
end
fixture:Destroy()
if not ok then error(err) end
return HttpService:JSONEncode(result)
