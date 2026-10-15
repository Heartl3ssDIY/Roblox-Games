local RunService=game:GetService("RunService")
local Motion={}
local states=setmetatable({},{__mode="k"})

local function state(model)
 local s=states[model]
 if s then return s end
 s={wheels={},doors={},spin=0,door=0,cargo={}}
 local root=model:GetPivot()
 for _,group in model:GetChildren() do
  if group:IsA("Model") then
   local kind=group:GetAttribute("RigType")
   if kind=="wheel" then
    table.insert(s.wheels,{model=group,home=root:ToObjectSpace(group:GetPivot()),radius=group:GetAttribute("Radius") or 1})
   elseif kind=="door" then
    table.insert(s.doors,{model=group,home=root:ToObjectSpace(group:GetPivot()),angle=math.rad(group:GetAttribute("OpenAngle") or 110)})
   end
  end
 end
 states[model]=s
 return s
end

function Motion.pose(model,cf,distance)
 local s=state(model)
 s.spin+=distance or 0
 model:PivotTo(cf)
 for _,w in s.wheels do w.model:PivotTo(cf*w.home*CFrame.Angles(-s.spin/w.radius,0,0)) end
 for _,d in s.doors do d.model:PivotTo(cf*d.home*CFrame.Angles(0,d.angle*s.door,0)) end
end

function Motion.doorFraction(model,fraction)
 state(model).door=math.clamp(fraction,0,1)
 Motion.pose(model,model:GetPivot(),0)
end

function Motion.doors(model,open,duration)
 local s=state(model)
 local from=s.door
 local target=open and 1 or 0
 duration=duration or 0.65
 if duration<=0 then Motion.doorFraction(model,target);return end
 local start=os.clock()
 repeat
  if not model.Parent then return end
  local a=math.clamp((os.clock()-start)/duration,0,1)
  Motion.doorFraction(model,from+(target-from)*(a*a*(3-2*a)))
  if a>=1 then break end
  RunService.Heartbeat:Wait()
 until false
end

function Motion.route(model,plot,pad)
 local inbound=pad.Parent.Name=="OffloadBays"
 local outward=(inbound and pad.CFrame.LookVector or -pad.CFrame.LookVector)
 outward=Vector3.new(outward.X,0,outward.Z).Unit
 local yard=plot.wh:FindFirstChild("WarehouseVisuals")
 yard=yard and yard:FindFirstChild("Yard")
 local road=yard and yard:FindFirstChild(inbound and "ReceivingApron" or "DispatchApron")
 local ground=workspace:FindFirstChild("Baseplate")
 local low=ground and ground.Position.Y+ground.Size.Y/2 or 0
 local high=road and road.Position.Y+road.Size.Y/2 or pad.Position.Y
 local half=road and (math.abs(road.CFrame.RightVector:Dot(outward))*road.Size.X+math.abs(road.CFrame.LookVector:Dot(outward))*road.Size.Z)/2 or 65
 local edge=road and (road.Position-pad.Position):Dot(outward)+half or 135
 local rot=CFrame.lookAt(Vector3.zero,outward)
 local rear=model:GetPivot():PointToObjectSpace(model.RearDoor.Position)
 local p=pad.Position+outward*16-rot:VectorToWorldSpace(rear)
 p=Vector3.new(p.X,high+.035,p.Z)
 local function at(d,y)
  local q=pad.Position+outward*d
  return Vector3.new(q.X,y+.035,q.Z)
 end
 return {park=CFrame.new(p)*rot,outward=outward,pad=pad.Position,edge=edge,high=high,low=low,ramp=12,
  points={p,at(edge,high),at(edge+12,low),at(edge+44,low)}}
end

function Motion.roadPose(model,route,position)
 local function height(p)
  local d=(p-route.pad):Dot(route.outward)
  return route.high+(route.low-route.high)*math.clamp((d-route.edge)/route.ramp,0,1)
 end
 local h0=height(position-route.outward*3)
 local h1=height(position+route.outward*3)
 local cf=CFrame.lookAt(Vector3.new(position.X,height(position)+.035,position.Z),Vector3.new(position.X,height(position)+.035,position.Z)+route.outward+Vector3.new(0,(h1-h0)/6,0))
 local raise=0
 for _,w in state(model).wheels do
  local p=(cf*w.home).Position
  raise=math.max(raise,height(p)+.025-(p.Y-w.radius))
 end
 return cf+Vector3.new(0,raise,0)
end

function Motion.drive(model,route,reverse)
 local points={}
 if reverse then for i=#route.points,1,-1 do table.insert(points,route.points[i]) end
 else for _,p in route.points do table.insert(points,p) end end
 for _,p in model:GetDescendants() do if p:IsA("BasePart") then p.CanCollide=false end end
 local segments={};local total=0
 for i=1,#points-1 do local len=(points[i+1]-points[i]).Magnitude;table.insert(segments,{a=points[i],b=points[i+1],length=len,start=total});total+=len end
 local travelled=0;local last=model:GetPivot().Position
 while travelled<total and model.Parent do
  local dt=math.min(RunService.Heartbeat:Wait(),.1)
  local remaining=total-travelled
  local speed=reverse and math.clamp(math.sqrt(remaining)*5,5,24) or math.clamp(8+travelled*.5,8,30)
  travelled=math.min(total,travelled+speed*dt)
  local segment=segments[#segments]
  for _,v in segments do if travelled<=v.start+v.length then segment=v;break end end
  local pos=segment.a:Lerp(segment.b,math.clamp((travelled-segment.start)/segment.length,0,1))
  local cf=Motion.roadPose(model,route,pos)
  local distance=(cf.Position-last).Magnitude*(reverse and -1 or 1)
  Motion.pose(model,cf,distance);last=cf.Position
  if not reverse and travelled>total-20 then
   local alpha=math.clamp((travelled-(total-20))/20,0,1)
   for _,p in model:GetDescendants() do if p:IsA("BasePart") and not p:GetAttribute("RigMarker") then p.Transparency=alpha end end
  end
 end
end

local function parcelVisual(source)
 local visual=Instance.new("Model");visual.Name="CargoParcel"
 local body
 if source then
  body=source:Clone()
  for _,d in body:GetDescendants() do
   if d:IsA("ProximityPrompt") or d:IsA("LuaSourceContainer") or d:IsA("Highlight") or d:IsA("SelectionBox") then d:Destroy() end
  end
 else
  body=Instance.new("Part");body.Name="Package";body.Size=Vector3.new(1.8,1.6,1.6)
  body.Color=Color3.fromRGB(190,146,90);body.Material=Enum.Material.Cardboard
  local tape=Instance.new("Part");tape.Name="Tape";tape.Size=Vector3.new(.28,.014,1.6);tape.Color=Color3.fromRGB(220,187,129)
  tape.CFrame=body.CFrame*CFrame.new(0,.807,0);tape.Parent=body
 end
 body.Parent=visual;visual.PrimaryPart=body
 for _,d in visual:GetDescendants() do
  if d:IsA("BasePart") then d.Anchored=true;d.CanCollide=false;d.CanQuery=false;d.CanTouch=false end
 end
 for _,d in visual:GetDescendants() do if d:IsA("JointInstance") or d:IsA("WeldConstraint") then d:Destroy() end end
 visual:PivotTo(CFrame.identity)
 return visual
end

function Motion.cargo(model,count,capacity,source)
 local s=state(model);local bounds=model:FindFirstChild("CargoBounds")
 if not bounds then return end
 local limit=math.min(capacity,60)
 local wanted=count>0 and math.min(limit,math.ceil(count/capacity*limit)) or 0
 while #s.cargo>wanted do local v=table.remove(s.cargo);v:Destroy() end
 local columns=3;local rows=math.max(1,math.ceil(limit/9));local layers=math.ceil(limit/(columns*rows))
 local cell=Vector3.new(bounds.Size.X/columns,bounds.Size.Y/layers,bounds.Size.Z/rows)
 while #s.cargo<wanted do
  local i=#s.cargo;local col=i%columns;local row=math.floor(i/columns)%rows;local layer=math.floor(i/(columns*rows))
  local v=parcelVisual(source);local _,size=v:GetBoundingBox()
  local scale=math.min(cell.X/size.X,cell.Y/size.Y,cell.Z/size.Z)*.92
  v:ScaleTo(v:GetScale()*scale)
  local center,sz=v:GetBoundingBox()
  local bottom=-bounds.Size.Y/2+.015
  for level=0,layer-1 do
   local below=s.cargo[level*columns*rows+row*columns+col+1]
   if below then local _,bs=below:GetBoundingBox();bottom+=bs.Y+.02 end
  end
  local offset=Vector3.new(-bounds.Size.X/2+cell.X*(col+.5),bottom+sz.Y/2,-bounds.Size.Z/2+cell.Z*(row+.5))
  v:PivotTo(bounds.CFrame*CFrame.new(offset)*CFrame.new(v:GetPivot().Position-center.Position))
  v.Parent=model;table.insert(s.cargo,v)
 end
end

return Motion
