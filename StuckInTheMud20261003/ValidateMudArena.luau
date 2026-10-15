local arena=assert(workspace:FindFirstChild("Stuck in the Mud"),"Mud school playground missing")
local geometry=assert(arena:FindFirstChild("Geometry"),"Mud geometry missing")
local gameplay=assert(arena:FindFirstChild("Gameplay"),"Mud gameplay folder missing")
local bounds=assert(gameplay:FindFirstChild("ArenaBounds"),"Mud bounds missing")
local nav=assert(gameplay:FindFirstChild("NavigationNodes"),"Mud navigation missing")
local starts=assert(gameplay:FindFirstChild("StartPads"),"Mud starting pads missing")
local teams=assert(gameplay:FindFirstChild("TeamSpawns"),"Mud team spawn groups missing")
local practice=assert(gameplay:FindFirstChild("PracticeSpawns"),"Mud practice pads missing")
local floorY=arena:GetAttribute("FloorY")
local checks=0
local function check(condition,message) assert(condition,message) checks+=1 end
local ray=RaycastParams.new()
ray.FilterType=Enum.RaycastFilterType.Include ray.FilterDescendantsInstances={geometry}
ray.RespectCanCollide=true
local overlap=OverlapParams.new()
overlap.FilterType=Enum.RaycastFilterType.Include overlap.FilterDescendantsInstances={geometry}
overlap.RespectCanCollide=true
check(bounds.Size==Vector3.new(832,120,832),"Mud must be832square")
check((bounds.Position-Vector3.new(8800,92.9,4534)).Magnitude<0.02,"Mud safe center differs")
check(math.abs(floorY-32.9)<0.02,"Mud floor height differs")
check(arena:GetAttribute("CourtWidth")==832 and arena:GetAttribute("CourtLength")==832,"Mud dimensions absent")
check(arena:GetAttribute("RoundDuration")==300,"Mud round must last five minutes")
local maximumPlayers=arena:GetAttribute("MaxPlayers")
check(typeof(maximumPlayers)=="number" and maximumPlayers>=2 and maximumPlayers<=24,"Mud roster exceeds physical spawn capacity")
check(arena:GetAttribute("MaximumRouteHeight")==12,"Unexpected maximum elevated route height")
check(arena:GetAttribute("MinimumPathWidth")>=6,"Mud ground lane width too narrow")
check(#starts:GetChildren()==24,"Mud needs24 general spawn pads")
check(#teams:GetChildren()==12,"Mud needs12 team groups")
check(#practice:GetChildren()>=4,"Mud needs four nearby practice spawns")
local nodeLookup={}
for _,node in ipairs(nav:GetChildren()) do nodeLookup[node.Name]=node end
local function capsuleClear(point,message)
 local objects=workspace:GetPartBoundsInBox(CFrame.new(point+Vector3.new(0,0.2,0)),Vector3.new(5.8,6.8,5.8),overlap)
 check(#objects==0,message.." intersects solid geometry")
end
local function padCheck(pad)
 check(pad:IsA("BasePart") and pad.Transparency==1 and not pad.CanCollide and not pad.CanQuery,"Spawn pad must be invisible/passable")
 check(math.abs(pad.Position.Y-floorY-3.6)<0.02,"Spawn pad is not at root height")
 local localPoint=bounds.CFrame:PointToObjectSpace(pad.Position)
 check(math.abs(localPoint.X)<406 and math.abs(localPoint.Z)<406,"Spawn too close to boundary")
 local hit=workspace:Raycast(pad.Position,Vector3.new(0,-10,0),ray)
 check(hit and math.abs(hit.Position.Y-floorY)<0.03,"Spawn lacks flat ground")
 capsuleClear(pad.Position,"Spawn "..pad:GetFullName())
end
for _,pad in ipairs(starts:GetChildren()) do
 padCheck(pad)
 check(nodeLookup[pad:GetAttribute("NavigationNode")]~=nil,"General spawn lacks a connected navigation approach")
end
local teamPads=0
for index=1,12 do
 local group=assert(teams:FindFirstChild(string.format("Group%02d",index)),"Missing team group")
 check(group:GetAttribute("TeamId")==index and group:GetAttribute("TeamIndex")==index,"Team index metadata differs")
 check(group:GetAttribute("Capacity")==12 and #group:GetChildren()==12,"Each team group needs12 spawn slots")
 for _,pad in ipairs(group:GetChildren()) do padCheck(pad) teamPads+=1 end
end
for _,pad in ipairs(practice:GetChildren()) do padCheck(pad) check(nodeLookup[pad:GetAttribute("NavigationNode")]~=nil,"Practice navigation absent") end
local practicePads=practice:GetChildren()
for i=1,#practicePads do for j=i+1,#practicePads do
 local distance=(practicePads[i].Position-practicePads[j].Position).Magnitude
 check(distance>=15 and distance<=50,"Practice characters start too close or too far apart")
 local direction=practicePads[j].Position-practicePads[i].Position
 check(workspace:Raycast(practicePads[i].Position,direction,ray)==nil,"Practice spawns lack direct open routes")
end end

local partCount,walkable,rampCount,stepCount,cubbies=0,0,0,0,0
for _,object in ipairs(arena:GetDescendants()) do
 check(not object:IsA("BaseScript") and not object:IsA("ModuleScript"),"Map geometry must be scriptless")
 if object:IsA("BasePart") then
  partCount+=1 check(object.Anchored,"Mud map has an unanchored part")
  if object:GetAttribute("DecorativeRoof") then check(not object.CanCollide,"Decorative roof creates an inaccessible perch") end
  if object:GetAttribute("Walkable") then
   walkable+=1
   check(object.CanCollide,"Walkable surface lacks collision")
   check((object:GetAttribute("PathWidth") or 0)>=6,"Walkable path width too narrow")
   check((object:GetAttribute("TopHeight") or object:GetAttribute("ToHeight") or 0)<=12.01,"Walkable surface too tall")
   check((object:GetAttribute("JumpGap") or 0)<=8,"Jump gap exceeds safe range")
   check((object:GetAttribute("StepRise") or 0)<=6,"Step rise exceeds safe range")
  end
  if object:GetAttribute("IsRamp") then
   rampCount+=1
   local rise,run=object:GetAttribute("Rise"),object:GetAttribute("Run")
   check(run>=40 and math.deg(math.atan(rise/run))<=25,"Ramp is too steep or short")
   local topCenter=object.Position+object.CFrame.UpVector*object.Size.Y/2
   local a,b=topCenter+object.CFrame.LookVector*object.Size.Z/2,topCenter-object.CFrame.LookVector*object.Size.Z/2
   local low,high=a.Y<b.Y and a or b,a.Y<b.Y and b or a
   check(math.abs(low.Y-floorY-0.18)<0.03,"Ramp does not meet ground")
   check(math.abs(high.Y-floorY-12)<0.03,"Ramp does not meet the deck height")
   local decks={}
   for _,candidate in ipairs(object.Parent:GetChildren()) do
    if candidate:IsA("BasePart") and candidate:GetAttribute("TopHeight")==12 and not candidate:GetAttribute("IsStep") then table.insert(decks,candidate) end
   end
   local deckRay=RaycastParams.new() deckRay.FilterType=Enum.RaycastFilterType.Include deckRay.FilterDescendantsInstances=decks deckRay.RespectCanCollide=true
   local centroid=Vector3.zero
   for _,deck in ipairs(decks) do centroid+=deck.Position end
   centroid/=math.max(1,#decks)
   local toward=Vector3.new(centroid.X-high.X,0,centroid.Z-high.Z)
   local target=high+(toward.Magnitude>0 and toward.Unit*0.35 or Vector3.zero)
   local hit=workspace:Raycast(target+Vector3.new(0,2,0),Vector3.new(0,-4,0),deckRay)
   check(hit and math.abs(hit.Position.Y-floorY-12)<0.04,"Ramp top is detached from its loop")
  end
  if object:GetAttribute("IsStep") then
   stepCount+=1
   check(object:GetAttribute("StepRise")==3 and object:GetAttribute("PathWidth")==14,"Playfort stairs lack wide low steps")
  end
 elseif object:GetAttribute("CoverCubby") then
  cubbies+=1
  local a,b=object:FindFirstChild("DoorA"),object:FindFirstChild("DoorB")
  check(object:GetAttribute("TwoExits")==true and a and b,"Cubby lacks two exits")
  check(object:GetAttribute("ExitWidth")>=12 and object:GetAttribute("ClearInteriorHeight")>=8,"Cubby escape too narrow")
  local delta=b.Position-a.Position local side=Vector3.new(-delta.Z,0,delta.X).Unit*3
  for _,offset in ipairs({Vector3.zero,side,-side}) do
   check(workspace:Raycast(a.Position+offset,delta,ray)==nil,object.Name.." contains a cubby exit blocker")
  end
 end
end
check(rampCount==12,"Each of four forts needs three broad ramps including its slide")
check(stepCount==16,"Each fort needs four low stair steps")
check(walkable==44,"Elevated geometry is incomplete")
check(cubbies>=15 and cubbies==arena:GetAttribute("TwoExitCubbies"),"Schoolyard hiding cubbies are too sparse")
local forts=geometry.ElevatedRoutes:GetChildren()
check(#forts==4,"Mud needs four low connected playfort loops")
for _,fort in ipairs(forts) do
 check(fort:GetAttribute("GroundRouteConnected")==true and fort:GetAttribute("IndependentAccesses")>=2,"Elevated route has a dead end")
 local ramps,stairs,decks=0,0,0
 for _,object in ipairs(fort:GetChildren()) do
  if object:IsA("BasePart") and object:GetAttribute("Walkable") then
   if object:GetAttribute("IsRamp") then ramps+=1 elseif object:GetAttribute("IsStep") then stairs+=1 else decks+=1 end
  end
 end
 check(ramps==3 and stairs==4 and decks==4,"Playfort route pieces/accesses missing")
end
for index=1,3 do
 local room=geometry.Landmarks:FindFirstChild(string.format("Classroom%02d",index))
 check(room and room:GetAttribute("TwoExits")==true,"School classroom needs two doors")
 local a,b=room.DoorA,room.DoorB local direction=b.Position-a.Position
 for _,offset in ipairs({Vector3.zero,Vector3.new(3,0,0),Vector3.new(-3,0,0)}) do
  check(workspace:Raycast(a.Position+offset,direction,ray)==nil,"Classroom through-route is blocked")
 end
end
check(geometry.Landmarks:FindFirstChild("MonkeyBars")~=nil,"Monkey bars landmark missing")
check(geometry.Landmarks:FindFirstChild("Swings")~=nil,"Safe fixed swings landmark missing")
check(geometry.Landmarks:FindFirstChild("RoundersPitch")~=nil,"Rounders field missing")
check(geometry.Landmarks:FindFirstChild("PaintedGames")~=nil,"Painted schoolyard games missing")

local nodes=nav:GetChildren()
check(#nodes>=500,"Ground navigation does not cover the large map")
check(#nodes==arena:GetAttribute("NavigationNodes"),"Navigation count metadata differs")
check((arena:GetAttribute("DiscardedNavigationNodes") or 0)<=12,"Large disconnected ground pockets were discarded")
local adjacency={} local edgeCount=0 local minX,maxX,minZ,maxZ=math.huge,-math.huge,math.huge,-math.huge
local cover=gameplay.CoverVolumes:GetChildren()
check(#cover>=110 and #cover==arena:GetAttribute("CoverStations"),"School playground lacks distributed cover")
local maximumCoverDistance=0
for _,node in ipairs(nodes) do
 check(node:IsA("BasePart") and node:GetAttribute("GroundNode")==true,"Navigation contains a non-ground waypoint")
 check(node:GetAttribute("LaneWidth")>=6,"Ground waypoint clearance too narrow")
 local hit=workspace:Raycast(node.Position,Vector3.new(0,-10,0),ray)
 check(hit and math.abs(hit.Position.Y-floorY)<0.03,"Navigation waypoint lacks ground")
 capsuleClear(node.Position,"Navigation "..node.Name)
 minX=math.min(minX,node.Position.X) maxX=math.max(maxX,node.Position.X)
 minZ=math.min(minZ,node.Position.Z) maxZ=math.max(maxZ,node.Position.Z)
 local nearest=math.huge
 for _,volume in ipairs(cover) do
  local dx,dz=node.Position.X-volume.Position.X,node.Position.Z-volume.Position.Z
  nearest=math.min(nearest,math.sqrt(dx*dx+dz*dz))
 end
 maximumCoverDistance=math.max(maximumCoverDistance,nearest)
 check(nearest<=144,string.format("Navigation %s is %.2fstuds from nearest cover",node.Name,nearest))
 local neighbors=string.split(node:GetAttribute("Neighbors") or "",",")
 check(#neighbors>0 and neighbors[1]~="","Ground navigation node isolated")
 adjacency[node.Name]=neighbors
 for _,neighborName in ipairs(neighbors) do
  local neighbor=nodeLookup[neighborName]
  check(neighbor~=nil,"Navigation link points to a missing node")
  if node.Name<neighborName then
   edgeCount+=1
   local delta=Vector3.new(neighbor.Position.X-node.Position.X,0,neighbor.Position.Z-node.Position.Z)
   local side=Vector3.new(-delta.Z,0,delta.X).Unit*3
   for _,height in ipairs({1.5,3.5,6.5}) do for _,offset in ipairs({Vector3.zero,side,-side}) do
    local origin=Vector3.new(node.Position.X,floorY+height,node.Position.Z)+offset
    check(workspace:Raycast(origin,delta,ray)==nil,"Navigation edge crosses solid geometry")
   end end
  end
 end
end
check(maxX-minX>=760 and maxZ-minZ>=760,"Navigation misses an edge region")
local visited={} local queue={nodes[1].Name} visited[nodes[1].Name]=true local at=1
while queue[at] do
 local current=queue[at] at+=1
 for _,neighbor in ipairs(adjacency[current]) do
  check(table.find(adjacency[neighbor],current)~=nil,"Ground navigation links must be reciprocal")
  if not visited[neighbor] then visited[neighbor]=true table.insert(queue,neighbor) end
 end
end
check(#queue==#nodes,"Ground navigation is disconnected")
check(edgeCount==arena:GetAttribute("NavigationEdges"),"Navigation edge metadata differs")
return {passed=checks,parts=partCount,spawnPads=24,teamGroups=12,teamSpawnSlots=teamPads,practiceSpawns=#practicePads,playforts=4,ramps=rampCount,stairs=stepCount,twoExitCubbies=cubbies,coverStations=#cover,navigationNodes=#nodes,navigationEdges=edgeCount,connected=true,maximumCoverCenterDistance=maximumCoverDistance,linearScaleFromTag=2,areaScaleFromTag=4,liveTraversal="Playtest pursuit, shooting sightlines and rescue timing before final balance tuning"}
