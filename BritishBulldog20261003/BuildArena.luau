local Physics = game:GetService("PhysicsService")
local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")
local arena = workspace:FindFirstChild("British Bulldog game")
assert(arena, "British Bulldog game folder is missing")
assert(not arena:FindFirstChild("Gameplay"), "Arena has already been built")

local original = arena:GetChildren()
table.sort(original, function(a, b) return a.Position.Z < b.Position.Z end)
local ground, earth, northLine, southLine
for _, p in ipairs(original) do
 if p:IsA("BasePart") then
  if p.Size.Y > 100 then earth = p
  elseif p.Size.Y > 10 then ground = p
  elseif p.Position.Z < 4534 then northLine = p
  else southLine = p end
 end
end
assert(ground and earth and northLine and southLine, "Original four arena parts not found")

local lightingBackup = Instance.new("Folder")
lightingBackup.Name = "BritishBulldogLightingBefore20261003"
for _, p in ipairs({"Brightness", "ClockTime", "Ambient", "OutdoorAmbient", "ExposureCompensation"}) do
 lightingBackup:SetAttribute(p, Lighting[p])
end
for _, v in ipairs(Lighting:GetChildren()) do v:Clone().Parent = lightingBackup end
lightingBackup.Parent = ServerStorage

local navy = Color3.fromRGB(27, 45, 61)
local blue = Color3.fromRGB(55, 148, 229)
local cream = Color3.fromRGB(255, 224, 136)
local gold = Color3.fromRGB(255, 199, 58)
local grass = Color3.fromRGB(129, 201, 76)
local paleGrass = Color3.fromRGB(139, 211, 85)
local cx, cz, floorY = 4626, 4534, 31.5
local function folder(name, parent)
 local f = Instance.new("Folder")
 f.Name = name
 f.Parent = parent
 return f
end
local scenery = folder("CartoonScenery", arena)
local walls = folder("ArenaWalls", arena)
local art = folder("CourtArtwork", arena)
local gameplay = folder("Gameplay", arena)
local function part(name, size, position, color, parent, collidable, shape)
 local p = Instance.new("Part")
 p.Name = name
 p.Size = size
 p.Position = Vector3.new(cx, floorY, cz) + position
 p.Color = color
 p.Material = Enum.Material.SmoothPlastic
 p.Anchored = true
 p.CanCollide = collidable == true
 p.CanTouch = false
 p.CanQuery = collidable == true
 p.CastShadow = collidable == true
 p.TopSurface = Enum.SurfaceType.Smooth
 p.BottomSurface = Enum.SurfaceType.Smooth
 if shape then p.Shape = shape end
 p.Parent = parent
 return p
end
local function block(name, x,y,z, px,py,pz, color,parent,collidable)
 return part(name,Vector3.new(x,y,z),Vector3.new(px,py,pz),color,parent,collidable)
end
local function sphere(name, size, position, color, parent)
 return part(name,size,position,color,parent,false,Enum.PartType.Ball)
end
local function cylinder(name, diameter, height, position, color, parent)
 local p = part(name,Vector3.new(height,diameter,diameter),position,color,parent,false,Enum.PartType.Cylinder)
 p.CFrame = CFrame.new(p.Position) * CFrame.Angles(0,0,math.pi/2)
 return p
end

ground.Name = "IslandGrass"
ground.Color = grass
ground.Material = Enum.Material.SmoothPlastic
ground.Anchored = true
earth.Name = "IslandEarth"
earth.Size = Vector3.new(751, 48, 721)
earth.Position = Vector3.new(cx, -25.5, cz)
earth.Color = Color3.fromRGB(159, 102, 65)
earth.Material = Enum.Material.SmoothPlastic
earth.Anchored = true
for _, side in ipairs({-1,1}) do
 block("IslandSideOutline",8,38,730,side*376,-17,0,navy,scenery,true)
 block("IslandEndOutline",752,38,8,0,-17,side*361,navy,scenery,true)
 block("IslandGrassLip",10,7,728,side*377,-1.5,0,Color3.fromRGB(94,164,56),scenery,true)
 block("IslandGrassLip",752,7,10,0,-1.5,side*362,Color3.fromRGB(94,164,56),scenery,true)
 block("EarthLayer",4,11,724,side*377,-40,0,Color3.fromRGB(195,139,89),scenery,false)
 block("EarthLayer",752,11,4,0,-40,side*362,Color3.fromRGB(195,139,89),scenery,false)
end

block("CourtFoundationOutline",244,1.5,292,0,0.4,0,navy,art,true)
block("CourtFloor",224,0.24,272,0,1.28,0,grass,art,true)
for i=0,6 do
 block("GrassStripe"..i,32,0.05,192,-96+i*32,1.425,0,i%2==0 and paleGrass or grass,art,false)
end
for _,side in ipairs({-1,1}) do
 block("SafeEndOutline",224,0.10,37,0,1.48,side*113.5,navy,art,false)
 block("SafeEndBlue",220,0.07,34,0,1.565,side*114,Color3.fromRGB(81,186,238),art,false)
 for i=-4,4 do
  block("SafeEndStripe",12,0.04,34,i*24,1.62,side*114,Color3.fromRGB(107,207,251),art,false)
 end
 local z=side*140
 block("EndWallOutline",240,25,8,0,13,z,navy,walls,true)
 block("EndWallFace",226,18,0.25,0,13,z-side*4.14,blue,walls,false)
 block("EndWallFaceOuter",226,18,0.25,0,13,z+side*4.14,blue,walls,false)
 block("EndWallCapOutline",242,5,10,0,26,z,navy,walls,false)
 block("EndWallYellowCap",238,2.8,8,0,26.5,z,gold,walls,false)
 block("EndWallLowerTrim",228,1,0.35,0,5,z-side*4.3,cream,walls,false)
 for i=-3,3 do
  local x=i*36
  block("WallPillarOutline",7,27,9,x,13.5,z,navy,walls,false)
  block("WallPillarCream",4.6,24,9.1,x,13.5,z,cream,walls,false)
  sphere("PillarBallOutline",Vector3.new(7,7,7),Vector3.new(x,30,z),navy,walls)
  sphere("PillarBallYellow",Vector3.new(7.6,7.6,7.6),Vector3.new(x,30.7,z),gold,walls)
 end
end
for _, side in ipairs({-1,1}) do
 local x=side*116
 block("SideWallOutline",8,25,280,x,13,0,navy,walls,true)
 block("SideWallFace",0.25,18,267,x-side*4.14,13,0,blue,walls,false)
 block("SideWallFaceOuter",0.25,18,267,x+side*4.14,13,0,blue,walls,false)
 block("SideWallCapOutline",10,5,282,x,26,0,navy,walls,false)
 block("SideWallYellowCap",8,2.8,278,x,26.5,0,gold,walls,false)
 block("SideWallLowerTrim",0.35,1,267,x-side*4.3,5,0,cream,walls,false)
 for i=-3,3 do
  local z=i*42
  block("WallPillarOutline",9,27,7,x,13.5,z,navy,walls,false)
  block("WallPillarCream",9.1,24,4.6,x,13.5,z,cream,walls,false)
  sphere("PillarBallOutline",Vector3.new(7,7,7),Vector3.new(x,30,z),navy,walls)
  sphere("PillarBallYellow",Vector3.new(7.6,7.6,7.6),Vector3.new(x,30.7,z),gold,walls)
 end
end

for _, item in ipairs({{northLine,"NorthLine",-96},{southLine,"SouthLine",96}}) do
 local p,name,z=table.unpack(item)
 p.Name=name
 p.Size=Vector3.new(224,0.08,3)
 p.Position=Vector3.new(cx,floorY+1.77,cz+z)
 p.Color=Color3.fromRGB(255,251,228)
 p.Material=Enum.Material.SmoothPlastic
 p.Anchored=true
 p.CanCollide=false
 p.CanTouch=false
 p.CastShadow=false
 p.Parent=gameplay
 block(name.."Ink",224,0.08,5.2,0,1.68,z,navy,art,false)
 for i=-4,4 do
  local arrow=block("CrossingChevron",1,0.06,7,i*22,1.57,z+(z<0 and 7 or -7),Color3.fromRGB(248,233,171),art,false)
  arrow.CFrame=arrow.CFrame*CFrame.Angles(0,math.rad(35),0)
  local other=arrow:Clone()
  other.Position=arrow.Position+Vector3.new(4,0,0)
  other.CFrame=CFrame.new(other.Position)*CFrame.Angles(0,math.rad(-35),0)
  other.Parent=art
 end
end

local bounds=block("ArenaBounds",224,100,272,0,50,0,navy,gameplay,false)
bounds.Transparency=1
local barriers=folder("BulldogBarriers",gameplay)
for _,name in ipairs({"BBRunner","BBBulldog","BBTagged","BBBarrier"}) do
 if not Physics:IsCollisionGroupRegistered(name) then Physics:RegisterCollisionGroup(name) end
end
Physics:CollisionGroupSetCollidable("BBBarrier","BBRunner",false)
Physics:CollisionGroupSetCollidable("BBBarrier","BBTagged",false)
Physics:CollisionGroupSetCollidable("BBBarrier","BBBulldog",true)
Physics:CollisionGroupSetCollidable("BBBarrier","Default",false)
for _,side in ipairs({-1,1}) do
 local zone=block(side<0 and "SafeNorth" or "SafeSouth",224,100,40,0,50,side*116,blue,gameplay,false)
 zone.Transparency=1
 local barrier=block(side<0 and "NorthBulldogBarrier" or "SouthBulldogBarrier",232,100,1.5,0,50,side*96,navy,barriers,true)
 barrier.Transparency=1
 barrier.CollisionGroup="BBBarrier"
 barrier.CastShadow=false
end
local northSpawns=folder("RunnersNorth",gameplay)
local southSpawns=folder("RunnersSouth",gameplay)
local bulldogSpawns=folder("BulldogSpawns",gameplay)
for i=1,24 do
 local x=-88+((i-1)%8)*25
 local row=math.floor((i-1)/8)
 for _,side in ipairs({-1,1}) do
  local p=block("Spawn"..string.format("%02d",i),1,1,1,x,5,side*(105+row*10),blue,side<0 and northSpawns or southSpawns,false)
  p.Transparency=1
  p.CFrame=CFrame.lookAt(p.Position,p.Position+Vector3.new(0,0,-side))
 end
 local p=block("Spawn"..string.format("%02d",i),1,1,1,-84+((i-1)%8)*24,5,-24+math.floor((i-1)/8)*24,navy,bulldogSpawns,false)
 p.Transparency=1
end

cylinder("PawPadInk",26,0.08,Vector3.new(0,1.55,0),navy,art)
cylinder("PawPadGold",22.5,0.09,Vector3.new(0,1.61,0),gold,art)
for i, pos in ipairs({Vector3.new(-18,1.56,-12),Vector3.new(-7,1.56,-21),Vector3.new(7,1.56,-21),Vector3.new(18,1.56,-12)}) do
 cylinder("PawToeInk"..i,12,0.08,pos,navy,art)
 cylinder("PawToeGold"..i,9.5,0.09,pos+Vector3.new(0,0.06,0),gold,art)
end

local function titleSign(side)
 local z=side*144
 block("TitlePost",4,18,4,-54,40,z,navy,walls,false)
 block("TitlePost",4,18,4,54,40,z,navy,walls,false)
 local sign=block("BritishBulldogTitle",128,18,2,0,48,z,navy,walls,false)
 local panel=block("TitleCreamPanel",124,14.6,0.2,0,48,z-side*1.12,cream,walls,false)
 local gui=Instance.new("SurfaceGui")
 gui.Name="TitleArtwork"
 gui.Face=side<0 and Enum.NormalId.Back or Enum.NormalId.Front
 gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud
 gui.PixelsPerStud=14
 gui.LightInfluence=0
 gui.Parent=panel
 local text=Instance.new("TextLabel")
 text.Name="Title"
 text.Size=UDim2.fromScale(0.96,0.94)
 text.Position=UDim2.fromScale(0.02,0.03)
 text.BackgroundTransparency=1
 text.FontFace=Font.new("rbxasset://fonts/families/LuckiestGuy.json")
 text.Text="BRITISH BULLDOG"
 text.TextScaled=true
 text.TextColor3=navy
 text.Parent=gui
end
titleSign(-1)
titleSign(1)

local treePositions={{-246,-245},{-178,-267},{-78,-294},{50,-288},{185,-269},{277,-244},{-284,-117},{-303,30},{-272,179},{-202,275},{-75,285},{70,290},{210,263},{285,164},{295,20},{287,-115}}
for i,pos in ipairs(treePositions) do
 local x,z=pos[1],pos[2]
 local h=28+(i%3)*4
 local t=Instance.new("Model")
 t.Name="BubbleTree"..string.format("%02d",i)
 t.Parent=scenery
 block("TrunkInk",7,h,7,x,h/2,z,Color3.fromRGB(54,63,46),t,true)
 block("Trunk",5.4,h,5.4,x,h/2,z,Color3.fromRGB(154,109,65),t,false)
 for j, offset in ipairs({Vector3.new(0,h+8,0),Vector3.new(-11,h,1),Vector3.new(10,h+3,2),Vector3.new(0,h+1,-10)}) do
  local center=Vector3.new(x,0,z)+offset
  sphere("CanopyInk"..j,Vector3.new(27,26,27),center,Color3.fromRGB(53,110,61),t)
  sphere("Canopy"..j,Vector3.new(28,27,28),center+Vector3.new(0,1.7,0),j%2==0 and Color3.fromRGB(168,219,79) or Color3.fromRGB(112,190,76),t)
 end
 local outline=Instance.new("Highlight")
 outline.Name="CartoonOutline"
 outline.Adornee=t
 outline.FillTransparency=1
 outline.OutlineTransparency=0
 outline.OutlineColor=Color3.fromRGB(31,74,48)
 outline.DepthMode=Enum.HighlightDepthMode.Occluded
 outline.Parent=t
end
for i,pos in ipairs({{-165,-177},{165,-183},{-195,139},{173,179},{-316,273},{314,-287},{-342,-275},{332,284}}) do
 local x,z=pos[1],pos[2]
 sphere("BoulderOutline"..i,Vector3.new(26,16,22),Vector3.new(x,5,z),Color3.fromRGB(77,101,99),scenery)
 sphere("Boulder"..i,Vector3.new(23,14,19),Vector3.new(x,6.5,z),Color3.fromRGB(164,189,179),scenery)
 for j=-1,1 do sphere("Shrub"..i.."_"..j,Vector3.new(13,10,13),Vector3.new(x+23+j*9,4,z+4),j==0 and Color3.fromRGB(169,217,77) or Color3.fromRGB(81,156,73),scenery) end
end

for name,value in pairs({RoundDuration=180,DepartureSeconds=5,CountdownSeconds=3,IntermissionSeconds=12,MinimumPlayers=2,AutoStart=true,RunnerWalkSpeed=16,BulldogWalkSpeed=18}) do arena:SetAttribute(name,value) end
arena:SetAttribute("CourtWidth",224)
arena:SetAttribute("CourtLength",272)
arena:SetAttribute("CrossingLength",192)
arena:SetAttribute("BuildVersion","20261003")
Lighting.Brightness=2.4
Lighting.ClockTime=13.5
Lighting.Ambient=Color3.fromRGB(145,158,175)
Lighting.OutdoorAmbient=Color3.fromRGB(160,172,188)
Lighting.ExposureCompensation=0.08
local atmosphere=Lighting:FindFirstChildWhichIsA("Atmosphere")
if atmosphere then atmosphere.Density=0.13 atmosphere.Haze=0.25 atmosphere.Offset=0.1 atmosphere.Color=Color3.fromRGB(208,235,255) end
local dof=Lighting:FindFirstChildWhichIsA("DepthOfFieldEffect")
if dof then dof.Enabled=false end
local bloom=Lighting:FindFirstChildWhichIsA("BloomEffect")
if bloom then bloom.Intensity=0.12 bloom.Threshold=2 bloom.Size=18 end
return {parts=#arena:GetDescendants(),width=224,length=272,crossing=192,floorY=floorY+1.4}
