local M={}
local function platform(p)
 if not p or not p:IsA("BasePart") or not p.CanCollide then return false end
 local name=p.Name:lower()
 return p:IsA("SpawnLocation") or name:find("runsurface",1,true)~=nil or p:GetAttribute("RunnerValidPlatform")==true
end
M.IsPlatform=platform
function M.Center(support,sign,laneZ,course)
 if not platform(support) or not support:IsDescendantOf(course) or (sign~=1 and sign~=-1) then return nil end
 local up=Vector3.new(0,sign,0)
 local half=support.Size*.5
 local lane=support.CFrame:PointToObjectSpace(Vector3.new(support.Position.X,support.Position.Y,laneZ or support.Position.Z))
 local z=math.clamp(lane.Z,-math.max(0,half.Z-1),math.max(0,half.Z-1))
 local ray=RaycastParams.new() ray.FilterType=Enum.RaycastFilterType.Include ray.FilterDescendantsInstances={support} ray.RespectCanCollide=true
 local overlap=OverlapParams.new() overlap.FilterType=Enum.RaycastFilterType.Include overlap.FilterDescendantsInstances={course}
 local extent=math.abs(support.CFrame.RightVector.Y)*half.X+math.abs(support.CFrame.UpVector.Y)*half.Y+math.abs(support.CFrame.LookVector.Y)*half.Z
 -- Prefer the centre; use only the middle portion if a hazard occupies the exact centre.
 for _,fraction in {0,.15,-.15,.3,-.3} do
  local point=support.CFrame:PointToWorldSpace(Vector3.new(half.X*fraction,0,z))
  local hit=workspace:Raycast(point+up*(extent+8),-up*(extent*2+16),ray)
  if hit and hit.Normal:Dot(up)>.9 then
   local position=hit.Position+up*3.12
   local cf=CFrame.lookAt(position,position+Vector3.new(-1,0,0),up)
   local clear=true
   for _,part in workspace:GetPartBoundsInBox(cf,Vector3.new(2.1,5.98,1.6),overlap) do
    if part~=support and (part.CanCollide or part.CanTouch) then
     local n=part.Name:lower()
     if part.CanCollide or n:find("spike",1,true) or n:find("wheel",1,true) then clear=false break end
    end
   end
   if clear then return {cframe=cf,x=position.X,sign=sign,support=support,localCFrame=support.CFrame:ToObjectSpace(cf)} end
  end
 end
 -- Some spawn pads sit partly inside a run surface; recover on that surface, not inside it.
 if support:IsA("SpawnLocation") then
  local surfaces={}
  for _,part in course:GetDescendants() do
   if platform(part) and not part:IsA("SpawnLocation") then table.insert(surfaces,part) end
  end
  ray.FilterDescendantsInstances=surfaces
  local hit=workspace:Raycast(support.Position+up*8,-up*16,ray)
  if hit and hit.Normal:Dot(up)>.9 then return M.Center(hit.Instance,sign,laneZ,course) end
 end
end
return M
