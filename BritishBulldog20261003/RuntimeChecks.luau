local Service = require(game:GetService("ServerScriptService").BritishBulldogService)
local arena = workspace["British Bulldog game"]
local controller = Service.new(arena)
local testState = Instance.new("Folder")
testState.Name = "BritishBulldogTestState"
testState.Parent = game:GetService("ServerStorage")
controller.state = testState
controller:_collisionGroups()
controller.active = true
controller.running = true
controller.phase = "Crossing"
controller.source = "North"
controller.destination = "South"
controller.endsAt = workspace:GetServerTimeNow() + 180
local checks = {}
local rigs = Instance.new("Folder")
rigs.Name = "BritishBulldogRuntimeFixtures"
rigs.Parent = workspace
local function expect(condition, label)
 assert(condition, label)
 table.insert(checks, label)
end
local function position(x,z)
 return Vector3.new(4626+x,36.5,4534+z)
end
local function record(name, role, x,z,index)
 local attrs = {}
 local player = { DisplayName = name }
 function player:GetAttribute(key) return attrs[key] end
 function player:SetAttribute(key,value) attrs[key]=value end
 local char = Instance.new("Model")
 char.Name = name
 char.Parent = rigs
 local root = Instance.new("Part")
 root.Name = "HumanoidRootPart"
 root.Size = Vector3.new(2,2,1)
 root.CFrame = CFrame.new(position(x,z))
 root.CanQuery = false
 root.CanCollide = false
 root.Parent = char
 char.PrimaryPart = root
 local head = Instance.new("Part")
 head.Name = "Head"
 head.Size = Vector3.new(2,1,1)
 head.CFrame = root.CFrame + Vector3.new(0,2,0)
 head.CanQuery = false
 head.CanCollide = false
 head.Parent = char
 local weld = Instance.new("WeldConstraint")
 weld.Part0 = root
 weld.Part1 = head
 weld.Parent = root
 local hum = Instance.new("Humanoid")
 hum.RequiresNeck = false
 hum.Parent = char
 local r = {player=player,character=char,root=root,humanoid=hum,role=role,participating=true,ready=true,originalGroups={},connections={},characterConnections={},spawnIndex=index,arrived=false,departed=role=="Runner",frozen=false}
 player.Character=char
 controller.records[player]=r
 controller:_setRole(r,role)
 return r
end
local runner=record("FixtureRunner","Runner",0,0,1)
local bulldog=record("FixtureBulldog","Bulldog",3,0,2)
local ok,failure=xpcall(function()
 controller:_tick()
 expect(runner.role=="Tagged","Server proximity tag")
 expect(runner.frozen and runner.humanoid.WalkSpeed==0,"Tagged freezes movement")
 expect(runner.character:FindFirstChild("BBTaggedLabel")~=nil,"Editable overhead template cloned")
 local caughtAt=runner.root.Position
 controller:_finishCrossing()
 expect(runner.role=="Bulldog" and not runner.frozen,"Caught joins Bulldogs on transition")
 expect((runner.root.Position-caughtAt).Magnitude<0.01,"Conversion preserves legal tag position")
 expect(runner.humanoid.WalkSpeed==18,"Bulldog speed applied")
 expect(runner.character.BBOutline.OutlineColor==Color3.fromRGB(255,72,86),"Red Bulldog outline")
 controller.source="North" controller.destination="South"
 controller:_setRole(runner,"Runner")
 runner.pendingBulldog=false runner.arrived=false runner.departed=false
 controller:_teleport(runner,CFrame.new(position(0,-110)))
 controller:_teleport(bulldog,CFrame.new(position(0,-92)))
 controller:_departure(runner,true,workspace:GetServerTimeNow()+5)
 controller:_tick()
 expect(runner.role=="Runner" and runner.mustLeave,"Source safe zone cannot be tagged")
 controller:_teleport(runner,CFrame.new(position(20,-94)))
 controller:_tick()
 expect(runner.departed and not runner.mustLeave,"Leaving source cancels departure deadline")
 controller:_teleport(runner,CFrame.new(position(20,-110)))
 controller:_tick()
 expect(runner.root.Position.Z>4534-96,"Retreat cannot regain source immunity")
 controller:_teleport(runner,CFrame.new(position(20,100)))
 controller:_tick()
 expect(runner.arrived and runner.role=="Runner","Destination arrival remains safe")
 runner.arrived=false runner.departed=false
 controller:_teleport(runner,CFrame.new(position(0,-110)))
 controller:_departure(runner,true,workspace:GetServerTimeNow()-0.1)
 controller:_tick()
 expect(runner.role=="Bulldog" and runner.pendingBulldog and runner.frozen,"Expired departure converts and holds Bulldog")
 controller:_finishCrossing()
 expect(not runner.frozen and not runner.pendingBulldog,"Departure forfeiter releases next crossing")
 controller.source="North" controller.destination="South"
 controller:_setRole(runner,"Runner")
 runner.arrived=false runner.departed=false
 controller:_teleport(runner,CFrame.new(position(0,-110)))
 controller:_departure(runner,true,workspace:GetServerTimeNow()-0.1)
 controller.endsAt=workspace:GetServerTimeNow()-0.1
 controller:_tick()
 expect(runner.role=="Runner","Expiry prevents late forfeits")
 expect(controller:_outcome()=="Runners","Remaining runner wins at timeout")
 controller.endsAt=workspace:GetServerTimeNow()+180
 controller:_teleport(bulldog,CFrame.new(position(0,-120)))
 controller:_keepBulldogInField(bulldog)
 expect(bulldog.root.Position.Z>=4534-92,"Server corrects Bulldog safe-zone breach")
 expect(controller:_inField(position(111,0)),"Sideline runner remains eligible for tagging")
 local ray=RaycastParams.new()
 ray.RespectCanCollide=true
 ray.CollisionGroup="BBBulldog"
 local blocked=workspace:Raycast(position(80,-88),Vector3.new(0,0,-15),ray)
 expect(blocked and blocked.Instance.Name=="NorthBulldogBarrier","Physical barrier blocks Bulldog collision group")
 ray.CollisionGroup="BBRunner"
 expect(workspace:Raycast(position(80,-88),Vector3.new(0,0,-15),ray)==nil,"Physical barrier passes Runner collision group")
 controller:_restoreCharacter(runner)
 expect(runner.humanoid.WalkSpeed==16 and runner.root.CollisionGroup=="Default","Cleanup restores movement and collision group")
 expect(runner.character:FindFirstChild("BBOutline")==nil,"Cleanup removes role visuals")
end,debug.traceback)
controller.active=false
for _,r in pairs(controller.records) do controller:_restoreCharacter(r) end
rigs:Destroy()
testState:Destroy()
assert(ok,failure)
return {passed=#checks,checks=checks,fixtureType="server rigs and player adapters; not a multiplayer session"}
