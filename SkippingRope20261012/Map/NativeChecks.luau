local arena = assert(workspace:FindFirstChild("Skipping Rope"))
local origin = arena:GetAttribute("SROriginCFrame")
local gameplay = arena.Gameplay
local checks = 0
local function check(condition, message)
 assert(condition, message)
 checks += 1
end
local function near(a, b) return (a-b).Magnitude < .015 end
local variants = game.MaterialService.PlaygroundRetroStuds
check(arena:GetAttribute("GameId") == "SkippingRope" and arena:GetAttribute("IslandNumber") == 6, "Island identity mismatch")
check(arena:GetAttribute("MinimumPlayers") == 2 and arena:GetAttribute("MaxPlayers") == 24 and arena:GetAttribute("RoundDuration") == 120, "Game limits mismatch")
check(near(origin.Position,Vector3.new(14600,33,4534)), "Island location mismatch")
check(#gameplay.Lanes:GetChildren()==3, "Expected three rope lanes")
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include
overlap.FilterDescendantsInstances = {arena}
overlap.RespectCanCollide = true
local ray = RaycastParams.new()
ray.FilterType = Enum.RaycastFilterType.Include
ray.FilterDescendantsInstances = {arena}
ray.RespectCanCollide = true
local visible, solids, ropeCount, turners, spots, spawnCount = 0,0,0,0,0,0
local function clearSpawn(marker)
 local hits=workspace:GetPartBoundsInBox(marker.CFrame,Vector3.new(2.8,4.8,2.8),overlap)
 check(#hits==0, "Spawn volume blocked: "..marker:GetFullName())
 local hit=workspace:Raycast(marker.Position,Vector3.new(0,-8,0),ray)
 check(hit and math.abs(hit.Position.Y-origin.Y)<.015, "Spawn lacks level floor: "..marker:GetFullName())
 check(marker.Transparency==1 and not marker.CanCollide and not marker.CanQuery, "Spawn marker affects gameplay")
end
for laneIndex=1,3 do
 local lane=assert(gameplay.Lanes:FindFirstChild(string.format("Lane%02d",laneIndex)))
 local cf=lane.RopeOrigin.CFrame
 check(near(cf.Position,origin:PointToWorldSpace(Vector3.new(0,0,(laneIndex-2)*34))), "Lane location mismatch")
 check(lane.ModelStreamingMode==Enum.ModelStreamingMode.Atomic,"Lane must stream atomically")
 for name,value in {LaneIndex=laneIndex,RopeHalfSpan=26,RopeFlatHalfSpan=16,RopeRadius=8,RopePivotHeight=8.8} do check(lane:GetAttribute(name)==value,"Lane setting mismatch: "..name) end
 check(#lane.Spots:GetChildren()==8,"Expected eight jumping spots")
 for index=1,8 do
  local marker=assert(lane.Spots:FindFirstChild(string.format("Spot%02d",index)))
  check(near(cf:PointToObjectSpace(marker.Position),Vector3.new(-14+(index-1)*4,3,0)),"Incorrect jumping spot")
  clearSpawn(marker)
  spots+=1
 end
 check(#lane.RopeSegments:GetChildren()==40,"Expected 40 rope segments")
 local function expected(x)
  local u=math.clamp((math.abs(x)-16)/10,0,1)
  return cf:PointToWorldSpace(Vector3.new(x,8.8+8*math.sqrt(math.max(0,1-u*u)),0))
 end
 for index=1,40 do
  local p=assert(lane.RopeSegments:FindFirstChild(string.format("Segment%02d",index)))
  local first,last=-26+(index-1)*52/40,-26+index*52/40
  check(math.abs(p:GetAttribute("RopeStartX")-first)<.001 and math.abs(p:GetAttribute("RopeEndX")-last)<.001,"Rope sample attributes mismatch")
  check(p.Shape==Enum.PartType.Cylinder,"Rope must use local-X cylinders")
  check(near(p.Position-p.CFrame.RightVector*p.Size.X/2,expected(first)) and near(p.Position+p.CFrame.RightVector*p.Size.X/2,expected(last)),"Rope rest profile differs from shared math")
  check(not p.CanCollide and not p.CanTouch and not p.CanQuery and not p.CastShadow,"Rope visual affects physics")
  ropeCount+=1
 end
 for _,name in {"LeftTurner","RightTurner"} do
  local npc=assert(lane:FindFirstChild(name))
  local side=name=="LeftTurner" and -1 or 1
  local at=cf:PointToWorldSpace(Vector3.new(side*26,8.8,0))
  check(near(npc.TurnPivot.Position,at),"NPC turn axis misplaced")
  check(near(npc.TurnArm:GetPivot().Position,at),"NPC arm base misplaced")
  check(typeof(npc.TurnArm:GetAttribute("TurnBaseCFrame"))=="CFrame","Authored arm pose missing")
  check(near(npc.TurnArm.Hand.Position,at),"NPC hand misses rope endpoint")
  check(npc.TurnArm:GetAttribute("TurnBaseCFrame").RightVector:Dot(cf.RightVector)>.999,"Turn arm local axis differs")
  check(npc:FindFirstChild("Head") and npc:FindFirstChild("Torso") and npc:FindFirstChild("CartoonOutline"),"NPC body incomplete")
  turners+=1
 end
 check(8.8-8>=.75 and 8.8+8>15,"Rope sweep lacks ground/head clearance")
end
for _,name in {"EntrySpawns","SpectatorSpawns"} do
 local group=gameplay[name]
 check(#group:GetChildren()==24,"Spawn count mismatch")
 for _,marker in group:GetChildren() do
  clearSpawn(marker)
  local p=origin:PointToObjectSpace(marker.Position)
  if name=="EntrySpawns" then check(math.abs(p.Z)>=55 and math.abs(p.Z)<=70,"Entry intrudes into rope sweep")
  else check(math.abs(p.X)>=52 and math.abs(p.X)<=61 and math.abs(p.Z)<=45,"Spectator intrudes into rope sweep") end
  spawnCount+=1
 end
end
local seatCount, used = 0, {}
for _, bench in arena.Grounds.SpectatorBenches:GetChildren() do
 local benchCF = bench.BenchSeat.CFrame * CFrame.new(0,-1.9,0)
 local count=0
 check(math.abs(bench.BenchSeat.Size.X-12.6)<.001 and math.abs(bench.BenchBack.Size.X-12.6)<.001,"Bench width mismatch")
 for _,seat in bench:GetChildren() do if seat:IsA("Seat") then
  count+=1
  local index=seat:GetAttribute("SKSpectatorIndex")
  check(type(index)=="number" and index>=1 and index<=24 and not used[index],"Spectator seat index duplicated")
  used[index]=true
  local marker=gameplay.SpectatorSpawns:FindFirstChild(string.format("Spectator%02d",index))
  check(marker and marker:GetAttribute("SKSpectatorIndex")==index,"Spectator seat has no matching spawn")
  check(near(marker.Position,(seat.CFrame*CFrame.new(0,.8,-3.2)).Position),"Spectator spawn offset mismatch")
  local localPos=benchCF:PointToObjectSpace(seat.Position)
  check(math.abs(localPos.X)+seat.Size.X/2<=bench.BenchSeat.Size.X/2-.1,"Seat is off the bench")
  check(seat.CanCollide and seat.Anchored and not seat.Disabled,"Spectator seat unusable")
  local towardCentre=origin.Position-Vector3.new(seat.Position.X,origin.Y,seat.Position.Z)
  check(seat.CFrame.LookVector:Dot(towardCentre.Unit)>.7,"Spectator faces away from arena")
  seatCount+=1
 end end
 check(count==4,"Bench needs four seats")
end
check(seatCount==24,"Missing spectator seats")
for _,p in arena:GetDescendants() do if p:IsA("BasePart") then
 check(p.Anchored,"Unanchored island part")
 check(p:GetAttribute("SkippingRopeMapPart")==true,"Map part is not marked")
 if p.Transparency<1 then
  visible+=1
  check(p.Material==variants.BaseMaterial,"Unexpected material")
  check(p.MaterialVariant==variants.Name or p.Color==Color3.fromRGB(24,29,36) or p:GetAttribute("RopeSegment")==true,"Visible prop is missing its stud texture")
 end
 if p.CanCollide then solids+=1 end
end end
check(gameplay.ArenaBounds.Size==Vector3.new(166,70,162),"Arena bounds mismatch")
local report={checks=checks,lanes=3,jumpSpots=spots,turners=turners,ropeSegments=ropeCount,entrySpawns=24,spectatorSpawns=24,spawnVolumesChecked=spots+spawnCount,spectatorSeats=seatCount,visibleParts=visible,solidParts=solids,authoredOrigin=tostring(origin.Position),playStarted=false,published=false}
return game:GetService("HttpService"):JSONEncode(report)

