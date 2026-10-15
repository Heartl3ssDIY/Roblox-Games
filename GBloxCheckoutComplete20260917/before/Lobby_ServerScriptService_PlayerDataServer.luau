
local Players=game:GetService("Players")
local Marketplace=game:GetService("MarketplaceService")
local RS=game:GetService("ReplicatedStorage")
local Data=require(script.Parent:WaitForChild("PlayerData"))
local request=RS:FindFirstChild("GBloxShopRequest") or Instance.new("RemoteFunction")
request.Name="GBloxShopRequest";request.Parent=RS
local feedback=RS:FindFirstChild("GBloxShopFeedback") or Instance.new("RemoteEvent")
feedback.Name="GBloxShopFeedback";feedback.Parent=RS
local last,busy={},{}
request.OnServerInvoke=function(player,kind,id)
 if (kind~="GamePass" and kind~="Product") or type(id)~="number" or id~=math.floor(id) then return false,"Invalid item." end
 if busy[player] or os.clock()-(last[player] or -10)<1 then return false,"Please wait a moment." end
 last[player]=os.clock();busy[player]=true
 local ok,allowed,message=pcall(Data.CanPromptPurchase,player,kind,id)
 busy[player]=nil
 if not ok then warn("[GBloxShop] Prepare failed:",allowed);return false,"Shop unavailable. Please try again." end
 return allowed,message
end
Marketplace.ProcessReceipt=function(receipt)
 local player=Players:GetPlayerByUserId(receipt.PlayerId)
 if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
 local ok,saved=pcall(Data.GrantCashReceipt,player,receipt)
 if not ok then warn("[GBloxShop] Receipt save failed:",saved) end
 if ok and saved then
  if player.Parent then feedback:FireClient(player,"Purchase received! Your cash has been added.") end
  return Enum.ProductPurchaseDecision.PurchaseGranted
 end
 return Enum.ProductPurchaseDecision.NotProcessedYet
end
Marketplace.PromptGamePassPurchaseFinished:Connect(function(player,id,purchased)
 if not purchased or (id~=1981874715 and id~=1981928696) then return end
 local ok,err=pcall(Data.RecordCashPass,player,id)
 if not ok then warn("[GBloxShop] Pass save failed:",err) end
 if player.Parent then feedback:FireClient(player,"Cash boost active! Thank you.") end
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

