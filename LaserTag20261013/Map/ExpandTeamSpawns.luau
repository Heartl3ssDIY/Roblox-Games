assert(not game:GetService("RunService"):IsRunning(),"Stop Play before extending Laser Tag spawns")
local arena=assert(workspace:FindFirstChild("Stuck in the Mud"))
local teamSpawns=assert(arena.Gameplay:FindFirstChild("TeamSpawns"))
local backup=assert(game.ServerStorage:FindFirstChild("LaserTagVisualBackup20261013"))
if backup:FindFirstChild("TeamSpawnExpansion") then
 assert(teamSpawns.Group01:GetAttribute("LaserTagSpawnCapacity")==30 and teamSpawns.Group07:GetAttribute("LaserTagSpawnCapacity")==30)
 return {alreadyInstalled=true}
end
local overlaps=OverlapParams.new();overlaps.RespectCanCollide=true;overlaps.FilterType=Enum.RaycastFilterType.Include;overlaps.FilterDescendantsInstances={arena.Geometry,arena.Scenery}
local rays=RaycastParams.new();rays.RespectCanCollide=true;rays.FilterType=Enum.RaycastFilterType.Include;rays.FilterDescendantsInstances={arena.Geometry,arena.Scenery}
local plans={}
for _,name in {"Group01","Group07"} do
 local group=assert(teamSpawns:FindFirstChild(name))
 local points={};local center=Vector3.zero
 for _,p in group:GetChildren() do
  if p:IsA("BasePart") then table.insert(points,p.Position);center+=p.Position end
 end
 assert(#points==12,"Expected original twelve team spawn pads")
 center/=#points
 local cf=CFrame.lookAt(center,Vector3.new(arena.Gameplay.ArenaBounds.Position.X,center.Y,arena.Gameplay.ArenaBounds.Position.Z))
 local added={}
 for row=2,12 do
  for col=0,5 do
   if #added>=18 then break end
   local position=cf:PointToWorldSpace(Vector3.new((col-2.5)*6,0,-row*6))
   local valid=true
   for _,other in points do if (position-other).Magnitude<5.5 then valid=false;break end end
   local localPosition=arena.Gameplay.ArenaBounds.CFrame:PointToObjectSpace(position)
   if math.abs(localPosition.X)>arena.Gameplay.ArenaBounds.Size.X/2-8 or math.abs(localPosition.Z)>arena.Gameplay.ArenaBounds.Size.Z/2-8 then valid=false end
   local face=CFrame.lookAt(position,Vector3.new(arena.Gameplay.ArenaBounds.Position.X,position.Y,arena.Gameplay.ArenaBounds.Position.Z))
   if valid and #workspace:GetPartBoundsInBox(face,Vector3.new(3.8,5.4,3.8),overlaps)>0 then valid=false end
   local floor=valid and workspace:Raycast(position,Vector3.new(0,-8,0),rays)
   if not floor or position.Y-floor.Position.Y<2.5 or position.Y-floor.Position.Y>4.2 then valid=false end
   if valid then table.insert(points,position);table.insert(added,face) end
  end
  if #added>=18 then break end
 end
 assert(#added==18,"Unable to find 30 clear positions for "..name)
 table.insert(plans,{group=group,added=added})
end
local stored=Instance.new("Folder");stored.Name="TeamSpawnExpansion";stored.Parent=backup
local manifest={groups={}}
for _,plan in plans do
 plan.group:Clone().Parent=stored
 local result={group=plan.group.Name,created={}}
 for i,cf in plan.added do
  local marker=plan.group["01"]:Clone();marker.Name=string.format("%02d",i+12);marker.CFrame=cf
  marker:SetAttribute("LaserTagAddedSpawn",true);marker.Parent=plan.group
  local ref=Instance.new("ObjectValue");ref.Name=plan.group.Name.."_"..marker.Name;ref.Value=marker;ref.Parent=stored
  table.insert(result.created,{name=marker.Name,cf={cf:GetComponents()}})
 end
 plan.group:SetAttribute("LaserTagSpawnCapacity",30)
 table.insert(manifest.groups,result)
end
local checks=0;local minSpacing=math.huge
for _,plan in plans do
 local parts={}
 for _,p in plan.group:GetChildren() do if p:IsA("BasePart") then table.insert(parts,p) end end
 assert(#parts==30);checks+=1
 for i,p in parts do
  assert(#workspace:GetPartBoundsInBox(p.CFrame,Vector3.new(3.8,5.4,3.8),overlaps)==0,"Spawn blocked");checks+=1
  assert(workspace:Raycast(p.Position,Vector3.new(0,-8,0),rays),"Spawn not grounded");checks+=1
  for j=i+1,#parts do
   local distance=(p.Position-parts[j].Position).Magnitude
   assert(distance>=5.5,"Overlapping spawn pair");checks+=1
   minSpacing=math.min(minSpacing,distance)
  end
 end
end
local value=Instance.new("StringValue");value.Name="Manifest";value.Value=game:GetService("HttpService"):JSONEncode(manifest);value.Parent=stored
stored:SetAttribute("ChecksPassed",checks)
stored:SetAttribute("MinSpacing",minSpacing)
return {installed=true,added=36,totalSpawns=60,checks=checks,minSpacing=minSpacing,groups={"Group01","Group07"}}
