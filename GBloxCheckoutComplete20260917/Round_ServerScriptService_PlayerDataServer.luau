local Players=game:GetService("Players")
local Marketplace=game:GetService("MarketplaceService")
local RS=game:GetService("ReplicatedStorage")
local Catalog=require(RS:WaitForChild("GBloxPurchaseCatalog"))
local PetCatalog=require(RS:WaitForChild("GBloxPetCatalog"))
local Data=require(script.Parent:WaitForChild("PlayerData"))
local request=RS:FindFirstChild("GBloxShopRequest") or Instance.new("RemoteFunction")
request.Name="GBloxShopRequest" request.Parent=RS
local feedback=RS:FindFirstChild("GBloxShopFeedback") or Instance.new("RemoteEvent")
feedback.Name="GBloxShopFeedback" feedback.Parent=RS
local last,busy={},{}
request.OnServerInvoke=function(player,kind,id)
 if (kind~="GamePass" and kind~="Product") or type(id)~="number" or id~=math.floor(id) then return false,"Invalid item." end
 if busy[player] or os.clock()-(last[player] or -10)<1 then return false,"Please wait a moment." end
 last[player]=os.clock() busy[player]=true
 -- Orbit must use the egg stand's odds confirmation, not the generic shop remote.
 if id==3713207054 then busy[player]=nil return false,"Use the Orbit egg stand." end
 local ok,allowed,message=pcall(Data.CanPromptPurchase,player,kind,id)
 busy[player]=nil
 if not ok then warn("[GBloxShop]",allowed) return false,"Shop unavailable. Please try again." end
 return allowed,message
end
-- The only receipt callback in each place handles every configured product.
Marketplace.ProcessReceipt=function(receipt)
 local player=Players:GetPlayerByUserId(receipt.PlayerId)
 if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
 local ok,saved,isNew,marker=pcall(Data.GrantPurchaseReceipt,player,receipt)
 if not ok then warn("[GBloxShop] Receipt pending:",saved) end
 if not ok or not saved then return Enum.ProductPurchaseDecision.NotProcessedYet end
 local item=Catalog.Products[receipt.ProductId]
 if player.Parent and item then
  feedback:FireClient(player,item.Name.." received and saved!")
  if type(marker)=="table" and marker.Pet then
   local remote=RS:FindFirstChild("GBloxEggRequest")
   local pet=PetCatalog.GetPet(marker.Pet)
   if remote and pet then remote:FireClient(player,{Ok=true,Theme="Orbit",PurchaseId=receipt.PurchaseId,Results={{Id=pet.Id,Chance=pet.Chance,CashMultiplier=pet.CashMultiplier,TrophyMultiplier=pet.TrophyMultiplier}}}) end
  end
 end
 return Enum.ProductPurchaseDecision.PurchaseGranted
end
Marketplace.PromptGamePassPurchaseFinished:Connect(function(player,id,purchased)
 if not purchased or not Catalog.Passes[id] then return end
 local ok,activated=pcall(Data.RecordCashPass,player,id)
 if player.Parent then feedback:FireClient(player,ok and activated and (Catalog.Passes[id].Name.." active!") or "Ownership will refresh when you rejoin.") end
end)
local function joined(player)
 if Data.Load(player) and player.Parent then Data.RefreshCashPasses(player) end
end
Players.PlayerAdded:Connect(joined)
Players.PlayerRemoving:Connect(function(player) last[player]=nil;busy[player]=nil;Data.Remove(player) end)
for _,player in Players:GetPlayers() do task.spawn(joined,player) end
task.spawn(function()
 while task.wait(45) do for _,player in Players:GetPlayers() do task.spawn(Data.Save,player) end end
end)
game:BindToClose(function()
 local pending=0
 for _,player in Players:GetPlayers() do pending+=1;task.spawn(function() Data.Remove(player);pending-=1 end) end
 local deadline=os.clock()+25
 while pending>0 and os.clock()<deadline do task.wait(.1) end
end)

