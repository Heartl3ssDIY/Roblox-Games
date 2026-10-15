local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Data=require(script.Parent.PlayerData)
local remote=RS:WaitForChild("GBloxPlaytimeRewards")
local busy,last={},{}
remote.OnServerInvoke=function(player,action,index)
 if action~="Status" and action~="Claim" then return {Ok=false,Message="Unknown request."} end
 if busy[player] or os.clock()-(last[player] or -math.huge)<.35 then return {Ok=false,Message="Please wait a moment."} end
 busy[player]=true last[player]=os.clock()
 local ok,result=pcall(function()
  local state,message=Data.PlaytimeRewardStatus(player)
  if not state then return {Ok=false,Message=message} end
  local success=true
  if action=="Claim" then
   if player:GetAttribute("GBloxLobbyReady")~=true or player:GetAttribute("GBloxInParty") then return {Ok=false,Message="Claim your rewards back in the lobby."} end
   success,message=Data.ClaimPlaytimeReward(player,index)
   state=Data.PlaytimeRewardStatus(player)
  end
  return {Ok=success,Message=message,State=state}
 end)
 busy[player]=nil
 if not ok then warn("[PlaytimeRewards]",result) return {Ok=false,Message="Rewards unavailable. Please retry."} end
 return result
end
Players.PlayerRemoving:Connect(function(player) busy[player]=nil last[player]=nil end)
