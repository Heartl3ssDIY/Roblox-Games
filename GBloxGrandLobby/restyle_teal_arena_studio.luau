-- Restyle only the separate proposed lobby; archive the previous design.
local W=workspace
local previous=assert(W:FindFirstChild("G-Blox NEW Lobby - Cloud Club"))
local root=previous:Clone()
root.Name="G-Blox NEW Lobby - Teal Arena"
root:SetAttribute("Design","G-Blox blue grey teal lobby; reused original visual assets")
local O=previous.PrimaryPart.Position+Vector3.new(0,1.5,0)
local palette={
 {{255,244,216},{157,174,186}},{{255,254,244},{211,225,233}},
 {{113,220,244},{4,162,182}},{{0,192,222},{0,196,207}},
 {{65,145,223},{34,70,106}},{{43,67,118},{14,37,58}},
 {{255,151,186},{36,103,141}},{{255,112,123},{37,112,153}},
 {{255,214,82},{0,202,214}},{{182,163,242},{73,100,123}},
 {{137,227,188},{60,139,148}},{{61,174,129},{41,110,120}},
 {{220,244,239},{94,113,128}},{{36,47,77},{18,33,47}}
}
for _,o in root:GetDescendants() do
 if o:IsA("BasePart") then
  local best,dist
  for _,p in palette do local a=Color3.fromRGB(table.unpack(p[1]))
   local d=(o.Color.R-a.R)^2+(o.Color.G-a.G)^2+(o.Color.B-a.B)^2
   if not dist or d<dist then best,dist=p[2],d end
  end
  o.Color=Color3.fromRGB(table.unpack(best))
 end
 if o:IsA("TextLabel") then o.TextColor3=Color3.fromRGB(215,245,250) end
 if o:IsA("PointLight") then o.Color=Color3.fromRGB(225,244,255) o.Brightness=.65 end
end
local floors=root["01 Floor and Paths"]
for _,o in floors:GetChildren() do
 if o.Name=="Promenade confetti" then o:Destroy()
 elseif o.Name:find("Central cream") then o.Name=o.Name:gsub("cream","grey")
 elseif o.Name:find("pastel") then o.Name=o.Name:gsub("pastel","teal") end
end
local walls=root["02 Walls and Arches"]
for _,o in walls:GetChildren() do
 if o.Name:find("Rainbow") or o.Name:find("cloud") or o.Name=="Column bubble cap" then o:Destroy()
 elseif o.Name=="Cloud club subtitle" then
  o.Name="G-Blox tagline"
  o.Lettering.TextLabel.Text="RACE. FLIP. WIN."
 elseif o.Name=="G-BLOX welcome sign" then
  o.Color=Color3.fromRGB(18,48,71)
 end
end
local roof=root["03 CLOSED Roof and Clouds"]
for _,o in roof:GetChildren() do
 if o.Name:find("Ceiling cloud") or o.Name=="Star string" or o.Name=="Five point star" then o:Destroy() end
end
roof.Name="03 CLOSED Roof"
local stage=root["04 Cloud Stage and Stairs"]
stage.Name="04 Raised Platform and Stairs"
for _,o in stage:GetChildren() do
 if o.Name=="Gallery bubble" then o:Destroy() else o.Name=o.Name:gsub("Cloud","Arena"):gsub("candy","teal"):gsub("Bubble","Smooth") end
end
root["05 Happy Gravity Statue"]:Destroy()
root["07 Decorations"]:Destroy()
local centerpiece=Instance.new("Model") centerpiece.Name="05 Reused Podium and Lightning" centerpiece.Parent=root
local decor=Instance.new("Model") decor.Name="07 Original G-Blox Decor" decor.Parent=root
local displays=Instance.new("Model") displays.Name="09 Reused Leaderboard - visual copy" displays.Parent=root
local C={teal=Color3.fromRGB(0,202,214), navy=Color3.fromRGB(18,48,71), grey=Color3.fromRGB(137,160,175), white=Color3.fromRGB(214,230,238), blue=Color3.fromRGB(35,108,149)}
local function part(n,size,pos,c,parent)
 local p=Instance.new("Part") p.Name=n p.Size=size p.CFrame=CFrame.new(O+pos)
 p.Color=C[c] p.Material=Enum.Material.SmoothPlastic p.Anchored=true p.CanCollide=false p.CanTouch=false p.TopSurface=Enum.SurfaceType.Smooth p.BottomSurface=Enum.SurfaceType.Smooth p.Parent=parent or decor return p
end
local function visualOnly(m)
 for _,o in m:GetDescendants() do
  if o:IsA("LuaSourceContainer") or o:IsA("ProximityPrompt") or o:IsA("ClickDetector") then o:Destroy()
  elseif o:IsA("BasePart") then o.Anchored=true o.CanTouch=false end
 end
end
-- Use actual authored podium bevels, not a newly invented pastel plinth.
local podium=Instance.new("Model") podium.Name="Original Gravity Podium - architecture only" podium.Parent=centerpiece
for _,o in W["Pet Podium Gravity"]:GetChildren() do
 if o:IsA("BasePart") and (o.Name:match("_Base$") or o.Name:match("_Plinth$") or o.Name:match("_Trim$") or o.Name:match("_Top$")) then
  local p=o:Clone() p.Anchored=true p.CanTouch=false p.Parent=podium
  if p.Name:match("_Trim$") then p.Color=C.teal elseif p.Name:match("_Top$") then p.Color=C.white elseif p.Name:match("_Base$") then p.Color=C.navy else p.Color=C.grey end
 end
end
podium:ScaleTo(1.9)
do local cf,s=podium:GetBoundingBox() local target=O+Vector3.new(0,s.Y/2,16) podium:PivotTo(CFrame.new(target-cf.Position)*podium:GetPivot()) end
local sourceBolt
for _,o in W.Decor:GetDescendants() do
 if o:IsA("MeshPart") and o.Name=="Lightning_Decor_Bolt_1" then sourceBolt=o break end
end
assert(sourceBolt,"Existing lightning mesh unavailable")
local function bolt(n,x,y,z,h,yaw,parent)
 local p=sourceBolt:Clone() p.Name=n
 p.Size=sourceBolt.Size*(h/sourceBolt.Size.Y)
 p.CFrame=CFrame.new(O+Vector3.new(x,y,z))*CFrame.Angles(0,yaw or 0,0)
 p.Color=C.teal p.Material=Enum.Material.SmoothPlastic p.Anchored=true p.CanCollide=false p.CanTouch=false
 p.Parent=parent or decor return p
end
local _,ps=podium:GetBoundingBox()
bolt("Original bolt - centrepiece",0,ps.Y+10,16,20,0,centerpiece)
-- Small authored orbit references the original gravity stand.
local orbit=W["Pet Podium Gravity"]:FindFirstChild("Pet_Podium_Gravity_GravityOrbit"):Clone()
orbit.Name="Original gravity orbit"; orbit.Size=orbit.Size*2.8
orbit.CFrame=CFrame.new(O+Vector3.new(0,ps.Y+10,17))*orbit.CFrame.Rotation
orbit.Color=C.blue orbit.Anchored=true orbit.CanCollide=false orbit.CanTouch=false orbit.Parent=centerpiece
for _,x in {-65,65,-116,116} do bolt("Rear wall lightning",x,28,94.5,12,0) end
for _,side in {-1,1} do for _,z in {-72,-20,32,78} do
 bolt("Side wall lightning",side*137,24,z,10,side*math.pi/2)
end end
-- Reuse leaderboard visuals; keep the live originals/scripts where they are.
local leader=W.LeaderboardDisplay:Clone() leader.Name="LeaderboardDisplay - layout preview"
visualOnly(leader)
leader:SetAttribute("VisualCopyOnly",true)
leader:SetAttribute("Source","Workspace.LeaderboardDisplay")
leader.Parent=displays
do
 local cf,s=leader:GetBoundingBox()
 local transform=CFrame.new(O+Vector3.new(-125,s.Y/2,0))*CFrame.Angles(0,math.pi,0)*CFrame.new(-cf.Position)
 leader:PivotTo(transform*leader:GetPivot())
end
-- Floor speed-chevron graphics instead of confetti.
for _,x in {-43,43} do for z=-69,35,26 do for _,dx in {-1,1} do
 local p=part("Floor speed chevron",Vector3.new(1,.06,5),Vector3.new(x+dx*1.6,.13,z), "teal",floors)
 p.CFrame=p.CFrame*CFrame.Angles(0,dx*math.rad(42),0)
end end end
-- Calm architectural benches; no bubble trees.
for _,pos in {{-82,-79,0},{68,-78,0},{-61,85,8.4},{61,85,8.4}} do
 local x,z,y=table.unpack(pos)
 local seat=part("Grey bench",Vector3.new(15,1,5),Vector3.new(x,y+2.8,z),"grey")
 seat.CanCollide=true
 for _,dx in {-5,5} do local p=part("Bench leg",Vector3.new(1.5,2.4,3.5),Vector3.new(x+dx,y+1.2,z),"navy") p.CanCollide=true end
 part("Teal bench trim",Vector3.new(14,.22,.16),Vector3.new(x,y+2.8,z-2.6),"teal")
end
local obby=root["06 Practice Obby"]
for _,o in obby:GetChildren() do
 if o.Name=="Practice sign" then o.Lettering.TextLabel.Text="PRACTICE" o.Color=C.navy end
 o.Name=o.Name:gsub("soft","")
end
for _,o in root["08 Lighting"]:GetChildren() do
 if o:IsA("BasePart") then
  if o.Name=="Cloud lamp" then o.Name="Ceiling light panel" o.Shape=Enum.PartType.Block o.Size=Vector3.new(2,.25,10) o.Position=Vector3.new(o.Position.X,O.Y+47.8,o.Position.Z)
  else o.Name="Podium accent light" end
  o.Color=Color3.fromRGB(205,244,255)
 end
end
-- Change names that still imply the removed cloud/toy theme.
for _,o in root:GetDescendants() do
 if not o:IsA("TextLabel") then o.Name=o.Name:gsub("Candy","Teal"):gsub("candy","teal"):gsub("Pastel","Blue"):gsub("Soft","Smooth") end
end
local storage=game:GetService("ServerStorage")
local backups=storage:FindFirstChild("G-Blox Lobby Design Backups") or Instance.new("Folder")
backups.Name="G-Blox Lobby Design Backups" backups.Parent=storage
game:GetService("ChangeHistoryService"):SetWaypoint("Before G-Blox teal revision")
previous.Name="Archived Cloud Club "..os.date("!%Y%m%d_%H%M%S")
previous.Parent=backups
root.Parent=W
game:GetService("Selection"):Set({root})
W.CurrentCamera.CFrame=CFrame.lookAt(O+Vector3.new(88,22,-82),O+Vector3.new(-12,20,28))
game:GetService("ChangeHistoryService"):SetWaypoint("G-Blox blue grey teal revision")
local count=0 for _,o in root:GetDescendants() do if o:IsA("BasePart") then count+=1 end end
return game:GetService("HttpService"):JSONEncode({name=root.Name,parts=count,backup=previous:GetFullName(),originalLobby=W.Lobby:GetFullName(),leaderboard="Visual copy; original remains live"})

