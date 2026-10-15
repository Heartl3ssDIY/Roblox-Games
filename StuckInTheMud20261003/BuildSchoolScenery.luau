local ink=Color3.fromRGB(27,45,61)
local cream=Color3.fromRGB(255,243,200)
local brick=Color3.fromRGB(239,169,111)
local blue=Color3.fromRGB(76,182,238)
local coral=Color3.fromRGB(255,127,121)
local gold=Color3.fromRGB(255,203,68)
local mint=Color3.fromRGB(92,209,166)
local green=Color3.fromRGB(129,201,76)
local white=Color3.fromRGB(255,253,240)
local font=Font.new("rbxasset://fonts/families/FredokaOne.json")

local function build(arena)
 if not arena then return {built=false,reason="Arena is absent"} end
 local existing=arena:FindFirstChild("SchoolScenery")
 if existing then return {built=false,preserved=true,folder=existing:GetFullName()} end
 local gameplay=assert(arena:FindFirstChild("Gameplay"),"Arena gameplay is missing")
 local bounds=assert(gameplay:FindFirstChild("ArenaBounds"),"Arena bounds are missing")
 assert(bounds:IsA("BasePart") and bounds.CFrame.UpVector:Dot(Vector3.yAxis)>0.999,"School scenery needs horizontal arena bounds")
 local floorY=arena:GetAttribute("FloorY")
 if typeof(floorY)~="number" then
  local floor=arena:FindFirstChild("CourtFloor",true)
  floorY=floor and floor.Position.Y+floor.Size.Y/2 or bounds.Position.Y-bounds.Size.Y/2
 end
 assert(floorY==floorY and math.abs(floorY)<100000,"Arena floor is invalid")
 local base=CFrame.new(bounds.Position.X,floorY,bounds.Position.Z)*bounds.CFrame.Rotation
 local halfWidth,halfLength=bounds.Size.X/2,bounds.Size.Z/2
 local scenery=Instance.new("Folder")
 scenery.Name="SchoolScenery"
 scenery:SetAttribute("SchoolStyleVersion",1)
 scenery:SetAttribute("DecorationOnly",true)
 scenery:SetAttribute("MinimumArenaClearance",24)
 scenery:SetAttribute("SourceArenaBounds",bounds.CFrame)
 scenery:SetAttribute("SourceArenaSize",bounds.Size)
 local count=0
 local function folder(name)
  local object=Instance.new("Folder") object.Name=name object.Parent=scenery return object
 end
 local function part(name,size,position,color,parent,rotation,shape)
  local object=Instance.new("Part")
  object.Name=name object.Size=size object.CFrame=base*CFrame.new(position)*(rotation or CFrame.identity)
  object.Color=color object.Material=Enum.Material.SmoothPlastic object.Anchored=true
  object.CanCollide=false object.CanTouch=false object.CanQuery=false object.CastShadow=true
  object.TopSurface=Enum.SurfaceType.Smooth object.BottomSurface=Enum.SurfaceType.Smooth
  if shape then object.Shape=shape end
  object.Parent=parent count+=1 return object
 end
 local function label(object,value,face)
  local gui=Instance.new("SurfaceGui")
  gui.Name="ClassDetail" gui.Face=face gui.LightInfluence=0.3 gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud
  gui.PixelsPerStud=32 gui.AlwaysOnTop=false gui.Parent=object
  local text=Instance.new("TextLabel")
  text.Name="Label" text.Size=UDim2.fromScale(1,1) text.BackgroundTransparency=1 text.Text=value
  text.TextColor3=ink text.FontFace=font text.TextScaled=true text.TextWrapped=true text.Parent=gui
 end
 local school=folder("ClassroomFacade")
 local schoolZ=-halfLength-74
 local schoolWidth=math.clamp(bounds.Size.X*0.8,180,256)
 part("SchoolIslandSoil",Vector3.new(schoolWidth+26,36,58),Vector3.new(0,-22,schoolZ),Color3.fromRGB(159,102,65),school)
 part("SchoolIslandInk",Vector3.new(schoolWidth+28,8,60),Vector3.new(0,-4,schoolZ),ink,school)
 part("SchoolIslandGrass",Vector3.new(schoolWidth+24,0.8,56),Vector3.new(0,0.1,schoolZ),green,school)
 part("FacadeInk",Vector3.new(schoolWidth+4,56,30),Vector3.new(0,28,schoolZ),ink,school)
 part("WarmSchoolWall",Vector3.new(schoolWidth,53,0.7),Vector3.new(0,27.5,schoolZ+15.4),brick,school)
 part("FoundationCream",Vector3.new(schoolWidth+2,3,31),Vector3.new(0,1.5,schoolZ),cream,school)
 part("RoofInk",Vector3.new(schoolWidth+12,4,38),Vector3.new(0,57,schoolZ),ink,school)
 part("RoofCream",Vector3.new(schoolWidth+9,2.2,35),Vector3.new(0,58.7,schoolZ),cream,school)
 for _,side in ipairs({-1,1}) do
  part("FacadeColumn",Vector3.new(5,54,1.4),Vector3.new(side*(schoolWidth/2-4),28,schoolZ+15.9),cream,school)
  part("ColumnCap",Vector3.new(8,2,3),Vector3.new(side*(schoolWidth/2-4),55,schoolZ+16),gold,school)
 end
 for _,height in ipairs({16,38}) do for column=-3,3 do
  if height~=16 or column~=0 then
   local x=column*(schoolWidth-28)/7
   part("WindowInk",Vector3.new(21,13,1.2),Vector3.new(x,height,schoolZ+16),ink,school)
   part("WindowGlass",Vector3.new(18.4,10.4,1.25),Vector3.new(x,height,schoolZ+16.75),blue,school)
   part("WindowCrossVertical",Vector3.new(0.7,10.6,0.3),Vector3.new(x,height,schoolZ+17.55),cream,school)
   part("WindowCrossHorizontal",Vector3.new(18.6,0.7,0.3),Vector3.new(x,height,schoolZ+17.55),cream,school)
   part("WindowSill",Vector3.new(23,1.3,2.4),Vector3.new(x,height-7.2,schoolZ+16.8),cream,school)
  end
 end end
 part("DoorInk",Vector3.new(22,25,1.4),Vector3.new(0,12.5,schoolZ+16),ink,school)
 part("DoorColor",Vector3.new(19.6,22.6,1.45),Vector3.new(0,12.5,schoolZ+16.8),mint,school)
 part("DoorWindow",Vector3.new(13,10,0.3),Vector3.new(0,17,schoolZ+17.8),blue,school)
 part("DoorDivider",Vector3.new(0.7,23,0.35),Vector3.new(0,12.5,schoolZ+17.8),cream,school)
 for _,side in ipairs({-1,1}) do
  part("DoorHandle",Vector3.new(0.8,3,0.5),Vector3.new(side*1.8,9,schoolZ+18),gold,school)
 end
 local plaque=part("RoomPlaque",Vector3.new(11,2.6,0.5),Vector3.new(0,28.8,schoolZ+16.6),cream,school)
 label(plaque,"ROOM 4",Enum.NormalId.Back)
 part("SchoolClockInk",Vector3.new(0.7,10,10),Vector3.new(0,50,schoolZ+16.1),ink,school,CFrame.Angles(0,math.pi/2,0),Enum.PartType.Cylinder)
 part("SchoolClockFace",Vector3.new(0.8,8.5,8.5),Vector3.new(0,50,schoolZ+16.8),cream,school,CFrame.Angles(0,math.pi/2,0),Enum.PartType.Cylinder)
 part("ClockMinuteHand",Vector3.new(0.5,3.7,0.25),Vector3.new(0,51.2,schoolZ+17.4),ink,school)
 part("ClockHourHand",Vector3.new(2.8,0.5,0.25),Vector3.new(1.2,50,schoolZ+17.4),ink,school)
 for index=0,3 do
  local angle=index*math.pi/2
  part("ClockTick",Vector3.new(0.6,0.6,0.2),Vector3.new(math.sin(angle)*3.3,50+math.cos(angle)*3.3,schoolZ+17.4),ink,school)
 end

 local recreation=folder("PaintedSchoolGames")
 local courtX=halfWidth+72
 part("SchoolCourtSoil",Vector3.new(69,26,129),Vector3.new(courtX,-13.5,0),Color3.fromRGB(159,102,65),recreation)
 part("HopscotchCourtInk",Vector3.new(72,0.8,132),Vector3.new(courtX,-0.4,0),ink,recreation)
 part("HopscotchCourtColor",Vector3.new(69,0.18,129),Vector3.new(courtX,0.05,0),Color3.fromRGB(225,199,150),recreation)
 local squares={{0,-27},{-3,-20},{3,-20},{0,-13},{-3,-6},{3,-6},{0,1},{0,8}}
 for index,offset in ipairs(squares) do
  local position=Vector3.new(courtX+offset[1],0.2,offset[2])
  part("HopscotchOutline",Vector3.new(5.4,0.12,5.4),position,ink,recreation)
  local square=part("HopscotchSquare",Vector3.new(4.6,0.13,4.6),position+Vector3.new(0,0.08,0),index%3==0 and mint or index%3==1 and gold or coral,recreation)
  label(square,tostring(index),Enum.NormalId.Top)
 end
 local beanZ=halfLength+62
 part("BeanbagCourtSoil",Vector3.new(93,26,41),Vector3.new(0,-13.5,beanZ),Color3.fromRGB(159,102,65),recreation)
 part("BeanbagCourtInk",Vector3.new(96,0.8,44),Vector3.new(0,-0.4,beanZ),ink,recreation)
 part("BeanbagCourtGreen",Vector3.new(93,0.18,41),Vector3.new(0,0.05,beanZ),green,recreation)
 for index,color in ipairs({blue,coral,mint}) do
  local x=(index-2)*25
  part("BeanbagTargetInk",Vector3.new(13,0.15,13),Vector3.new(x,0.2,beanZ-3),ink,recreation)
  part("BeanbagTarget",Vector3.new(10.5,0.16,10.5),Vector3.new(x,0.3,beanZ-3),color,recreation)
  part("TargetCenter",Vector3.new(3,0.17,3),Vector3.new(x,0.4,beanZ-3),cream,recreation)
  part("SoftBeanbag",Vector3.new(4.2,2,4.2),Vector3.new(x+7,1.2,beanZ+11),color,recreation,CFrame.Angles(0,index*0.4,0),Enum.PartType.Ball)
 end
 for _,side in ipairs({-1,1}) do
  part("BeanbagCourtStripe",Vector3.new(88,0.12,0.6),Vector3.new(0,0.2,beanZ+side*18),white,recreation)
 end
 local benches=folder("Benches")
 for _,side in ipairs({-1,1}) do
  local x,z=courtX,side*54
  part("BenchSeatInk",Vector3.new(22,2,7),Vector3.new(x,4,z),ink,benches)
  for plank=-1,1 do part("BenchSeatPlank",Vector3.new(20.5,1,1.7),Vector3.new(x,4.7,z+plank*2),gold,benches) end
  part("BenchBackInk",Vector3.new(22,5.5,1.8),Vector3.new(x,7.4,z+side*3.7),ink,benches)
  part("BenchBackColor",Vector3.new(20.5,4,1.9),Vector3.new(x,7.4,z+side*3.8),cream,benches)
  for _,leg in ipairs({-1,1}) do part("BenchLeg",Vector3.new(2,4,5),Vector3.new(x+leg*8,2,z),ink,benches) end
 end
 local details=folder("ClassNoticeboard")
 local boardX=-halfWidth-66
 local facing=CFrame.Angles(0,math.pi/2,0)
 part("NoticeboardSoil",Vector3.new(34,26,28),Vector3.new(boardX,-13.5,0),Color3.fromRGB(159,102,65),details)
 part("NoticeboardPaving",Vector3.new(38,0.8,32),Vector3.new(boardX,-0.4,0),cream,details)
 part("NoticeboardInk",Vector3.new(18,12,1.6),Vector3.new(boardX,14,0),ink,details,facing)
 part("NoticeboardCork",Vector3.new(15.8,9.8,1.7),Vector3.new(boardX+0.9,14,0),brick,details,facing)
 for _,side in ipairs({-1,1}) do
  part("NoticeboardPost",Vector3.new(1.8,14,1.8),Vector3.new(boardX,7,side*6.5),ink,details)
  local paper=part("PinnedClassPaper",Vector3.new(5.2,6,0.2),Vector3.new(boardX+1.9,14,side*4),cream,details,facing)
  label(paper,side<0 and "CLASS\n4B" or "SPORTS\nDAY",Enum.NormalId.Back)
  part("NoticePin",Vector3.new(0.4,0.9,0.9),Vector3.new(boardX+2.2,16.2,side*4),coral,details,nil,Enum.PartType.Ball)
 end
 local plants=folder("SchoolPlanters")
 for _,side in ipairs({-1,1}) do
  for _,z in ipairs({-halfLength*0.48,halfLength*0.48}) do
   local x=side*(halfWidth+44)
   part("PlanterPedestal",Vector3.new(14,28,14),Vector3.new(x,-14,z),Color3.fromRGB(159,102,65),plants)
   part("PlanterInk",Vector3.new(13,4.5,13),Vector3.new(x,2.25,z),ink,plants)
   part("PlanterCream",Vector3.new(11.5,3.6,11.5),Vector3.new(x,2.5,z),cream,plants)
   part("PlantSoil",Vector3.new(10.8,0.3,10.8),Vector3.new(x,4.5,z),Color3.fromRGB(113,77,52),plants)
   for tuft=-1,1 do
    part("RoundShrub",Vector3.new(6.4,6.7,6.4),Vector3.new(x+tuft*2.8,7,z),tuft==0 and mint or green,plants,nil,Enum.PartType.Ball)
   end
  end
 end
 local checks=0
 for _,object in ipairs(scenery:GetDescendants()) do
  assert(not object:IsA("BaseScript") and not object:IsA("ModuleScript"),"School scenery must be scriptless")
  if object:IsA("BasePart") then
   assert(object.Anchored and not object.CanCollide and not object.CanTouch and not object.CanQuery,"School scenery must not affect gameplay")
   local minX,minZ,maxX,maxZ=math.huge,math.huge,-math.huge,-math.huge
   for _,x in ipairs({-1,1}) do for _,y in ipairs({-1,1}) do for _,z in ipairs({-1,1}) do
    local point=base:PointToObjectSpace(object.CFrame:PointToWorldSpace(Vector3.new(x*object.Size.X/2,y*object.Size.Y/2,z*object.Size.Z/2)))
    minX=math.min(minX,point.X) maxX=math.max(maxX,point.X)
    minZ=math.min(minZ,point.Z) maxZ=math.max(maxZ,point.Z)
   end end end
   assert(minX>=halfWidth+24 or maxX<=-halfWidth-24 or minZ>=halfLength+24 or maxZ<=-halfLength-24,"School scenery intrudes into the arena: "..object.Name)
   checks+=1
  end
 end
 scenery:SetAttribute("PartCount",count)
 scenery:SetAttribute("ClearanceChecks",checks)
 scenery.Parent=arena
 return {built=true,folder=scenery:GetFullName(),parts=count,clearanceChecks=checks}
end

return {
 BritishBulldog=build(workspace:FindFirstChild("British Bulldog game") or workspace:FindFirstChild("British Bulldog Game")),
 TagYoureIt=build(workspace:FindFirstChild("Tag You're It")),
}
