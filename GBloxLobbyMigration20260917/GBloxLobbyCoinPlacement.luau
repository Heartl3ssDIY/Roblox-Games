-- Spatial placement shared by the live coin service and Edit-mode migration checks.
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

