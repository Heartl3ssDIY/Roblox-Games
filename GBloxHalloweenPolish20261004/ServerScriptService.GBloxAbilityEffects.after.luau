local M={}
function M.new(context)
 local states={}
 local self={}
 local clear
 local function active(player,s)
  return player.Parent and context.Runners[player]==s.data and s.data.root==s.root
   and s.root.Parent and s.data.status=="Running" and not s.data.recovering
   and context.RoundKey()==s.round and context.Phase()=="Running"
   and s.data.humanoid and s.data.humanoid.Health>0
 end
 local function state(player)
  local data=context.Runners[player]
  if not data or not data.root then return end
  local s=states[player]
  if not s or s.root~=data.root or s.round~=context.RoundKey() or s.data~=data then
   if s then clear(player,s) end
   s={data=data,root=data.root,round=context.RoundKey()}
   states[player]=s
  end
  return s
 end
 local function restoreCorner(player,s)
  if s.cornerVelocity then s.cornerVelocity:Destroy() s.cornerVelocity=nil end
  if s.cornerAttachment then s.cornerAttachment:Destroy() s.cornerAttachment=nil end
  if s.cornerForward and s.cornerForward.Parent then s.cornerForward.Enabled=s.cornerForwardEnabled end
  s.cornerForward=nil s.cornerForwardEnabled=nil
  if s.cornerOwnershipTaken and active(player,s) and not s.root.Anchored then
   pcall(function()
    if s.cornerOwnerAuto then s.root:SetNetworkOwnershipAuto()
    else s.root:SetNetworkOwner(s.cornerOwner) end
   end)
  end
  s.cornerOwnershipTaken=nil s.cornerOwner=nil s.cornerOwnerAuto=nil
  s.cornerUntil=nil s.cornerFallSpeed=nil
  s.data.cornerWebUntil=nil
  player:SetAttribute("GBloxCornerWebHeldUntil",nil)
  if active(player,s) and not s.frozenUntil then
   context.SetSpeed(s.data,(s.data.normalBoostUntil or 0)>context.Now() and context.BoostMultiplier or 1)
  end
 end
 local function syncFreeze(player,s)
  local now=context.Now()
  local previous=s.frozenUntil
  if (s.abilityFrozenUntil or 0)<=now then s.abilityFrozenUntil=nil end
  if (s.seasonalFrozenUntil or 0)<=now then s.seasonalFrozenUntil=nil end
  local untilTime=math.max(s.abilityFrozenUntil or 0,s.seasonalFrozenUntil or 0)
  s.frozenUntil=untilTime>now and untilTime or nil
  s.data.freezeUntil=s.frozenUntil
  player:SetAttribute("GBloxFrozenUntil",s.frozenUntil)
  player:SetAttribute("GBloxHalloweenHeldUntil",s.seasonalFrozenUntil)
  if s.frozenUntil then
   s.root.AssemblyLinearVelocity=Vector3.zero
   s.root.AssemblyAngularVelocity=Vector3.zero
   s.root.Anchored=true
   if s.data.velocity then s.data.velocity.LineVelocity=0 end
   if s.data.runTrack then s.data.runTrack:AdjustSpeed(0) end
  elseif previous and active(player,s) then
   s.root.AssemblyLinearVelocity=Vector3.zero
   s.root.AssemblyAngularVelocity=Vector3.zero
   s.root.Anchored=false
   pcall(function()
    if s.cornerUntil and s.cornerUntil>now and s.cornerOwnershipTaken then s.root:SetNetworkOwner(nil)
    else s.root:SetNetworkOwner(player) end
   end)
   if not s.cornerUntil or s.cornerUntil<=now then
    context.SetSpeed(s.data,(s.data.normalBoostUntil or 0)>now and context.BoostMultiplier or 1)
   end
  end
 end
 local function syncCorner(player,s)
  if not s.cornerUntil then return end
  if context.Now()>=s.cornerUntil then restoreCorner(player,s) return end
  s.data.cornerWebUntil=s.cornerUntil
  player:SetAttribute("GBloxCornerWebHeldUntil",s.cornerUntil)
  if s.cornerForward and s.cornerForward.Parent then
   s.cornerForward.Enabled=false
   s.cornerForward.LineVelocity=0
  end
  if s.data.runTrack then s.data.runTrack:AdjustSpeed(0) end
  if s.frozenUntil or s.root.Anchored then
   if s.cornerVelocity then s.cornerVelocity.Enabled=false end
   return
  end
  if not s.cornerOwnershipTaken then
   s.cornerOwner=player
   pcall(function() s.cornerOwnerAuto=s.root:GetNetworkOwnershipAuto() s.cornerOwner=s.root:GetNetworkOwner() end)
   local ok=pcall(function() s.root:SetNetworkOwner(nil) end)
   if ok then s.cornerOwnershipTaken=true end
  end
  if not s.cornerVelocity then
   local attachment=s.data.attachment
   if not attachment or not attachment.Parent then
    attachment=Instance.new("Attachment")
    attachment.Name="GBloxCornerWebAttachment"
    attachment.Parent=s.root
    s.cornerAttachment=attachment
   end
   local velocity=Instance.new("LinearVelocity")
   velocity.Name="GBloxCornerWebFall"
   velocity.Attachment0=attachment
   velocity.RelativeTo=Enum.ActuatorRelativeTo.World
   velocity.VelocityConstraintMode=Enum.VelocityConstraintMode.Vector
   velocity.ForceLimitsEnabled=true
   velocity.ForceLimitMode=Enum.ForceLimitMode.Magnitude
   velocity.MaxForce=100000
   velocity.Parent=s.root
   s.cornerVelocity=velocity
  end
  s.cornerVelocity.VectorVelocity=Vector3.new(0,-(s.data.gravitySign or 1)*s.cornerFallSpeed,0)
  s.cornerVelocity.Enabled=true
 end
 function self.Freeze(player,seconds)
  local s=state(player)
  if not s then return end
  s.abilityFrozenUntil=math.max(s.abilityFrozenUntil or 0,context.Now()+seconds)
  syncFreeze(player,s)
  syncCorner(player,s)
 end
 function self.FreezeSeasonal(player,seconds)
  local s=state(player)
  if not s then return end
  s.seasonalFrozenUntil=math.max(s.seasonalFrozenUntil or 0,context.Now()+seconds)
  syncFreeze(player,s)
  syncCorner(player,s)
  return s.seasonalFrozenUntil
 end
 function self.ClearSeasonalFreeze(player)
  local s=states[player]
  if not s then player:SetAttribute("GBloxHalloweenHeldUntil",nil) return end
  s.seasonalFrozenUntil=nil
  syncFreeze(player,s)
  if active(player,s) then syncCorner(player,s) end
 end
 function self.HoldCornerWeb(player,seconds,fallSpeed)
  if typeof(seconds)~="number" or seconds~=seconds or seconds<=0 or seconds==math.huge then return end
  local s=state(player)
  if not s or not active(player,s) or (s.root.Anchored and not s.frozenUntil) then return end
  if (s.cornerUntil or 0)>context.Now() then return s.cornerUntil end
  if s.cornerUntil then restoreCorner(player,s) end
  s.cornerUntil=context.Now()+math.clamp(seconds,.5,10)
  s.cornerFallSpeed=typeof(fallSpeed)=="number" and fallSpeed==fallSpeed and math.clamp(fallSpeed,.5,12) or 6
  s.cornerForward=s.data.velocity
  s.cornerForwardEnabled=s.cornerForward and s.cornerForward.Enabled
  syncCorner(player,s)
  return s.cornerUntil
 end
 function self.ClearCornerWebHold(player)
  local s=states[player]
  if not s or not s.cornerUntil then player:SetAttribute("GBloxCornerWebHeldUntil",nil) return end
  restoreCorner(player,s)
 end
 function self.Superspeed(player,seconds)
  local s=state(player)
  if not s then return end
  s.superUntil=context.Now()+seconds
  s.data.superUntil=s.superUntil
  player:SetAttribute("GBloxSuperspeedUntil",s.superUntil)
  context.SetSpeed(s.data,context.BoostMultiplier*2)
 end
 function self.Antispike(player,seconds)
  local s=state(player)
  if not s then return end
  s.antiUntil=context.Now()+seconds
  s.data.antispikeUntil=s.antiUntil
  s.data.antispikeRound=s.round
  player:SetAttribute("GBloxAntispikeUntil",s.antiUntil)
 end
 clear=function(player,s)
  local hadSuper=s.data.superUntil~=nil
  if s.cornerUntil or s.cornerVelocity then restoreCorner(player,s) end
  s.data.freezeUntil=nil s.data.superUntil=nil s.data.antispikeUntil=nil s.data.antispikeRound=nil
  if hadSuper then context.SetSpeed(s.data,(s.data.normalBoostUntil or 0)>context.Now() and context.BoostMultiplier or 1) end
  for _,name in {"GBloxFrozenUntil","GBloxHalloweenHeldUntil","GBloxCornerWebHeldUntil","GBloxSuperspeedUntil","GBloxAntispikeUntil"} do player:SetAttribute(name,nil) end
  states[player]=nil
 end
 function self.Step()
  local now=context.Now()
  for player,s in states do
   if not active(player,s) then clear(player,s)
   else
    syncFreeze(player,s)
    syncCorner(player,s)
    if s.superUntil and now>=s.superUntil then
     s.superUntil=nil s.data.superUntil=nil player:SetAttribute("GBloxSuperspeedUntil",nil)
     context.SetSpeed(s.data,(s.data.normalBoostUntil or 0)>now and context.BoostMultiplier or 1)
    end
    if s.antiUntil and now>=s.antiUntil then
     s.antiUntil=nil s.data.antispikeUntil=nil s.data.antispikeRound=nil player:SetAttribute("GBloxAntispikeUntil",nil)
    end
    if not s.frozenUntil and not s.cornerUntil and not s.superUntil and not s.antiUntil then states[player]=nil end
   end
  end
 end
 function self.Remove(player) local s=states[player] if s then clear(player,s) end end
 return self
end
return M
