return function(sources)
 local checks=0
 local function check(value,message)
  checks+=1
  assert(value,message)
 end
 local function signal()
  local s={listeners={}}
  function s:Connect(fn)
   local c={Connected=true}
   function c:Disconnect() self.Connected=false end
   table.insert(self.listeners,{connection=c,fn=fn})
   return c
  end
  function s:Fire(...)
   for _,entry in table.clone(self.listeners) do if entry.connection.Connected then entry.fn(...) end end
  end
  return s
 end
 local function run(source,values)
  local fn,err=loadstring(source)
  assert(fn,err)
  local env=setmetatable(values,{__index=getfenv()})
  setfenv(fn,env)
  fn()
 end

 local petSource=sources.PetFollower
 local renderStart=assert(petSource:find("RunService.RenderStepped",1,true))
 check(not petSource:sub(renderStart):find("GetDescendants",1,true),"No descendant traversal in pet frame loop")
 local world=Instance.new("Folder")
 local rs=Instance.new("Folder")
 local templates=Instance.new("Folder") templates.Name="GBloxPetTemplates" templates.Parent=rs
 local template=Instance.new("Model") template.Name="TestPet" template.Parent=templates
 local petRoot=Instance.new("Part") petRoot.Name="PetRoot" petRoot.Parent=template template.PrimaryPart=petRoot
 local wing=Instance.new("Part") wing.Name="Wing" wing.Parent=template
 local motor=Instance.new("Motor6D") motor.Name="WingMotor_L" motor.Part0=petRoot motor.Part1=wing motor:SetAttribute("GBloxWingSide","L") motor.Parent=petRoot
 local trail=Instance.new("Trail") trail.Name="GBloxVelocityTrail" trail.Enabled=true trail.Parent=petRoot
 local character=Instance.new("Model")
 local root=Instance.new("Part") root.Name="HumanoidRootPart" root.Parent=character
 local hum=Instance.new("Humanoid") hum.Parent=character
 local attrs={GBloxEquippedPet="TestPet",GBloxEquippedPet2="TestPet"}
 local attrSignals={}
 local player={Name="TestPlayer",Character=character,CharacterAdded=signal(),CharacterRemoving=signal()}
 function player:GetAttribute(name) return attrs[name] end
 function player:GetAttributeChangedSignal(name) attrSignals[name]=attrSignals[name] or signal() return attrSignals[name] end
 local players={PlayerAdded=signal(),PlayerRemoving=signal()}
 function players:GetPlayers() return {player} end
 local frames=signal()
 local services={Players=players,ReplicatedStorage=rs,RunService={RenderStepped=frames}}
 local fakeGame={}
 function fakeGame:GetService(name) return services[name] end
 local now=0
 local immediate={spawn=function(fn,...) fn(...) end,defer=function(fn,...) fn(...) end}
 local ok,err=pcall(function()
  run(petSource,{game=fakeGame,workspace=world,time=function() return now end,task=immediate})
  local folder=world:FindFirstChild("GBloxActivePets")
  check(folder~=nil and #folder:GetChildren()==2,"Two equipped pet slots spawn")
  frames:Fire(1/60)
  for _,model in folder:GetChildren() do check(not model.PetRoot.GBloxVelocityTrail.Enabled,"Trails idle on first frame") end
  root.CFrame=CFrame.new(100,0,0) now=.1 frames:Fire(.1)
  for _,model in folder:GetChildren() do
   check(model.PetRoot.GBloxVelocityTrail.Enabled,"Moving pets enable cached trails")
   check(model.PetRoot.WingMotor_L.Transform~=CFrame.identity,"Wing animation remains active")
  end
  for _=1,180 do now+=1/60 frames:Fire(1/60) end
  for _,model in folder:GetChildren() do check(not model.PetRoot.GBloxVelocityTrail.Enabled,"Settled pets disable trails") end
  check(trail.Enabled,"Source template is not modified")
  attrs.GBloxEquippedPet2=nil attrSignals.GBloxEquippedPet2:Fire()
  check(#folder:GetChildren()==1,"Unequipping second slot cleans old pets")
  local model=folder:GetChildren()[1]
  model.PetRoot.GBloxVelocityTrail:Destroy()
  root.CFrame=CFrame.new(200,0,0) now+=.1 frames:Fire(.1)
  check(model.Parent==folder,"Destroyed cached trail is safe")
  local old=model:GetPivot()
  hum.Health=0 now+=.1 frames:Fire(.1)
  check(model:GetPivot()==old,"Dead character pet animation remains paused")
  player.CharacterRemoving:Fire()
  check(#folder:GetChildren()==0,"Character removal destroys pet models")
  hum.Health=100 player.CharacterAdded:Fire(character)
  check(#folder:GetChildren()==1,"Respawn recreates equipped pet")
  players.PlayerRemoving:Fire(player)
  check(#folder:GetChildren()==0,"Player removal cleans pets")
 end)
 world:Destroy() rs:Destroy() character:Destroy()
 assert(ok,err)

 local function coinFixture()
  local frame,added,removed,destroying=signal(),signal(),signal(),signal()
  local connections=0
  local folder={children={},ChildAdded=added,ChildRemoved=removed,reads=0}
  function folder:GetChildren() self.reads+=1 return table.clone(self.children) end
  local function coin(name,position)
   local changed=signal()
   local c={Name=name,Parent=folder,CFrame=CFrame.new(position),attrs={RestCFrame=CFrame.new(position)},reads=0,changed=changed}
   function c:IsA(class) return class=="BasePart" end
   function c:GetAttribute(key) self.reads+=1 return self.attrs[key] end
   function c:GetAttributeChangedSignal() connections+=1 return changed end
   table.insert(folder.children,c)
   return c
  end
  local c1=coin("First",Vector3.zero)
  local r={Position=Vector3.zero}
  local char={FindFirstChild=function() return r end}
  local p={Character=char}
  local collected=signal()
  local ss={PlayLocalSound=function() end}
  local rsMock={WaitForChild=function() return {OnClientEvent=collected} end}
  local services={RunService={RenderStepped=frame},SoundService=ss}
  local g={Players={LocalPlayer=p},ReplicatedStorage=rsMock}
  function g:GetService(name) return services[name] end
  local w={WaitForChild=function() return folder end,GetServerTimeNow=function() return 1 end}
  run(sources.LobbyCoinEffects,{game=g,workspace=w,script={Destroying=destroying},Instance={new=function() return {} end}})
  check(folder.reads==1,"Visual cache discovers initial coin list once")
  local reads=c1.reads
  for _=1,120 do frame:Fire(1/60) end
  check(folder.reads==1 and c1.reads==reads,"Visual frames perform no child or attribute traversal")
  local expected=c1.attrs.RestCFrame*CFrame.new(0,math.sin(2.4)*.55,0)*CFrame.Angles(0,1.2,0)
  check(c1.CFrame==expected,"Cached visual uses original bob and spin formula")
  local c2=coin("StreamedIn",Vector3.new(10,0,0)) added:Fire(c2)
  frame:Fire(1/60)
  check(c2.CFrame~=c2.attrs.RestCFrame,"Streamed-in coin begins animating")
  c2.attrs.RestCFrame=CFrame.new(30,0,0) c2.changed:Fire() frame:Fire(1/60)
  check(math.abs(c2.CFrame.Position.X-30)<.001,"Server respawn RestCFrame update is respected")
  c2.Parent=nil removed:Fire(c2)
  local before=c2.CFrame frame:Fire(1/60)
  check(c2.CFrame==before and not c2.changed.listeners[1].connection.Connected,"Stream-out stops updates and disconnects attribute listener")
  c2.Parent=folder added:Fire(c2) added:Fire(c2)
  check(connections==3,"Stream-in rebinds once; duplicate add is ignored")
  r.Position=Vector3.new(1000,0,0) before=c1.CFrame frame:Fire(1/60)
  check(c1.CFrame==before,"Existing 180-stud distance cull is preserved")
  p.Character=nil frame:Fire(1/60)
  check(c1.CFrame==before,"Missing character is safe")
  destroying:Fire()
  check(not frame.listeners[1].connection.Connected and not added.listeners[1].connection.Connected and not removed.listeners[1].connection.Connected,"Script cleanup disconnects cache and frame signals")
  check(not c1.changed.listeners[1].connection.Connected and not c2.changed.listeners[2].connection.Connected,"Script cleanup disconnects all coin listeners")
 end
 coinFixture()

 local function collectionFixture(options)
  options=options or {}
  local heartbeat=signal()
  local callbacks={}
  local players={calls=0,list={}}
  function players:GetPlayers() self.calls+=1 return self.list end
  local folder={children={}}
  function folder:GetChildren() return self.children end
  local floor={CFrame=CFrame.identity,Size=Vector3.new(200,1,200)}
  for i=1,3 do
   local coin={Name="Coin"..i,Position=Vector3.zero,CFrame=CFrame.identity,Parent=folder,Transparency=0}
   function coin:IsA(class) return class=="BasePart" end
   function coin:GetAttribute() return 10 end
   function coin:SetAttribute(name,value) self[name]=value end
   table.insert(folder.children,coin)
  end
  local records={}
  for i=1,2 do
   local character={}
   local root={Position=Vector3.zero,Parent=character}
   local hum={Health=100,Parent=character}
   function root:IsDescendantOf(other) return self.Parent==other end
   function hum:IsDescendantOf(other) return self.Parent==other end
   function character:FindFirstChild() return root end
   function character:FindFirstChildOfClass() return hum end
   local player={Name="Player"..i,Character=character,Parent=players,ready=true}
   function player:GetAttribute() return self.ready end
   table.insert(players.list,player)
   table.insert(records,{player=player,root=root,hum=hum,character=character})
  end
  if options.unready then records[1].player.ready=false end
  if options.dead then records[1].hum.Health=0 end
  local awards,events={},{}
  local data={}
  function data.AddEarnedCash(player,amount)
   if options.fail then return nil end
   table.insert(awards,{player=player,amount=amount})
   if #awards==1 and options.depart then player.Parent=nil end
   if #awards==1 and options.respawn then
    player.Character={FindFirstChild=function() return nil end,FindFirstChildOfClass=function() return nil end}
   end
   if #awards==1 and options.loseReady then player.ready=false end
   return 10,amount*2
  end
  local remote={FireClient=function(_,player,amount) table.insert(events,{player=player,amount=amount}) end}
  local g={ReplicatedStorage={WaitForChild=function() return remote end}}
  function g:GetService(name) return name=="Players" and players or {Heartbeat=heartbeat} end
  local w={}
  function w:WaitForChild(name) return name=="LobbyCoins" and folder or {WaitForChild=function() return floor end} end
  function w:FindFirstChild() return nil end
  function w:GetPartBoundsInBox() return options.noDestination and {true} or {} end
  function w:Raycast() return options.blocked and {} or nil end
  local scriptMock={Parent={WaitForChild=function() return data end}}
  run(sources.LobbyCoins,{game=g,workspace=w,script=scriptMock,require=function(value) return value end,
   Random={new=function() return {NextNumber=function() return 20 end} end},
   OverlapParams={new=function() return {} end},RaycastParams={new=function() return {} end},
   task={delay=function(_,fn) table.insert(callbacks,fn) end}})
  heartbeat:Fire(.01)
  check(players.calls==0,"Collection cadence is unchanged")
  heartbeat:Fire(.12)
  check(players.calls==1,"Exactly one player snapshot per collection tick")
  if options.fail or options.blocked or options.noDestination then
   check(#awards==0 and #events==0 and #callbacks==0,"Failed, blocked, or unplaceable coins never award or respawn")
   check(folder.children[1].Transparency==0,"Unawarded coin stays visible")
  else
   check(#awards==3 and #events==3 and #callbacks==3,"Each coin grants once and queues one respawn")
   for i=1,3 do check(events[i].amount==20,"Awarded multiplier result is forwarded") end
   local expectedFirst=(options.dead or options.unready) and records[2].player or records[1].player
   check(awards[1].player==expectedFirst,"Initial eligibility filtering preserves player order")
   if options.depart or options.respawn or options.loseReady then check(awards[2].player==records[2].player,"Stale snapshot entries cannot receive later coins") end
   heartbeat:Fire(.12)
   check(#awards==3,"Busy coins cannot award twice before respawn")
   for _,fn in callbacks do fn() end
   check(folder.children[1].Transparency==0 and typeof(folder.children[1].RestCFrame)=="CFrame","Original delayed respawn and rest frame update remain")
  end
 end
 for _,options in {{},{depart=true},{respawn=true},{loseReady=true},{unready=true},{dead=true},{fail=true},{blocked=true},{noDestination=true}} do collectionFixture(options) end
 return {passed=checks,scope="Isolated mocks and detached pet instances; no live balances, scripts, or Workspace objects changed"}
end
