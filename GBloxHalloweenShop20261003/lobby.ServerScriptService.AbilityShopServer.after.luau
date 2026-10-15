local Data=require(script.Parent.PlayerData)
local Rules=require(game.ReplicatedStorage:WaitForChild("GBloxAbilityRules"))
local remote=game.ReplicatedStorage:WaitForChild("AbilityPurchase")
local busy,last={},{}
remote.OnServerInvoke=function(player,id)
 if typeof(id)~="string" or not Rules.GetPurchase(id) then return false,"Unknown ability." end
 if busy[player] or os.clock()-(last[player] or 0)<1 then return false,"Please wait." end
 busy[player]=true last[player]=os.clock()
 local ok,success,message=pcall(Data.BuyAbility,player,id)
 busy[player]=nil
 if not ok then warn("[AbilityShop]",success) return false,"Purchase unavailable. Please try later." end
 return success,message
end
game.Players.PlayerRemoving:Connect(function(p) busy[p]=nil last[p]=nil end)
