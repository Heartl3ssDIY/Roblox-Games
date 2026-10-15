-- Assemble the avatar before displaying it: anchoring every limb prevents
-- Roblox's deferred rig joints from correcting initial part positions.
local Statue = {}
Statue.Revision = 1

local function jointFrames(joint)
 if joint:IsA("JointInstance") then
  return joint.Part0,joint.Part1,joint.C0,joint.C1,
   joint:IsA("Motor6D") and joint.Transform or CFrame.identity
 elseif joint:IsA("AnimationConstraint") or joint:IsA("RigidConstraint") then
  local a,b=joint.Attachment0,joint.Attachment1
  if a and b and a.Parent:IsA("BasePart") and b.Parent:IsA("BasePart") then
   return a.Parent,b.Parent,a.CFrame,b.CFrame,
    joint:IsA("AnimationConstraint") and joint.Transform or CFrame.identity
  end
 end
end

local function verticalExtent(part)
 local cf,size=part.CFrame,part.Size
 return (math.abs(cf.RightVector.Y)*size.X+math.abs(cf.UpVector.Y)*size.Y+math.abs(cf.LookVector.Y)*size.Z)/2
end

function Statue.Prepare(avatar,podium)
 local root=assert(avatar:FindFirstChild("HumanoidRootPart"),"Statue has no root")
 local humanoid=assert(avatar:FindFirstChildOfClass("Humanoid"),"Statue has no humanoid")
 humanoid.EvaluateStateMachine=false
 humanoid.AutoRotate=false
 humanoid.BreakJointsOnDeath=false
 humanoid.RequiresNeck=false
 humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
 humanoid.AutomaticScalingEnabled=false
 avatar.PrimaryPart=root
 avatar.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
 local scale=tonumber(podium:GetAttribute("StatueScale")) or 1.5
 avatar:ScaleTo(math.clamp(scale,.5,3))
 local descendants=avatar:GetDescendants()
 local joints={}
 for _,object in descendants do
  if object:IsA("BasePart") then
   object.Anchored=false object.CanCollide=false object.CanTouch=false object.CanQuery=false
   object.Massless=true
  elseif object:IsA("Script") or object:IsA("LocalScript") then
   object:Destroy()
  elseif object:IsA("AnimationConstraint") then
   object.IsKinematic=true object.Transform=CFrame.identity table.insert(joints,object)
  elseif object:IsA("Motor6D") then
   object.Transform=CFrame.identity table.insert(joints,object)
  elseif object:IsA("JointInstance") or object:IsA("RigidConstraint") then
   table.insert(joints,object)
  end
 end
 root.Anchored=true
 -- Resolve the root-to-head/limb/accessory graph without waiting for physics.
 local placed={[root]=true}
 for _=1,#joints+1 do
  local changed=false
  for _,joint in joints do
   local a,b,c0,c1,transform=jointFrames(joint)
   if a and b and a:IsDescendantOf(avatar) and b:IsDescendantOf(avatar) then
    local relative=c0*transform*c1:Inverse()
    if placed[a] and not placed[b] then
     b.CFrame=a.CFrame*relative placed[b]=true changed=true
    elseif placed[b] and not placed[a] then
     a.CFrame=b.CFrame*relative:Inverse() placed[a]=true changed=true
    end
   end
  end
  if not changed then break end
 end
 for _,part in avatar:GetChildren() do
  if part:IsA("BasePart") then
   assert(placed[part],"Disconnected statue body part: "..part.Name)
  end
 end
 local anchor=podium.AvatarAnchor
 avatar:PivotTo(CFrame.lookAt(anchor.Position,anchor.Position-anchor.CFrame.RightVector))
 -- Use actual feet, not a fixed root height or accessory bounding box.
 local bottom=math.huge
 for _,name in {"LeftFoot","RightFoot","Left Leg","Right Leg"} do
  local foot=avatar:FindFirstChild(name)
  if foot and foot:IsA("BasePart") then bottom=math.min(bottom,foot.Position.Y-verticalExtent(foot)) end
 end
 assert(bottom<math.huge,"Statue has no feet")
 local top=podium.Top
 local surfaceY=top.Position.Y+verticalExtent(top)
 avatar:PivotTo(avatar:GetPivot()+Vector3.new(0,surfaceY-bottom+.03,0))
 local bounds,size=avatar:GetBoundingBox()
 avatar:SetAttribute("StatueRevision",Statue.Revision)
 return bounds.Position.Y+size.Y/2+1.2
end

function Statue.Create(userId,podium)
 local avatar
 local ok,result=pcall(function()
  local players=game:GetService("Players")
  local description=players:GetHumanoidDescriptionFromUserIdAsync(userId)
  avatar=players:CreateHumanoidModelFromDescriptionAsync(description,Enum.HumanoidRigType.R15)
  description:Destroy()
  avatar.Name="ChampionAvatar"
  local signY=Statue.Prepare(avatar,podium)
  local highlight=Instance.new("Highlight")
  highlight.Name="ChampionOutline" highlight.FillTransparency=1
  highlight.OutlineColor=podium.UpperStep.Color highlight.OutlineTransparency=0
  highlight.Parent=avatar
  return signY
 end)
 if not ok then if avatar then avatar:Destroy() end error(result,0) end
 return avatar,result
end
return Statue

