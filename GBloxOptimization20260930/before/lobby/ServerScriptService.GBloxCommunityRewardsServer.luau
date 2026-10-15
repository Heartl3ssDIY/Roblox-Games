local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local CS=game:GetService("CollectionService")
local Groups=game:GetService("GroupService")
local Data=require(script.Parent.PlayerData)
local Rules=require(RS.GBloxCommunityRewardRules)
local remote=RS:WaitForChild("GBloxCommunityRewards")
local busy,last={},{}
local function nearGift(player)
 if player:GetAttribute("GBloxLobbyReady")~=true or player:GetAttribute("GBloxInParty") or player:GetAttribute("OnTreadmill") then return false end
 local char=player.Character
 local root=char and char:FindFirstChild("HumanoidRootPart")
 local hum=char and char:FindFirstChildOfClass("Humanoid")
 if not root or not hum or hum.Health<=0 then return false end
 for _,part in CS:GetTagged("GBloxCommunityGift") do
  if part:IsA("BasePart") and part:IsDescendantOf(workspace)
   and Rules.Near(root.Position,part:GetAttribute("GiftCenter") or part.Position,Rules.CloseRadius) then return true end
 end
 return false
end
local function member(player,refresh)
 if not refresh then
  local ok,result=pcall(function() return player:IsInGroupAsync(Rules.GroupId) end)
  if ok and result then return true end
 end
 -- Check server-side group data after a prompt; never trust a client "joined" flag.
 -- If Roblox's membership cache hasn't updated, withhold the grant and allow retry.
 local ok,groups=pcall(function() return Groups:GetGroupsAsync(player.UserId) end)
 if not ok then return nil end
 for _,group in groups do if group.Id==Rules.GroupId then return true end end
 return false
end
remote.OnServerInvoke=function(player,action)
 if action~="Visit" and action~="CheckCommunity" and action~="ThankYou" then return {Ok=false,Message="Unknown request."} end
 if not nearGift(player) then return {Ok=false,Message="Walk up to the gift box in the lobby."} end
 if busy[player] or os.clock()-(last[player] or -math.huge)<.8 then return {Ok=false,Message="Please wait a moment."} end
 busy[player]=true last[player]=os.clock()
 local ok,result=pcall(function()
  local state=Data.CommunityRewardStatus(player)
  if not state then return {Ok=false,Message="Your save is still loading."} end
  local success,message=true,"Each reward can only be claimed once."
  local isMember=state.Community
  if action=="ThankYou" then
   if not state.Like then success,message=Data.ClaimLikeThankYou(player)
   else message="Your thank-you gift is already claimed. You can still use the game-page link." end
  elseif not state.Community then
   isMember=member(player,action=="CheckCommunity")
   if not nearGift(player) then return {Ok=false,Message="Return to the gift box to collect your reward."} end
   if isMember then success,message=Data.ClaimCommunityReward(player,true)
   elseif isMember==nil then success=false message="Couldn't check membership. Try the community button again."
   elseif action=="CheckCommunity" then message="Membership hasn't updated yet. Try again shortly, or rejoin after joining."
   else message="Join our community for a free reward. Tap the heart for your one-time thank-you gift." end
  elseif action~="ThankYou" then message="Your community reward is already claimed." end
  return {Ok=success,Message=message,State=Data.CommunityRewardStatus(player),IsMember=isMember==true,GroupId=Rules.GroupId}
 end)
 busy[player]=nil
 if not ok then warn("[CommunityRewards]",result) return {Ok=false,Message="Could not process your reward. Please try again."} end
 return result
end
Players.PlayerRemoving:Connect(function(player) busy[player]=nil last[player]=nil end)

