local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Data=require(script.Parent:WaitForChild("PlayerData"))
local remote=RS:FindFirstChild("GBloxRedeemCode") or Instance.new("RemoteFunction")
remote.Name="GBloxRedeemCode" remote.Parent=RS
local busy,last={},{ }
remote.OnServerInvoke=function(player,input)
 if type(input)~="string" or #input>64 then return false,"That code is not valid." end
 local now=os.clock()
 if busy[player] or now-(last[player] or -math.huge)<1 then return false,"Please wait a moment before trying again." end
 last[player]=now busy[player]=true
 local ok,success,message=pcall(Data.RedeemCode,player,input)
 busy[player]=nil
 if not ok then warn("[Codes] Redemption failed:",success) return false,"Could not redeem right now. Please try again." end
 return success,message
end
Players.PlayerRemoving:Connect(function(player) busy[player]=nil last[player]=nil end)

