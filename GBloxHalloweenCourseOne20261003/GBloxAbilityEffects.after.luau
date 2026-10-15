local M={}
function M.new(context)
 local states={}
 local self={}
 local function state(player)
  local data=context.Runners[player]
  if not data or not data.root then return end
  local s=states[player]
  if not s or s.root~=data.root or s.round~=context.RoundKey() then
   s={data=data,root=data.root,round=context.RoundKey()}
   states[player]=s
  end
  return s
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
  elseif previous and context.Runners[player]==s.data and s.data.root==s.root
   and s.root.Parent and s.data.status=="Running" and not s.data.recovering
   and context.RoundKey()==s.round and context.Phase()=="Running"
   and s.data.humanoid and s.data.humanoid.Health>0 then
   s.root.AssemblyLinearVelocity=Vector3.zero
   s.root.AssemblyAngularVelocity=Vector3.zero
   s.root.Anchored=false
   pcall(function() s.root:SetNetworkOwner(player) end)
  end
 end
 function self.Freeze(player,seconds)
  local s=state(player)
  if not s then return end
  s.abilityFrozenUntil=math.max(s.abilityFrozenUntil or 0,context.Now()+seconds)
  syncFreeze(player,s)
 end
 function self.FreezeSeasonal(player,seconds)
  local s=state(player)
  if not s then return end
  s.seasonalFrozenUntil=math.max(s.seasonalFrozenUntil or 0,context.Now()+seconds)
  syncFreeze(player,s)
  return s.seasonalFrozenUntil
 end
 function self.ClearSeasonalFreeze(player)
  local s=states[player]
  if not s then
   player:SetAttribute("GBloxHalloweenHeldUntil",nil)
   return
  end
  s.seasonalFrozenUntil=nil
  syncFreeze(player,s)
 end
 function self.Superspeed(player,seconds)
  local s=state(player)
  s.superUntil=context.Now()+seconds
  s.data.superUntil=s.superUntil
  player:SetAttribute("GBloxSuperspeedUntil",s.superUntil)
  context.SetSpeed(s.data,context.BoostMultiplier*2)
 end
 function self.Antispike(player,seconds)
  local s=state(player)
  s.antiUntil=context.Now()+seconds
  s.data.antispikeUntil=s.antiUntil
  s.data.antispikeRound=s.round
  player:SetAttribute("GBloxAntispikeUntil",s.antiUntil)
 end
 local function clear(player,s)
  local hadSuper=s.data.superUntil~=nil
  s.data.freezeUntil=nil s.data.superUntil=nil s.data.antispikeUntil=nil s.data.antispikeRound=nil
  if hadSuper then context.SetSpeed(s.data,(s.data.normalBoostUntil or 0)>context.Now() and context.BoostMultiplier or 1) end
  for _,name in {"GBloxFrozenUntil","GBloxHalloweenHeldUntil","GBloxSuperspeedUntil","GBloxAntispikeUntil"} do player:SetAttribute(name,nil) end
  states[player]=nil
 end
 function self.Step()
  local now=context.Now()
  for player,s in states do
   local data=context.Runners[player]
   if not player.Parent or data~=s.data or data.root~=s.root or not s.root.Parent
    or context.RoundKey()~=s.round or context.Phase()~="Running" or data.status~="Running" or data.recovering
    or not data.humanoid or data.humanoid.Health<=0 then
    clear(player,s)
   else
    syncFreeze(player,s)
    if s.superUntil and now>=s.superUntil then
     s.superUntil=nil data.superUntil=nil player:SetAttribute("GBloxSuperspeedUntil",nil)
     context.SetSpeed(data,(data.normalBoostUntil or 0)>now and context.BoostMultiplier or 1)
    end
    if s.antiUntil and now>=s.antiUntil then
     s.antiUntil=nil data.antispikeUntil=nil data.antispikeRound=nil player:SetAttribute("GBloxAntispikeUntil",nil)
    end
    if not s.frozenUntil and not s.superUntil and not s.antiUntil then states[player]=nil end
   end
  end
 end
 function self.Remove(player) local s=states[player] if s then clear(player,s) end end
 return self
end
return M

