local arena=assert(workspace:FindFirstChild("Stuck in the Mud"),"Mud map missing")
if (arena:GetAttribute("MudGeometryRepairVersion") or 0)>=2 then return {repaired=false,preserved=true,version=2} end
local geometry=assert(arena:FindFirstChild("Geometry"),"Mud geometry missing")
local gameplay=assert(arena:FindFirstChild("Gameplay"),"Mud gameplay missing")
local floorY=arena:GetAttribute("FloorY")
local center=Vector3.new(arena:GetAttribute("CenterX"),floorY,arena:GetAttribute("CenterZ"))
local moved,markers=0,0
for _,model in ipairs(geometry.DistributedCover:GetChildren()) do
 if model.Name=="SouthernSchoolStorage" then
  local reference=model:FindFirstChild("StorageInk")
  if reference and math.abs(reference.Position.Z-center.Z-348)<0.1 then
   for _,object in ipairs(model:GetDescendants()) do if object:IsA("BasePart") then object.CFrame+=Vector3.new(0,0,14) end end
   moved+=1
  end
 end
end
for _,volume in ipairs(gameplay.CoverVolumes:GetChildren()) do
 if volume.Name=="SouthernSchoolStorage" and math.abs(volume.Position.Z-center.Z-348)<0.1 then volume.CFrame+=Vector3.new(0,0,14) markers+=1 end
end
local ink=Color3.fromRGB(28,43,62)
local cream=Color3.fromRGB(255,239,194)
local createdCubbies=0
local function makePart(label,size,position,color,parent,collide)
 local object=Instance.new("Part") object.Name=label object.Size=size object.Position=center+position
 object.Color=color object.Material=Enum.Material.SmoothPlastic object.Anchored=true
 object.CanCollide=collide==true object.CanTouch=false object.CanQuery=collide==true object.CastShadow=collide==true
 object.TopSurface=Enum.SurfaceType.Smooth object.BottomSurface=Enum.SurfaceType.Smooth object.Parent=parent return object
end
for _,x in ipairs({-364,364}) do for _,z in ipairs({-144,144}) do
 local label="OuterSideCubby"..(x<0 and "West" or "East")..(z<0 and "North" or "South")
 if not geometry.DistributedCover:FindFirstChild(label) then
  local model=Instance.new("Folder") model.Name=label model.Parent=geometry.DistributedCover
  model:SetAttribute("CoverCubby",true) model:SetAttribute("TwoExits",true) model:SetAttribute("ExitWidth",20)
  model:SetAttribute("ClearInteriorHeight",10) model:SetAttribute("GroundRouteConnected",true)
  local color=x<0 and Color3.fromRGB(88,174,224) or Color3.fromRGB(111,196,151)
  for _,side in ipairs({-1,1}) do
   makePart("CubbyWallInk",Vector3.new(2,10,24),Vector3.new(x+side*11,5,z),ink,model,true)
   makePart("CubbyWallColor",Vector3.new(0.2,8.4,22),Vector3.new(x+side*9.9,5,z),color,model,false)
   for rung=1,3 do makePart("CubbyWallPanel",Vector3.new(0.24,0.45,21),Vector3.new(x+side*9.7,rung*2.7,z),cream,model,false) end
  end
  makePart("CubbyRoofInk",Vector3.new(26,1.2,28),Vector3.new(x,10.6,z),ink,model,false):SetAttribute("DecorativeRoof",true)
  makePart("CubbyRoofColor",Vector3.new(24.5,0.8,26.5),Vector3.new(x,11.2,z),color,model,false):SetAttribute("DecorativeRoof",true)
  for _,side in ipairs({-1,1}) do
   local door=makePart(side<0 and "DoorA" or "DoorB",Vector3.new(20,1,10),Vector3.new(x,3.6,z+side*17),cream,model,false)
   door.Transparency=1 door:SetAttribute("ExitWidth",20)
  end
  local volume=makePart(label,Vector3.new(26,10,28),Vector3.new(x,5,z),cream,gameplay.CoverVolumes,false)
  volume.Transparency=1 volume:SetAttribute("CoverKind","TwoExitCubby") volume:SetAttribute("NearbyRescueSpace",true)
  createdCubbies+=1
 end
end end
local boxes={}
for _,part in ipairs(geometry:GetDescendants()) do
 if part:IsA("BasePart") and part.CanCollide then
  local low=Vector3.new(math.huge,math.huge,math.huge) local high=Vector3.new(-math.huge,-math.huge,-math.huge)
  for _,x in ipairs({-1,1}) do for _,y in ipairs({-1,1}) do for _,z in ipairs({-1,1}) do
   local point=part.CFrame:PointToWorldSpace(Vector3.new(x*part.Size.X/2,y*part.Size.Y/2,z*part.Size.Z/2))-center
   low=Vector3.new(math.min(low.X,point.X),math.min(low.Y,point.Y),math.min(low.Z,point.Z))
   high=Vector3.new(math.max(high.X,point.X),math.max(high.Y,point.Y),math.max(high.Z,point.Z))
  end end end
  if low.Y<7.8 and high.Y>0.2 then table.insert(boxes,{x1=low.X-3.2,x2=high.X+3.2,z1=low.Z-3.2,z2=high.Z+3.2}) end
 end
end
local function pointClear(x,z)
 for _,box in ipairs(boxes) do if x>=box.x1 and x<=box.x2 and z>=box.z1 and z<=box.z2 then return false end end
 return true
end
local function segmentClear(a,b)
 local dx,dz=b.x-a.x,b.z-a.z
 for _,box in ipairs(boxes) do
  local low,high=0,1
  local function clip(origin,delta,minimum,maximum)
   if math.abs(delta)<0.0001 then return origin>=minimum and origin<=maximum end
   local first,last=(minimum-origin)/delta,(maximum-origin)/delta
   if first>last then first,last=last,first end
   low=math.max(low,first) high=math.min(high,last) return low<=high
  end
  if clip(a.x,dx,box.x1,box.x2) and clip(a.z,dz,box.z1,box.z2) then return false end
 end
 return true
end
local candidates={} local lookup={}
for ix=-16,16 do for iz=-16,16 do
 local x,z=ix*24,iz*24
 if pointClear(x,z) then
  local item={x=x,z=z,ix=ix,iz=iz,neighbors={}}
  table.insert(candidates,item) lookup[ix..":"..iz]=item
 end
end end
for _,item in ipairs(candidates) do
 for _,offset in ipairs({{-1,0},{1,0},{0,-1},{0,1},{-1,-1},{-1,1},{1,-1},{1,1}}) do
  local neighbor=lookup[(item.ix+offset[1])..":"..(item.iz+offset[2])]
  if neighbor and segmentClear(item,neighbor) then table.insert(item.neighbors,neighbor) end
 end
end
local visited={} local largest={}
for _,item in ipairs(candidates) do
 if not visited[item] then
  local queue={item} visited[item]=true local at=1
  while queue[at] do
   local current=queue[at] at+=1
   for _,neighbor in ipairs(current.neighbors) do if not visited[neighbor] then visited[neighbor]=true table.insert(queue,neighbor) end end
  end
  if #queue>#largest then largest=queue end
 end
end
local nav=assert(gameplay:FindFirstChild("NavigationNodes"),"Generated navigation missing")
for _,object in ipairs(nav:GetChildren()) do assert(object:IsA("BasePart") and object:GetAttribute("GroundNode")==true,"Navigation contains an unrecognized authored object") end
nav:ClearAllChildren()
local retained={} local edges=0
for index,item in ipairs(largest) do
 retained[item]=true item.name=string.format("N%04d",index)
 local node=Instance.new("Part") node.Name=item.name node.Size=Vector3.one
 node.Position=center+Vector3.new(item.x,3.6,item.z) node.Anchored=true node.CanCollide=false node.CanTouch=false node.CanQuery=false node.Transparency=1
 node:SetAttribute("GroundNode",true) node:SetAttribute("LaneWidth",6.4) node.Parent=nav item.object=node
end
for _,item in ipairs(largest) do
 local names={}
 for _,neighbor in ipairs(item.neighbors) do if retained[neighbor] then table.insert(names,neighbor.name) edges+=1 end end
 table.sort(names) item.object:SetAttribute("Neighbors",table.concat(names,","))
end
for _,label in ipairs({"StartPads","PracticeSpawns"}) do
 for _,pad in ipairs(gameplay[label]:GetChildren()) do
  local best,distance=nil,math.huge local point=pad.Position-center
  for _,item in ipairs(largest) do
   local squared=(item.x-point.X)^2+(item.z-point.Z)^2
   if squared<distance and segmentClear({x=point.X,z=point.Z},item) then best=item distance=squared end
  end
  assert(best,"Repaired spawn approach missing") pad:SetAttribute("NavigationNode",best.name)
 end
end
arena:SetAttribute("NavigationNodes",#largest) arena:SetAttribute("NavigationEdges",edges/2)
local cubbies=0
for _,object in ipairs(geometry.DistributedCover:GetChildren()) do if object:GetAttribute("CoverCubby")==true then cubbies+=1 end end
arena:SetAttribute("CoverStations",#gameplay.CoverVolumes:GetChildren()) arena:SetAttribute("TwoExitCubbies",cubbies)
arena:SetAttribute("DiscardedNavigationNodes",#candidates-#largest) arena:SetAttribute("MudGeometryRepairVersion",2)
return {repaired=true,version=2,movedStorageModels=moved,movedCoverMarkers=markers,createdCubbies=createdCubbies,navigationNodes=#largest,navigationEdges=edges/2,preservedGeometry=true}
