function PlayerData.PlaytimeRewardStatus(player)
 local p=profiles[player]
 if not p or (not p.CanSave and not p.StudioTemporary) then return nil,"Your save is still loading." end
 local status=PlaytimeRules.Status(p.PlaytimeRewards,os.time())
 status.Temporary=p.StudioTemporary==true
 return status
end
function PlayerData.ClaimPlaytimeReward(player,index)
 local p=profiles[player]
 if not p or (not p.CanSave and not p.StudioTemporary) then return false,"Your save is still loading." end
 if saving[player] or p.PurchasePending or (p.CanSave and os.time()>=(p.LeaseUntil or 0)) then return false,"Save busy; please try again shortly." end
 local ok,message=PlaytimeRules.Apply(p,os.time(),index)
 if not ok then return false,message end
 sync(player)
 if p.StudioTemporary then return true,message.." (Studio preview; not saved.)" end
 local saved=PlayerData.Save(player)
 return true,saved and message or message.." Save pending; please stay connected."
end
function PlayerData.PreparePlaytimeTeleport(player,destination)
 local p=profiles[player]
 if not p or (not p.CanSave and not p.StudioTemporary) then return nil,"Your save is still loading." end
 if not PlaytimeRules.Places[destination] then return nil,"This destination does not carry playtime." end
 if saving[player] or p.PurchasePending or p.PlaytimeRewards.Handoff then return nil,"Save busy; please try again shortly." end
 if p.CanSave and os.time()>=(p.LeaseUntil or 0) then return nil,"Your save is reconnecting." end
 local token=Http:GenerateGUID(false)
 p.PlaytimeRewards.Handoff={Token=token,From=game.PlaceId,To=destination,Expires=os.time()+180}
 player:SetAttribute("GBloxPlaytimeTransferring",true)
 if not p.StudioTemporary and not PlayerData.Save(player) then
  p.PlaytimeRewards.Handoff=nil player:SetAttribute("GBloxPlaytimeTransferring",false)
  return nil,"Could not safely save your playtime. Please retry."
 end
 -- A failed/stalled teleport must not lock claims indefinitely.
 task.delay(180,function() PlayerData.CancelPlaytimeTeleport(player,token) end)
 return token
end
function PlayerData.CancelPlaytimeTeleport(player,token)
 local p=profiles[player]
 local h=p and p.PlaytimeRewards and p.PlaytimeRewards.Handoff
 if h and (token==nil or h.Token==token) then
  p.PlaytimeRewards.Handoff=nil
  if player.Parent then player:SetAttribute("GBloxPlaytimeTransferring",false) end
 end
end
