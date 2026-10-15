local Data=require(script.Parent.PlayerData)
local remote=game.ReplicatedStorage:WaitForChild("AbilityPurchase")
local prices={GravitySwitch=300000,PlatBeGone=100000,Kong=500000,Freeze=200000,Antispike=400000,Superspeed=500000}
local busy,last={},{}
remote.OnServerInvoke=function(player,id)
 if typeof(id)~="string" or not prices[id] then return false,"Unknown ability." end
 if busy[player] or os.clock()-(last[player] or 0)<1 then return false,"Please wait." end
 busy[player]=true last[player]=os.clock()
 local ok,success,message=pcall(Data.BuyAbility,player,id,prices[id])
 busy[player]=nil
 if not ok then warn("[AbilityShop]",success) return false,"Purchase unavailable. Please try later." end
 return success,message
end
game.Players.PlayerRemoving:Connect(function(p) busy[p]=nil last[p]=nil end)
