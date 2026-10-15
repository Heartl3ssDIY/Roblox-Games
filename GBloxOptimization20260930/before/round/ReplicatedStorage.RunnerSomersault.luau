local RunService=game:GetService("RunService")
local Players=game:GetService("Players")
local Ground=require(script.Parent.RunnerGroundCheck)
local config=require(script.Parent.RunnerConfig)
local M={}
local active={}
local function restore(character)
 local state=active[character] if not state then return end
 for joint,base in state.joints do if joint.Parent then joint.C0=base end end
 active[character]=nil
end
M.Reset=restore
function M.Play(character,oldSign,newSign)
 if not character then return end
 restore(character)
 local root=character:FindFirstChild("HumanoidRootPart")
 local torso=character:FindFirstChild("Torso")
 local rootJoint=root and root:FindFirstChild("RootJoint")
 if not torso or not rootJoint or not rootJoint:IsA("Motor6D") then return end
 local old=CFrame.lookAt(Vector3.zero,Vector3.new(-1,0,0),Vector3.new(0,oldSign,0))
 local new=CFrame.lookAt(Vector3.zero,Vector3.new(-1,0,0),Vector3.new(0,newSign,0))
 local joints={[rootJoint]=rootJoint.C0}
 for _,n in {"Left Hip","Right Hip","Left Shoulder","Right Shoulder"} do
  local j=torso:FindFirstChild(n) if j and j:IsA("Motor6D") then joints[j]=j.C0 end
 end
 local offset=new:ToObjectSpace(old)
 active[character]={root=root,joint=rootJoint,joints=joints,offset=offset,started=os.clock(),sign=newSign}
 rootJoint.C0=offset*joints[rootJoint]
end
RunService.PreSimulation:Connect(function()
 local now=os.clock()
 for character,s in active do
  if not character.Parent or not s.root.Parent or s.root.Anchored then restore(character) continue end
  local age=now-s.started
  if age>.12 and not s.landing and Ground.Support(character,s.root.Position,s.sign) then
   s.landing=now s.landPose=s.joint.C0
   s.landJoints={} for j in s.joints do s.landJoints[j]=j.C0 end
  end
  if s.landing then
   local t=math.clamp((now-s.landing)/.12,0,1)
   for j,base in s.joints do j.C0=s.landJoints[j]:Lerp(base,t) end
   if t>=1 then restore(character) end
  else
   local t=math.clamp(age/config.SomersaultDuration,0,1)
   local smooth=t*t*(3-2*t)
   local tuck=math.sin(math.pi*t)^2
   s.joint.C0=s.offset:Lerp(CFrame.identity,smooth)*CFrame.Angles(-2*math.pi*smooth,0,0)*s.joints[s.joint]
   for j,base in s.joints do if j~=s.joint then
    local angle=j.Name:find("Hip") and -1.1 or -.65
    j.C0=CFrame.new(base.Position)*CFrame.Angles(angle*tuck,0,0)*base.Rotation
   end end
   if t>=1 then restore(character) end
  end
 end
end)
local function observe(player)
 if player==Players.LocalPlayer then return end
 local last=player:GetAttribute("GravitySign")
 player:GetAttributeChangedSignal("GravitySign"):Connect(function()
  local sign=player:GetAttribute("GravitySign")
  if last and sign and sign~=last and player:GetAttribute("RunnerStatus")=="Running" then M.Play(player.Character,last,sign) end
  last=sign
 end)
 player.CharacterRemoving:Connect(restore)
end
Players.PlayerAdded:Connect(observe)
for _,p in Players:GetPlayers() do observe(p) end
return M
