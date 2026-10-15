local M={}
local offsets={Vector3.zero,Vector3.new(-.72,0,0),Vector3.new(.72,0,0),
 Vector3.new(0,0,-.95),Vector3.new(0,0,.95),
 Vector3.new(-.72,0,-.95),Vector3.new(-.72,0,.95),
 Vector3.new(.72,0,-.95),Vector3.new(.72,0,.95)}
local down=Vector3.new(0,-3.45,0)
local up=Vector3.new(0,3.45,0)
local positiveY=Vector3.yAxis
local negativeY=-Vector3.yAxis
local ray=RaycastParams.new()
ray.FilterType=Enum.RaycastFilterType.Exclude
ray.RespectCanCollide=true
local excluded={}
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
 if excluded[1]~=character then
  excluded[1]=character
  ray.FilterDescendantsInstances=excluded
 end
 local direction=sign==1 and down or up
 local normal=sign==1 and positiveY or negativeY
 -- Support is synchronous, so these query parameters are never shared across a yield.
 for _,offset in offsets do
  local hit=workspace:Raycast(position+offset,direction,ray)
  if hit and hit.Normal:Dot(normal)>.9 and validPlatform(hit.Instance) then
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
