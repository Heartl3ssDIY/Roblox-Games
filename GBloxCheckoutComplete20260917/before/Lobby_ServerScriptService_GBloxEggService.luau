local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")

local Data = require(script.Parent:WaitForChild("PlayerData"))
local Catalog = require(ReplicatedStorage:WaitForChild("GBloxPetCatalog"))

local remote = ReplicatedStorage:FindFirstChild("GBloxEggRequest") or Instance.new("RemoteEvent")
remote.Name = "GBloxEggRequest"
remote.Parent = ReplicatedStorage

local rng = Random.new()
local lastRequest = {}
local autoOpening = {}
local lastTheme = {}

local function reply(player, payload)
 payload.Theme=payload.Theme or lastTheme[player]
 remote:FireClient(player, payload)
end

local function nearbyEgg(player, requestedTheme)
 local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 if not root then return nil end
 for _,stand in CollectionService:GetTagged("GBloxEggStand") do
  local theme = stand:GetAttribute("EggTheme")
  if theme == requestedTheme then
   local delta = root.Position - stand.Position
   if Vector2.new(delta.X,delta.Z).Magnitude <= 14 and math.abs(delta.Y) <= 11 then
    return stand
   end
  end
 end
 return nil
end

local function rollPet(egg)
 local roll = rng:NextNumber(0,100)
 local total = 0
 for _,pet in egg.Pets do
  total += pet.Chance
  if roll <= total then return pet end
 end
 return egg.Pets[#egg.Pets]
end

local function hatchTrophyEggs(player, theme, count)
 local egg = Catalog.Eggs[theme]
 if not egg or egg.Currency ~= "Trophies" or not nearbyEgg(player,theme) then
  return false,"Move closer to the egg."
 end
 local profile = Data.Get(player)
 if not profile then return false,"Your data is still loading." end
 local cost = count == 3 and egg.TripleCost or egg.SingleCost
 if (profile.Trophies or 0) < cost then return false,"You need "..cost.." trophies." end

 local results, ids = {}, {}
 local best
 for _=1,count do
  local pet = rollPet(egg)
  table.insert(ids,pet.Id)
  table.insert(results,{
   Id=pet.Id,
   Chance=pet.Chance,
   CashMultiplier=pet.CashMultiplier,
   TrophyMultiplier=pet.TrophyMultiplier,
  })
  if not best or pet.CashMultiplier > best.CashMultiplier then best=pet end
 end
 if not Data.TrySpendTrophies(player,cost) then return false,"Purchase could not be completed. Try again." end
 if not Data.AddPets(player,ids,best.Id) then
  warn("[GBloxEggs] Pets could not be recorded after trophy charge for",player.UserId)
  return false,"Your hatch could not be recorded. Please rejoin."
 end
 return true,results
end

local function ownsPass(player,passId)
 if passId <= 0 then return false,"missing" end
 local ok,result = pcall(MarketplaceService.UserOwnsGamePassAsync,MarketplaceService,player.UserId,passId)
 if not ok then return false,"check_failed" end
 return result == true
end

local function stopAuto(player,message)
 if autoOpening[player] then
  autoOpening[player]=nil
  reply(player,{Ok=true,AutoActive=false,Message=message or "Auto open stopped."})
 end
end

local function startAuto(player,theme)
 if Catalog.Eggs[theme].Currency ~= "Trophies" then
  reply(player,{Ok=false,Message="Auto open is only configured for trophy eggs."})
  return
 end
 local owned,reason=ownsPass(player,Catalog.Gamepasses.AutoOpen)
 if not owned then
  if reason=="missing" then
   reply(player,{Ok=false,Message="Auto-open gamepass ID still needs to be added."})
  elseif reason=="check_failed" then
   reply(player,{Ok=false,Message="Could not verify the auto-open gamepass. Try again."})
  else
   reply(player,{Ok=false,Message="Auto open requires its gamepass.",PromptPass=Catalog.Gamepasses.AutoOpen})
  end
  return
 end
 autoOpening[player]=theme
 reply(player,{Ok=true,AutoActive=true,Message="Auto open started."})
 task.spawn(function()
  while autoOpening[player]==theme and player.Parent do
   local ok,result=hatchTrophyEggs(player,theme,1)
   if not ok then stopAuto(player,result) break end
   reply(player,{Ok=true,AutoActive=true,Results=result})
   task.wait(2)
  end
 end)
end

local function handleRequest(player,action,theme)
 if typeof(action)~="string" or typeof(theme)~="string" or not Catalog.Eggs[theme] then return end
 lastTheme[player]=theme
 if not nearbyEgg(player,theme) then
  stopAuto(player)
  reply(player,{Ok=false,Message="Move closer to the egg."})
  return
 end

 if action=="Auto" then
  if autoOpening[player] then stopAuto(player) else startAuto(player,theme) end
  return
 end

 local now=os.clock()
 if now-(lastRequest[player] or 0)<.35 then return end
 lastRequest[player]=now
 stopAuto(player)

 local egg=Catalog.Eggs[theme]
 if egg.Currency=="Robux" then
  if action~="One" then
   reply(player,{Ok=false,Message="Orbit triple and auto products still need IDs."})
  elseif Catalog.Products.OrbitSingle<=0 then
   reply(player,{Ok=false,Message="Orbit's 249 Robux developer product ID still needs to be added."})
  else
   MarketplaceService:PromptProductPurchase(player,Catalog.Products.OrbitSingle)
  end
  return
 end

 local count=action=="Three" and 3 or 1
 if count==3 then
  local owned,reason=ownsPass(player,Catalog.Gamepasses.TripleOpen)
  if not owned then
   if reason=="missing" then
    reply(player,{Ok=false,Message="3-egg gamepass ID still needs to be added."})
   elseif reason=="check_failed" then
    reply(player,{Ok=false,Message="Could not verify the 3-egg gamepass. Try again."})
   else
    reply(player,{Ok=false,Message="Opening 3 eggs requires its gamepass.",PromptPass=Catalog.Gamepasses.TripleOpen})
   end
   return
  end
 end

 local ok,result=hatchTrophyEggs(player,theme,count)
 if ok then reply(player,{Ok=true,Results=result})
 else reply(player,{Ok=false,Message=result}) end
end

remote.OnServerEvent:Connect(handleRequest)
for _,stand in CollectionService:GetTagged("GBloxEggStand") do
 for _,object in stand:GetDescendants() do
  if object:IsA("ProximityPrompt") and object:GetAttribute("EggAction") then
   object.Triggered:Connect(function(player)
    handleRequest(player,object:GetAttribute("EggAction"),object:GetAttribute("EggTheme"))
   end)
  end
 end
end

Players.PlayerRemoving:Connect(function(player)
 autoOpening[player]=nil
 lastRequest[player]=nil
 lastTheme[player]=nil
end)

local orbitProduct=Catalog.Products.OrbitSingle
if orbitProduct>0 then
 local previous=MarketplaceService.ProcessReceipt
 MarketplaceService.ProcessReceipt=function(receipt)
  if receipt.ProductId~=orbitProduct then
   if previous then return previous(receipt) end
   return Enum.ProductPurchaseDecision.NotProcessedYet
  end
  local player=Players:GetPlayerByUserId(receipt.PlayerId)
  if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
  lastTheme[player]="Orbit"
  local pet=rollPet(Catalog.Eggs.Orbit)
  local saved=Data.GrantProductPet(player,tostring(receipt.PurchaseId),pet.Id)
  if not saved then return Enum.ProductPurchaseDecision.NotProcessedYet end
  reply(player,{Ok=true,Results={{
   Id=pet.Id,
   Chance=pet.Chance,
   CashMultiplier=pet.CashMultiplier,
   TrophyMultiplier=pet.TrophyMultiplier,
  }}})
  return Enum.ProductPurchaseDecision.PurchaseGranted
 end
end

