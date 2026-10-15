assert(not game:GetService("RunService"):IsRunning(), "Stop Play before extending spectator seating")
local arena=assert(workspace:FindFirstChild("Skipping Rope"))
local version="20261012-four-per-bench"
if arena:GetAttribute("SpectatorSeatingVersion")==version then return {alreadyInstalled=true,seats=24} end
local backup=game.ServerStorage:FindFirstChild("SkippingRopeMapBackup20261012")
assert(backup and not backup:FindFirstChild("SpectatorSeatingBefore"),"Missing clean seating backup location")
local snapshot=Instance.new("Folder")
snapshot.Name="SpectatorSeatingBefore"
snapshot.Parent=backup
arena.Grounds.SpectatorBenches:Clone().Parent=snapshot
arena.Gameplay.SpectatorSpawns:Clone().Parent=snapshot
snapshot:SetAttribute("PreviousPartCount",arena:GetAttribute("PartCount"))
local index=0
for _,side in {"West","East"} do
 for row=1,3 do
  local bench=assert(arena.Grounds.SpectatorBenches:FindFirstChild(string.format("%sBench%02d",side,row)))
  local cf=bench.BenchSeat.CFrame*CFrame.new(0,-1.9,0)
  local prior={}
  for _,p in bench:GetChildren() do if p:IsA("Seat") then table.insert(prior,p) end end
  table.sort(prior,function(a,b) return a.Name<b.Name end)
  assert(#prior==2,"Expected two original bench seats")
  bench.BenchSeat.Size=Vector3.new(12.6,.5,2.6)
  bench.BenchBack.Size=Vector3.new(12.6,2.2,.4)
  for _,p in bench:GetChildren() do
   if p.Name=="Leg" and p:IsA("BasePart") then
    local localPosition=cf:PointToObjectSpace(p.Position)
    p.CFrame=cf*CFrame.new(localPosition.X<0 and -4.8 or 4.8,localPosition.Y,localPosition.Z)
   end
  end
  for seatIndex,x in {-4.5,-1.5,1.5,4.5} do
   index+=1
   local seat=prior[seatIndex]
   if not seat then seat=prior[1]:Clone() seat.Parent=bench end
   seat.Name=string.format("Seat%02d",seatIndex)
   seat.CFrame=cf*CFrame.new(x,2.2,0)
   seat.Size=Vector3.new(2.6,.1,2.2)
   seat:SetAttribute("SKSpectatorIndex",index)
   local spawn=assert(arena.Gameplay.SpectatorSpawns:FindFirstChild(string.format("Spectator%02d",index)))
   spawn.CFrame=seat.CFrame*CFrame.new(0,.8,-3.2)
   spawn:SetAttribute("SpectatorIndex",index)
   spawn:SetAttribute("SKSpectatorIndex",index)
  end
  task.wait()
 end
end
assert(index==24)
arena:SetAttribute("SpectatorSeats",24)
arena:SetAttribute("SpectatorSeatingVersion",version)
local count=0
for _,p in arena:GetDescendants() do if p:IsA("BasePart") then count+=1 end end
arena:SetAttribute("PartCount",count)
backup:SetAttribute("CreatedPartCount",count)
return {seats=index,totalMapParts=count,westIndices="1-12",eastIndices="13-24",standingOffset="Seat.CFrame * CFrame.new(0,0.8,-3.2)"}

