local W=workspace local CS=game:GetService("CollectionService")
local floor=W.Lobby["Lobby floor"] local O=floor.Position+Vector3.new(0,floor.Size.Y/2,0)
local report={checks=0,failures={},details={}}
local function check(ok,message)
 report.checks+=1 if not ok then table.insert(report.failures,message) end
end
local function inside(p,pad)
 local q=floor.CFrame:PointToObjectSpace(p)
 return math.abs(q.X)<=floor.Size.X/2-(pad or 0) and math.abs(q.Z)<=floor.Size.Z/2-(pad or 0)
end
check(W.Lobby:GetAttribute("MigrationComplete")==true,"Migration completion")
check(math.abs(floor.Size.X-288.3426818847656)<.01 and math.abs(floor.Size.Z-200.13206481933594)<.01,"Doubled footprint")
local counts={GBloxEggStand=3,GBloxEggRing=6,GBloxCommunityGift=1,GBloxTreadmill=2,GBloxAbilityCounter=1}
for tag,count in counts do
 local list=CS:GetTagged(tag) check(#list==count,tag.." duplicate count")
 for _,o in list do check(o:IsDescendantOf(W) and inside(o.Position,2),tag.." outside lobby: "..o:GetFullName()) end
end
for _,ring in CS:GetTagged("GBloxEggRing") do check((ring.Position-ring:GetAttribute("RingRestCFrame").Position).Magnitude<.02,"Ring animation base "..ring.Name) end
local gift=W["Join community + Like game"]
check((gift:GetPivot().Position-gift:GetAttribute("GiftRestPivot").Position).Magnitude<.02,"Gift animation base")
for _,p in gift:GetDescendants() do if p:IsA("BasePart") then check(p.Anchored and not p.CanCollide,"Gift physics "..p.Name) end end
local navFilter=OverlapParams.new()
navFilter.FilterType=Enum.RaycastFilterType.Exclude
navFilter.FilterDescendantsInstances={W.LobbyNavigationTargets,W.LobbyCoins}
navFilter.RespectCanCollide=true
for _,marker in W.LobbyNavigationTargets:GetChildren() do
 check(inside(marker.Position,5),"Navigation bounds "..marker.Name)
 local hits=W:GetPartBoundsInBox(CFrame.new(marker.Position+Vector3.new(0,3,0)),Vector3.new(3,5,3),navFilter)
 check(#hits==0,"Navigation obstructed "..marker.Name..": "..(#hits>0 and hits[1]:GetFullName() or ""))
 local ray=RaycastParams.new() ray.FilterType=Enum.RaycastFilterType.Exclude ray.FilterDescendantsInstances={W.LobbyNavigationTargets,W.LobbyCoins} ray.RespectCanCollide=true
 local hit=W:Raycast(marker.Position+Vector3.new(0,1,0),Vector3.new(0,-3,0),ray)
 check(hit~=nil and hit.Normal.Y>.9,"Navigation lacks floor "..marker.Name)
end
local counter=CS:GetTagged("GBloxAbilityCounter")[1]
check(Vector2.new(counter.Position.X-W.LobbyNavigationTargets.Shops.Position.X,counter.Position.Z-W.LobbyNavigationTargets.Shops.Position.Z).Magnitude<10,"Shop navigation activation radius")
for _,stand in CS:GetTagged("GBloxEggStand") do
 local found=false for _,p in stand:GetDescendants() do if p:IsA("ProximityPrompt") then found=true end end
 check(found,"Egg prompts retained "..stand.Name)
end
local closest=math.huge
for _,stand in CS:GetTagged("GBloxEggStand") do closest=math.min(closest,(stand.Position-W.LobbyNavigationTargets.Eggs.Position).Magnitude) end
check(closest<=14,"Egg navigation activation radius")
for _,s in W.Lobby:GetChildren() do if s:IsA("SpawnLocation") then
 check(s.Enabled and inside(s.Position,6),"Spawn placement "..s.Name)
 local hits=W:GetPartBoundsInBox(CFrame.new(s.Position+Vector3.new(0,3,0)),Vector3.new(3,5,3),navFilter)
 check(#hits==0,"Spawn obstructed "..s.Name)
end end
for _,m in W.TeleportZones:GetChildren() do if m:IsA("Model") then
 check(inside(m.ZoneContainer.Position,8),"Party bounds "..m.Name)
 check(m.BillboardGui.Adornee==m.ZoneContainer,"Party label "..m.Name)
 check(m.ZoneContainer.Position.Y-m.ZoneContainer.Size.Y/2>O.Y+8,"Party floor height "..m.Name)
end end
check(inside(W.TeleportZones.LobbyPos.Position,8),"Queue exit target")
for _,belt in CS:GetTagged("GBloxTreadmill") do
 local console=belt.Parent:FindFirstChild(belt.Name:gsub("_Belt$","_Console"))
 local dir=console.Position-belt.Position dir=Vector3.new(dir.X,0,dir.Z).Unit
 local frame=CFrame.lookAt(belt.Position,belt.Position+dir)
 local exit=frame:PointToWorldSpace(Vector3.new(0,0,belt.Size.Z/2+4))
 local ray=RaycastParams.new() ray.FilterType=Enum.RaycastFilterType.Exclude ray.FilterDescendantsInstances={belt.Parent} ray.RespectCanCollide=true
 local hit=W:Raycast(exit+Vector3.new(0,8,0),Vector3.new(0,-30,0),ray)
 check(hit~=nil and hit.Normal.Y>.6 and inside(hit.Position,4),"Treadmill safe exit "..belt.Name)
end
local Placement=assert(loadstring([====[-- Spatial placement shared by the live coin service and Edit-mode migration checks.
local Placement={}
function Placement.Contains(floor,position,margin)
 local p=floor.CFrame:PointToObjectSpace(position)
 margin=margin or 5
 return math.abs(p.X)<=floor.Size.X/2-margin and math.abs(p.Z)<=floor.Size.Z/2-margin
  and math.abs(p.Y-(floor.Size.Y/2+2.8))<.1
end
function Placement.IsClear(floor,folder,coin,position)
 if not Placement.Contains(floor,position,5) then return false end
 local excluded={floor,folder}
 local nav=workspace:FindFirstChild("LobbyNavigationTargets")
 if nav then table.insert(excluded,nav) end
 local overlap=OverlapParams.new()
 overlap.FilterType=Enum.RaycastFilterType.Exclude
 overlap.FilterDescendantsInstances=excluded
 if #workspace:GetPartBoundsInBox(CFrame.new(position+Vector3.new(0,1.2,0)),Vector3.new(5,7.5,5),overlap)>0 then return false end
 for _,other in folder:GetChildren() do
  if other~=coin and other:IsA("BasePart") and (other.Position-position).Magnitude<6 then return false end
 end
 return true
end
function Placement.Find(floor,folder,coin,rng,attempts)
 for _=1,attempts or 400 do
  local position=floor.CFrame:PointToWorldSpace(Vector3.new(
   rng:NextNumber(-floor.Size.X/2+5,floor.Size.X/2-5),
   floor.Size.Y/2+2.8,
   rng:NextNumber(-floor.Size.Z/2+5,floor.Size.Z/2-5)))
  if (position-coin.Position).Magnitude>=12 and Placement.IsClear(floor,folder,coin,position) then return position end
 end
 return nil
end
return Placement
]====]))()
local n=0 for _,coin in W.LobbyCoins:GetChildren() do if coin:IsA("BasePart") then
 n+=1 check(Placement.IsClear(floor,W.LobbyCoins,coin,coin.Position),"Coin obstructed "..coin.Name)
 check((coin:GetAttribute("RestCFrame").Position-coin.Position).Magnitude<.01,"Coin animation base "..coin.Name)
end end
check(n==45,"All 45 coins retained")
local rng=Random.new(101)
for i=1,100 do
 local p=Placement.Find(floor,W.LobbyCoins,W.LobbyCoins.BoltCoin_1,rng)
 check(p~=nil and Placement.IsClear(floor,W.LobbyCoins,W.LobbyCoins.BoltCoin_1,p),"Coin respawn sample "..i)
end
local compiled=0
for _,svc in {game.ServerScriptService,game.ReplicatedStorage,game.StarterPlayer,game.StarterGui,game.ReplicatedFirst,W} do for _,s in svc:GetDescendants() do if s:IsA("LuaSourceContainer") then
 local f,e=loadstring(s.Source,s:GetFullName()) check(f~=nil,"Syntax "..s:GetFullName()..": "..tostring(e)) compiled+=1
end end end
report.details.compiledScripts=compiled report.details.coins=n report.details.sampledRespawns=100
report.details.mode="Edit only; no gameplay, purchases or data writes performed"
return game:GetService("HttpService"):JSONEncode(report)
