-- One numbered zone contains several independently removable platform models.
local M={}
local active={}
local function surface(part)
 return part:IsA("BasePart") and part.Name:lower():find("runsurface",1,true)~=nil
end
function M.Find(course,position)
 local passed={}
 for _,zone in course:GetDescendants() do
  if zone:IsA("Model") and zone.Name:lower():match("zone[_ ]%d+$") then
   local edge=math.huge
   local platforms={}
   for _,model in zone:GetChildren() do
    if model:IsA("Model") then
     local support
     for _,part in model:GetDescendants() do
      if surface(part) then
       local cf,h=part.CFrame,part.Size*.5
       local extent=math.abs(cf.RightVector.X)*h.X+math.abs(cf.UpVector.X)*h.Y+math.abs(cf.LookVector.X)*h.Z
       edge=math.min(edge,part.Position.X-extent)
       if part.CanCollide and not model:GetAttribute("GBloxPlatformMissing") then support=support or part end
      end
     end
     if support then table.insert(platforms,{model=model,support=support}) end
    end
   end
   -- Courses run toward negative X; the whole previous zone must be behind.
   if edge<math.huge and edge>position.X+.01 then
    table.insert(passed,{zone=zone,edge=edge,platforms=platforms})
   end
  end
 end
 table.sort(passed,function(a,b) return a.edge<b.edge end)
 local previous=passed[1]
 if not previous then return nil end
 local best,score
 for _,entry in previous.platforms do
  local p=entry.support.Position
  local distance=math.abs(p.Y-position.Y)+math.abs(p.Z-position.Z)
  if not score or distance<score then best=entry.model score=distance end
 end
 return best,previous.zone
end
function M.Hide(model,duration,schedule)
 if not model or not model.Parent or active[model] or model:GetAttribute("GBloxPlatformMissing") then return false end
 local snapshot={}
 for _,v in model:GetDescendants() do
  local properties
  if v:IsA("BasePart") then
   properties={Transparency=v.Transparency,CanCollide=v.CanCollide,CanTouch=v.CanTouch,CanQuery=v.CanQuery}
  elseif v:IsA("Decal") or v:IsA("Texture") then properties={Transparency=v.Transparency}
  elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") or v:IsA("Light") or v:IsA("SurfaceGui") or v:IsA("BillboardGui") then properties={Enabled=v.Enabled} end
  if properties then table.insert(snapshot,{instance=v,properties=properties}) end
 end
 if #snapshot==0 then return false end
 active[model]=snapshot
 model:SetAttribute("GBloxPlatformMissing",true)
 for _,entry in snapshot do
  local v=entry.instance
  if v:IsA("BasePart") then v.Transparency=1 v.CanCollide=false v.CanTouch=false v.CanQuery=false
  elseif entry.properties.Transparency~=nil then v.Transparency=1 else v.Enabled=false end
 end
 local function restore()
  if active[model]~=snapshot then return end
  active[model]=nil
  for _,entry in snapshot do
   if entry.instance.Parent then
    for property,value in entry.properties do entry.instance[property]=value end
   end
  end
  if model.Parent then model:SetAttribute("GBloxPlatformMissing",nil) end
 end
 (schedule or task.delay)(duration,restore)
 return true,restore
end
return M

