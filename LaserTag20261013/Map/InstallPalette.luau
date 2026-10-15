assert(not game:GetService("RunService"):IsRunning(), "Stop Play before applying the Laser Tag palette")
local HttpService=game:GetService("HttpService")
local arena=assert(workspace:FindFirstChild("Stuck in the Mud"))
local geometry=assert(arena:FindFirstChild("Geometry"))
local scenery=assert(arena:FindFirstChild("Scenery"))
local assets=assert(game.ReplicatedStorage:FindFirstChild("MudAssets"))
local version="20261013-muted-laser-v1"
if geometry:GetAttribute("LaserTagPaletteVersion")==version then return {alreadyInstalled=true} end
assert(not game.ServerStorage:FindFirstChild("LaserTagVisualBackup20261013"),"An existing backup needs inspection")
local rgb=Color3.fromRGB
local palette={
 ["149,104,70"]=rgb(91,69,54),
 ["148,97,68"]=rgb(91,68,50),
 ["149,205,97"]=rgb(76,112,74),
 ["134,194,83"]=rgb(60,85,63),
 ["154,217,231"]=rgb(92,139,149),
 ["88,174,224"]=rgb(61,110,149),
 ["111,196,151"]=rgb(62,107,100),
 ["247,127,113"]=rgb(164,69,70),
 ["175,149,218"]=rgb(89,80,120),
 ["255,205,77"]=rgb(153,128,79),
 ["234,143,112"]=rgb(118,83,71),
 ["255,253,235"]=rgb(188,196,193),
 ["217,209,183"]=rgb(124,129,127),
 ["28,43,62"]=rgb(28,43,62),
 ["255,239,194"]=rgb(143,147,143),
}
local gunPalettes={
 HeatGun={
  ["24,35,62"]=rgb(24,35,62),["243,136,45"]=rgb(183,51,62),
  ["255,238,199"]=rgb(213,220,230),["255,218,91"]=rgb(239,89,98),
  ["245,81,55"]=rgb(255,176,181),["244,116,36"]=rgb(128,36,48),
  ["255,207,74"]=rgb(250,143,149),
 },
 MudGun={
  ["24,35,62"]=rgb(24,35,62),["168,110,57"]=rgb(43,111,188),
  ["119,201,103"]=rgb(76,187,235),["114,74,40"]=rgb(35,77,131),
  ["255,238,199"]=rgb(213,220,230),["126,204,91"]=rgb(155,224,255),
 },
}
local function key(c)
 return string.format("%d,%d,%d",math.round(c.R*255),math.round(c.G*255),math.round(c.B*255))
end
local function nextMapColor(p)
 if p.Transparency>=1 then return p.Color end
 local mapped=assert(palette[key(p.Color)],"Unknown arena colour: "..p:GetFullName().." "..key(p.Color))
 if p.Name=="PlaygroundFloor" then return rgb(56,64,70) end
 if string.match(p.Name,"^MownStripe") then
  return key(p.Color)=="149,205,97" and rgb(64,72,77) or rgb(56,64,70)
 end
 if p.Name=="RoundersMownField" then return rgb(65,77,72) end
 if p.Name=="FenceXPanels" or p.Name=="FenceZPanels" then return rgb(51,69,85) end
 if p.Name=="FenceXPost" or p.Name=="FenceZPost" then
  return p.Position.X<8800 and rgb(164,69,70) or rgb(61,110,149)
 end
 if p.Name=="FenceXCap" or p.Name=="FenceZCap" or p.Name=="RoofCream" then return rgb(83,93,109) end
 if string.find(p.Name,"CreamEdge",1,true) or string.find(p.Name,"LoopEdgeCream",1,true) then
  return p.Position.X<8800 and rgb(207,90,96) or rgb(73,160,205)
 end
 if p.Name=="SpawnCircleColor" then
  local closest,dist
  for _,group in arena.Gameplay.TeamSpawns:GetChildren() do
   local marker=group:FindFirstChild("01")
   if marker and marker:IsA("BasePart") then
    local d=(Vector3.new(marker.Position.X,0,marker.Position.Z)-Vector3.new(p.Position.X,0,p.Position.Z)).Magnitude
    if not dist or d<dist then closest=tonumber(string.match(group.Name,"%d+"));dist=d end
   end
  end
  if closest==1 then return rgb(164,69,70) end
  if closest==7 then return rgb(61,110,149) end
  return p.Position.X<8800 and rgb(164,69,70) or rgb(61,110,149)
 end
 return mapped
end
local properties={"CFrame","Size","Material","MaterialVariant","Transparency","Reflectance","Anchored","CanCollide","CanQuery","CanTouch","CollisionGroup","Massless","CastShadow","TopSurface","BottomSurface","LeftSurface","RightSurface","FrontSurface","BackSurface","CustomPhysicalProperties"}
local snapshots={}
local manifest={version=version,placeId=game.PlaceId,parts={},originalDisplayName=arena:GetAttribute("GameDisplayName")}
local plan={}
local function inspect(root,kind)
 for _,p in root:GetDescendants() do
  if p:IsA("BasePart") then
   local nextColor=p.Color
   if kind=="Map" then nextColor=nextMapColor(p)
   elseif p.Transparency<1 then nextColor=assert(gunPalettes[kind][key(p.Color)],"Unknown gun colour "..p:GetFullName().." "..key(p.Color)) end
   local row={part=p,color=p.Color,after=nextColor,props={}}
   for _,property in properties do row.props[property]=p[property] end
   if p:IsA("MeshPart") then row.props.MeshId=p.MeshId;row.props.TextureID=p.TextureID end
   table.insert(snapshots,row)
   table.insert(manifest.parts,{path=p:GetFullName(),kind=kind,color={p.Color.R,p.Color.G,p.Color.B},after={nextColor.R,nextColor.G,nextColor.B},cf={p.CFrame:GetComponents()},size={p.Size.X,p.Size.Y,p.Size.Z},material=p.Material.Name,variant=p.MaterialVariant,canCollide=p.CanCollide,canQuery=p.CanQuery,canTouch=p.CanTouch,transparency=p.Transparency})
   if nextColor~=p.Color then table.insert(plan,row) end
  end
 end
end
inspect(geometry,"Map")
inspect(scenery,"Map")
inspect(assert(assets:FindFirstChild("HeatGun")),"HeatGun")
inspect(assert(assets:FindFirstChild("MudGun")),"MudGun")
assert(#snapshots==1702,"Unexpected map and gun part count")
local rig={}
for _,name in {"HeatGun","MudGun"} do
 for _,p in assets[name]:GetDescendants() do
  if p:IsA("Attachment") then table.insert(rig,{object=p,cf=p.CFrame,parent=p.Parent}) end
  if p:IsA("JointInstance") then table.insert(rig,{object=p,c0=p.C0,c1=p.C1,part0=p.Part0,part1=p.Part1,parent=p.Parent}) end
  if p:IsA("WeldConstraint") then table.insert(rig,{object=p,part0=p.Part0,part1=p.Part1,parent=p.Parent}) end
 end
end
local lighting=game:GetService("Lighting")
local lightingSnapshot={}
for _,property in {"Ambient","OutdoorAmbient","Brightness","ClockTime","FogColor","FogStart","FogEnd","ExposureCompensation","GlobalShadows"} do lightingSnapshot[property]=lighting[property] end
local backup=Instance.new("Folder");backup.Name="LaserTagVisualBackup20261013";backup.Parent=game.ServerStorage
local originals=Instance.new("Folder");originals.Name="Originals";originals.Parent=backup
geometry:Clone().Parent=originals
scenery:Clone().Parent=originals
assets.HeatGun:Clone().Parent=originals
assets.MudGun:Clone().Parent=originals
local targets=Instance.new("Folder");targets.Name="ColourTargets";targets.Parent=backup
for i,row in snapshots do
 local ref=Instance.new("ObjectValue");ref.Name=string.format("Part%04d",i);ref.Value=row.part
 ref:SetAttribute("OriginalColor",row.color);ref:SetAttribute("InstalledColor",row.after);ref.Parent=targets
end
local originalName=Instance.new("StringValue");originalName.Name="OriginalDisplayName";originalName.Value=arena:GetAttribute("GameDisplayName") or "";originalName.Parent=backup
backup:SetAttribute("OriginalDisplayNameWasNil",arena:GetAttribute("GameDisplayName")==nil)
local json=HttpService:JSONEncode(manifest)
local chunks=Instance.new("Folder");chunks.Name="Manifest";chunks.Parent=backup
for start=1,#json,60000 do
 local chunk=Instance.new("StringValue");chunk.Name=string.format("Chunk%03d",math.floor((start-1)/60000)+1);chunk.Value=string.sub(json,start,start+59999);chunk.Parent=chunks
end
backup:SetAttribute("Version",version)
local ok,failure=xpcall(function()
 for _,row in plan do row.part.Color=row.after end
 local checks=0
 for _,row in snapshots do
  assert(row.part.Color==row.after,"Incorrect colour on "..row.part:GetFullName());checks+=1
  for property,original in row.props do assert(row.part[property]==original,"Unexpected property change: "..row.part:GetFullName().."."..property);checks+=1 end
 end
 for _,row in rig do
  assert(row.object.Parent==row.parent);checks+=1
  if row.cf then assert(row.object.CFrame==row.cf);checks+=1 end
  if row.c0 then assert(row.object.C0==row.c0 and row.object.C1==row.c1);checks+=2 end
  if row.part0 then assert(row.object.Part0==row.part0 and row.object.Part1==row.part1);checks+=2 end
 end
 for property,original in lightingSnapshot do assert(lighting[property]==original,"Global lighting changed");checks+=1 end
 geometry:SetAttribute("LaserTagPaletteVersion",version)
 scenery:SetAttribute("LaserTagPaletteVersion",version)
 assets.HeatGun:SetAttribute("LaserTagPaletteVersion",version)
 assets.MudGun:SetAttribute("LaserTagPaletteVersion",version)
 arena:SetAttribute("GameDisplayName","Laser Tag")
 backup:SetAttribute("Installed",true)
 backup:SetAttribute("ChecksPassed",checks)
 backup:SetAttribute("PartsChecked",#snapshots)
 backup:SetAttribute("PartsRecoloured",#plan)
end,debug.traceback)
if not ok then
 for _,row in snapshots do row.part.Color=row.color end
 backup:SetAttribute("InstallError",tostring(failure))
 error(failure)
end
return {installed=true,partsRecoloured=#plan,partsPreserved=#snapshots,checks=backup:GetAttribute("ChecksPassed"),backup=backup:GetFullName(),manifestBytes=#json,manifestChunks=#chunks:GetChildren()}
