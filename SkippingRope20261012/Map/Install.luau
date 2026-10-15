local ServerStorage=game:GetService("ServerStorage")
assert(not ServerStorage:FindFirstChild("SkippingRopeMapBackup20261012"),"Existing skipping rope map backup")
assert(not workspace:FindFirstChild("Skipping Rope"),"Skipping Rope already exists")
assert(#workspace:GetPartBoundsInBox(CFrame.new(14600,45,4534),Vector3.new(176,100,172))==0,"New island footprint is occupied")
local backup=Instance.new("Folder")
backup.Name="SkippingRopeMapBackup20261012"
backup:SetAttribute("NewIslandOnly",true)
backup:SetAttribute("OriginalPresent",false)
backup.Parent=ServerStorage
local oldRoot={}
for _,child in workspace:GetChildren() do oldRoot[child]=child.Name end
local build = function(target, options)
 target = target or workspace
 options = options or {}
 assert(not game:GetService("RunService"):IsRunning(), "Stop Play before building the island")
 assert(not target:FindFirstChild("Skipping Rope"), "Skipping Rope island already exists")
 local origin = options.origin or CFrame.new(14600, 33, 4534)
 local variant = assert(game.MaterialService:FindFirstChild("PlaygroundRetroStuds"), "Stud material missing")
 local ink = Color3.fromRGB(24, 29, 36)
 local cream = Color3.fromRGB(230, 222, 201)
 local grass = Color3.fromRGB(126, 157, 103)
 local wood = Color3.fromRGB(157, 124, 89)
 local laneColours = {Color3.fromRGB(192, 144, 76), Color3.fromRGB(97, 147, 137), Color3.fromRGB(158, 137, 167)}
 local arena = Instance.new("Folder")
 arena.Name = "Skipping Rope"
 arena:SetAttribute("BuildVersion", "20261012")
 arena:SetAttribute("BuildComplete", false)
 arena.Parent = target
 local function container(parent, name, class)
  local item = Instance.new(class or "Folder")
  item.Name = name
  item.Parent = parent
  return item
 end
 local function part(parent, name, size, cf, colour, solid, class)
  local item = Instance.new(class or "Part")
  item.Name, item.Size, item.CFrame, item.Color = name, size, cf, colour
  item.Anchored, item.CanCollide, item.CanQuery = true, solid == true, solid == true
  item.CanTouch = class == "Seat"
  item.CastShadow = solid == true
  item.Material, item.MaterialVariant = variant.BaseMaterial, colour == ink and "" or variant.Name
  item.TopSurface, item.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
  item:SetAttribute("SkippingRopeMapPart", true)
  item.Parent = parent
  return item
 end
 local function block(parent, name, size, pos, colour, solid)
  return part(parent, name, size, origin * CFrame.new(pos), colour, solid)
 end
 local function marker(parent, name, cf)
  local item = part(parent, name, Vector3.new(.25,.25,.25), cf, ink, false)
  item.Transparency = 1
  return item
 end
 local function outline(parent, model, name)
  local h = Instance.new("Highlight")
  h.Name = name or "CartoonOutline"
  h.Adornee, h.FillTransparency, h.OutlineTransparency = model, 1, 0
  h.DepthMode, h.OutlineColor = Enum.HighlightDepthMode.Occluded, ink
  h.Parent = parent
 end
 local function label(host, face, text, color)
  local gui = Instance.new("SurfaceGui")
  gui.Name, gui.Face = "EditableLabel", face
  gui.SizingMode, gui.PixelsPerStud = Enum.SurfaceGuiSizingMode.PixelsPerStud, 48
  gui.LightInfluence, gui.MaxDistance = .1, 220
  gui.Parent = host
  local textLabel = Instance.new("TextLabel")
  textLabel.Name, textLabel.Size, textLabel.BackgroundTransparency = "Caption", UDim2.fromScale(1,1), 1
  textLabel.Text, textLabel.TextColor3 = text, color or cream
  textLabel.Font, textLabel.TextScaled, textLabel.TextWrapped = Enum.Font.FredokaOne, true, true
  textLabel.TextStrokeColor3, textLabel.TextStrokeTransparency = ink, 0
  textLabel.Parent = gui
 end
 local function topDisc(parent, name, radius, frame, colour, height)
  local p = part(parent, name, Vector3.new(height, radius*2, radius*2), frame * CFrame.Angles(0,0,math.pi/2), colour, false)
  p.Shape = Enum.PartType.Cylinder
  return p
 end
 local function bar(parent, name, a, b, thickness, colour)
  local length = (b-a).Magnitude
  return part(parent, name, Vector3.new(thickness,thickness,length), CFrame.lookAt((a+b)/2,b), colour, false)
 end
 local geometry = container(arena,"Geometry")
 local island = container(geometry,"SixthIsland","Model")
 block(island,"WarmEarth",Vector3.new(164,18,160),Vector3.new(0,-10,0),Color3.fromRGB(126,98,70),true)
 block(island,"BottomOutline",Vector3.new(165,.7,161),Vector3.new(0,-19.35,0),ink,true)
 block(island,"IslandOutline",Vector3.new(168,1.1,164),Vector3.new(0,-.65,0),ink,true)
 block(island,"StuddedGrass",Vector3.new(166,1,162),Vector3.new(0,-.5,0),grass,true)
 local grounds = container(arena,"Grounds")
 for _, x in {-58,58} do
  block(grounds,"SpectatorWalkOutline",Vector3.new(16,.07,145),Vector3.new(x,.035,0),ink,false)
  block(grounds,"SpectatorWalk",Vector3.new(15.5,.07,144.5),Vector3.new(x,.075,0),cream,false)
 end
 for _, z in {-62,62} do
  block(grounds,"ArrivalWalkOutline",Vector3.new(100,.07,24),Vector3.new(0,.035,z),ink,false)
  block(grounds,"ArrivalWalk",Vector3.new(99.5,.07,23.5),Vector3.new(0,.075,z),cream,false)
 end
 local gameplay = container(arena,"Gameplay")
 local bounds = part(gameplay,"ArenaBounds",Vector3.new(166,70,162),origin*CFrame.new(0,35,0),ink,false)
 bounds.Transparency=1
 marker(gameplay,"ArenaCenter",origin)
 local lanes = container(gameplay,"Lanes")
 local function turner(lane, name, laneFrame, side, shirt, skin, hair, npcName)
  local npc = container(lane,name,"Model")
  local platformCF = laneFrame * CFrame.new(side*30.6,0,0)
  part(npc,"PlatformOutline",Vector3.new(8.2,.25,8.2),platformCF*CFrame.new(0,.125,0),ink,true)
  part(npc,"PlatformStep",Vector3.new(7.8,1.2,7.8),platformCF*CFrame.new(0,.6,0),wood,true)
  part(npc,"PlatformTop",Vector3.new(6.3,1.2,6.3),platformCF*CFrame.new(0,1.8,0),cream,true)
  local bodyPos = laneFrame:PointToWorldSpace(Vector3.new(side*30.6,2.4,0))
  local bodyCF = CFrame.lookAt(bodyPos, bodyPos+laneFrame.RightVector*(-side))
  for _, x in {-.7,.7} do
   part(npc,"Shoe",Vector3.new(1.15,.6,1.6),bodyCF*CFrame.new(x,.35,-.2),ink,false)
   part(npc,"Leg",Vector3.new(1,2.25,1),bodyCF*CFrame.new(x,1.7,0),Color3.fromRGB(60,72,83),false)
  end
  part(npc,"Torso",Vector3.new(2.65,2.8,1.55),bodyCF*CFrame.new(0,4,0),shirt,false)
  part(npc,"Collar",Vector3.new(1.2,.35,1.6),bodyCF*CFrame.new(0,5.25,0),cream,false)
  part(npc,"Belt",Vector3.new(2.75,.24,1.6),bodyCF*CFrame.new(0,2.65,0),ink,false)
  local headCF = bodyCF*CFrame.new(0,6.8,0)
  part(npc,"Head",Vector3.new(2.45,2.45,2.2),headCF,skin,false)
  local cap=part(npc,"Hair",Vector3.new(2.6,.78,2.35),headCF*CFrame.new(0,1.07,.02),hair,false)
  cap.Shape=Enum.PartType.Ball
  part(npc,"HairBack",Vector3.new(2.42,1.7,.32),headCF*CFrame.new(0,.32,1.05),hair,false)
  for _, x in {-.48,.48} do
   local eye=part(npc,"Eye",Vector3.new(.28,.37,.12),headCF*CFrame.new(x,.18,-1.14),ink,false)
   eye.Shape=Enum.PartType.Ball
   local glint=part(npc,"EyeGlint",Vector3.new(.08,.1,.04),headCF*CFrame.new(x-.04,.25,-1.205),cream,false)
   glint.Shape=Enum.PartType.Ball
  end
  part(npc,"Smile",Vector3.new(.55,.12,.06),headCF*CFrame.new(0,-.52,-1.14),ink,false)
  for _, x in {-.32,.32} do part(npc,"SmileCorner",Vector3.new(.12,.18,.06),headCF*CFrame.new(x,-.43,-1.14),ink,false) end
  part(npc,"RelaxedSleeve",Vector3.new(.9,1.3,.95),bodyCF*CFrame.new(1.7,4.55,0),shirt,false)
  part(npc,"RelaxedHand",Vector3.new(.85,1.2,.85),bodyCF*CFrame.new(1.7,3.35,0),skin,false)
  local pivotCF = laneFrame*CFrame.new(side*26,8.8,0)
  marker(npc,"TurnPivot",pivotCF)
  local arm=container(npc,"TurnArm","Model")
  arm.WorldPivot=pivotCF
  part(arm,"TurningSleeve",Vector3.new(1.5,1.1,1.1),pivotCF*CFrame.new(side*3.65,0,0),shirt,false)
  part(arm,"Forearm",Vector3.new(2.9,.82,.82),pivotCF*CFrame.new(side*1.9,0,0),skin,false)
  local hand=part(arm,"Hand",Vector3.new(.9,1.08,1.08),pivotCF,skin,false)
  part(arm,"WristBand",Vector3.new(.25,1,1),pivotCF*CFrame.new(side*.6,0,0),cream,false)
  local attachment=Instance.new("Attachment")
  attachment.Name="RopeGrip"
  attachment.Parent=hand
  arm.WorldPivot=pivotCF
  arm:SetAttribute("RestCFrame",pivotCF)
  arm:SetAttribute("TurnBaseCFrame",pivotCF)
  arm:SetAttribute("RotationAxis","X")
  npc:SetAttribute("TurnerName",npcName)
  npc:SetAttribute("TurnSide",side)
  npc:SetAttribute("TurnArmRestCFrame",pivotCF)
  npc:SetAttribute("RopeTurner",true)
  npc.WorldPivot=bodyCF
  outline(npc,npc)
  return npc
 end
 for index=1,3 do
  local lane=container(lanes,string.format("Lane%02d",index),"Model")
  lane.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
  local laneFrame=origin*CFrame.new(0,0,(index-2)*34)
  for key,value in {LaneIndex=index,RopeHalfSpan=26,RopeFlatHalfSpan=16,RopeRadius=8,RopePivotHeight=8.8,InitialAngle=math.pi} do lane:SetAttribute(key,value) end
  marker(lane,"RopeOrigin",laneFrame)
  part(lane,"CourtOutline",Vector3.new(71,.08,24.6),laneFrame*CFrame.new(0,.04,0),ink,false)
  part(lane,"CourtSurface",Vector3.new(70.5,.08,24.1),laneFrame*CFrame.new(0,.085,0),cream,false)
  for _, side in {-1,1} do
   part(lane,"CourtAccent",Vector3.new(66,.035,.25),laneFrame*CFrame.new(0,.145,side*11.1),laneColours[index],false)
  end
  local spots=container(lane,"Spots")
  local circles=container(lane,"JumpCircles","Model")
  for spotIndex=1,8 do
   local x=-14+(spotIndex-1)*4
   local ground=laneFrame*CFrame.new(x,.16,0)
   topDisc(circles,"CircleOutline"..spotIndex,1.72,ground,ink,.045)
   topDisc(circles,"CircleColour"..spotIndex,1.54,ground*CFrame.new(0,.033,0),laneColours[index],.045)
   local number=part(circles,"SpotLabel"..spotIndex,Vector3.new(1.5,.02,1.5),ground*CFrame.new(0,.065,0),laneColours[index],false)
   number.Transparency=1
   label(number,Enum.NormalId.Top,tostring(spotIndex))
   local spot=marker(spots,string.format("Spot%02d",spotIndex),laneFrame*CFrame.new(x,3,0))
   spot:SetAttribute("SpotIndex",spotIndex)
   spot:SetAttribute("LaneIndex",index)
  end
  local rope=container(lane,"RopeSegments","Model")
  local function ropePoint(x)
local u=math.clamp((math.abs(x)-16)/10,0,1)
   local radial=8*math.sqrt(math.max(0,1-u*u))
   return laneFrame:PointToWorldSpace(Vector3.new(x,8.8+radial,0))
  end
  for segment=1,40 do
   local x0=-26+(segment-1)*52/40
   local x1=-26+segment*52/40
   local a,b=ropePoint(x0),ropePoint(x1)
   local axis=(b-a).Unit
   local ropePart=part(rope,string.format("Segment%02d",segment),Vector3.new((b-a).Magnitude,.3,.3),CFrame.fromMatrix((a+b)/2,axis,laneFrame.LookVector),laneColours[index],false)
   ropePart.Shape=Enum.PartType.Cylinder
   ropePart:SetAttribute("RopeStartX",x0)
   ropePart:SetAttribute("RopeEndX",x1)
   ropePart:SetAttribute("SegmentIndex",segment)
   ropePart:SetAttribute("RopeSegment",true)
   ropePart.MaterialVariant=""
  end
  rope.WorldPivot=laneFrame
  outline(lane,rope,"RopeOutline")
  turner(lane,"LeftTurner",laneFrame,-1,laneColours[index],({Color3.fromRGB(218,172,128),Color3.fromRGB(132,89,61),Color3.fromRGB(184,130,90)})[index],ink,({"Mia","Ava","Zoe"})[index])
  turner(lane,"RightTurner",laneFrame,1,laneColours[index],({Color3.fromRGB(161,107,74),Color3.fromRGB(232,185,143),Color3.fromRGB(114,76,55)})[index],Color3.fromRGB(80,57,40),({"Noah","Leo","Max"})[index])
  local sign=container(lane,"LaneSign","Model")
  local signCF=laneFrame*CFrame.new(-43,5.4,-7)*CFrame.Angles(0,-math.pi/2,0)
  local board=part(sign,"Board",Vector3.new(11,3.1,.4),signCF,laneColours[index],false)
  label(board,Enum.NormalId.Front,"ROPE "..index)
  label(board,Enum.NormalId.Back,"ROPE "..index)
  for _,x in {-4.5,4.5} do part(sign,"Post",Vector3.new(.35,4.3,.35),signCF*CFrame.new(x,-3.1,0),ink,true) end
  outline(sign,sign)
  lane.WorldPivot=laneFrame
  task.wait()
 end
local benches=container(grounds,"SpectatorBenches")
 local spectatorSeats={}
 for _,side in {-1,1} do
  for row,z in {-38,0,38} do
   local bench=container(benches,string.format("%sBench%02d",side<0 and "West" or "East",row),"Model")
   local at=origin:PointToWorldSpace(Vector3.new(side*59,0,z))
   local cf=CFrame.lookAt(at,origin:PointToWorldSpace(Vector3.new(0,0,z)))
part(bench,"BenchSeat",Vector3.new(12.6,.5,2.6),cf*CFrame.new(0,1.9,0),wood,true)
   part(bench,"BenchBack",Vector3.new(12.6,2.2,.4),cf*CFrame.new(0,3.2,1.12),wood,true)
   for _,x in {-4.8,4.8} do part(bench,"Leg",Vector3.new(.55,1.65,2.1),cf*CFrame.new(x,.825,0),ink,true) end
   for seatIndex,x in {-4.5,-1.5,1.5,4.5} do
    local seat=part(bench,string.format("Seat%02d",seatIndex),Vector3.new(2.6,.1,2.2),cf*CFrame.new(x,2.2,0),wood,true,"Seat")
    seat.Transparency=1
    seat:SetAttribute("SKSpectatorIndex",#spectatorSeats+1)
    table.insert(spectatorSeats,seat)
   end
   outline(bench,bench)
  end
 end
 local entries=container(gameplay,"EntrySpawns")
 local spectators=container(gameplay,"SpectatorSpawns")
 for row=1,4 do
  for column=1,6 do
   local i=(row-1)*6+column
   local x=(column-3.5)*9
   marker(entries,string.format("Entry%02d",i),origin*CFrame.new(x,3,-70+(row-1)*5)*CFrame.Angles(0,math.pi,0))
local seat=spectatorSeats[i]
   local spectator=marker(spectators,string.format("Spectator%02d",i),seat.CFrame*CFrame.new(0,.8,-3.2))
   spectator:SetAttribute("SpectatorIndex",i)
   spectator:SetAttribute("SKSpectatorIndex",i)
  end
 end
 local fence=container(grounds,"BoundaryFence","Model")
 for _,side in {-1,1} do
  block(fence,"SideRail",Vector3.new(.5,2,150),Vector3.new(side*79,2,0),wood,true)
  block(fence,"SideRailOutline",Vector3.new(.6,.14,150),Vector3.new(side*79,3.06,0),ink,false)
  block(fence,"EndRail",Vector3.new(158,2,.5),Vector3.new(0,2,side*77),wood,true)
  block(fence,"EndRailOutline",Vector3.new(158,.14,.6),Vector3.new(0,3.06,side*77),ink,false)
  for i=-3,3 do
   block(fence,"SidePost",Vector3.new(.8,3.6,.8),Vector3.new(side*79,1.8,i*24),ink,true)
   block(fence,"EndPost",Vector3.new(.8,3.6,.8),Vector3.new(i*24,1.8,side*77),ink,true)
  end
 end
 local gameSign=container(grounds,"GameSign","Model")
 local signCF=origin*CFrame.new(0,7,-76)
 local board=part(gameSign,"Nameboard",Vector3.new(25,4.1,.45),signCF,wood,false)
 label(board,Enum.NormalId.Front,"SKIPPING ROPE")
 label(board,Enum.NormalId.Back,"SKIPPING ROPE")
 for _,x in {-10,10} do part(gameSign,"Post",Vector3.new(.55,5,.55),signCF*CFrame.new(x,-4.3,0),ink,true) end
 outline(gameSign,gameSign)
 local rulesCF=origin*CFrame.new(43,5.6,-61)*CFrame.Angles(0,math.pi/4,0)
 local rules=part(grounds,"RulesBoard",Vector3.new(13,5.8,.5),rulesCF,cream,false)
 label(rules,Enum.NormalId.Front,"JUMP THE ROPE\nStay in your circle\nLast jumpers standing win!")
 for _,x in {-5,5} do part(grounds,"RulesPost",Vector3.new(.4,3,.4),rulesCF*CFrame.new(x,-4.25,0),ink,true) end
 for key,value in {GameId="SkippingRope",IslandNumber=6,FloorY=origin.Position.Y,MinimumPlayers=2,MaxPlayers=24,RoundDuration=120,LaneCount=3,SpotsPerLane=8,SpectatorSeats=24,SpectatorSeatingVersion="20261012-four-per-bench",BuildVersion="20261012",StudMaterial=variant.Name} do arena:SetAttribute(key,value) end
 arena:SetAttribute("SROriginCFrame",origin)
 arena:SetAttribute("BuildComplete",true)
 return arena
end

local ok,arena=pcall(build,workspace)
if not ok then
 local partial=workspace:FindFirstChild("Skipping Rope")
 if partial and partial:GetAttribute("BuildVersion")=="20261012" then partial.Parent=backup partial.Name="IncompleteIsland" end
 error(arena)
end
for child,name in oldRoot do assert(child.Parent==workspace and child.Name==name,"Existing workspace object changed") end
local target=Instance.new("ObjectValue")
target.Name="CreatedIsland"
target.Value=arena
target.Parent=backup
local partCount=0
for _,part in arena:GetDescendants() do if part:IsA("BasePart") then partCount+=1 end end
arena:SetAttribute("PartCount",partCount)
backup:SetAttribute("CreatedPartCount",partCount)
return {island=arena:GetFullName(),parts=partCount,lanes=#arena.Gameplay.Lanes:GetChildren(),entrySpawns=#arena.Gameplay.EntrySpawns:GetChildren(),spectatorSpawns=#arena.Gameplay.SpectatorSpawns:GetChildren()}

