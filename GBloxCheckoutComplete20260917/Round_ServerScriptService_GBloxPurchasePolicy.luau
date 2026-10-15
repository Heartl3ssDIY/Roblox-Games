local Players=game:GetService("Players")
local Policy=game:GetService("PolicyService")
local M={}
local cache={}
function M.CanRandom(player)
 local entry=cache[player]
 if entry and os.clock()-entry.at<300 then return entry.allowed,entry.message end
 local ok,result=pcall(Policy.GetPolicyInfoForPlayerAsync,Policy,player)
 local allowed=ok and typeof(result)=="table" and result.ArePaidRandomItemsRestricted==false
 local message=allowed and "" or ok and "Random eggs are unavailable for your account." or "Could not check egg eligibility. Please try again."
 if ok and player.Parent then cache[player]={at=os.clock(),allowed=allowed,message=message} end
 if player.Parent then player:SetAttribute("GBloxRandomEggsAllowed",allowed) end
 return allowed,message
end
Players.PlayerRemoving:Connect(function(p) cache[p]=nil end)
return M

