local storage=game.ServerStorage
local originals=workspace:FindFirstChild("GunGripAudit20261004")
local fixtures=storage:FindFirstChild("WeaponRigFixtures") or Instance.new("Folder")
fixtures.Name="WeaponRigFixtures" fixtures.Parent=storage
if originals then for _,r in ipairs(originals:GetChildren())do if not fixtures:FindFirstChild(r.Name)then local c=r:Clone()c.Parent=fixtures end end end
local old=workspace:FindFirstChild("GunGripPosePreview20261004")if old then old:Destroy()end
local folder=Instance.new("Folder")folder.Name="GunGripPosePreview20261004"folder.Parent=workspace
local result={}
local function poseMap(r,kind)
 local id=kind=="Tool" and r.Animate.toolnone.ToolNoneAnim.AnimationId or r.Animate.walk.WalkAnim.AnimationId
 local seq=game.ServerStorage.WeaponRigFixtures:FindFirstChild("GunAuditAnimation"..id:match("%d+$"))
 local frames=seq:GetKeyframes()table.sort(frames,function(a,b)return a.Time<b.Time end)
 local frame=frames[kind=="Tool" and 1 or math.max(1,math.floor(#frames/3))]
 local out={}for _,p in ipairs(frame:GetDescendants())do if p:IsA("Pose")and p.Weight>0 then out[p.Name]=p.CFrame end end
 return out
end
for i,name in ipairs({"R6","R15"})do
 for j,gunName in ipairs({"MudGun","HeatGun"})do
  for k,stance in ipairs({"Stand","Walk"})do
   local r=fixtures[name]:Clone()r.Name=name.."_"..gunName.."_"..stance
   for _,c in ipairs(r:GetChildren())do if c:IsA("Tool")then c:Destroy()end end
   local poses=stance=="Walk" and poseMap(r,"Walk")or {}
   for p,cf in pairs(poseMap(r,"Tool"))do if p:find("Right")then poses[p]=cf end end
   r.Parent=folder;r:PivotTo(CFrame.new((i-1)*12+(j-1)*6,1100,(k-1)*-11))
   local remaining={}
   for _,p in ipairs(r:GetDescendants())do
    if p:IsA("BasePart")then p.Anchored=true
    elseif p:IsA("Motor6D")then table.insert(remaining,{a=p.Part0,b=p.Part1,c0=p.C0,c1=p.C1})p.Enabled=false
    elseif p:IsA("AnimationConstraint")then table.insert(remaining,{a=p.Attachment0.Parent,b=p.Attachment1.Parent,c0=p.Attachment0.CFrame,c1=p.Attachment1.CFrame})p.Enabled=false
    elseif p:IsA("Constraint")then p.Enabled=false end
   end
   local known={[r.HumanoidRootPart]=true}
   for pass=1,20 do for _,q in ipairs(remaining)do if known[q.a] and not known[q.b]then q.b.CFrame=q.a.CFrame*q.c0*(poses[q.b.Name]or CFrame.identity)*q.c1:Inverse();known[q.b]=true end end end
   local t=game.ReplicatedStorage.MudAssets[gunName]:Clone()
   local holder=Instance.new("Folder")holder.Name="WeaponPreview"holder.Parent=r;t.Parent=holder
   local h=t.Handle
   local hand=r:FindFirstChild("RightHand")or r:FindFirstChild("Right Arm")
   local nativeC0=name=="R6"and CFrame.new(0,-1,0)*CFrame.Angles(-math.pi/2,0,0)or hand.RightGripAttachment.CFrame
   local target=hand.CFrame*nativeC0*t.Grip:Inverse()
   local delta=target*h.CFrame:Inverse()
   local cfs={}for _,p in ipairs(t:GetDescendants())do if p:IsA("WeldConstraint")then p.Enabled=false elseif p:IsA("BasePart")then p.Anchored=true;cfs[p]=p.CFrame end end
   for p,cf in pairs(cfs)do p.CFrame=delta*cf end
   local muzzle=h.MuzzleAttachment
   table.insert(result,{name=r.Name,forward=muzzle.WorldCFrame.LookVector:Dot(r.HumanoidRootPart.CFrame.LookVector),up=h.CFrame.UpVector:Dot(Vector3.yAxis),handGap=(hand.Position-h.Position).Magnitude})
  end
 end
end
return game.HttpService:JSONEncode(result)

