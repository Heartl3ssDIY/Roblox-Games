local M=(function()
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

end)()
local count=0
local function check(value,message) count+=1 assert(value,message) end
local clock=1
local round=1
local phase="Running"
local runners={}
local function player(id,status)
 local p={UserId=id,Parent=true,attrs={}}
 function p:GetAttribute(key) return self.attrs[key] end
 function p:SetAttribute(key,value) self.attrs[key]=value end
 local character={}
 local root={Parent=character,Position=Vector3.new(id*10,5,8)}
 p.Character=character
 runners[p]={status=status,courseVersion=round,character=character,root=root,humanoid={Health=100}}
 return p
end
local viewer=player(1,"Out")
local a=player(2,"Running")
local b=player(3,"Running")
local api=M.new({Runners=runners,Phase=function() return phase end,RoundKey=function() return round end,Now=function() return clock end})
api:Step()
check(viewer.ReplicationFocus==runners[a].root,"initial target focus")
check(viewer:GetAttribute("RunnerSpectateUserId")==2,"initial target id")
check(viewer:GetAttribute("RunnerSpectatePosition")==runners[a].root.Position,"server position independent of local rig")
check(a.ReplicationFocus==nil and b.ReplicationFocus==nil,"active runners not altered")
local revision=viewer:GetAttribute("RunnerSpectateRevision")
api:Step()
check(viewer:GetAttribute("RunnerSpectateRevision")==revision,"unchanged Step not republishing revision")
runners[a].root.Position=Vector3.new(100,5,8)
clock+=.6 api:Step()
check(viewer:GetAttribute("RunnerSpectatePosition")==runners[a].root.Position,"moving position refresh")
check(viewer:GetAttribute("RunnerSpectateRevision")==revision,"position refresh not new target")
check(api:Select(viewer,3),"valid selection")
check(viewer.ReplicationFocus==runners[b].root,"focus follows selected target")
check(not api:Select(viewer,2),"rate limiting")
clock+=.3
check(api:Select(viewer,2),"selection after rate window")
runners[a].status="Finished" api:Step()
check(viewer:GetAttribute("RunnerSpectateUserId")==3,"finished target automatically replaced")
check(a:GetAttribute("RunnerSpectateUserId")==3,"finished player becomes observer")
b.Parent=nil api:Step()
check(viewer.ReplicationFocus==nil,"departing target clears focus")
check(viewer:GetAttribute("RunnerSpectateUserId")==nil,"no runners clears target")
check(viewer:GetAttribute("RunnerSpectatePosition")==nil,"no runners clears position")
b.Parent=true runners[b].status="Running" api:Step()
check(viewer.ReplicationFocus==runners[b].root,"target returning selected")
local oldRevision=viewer:GetAttribute("RunnerSpectateRevision")
local newCharacter={}
b.Character=newCharacter runners[b].character=newCharacter runners[b].root={Parent=newCharacter,Position=Vector3.new(200,6,8)}
api:Step()
check(viewer.ReplicationFocus==runners[b].root,"replacement root followed")
check(viewer:GetAttribute("RunnerSpectateRevision")>oldRevision,"same user new root new revision")
runners[b].root.Parent=nil api:Step()
check(viewer.ReplicationFocus==nil,"missing root clears")
runners[b].root.Parent=newCharacter runners[b].humanoid.Health=0 api:Step()
check(viewer.ReplicationFocus==nil,"dead target rejected")
runners[b].humanoid.Health=100 runners[b].courseVersion=2 api:Step()
check(viewer.ReplicationFocus==nil,"wrong course rejected")
runners[b].courseVersion=1 api:Step()
check(viewer.ReplicationFocus==runners[b].root,"right course recovered")
viewer:SetAttribute("GBloxPodiumActive",true) api:Step()
check(viewer.ReplicationFocus==nil,"podium focus restored")
check(viewer:GetAttribute("RunnerSpectateUserId")==nil,"podium metadata cleared")
viewer:SetAttribute("GBloxPodiumActive",false)
for _,status in {"Out","Finished","Spectating"} do
 runners[viewer].status=status runners[viewer].courseVersion=nil api:Step()
 check(viewer.ReplicationFocus==runners[b].root,status.." can spectate including late join")
end
for _,status in {"Running","Waiting","Loading","Podium"} do
 runners[viewer].status=status api:Step()
 check(viewer.ReplicationFocus==nil,status.." not observing")
end
runners[viewer].status="Out"
for _,value in {"Waiting","Countdown","Intermission","AwaitingCourse","MatchComplete"} do
 phase="Running" api:Step()
 phase=value api:Step()
 check(viewer.ReplicationFocus==nil,value.." clears focus")
 check(not api:Select(viewer,3),value.." selection denied")
end
phase="Running" api:Step()
for _,value in {"3",true,0,1.5,math.huge,-math.huge,0/0,9007199254740992} do
 clock+=1
 check(not api:Select(viewer,value),"invalid target value rejected")
end
clock+=1 check(not api:Select(viewer,viewer.UserId),"cannot spectate self")
clock+=1 check(not api:Select(viewer,999999),"unknown target rejected")
clock+=1 check(not api:Select(b,viewer.UserId),"running player request denied")
clock+=1 check(not api:Select(viewer,a.UserId),"finished target request denied")
local c=player(-1,"Running")
clock+=1 check(api:Select(viewer,-1),"Studio negative player id accepted")
check(viewer.ReplicationFocus==runners[c].root,"Studio player selected")
api:Remove(viewer)
check(viewer.ReplicationFocus==nil,"Remove restores focus")
check(viewer:GetAttribute("RunnerSpectateUserId")==nil,"Remove clears metadata")
runners[viewer]=nil api:Step()
check(viewer.ReplicationFocus==nil,"removed observer stays clear")
local newcomer=player(8,"Spectating")
api:Step()
check(newcomer.ReplicationFocus==runners[c].root,"late arrival initialized")
round=2 api:Step()
check(newcomer.ReplicationFocus==nil,"old round targets rejected")
runners[b].courseVersion=2 api:Step()
check(newcomer.ReplicationFocus==runners[b].root,"new current course selected")
return count

