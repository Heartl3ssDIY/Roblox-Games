local M={}
local function finiteVector(value)
 return typeof(value)=="Vector3" and value.Magnitude<10000000
end
local function validPlatform(part)
 if not part or not part:IsA("BasePart") or not part:IsDescendantOf(workspace) or not part.CanCollide then return false end
 local name=part.Name:lower()
 return name:find("runsurface",1,true)~=nil or part:IsA("SpawnLocation")
  or name=="runnerplayercollider" or part:GetAttribute("RunnerValidPlatform")==true
end

function M.Support(character,position,sign)
 if not finiteVector(position) or (sign~=1 and sign~=-1) then return nil end
 local ray=RaycastParams.new()
 ray.FilterType=Enum.RaycastFilterType.Exclude
 ray.FilterDescendantsInstances=character and {character} or {}
 ray.RespectCanCollide=true
 -- The sideways runner collider has a 1.5-by-2 stud world-space footprint.
 -- Sample just inside its edges, including the corners, not only its centre line.
 for _,offset in {Vector3.zero,Vector3.new(-.72,0,0),Vector3.new(.72,0,0),
  Vector3.new(0,0,-.95),Vector3.new(0,0,.95),
  Vector3.new(-.72,0,-.95),Vector3.new(-.72,0,.95),
  Vector3.new(.72,0,-.95),Vector3.new(.72,0,.95)} do
  local hit=workspace:Raycast(position+offset,Vector3.new(0,-sign*3.45,0),ray)
  if hit and hit.Normal:Dot(Vector3.new(0,sign,0))>.9 and validPlatform(hit.Instance) then
   return hit.Instance,hit
  end
 end
end

function M.ValidTakeoff(character,rootPosition,sign,takeoff,support,groundPosition,groundTime,now,maxSpeed,grace)
 if not finiteVector(rootPosition) or not finiteVector(takeoff) or not finiteVector(groundPosition)
  or typeof(support)~="Instance" or not validPlatform(support)
  or typeof(groundTime)~="number" or groundTime~=groundTime then return false end
 local age=now-groundTime
 if age<-.1 or age>grace+.4 then return false end
 if (rootPosition-takeoff).Magnitude>math.max(16,maxSpeed*.4) then return false end
 if math.abs(takeoff.Y-groundPosition.Y)>2.5 or (takeoff-groundPosition).Magnitude>maxSpeed*grace+1 then return false end
 -- At a platform seam, either neighbouring surface can be the first ray hit.
 -- Revalidate actual support at the sampled position, not first-hit instance identity.
 return M.Support(character,groundPosition,sign)~=nil
end

function M.RejectedVelocity(velocity,sign)
 -- Undo the unaccepted launch, never turn it into a normal-gravity jump.
 return Vector3.new(velocity.X,math.min(velocity.Y*sign,0)*sign,0)
end
return M
