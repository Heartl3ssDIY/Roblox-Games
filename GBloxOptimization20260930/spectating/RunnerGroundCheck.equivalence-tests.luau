local assertions=0
local function check(value,message) assertions+=1 assert(value,message) end
local actualTypeof=typeof
local function typeof(value)
 if type(value)=="table" and value.fakeInstance then return "Instance" end
 return actualTypeof(value)
end
local allocated=0
local RaycastParams={new=function() allocated+=1 return {FilterDescendantsInstances={}} end}
local state
local workspace={}
function workspace:Raycast(origin,direction,ray)
 local record={origin=origin,direction=direction,filter=ray.FilterDescendantsInstances[1],collide=ray.RespectCanCollide,filterType=ray.FilterType}
 table.insert(state.trace,record)
 return state.hits[#state.trace]
end
local old=(function()
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
end)()
local updated=(function()
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
end)()
local function part(name,kind)
 local p={Name=name,CanCollide=true,inWorld=true,fakeInstance=true,kind=kind or "Part",attrs={}}
 function p:IsA(class) return class=="BasePart" or class==self.kind end
 function p:IsDescendantOf(w) return self.inWorld and w==workspace end
 function p:GetAttribute(key) return self.attrs[key] end
 return p
end
local surface=part("RunSurface")
local characterA={}
local characterB={}
local position=Vector3.new(10,20,30)
local function execute(module,character,point,sign,hits)
 state={hits=hits or {},trace={}}
 local p,h=module.Support(character,point,sign)
 return p,h,state.trace
end
local function compare(character,point,sign,hits,label)
 local p1,h1,t1=execute(old,character,point,sign,hits)
 local p2,h2,t2=execute(updated,character,point,sign,hits)
 check(p1==p2 and h1==h2,label.." results")
 check(#t1==#t2,label.." ray count")
 for i,a in t1 do
  local b=t2[i]
  check(a.origin==b.origin and a.direction==b.direction,label.." ray geometry "..i)
  check(a.filter==b.filter and a.filter==character and a.collide==b.collide and a.filterType==b.filterType,label.." ray filter "..i)
 end
end
for _,sign in {1,-1} do
 for index=1,9 do
  local hits={}
  hits[index]={Instance=surface,Normal=Vector3.new(0,sign,0),Distance=3.08}
  compare(characterA,position,sign,hits,"offset "..index.." sign "..sign)
 end
end
compare(nil,position,1,{},"nil character")
compare(characterB,position,-1,{},"different character")
compare(characterA,position,1,{},"filter restored")
compare(characterA,nil,1,{},"nil point")
compare(characterA,Vector3.new(math.huge,0,0),1,{},"infinite point")
compare(characterA,Vector3.new(0/0,0,0),1,{},"NaN point")
compare(characterA,position,0,{},"invalid sign")
compare(characterA,Vector3.new(10000000,0,0),1,{},"oversize point")
local invalid=part("Decoration")
compare(characterA,position,1,{{Instance=invalid,Normal=Vector3.yAxis,Distance=1},{Instance=surface,Normal=Vector3.yAxis,Distance=3}},"ignore decoration")
surface.CanCollide=false
compare(characterA,position,1,{{Instance=surface,Normal=Vector3.yAxis,Distance=3}},"noncollidable")
surface.CanCollide=true surface.inWorld=false
compare(characterA,position,1,{{Instance=surface,Normal=Vector3.yAxis,Distance=3}},"outside world")
surface.inWorld=true
compare(characterA,position,1,{{Instance=surface,Normal=Vector3.new(0,.9,0),Distance=3}},"normal threshold")
for _,p in {part("Spawn","SpawnLocation"),part("RunnerPlayerCollider"),part("Other")} do
 if p.Name=="Other" then p.attrs.RunnerValidPlatform=true end
 compare(characterA,position,1,{{Instance=p,Normal=Vector3.yAxis,Distance=3}},p.Name)
end
local priorAllocated=allocated
for i=1,50 do execute(updated,i%2==0 and characterA or characterB,position,1,{}) end
check(allocated==priorAllocated,"no RaycastParams allocations per updated query")
for _,case in {
 {age=0,offset=0,y=0,speed=36,grace=.1},
 {age=-.101,offset=0,y=0,speed=36,grace=.1},
 {age=-.1,offset=0,y=0,speed=36,grace=.1},
 {age=.501,offset=0,y=0,speed=36,grace=.1},
 {age=.5,offset=0,y=0,speed=36,grace=.1},
 {age=0,offset=4.59,y=0,speed=36,grace=.1},
 {age=0,offset=4.61,y=0,speed=36,grace=.1},
 {age=0,offset=0,y=2.5,speed=36,grace=.1},
 {age=0,offset=0,y=2.51,speed=36,grace=.1},
} do
 local takeoff=position+Vector3.new(case.offset,case.y,0)
 state={hits={{Instance=surface,Normal=Vector3.yAxis,Distance=3}},trace={}}
 local a=old.ValidTakeoff(characterA,position,1,takeoff,surface,position,100-case.age,100,case.speed,case.grace)
 state={hits={{Instance=surface,Normal=Vector3.yAxis,Distance=3}},trace={}}
 local b=updated.ValidTakeoff(characterA,position,1,takeoff,surface,position,100-case.age,100,case.speed,case.grace)
 check(a==b,"takeoff bounds equivalence")
end
for _,sign in {1,-1} do for _,y in {-18,0,18} do
 local v=Vector3.new(-36,y,4)
 check(old.RejectedVelocity(v,sign)==updated.RejectedVelocity(v,sign),"rejected velocity unchanged")
end end
return assertions

