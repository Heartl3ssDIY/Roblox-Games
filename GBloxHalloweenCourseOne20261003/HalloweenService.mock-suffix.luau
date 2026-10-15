end)()

local checks=0
local function expect(condition,message)
 assert(condition,message)
 checks+=1
end
local theme=Instance.new("Folder")
theme.Name="GBloxCourseTheme"
theme:SetAttribute("ActiveTheme","Halloween")
theme.Parent=ReplicatedStorage
local templates=Instance.new("Folder")
for _,name in {"Ghost","Trap_Web","Throwable_Pumpkin","Zombie_Hand"} do
 local model=Instance.new("Model") model.Name=name
 local part=Instance.new("Part") part.Name=name=="Zombie_Hand" and "Halloween_Palm" or "Artwork" part.Parent=model
 model.Parent=templates
end
local settings=Instance.new("Folder")
for name,value in Subject.Defaults do settings:SetAttribute(name,value) end
local course=Instance.new("Model") course.Name="Course1" course.Parent=Workspace
local support=Instance.new("Part") support.Name="Flat_Platform_RunSurface" support.Size=Vector3.new(200,2,20) support.Parent=course
currentSupport=support
local gameplay=Instance.new("Folder") gameplay.Name="HalloweenGameplay" gameplay.Parent=course
local trapFolder=Instance.new("Folder") trapFolder.Name="Traps" trapFolder.Parent=gameplay
local grave=Instance.new("Model") grave.Name="Grave" grave:SetAttribute("TrapType","Grave") grave:SetAttribute("SurfaceNormalY",1)
local sensor=Instance.new("Part") sensor.Name="Sensor" sensor.Size=Vector3.new(7,6,7) sensor.CFrame=CFrame.new(50,3,0) sensor.Parent=grave
local reference=Instance.new("ObjectValue") reference.Name="Support" reference.Value=support reference.Parent=grave
grave.Parent=trapFolder

local runners={}
local function player(id,x,z)
 local p=Instance.new("Player") p.UserId=id p.Parent=Players
 local character=Instance.new("Model") character.Parent=Workspace p.Character=character
 local root=Instance.new("Part") root.Size=Vector3.new(2,6,1.5) root.CFrame=CFrame.new(x,3,z or 0) root.AssemblyLinearVelocity=Vector3.zero root.Anchored=false root.Parent=character
 local data={player=p,character=character,root=root,collider=root,humanoid={Health=100},status="Running",gravitySign=1,courseVersion=1}
 runners[p]=data
 return p,data
end
local owner,ownerData=player(1,0)
local victimA,aData=player(2,2,1)
local victimB,bData=player(3,2,-1)
local now,round,courseNumber,phase=0,1,1,"Running"
local frozen,eliminated,packets={},{},{}
local service
service=Subject.new({
 Runners=runners,Settings=settings,Templates=templates,
 Now=function() return now end,RoundKey=function() return round end,CourseNumber=function() return courseNumber end,
 Phase=function() return phase end,Course=function() return course end,
 Progress=function(data) return -data.root.Position.X/100 end,
 Freeze=function(p,seconds)
  frozen[p]=now+seconds runners[p].freezeUntil=now+seconds runners[p].root.Anchored=true
  return now+seconds
 end,
 ClearFreeze=function(p)
  frozen[p]=nil
  local data=runners[p]
  if data then data.freezeUntil=nil data.root.Anchored=false end
 end,
 Eliminate=function(p,reason)
  table.insert(eliminated,{player=p,reason=reason}) runners[p].status="Out" service:Remove(p)
 end,
 Send=function(p,action,payload) table.insert(packets,{player=p,action=action,payload=payload}) end,
 Broadcast=function(action,payload) table.insert(packets,{action=action,payload=payload}) end,
 IsPlatform=function(part) return part==support end,
})
local function step(seconds)
 local remaining=seconds
 while remaining>0.0001 do local dt=math.min(0.1,remaining) now+=dt service:Step(dt) remaining-=dt end
end
service:Step(.1)
local ok,_,untilTime=service:Activate(owner,"Web")
expect(ok and untilTime==30,"Web activates with 30-second cooldown")
step(.1)
expect(not frozen[owner],"Web owner is immune")
expect(frozen[victimA] and frozen[victimB],"A web freezes multiple other racers")
expect(math.abs(frozen[victimA]-(now+5))<.001,"Web freeze is five seconds")
expect(owner:GetAttribute("GBloxHalloweenWebCooldownUntil")==30,"Cooldown attribute uses server clock")
step(5.1)
expect(not frozen[victimA] and not frozen[victimB],"Web victims are released")
step(.2)
expect(not frozen[victimA],"Same web cannot retrap its victim")
service:Remove(owner)
step(.2)
ok,_,untilTime=service:Activate(owner,"Web")
expect(not ok and untilTime==30,"Recovery/Remove cannot bypass cooldown")
service:Clear()
expect(not owner:GetAttribute("GBloxHalloweenWebCooldownUntil"),"Clear removes seasonal cooldowns")
theme:SetAttribute("ActiveTheme","Normal")
service:Step(.1)
ok=service:Activate(owner,"Web")
expect(not ok,"Normal theme gates abilities")
theme:SetAttribute("ActiveTheme","Halloween") courseNumber=2
service:Step(.1)
ok=service:Activate(owner,"Web")
expect(not ok,"Course two gates abilities")

courseNumber=1 round+=1
for _,data in runners do data.courseVersion=round data.status="Running" data.root.Anchored=false end
aData.root.CFrame=CFrame.new(50,3,0)
aData.root.AssemblyLinearVelocity=Vector3.new(-20,0,0)
service:Step(.1)
step(1.2)
expect(not aData.freezeUntil,"Passing through a grave does not capture")
aData.root.AssemblyLinearVelocity=Vector3.zero
step(1.2)
expect(aData.freezeUntil and victimA:GetAttribute("GBloxHalloweenGraveUntil"),"One stationary second starts grave capture")
local graveEnds=victimA:GetAttribute("GBloxHalloweenGraveUntil")
step(4.5)
expect(aData.status=="Running","Grave holds for five seconds before elimination")
step(math.max(0,graveEnds-now)+.2)
expect(aData.status=="Out" and #eliminated==1,"Grave eliminates directly at end of hold")
expect(not frozen[victimA] and not victimA:GetAttribute("GBloxHalloweenGraveUntil"),"Terminal grave cleanup releases seasonal hold")

service:Clear() round+=1
settings:SetAttribute("GhostInitialDelay",2)
settings:SetAttribute("GhostBaseSpeed",24)
settings:SetAttribute("GhostSpawnBehind",22)
ownerData.courseVersion=round ownerData.root.CFrame=CFrame.new(10,3,0) ownerData.status="Running"
bData.courseVersion=round bData.root.CFrame=CFrame.new(0,3,0) bData.status="Running"
aData.status="Out"
service:Step(.1)
step(2.3)
local runtime=Workspace:FindFirstChild("GBloxHalloweenRuntime")
local ghost=runtime and runtime:FindFirstChild("LastPlaceGhost")
expect(ghost and ghost:GetAttribute("TargetUserId")==owner.UserId,"Ghost chooses last-progress racer")
ownerData.root.CFrame=CFrame.new(-20,3,0)
step(.1)
ghost=runtime:FindFirstChild("LastPlaceGhost")
expect(ghost and ghost:GetAttribute("TargetUserId")==victimB.UserId,"Ghost switches target after overtaking")
step(2)
expect(#eliminated==2 and bData.status=="Out","Ghost catches exactly one racer")
step(3)
expect(#eliminated==2 and ownerData.status=="Running","Ghost stops eating after its first victim")
theme:SetAttribute("ActiveTheme","Normal") service:Step(.1)
theme:SetAttribute("ActiveTheme","Halloween") service:Step(.1)
step(5)
expect(#eliminated==2,"Theme toggling cannot grant another ghost elimination in same course version")

service:Clear() round+=1
settings:SetAttribute("GhostInitialDelay",30)
ownerData.courseVersion=round ownerData.status="Running" ownerData.root.CFrame=CFrame.new(10,3,0)
bData.courseVersion=round bData.status="Running" bData.root.CFrame=CFrame.new(0,3,0)
service:Step(.1)
ok,_,untilTime=service:Activate(owner,"Pumpkin")
expect(ok and math.abs(untilTime-(now+10))<.001,"Pumpkin has configurable provisional 10-second cooldown")
step(.3)
local splat
for _,packet in packets do if packet.action=="PumpkinSplat" then splat=packet end end
expect(splat and splat.player==victimB and splat.payload.duration==3 and splat.payload.roundKey==round,"Pumpkin hits ahead target with versioned three-second splat")
expect(not bData.freezeUntil and not bData.root.Anchored,"Pumpkin obscures view without immobilizing")

service:Clear()
expect(not Workspace:FindFirstChild("GBloxHalloweenRuntime"),"Clear destroys runtime visuals")
expect(not owner:GetAttribute("GBloxHalloweenPumpkinCooldownUntil"),"Clear removes pumpkin cooldown attribute")

round+=1
ownerData.courseVersion=round ownerData.status="Running" ownerData.gravitySign=-1 ownerData.root.CFrame=CFrame.new(10,-3,0)
bData.courseVersion=round bData.status="Running" bData.gravitySign=-1 bData.root.CFrame=CFrame.new(12,-3,0)
service:Step(.1)
ok=service:Activate(owner,"Web")
expect(ok,"Upside-down runner can place a web on ceiling support")
step(.2)
expect(frozen[victimB] and not frozen[owner],"Ceiling web traps another inverted runner but not owner")
service:Remove(victimB)
expect(not frozen[victimB] and not victimB:GetAttribute("GBloxHalloweenTrappedUntil"),"Recovery/Remove cancels an active seasonal freeze")
service:Clear()

round+=1
settings:SetAttribute("GhostInitialDelay",2) settings:SetAttribute("GhostSpawnBehind",50)
ownerData.courseVersion=round ownerData.gravitySign=1 ownerData.root.CFrame=CFrame.new(10,3,0)
bData.courseVersion=round bData.gravitySign=1 bData.root.CFrame=CFrame.new(-100,3,0)
service:Step(.1)
step(2.3)
runtime=Workspace:FindFirstChild("GBloxHalloweenRuntime") ghost=runtime:FindFirstChild("LastPlaceGhost")
expect(ghost and ghost:GetAttribute("Speed")==24,"Ghost starts at configurable base speed")
step(1.1)
ghost=runtime:FindFirstChild("LastPlaceGhost")
expect(ghost and math.abs(ghost:GetAttribute("Speed")-25.1)<.001,"Ghost increases 1.1 studs per second after each 1.1-second interval")
service:Clear()
print("HalloweenService isolated behavior checks passed: "..checks)
