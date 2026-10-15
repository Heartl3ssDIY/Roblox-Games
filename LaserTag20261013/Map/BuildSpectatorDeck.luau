assert(not game:GetService("RunService"):IsRunning(),"Stop Play before adding the spectator deck")
local arena=assert(workspace:FindFirstChild("Stuck in the Mud"))
local geometry=assert(arena:FindFirstChild("Geometry"))
local gameplay=assert(arena:FindFirstChild("Gameplay"))
local version="20261013-spectator-deck-v1"
if geometry:FindFirstChild("LaserSpectatorDeck") then
 assert(geometry.LaserSpectatorDeck:GetAttribute("BuildVersion")==version,"Unexpected spectator deck")
 return {alreadyInstalled=true}
end
assert(not gameplay:FindFirstChild("SpectatorSpawns"),"Existing spectator spawns need inspection")
local backup=assert(game.ServerStorage:FindFirstChild("LaserTagVisualBackup20261013"))
local overlap=OverlapParams.new();overlap.RespectCanCollide=true
assert(#workspace:GetPartBoundsInBox(CFrame.new(8800,85,4078),Vector3.new(124,18,40),overlap)==0,"Spectator deck area is occupied")
local deck=Instance.new("Model");deck.Name="LaserSpectatorDeck";deck.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
deck:SetAttribute("BuildVersion",version)
local markers=Instance.new("Folder");markers.Name="SpectatorSpawns"
local ink=Color3.fromRGB(28,43,62)
local slate=Color3.fromRGB(91,105,119)
local grey=Color3.fromRGB(143,147,143)
local red=Color3.fromRGB(207,90,96)
local blue=Color3.fromRGB(73,160,205)
local origin=Vector3.new(8800,78.9,4078)
local function part(name,size,offset,color,solid)
 local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=CFrame.new(origin+offset)
 p.Color=color;p.Anchored=true;p.CanCollide=solid;p.CanTouch=false;p.CanQuery=solid
 p.Material=Enum.Material.SmoothPlastic;p.MaterialVariant="PlaygroundRetroStuds"
 p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=deck
 return p
end
part("IslandSupportInk",Vector3.new(130,40,44),Vector3.new(0,-76,2),ink,true)
part("IslandSupportEarth",Vector3.new(128,39.6,43.6),Vector3.new(0,-75.8,2),Color3.fromRGB(91,69,54),false)
part("DeckOutline",Vector3.new(120,2,36),Vector3.new(0,-1,0),ink,true)
part("DeckStudSurface",Vector3.new(118.8,.1,34.8),Vector3.new(0,.05,0),slate,false)
for _,x in {-51,51} do
 for _,z in {-11,11} do
  part("SupportPostInk",Vector3.new(4,55,4),Vector3.new(x,-28.5,z),ink,true)
  part("SupportPostFace",Vector3.new(2.8,54.6,4.08),Vector3.new(x,-28.5,z),grey,false)
 end
end
for i=-5,5 do
 for _,z in {-17.5,17.5} do
  part("RailPost",Vector3.new(.7,4.5,.7),Vector3.new(i*11.6,2.25,z),ink,true)
 end
end
for _,z in {-17.5,17.5} do
 part("RailInk",Vector3.new(120,.65,.85),Vector3.new(0,4.5,z),ink,true)
 part("RedRailAccent",Vector3.new(58,.22,.95),Vector3.new(-29.5,4.85,z),red,false)
 part("BlueRailAccent",Vector3.new(58,.22,.95),Vector3.new(29.5,4.85,z),blue,false)
 local glass=part("SafetyPanel",Vector3.new(118,3.8,.2),Vector3.new(0,2.15,z),Color3.fromRGB(135,173,186),true)
 glass.Transparency=.72;glass.MaterialVariant="";glass.CastShadow=false
end
for _,x in {-59.5,59.5} do
 part("SideRailInk",Vector3.new(.85,.65,36),Vector3.new(x,4.5,0),ink,true)
 local glass=part("SideSafetyPanel",Vector3.new(.2,3.8,35),Vector3.new(x,2.15,0),Color3.fromRGB(135,173,186),true)
 glass.Transparency=.72;glass.MaterialVariant="";glass.CastShadow=false
end
for _,x in {-32,32} do
 local color=x<0 and red or blue
 local stripe=part("TeamViewingStripe",Vector3.new(1,.06,29),Vector3.new(x,.13,0),color,false)
 stripe.CastShadow=false
end
local floorY=78.9
for row=0,4 do
 for col=0,11 do
  local index=row*12+col+1
  local position=Vector3.new(8800+(col-5.5)*8, floorY+3, 4078+(row-2)*5.5)
  local marker=Instance.new("Part");marker.Name=string.format("%03d",index);marker.Size=Vector3.new(2,.2,2)
  marker.CFrame=CFrame.lookAt(position,position+Vector3.new(0,0,1));marker.Anchored=true;marker.Transparency=1
  marker.CanCollide=false;marker.CanTouch=false;marker.CanQuery=false;marker.CastShadow=false
  marker:SetAttribute("SpectatorIndex",index);marker:SetAttribute("FloorY",floorY);marker.Parent=markers
 end
end
deck.Parent=geometry;markers.Parent=gameplay
local bounds=Instance.new("Part");bounds.Name="SpectatorBounds";bounds.Size=Vector3.new(116,30,32)
bounds.CFrame=CFrame.new(8800,93.9,4078);bounds.Anchored=true;bounds.Transparency=1
bounds.CanCollide=false;bounds.CanTouch=false;bounds.CanQuery=false;bounds.CastShadow=false;bounds.Parent=gameplay
local created=Instance.new("Folder");created.Name="SpectatorDeckCreated";created.Parent=backup
for _,p in {deck,markers,bounds} do local ref=Instance.new("ObjectValue");ref.Name=p.Name;ref.Value=p;ref.Parent=created end
local checks=0
local rayParams=RaycastParams.new();rayParams.RespectCanCollide=true;rayParams.FilterType=Enum.RaycastFilterType.Include;rayParams.FilterDescendantsInstances={deck}
for _,marker in markers:GetChildren() do
 local p=marker.Position
 assert(p.Z+2<gameplay.ArenaBounds.Position.Z-gameplay.ArenaBounds.Size.Z/2,"Spectator inside active arena");checks+=1
 local hits=workspace:GetPartBoundsInBox(marker.CFrame,Vector3.new(3,4.8,3),overlap)
 assert(#hits==0,"Blocked spectator marker: "..marker.Name);checks+=1
 local floor=workspace:Raycast(p,Vector3.new(0,-8,0),rayParams)
 assert(floor and floor.Instance.Name=="DeckOutline","Missing spectator floor");checks+=1
 assert(math.abs(floor.Position.Y-floorY)<.01,"Incorrect floor height");checks+=1
 assert(marker.CFrame.LookVector.Z>.99,"Spectator must face arena");checks+=1
end
local count=0
for _,p in deck:GetDescendants() do
 if p:IsA("BasePart") then
  assert(p.Anchored and not p.CanTouch,"Unsafe spectator part");checks+=1
  count+=1
 end
end
assert(#markers:GetChildren()==60)
deck:SetAttribute("ChecksPassed",checks)
deck:SetAttribute("DeckTopY",floorY)
deck:SetAttribute("SpectatorCapacity",60)
return {installed=true,parts=count,spawns=60,checks=checks,deckTopY=floorY,spawnY=floorY+3,center={8800,4078},bounds={8742,8858,4062,4094},outsideArena=true}
