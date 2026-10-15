local ReplicatedStorage=game:GetService("ReplicatedStorage")
local assets=ReplicatedStorage:FindFirstChild("MudAssets")
if not assets then
 assets=Instance.new("Folder")
 assets.Name="MudAssets"
 assets.Parent=ReplicatedStorage
end
assert(assets:IsA("Folder"),"MudAssets must be a Folder")
local ink=Color3.fromRGB(24,35,62)
local cream=Color3.fromRGB(255,246,216)
local soil=Color3.fromRGB(127,79,42)
local mud=Color3.fromRGB(161,108,62)
local green=Color3.fromRGB(112,177,88)
local orange=Color3.fromRGB(255,126,48)
local yellow=Color3.fromRGB(255,212,73)
local cylinderRotation=CFrame.Angles(0,math.pi/2,0)
local tankRotation=CFrame.Angles(0,0,math.pi/2)
local function build(name,kind)
 local old=assets:FindFirstChild(name)
 if old then
  assert(old:IsA("Tool") and old:GetAttribute("ManagedMudTemplate")==true,name.." already exists and was preserved")
  return {created=false,preserved=true,parts=#old:GetDescendants()}
 end
 local tool=Instance.new("Tool")
 tool.Name=name
 tool.RequiresHandle=true
 tool.CanBeDropped=false
 tool.ToolTip=kind=="Mud" and "Mud blaster" or "Warm blaster"
 tool.Grip=CFrame.new(0,-0.15,0)
 tool:SetAttribute("GunKind",kind)
 tool:SetAttribute("TemplateVersion",1)
 tool:SetAttribute("ManagedMudTemplate",true)
 tool:SetAttribute("MeshArtReplaceable",true)
 local handle=Instance.new("Part")
 handle.Name="Handle"
 handle.Size=Vector3.new(0.55,1.5,0.68)
 handle.Material=Enum.Material.SmoothPlastic
 handle.Color=kind=="Mud" and green or orange
 handle.Anchored=false
 handle.Massless=true
 handle.CanCollide=false
 handle.CanTouch=false
 handle.CanQuery=false
 handle.CastShadow=false
 handle.Parent=tool
 local art=Instance.new("Folder")
 art.Name="Art"
 art.Parent=tool
 local muzzle=Instance.new("Attachment")
 muzzle.Name="MuzzleAttachment"
 muzzle.CFrame=CFrame.new(0,1,-2.65)
 muzzle.Parent=handle
 local count=1
 local function part(partName,size,cframe,color,shape,material)
  local object=Instance.new("Part")
  object.Name=partName
  object.Size=size
  object.CFrame=cframe
  object.Material=material or Enum.Material.SmoothPlastic
  object.Color=color
  if shape then object.Shape=shape end
  object.Anchored=false
  object.Massless=true
  object.CanCollide=false
  object.CanTouch=false
  object.CanQuery=false
  object.CastShadow=false
  object.Parent=art
  local weld=Instance.new("WeldConstraint")
  weld.Name="HandleWeld"
  weld.Part0=handle
  weld.Part1=object
  weld.Parent=object
  count+=1
  return object
 end
 local function box(partName,size,position,color)
  return part(partName,size,CFrame.new(position),color)
 end
 local function ball(partName,size,position,color)
  return part(partName,size,CFrame.new(position),color,Enum.PartType.Ball)
 end
 local function barrel(partName,length,diameter,position,color)
  return part(partName,Vector3.new(length,diameter,diameter),CFrame.new(position)*cylinderRotation,color,Enum.PartType.Cylinder)
 end
 box("Body",Vector3.new(1.35,1.2,2.1),Vector3.new(0,1,-0.55),kind=="Mud" and green or orange)
 box("Belly",Vector3.new(1.4,0.28,1.55),Vector3.new(0,0.58,-0.4),cream)
 box("BackBumper",Vector3.new(1.45,0.92,0.24),Vector3.new(0,1,0.58),ink)
 box("TopRim",Vector3.new(1.42,0.09,2.15),Vector3.new(0,1.62,-0.55),ink)
 box("BottomRim",Vector3.new(1.42,0.09,2.15),Vector3.new(0,0.4,-0.55),ink)
 for _,side in ipairs({-1,1}) do
  box("SidePanel",Vector3.new(0.08,0.75,1.25),Vector3.new(side*0.715,1,-0.35),cream)
  for _,z in ipairs({-0.85,0.15}) do ball("ToyBolt",Vector3.new(0.14,0.16,0.16),Vector3.new(side*0.77,1.23,z),ink) end
 end
 for _,y in ipairs({-0.58,-0.3,0,0.28}) do box("GripRib",Vector3.new(0.6,0.055,0.73),Vector3.new(0,y,0),ink) end
 box("GripFoot",Vector3.new(0.69,0.16,0.8),Vector3.new(0,-0.74,0),cream)
 ball("ThumbButton",Vector3.new(0.42,0.32,0.38),Vector3.new(0,0.42,-0.73),kind=="Mud" and mud or yellow)
 barrel("NozzleCollar",0.32,1.06,Vector3.new(0,1,-1.63),ink)
 barrel("WideNozzle",0.66,1.38,Vector3.new(0,1,-2.08),kind=="Mud" and mud or yellow)
 barrel("NozzleRim",0.12,1.47,Vector3.new(0,1,-2.45),ink)
 barrel("NozzleFace",0.13,1.24,Vector3.new(0,1,-2.53),kind=="Mud" and soil or orange)
 if kind=="Mud" then
  part("MuddyTank",Vector3.new(1.12,1.15,1.15),CFrame.new(0,2.05,0.1)*tankRotation,soil,Enum.PartType.Cylinder)
  part("TankCap",Vector3.new(0.16,1.25,1.25),CFrame.new(0,2.67,0.1)*tankRotation,green,Enum.PartType.Cylinder)
  ball("TankKnob",Vector3.new(0.48,0.3,0.48),Vector3.new(0,2.84,0.1),cream)
  box("TankWindow",Vector3.new(0.11,0.68,0.6),Vector3.new(0.62,2.03,0.1),mud)
  for index,position in ipairs({Vector3.new(-0.48,0.61,-2.5),Vector3.new(0.35,0.5,-2.52),Vector3.new(0.63,0.84,-2.5)}) do
   ball("MudDrip"..index,Vector3.new(0.24,0.42,0.26),position,soil)
  end
  for _,side in ipairs({-1,1}) do
   ball("MudBadge",Vector3.new(0.09,0.49,0.65),Vector3.new(side*0.77,0.97,-0.3),mud)
   ball("MudBadgeDot",Vector3.new(0.1,0.18,0.18),Vector3.new(side*0.82,1.18,-0.66),soil)
  end
 else
  part("WarmCore",Vector3.new(1.0,0.72,0.72),CFrame.new(0,2.0,0.1)*tankRotation,orange,Enum.PartType.Cylinder)
  for index=1,5 do
   part("WarmCoil"..index,Vector3.new(0.095,1.08,1.08),CFrame.new(0,1.62+index*0.18,0.1)*tankRotation,yellow,Enum.PartType.Cylinder)
  end
  part("CoilCap",Vector3.new(0.15,1.18,1.18),CFrame.new(0,2.62,0.1)*tankRotation,ink,Enum.PartType.Cylinder)
  ball("WarmKnob",Vector3.new(0.48,0.32,0.48),Vector3.new(0,2.81,0.1),yellow)
  for _,side in ipairs({-1,1}) do
   ball("SunBadge",Vector3.new(0.1,0.48,0.48),Vector3.new(side*0.78,0.97,-0.3),yellow)
   for _,y in ipairs({0.65,1.29}) do box("SunRay",Vector3.new(0.09,0.16,0.13),Vector3.new(side*0.79,y,-0.3),orange) end
  end
 end
 tool.Parent=assets
 return {created=true,parts=count,muzzle=muzzle:GetFullName()}
end
return {MudGun=build("MudGun","Mud"),HeatGun=build("HeatGun","Heat"),folder=assets:GetFullName(),scripts=0,forward="Handle local -Z",muzzleOffset=Vector3.new(0,1,-2.65)}
