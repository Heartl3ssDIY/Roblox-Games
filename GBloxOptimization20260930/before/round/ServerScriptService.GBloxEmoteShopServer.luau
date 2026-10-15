local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local Content=game:GetService("ContentProvider")
local C=require(RS:WaitForChild("GBloxEmoteCatalog"))
local Data=require(game.ServerScriptService:WaitForChild("PlayerData"))
local remote=RS:FindFirstChild("GBloxEmoteRequest") or Instance.new("RemoteFunction")
remote.Name="GBloxEmoteRequest" remote.Parent=RS
local busy,last,availability,loading={},{},{},{}
local function available(id)
 local prior=availability[id]
 if prior and os.clock()-prior.at<(prior.ok and 300 or 15) then return prior.ok end
 if not loading[id] then
  loading[id]=true
  task.spawn(function()
   local animation=Instance.new("Animation") animation.AnimationId=C.ById[id].AnimationId
   local success=false
   local ok=pcall(function()
    Content:PreloadAsync({animation},function(_,status) if status==Enum.AssetFetchStatus.Success then success=true end end)
   end)
   animation:Destroy()
   availability[id]={ok=ok and success,at=os.clock()} loading[id]=nil
  end)
 end
 local deadline=os.clock()+10
 while loading[id] and os.clock()<deadline do task.wait(.1) end
 return not loading[id] and availability[id] and availability[id].ok==true
end
remote.OnServerInvoke=function(player,action,id)
 if (action~="Buy" and action~="Equip" and action~="Unequip") or typeof(id)~="string" or not C.ById[id] then return false,"Unknown emote." end
 if busy[player] or os.clock()-(last[player] or -math.huge)<.5 then return false,"Please wait a moment." end
 busy[player]=true last[player]=os.clock()
 local ok,success,message=pcall(function()
  if action=="Buy" then
   local p=Data.Get(player)
   if not p then return false,"Your inventory is loading." end
   if not (p.Emotes and p.Emotes.Owned and p.Emotes.Owned[id]) and not available(id) then
    return false,"This emote couldn't load. No trophies were spent."
   end
   if not player.Parent then return false,"Player disconnected." end
   return Data.BuyEmote(player,id)
  end
  return Data.SetEquippedEmote(player,id,action=="Equip")
 end)
 busy[player]=nil
 if not ok then warn("[EmoteShop]",success) return false,"Couldn't complete the request. Check your inventory before retrying." end
 return success,message
end
Players.PlayerRemoving:Connect(function(p) busy[p]=nil last[p]=nil end)

