assert(not game:GetService("RunService"):IsRunning(),"Edit only")
local report={checks={},errors={}}
local function check(name,condition) table.insert(report.checks,{name=name,passed=not not condition})assert(condition,name)end
local world=Instance.new("Folder")world.Name,world.Parent="LaserTagNativeFixture20261013",workspace
local now,roster=100,{}
local function signal()return{Connect=function()return{Disconnect=function()end}end}end
local players={PlayerAdded=signal(),PlayerRemoving=signal()}
function players:GetPlayers()return roster end
local virtualWorld=setmetatable({GetServerTimeNow=function()return now end},{__index=function(_,key)
 local value=workspace[key]if typeof(value)=="function"then return function(_,...)return value(workspace,...)end end return value
end})
local env={game={GetService=function(_,name)if name=="Players"then return players elseif name=="RunService"then return{Heartbeat=signal()}else return game:GetService(name)end end},
 workspace=virtualWorld,task=task,typeof=function(value)return type(value)=="table"and value.fixturePlayer and "Instance"or typeof(value)end}
local Service=require(game.ServerStorage.LaserTagNativeCandidate20261013)(env)
local services={}
local function part(parent,name,pos,size)
 local p=Instance.new("Part")p.Name,p.Position,p.Size=name,pos,size or Vector3.one
 p.Anchored,p.CanCollide,p.CanQuery=true,true,true p.Parent=parent return p
end
local origin=Vector3.new(-28000,2000,-23000)
local arena=Instance.new("Folder")arena.Name,arena.Parent="LaserArenaFixture",world
local gp=Instance.new("Folder")gp.Name,gp.Parent="Gameplay",arena
local bounds=part(gp,"ArenaBounds",origin,Vector3.new(400,100,400))bounds.CanQuery,bounds.CanCollide=false,false
local starts=Instance.new("Folder")starts.Name,starts.Parent="StartPads",gp
part(starts,"01",origin+Vector3.new(-40,0,20))
part(starts,"02",origin+Vector3.new(40,0,-20))
local spectator=Instance.new("Folder")spectator.Name,spectator.Parent="SpectatorSpawns",gp
for i=1,8 do local p=part(spectator,string.format("%02d",i),origin+Vector3.new(i*5,0,230))p.CanCollide,p.CanQuery=false,false end
arena:SetAttribute("FloorY",origin.Y-4)arena:SetAttribute("CountdownSeconds",3)arena:SetAttribute("ResultsSeconds",0)
local state=Instance.new("Folder")state.Parent=world
local service=Service.new(arena,state)table.insert(services,service)service.running=true
service._driveBots=function()end
service.effects=Instance.new("Folder")service.effects.Parent=world
local serial=0
local function makePlayer(rig,pos)
 serial+=1
 local p={fixturePlayer=true,UserId=984000+serial,Name="LaserFixture"..serial,DisplayName="Fixture "..serial,Parent=players,CharacterAdded=signal(),CharacterRemoving=signal(),ChildAdded=signal(),attributes={PCDataReady=true}}
 function p:IsA(name)return name=="Player"end
 function p:GetAttribute(name)return self.attributes[name]end
 function p:SetAttribute(name,value)self.attributes[name]=value end
 function p:GetAttributeChangedSignal()return signal()end
 function p:FindFirstChild(name)return name=="Backpack"and self.backpack or name=="StarterGear"and self.starterGear end
 function p:GetChildren()return{self.backpack,self.starterGear}end
 p.backpack=Instance.new("Backpack")p.backpack.Parent=world
 p.starterGear=Instance.new("Folder")p.starterGear.Name,p.starterGear.Parent="StarterGear",world
 local character=game.ServerStorage.WeaponRigFixtures[rig]:Clone()
 for _,x in ipairs(character:GetDescendants())do if x:IsA("LuaSourceContainer")then x:Destroy()elseif x:IsA("BasePart")then x.Anchored=true end end
 character.Name,character.Parent=p.Name,world
 character:PivotTo(CFrame.new(pos)*character.HumanoidRootPart.CFrame:Inverse()*character:GetPivot())
 local accessory=Instance.new("Accessory")accessory.Name,accessory.Parent="NativeAuditHat",character
 local audio=Instance.new("AudioEmitter")audio.Name,audio.Parent="NativeAuditAudio",character
 p.Character=character
 table.insert(roster,p)
 local record=service:_record(p,false)service:_setupCharacter(record,character)
 return p,record
end
local function move(record,pos)
 service:_teleport(record,CFrame.new(pos))
 record.lastGoodCFrame=record.root.CFrame
end
local function prepareGun(record)
 local tool=record.character:FindFirstChildOfClass("Tool") or record.managedTools[1]
 assert(tool,"No team gun issued")
 if tool.Parent~=record.character then tool.Parent=record.character end
 for _,x in ipairs(record.character:GetDescendants()) do
  if (x:IsA("Weld") or x:IsA("Motor6D") or x:IsA("WeldConstraint")) and ((x.Part0 and x.Part0:IsDescendantOf(tool)) or (x.Part1 and x.Part1:IsDescendantOf(tool))) then x:Destroy() end
 end
 local handle=tool.Handle
 local transform=CFrame.new(record.root.Position+Vector3.new(1,0,-1))*handle.CFrame:Inverse()
 for _,x in ipairs(tool:GetDescendants())do if x:IsA("BasePart")then x.CFrame=transform*x.CFrame x.CanQuery=false end end
 return tool
end
local function aim(record,target)
 local camera=record.character.Head.Position+Vector3.new(0,0,10)
 return{cameraOrigin=camera,cameraDirection=(target-camera).Unit}
end
local function playing(list,teams)
 service:StopRound()
 service:_begin(list,"Round",teams)
 now=service.countdownEndsAt service:_tick(0)
 check("Countdown enters fixed five minute game",service.phase=="Playing"and service.endsAt-now==300)
end
local function flushShots()
 for _,shot in ipairs(service.projectiles)do if shot.part.Parent then shot.part:Destroy()end end table.clear(service.projectiles)
end
local ok,failure=xpcall(function()
 for count=2,60 do
  local assignment,teamCount=Service.TeamAssignments(count,12,2)
  local counts={0,0}
  for _,team in ipairs(assignment)do counts[team]+=1 end
  check("Two balanced teams at population "..count,teamCount==2 and #assignment==count and math.abs(counts[1]-counts[2])<=1)
 end
 local assigned=Service.TeamAssignments(80)
 check("Team assignments stop at server maximum",#assigned==60)
 local w=Service.ChooseTimeoutTeams({1,2},{3,2},{3,6})
 check("Timeout prioritizes surviving players",#w==1 and w[1]==1)
 w=Service.ChooseTimeoutTeams({1,2},{2,2},{3,5})
 check("Timeout uses remaining hearts as tie break",#w==1 and w[1]==2)
 w=Service.ChooseTimeoutTeams({1,2},{2,2},{4,4})
 check("Exact timeout tie shares win",#w==2)
 local a,ar=makePlayer("R15",origin)
 local b,br=makePlayer("R6",origin+Vector3.new(0,0,-30))
 local c,cr=makePlayer("R6",origin+Vector3.new(40,0,0))
 local d,dr=makePlayer("R15",origin+Vector3.new(40,0,-30))
 check("Normal minimum is two",not service:StartRound({a}))
 a:SetAttribute("PCAFK",true)check("AFK is excluded",#service:_readyPlayers({a,b})==1)a:SetAttribute("PCAFK",false)
 a:SetAttribute("PCDataReady",false)check("Unloaded profile excluded",#service:_readyPlayers({a,b})==1)a:SetAttribute("PCDataReady",true)
 a:SetAttribute("HSParticipating",true)check("Another game excluded",#service:_readyPlayers({a,b})==1)a:SetAttribute("HSParticipating",false)
 check("Duplicate players excluded",#service:_readyPlayers({a,a,b})==2)
 playing({a,b,c,d},{1,2,1,2})
 move(ar,origin)move(br,origin+Vector3.new(0,0,-30))
 move(cr,origin+Vector3.new(40,0,0))move(dr,origin+Vector3.new(40,0,-30))
 local red=prepareGun(ar)local blue=prepareGun(br)prepareGun(cr)prepareGun(dr)
 check("Red team has only HeatGun",red.Name=="HeatGun"and #ar.managedTools==1)
 check("Blue team has only MudGun",blue.Name=="MudGun"and #br.managedTools==1)
 check("Players start with three hearts",a:GetAttribute("MDLives")==3 and b:GetAttribute("MDLives")==3)
 local gui=ar.character:FindFirstChild("MDLivesDisplay")
 check("Editable three hearts overhead cloned",gui and gui:FindFirstChild("Heart1")and gui:FindFirstChild("Heart2")and gui:FindFirstChild("Heart3"))
 check("Avatar hat and audio preserved",ar.character:FindFirstChild("NativeAuditHat")and ar.character:FindFirstChild("NativeAuditAudio"))
 local target=br.character:FindFirstChild("Torso")or br.character:FindFirstChild("UpperTorso")
 local packet=aim(ar,target.Position)
 local direction,muzzle=service:_resolveAim(ar,"Heat",packet)
 check("Camera aim resolves red gun to enemy",direction~=nil and muzzle~=nil)
 check("Vector legacy aim still accepted",service:_resolveAim(ar,"Heat",Vector3.new(0,0,-1))~=nil)
 check("Wrong team gun denied",service:_equipped(ar,"Mud")==nil)
 check("Other team equip denied",not service:_action(ar,"Equip","MudGun").ok)
 now+=0.1 check("Assigned gun re-equip accepted",service:_action(ar,"Equip","HeatGun").ok)
 check("Outsider remote rejected",not service:Action(makePlayer("R6",origin+Vector3.new(100,0,80)),"Fire",packet).ok)
 check("Forged non-player rejected",not service:Action({},"Fire",packet).ok)
 check("Unknown and removed colour actions denied",not service:_action(ar,"ChooseColor","Green").ok and not service:_action(ar,"Heat",true,packet).ok)
 check("Red laser fire accepted",service:Action(a,"Fire",packet).ok)
 local shot=service.projectiles[1]
 check("Small rectangular red pulse",shot and shot.part.Shape==Enum.PartType.Block and shot.part.Size==Vector3.new(0.32,0.32,2.4) and shot.part:GetAttribute("MDTeamId")==1)
 check("Shot begins before hitting enemy",br.lives==3)
 check("Cooldown rejects rapid repeat",not service:_fire(ar,packet,now+0.01))
 service:_tickProjectiles(0.05)
 check("Laser travels at finite speed",br.lives==3 and #service.projectiles==1)
 for _=1,10 do service:_tickProjectiles(0.05)end
 check("Red swept pulse removes exactly one blue heart",br.lives==2 and b:GetAttribute("MDLives")==2 and #service.projectiles==0)
 check("First hit never freezes or muddies",not br.frozen and not br.muddy and b:GetAttribute("MDMuddy")==false)
 check("Health display empties one heart",br.character.MDLivesDisplay.Heart3.Text=="♡")
 check("Friendly hit denied",not service:_laserHit(cr,ar)and cr.lives==3)
 check("Self hit denied",not service:_laserHit(ar,ar)and ar.lives==3)
 check("Far forged camera denied",service:_resolveAim(ar,"Heat",{cameraOrigin=origin+Vector3.new(500,0,0),cameraDirection=Vector3.new(0,0,-1)})==nil)
 check("NaN direction denied",service:_resolveAim(ar,"Heat",{cameraOrigin=packet.cameraOrigin,cameraDirection=Vector3.new(0/0,0,-1)})==nil)
 check("Infinite camera denied",service:_resolveAim(ar,"Heat",{cameraOrigin=Vector3.new(math.huge,0,0),cameraDirection=Vector3.new(0,0,-1)})==nil)
 check("Zero direction denied",service:_resolveAim(ar,"Heat",Vector3.zero)==nil)
 local wall=part(world,"CameraWall",ar.character.Head.Position+Vector3.new(0,0,5),Vector3.new(20,15,1))
 check("Camera cannot aim through rear wall",service:_resolveAim(ar,"Heat",packet)==nil)wall:Destroy()
 wall=part(world,"MuzzleWall",ar.root.Position+Vector3.new(0.5,0.5,-1),Vector3.new(0.3,8,4))
 check("Gun muzzle cannot protrude through cover",service:_resolveAim(ar,"Heat",packet)==nil)wall:Destroy()
 local oldMuzzle=red.Handle.MuzzleAttachment.Position
 red.Handle.MuzzleAttachment.Position=Vector3.new(0,0,-50)
 check("Displaced muzzle denied",service:_resolveAim(ar,"Heat",packet)==nil)red.Handle.MuzzleAttachment.Position=oldMuzzle
 red:SetAttribute("MDOwnerUserId",0)check("Foreign gun denied",not service:_fire(ar,packet,now+2))red:SetAttribute("MDOwnerUserId",a.UserId)
 red:SetAttribute("MDRound",0)check("Old round gun denied",not service:_fire(ar,packet,now+2))red:SetAttribute("MDRound",service.roundNumber)
 red:SetAttribute("MDTeamId",2)check("Other team gun denied",not service:_fire(ar,packet,now+2))red:SetAttribute("MDTeamId",1)
 wall=part(world,"ShotWall",origin+Vector3.new(0,0,-16),Vector3.new(20,20,1))
 now+=1
 check("Firing toward a wall allowed",service:_fire(ar,packet,now))
 for _=1,10 do service:_tickProjectiles(0.05)end
 check("Wall blocks pulse before enemy",br.lives==2 and #service.projectiles==0)wall:Destroy()
 local redTarget=ar.character:FindFirstChild("UpperTorso")
 check("Blue gun also fires",service:_fire(br,aim(br,redTarget.Position),now))
 check("Blue pulse colour and team",service.projectiles[1]and service.projectiles[1].teamId==2 and service.projectiles[1].part.Color==Color3.fromRGB(65,165,255))
 for _=1,10 do service:_tickProjectiles(0.05)end
 check("Blue pulse damages red enemy",ar.lives==2)
 check("Second enemy hit leaves one heart",service:_laserHit(br,ar)and br.lives==1 and not br.eliminated)
 check("Third enemy hit eliminates",service:_laserHit(br,ar)and br.lives==0 and br.eliminated)
 check("Eliminated remains round member and cannot fire",b:GetAttribute("MDParticipating")==true and b:GetAttribute("MDEliminated")==true and not service:_fire(br,packet,now+2))
 check("Eliminated gun removed",not br.character:FindFirstChildOfClass("Tool")and #br.managedTools==0)
 check("Eliminated moved outside combat bounds",br.root.Position.Z>origin.Z+200)
 check("No post elimination damage",not service:_laserHit(br,ar))
 move(br,origin+Vector3.new(0,0,-20))service:_keepLegal(br)
 check("Eliminated cannot reenter arena",br.root.Position.Z>origin.Z+200)
 local replacement=game.ServerStorage.WeaponRigFixtures.R6:Clone()
 for _,x in ipairs(replacement:GetDescendants())do if x:IsA("LuaSourceContainer")then x:Destroy()end end
 replacement.Parent=world b.Character=replacement service:_setupCharacter(br,replacement)
 check("Respawn stays out with zero lives",br.eliminated and br.lives==0 and not br.character:FindFirstChildOfClass("Tool")and br.root.Position.Z>origin.Z+200)
 ar.sprintHeld=true ar.sprintLeaseEndsAt=now+1 ar.sprintRemaining=0 ar.root.AssemblyLinearVelocity=Vector3.new(2,0,0)
 service:_tickSprint(ar,0.1,now)
 check("Sprint recharges from zero",ar.sprintRemaining>0)
 service:_tickSprint(ar,0.01,now)
 check("Partial recharge can sprint immediately",ar.sprinting and ar.humanoid.WalkSpeed>16)
 ar.root.AssemblyLinearVelocity=Vector3.zero
 service:_laserHit(dr,ar)service:_laserHit(dr,ar)service:_laserHit(dr,ar)
 service:_tick(0)
 check("Last team standing ends round",service.phase=="Results"and state:GetAttribute("WinnerTeamIds")=="1"and state:GetAttribute("ResultReason")=="LastTeamStanding")
 check("Normal round produces reward eligible result",state:GetAttribute("LastResultPractice")==false and #string.split(state:GetAttribute("LastResultParticipantIds"),",")==4)
 service:_tick(0)
 check("Cleanup removes participation lives and GUI",not a:GetAttribute("MDParticipating")and a:GetAttribute("MDLives")==0 and not ar.character:FindFirstChild("MDLivesDisplay"))
 check("Cleanup restores normal movement",ar.humanoid.WalkSpeed==16)
 check("Team modes reset after round",state:GetAttribute("Mode")=="Waiting")
 check("Normal two player start works",service:StartRound({a,c}))
 check("Team split stays red blue",ar.teamId~=cr.teamId and math.min(ar.teamId,cr.teamId)==1 and math.max(ar.teamId,cr.teamId)==2)
 service:StopRound()
 check("Stop cancels rewards",state:GetAttribute("LastResultPractice")==true and state:GetAttribute("LastResultWinnerIds")=="")
 for _,role in ipairs({"Red","Blue","Shooter","Medic"})do
  service.botFolder=Instance.new("Folder")service.botFolder.Parent=world
  check("Practice starts "..role,service:StartPractice(a,role))
  local expected=(role=="Red"or role=="Shooter")and 1 or 2
  check("Practice team maps correctly "..role,ar.teamId==expected and prepareGun(ar).Name==(expected==1 and "HeatGun"or "MudGun"))
  now=service.countdownEndsAt service:_tick(0)
  now=service.endsAt service:_tick(0)
  check("Practice excludes rewards "..role,state:GetAttribute("LastResultPractice")==true and service.phase=="Results")
  service:StopRound()
 end
 check("Practice bots cleaned up",service.botFolder==nil)
 check("Live originals untouched",game.ReplicatedStorage.MudAssets.HeatGun.Parent==game.ReplicatedStorage.MudAssets)
end,debug.traceback)
if not ok then table.insert(report.errors,failure)end
pcall(function()service:Stop()end)
world:Destroy()
report.passed,report.checkCount=ok,#report.checks
return game.HttpService:JSONEncode(report)