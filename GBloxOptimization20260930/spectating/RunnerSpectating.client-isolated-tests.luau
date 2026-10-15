local clock=1
local os={clock=function() return clock end}
local queue={}
local task={spawn=function(fn) table.insert(queue,fn) end}
local function drain()
 local pending=queue queue={}
 for _,fn in pending do fn() end
end
local function object(id,status)
 local p={UserId=id,DisplayName="Player"..id,attrs={RunnerStatus=status},signals={},Character={}}
 function p:GetAttribute(key) return self.attrs[key] end
 function p:GetAttributeChangedSignal(key)
  if not self.signals[key] then
   local signal={listeners={}}
   function signal:Connect(fn) table.insert(self.listeners,fn) end
   function signal:Fire() for _,fn in self.listeners do fn() end end
   self.signals[key]=signal
  end
  return self.signals[key]
 end
 function p:SetAttribute(key,value)
  self.attrs[key]=value
  if self.signals[key] then self.signals[key]:Fire() end
 end
 function p.Character:FindFirstChild(key) return self[key] end
 return p
end
local player=object(1,"Out")
local a=object(2,"Running")
local b=object(3,"Running")
local roster={player,a,b}
local Players={}
function Players:GetPlayers() return roster end
function Players:GetPlayerByUserId(id) for _,p in roster do if p.UserId==id then return p end end end
local workspace=object(0,"None") workspace.StreamingEnabled=true workspace.attrs.RunnerRoundPhase="Running"
local phase="Running"
local cameraTarget=player
local spectate={Visible=false}
local spectateName={Text=""}
local calls={}
local onStream
function player:RequestStreamAroundAsync(position,timeout)
 table.insert(calls,{position=position,timeout=timeout})
 if onStream then local fn=onStream onStream=nil fn() end
end
local remotes={}
local event={}
function event:FireServer(action,id) table.insert(remotes,{action=action,id=id}) end
local spectatorHoldUntil=0
local spectatorStreamKey
local queuedStreamPosition
local streamWorkerRunning=false
local function isSpectating()
 local status=player:GetAttribute("RunnerStatus")
 return phase=="Running" and not player:GetAttribute("GBloxPodiumActive")
  and not player:GetAttribute("GBloxPodiumCameraActive")
  and (status=="Out" or status=="Finished" or status=="Spectating")
end
local function requestSpectatorStream()
 local userId=player:GetAttribute("RunnerSpectateUserId")
 local revision=player:GetAttribute("RunnerSpectateRevision")
 local position=player:GetAttribute("RunnerSpectatePosition")
 local key=isSpectating() and typeof(userId)=="number" and typeof(revision)=="number"
  and typeof(position)=="Vector3" and tostring(revision)..":"..tostring(userId) or nil
 if key==spectatorStreamKey then return end
 spectatorStreamKey=key
 if not key then position=nil end
 queuedStreamPosition=typeof(position)=="Vector3" and position or nil
 if streamWorkerRunning or not queuedStreamPosition or not workspace.StreamingEnabled then return end
 streamWorkerRunning=true
 task.spawn(function()
  while queuedStreamPosition and isSpectating() do
   local requestedKey=spectatorStreamKey
   local requestedPosition=queuedStreamPosition
   queuedStreamPosition=nil
   pcall(function() player:RequestStreamAroundAsync(requestedPosition,2) end)
   if requestedKey==spectatorStreamKey then break end
  end
  streamWorkerRunning=false
 end)
end
local function refreshSpectatorTarget()
 local active=isSpectating()
 spectate.Visible=active
 if not active then return end
 if os.clock()<spectatorHoldUntil then cameraTarget=player return end
 local userId=player:GetAttribute("RunnerSpectateUserId")
 local target=typeof(userId)=="number" and Players:GetPlayerByUserId(userId) or nil
 local text
 if target and target:GetAttribute("RunnerStatus")=="Running" then
  cameraTarget=target
  local root=target.Character and target.Character:FindFirstChild("HumanoidRootPart")
  text=root and target.DisplayName or "LOADING "..target.DisplayName.."..."
 else
  cameraTarget=player
  text="WAITING FOR NEXT ROUND"
 end
 if spectateName.Text~=text then spectateName.Text=text end
end
local function runnersToWatch()
 local result={}
 for _,other in Players:GetPlayers() do
  if other~=player and other:GetAttribute("RunnerStatus")=="Running" then
   table.insert(result,other)
  end
 end
 table.sort(result,function(first,second) return first.UserId<second.UserId end)
 return result
end
local function chooseSpectatorTarget(direction)
 if not isSpectating() then return end
 local runners=runnersToWatch()
 if #runners==0 then return end
 local currentId=player:GetAttribute("RunnerSpectateUserId")
 local index
 for i,other in runners do if other.UserId==currentId then index=i break end end
 if index then index=(index-1+direction)%#runners+1
 else index=direction<0 and #runners or 1 end
 spectatorHoldUntil=0
 event:FireServer("Spectate",runners[index].UserId)
end
for _,name in {"RunnerSpectateRevision","RunnerSpectateUserId","RunnerSpectatePosition"} do
 player:GetAttributeChangedSignal(name):Connect(requestSpectatorStream)
end
local lastSpectatorStatus=player:GetAttribute("RunnerStatus")
player:GetAttributeChangedSignal("RunnerStatus"):Connect(function()
 local status=player:GetAttribute("RunnerStatus")
 if status=="Finished" and lastSpectatorStatus~="Finished" then spectatorHoldUntil=os.clock()+.8
 elseif status~="Finished" then spectatorHoldUntil=0 end
 lastSpectatorStatus=status
 requestSpectatorStream()
end)
workspace:GetAttributeChangedSignal("RunnerRoundPhase"):Connect(function()
 phase=workspace:GetAttribute("RunnerRoundPhase") or phase
 requestSpectatorStream()
end)
for _,name in {"GBloxPodiumActive","GBloxPodiumCameraActive"} do
 player:GetAttributeChangedSignal(name):Connect(requestSpectatorStream)
end
requestSpectatorStream()

local count=0
local function check(value,message) count+=1 assert(value,message) end
local function publish(target,revision,position)
 player:SetAttribute("RunnerSpectatePosition",position)
 player:SetAttribute("RunnerSpectateUserId",target and target.UserId or nil)
 player:SetAttribute("RunnerSpectateRevision",revision)
end
check(isSpectating(),"out during running")
publish(a,1,Vector3.new(100,5,1))
check(#queue==1,"stream worker scheduled")
refreshSpectatorTarget()
check(cameraTarget==a,"unstreamed rig still selected")
check(spectateName.Text=="LOADING Player2...","missing root loading label")
publish(b,2,Vector3.new(200,5,1))
publish(a,3,Vector3.new(300,5,1))
check(#queue==1,"switch burst single worker")
drain()
check(#calls==1 and calls[1].position==Vector3.new(300,5,1),"burst coalesces latest position")
check(calls[1].timeout==2,"request bounded two seconds")
requestSpectatorStream()
check(#queue==0,"same target revision not repeated")
onStream=function() publish(b,5,Vector3.new(500,5,1)) end
publish(a,4,Vector3.new(400,5,1))
drain()
check(#calls==3,"inflight change issues only latest followup")
check(calls[3].position==Vector3.new(500,5,1),"inflight follows latest target")
refreshSpectatorTarget()
check(cameraTarget==b,"confirmed target followed")
b.Character.HumanoidRootPart={}
refreshSpectatorTarget()
check(spectateName.Text=="Player3","loading label clears on root arrival")
chooseSpectatorTarget(1)
check(remotes[#remotes].action=="Spectate" and remotes[#remotes].id==2,"next wraps and sends id")
check(cameraTarget==b,"selection waits server confirmation")
chooseSpectatorTarget(-1)
check(remotes[#remotes].id==2,"previous target selection")
player:SetAttribute("RunnerSpectateUserId",nil)
chooseSpectatorTarget(-1)
check(remotes[#remotes].id==3,"previous from unset starts at last")
chooseSpectatorTarget(1)
check(remotes[#remotes].id==2,"next from unset starts at first")
publish(a,6,Vector3.new(600,5,1))
player:SetAttribute("RunnerStatus","Finished")
refreshSpectatorTarget()
check(cameraTarget==player,"finish VFX .8 second hold")
clock+=.79 refreshSpectatorTarget()
check(cameraTarget==player,"finish hold before deadline")
clock+=.02 refreshSpectatorTarget()
check(cameraTarget==a,"finish hold expires")
player:SetAttribute("RunnerStatus","Spectating")
refreshSpectatorTarget()
check(cameraTarget==a and spectate.Visible,"late arrival state enables controls")
player:SetAttribute("GBloxPodiumActive",true)
local previousCount=#calls
drain()
check(#calls==previousCount,"podium cancels queued prefetch")
check(not isSpectating(),"podium yields camera")
refreshSpectatorTarget()
check(not spectate.Visible,"podium hides spectate")
player:SetAttribute("GBloxPodiumActive",false)
player:SetAttribute("GBloxPodiumCameraActive",true)
check(not isSpectating(),"podium camera flag protected")
player:SetAttribute("GBloxPodiumCameraActive",false)
player:SetAttribute("RunnerStatus","Running")
check(not isSpectating(),"active racer excluded")
local before=#remotes chooseSpectatorTarget(1)
check(#remotes==before,"active racer sends no spectate requests")
player:SetAttribute("RunnerStatus","Out")
workspace:SetAttribute("RunnerRoundPhase","Intermission")
check(not isSpectating(),"non-running phase excluded")
workspace:SetAttribute("RunnerRoundPhase","Running")
publish(nil,7,nil)
refreshSpectatorTarget()
check(cameraTarget==player and spectateName.Text=="WAITING FOR NEXT ROUND","empty selection fallback")
player:SetAttribute("RunnerSpectateUserId",999)
refreshSpectatorTarget()
check(cameraTarget==player,"unknown target safe")
publish(a,8,Vector3.new(800,5,1))
a:SetAttribute("RunnerStatus","Finished")
refreshSpectatorTarget()
check(cameraTarget==player,"finished target no longer followed")
drain()
player:SetAttribute("RunnerSpectatePosition",nil)
player:SetAttribute("RunnerSpectateUserId",b.UserId)
player:SetAttribute("RunnerSpectateRevision",10)
check(#queue==0,"partial metadata waits for position")
player:SetAttribute("RunnerSpectatePosition",Vector3.new(900,5,1))
check(#queue==1,"late position schedules prefetch")
drain()
check(calls[#calls].position==Vector3.new(900,5,1),"late position prefetched")
return count

