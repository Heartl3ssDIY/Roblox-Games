local name = "Tag You're It"
local existing = workspace:FindFirstChild(name)
if existing then
 return {built=false,reason="Existing Tag You're It folder preserved",folder=existing:GetFullName()}
end

local center = Vector3.new(6500,32.9,4534)
local navy = Color3.fromRGB(27,45,61)
local cream = Color3.fromRGB(255,243,200)
local white = Color3.fromRGB(255,253,240)
local grass = Color3.fromRGB(129,201,76)
local grassLight = Color3.fromRGB(142,213,88)
local blue = Color3.fromRGB(76,182,238)
local coral = Color3.fromRGB(255,127,121)
local gold = Color3.fromRGB(255,203,68)
local mint = Color3.fromRGB(92,209,166)
local purple = Color3.fromRGB(181,153,236)
local arena = Instance.new("Folder")
arena.Name = name
local function folder(label,parent)
 local result = Instance.new("Folder")
 result.Name = label
 result.Parent = parent
 return result
end
local geometry = folder("Geometry",arena)
local scenery = folder("Scenery",arena)
local gameplay = folder("Gameplay",arena)
local perimeter = folder("Perimeter",geometry)
local floorArt = folder("FloorArtwork",geometry)
local routes = folder("ParkourRoutes",geometry)
local vaults = folder("VaultObstacles",gameplay)
local navObstacles = {}
local routeStats = {}
local totalParts = 0

local function recordObstacle(p)
 if not p.CanCollide then return end
 local minimum = Vector3.new(math.huge,math.huge,math.huge)
 local maximum = Vector3.new(-math.huge,-math.huge,-math.huge)
 for _,x in ipairs({-1,1}) do
  for _,y in ipairs({-1,1}) do
   for _,z in ipairs({-1,1}) do
    local q = p.CFrame:PointToWorldSpace(Vector3.new(x*p.Size.X/2,y*p.Size.Y/2,z*p.Size.Z/2))-center
    minimum = Vector3.new(math.min(minimum.X,q.X),math.min(minimum.Y,q.Y),math.min(minimum.Z,q.Z))
    maximum = Vector3.new(math.max(maximum.X,q.X),math.max(maximum.Y,q.Y),math.max(maximum.Z,q.Z))
   end
  end
 end
 if minimum.Y < 7.8 and maximum.Y > 0.2 then
  table.insert(navObstacles,{x1=minimum.X-3.3,x2=maximum.X+3.3,z1=minimum.Z-3.3,z2=maximum.Z+3.3})
 end
end
local function part(label,size,position,color,parent,collidable,shape)
 local p = Instance.new("Part")
 p.Name = label
 p.Size = size
 p.Position = center+position
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
 totalParts += 1
 return p
end
local function block(label,x,y,z,px,py,pz,color,parent,collidable)
 local p = part(label,Vector3.new(x,y,z),Vector3.new(px,py,pz),color,parent,collidable)
 recordObstacle(p)
 return p
end
local function cylinder(label,diameter,height,position,color,parent,collidable)
 local p = part(label,Vector3.new(height,diameter,diameter),position,color,parent,collidable,Enum.PartType.Cylinder)
 p.CFrame = CFrame.new(p.Position)*CFrame.Angles(0,0,math.pi/2)
 recordObstacle(p)
 return p
end
local function sphere(label,size,position,color,parent)
 return part(label,size,position,color,parent,false,Enum.PartType.Ball)
end
local function paint(label,x,z,px,pz,color,parent,y)
 return block(label,x,0.06,z,px,y or 0.035,pz,color,parent,false)
end
local function deck(label,x,z,px,pz,top,color,parent,routeId,width)
 local p = block(label.."Ink",x,1.2,z,px,top-0.6,pz,navy,parent,true)
 p:SetAttribute("Walkable",true)
 p:SetAttribute("RouteId",routeId)
 p:SetAttribute("TopHeight",top)
 p:SetAttribute("PathWidth",width or math.min(x,z))
 block(label.."Surface",x-0.55,0.12,z-0.55,px,top+0.06,pz,color,parent,false)
 return p
end
local function support(label,px,pz,height,parent)
 block(label.."Ink",3.4,height,3.4,px,height/2,pz,navy,parent,true)
 block(label.."Cream",2.5,height-0.5,3.5,px,height/2,pz,cream,parent,false)
end
local function ramp(label,p0,p1,width,color,parent,routeId)
 local a,b = center+p0,center+p1
 local direction = b-a
 local frame = CFrame.lookAt((a+b)/2,b)
 frame -= frame.UpVector*0.7
 local p = part(label.."Ink",Vector3.new(width,1.4,direction.Magnitude),Vector3.zero,navy,parent,true)
 p.CFrame = frame
 p:SetAttribute("Walkable",true)
 p:SetAttribute("IsRamp",true)
 p:SetAttribute("RouteId",routeId)
 p:SetAttribute("PathWidth",width)
 p:SetAttribute("Rise",math.abs(p1.Y-p0.Y))
 p:SetAttribute("Run",Vector2.new(p1.X-p0.X,p1.Z-p0.Z).Magnitude)
 p:SetAttribute("FromHeight",p0.Y)
 p:SetAttribute("ToHeight",p1.Y)
 recordObstacle(p)
 local surface = part(label.."Surface",Vector3.new(width-0.6,0.1,direction.Magnitude-0.2),Vector3.zero,color,parent,false)
 surface.CFrame = frame+frame.UpVector*0.75
 for _,side in ipairs({-1,1}) do
  local rail = part(label.."Edge",Vector3.new(0.5,0.08,direction.Magnitude-0.4),Vector3.zero,cream,parent,false)
  rail.CFrame = frame+frame.UpVector*0.84+frame.RightVector*(side*(width/2-0.8))
 end
 return p
end
local function stair(label,x,z,px,pz,top,color,parent,routeId)
 local p = block(label.."Ink",x,top,z,px,top/2,pz,navy,parent,true)
 p:SetAttribute("Walkable",true)
 p:SetAttribute("IsStep",true)
 p:SetAttribute("RouteId",routeId)
 p:SetAttribute("TopHeight",top)
 p:SetAttribute("StepRise",4)
 p:SetAttribute("PathWidth",math.min(x,z))
 block(label.."Surface",x-0.35,0.1,z-0.35,px,top+0.05,pz,color,parent,false)
 return p
end

block("IslandEarth",448,48,448,0,-34,0,Color3.fromRGB(159,102,65),geometry,true)
block("IslandInk",448,10,448,0,-5,0,navy,geometry,true)
block("GrassCourt",416,2,416,0,-1,0,grass,geometry,true)
for _,side in ipairs({-1,1}) do
 block("GrassLipX",8,4,440,side*221,-3,0,Color3.fromRGB(96,172,63),geometry,false)
 block("GrassLipZ",448,4,8,0,-3,side*221,Color3.fromRGB(96,172,63),geometry,false)
 block("EarthStripeX",0.2,10,448,side*224.1,-38,0,Color3.fromRGB(194,140,92),geometry,false)
 block("EarthStripeZ",448,10,0.2,0,-38,side*224.1,Color3.fromRGB(194,140,92),geometry,false)
end
for index=-6,6 do
 paint("MownGrass"..index,30,416,index*32,0,index%2==0 and grassLight or grass,floorArt)
end
paint("NorthSouthPathInk",30,380,0,0,Color3.fromRGB(107,174,73),floorArt,0.10)
paint("NorthSouthPath",24,376,0,0,cream,floorArt,0.15)
paint("EastWestPathInk",380,30,0,0,Color3.fromRGB(107,174,73),floorArt,0.10)
paint("EastWestPath",376,24,0,0,cream,floorArt,0.15)
cylinder("CentralPlazaInk",92,0.10,Vector3.new(0,0.22,0),navy,floorArt,false)
cylinder("CentralPlazaCream",88,0.10,Vector3.new(0,0.29,0),cream,floorArt,false)
cylinder("CentralPlazaMint",68,0.10,Vector3.new(0,0.36,0),Color3.fromRGB(202,236,164),floorArt,false)
cylinder("TaggerCircleInk",22,0.10,Vector3.new(0,0.43,0),navy,floorArt,false)
cylinder("TaggerCircleWhite",18,0.10,Vector3.new(0,0.50,0),white,floorArt,false)
cylinder("TaggerCircleGold",12,0.10,Vector3.new(0,0.57,0),gold,floorArt,false)
for index=1,12 do
 local angle = index*math.pi/6
 cylinder("PlazaDot"..index,3.5,0.08,Vector3.new(math.cos(angle)*39,0.39,math.sin(angle)*39),index%2==0 and white or gold,floorArt,false)
end

for _,side in ipairs({-1,1}) do
 paint("StartingBorderInk",386,6.5,0,side*190,navy,floorArt,0.18)
 paint("StartingBorderWhite",382,4,0,side*190,white,floorArt,0.25)
 paint("StartingBorderInk",6.5,374,side*190,0,navy,floorArt,0.18)
 paint("StartingBorderWhite",4,376,side*190,0,white,floorArt,0.25)
 local x,z = side*212,side*212
 block("WestEastFenceInk",8,16,432,x,8,0,navy,perimeter,true)
 block("WestEastFenceBlue",0.25,11,420,x-side*4.15,8,0,blue,perimeter,false)
 block("WestEastFenceCapInk",10,2.8,434,x,16.7,0,navy,perimeter,false)
 block("WestEastFenceCapCream",8.8,1.6,432,x,17.2,0,cream,perimeter,false)
 block("NorthSouthFenceInk",432,16,8,0,8,z,navy,perimeter,true)
 block("NorthSouthFenceBlue",420,11,0.25,0,8,z-side*4.15,blue,perimeter,false)
 block("NorthSouthFenceCapInk",434,2.8,10,0,16.7,z,navy,perimeter,false)
 block("NorthSouthFenceCapCream",432,1.6,8.8,0,17.2,z,cream,perimeter,false)
 for index=-6,6 do
  local coordinate = index*32
  block("FenceColumnInk",8.5,19,6,x,9.5,coordinate,navy,perimeter,false)
  block("FenceColumnCream",8.6,17,4,x,9.6,coordinate,cream,perimeter,false)
  block("FenceColumnInk",6,19,8.5,coordinate,9.5,z,navy,perimeter,false)
  block("FenceColumnCream",4,17,8.6,coordinate,9.6,z,cream,perimeter,false)
  sphere("FenceButton",Vector3.new(6,6,6),Vector3.new(x,21,coordinate),index%2==0 and gold or white,perimeter)
  sphere("FenceButton",Vector3.new(6,6,6),Vector3.new(coordinate,21,z),index%2==0 and gold or white,perimeter)
 end
end

local courses = {
 {id="Sunbeam",x=-102,z=-102,color=gold,accent=Color3.fromRGB(255,231,143),kind="Steps"},
 {id="CoralRoofs",x=102,z=-102,color=coral,accent=Color3.fromRGB(255,183,165),kind="Roof"},
 {id="Wavewalk",x=-102,z=102,color=blue,accent=Color3.fromRGB(155,221,250),kind="Stones"},
 {id="MintTerrace",x=102,z=102,color=mint,accent=Color3.fromRGB(168,237,194),kind="Terrace"},
}
for _,course in ipairs(courses) do
 local c = folder(course.id,routes)
 c:SetAttribute("RouteId",course.id)
 c:SetAttribute("MainHeight",12)
 c:SetAttribute("MainWidth",16)
 c:SetAttribute("AccessCount",2)
 c:SetAttribute("MaximumStepRise",4)
 c:SetAttribute("MaximumJumpGap",4)
 c:SetAttribute("ContinuousGroundRoute",true)
 c:SetAttribute("CenterX",course.x)
 c:SetAttribute("CenterZ",course.z)
 local x,z = course.x,course.z
 paint("GardenPatchInk",120,120,x,z,Color3.fromRGB(103,172,70),c,0.1)
 paint("GardenPatch",116,116,x,z,Color3.fromRGB(176,221,118),c,0.15)
 paint("PatioInk",74,74,x,z,navy,c,0.22)
 paint("Patio",70,70,x,z,course.accent,c,0.29)
 for _,side in ipairs({-1,1}) do
  deck("LoopNorthSouth"..side,112,16,x,z+side*48,12,course.color,c,course.id,16)
  deck("LoopWestEast"..side,16,80,x+side*48,z,12,course.color,c,course.id,16)
  paint("LoopLane",100,1.0,x,z+side*48,cream,c,12.16)
  paint("LoopLane",1.0,70,x+side*48,z,cream,c,12.16)
  for _,other in ipairs({-1,1}) do support("LoopPillar",x+side*48,z+other*48,10.8,c) end
 end
 local signX,signZ = math.sign(x),math.sign(z)
 ramp("OuterWestEastRamp",Vector3.new(x+signX*80,0.18,z),Vector3.new(x+signX*48,12,z),18,course.color,c,course.id)
 ramp("OuterNorthSouthRamp",Vector3.new(x,0.18,z+signZ*80),Vector3.new(x,12,z+signZ*48),18,course.color,c,course.id)
 for index=1,3 do
  local pz = z+signZ*(17+index*8)
  local access=stair("PatioAccess"..index,14,8,x,pz,index*4,course.color,c,course.id)
  access:SetAttribute("PathWidth",14)
 end
 for _,side in ipairs({-1,1}) do
  local vaultX = x+side*22
  local vault = block(course.id.."Vault"..side,24,2.8,3,vaultX,1.4,z+side*26,navy,vaults,true)
  vault:SetAttribute("Vaultable",true)
  vault:SetAttribute("VaultHeight",2.8)
  vault:SetAttribute("RouteId",course.id)
  vault:SetAttribute("ApproachClearance",10)
  block("VaultFace",23.4,1.9,3.1,vaultX,1.7,z+side*26,course.color,vaults,false)
  block("VaultTop",23.6,0.3,3.2,vaultX,2.95,z+side*26,cream,vaults,false)
 end
 local maximumHeight = 12
 if course.kind == "Steps" then
  for index=1,5 do
   local top = math.min(index*3,12)
   local px = x-34+(index-1)*18
   local p = stair("SkippingStep"..index,14,14,px,z,top,course.color,c,course.id)
   p:SetAttribute("StepRise",3)
   p:SetAttribute("JumpGap",4)
   paint("StepDot",4,4,px,z,cream,c,top+0.14)
  end
 elseif course.kind == "Roof" then
  maximumHeight = 20
  deck("CoralRoof",28,32,x,z,20,course.color,c,course.id,28)
  for _,side in ipairs({-1,1}) do
   deck("RoofLanding",16,16,x+side*34,z,16,course.accent,c,course.id,16)
   deck("RoofApproach",12,16,x+side*20,z,20,course.color,c,course.id,12)
   support("RoofPillar",x+side*10,z-12,18.8,c)
   support("RoofPillar",x+side*10,z+12,18.8,c)
  end
  paint("RoofStripe",4,25,x,z,cream,c,20.16)
 elseif course.kind == "Stones" then
  paint("BluePatioInk",66,40,x,z,navy,c,0.34)
  paint("BluePatio",62,36,x,z,Color3.fromRGB(103,205,238),c,0.41)
  for index=1,4 do
   local top = 2+(index-1)*3
   local px = x-30+(index-1)*20
   local p = cylinder("SkippingStoneInk"..index,16,top,Vector3.new(px,top/2,z),navy,c,true)
   p:SetAttribute("Walkable",true)
   p:SetAttribute("RouteId",course.id)
   p:SetAttribute("PathWidth",16)
   p:SetAttribute("TopHeight",top)
   p:SetAttribute("JumpGap",4)
   p:SetAttribute("StepRise",3)
   cylinder("SkippingStoneTop"..index,15.4,0.12,Vector3.new(px,top+0.06,z),course.accent,c,false)
   cylinder("SkippingStoneDot"..index,4,0.1,Vector3.new(px,top+0.16,z),white,c,false)
  end
 elseif course.kind == "Terrace" then
  maximumHeight = 24
  deck("MintTopDeck",32,32,x,z,24,purple,c,course.id,32)
  for _,side in ipairs({-1,1}) do
   deck("TerraceStep1",12,16,x+side*34,z,16,course.accent,c,course.id,12)
   deck("TerraceStep2",12,16,x+side*22,z,20,course.color,c,course.id,12)
   support("TerracePillar",x+side*12,z-12,22.8,c)
   support("TerracePillar",x+side*12,z+12,22.8,c)
  end
  cylinder("TerraceMedallionInk",15,0.08,Vector3.new(x,24.18,z),navy,c,false)
  cylinder("TerraceMedallion",12,0.09,Vector3.new(x,24.25,z),cream,c,false)
 end
 c:SetAttribute("MaximumHeight",maximumHeight)
 table.insert(routeStats,{id=course.id,mainHeight=12,maximumHeight=maximumHeight,width=16,accesses=2,maxGap=4,maxStepRise=4})
 for _,offset in ipairs({Vector3.new(-29,0,-29),Vector3.new(29,0,29)}) do
  local px,pz = x+offset.X,z+offset.Z
  cylinder("PlanterInk",12,1.0,Vector3.new(px,0.5,pz),navy,c,false)
  cylinder("PlanterCream",10.5,0.8,Vector3.new(px,0.9,pz),cream,c,false)
  for index=-1,1 do
   sphere("SoftShrub",Vector3.new(7,6,7),Vector3.new(px+index*3.5,3.8,pz),index==0 and Color3.fromRGB(166,218,85) or Color3.fromRGB(95,170,77),c)
  end
 end
end

local bridges = folder("LinkBridges",routes)
for _,side in ipairs({-1,1}) do
 deck("NorthSouthLink"..side,96,16,0,side*102,12,white,bridges,"SharedLinks",16)
 deck("WestEastLink"..side,16,96,side*102,0,12,white,bridges,"SharedLinks",16)
 paint("LinkStripe",86,3,0,side*102,gold,bridges,12.16)
 paint("LinkStripe",3,86,side*102,0,gold,bridges,12.16)
 for _,other in ipairs({-1,1}) do
  support("LinkPillar",other*31,side*102,10.8,bridges)
  support("LinkPillar",side*102,other*31,10.8,bridges)
 end
end

local trees = folder("BubbleTrees",scenery)
local function tree(index,px,pz)
 local model = Instance.new("Model")
 model.Name = "BubbleTree"..string.format("%02d",index)
 model.Parent = trees
 local height = 22+(index%4)*3
 block("TrunkInk",6.0,height,6.0,px,height/2,pz,Color3.fromRGB(68,82,54),model,false)
 block("Trunk",4.5,height,4.5,px,height/2,pz,Color3.fromRGB(158,110,70),model,false)
 for branch,offset in ipairs({Vector3.new(0,height+7,0),Vector3.new(-7,height+1,3),Vector3.new(7,height+3,-2)}) do
  local q = Vector3.new(px,0,pz)+offset
  sphere("LeafInk"..branch,Vector3.new(23,23,23),q,Color3.fromRGB(50,115,63),model)
  sphere("Leaf"..branch,Vector3.new(22.5,22.5,22.5),q+Vector3.new(0,1.7,0),branch==2 and Color3.fromRGB(168,219,79) or Color3.fromRGB(112,190,76),model)
 end
end
local treeIndex = 0
for _,side in ipairs({-1,1}) do
 for index=-5,5 do
  treeIndex += 1
  tree(treeIndex,side*(238+(index%3)*7),index*43)
  treeIndex += 1
  tree(treeIndex,index*43,side*(238+((index+1)%3)*7))
 end
end
for index=1,24 do
 local side = index%4
 local along = -165+math.floor((index-1)/4)*66
 local px,pz
 if side==0 then px,pz=-201,along elseif side==1 then px,pz=201,along elseif side==2 then px,pz=along,-201 else px,pz=along,201 end
 for petal=1,4 do
  local angle = petal*math.pi/2
  sphere("FlowerPetal",Vector3.new(2.3,1.2,2.3),Vector3.new(px+math.cos(angle)*1.4,0.7,pz+math.sin(angle)*1.4),index%3==0 and coral or index%3==1 and purple or white,scenery)
 end
 sphere("FlowerCenter",Vector3.new(1.6,1.2,1.6),Vector3.new(px,1.0,pz),gold,scenery)
end

local bounds = block("ArenaBounds",416,100,416,0,50,0,navy,gameplay,false)
bounds.Transparency = 1
local pads = folder("StartPads",gameplay)
local spawnLocations = {}
for side=1,4 do
 for index=1,6 do
  local along = -150+(index-1)*60
  local x,z
  if side==1 then x,z=along,-190 elseif side==2 then x,z=190,along elseif side==3 then x,z=-along,190 else x,z=-190,-along end
  local id = (side-1)*6+index
  local pad = block(string.format("%02d",id),1,1,1,x,3.6,z,white,pads,false)
  pad.Transparency = 1
  pad.CFrame = CFrame.lookAt(pad.Position,Vector3.new(center.X,pad.Position.Y,center.Z))
  table.insert(spawnLocations,{x=x,z=z})
  cylinder("BorderStartInk"..id,8.2,0.08,Vector3.new(x,0.32,z),navy,floorArt,false)
  cylinder("BorderStartWhite"..id,6.7,0.08,Vector3.new(x,0.40,z),white,floorArt,false)
  cylinder("BorderStartBlue"..id,3.2,0.08,Vector3.new(x,0.48,z),blue,floorArt,false)
 end
end
local taggerSpawn = block("TaggerSpawn",1,1,1,0,3.6,0,coral,gameplay,false)
taggerSpawn.Transparency = 1

local function pointClear(x,z)
 for _,obstacle in ipairs(navObstacles) do
  if x>=obstacle.x1 and x<=obstacle.x2 and z>=obstacle.z1 and z<=obstacle.z2 then return false end
 end
 return true
end
local function segmentClear(a,b)
 local dx,dz = b.x-a.x,b.z-a.z
 for _,obstacle in ipairs(navObstacles) do
  local lo,hi = 0,1
  for _,axis in ipairs({{a.x,dx,obstacle.x1,obstacle.x2},{a.z,dz,obstacle.z1,obstacle.z2}}) do
   if math.abs(axis[2])<0.0001 then
    if axis[1]<axis[3] or axis[1]>axis[4] then lo=2 break end
   else
    local u,v = (axis[3]-axis[1])/axis[2],(axis[4]-axis[1])/axis[2]
    lo,hi = math.max(lo,math.min(u,v)),math.min(hi,math.max(u,v))
   end
  end
  if lo<=hi and lo<=1 and hi>=0 then return false end
 end
 return true
end
local navigation = folder("NavigationNodes",gameplay)
local nodeData = {}
local function node(x,z,isSpawn)
 if not pointClear(x,z) then return end
 local id = string.format("NN%03d",#nodeData+1)
 local p = block(id,0.7,0.7,0.7,x,3.6,z,navy,navigation,false)
 p.Transparency = 1
 p:SetAttribute("GroundNode",true)
 p:SetAttribute("SpawnNode",isSpawn==true)
 table.insert(nodeData,{x=x,z=z,part=p,neighbors={}})
end
for x=-180,180,30 do for z=-180,180,30 do node(x,z,false) end end
for _,q in ipairs(spawnLocations) do node(q.x,q.z,true) end
for a=1,#nodeData do
 for b=a+1,#nodeData do
  local q,r = nodeData[a],nodeData[b]
  local distance = Vector2.new(q.x-r.x,q.z-r.z).Magnitude
  if distance<=64 and segmentClear(q,r) then
   table.insert(q.neighbors,r.part.Name)
   table.insert(r.neighbors,q.part.Name)
  end
 end
end
local lookup = {}
for _,q in ipairs(nodeData) do
 table.sort(q.neighbors)
 q.part:SetAttribute("Neighbors",table.concat(q.neighbors,","))
 q.part:SetAttribute("Neighbor",table.concat(q.neighbors,","))
 lookup[q.part.Name] = q
end
local visited,queue = {},{}
if #nodeData>0 then visited[nodeData[1].part.Name]=true queue[1]=nodeData[1] end
local at = 1
while queue[at] do
 local q = queue[at]
 at += 1
 for _,neighbor in ipairs(q.neighbors) do
  if not visited[neighbor] then visited[neighbor]=true table.insert(queue,lookup[neighbor]) end
 end
end
assert(#queue==#nodeData,"Tag navigation graph is disconnected; build was not installed")
assert(#nodeData>=100,"Tag arena has too few ground navigation nodes")
assert(#pads:GetChildren()==24,"Tag arena must have 24 starting pads")
for key,value in pairs({RoundDuration=180,CountdownSeconds=3,ResultsSeconds=7,TaggerWalkSpeed=18,RunnerWalkSpeed=16,MinimumPlayers=2,AutoStart=false,WinRule="MostTaggerTime",CourtWidth=416,CourtLength=416,FloorY=32.9,MaximumRouteHeight=24,BuildVersion="20261003"}) do arena:SetAttribute(key,value) end
arena:SetAttribute("NavigationNodeCount",#nodeData)
arena:SetAttribute("ParkourRouteCount",4)
arena:SetAttribute("GroundNavigationConnected",true)
arena.Parent = workspace
return {built=true,folder=arena:GetFullName(),parts=totalParts,width=416,length=416,area=173056,areaRatioToBulldog=173056/(224*368),floorY=center.Y,startPads=24,navigationNodes=#nodeData,navigationConnected=true,routes=routeStats,vaults=#vaults:GetChildren()/3}
