local M={}

function M.new(context)
 local states={}
 local requests={}
 local now=context.Now or os.clock
 local phase=context.Phase
 local runners=context.Runners
 local function eligible(player,data)
  return data and player.Parent and phase()=="Running"
   and not player:GetAttribute("GBloxPodiumActive")
   and (data.status=="Out" or data.status=="Finished" or data.status=="Spectating")
 end
 local function targetRoot(player,observer)
  local data=player and runners[player]
  if player==observer or not data or not player.Parent or data.status~="Running"
   or data.courseVersion~=context.RoundKey() or not data.humanoid or data.humanoid.Health<=0
   or not data.root or not data.root.Parent or data.character~=player.Character
   or data.root.Parent~=data.character then return nil end
  return data.root
 end
 local function firstTarget(observer)
  local first
  for candidate in runners do
   if targetRoot(candidate,observer) and (not first or candidate.UserId<first.UserId) then first=candidate end
  end
  return first
 end
 local function publish(player,state)
  player:SetAttribute("RunnerSpectatePosition",state.root and state.root.Position or nil)
  player:SetAttribute("RunnerSpectateUserId",state.target and state.target.UserId or nil)
  player:SetAttribute("RunnerSpectateRevision",(player:GetAttribute("RunnerSpectateRevision") or 0)+1)
  state.nextPosition=now()+.5
 end
 local function clear(player)
  local state=states[player]
  if not state then return end
  states[player]=nil
  player.ReplicationFocus=nil
  if player.Parent then
   state.target=nil state.root=nil
   publish(player,state)
  end
 end
 local function apply(player,target)
  local root=targetRoot(target,player)
  if not root then target=nil end
  local state=states[player]
  if not state then
   state={}
   states[player]=state
  end
  if state.target~=target or state.root~=root or not state.initialized then
   state.initialized=true state.target=target state.root=root
   player.ReplicationFocus=root
   publish(player,state)
  elseif root and now()>=(state.nextPosition or 0) then
   player:SetAttribute("RunnerSpectatePosition",root.Position)
   state.nextPosition=now()+.5
  end
 end
 local self={}
 function self:Select(player,userId)
  if not eligible(player,runners[player]) or typeof(userId)~="number"
   or userId~=userId or math.abs(userId)>9007199254740991 or userId%1~=0 or userId==0 then return false end
  local timestamp=now()
  if timestamp-(requests[player] or -math.huge)<.2 then return false end
  requests[player]=timestamp
  local selected
  for candidate in runners do if candidate.UserId==userId then selected=candidate break end end
  if not targetRoot(selected,player) then return false end
  apply(player,selected)
  return true
 end
 function self:Step()
  for player,data in runners do
   if eligible(player,data) then
    local state=states[player]
    local target=state and state.target
    if not targetRoot(target,player) then target=firstTarget(player) end
    apply(player,target)
   else
    clear(player)
   end
  end
  for player in states do if not runners[player] then clear(player) end end
 end
 function self:Remove(player)
  clear(player)
  requests[player]=nil
 end
 return self
end

return M

