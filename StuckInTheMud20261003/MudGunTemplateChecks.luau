local assets=assert(game:GetService("ReplicatedStorage"):FindFirstChild("MudAssets"),"Install MudAssets first")
local checks=0
local function check(condition,message)
 assert(condition,message)
 checks+=1
end
local counts={}
for _,name in ipairs({"MudGun","HeatGun"}) do
 local tool=assert(assets:FindFirstChild(name),name.." missing")
 check(tool:IsA("Tool") and tool.RequiresHandle and not tool.CanBeDropped,name.." Tool flags")
 check(tool:GetAttribute("GunKind")== (name=="MudGun" and "Mud" or "Heat"),name.." GunKind")
 local handle=assert(tool:FindFirstChild("Handle"),name.." Handle missing")
 local muzzle=assert(handle:FindFirstChild("MuzzleAttachment"),name.." muzzle missing")
 check(muzzle:IsA("Attachment") and (muzzle.Position-Vector3.new(0,1,-2.65)).Magnitude<0.001,name.." stable muzzle")
 check(muzzle.CFrame.LookVector:Dot(Vector3.new(0,0,-1))>0.999,name.." muzzle forward")
 local art=assert(tool:FindFirstChild("Art"),name.." Art missing")
 local parts=0
 for _,object in ipairs(tool:GetDescendants()) do
  check(not object:IsA("LuaSourceContainer"),name.." contains no scripts")
  if object:IsA("BasePart") then
   parts+=1
   check(not object.Anchored and object.Massless and not object.CanCollide and not object.CanTouch and not object.CanQuery,name.." decorative physics flags")
   if object~=handle then
    check(object:IsDescendantOf(art),name.." replaceable Art hierarchy")
    local weld=object:FindFirstChild("HandleWeld")
    check(weld and weld:IsA("WeldConstraint") and weld.Part0==handle and weld.Part1==object,name.." welded art")
   end
  end
 end
 check(parts>=25,name.." cartoon art is present")
 counts[name]=parts
end
return {passed=checks,parts=counts,scripts=0,readOnly=true}
