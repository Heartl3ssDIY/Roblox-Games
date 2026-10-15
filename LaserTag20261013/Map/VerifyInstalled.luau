local arena=assert(workspace:FindFirstChild("Stuck in the Mud"))
local backup=assert(game.ServerStorage:FindFirstChild("LaserTagVisualBackup20261013"))
local chunks=backup.Manifest:GetChildren()
table.sort(chunks,function(a,b) return a.Name<b.Name end)
local encoded={}
for _,p in chunks do table.insert(encoded,p.Value) end
local manifest=game:GetService("HttpService"):JSONDecode(table.concat(encoded))
local checks=0
local changed=0
local byKind={}
for i,row in manifest.parts do
 local ref=assert(backup.ColourTargets:FindFirstChild(string.format("Part%04d",i)))
 local p=assert(ref.Value,"Missing original part")
 assert(p.Color==Color3.new(unpack(row.after)),"Palette mismatch: "..p:GetFullName());checks+=1
 assert(p.CFrame==CFrame.new(unpack(row.cf)),"Part moved: "..p:GetFullName());checks+=1
 assert(p.Size==Vector3.new(unpack(row.size)),"Part resized: "..p:GetFullName());checks+=1
 assert(p.Material.Name==row.material and p.MaterialVariant==row.variant,"Material changed");checks+=2
 assert(p.CanCollide==row.canCollide and p.CanQuery==row.canQuery and p.CanTouch==row.canTouch,"Collision changed");checks+=3
 assert(p.Transparency==row.transparency,"Visibility changed");checks+=1
 if ref:GetAttribute("OriginalColor")~=ref:GetAttribute("InstalledColor") then
  changed+=1;byKind[row.kind]=(byKind[row.kind] or 0)+1
 end
end
local deck=assert(arena.Geometry:FindFirstChild("LaserSpectatorDeck"))
local spawns=assert(arena.Gameplay:FindFirstChild("SpectatorSpawns"))
local overlaps=OverlapParams.new();overlaps.RespectCanCollide=true
local rays=RaycastParams.new();rays.RespectCanCollide=true;rays.FilterType=Enum.RaycastFilterType.Include;rays.FilterDescendantsInstances={deck}
for _,marker in spawns:GetChildren() do
 assert(marker.Position.Z+2<arena.Gameplay.ArenaBounds.Position.Z-arena.Gameplay.ArenaBounds.Size.Z/2);checks+=1
 assert(#workspace:GetPartBoundsInBox(marker.CFrame,Vector3.new(3,4.8,3),overlaps)==0);checks+=1
 local floor=workspace:Raycast(marker.Position,Vector3.new(0,-8,0),rays)
 assert(floor and floor.Instance.Name=="DeckOutline" and math.abs(floor.Position.Y-78.9)<.01);checks+=1
 assert(marker.CFrame.LookVector.Z>.99);checks+=1
end
assert(#spawns:GetChildren()==60)
return {passed=true,checks=checks,partsPreserved=#manifest.parts,partsRecoloured=changed,recolouredByKind=byKind,spectatorSpawns=60,initialFullPropertyChecks=backup:GetAttribute("ChecksPassed"),deckChecks=deck:GetAttribute("ChecksPassed"),globalLightingChanged=false,playTestPerformed=false}
