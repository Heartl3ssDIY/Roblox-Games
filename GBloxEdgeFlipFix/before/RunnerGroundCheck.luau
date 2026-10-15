local M={}
function M.Support(character,position,sign)
 local ray=RaycastParams.new() ray.FilterType=Enum.RaycastFilterType.Exclude ray.FilterDescendantsInstances={character} ray.RespectCanCollide=true
 for _,x in {0,-.65,.65} do
  local hit=workspace:Raycast(position+Vector3.new(x,0,0),Vector3.new(0,-sign*3.45,0),ray)
  if hit and hit.Normal:Dot(Vector3.new(0,sign,0))>.9 then
   local p=hit.Instance local n=p.Name:lower()
   if n:find("runsurface",1,true) or p:IsA("SpawnLocation") or n=="runnerplayercollider" or p:GetAttribute("RunnerValidPlatform")==true then return p end
  end
 end
end

function M.ValidTakeoff(character,rootPosition,sign,takeoff,support,groundPosition,groundTime,now,maxSpeed,grace)
 if typeof(takeoff)~="Vector3" or typeof(groundPosition)~="Vector3"
  or typeof(support)~="Instance" or not support:IsA("BasePart")
  or typeof(groundTime)~="number" or groundTime~=groundTime
  or not (takeoff.Magnitude<10000000 and groundPosition.Magnitude<10000000) then return false end
 -- A little transport allowance only applies to validating the original grounded sample.
 local age=now-groundTime
 if age<-.1 or age>grace+.4 then return false end
 if (rootPosition-takeoff).Magnitude>math.max(16,maxSpeed*.4) then return false end
 if math.abs(takeoff.Y-groundPosition.Y)>2.5 or (takeoff-groundPosition).Magnitude>maxSpeed*grace+1 then return false end
 return M.Support(character,groundPosition,sign)==support
end

return M
