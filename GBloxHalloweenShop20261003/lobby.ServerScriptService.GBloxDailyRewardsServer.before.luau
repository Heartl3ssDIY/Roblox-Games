local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Data=require(script.Parent.PlayerData)
local Rules=require(RS.GBloxDailyRewardRules)
local daily=RS:WaitForChild("GBloxDailyRewards")
local equip=RS:WaitForChild("GBloxAbilityEquip")
local offsets,busy,last={},{},{}
local function offsetFor(player,reported)
 -- A device supplies only its timezone; all dates and eligibility use the server clock.
 -- Freeze it for this session. The persisted claim-day high-water mark prevents
 -- claiming the same calendar date twice after reconnecting or travelling west.
 if offsets[player]~=nil then return offsets[player] end
 if not Rules.ValidOffset(reported) then return nil end
 offsets[player]=reported
 return reported
end
daily.OnServerInvoke=function(player,action,reported)
 if action~="Status" and action~="Claim" then return {Ok=false,Message="Unknown request."} end
 local offset=offsetFor(player,reported)
 if offset==nil then return {Ok=false,Message="Could not read your local time zone."} end
 if busy[player] then return {Ok=false,Message="Please wait for your current request."} end
 local now=os.clock()
 if now-(last[player] or -math.huge)<.35 then return {Ok=false,Message="Please wait a moment."} end
 last[player]=now busy[player]=true
 local ok,result=pcall(function()
  local status,message=Data.DailyRewardStatus(player,offset)
  if not status then return {Ok=false,Message=message} end
  local success=true
  if action=="Claim" then
   if player:GetAttribute("GBloxLobbyReady")~=true then return {Ok=false,Message="Enter the lobby before claiming."} end
   success,message=Data.ClaimDailyReward(player,offset)
   status=Data.DailyRewardStatus(player,offset)
  end
  return {Ok=success,Message=message,State=status}
 end)
 busy[player]=nil
 if not ok then warn("[DailyRewards]",result) return {Ok=false,Message="Rewards unavailable. Please try again."} end
 return result
end
equip.OnServerInvoke=function(player,id)
 if typeof(id)~="string" or (id~="" and not Rules.Abilities[id]) then return false,"Unknown ability." end
 if id=="Kong" then return false,"Kong is unavailable for now." end
 if player:GetAttribute("GBloxLobbyReady")~=true or player:GetAttribute("GBloxInParty") then return false,"Equip abilities in the lobby before joining a party." end
 if busy[player] or os.clock()-(last[player] or -math.huge)<.35 then return false,"Please wait a moment." end
 last[player]=os.clock() busy[player]=true
 local ok,success,message=pcall(Data.SetEquippedAbility,player,id)
 busy[player]=nil
 if not ok then warn("[AbilityEquip]",success) return false,"Could not equip. Please try again." end
 return success,message
end
-- Count continued attendance across midnight, even with the panel closed.
task.spawn(function()
 while true do
  task.wait(30)
  for player,offset in offsets do if player.Parent then Data.DailyRewardStatus(player,offset) end end
 end
end)
Players.PlayerRemoving:Connect(function(player) offsets[player]=nil busy[player]=nil last[player]=nil end)

