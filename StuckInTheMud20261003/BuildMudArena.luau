local name="Stuck in the Mud"
local existing=workspace:FindFirstChild(name)
if existing then return {built=false,preserved=true,folder=existing:GetFullName()} end
local center=Vector3.new(8800,32.9,4534)
local ink=Color3.fromRGB(28,43,62)
local cream=Color3.fromRGB(255,239,194)
local white=Color3.fromRGB(255,253,235)
local grass=Color3.fromRGB(134,194,83)
local grassLight=Color3.fromRGB(149,205,97)
local paving=Color3.fromRGB(217,209,183)
local brick=Color3.fromRGB(234,143,112)
local blue=Color3.fromRGB(88,174,224)
local coral=Color3.fromRGB(247,127,113)
local gold=Color3.fromRGB(255,205,77)
local mint=Color3.fromRGB(111,196,151)
local purple=Color3.fromRGB(175,149,218)
local arena=Instance.new("Folder")
arena.Name=name
local function folder(label,parent)
 local object=Instance.new("Folder") object.Name=label object.Parent=parent return object
end
local geometry=folder("Geometry",arena)
local scenery=folder("Scenery",arena)
local gameplay=folder("Gameplay",arena)
local perimeter=folder("Perimeter",geometry)
local artwork=folder("FloorArtwork",geometry)
local landmarks=folder("Landmarks",geometry)
local coverFolder=folder("DistributedCover",geometry)
local elevated=folder("ElevatedRoutes",geometry)
local coverVolumes=folder("CoverVolumes",gameplay)
local rescueAreas=folder("RescueAreas",gameplay)
local obstacleBoxes={}
local coverPositions={}
local partCount=0
local cubbyCount=0
local coverCount=0
local function obstacle(part)
 if not part.CanCollide then return end
 local lo=Vector3.new(math.huge,math.huge,math.huge)
 local hi=Vector3.new(-math.huge,-math.huge,-math.huge)
 for _,x in ipairs({-1,1}) do for _,y in ipairs({-1,1}) do for _,z in ipairs({-1,1}) do
  local point=part.CFrame:PointToWorldSpace(Vector3.new(x*part.Size.X/2,y*part.Size.Y/2,z*part.Size.Z/2))-center
  lo=Vector3.new(math.min(lo.X,point.X),math.min(lo.Y,point.Y),math.min(lo.Z,point.Z))
  hi=Vector3.new(math.max(hi.X,point.X),math.max(hi.Y,point.Y),math.max(hi.Z,point.Z))
 end end end
 if lo.Y<7.8 and hi.Y>0.2 then table.insert(obstacleBoxes,{x1=lo.X-3.2,x2=hi.X+3.2,z1=lo.Z-3.2,z2=hi.Z+3.2}) end
end
local function part(label,size,position,color,parent,collide,shape,rotation)
 local object=Instance.new("Part")
 object.Name=label object.Size=size object.CFrame=CFrame.new(center+position)*(rotation or CFrame.identity)
 object.Color=color object.Material=Enum.Material.SmoothPlastic object.Anchored=true
 object.CanCollide=collide==true object.CanTouch=false object.CanQuery=collide==true object.CastShadow=collide==true
 object.TopSurface=Enum.SurfaceType.Smooth object.BottomSurface=Enum.SurfaceType.Smooth
 if shape then object.Shape=shape end
 object.Parent=parent partCount+=1 obstacle(object) return object
end
local function block(label,x,y,z,px,py,pz,color,parent,collide)
 return part(label,Vector3.new(x,y,z),Vector3.new(px,py,pz),color,parent,collide)
end
local function ball(label,x,y,z,px,py,pz,color,parent)
 return part(label,Vector3.new(x,y,z),Vector3.new(px,py,pz),color,parent,false,Enum.PartType.Ball)
end
local function cylinder(label,diameter,height,position,color,parent,collide)
 return part(label,Vector3.new(height,diameter,diameter),position,color,parent,collide,Enum.PartType.Cylinder,CFrame.Angles(0,0,math.pi/2))
end
local function paint(label,x,z,px,pz,color,y)
 return block(label,x,0.06,z,px,y or 0.045,pz,color,artwork,false)
end
local function line(label,a,b,width,color,y)
 local delta=b-a
 local object=part(label,Vector3.new(width,0.07,delta.Magnitude),Vector3.new((a.X+b.X)/2,y or 0.08,(a.Z+b.Z)/2),color,artwork,false)
 object.CFrame=CFrame.lookAt(object.Position,center+Vector3.new(b.X,y or 0.08,b.Z))
 return object
end
local function surface(label,x,z,px,pz,top,color,parent,route,width)
 local object=block(label.."Ink",x,1.4,z,px,top-0.7,pz,ink,parent,true)
 object:SetAttribute("Walkable",true) object:SetAttribute("RouteId",route) object:SetAttribute("TopHeight",top)
 object:SetAttribute("PathWidth",width or math.min(x,z)) object:SetAttribute("JumpGap",0)
 block(label.."Surface",x-0.5,0.1,z-0.5,px,top+0.05,pz,color,parent,false)
 return object
end
local function ramp(label,p0,p1,width,color,parent,route)
 local a,b=center+p0,center+p1 local delta=b-a
 local frame=CFrame.lookAt((a+b)/2,b)
 local object=Instance.new("Part") object.Name=label.."Ink" object.Size=Vector3.new(width,1.4,delta.Magnitude)
 object.CFrame=frame-frame.UpVector*0.7 object.Color=ink object.Material=Enum.Material.SmoothPlastic
 object.Anchored=true object.CanCollide=true object.CanTouch=false object.CanQuery=true object.Parent=parent
 partCount+=1 obstacle(object)
 object:SetAttribute("Walkable",true) object:SetAttribute("IsRamp",true) object:SetAttribute("RouteId",route)
 object:SetAttribute("PathWidth",width) object:SetAttribute("Rise",math.abs(p1.Y-p0.Y))
 object:SetAttribute("Run",Vector2.new(p1.X-p0.X,p1.Z-p0.Z).Magnitude)
 object:SetAttribute("FromHeight",p0.Y) object:SetAttribute("ToHeight",p1.Y) object:SetAttribute("JumpGap",0)
 local fill=part(label.."Surface",Vector3.new(width-0.6,0.12,delta.Magnitude-0.1),Vector3.zero,color,parent,false)
 fill.CFrame=frame+frame.UpVector*0.06
 for _,side in ipairs({-1,1}) do
  local trim=part(label.."CreamEdge",Vector3.new(0.5,0.14,delta.Magnitude-0.2),Vector3.zero,cream,parent,false)
  trim.CFrame=frame+frame.RightVector*(side*(width/2-0.7))+frame.UpVector*0.15
 end
 return object
end
local function marker(label,position,size,parent)
 local object=part(label,size,position,white,parent,false) object.Transparency=1 object.CastShadow=false return object
end
local function coverVolume(label,position,size,kind)
 local object=marker(label,position,size,coverVolumes)
 object:SetAttribute("CoverKind",kind) object:SetAttribute("NearbyRescueSpace",true)
 coverCount+=1 table.insert(coverPositions,Vector2.new(position.X,position.Z)) return object
end

block("EarthIsland",864,40,864,0,-30,0,Color3.fromRGB(149,104,70),geometry,true)
block("IslandInk",864,8,864,0,-4,0,ink,geometry,true)
block("PlaygroundFloor",832,2,832,0,-1,0,grass,geometry,true)
for index=-8,8 do paint("MownStripe"..index,48,832,index*48,0,index%2==0 and grassLight or grass) end
paint("CentralNorthSouthInk",30,792,0,0,ink,0.1)
paint("CentralNorthSouthPaving",24,788,0,0,cream,0.15)
paint("CentralEastWestInk",792,30,0,0,ink,0.1)
paint("CentralEastWestPaving",788,24,0,0,cream,0.15)
for _,side in ipairs({-1,1}) do
 paint("PerimeterPathX",22,788,side*370,0,paving,0.12)
 paint("PerimeterPathZ",788,22,0,side*370,paving,0.12)
 block("FenceXInk",6,34,844,side*419,17,0,ink,perimeter,true)
 block("FenceZInk",844,34,6,0,17,side*419,ink,perimeter,true)
 block("FenceXPanels",0.3,26,832,side*415.8,16,0,blue,perimeter,false)
 block("FenceZPanels",832,26,0.3,0,16,side*415.8,blue,perimeter,false)
 block("FenceXCap",7.8,1.4,846,side*419,34,0,cream,perimeter,false)
 block("FenceZCap",846,1.4,7.8,0,34,side*419,cream,perimeter,false)
 for index=-8,8 do
  block("FenceXPost",1,30,2,side*415.5,16,index*48,cream,perimeter,false)
  block("FenceZPost",2,30,1,index*48,16,side*415.5,cream,perimeter,false)
 end
end
cylinder("CentralMeetingInk",52,0.12,Vector3.new(0,0.23,0),ink,artwork,false)
cylinder("CentralMeetingCream",48,0.12,Vector3.new(0,0.30,0),cream,artwork,false)
cylinder("CentralMeetingGold",29,0.12,Vector3.new(0,0.37,0),gold,artwork,false)
for index=1,8 do
 local angle=index*math.pi/4
 cylinder("MeetingDot",3.2,0.08,Vector3.new(math.cos(angle)*19,0.41,math.sin(angle)*19),white,artwork,false)
end

local function classroom(index,x,color)
 local room=folder(string.format("Classroom%02d",index),landmarks)
 room:SetAttribute("Landmark","Classroom") room:SetAttribute("TwoExits",true) room:SetAttribute("ExitWidth",16)
 paint("ClassroomPaving",102,82,x,-312,paving,0.07)
 for _,side in ipairs({-1,1}) do
  block("SideWallInk",2.5,21,58,x+side*45,10.5,-312,ink,room,true)
  block("SideWallBrick",0.2,19,56,x+side*43.65,10.5,-312,color,room,false)
  for _,half in ipairs({-1,1}) do
   block("DoorWallInk",36,21,2.5,x+half*27,10.5,-312+side*29,ink,room,true)
   block("DoorWallColor",34,19,0.22,x+half*27,10.5,-312+side*27.65,color,room,false)
  end
  block("DoorLintelInk",18,4,2.7,x,19,-312+side*29,ink,room,true)
  for _,windowX in ipairs({-27,27}) do
   block("WindowInk",19,10,0.25,x+windowX,13,-312+side*30.4,ink,room,false)
   block("WindowCream",16.4,7.6,0.28,x+windowX,13,-312+side*30.6,cream,room,false)
   block("WindowBlue",14.2,5.4,0.30,x+windowX,13,-312+side*30.8,Color3.fromRGB(154,217,231),room,false)
   block("WindowMullion",0.65,5.5,0.35,x+windowX,13,-312+side*31,cream,room,false)
  end
 end
 block("RoofInk",96,4,66,x,23,-312,ink,room,false):SetAttribute("DecorativeRoof",true)
 block("RoofCream",93,2,63,x,24.5,-312,cream,room,false):SetAttribute("DecorativeRoof",true)
 for _,side in ipairs({-1,1}) do
  block("DeskInk",20,3,8,x+side*26,1.5,-308,ink,room,true)
  block("DeskWood",19,0.4,7.5,x+side*26,3.2,-308,gold,room,false)
  block("BookcaseInk",14,7,3,x+side*34,3.5,-329,ink,room,true)
  for row=1,3 do
   for book=1,6 do block("BookSpine",1.7,1.6,0.25,x+side*34-5.2+book*1.6,row*1.8,-327.3,({blue,coral,gold,mint,purple,cream})[book],room,false) end
  end
 end
 marker("DoorA",Vector3.new(x,3.6,-344),Vector3.new(14,1,10),room)
 marker("DoorB",Vector3.new(x,3.6,-280),Vector3.new(14,1,10),room)
 coverVolume(room.Name,Vector3.new(x,10,-312),Vector3.new(92,20,60),"Classroom")
end
classroom(1,-120,brick) classroom(2,0,gold) classroom(3,120,coral)
paint("ClassroomCourtyardInk",348,84,0,-228,ink,0.11)
paint("ClassroomCourtyard",340,76,0,-228,paving,0.17)
for _,x in ipairs({-144,-96,-48,48,96,144}) do
 cylinder("CourtyardPlanterInk",15,3.2,Vector3.new(x,1.6,-246),ink,landmarks,true)
 cylinder("CourtyardPlanterTerracotta",13,1.1,Vector3.new(x,3.1,-246),coral,landmarks,false)
 ball("CourtyardShrub",14,7,14,x,6,-246,mint,scenery)
 coverVolume("CourtyardPlanter",Vector3.new(x,3,-246),Vector3.new(15,6,15),"Planter")
end

local function playfort(index,cx,cz,color)
 local route=folder(string.format("Playfort%02d",index),elevated)
 local id=route.Name
 route:SetAttribute("RouteId",id) route:SetAttribute("GroundRouteConnected",true)
 route:SetAttribute("IndependentAccesses",4) route:SetAttribute("MaximumHeight",12)
 paint("PlayfortSoftFallInk",242,142,cx,cz,ink,0.10)
 paint("PlayfortSoftFall",234,134,cx,cz,color,0.16)
 surface("WestLoop",18,120,cx-51,cz,12,color,route,id,18)
 surface("EastLoop",18,120,cx+51,cz,12,color,route,id,18)
 surface("NorthLoop",84,18,cx,cz-51,12,color,route,id,18)
 surface("SouthLoop",84,18,cx,cz+51,12,color,route,id,18)
 for _,dx in ipairs({-48,48}) do for _,dz in ipairs({-48,48}) do
  block("SupportInk",4,10.6,4,cx+dx,5.3,cz+dz,ink,route,true)
  block("SupportCream",2.8,10,4.2,cx+dx,5.3,cz+dz,cream,route,false)
  ball("SupportButton",5.6,5.6,5.6,cx+dx,15.2,cz+dz,color,scenery)
 end end
 ramp("WestAccess",Vector3.new(cx-108,0.18,cz-30),Vector3.new(cx-60,12,cz-30),16,color,route,id)
 ramp("EastAccess",Vector3.new(cx+108,0.18,cz+30),Vector3.new(cx+60,12,cz+30),16,color,route,id)
 ramp("WideSlide",Vector3.new(cx,0.18,cz-108),Vector3.new(cx,12,cz-60),14,gold,route,id)
 for step=1,4 do
  local top=step*3 local z=cz+96-step*8
  local object=block("Step"..step.."Ink",14,top,8,cx-24,top/2,z,ink,route,true)
  object:SetAttribute("Walkable",true) object:SetAttribute("RouteId",id) object:SetAttribute("PathWidth",14)
  object:SetAttribute("IsStep",true) object:SetAttribute("StepRise",3) object:SetAttribute("TopHeight",top) object:SetAttribute("JumpGap",0)
  block("Step"..step.."Color",13.5,0.12,7.5,cx-24,top+0.06,z,color,route,false)
 end
 for _,side in ipairs({-1,1}) do
  block("LoopEdgeCreamX",0.7,0.16,114,cx+side*58,12.18,cz,cream,route,false)
  block("LoopEdgeCreamZ",114,0.16,0.7,cx,12.18,cz+side*58,cream,route,false)
 end
 for _,dx in ipairs({-24,24}) do
  block("UnderFortScreenInk",14,7,3,cx+dx,3.5,cz,ink,route,true)
  block("UnderFortScreenColor",12.5,5.5,0.25,cx+dx,3.5,cz+1.7,color,route,false)
 end
 coverVolume(id,Vector3.new(cx,6,cz),Vector3.new(120,12,120),"Playfort")
end
playfort(1,-228,-156,blue) playfort(2,228,-156,mint)
playfort(3,-228,156,coral) playfort(4,228,156,purple)

local monkey=folder("MonkeyBars",landmarks) monkey:SetAttribute("Landmark","MonkeyBars")
paint("MonkeySoftFall",102,48,-300,0,gold,0.2)
for _,dx in ipairs({-38,38}) do for _,dz in ipairs({-18,18}) do
 block("MonkeyPostInk",3.6,11,3.6,-300+dx,5.5,dz,ink,monkey,true)
 block("MonkeyPostColor",2.4,10.6,3.8,-300+dx,5.5,dz,blue,monkey,false)
end end
for _,dz in ipairs({-18,18}) do block("MonkeyHeader",84,2,2.8,-300,10,dz,coral,monkey,false) end
for rung=1,9 do block("MonkeyRung",1.4,1.4,37,-340+rung*8,10,0,cream,monkey,false) end
coverVolume("MonkeyBars",Vector3.new(-300,5,0),Vector3.new(84,10,40),"PlayEquipment")
local swings=folder("Swings",landmarks) swings:SetAttribute("Landmark","Swings")
paint("SwingSoftFall",106,56,300,0,coral,0.22)
for _,dx in ipairs({-44,44}) do for _,dz in ipairs({-22,22}) do
 block("SwingPostInk",3.6,14,3.6,300+dx,7,dz,ink,swings,true)
 block("SwingPostColor",2.4,13.5,3.8,300+dx,7,dz,gold,swings,false)
end end
block("SwingHeaderInk",92,3,4,300,13.5,0,ink,swings,false)
block("SwingHeaderCream",89,1.5,4.2,300,14.3,0,cream,swings,false)
for _,dx in ipairs({-25,0,25}) do
 for _,side in ipairs({-1,1}) do block("SwingRope",0.35,10.6,0.35,300+dx+side*5,7.8,0,ink,swings,false) end
 block("SwingSeatInk",14,1,6,300+dx,2.3,0,ink,swings,false)
 block("SwingSeatColor",12.5,0.6,5,300+dx,2.8,0,blue,swings,false)
end
coverVolume("Swings",Vector3.new(300,6,0),Vector3.new(92,12,48),"PlayEquipment")

local pitch=folder("RoundersPitch",landmarks) pitch:SetAttribute("Landmark","Rounders")
paint("RoundersMownField",270,116,0,304,grassLight,0.20)
local bases={Vector3.new(0,0,250),Vector3.new(88,0,304),Vector3.new(0,0,356),Vector3.new(-88,0,304)}
for index=1,4 do
 line("RoundersDiamond",bases[index],bases[index%4+1],1.4,cream,0.25)
 cylinder("RoundersBaseInk",11,0.12,bases[index]+Vector3.new(0,0.30,0),ink,artwork,false)
 cylinder("RoundersBase",8.5,0.12,bases[index]+Vector3.new(0,0.38,0),white,artwork,false)
end
for side=-1,1,2 do
 block("PitchEquipmentBoxInk",28,5,9,side*110,2.5,304,ink,pitch,true)
 block("PitchEquipmentBoxCream",26,3.5,9.2,side*110,2.7,304,cream,pitch,false)
 coverVolume("PitchEquipment",Vector3.new(side*110,2.5,304),Vector3.new(28,5,9),"SportsStorage")
end
local games=folder("PaintedGames",landmarks) games:SetAttribute("Landmark","HopscotchBeanbags")
for index=1,10 do
 local z=42+index*9 local x=index%3==0 and 8 or -8
 paint("HopscotchInk",8.2,8.2,-52+x,z,ink,0.24)
 paint("HopscotchTile",6.6,6.6,-52+x,z,({blue,gold,coral,mint})[index%4+1],0.3)
 for dot=1,index do cylinder("HopscotchDot",0.75,0.08,Vector3.new(-52+x-2+(dot-1)%4*1.3,0.36,z-2+math.floor((dot-1)/4)*1.3),white,artwork,false) end
end
for _,z in ipairs({-66,66}) do
 cylinder("BeanbagTargetInk",18,0.12,Vector3.new(54,0.30,z),ink,artwork,false)
 cylinder("BeanbagTargetCream",14,0.12,Vector3.new(54,0.38,z),cream,artwork,false)
 cylinder("BeanbagTargetColor",7,0.12,Vector3.new(54,0.46,z),gold,artwork,false)
end

local function bench(label,x,z,color,parent,turn)
 local rotation=CFrame.Angles(0,turn or 0,0)
 local function add(n,size,offset,c,collide)
  return part(n,size,Vector3.new(x,0,z)+rotation:VectorToWorldSpace(offset),c,parent,collide,nil,rotation)
 end
 add(label.."SeatInk",Vector3.new(24,2.8,7),Vector3.new(0,1.4,0),ink,true)
 add(label.."SeatColor",Vector3.new(22.5,0.6,6),Vector3.new(0,3,0),color,false)
 add(label.."BackInk",Vector3.new(24,6,2.2),Vector3.new(0,3,-3.5),ink,true)
 add(label.."BackCream",Vector3.new(22,4.5,0.22),Vector3.new(0,3,-2.25),cream,false)
 coverVolume(label,Vector3.new(x,3,z),Vector3.new(26,6,12),"Bench")
end
local function cubby(label,x,z,color,turn)
 cubbyCount+=1
 local model=folder(label,coverFolder)
 model:SetAttribute("CoverCubby",true) model:SetAttribute("TwoExits",true) model:SetAttribute("ExitWidth",20)
 model:SetAttribute("ClearInteriorHeight",10) model:SetAttribute("GroundRouteConnected",true)
 local rotation=CFrame.Angles(0,turn or 0,0)
 local origin=Vector3.new(x,0,z)
 for _,side in ipairs({-1,1}) do
  local wall=part("CubbyWallInk",Vector3.new(2,10,24),origin+rotation:VectorToWorldSpace(Vector3.new(side*11,5,0)),ink,model,true,nil,rotation)
  part("CubbyWallColor",Vector3.new(0.2,8.4,22),origin+rotation:VectorToWorldSpace(Vector3.new(side*9.9,5,0)),color,model,false,nil,rotation)
  for rung=1,3 do part("CubbyWallPanel",Vector3.new(0.24,0.45,21),origin+rotation:VectorToWorldSpace(Vector3.new(side*9.7,rung*2.7,0)),cream,model,false,nil,rotation) end
 end
 part("CubbyRoofInk",Vector3.new(26,1.2,28),origin+Vector3.new(0,10.6,0),ink,model,false,nil,rotation):SetAttribute("DecorativeRoof",true)
 part("CubbyRoofColor",Vector3.new(24.5,0.8,26.5),origin+Vector3.new(0,11.2,0),color,model,false,nil,rotation):SetAttribute("DecorativeRoof",true)
 for _,side in ipairs({-1,1}) do
  local door=marker(side==-1 and "DoorA" or "DoorB",origin+rotation:VectorToWorldSpace(Vector3.new(0,3.6,side*17)),Vector3.new(20,1,10),model)
  door.CFrame=CFrame.new(door.Position)*rotation door:SetAttribute("ExitWidth",20)
 end
 coverVolume(label,origin+Vector3.new(0,5,0),Vector3.new(26,10,28),"TwoExitCubby")
end
local function storage(label,x,z,color)
 local model=folder(label,coverFolder)
 block("StorageInk",18,8,8,x,4,z,ink,model,true)
 block("StorageColor",16.5,6.5,0.2,x,4,z+4.15,color,model,false)
 for side=-1,1,2 do
  block("StorageDoorTrim",0.5,6.5,0.3,x+side*4,4,z+4.3,cream,model,false)
  block("StorageHandle",0.6,1.6,0.5,x+side*2,4,z+4.5,ink,model,false)
 end
 coverVolume(label,Vector3.new(x,4,z),Vector3.new(18,8,8),"Storage")
end
local function beanbags(label,x,z,color)
 local model=folder(label,coverFolder)
 for _,dx in ipairs({-6,6}) do
  local bag=part("BeanbagInk",Vector3.new(14,4,12),Vector3.new(x+dx,2,z),ink,model,true,Enum.PartType.Ball)
  ball("BeanbagColor",12.6,3.2,10.6,x+dx,2.3,z,color,model)
 end
 block("BeanbagScreenInk",22,5,2,x,2.5,z-6,ink,model,true)
 block("BeanbagScreenColor",20.5,3.5,0.22,x,2.5,z-4.85,color,model,false)
 coverVolume(label,Vector3.new(x,2.5,z),Vector3.new(26,5,16),"Beanbags")
end
local function excluded(x,z)
 if math.abs(x)<18 or math.abs(z)<18 then return true end
 if math.abs(x)<181 and z>-358 and z<-185 then return true end
 for _,cx in ipairs({-228,228}) do for _,cz in ipairs({-156,156}) do
  if math.abs(x-cx)<126 and math.abs(z-cz)<118 then return true end
 end end
 if math.abs(x+300)<58 and math.abs(z)<44 then return true end
 if math.abs(x-300)<60 and math.abs(z)<50 then return true end
 return false
end
local station=0
for ix=-7,7 do for iz=-7,7 do
 local x,z=ix*48,iz*48
 if not excluded(x,z) then
  station+=1 local color=({blue,coral,gold,mint,purple})[station%5+1]
  local label=string.format("SchoolyardCover%03d",station)
  if station%4==0 then cubby(label,x,z,color,station%8==0 and math.pi/2 or 0)
  elseif station%4==1 then bench(label,x,z,color,coverFolder,station%2==0 and math.pi/2 or 0)
  elseif station%4==2 then storage(label,x,z,color)
  else beanbags(label,x,z,color) end
 end
end end
for _,x in ipairs({-348,-300,-252,-204,-156,-108,-60,60,108,156,204,252,300,348}) do
 bench("OuterSchoolBench",x,-360,({blue,coral,gold,mint})[math.floor(math.abs(x)/12)%4+1],coverFolder,0)
end
for _,x in ipairs({-348,-252,-156,-60,60,156,252,348}) do
 storage("SouthernSchoolStorage",x,362,({blue,coral,gold,mint})[math.floor(math.abs(x)/12)%4+1])
end
for _,x in ipairs({-96,-48,48,96}) do
 bench("CourtyardBench",x,-198,coral,landmarks,0)
end
for _,x in ipairs({-364,364}) do for _,z in ipairs({-144,144}) do
 local label="OuterSideCubby"..(x<0 and "West" or "East")..(z<0 and "North" or "South")
 cubby(label,x,z,x<0 and blue or mint,0)
end end
local treeIndex=0
for _,side in ipairs({-1,1}) do
 for index=-3,3 do
  local x,z=side*399,index*104
  treeIndex+=1
  local tree=Instance.new("Model")
  tree.Name=string.format("Tree%02d",treeIndex)
  tree.Parent=scenery
  block("TreeTrunkInk",5,11,5,x,5.5,z,ink,tree,false)
  block("TreeTrunkBrown",3.6,10.5,5.2,x,5.5,z,Color3.fromRGB(148,97,68),tree,false)
  local shell=ball("TreeCrownInk",28,23,28,x,21,z,ink,tree)
  shell.Transparency=1
  shell.CanCollide=false
  shell.CanQuery=false
  shell.CanTouch=false
  ball("TreeCrownGreen",25,21,25,x,21.5,z,mint,tree)
  ball("TreeCrownLight",14,12,14,x-4,26,z-3,grassLight,tree)
  local outline=Instance.new("Highlight")
  outline.Name="TreeOutline"
  outline.Adornee=tree
  outline.FillTransparency=1
  outline.OutlineTransparency=0
  outline.OutlineColor=ink
  outline.DepthMode=Enum.HighlightDepthMode.Occluded
  outline.Parent=tree
 end
end

local bounds=marker("ArenaBounds",Vector3.new(0,60,0),Vector3.new(832,120,832),gameplay)
local groups=folder("TeamSpawns",gameplay)
local starts=folder("StartPads",gameplay)
local spawnList={Vector3.new(-264,0,-388),Vector3.new(0,0,-388),Vector3.new(264,0,-388),Vector3.new(388,0,-264),Vector3.new(388,0,0),Vector3.new(388,0,264),Vector3.new(264,0,388),Vector3.new(0,0,388),Vector3.new(-264,0,388),Vector3.new(-388,0,264),Vector3.new(-388,0,0),Vector3.new(-388,0,-264)}
for index,position in ipairs(spawnList) do
 local group=folder(string.format("Group%02d",index),groups)
 group:SetAttribute("TeamId",index) group:SetAttribute("TeamIndex",index) group:SetAttribute("Capacity",12)
 cylinder("SpawnCircleInk",35,0.1,position+Vector3.new(0,0.23,0),ink,artwork,false)
 cylinder("SpawnCircleCream",31,0.1,position+Vector3.new(0,0.30,0),cream,artwork,false)
 cylinder("SpawnCircleColor",23,0.1,position+Vector3.new(0,0.37,0),({blue,coral,gold,mint,purple})[index%5+1],artwork,false)
 local facing=CFrame.lookAt(center+position,center+Vector3.new(0,0,0))
 for padIndex=1,12 do
  local column=(padIndex-1)%4 local row=math.floor((padIndex-1)/4)
  local p=position+facing.RightVector*((column-1.5)*6)+facing.LookVector*((row-1)*6)+Vector3.new(0,3.6,0)
  local pad=marker(string.format("%02d",padIndex),p,Vector3.new(3,1,3),group)
  pad.CFrame=CFrame.lookAt(pad.Position,Vector3.new(center.X,pad.Position.Y,center.Z))
  pad:SetAttribute("TeamId",index) pad:SetAttribute("TeamIndex",index)
  if padIndex==4 or padIndex==9 then
   local start=pad:Clone() start.Name=string.format("%02d",(index-1)*2+(padIndex==4 and 1 or 2)) start.Parent=starts partCount+=1
  end
 end
end
local practice=folder("PracticeSpawns",gameplay)
for index,position in ipairs({Vector3.new(-20,3.6,0),Vector3.new(0,3.6,20),Vector3.new(20,3.6,0),Vector3.new(0,3.6,-20)}) do
 marker(string.format("%02d",index),position,Vector3.new(3,1,3),practice)
end
for index,position in ipairs({Vector3.new(-72,0,72),Vector3.new(72,0,-72),Vector3.new(-72,0,-72),Vector3.new(72,0,72)}) do
 local zone=marker(string.format("RescueArea%02d",index),position+Vector3.new(0,4,0),Vector3.new(20,8,20),rescueAreas)
 zone:SetAttribute("OptionalLandmark",true)
end

local function pointClear(x,z)
 for _,box in ipairs(obstacleBoxes) do if x>=box.x1 and x<=box.x2 and z>=box.z1 and z<=box.z2 then return false end end
 return true
end
local function segmentClear(a,b)
 local dx,dz=b.x-a.x,b.z-a.z
 for _,box in ipairs(obstacleBoxes) do
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
local nav=folder("NavigationNodes",gameplay)
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
local visited={} local queue={} local largest={}
for _,item in ipairs(candidates) do
 if not visited[item] then
  queue={item} visited[item]=true local at=1
  while queue[at] do
   local current=queue[at] at+=1
   for _,neighbor in ipairs(current.neighbors) do if not visited[neighbor] then visited[neighbor]=true table.insert(queue,neighbor) end end
  end
  if #queue>#largest then largest=queue end
 end
end
local retained={}
for index,item in ipairs(largest) do
 retained[item]=true item.name=string.format("N%04d",index)
 item.object=marker(item.name,Vector3.new(item.x,3.6,item.z),Vector3.new(1,1,1),nav)
 item.object:SetAttribute("GroundNode",true) item.object:SetAttribute("LaneWidth",6.4)
end
local edges=0
for _,item in ipairs(largest) do
 local neighborNames={}
 for _,neighbor in ipairs(item.neighbors) do if retained[neighbor] then table.insert(neighborNames,neighbor.name) edges+=1 end end
 table.sort(neighborNames) item.object:SetAttribute("Neighbors",table.concat(neighborNames,","))
end
for _,pad in ipairs(starts:GetChildren()) do
 local best,distance=nil,math.huge
 local p=pad.Position-center
 for _,item in ipairs(largest) do
  local squared=(item.x-p.X)^2+(item.z-p.Z)^2
  if squared<distance and segmentClear({x=p.X,z=p.Z},item) then best=item distance=squared end
 end
 assert(best,"Starting pad lacks a connected clear ground approach")
 pad:SetAttribute("NavigationNode",best.name)
end
for _,pad in ipairs(practice:GetChildren()) do
 local p=pad.Position-center local best,distance=nil,math.huge
 for _,item in ipairs(largest) do
  local squared=(item.x-p.X)^2+(item.z-p.Z)^2
  if squared<distance and segmentClear({x=p.X,z=p.Z},item) then best=item distance=squared end
 end
 assert(best,"Practice pad lacks navigation") pad:SetAttribute("NavigationNode",best.name)
end
arena:SetAttribute("FloorY",center.Y) arena:SetAttribute("CenterX",center.X) arena:SetAttribute("CenterZ",center.Z)
arena:SetAttribute("CourtWidth",832) arena:SetAttribute("CourtLength",832) arena:SetAttribute("MapStyle","SchoolPlayground")
arena:SetAttribute("RoundDuration",300) arena:SetAttribute("MaxPlayers",4) arena:SetAttribute("BaseSpeed",16)
arena:SetAttribute("MinimumPlayers",4) arena:SetAttribute("MaxTeamSize",2) arena:SetAttribute("TeamCount",2)
arena:SetAttribute("SprintMultiplier",2.5) arena:SetAttribute("SprintSeconds",10) arena:SetAttribute("SprintRefillSeconds",15)
arena:SetAttribute("MaximumRouteHeight",12) arena:SetAttribute("MinimumPathWidth",6.4)
arena:SetAttribute("CoverStations",coverCount) arena:SetAttribute("TwoExitCubbies",cubbyCount)
arena:SetAttribute("NavigationNodes",#largest) arena:SetAttribute("NavigationEdges",edges/2)
arena:SetAttribute("DiscardedNavigationNodes",#candidates-#largest) arena:SetAttribute("LayoutVersion",1)
arena:SetAttribute("MudGeometryRepairVersion",2)
arena.Parent=workspace
return {built=true,folder=arena:GetFullName(),parts=partCount,coverStations=coverCount,twoExitCubbies=cubbyCount,playfortLoops=4,navigationNodes=#largest,navigationEdges=edges/2,discardedNavigationNodes=#candidates-#largest,linearScaleFromTag=2,areaScaleFromTag=4}
