local M={}
function M.new(context)
 local states={}
 local self={}
 local function state(player)
  local data=context.Runners[player]
  local s=states[player]
  if not s or s.root~=data.root or s.round~=context.RoundKey() then
   s={data=data,root=data.root,round=context.RoundKey()} states[player]=s
  end
  return s
 end
 function self.Freeze(player,seconds)
  local s=state(player)
  s.frozenUntil=math.max(s.frozenUntil or 0,context.Now()+seconds)
  s.data.freezeUntil=s.frozenUntil
  s.root.AssemblyLinearVelocity=Vector3.zero
  s.root.AssemblyAngularVelocity=Vector3.zero
  s.root.Anchored=true
  player:SetAttribute("GBloxFrozenUntil",s.frozenUntil)
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
  for _,name in {"GBloxFrozenUntil","GBloxSuperspeedUntil","GBloxAntispikeUntil"} do player:SetAttribute(name,nil) end
  states[player]=nil
 end
 function self.Step()
  local now=context.Now()
  for player,s in states do
   local data=context.Runners[player]
   if not player.Parent or data~=s.data or data.root~=s.root or not s.root.Parent
    or context.RoundKey()~=s.round or context.Phase()~="Running" or data.status~="Running" or data.recovering
    or not data.humanoid or data.humanoid.Health<=0 then
    -- The round/recovery system owns anchoring after a state transition.
    clear(player,s)
   else
    if s.frozenUntil then
     if now>=s.frozenUntil then
      s.frozenUntil=nil data.freezeUntil=nil
      player:SetAttribute("GBloxFrozenUntil",nil)
      s.root.AssemblyLinearVelocity=Vector3.zero s.root.AssemblyAngularVelocity=Vector3.zero
      s.root.Anchored=false
     else
      s.root.Anchored=true
      s.root.AssemblyLinearVelocity=Vector3.zero s.root.AssemblyAngularVelocity=Vector3.zero
      if data.runTrack then data.runTrack:AdjustSpeed(0) end
     end
    end
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

