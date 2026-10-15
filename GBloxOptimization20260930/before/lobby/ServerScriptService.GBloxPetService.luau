local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local PetService = {}
local PET_NAMES = {
 "Falcon","Eagle","Bat","Hummingbird","Ostrich","Cheetah","Lion",
 "Hare","Bloodhound","Horse","Shark","Swordfish","Alien","Orca",
}
local WINGED = {Falcon=true,Eagle=true,Bat=true,Hummingbird=true,Ostrich=true}

local templates = ReplicatedStorage:FindFirstChild("GBloxPetTemplates") or Instance.new("Folder")
templates.Name = "GBloxPetTemplates"
templates.Parent = ReplicatedStorage
local hatched = ServerStorage:FindFirstChild("GBloxPetHatched") or Instance.new("BindableEvent")
hatched.Name = "GBloxPetHatched"
hatched.Parent = ServerStorage

local function petId(name)
 local lower = string.lower(name)
 for _,id in PET_NAMES do
  if string.find(lower,string.lower(id),1,true) then return id end
 end
end

local function headOf(model)
 for _,part in model:GetDescendants() do
  if part:IsA("BasePart") and string.find(string.lower(part.Name),"head_pearl_cube",1,true) then return part end
 end
 return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart",true)
end

local function wingSide(name)
 local s=string.lower(name)
 if string.find(s,"wing_l",1,true) or string.find(s,"thruster_l",1,true) or string.find(s,"vfx_l_jet",1,true) or string.find(s,"wing_-1",1,true) then return "L" end
 if string.find(s,"wing_r",1,true) or string.find(s,"thruster_r",1,true) or string.find(s,"vfx_r_jet",1,true) or string.find(s,"wing_1",1,true) then return "R" end
end

local function addVFX(model)
 for _,part in model:GetDescendants() do
  if not part:IsA("BasePart") or not string.match(part.Name,"^VFX_") then continue end
  part.Material=Enum.Material.Neon
  part.Color=Color3.fromRGB(24,241,255)
  part.CastShadow=false part.CanCollide=false part.CanTouch=false part.CanQuery=false part.Massless=true
  part.Transparency=string.find(part.Name,"Underlight",1,true) and .45 or .12
  local light=part:FindFirstChild("GBloxGlowLight") or Instance.new("PointLight")
  light.Name="GBloxGlowLight" light.Color=part.Color light.Shadows=false
  light.Brightness=string.find(part.Name,"Underlight",1,true) and .7 or 1.25
  light.Range=string.find(part.Name,"Underlight",1,true) and 5 or 3
  light.Parent=part
  if string.find(part.Name,"Jet",1,true) or string.find(part.Name,"SpeedRail",1,true) then
   local width=math.max(.04,math.min(part.Size.X,part.Size.Y,part.Size.Z)*.18)
   local a=part:FindFirstChild("GBloxTrailA") or Instance.new("Attachment")
   a.Name="GBloxTrailA" a.Position=Vector3.new(-width,0,0) a.Parent=part
   local b=part:FindFirstChild("GBloxTrailB") or Instance.new("Attachment")
   b.Name="GBloxTrailB" b.Position=Vector3.new(width,0,0) b.Parent=part
   local trail=part:FindFirstChild("GBloxVelocityTrail") or Instance.new("Trail")
   trail.Name="GBloxVelocityTrail" trail.Attachment0=a trail.Attachment1=b
   trail.Color=ColorSequence.new(part.Color)
   trail.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.25),NumberSequenceKeypoint.new(1,1)})
   trail.WidthScale=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)})
   trail.Lifetime=.18 trail.MinLength=.025 trail.FaceCamera=true trail.LightEmission=1 trail.Enabled=false
   trail.Parent=part
  end
 end
end

local function rig(model,id)
 local head=headOf(model)
 if not head then return false end
 model.PrimaryPart=head
 model:SetAttribute("GBloxPetId",id)
 addVFX(model)
 if model:GetAttribute("GBloxRigged") then return true end

 local wingParts={L={},R={}}
 for _,part in model:GetDescendants() do if part:IsA("BasePart") and part~=head then
  part.Anchored=false part.CanCollide=false part.CanTouch=false part.CanQuery=false part.Massless=true
  local side=WINGED[id] and wingSide(part.Name)
  if side then table.insert(wingParts[side],part) end
 end end
 head.Anchored=true head.CanCollide=false head.CanTouch=false head.CanQuery=false head.Massless=true

 local rigFolder=Instance.new("Folder")
 rigFolder.Name="GBloxWingRig"
 rigFolder.Parent=model
 local assigned={}
 if WINGED[id] then
  for _,side in {"L","R"} do
   local sign=side=="L" and -1 or 1
   local anchor=Instance.new("Part")
   anchor.Name="WingAnchor_"..side anchor.Size=Vector3.new(.12,.12,.12)
   anchor.Transparency=1 anchor.CanCollide=false anchor.CanTouch=false anchor.CanQuery=false anchor.Massless=true anchor.Anchored=false
   anchor.CFrame=head.CFrame*CFrame.new(sign*head.Size.X/2,0,0)
   anchor.Parent=rigFolder
   local motor=Instance.new("Motor6D")
   motor.Name="WingMotor_"..side motor.Part0=head motor.Part1=anchor
   motor.C0=head.CFrame:ToObjectSpace(anchor.CFrame) motor.C1=CFrame.identity
   motor.Parent=head
   motor:SetAttribute("GBloxWingSide",side)
   for _,part in wingParts[side] do
    local weld=Instance.new("WeldConstraint")
    weld.Name="GBloxWingWeld" weld.Part0=anchor weld.Part1=part weld.Parent=part
    assigned[part]=true
   end
  end
 end
 for _,part in model:GetDescendants() do if part:IsA("BasePart") and part~=head and not assigned[part] and not part:IsDescendantOf(rigFolder) then
  local weld=Instance.new("WeldConstraint")
  weld.Name="GBloxBodyWeld" weld.Part0=head weld.Part1=part weld.Parent=part
 end end
 model:SetAttribute("GBloxRigged",true)
 return true
end

function PetService.RefreshTemplates()
 local source=workspace:FindFirstChild("Pets")
 if not source then return 0 end
 local found={} local count=0
 for _,model in source:GetDescendants() do if model:IsA("Model") then
  local id=petId(model.Name)
  if id and not found[id] and headOf(model) and rig(model,id) then
   found[id]=true count+=1
   local old=templates:FindFirstChild(id)
   if old then old:Destroy() end
   local clone=model:Clone()
   clone.Name=id
   clone.Parent=templates
  end
 end end
 templates:SetAttribute("GBloxTemplateCount",count)
 return count
end

function PetService.Equip(player,id)
 if typeof(player)~="Instance" or not player:IsA("Player") or typeof(id)~="string" then return false end
 local template=templates:FindFirstChild(id)
 if not template then return false end
 player:SetAttribute("GBloxEquippedPet",id)
 return true
end

function PetService.Unequip(player)
 if typeof(player)=="Instance" and player:IsA("Player") then player:SetAttribute("GBloxEquippedPet",nil) end
end

function PetService.RegisterHatch(player,id)
 -- Your future server-side probability/stat system should call this only after
 -- it has charged the egg and selected a valid pet.
 return PetService.Equip(player,id)
end

PetService.RefreshTemplates()
hatched.Event:Connect(function(player,id) PetService.RegisterHatch(player,id) end)
return PetService

