local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local store=game:GetService("DataStoreService"):GetDataStore("GBloxAudioSettings_v1")
local remote=RS:WaitForChild("GBloxAudioSettings")
local busy,last={},{}
remote.OnServerInvoke=function(player,action,values)
 if busy[player] or os.clock()-(last[player] or -10)<.25 then return false,"Busy" end
 if action~="Load" and action~="Save" then return false,"Invalid request" end
 if action=="Save" and (typeof(values)~="table" or typeof(values.MusicEnabled)~="boolean" or typeof(values.SFXEnabled)~="boolean") then return false,"Invalid settings" end
 busy[player]=true last[player]=os.clock()
 local ok,result=pcall(function()
  local key="Player_"..player.UserId
  if action=="Load" then return store:GetAsync(key) end
  return store:UpdateAsync(key,function(old)
   local nextValue=typeof(old)=="table" and table.clone(old) or {}
   nextValue.MusicEnabled=values.MusicEnabled
   nextValue.SFXEnabled=values.SFXEnabled
   return nextValue
  end)
 end)
 busy[player]=nil
 if not ok then return false,"Audio changes apply this session; saving is unavailable." end
 result=typeof(result)=="table" and result or {}
 return true,{MusicEnabled=result.MusicEnabled~=false,SFXEnabled=result.SFXEnabled~=false}
end
Players.PlayerRemoving:Connect(function(player) busy[player]=nil last[player]=nil end)

