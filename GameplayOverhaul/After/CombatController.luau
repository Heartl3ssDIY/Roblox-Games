-- CombatController: client side of the black market. Currently powers the Flying Carpet -- while the
-- carpet tool is equipped you glide with WASD + Space/Shift (relative to the camera). Desktop controls.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local plr=Players.LocalPlayer

local flying=false; local bv=nil; local conn=nil

local function stopFlight(char)
	flying=false
	if conn then conn:Disconnect(); conn=nil end
	if bv then bv:Destroy(); bv=nil end
	if char then local c=char:FindFirstChild("CarpetVisual"); if c then c:Destroy() end end
end

local function startFlight(char)
	local hrp=char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart",3)
	if not hrp then return end
	flying=true
	bv=Instance.new("BodyVelocity"); bv.Name="CarpetFly"; bv.MaxForce=Vector3.new(1,1,1)*1e5; bv.Velocity=Vector3.zero; bv.Parent=hrp
	local carpet=Instance.new("Part"); carpet.Name="CarpetVisual"; carpet.Size=Vector3.new(5,0.4,7)
	carpet.Color=Color3.fromRGB(170,45,65); carpet.Material=Enum.Material.Fabric; carpet.CanCollide=false; carpet.Massless=true; carpet.Anchored=false
	carpet.CFrame=hrp.CFrame*CFrame.new(0,-3,0)
	local weld=Instance.new("WeldConstraint"); weld.Part0=hrp; weld.Part1=carpet; weld.Parent=carpet; carpet.Parent=char
	conn=RunService.RenderStepped:Connect(function()
		if not flying or not bv or not bv.Parent then stopFlight(char); return end
		local cam=workspace.CurrentCamera; if not cam then return end
		local dir=Vector3.zero
		if UIS:IsKeyDown(Enum.KeyCode.W) then dir+=cam.CFrame.LookVector end
		if UIS:IsKeyDown(Enum.KeyCode.S) then dir-=cam.CFrame.LookVector end
		if UIS:IsKeyDown(Enum.KeyCode.A) then dir-=cam.CFrame.RightVector end
		if UIS:IsKeyDown(Enum.KeyCode.D) then dir+=cam.CFrame.RightVector end
		if UIS:IsKeyDown(Enum.KeyCode.Space) then dir+=Vector3.new(0,1,0) end
		if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then dir+=Vector3.new(0,-1,0) end
		bv.Velocity = (dir.Magnitude>0) and (dir.Unit*65) or Vector3.new(0,0.1,0)
	end)
end

local function hookChar(char)
	char.ChildAdded:Connect(function(c) if c:IsA("Tool") and c.Name=="Flying Carpet" then startFlight(char) end end)
	char.ChildRemoved:Connect(function(c) if c:IsA("Tool") and c.Name=="Flying Carpet" then stopFlight(char) end end)
	local hum=char:FindFirstChildOfClass("Humanoid")
	if hum then hum.Died:Connect(function() stopFlight(char) end) end
end

-- Retired: the Magic Carpet is now a self-contained tool (ServerStorage.MagicCarpet) with its own
-- flight scripts, so the old generic carpet flight above is no longer hooked up.
local _=hookChar  -- keep reference (defined-but-unused) without running it

do
 local tags=game:GetService("CollectionService")
 local rigs=setmetatable({},{__mode="k"})
 local function watch(model,npc)
  if rigs[model] then return end
  local root=model:FindFirstChild("HumanoidRootPart") or model:WaitForChild("HumanoidRootPart",5)
  if not root or rigs[model] then return end
  local motors={}
  model.DescendantAdded:Connect(function(joint) if joint:IsA("Motor6D") then motors[joint.Name]={joint=joint,rotation=joint.C0.Rotation} end end)
  for _,joint in model:GetDescendants() do if joint:IsA("Motor6D") then motors[joint.Name]={joint=joint,rotation=joint.C0.Rotation} end end
  rigs[model]={root=root,motors=motors,npc=npc,last=root.Position,phase=0,speed=0,carry=0,bend=0}
 end
 tags:GetInstanceAddedSignal("WarehouseNPC"):Connect(function(m) task.defer(watch,m,true) end)
 for _,m in tags:GetTagged("WarehouseNPC") do watch(m,true) end
 local function player(p)
  p.CharacterAdded:Connect(function(c) c:WaitForChild("HumanoidRootPart");task.wait(.5);watch(c,false) end)
  if p.Character then task.defer(function() p.Character:WaitForChild("HumanoidRootPart");watch(p.Character,false) end) end
 end
 Players.PlayerAdded:Connect(player)
 for _,p in Players:GetPlayers() do player(p) end
 task.spawn(function()
  while true do
   for _,m in tags:GetTagged("WarehouseNPC") do if m:IsDescendantOf(workspace) and not rigs[m] then task.spawn(watch,m,true) end end
   task.wait(1)
  end
 end)
 RunService.PreSimulation:Connect(function(dt)
  for model,r in rigs do
   if not model.Parent or not r.root.Parent then rigs[model]=nil;continue end
   local distance=(r.root.Position-r.last).Magnitude;r.last=r.root.Position
   local speed=math.min(distance/math.max(dt,.001),30)
   r.speed+=(speed-r.speed)*math.min(dt*8,1)
   r.phase+=r.speed*dt*2.2
   r.carry+=( ((model:GetAttribute("CarryCount") or 0)>0 and 1 or 0)-r.carry)*math.min(dt*12,1)
   r.bend+=( (model:GetAttribute("PickupBend") and 1 or 0)-r.bend)*math.min(dt*12,1)
   if not r.npc and r.carry<.001 then continue end
   local walk=r.npc and math.sin(r.phase)*math.min(r.speed/8,1)*.48 or 0
   local function pose(names,x,z,weight)
    for _,name in names do
     local m=r.motors[name]
     if m and m.joint.Parent then
      local value=m.rotation:Inverse()*CFrame.Angles(x,0,z or 0)*m.rotation
      m.joint.Transform=weight and m.joint.Transform:Lerp(value,weight) or value
     end
    end
   end
   if r.npc then
    pose({"Right Hip","RightHip"},walk,0)
    pose({"Left Hip","LeftHip"},-walk,0)
    pose({"RightKnee"},-math.max(0,-walk)*.8,0)
    pose({"LeftKnee"},-math.max(0,walk)*.8,0)
    pose({"RootJoint","Waist"},-r.bend*.3,0)
   end
   local aim=model:GetAttribute("GuardAiming") and 1 or 0
   local hold=math.max(r.carry,aim)
   local x=math.rad(65)*hold
   pose({"Right Shoulder","RightShoulder"},x-walk*(1-hold),-hold*.12,not r.npc and r.carry or nil)
   pose({"Left Shoulder","LeftShoulder"},x+walk*(1-hold),hold*.12,not r.npc and r.carry or nil)
   pose({"RightElbow","LeftElbow"},hold*.35,0,not r.npc and r.carry or nil)
  end
 end)
end
