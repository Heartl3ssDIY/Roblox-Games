local arena = assert(workspace:FindFirstChild("Tag You're It"),"Tag arena missing")
local gameplay = assert(arena:FindFirstChild("Gameplay"),"Tag gameplay folder missing")
local geometry = assert(arena:FindFirstChild("Geometry"),"Tag geometry folder missing")
local bounds = assert(gameplay:FindFirstChild("ArenaBounds"),"Tag bounds missing")
local pads = assert(gameplay:FindFirstChild("StartPads"),"Tag start pads missing")
local nodes = assert(gameplay:FindFirstChild("NavigationNodes"),"Tag navigation missing")
local vaults = assert(gameplay:FindFirstChild("VaultObstacles"),"Tag vaults missing")
local floorY = arena:GetAttribute("FloorY")
local checks = 0
local function check(value,message)
 assert(value,message)
 checks += 1
end
check(bounds.Size==Vector3.new(416,100,416),"Tag court size differs")
check((bounds.Position-Vector3.new(6500,82.9,4534)).Magnitude<0.01,"Tag court center differs")
check(#pads:GetChildren()==24,"Tag needs 24 starting pads")
check(math.abs(floorY-32.9)<0.01,"Tag floor height differs")
check(arena:GetAttribute("MaximumRouteHeight")==24,"Unexpected maximum parkour height")
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = {geometry,vaults}
params.RespectCanCollide = true
for _,pad in ipairs(pads:GetChildren()) do
 check(pad:IsA("BasePart") and not pad.CanCollide and pad.Transparency==1,"Start pad must be invisible and passable")
 local point = bounds.CFrame:PointToObjectSpace(pad.Position)
 check(math.abs(point.X)<bounds.Size.X/2 and math.abs(point.Z)<bounds.Size.Z/2,"Start pad outside court")
 check(math.abs(math.max(math.abs(point.X),math.abs(point.Z))-190)<0.1,"Start pad misses white perimeter")
 local hit = workspace:Raycast(pad.Position,Vector3.new(0,-12,0),params)
 check(hit and math.abs(hit.Position.Y-floorY)<0.05,"Start pad lacks level ground")
end
local taggerSpawn = gameplay:FindFirstChild("TaggerSpawn")
check(taggerSpawn and (Vector2.new(taggerSpawn.Position.X,taggerSpawn.Position.Z)-Vector2.new(6500,4534)).Magnitude<0.01,"Tagger spawn misses center")
local walkableCount,rampCount,vaultCount = 0,0,0
for _,p in ipairs(arena:GetDescendants()) do
 if p:IsA("BasePart") then
  check(p.Anchored,"Tag map contains an unanchored part")
  if p:GetAttribute("Walkable") then
   walkableCount += 1
   check(p.CanCollide,"Walkable route lacks collision")
   check((p:GetAttribute("PathWidth") or 0)>=10,"A parkour route is too narrow")
   check((p:GetAttribute("TopHeight") or p:GetAttribute("ToHeight") or 0)<=24.01,"Parkour route exceeds maximum height")
   check((p:GetAttribute("StepRise") or 0)<=4,"Parkour step rise is too high")
   check((p:GetAttribute("JumpGap") or 0)<=6,"Parkour jump gap is too wide")
  end
  if p:GetAttribute("IsRamp") then
   rampCount += 1
   check(p:GetAttribute("Run")>=30,"Ramp run is too short")
   check(math.deg(math.atan(p:GetAttribute("Rise")/p:GetAttribute("Run")))<=30,"Ramp slope is too steep")
   local topCenter = p.Position+p.CFrame.UpVector*p.Size.Y/2
   local a,b = topCenter+p.CFrame.LookVector*p.Size.Z/2,topCenter-p.CFrame.LookVector*p.Size.Z/2
   check(math.abs(math.min(a.Y,b.Y)-floorY-0.18)<0.05,"Ramp bottom does not meet ground")
   check(math.abs(math.max(a.Y,b.Y)-floorY-12)<0.05,"Ramp top does not meet loop")
  end
  if p:GetAttribute("Vaultable") then
   vaultCount += 1
   check(p.CanCollide and p.Size.Y<=3.2,"Vault barrier is not traversable")
   check(p:GetAttribute("ApproachClearance")>=10,"Vault approach lacks room")
  end
 end
end
check(rampCount==8,"Each of four routes needs two ramps")
check(vaultCount==8,"Expected eight vault barriers")
check(walkableCount>=45,"Tag parkour network is incomplete")
local routeFolders = geometry.ParkourRoutes:GetChildren()
local courseCount = 0
for _,course in ipairs(routeFolders) do
 if course:GetAttribute("RouteId") then
  courseCount += 1
  local accesses = 0
  for _,p in ipairs(course:GetDescendants()) do if p:GetAttribute("IsRamp") then accesses += 1 end end
  check(accesses>=2,"Upper course needs two independent access ramps")
  check(course:GetAttribute("ContinuousGroundRoute")==true,"Course must preserve a ground escape")
 end
end
check(courseCount==4,"Expected four parkour circuits")
local lookup,count = {},0
for _,node in ipairs(nodes:GetChildren()) do lookup[node.Name]=node count+=1 end
check(count>=100,"Ground navigation is too sparse")
local adjacency = {}
for name,node in pairs(lookup) do
 local neighbors = string.split(node:GetAttribute("Neighbors") or "",",")
 adjacency[name] = neighbors
 check(#neighbors>=1 and neighbors[1]~="","Ground navigation has an isolated node")
 for _,neighbor in ipairs(neighbors) do
  local destination = lookup[neighbor]
  check(destination~=nil,"Navigation links to missing node")
  local direction = destination.Position-node.Position
  local sideways = Vector3.new(-direction.Z,0,direction.X).Unit*2.5
  for _,offset in ipairs({Vector3.zero,sideways,-sideways}) do
   local origin = Vector3.new(node.Position.X,floorY+1.5,node.Position.Z)+offset
   local hit = workspace:Raycast(origin,direction,params)
   check(hit==nil,"Ground navigation crosses a blocking object")
  end
 end
end
local visited,queue = {},{}
for name in pairs(lookup) do queue[1]=name visited[name]=true break end
local at=1
while queue[at] do
 local current=queue[at]
 at+=1
 for _,neighbor in ipairs(adjacency[current]) do
  check(table.find(adjacency[neighbor],current)~=nil,"Navigation links must be reciprocal")
  if not visited[neighbor] then visited[neighbor]=true table.insert(queue,neighbor) end
 end
end
check(#queue==count,"Navigation graph is disconnected")
return {passed=checks,walkableParts=walkableCount,ramps=rampCount,vaults=vaultCount,courses=courseCount,navigationNodes=count,connected=true,areaRatio=416*416/(224*368),liveTraversal="Use normal humanoid playtest for final jump feel"}
