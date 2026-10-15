local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")

local Data = require(script.Parent:WaitForChild("PlayerData"))
local Policy=require(script.Parent:WaitForChild("GBloxPurchasePolicy"))
local busy={}
local orbitConfirmed={}
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
  if stand:IsA("BasePart") and stand:IsDescendantOf(workspace) and theme == requestedTheme then
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
 local allowed,message=Policy.CanRandom(player)
 if not allowed then return false,message end
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
 local checked,owned=Data.CheckPass(player,passId)
 return owned,not checked and "check_failed" or nil
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
   task.wait(8)
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

 if action~="One" and action~="Three" and action~="Auto" and action~="BuyOrbit" then return end
 if action=="Auto" and autoOpening[player] then stopAuto(player) return end
 local eligible,reason=Policy.CanRandom(player)
 if not eligible then reply(player,{Ok=false,Message=reason}) return end
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
  if action=="One" then
   orbitConfirmed[player]=os.clock()+60
   reply(player,{Ok=true,ConfirmOrbit=true,Message="Orbit odds: Orca 85%, Swordfish 10%, Shark 4.5%, Alien 0.5%."})
  elseif action=="BuyOrbit" and (orbitConfirmed[player] or 0)>os.clock() then
   orbitConfirmed[player]=nil
   local allowed,message=Data.CanPromptPurchase(player,"Product",Catalog.Products.OrbitSingle)
   if allowed then MarketplaceService:PromptProductPurchase(player,Catalog.Products.OrbitSingle)
   else reply(player,{Ok=false,Message=message}) end
  else reply(player,{Ok=false,Message="Select one Orbit egg to see the odds."}) end
  return
 end
 if action=="BuyOrbit" then return end

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

local function guardedRequest(player,action,theme)
 if busy[player] then return end
 busy[player]=true
 local ok,err=pcall(handleRequest,player,action,theme)
 busy[player]=nil
 if not ok then warn("[GBloxEggs]",err) reply(player,{Ok=false,Message="Egg unavailable. Please try again."}) end
end
remote.OnServerEvent:Connect(guardedRequest)
for _,stand in CollectionService:GetTagged("GBloxEggStand") do
 for _,object in stand:GetDescendants() do
  if object:IsA("ProximityPrompt") and object:GetAttribute("EggAction") then
   object.Triggered:Connect(function(player)
    guardedRequest(player,object:GetAttribute("EggAction"),object:GetAttribute("EggTheme"))
   end)
  end
 end
end

Players.PlayerRemoving:Connect(function(player)
 autoOpening[player]=nil
 busy[player]=nil orbitConfirmed[player]=nil
 lastRequest[player]=nil
 lastTheme[player]=nil
end)


