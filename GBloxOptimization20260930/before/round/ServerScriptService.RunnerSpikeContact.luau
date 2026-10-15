-- Server-only, conservative body/teeth contact. No movement-collider or accessory damage.
local Contact = {}
local samples = {-0.8, 0, 0.8}
local function segment(teeth, body, a, b, toothRay, coverRay)
 local hit = workspace:Raycast(a, b-a, toothRay)
 if not hit then hit=workspace:Raycast(b,a-b,toothRay) end
 if not hit or hit.Instance~=teeth then return false end
 -- Test from the body centre: a platform between the avatar and contact shields it.
 local direction=hit.Position-body.Position
 if direction.Magnitude>0.001 and workspace:Raycast(body.Position,direction,coverRay) then return false end
 return true
end
function Contact.HasContact(teeth, character, course)
 if not teeth or not teeth.Parent or not teeth.CanQuery or teeth.Transparency>=1 then return false end
 local ancestor=teeth.Parent
 while ancestor and ancestor~=workspace do
  if ancestor:GetAttribute("GBloxPlatformMissing")==true then return false end
  ancestor=ancestor.Parent
 end
 local toothRay=RaycastParams.new()
 toothRay.FilterType=Enum.RaycastFilterType.Include
 toothRay.FilterDescendantsInstances={teeth}
 toothRay.RespectCanCollide=false
 local coverRay=RaycastParams.new()
 coverRay.FilterType=Enum.RaycastFilterType.Include
 coverRay.FilterDescendantsInstances={course}
 coverRay.RespectCanCollide=true
 for _,body in character:GetChildren() do
  if body:IsA("BasePart") and body.Name~="HumanoidRootPart"
   and body.Name~="RunnerCollider" and body.Name~="RunnerPlayerCollider"
   and body.Transparency<1 then
   local localCentre=teeth.CFrame:PointToObjectSpace(body.Position)
   local reach=body.Size.Magnitude*.5
   local half=teeth.Size*.5
   if math.abs(localCentre.X)<=half.X+reach and math.abs(localCentre.Y)<=half.Y+reach
    and math.abs(localCentre.Z)<=half.Z+reach then
    -- Slight inward tolerance: touching the invisible outer movement box is never enough.
    local h=Vector3.new(math.max(.01,body.Size.X*.5-.04),math.max(.01,body.Size.Y*.5-.04),math.max(.01,body.Size.Z*.5-.04))
    for _,u in samples do for _,v in samples do
     for axis=1,3 do
      local a,b
      if axis==1 then a=Vector3.new(-h.X,u*h.Y,v*h.Z) b=Vector3.new(h.X,u*h.Y,v*h.Z)
      elseif axis==2 then a=Vector3.new(u*h.X,-h.Y,v*h.Z) b=Vector3.new(u*h.X,h.Y,v*h.Z)
      else a=Vector3.new(u*h.X,v*h.Y,-h.Z) b=Vector3.new(u*h.X,v*h.Y,h.Z) end
      if segment(teeth,body,body.CFrame:PointToWorldSpace(a),body.CFrame:PointToWorldSpace(b),toothRay,coverRay) then return true end
     end
    end end
   end
  end
 end
 return false
end
return Contact

