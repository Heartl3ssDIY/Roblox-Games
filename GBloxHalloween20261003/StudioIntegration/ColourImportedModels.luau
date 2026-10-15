local targets = {"Bone_Saw_Base_Without_Wheel","Floor_Web_Trap","Last_Place_Chaser_Ghost","Jack_O_Lantern","Corner_Cobweb","Gravestone_Without_Hand","Ectoplasm_Lantern","Throwable_Pumpkin","Gravestone_Trap"}
local C = {green=Color3.fromRGB(151,249,44),dark=Color3.fromRGB(53,36,77),purple=Color3.fromRGB(132,72,162),stone=Color3.fromRGB(117,107,139),bone=Color3.fromRGB(235,226,191),orange=Color3.fromRGB(245,111,26),stem=Color3.fromRGB(74,110,44),earth=Color3.fromRGB(80,54,43),black=Color3.fromRGB(24,17,34),amber=Color3.fromRGB(255,184,76),skin=Color3.fromRGB(118,172,72),ghost=Color3.fromRGB(213,244,214)}
local groups = {
green={"RedSpike_Base_Cyan","Ghost_Green_Pupil"},
dark={"RedSpike_Base_DarkMetal","Lantern_Foot","Lantern_Frame","Lantern_Handle","Lantern_Roof","Torn_Cuff"},
purple={"RedSpike_Base_Edge","Lantern_Cap"},
stone={"RedSpike_Base_RunSurface","Arched_Headstone","Grave_Plinth"},
bone={"Skull","Skull_Tooth","Ghost_Fang","Finger_Nail","Web_Radial","Web_Scalloped_Ring","Grave_Cross_Horizontal","Grave_Cross_Vertical"},
orange={"Jack_O_Lantern_Lobed_Skin","Throwable_Pumpkin_Lobed_Skin"},
stem={"Bent_Pumpkin_Stem","Curled_Pumpkin_Vine"},
earth={"Broken_Earth","Disturbed_Earth"},
black={"Skull_Eye","Skull_Nose","Ghost_Eye","Ghost_Open_Mouth","Carved_Eye","Stone_Crack"},
amber={"Lantern_Luminous_Core","Eye_Glow","Jagged_Grin"},
skin={"Finger_1","Finger_2","Finger_3","Finger_4","Finger_Knuckle","Forearm","Hooked_Thumb","Palm"},
ghost={"Ghost_Flowing_Body","Ghost_Reaching_Arm"}}
local palette={Inset_Stone_Panel=Color3.fromRGB(76,63,95)}
for key,names in pairs(groups) do for _,n in ipairs(names) do palette[n]=C[key] end end
local models,parts={},{}
for _,name in ipairs(targets) do
local m=assert(workspace:FindFirstChild(name),"Missing "..name)
table.insert(models,m)
for _,p in ipairs(m:GetDescendants()) do
if p:IsA("BasePart") then
local n=p.Name:gsub("^Halloween_",""):gsub("%.%d+$","")
assert(palette[n],"Unmapped part "..p:GetFullName())
table.insert(parts,{part=p,key=n,cf=p.CFrame,size=p.Size,collide=p.CanCollide,touch=p.CanTouch,query=p.CanQuery,anchor=p.Anchored,transparency=p.Transparency,mesh=p:IsA("MeshPart") and p.MeshId})
end end end
local backup=Instance.new("Folder")
backup.Name="HalloweenImportsBeforeColour_"..os.date("%Y%m%d_%H%M%S")
for _,m in ipairs(models) do m:Clone().Parent=backup end
backup.Parent=game.ServerStorage
for _,entry in ipairs(parts) do
local p,n=entry.part,entry.key
p:SetAttribute("HalloweenImportOriginalColor",p.Color)
p:SetAttribute("HalloweenImportOriginalMaterial",p.Material.Name)
p.Color=palette[n]
p.Material=Enum.Material.SmoothPlastic
if n=="Lantern_Luminous_Core" or n=="Eye_Glow" or n=="Jagged_Grin" or n=="Ghost_Green_Pupil" or n=="RedSpike_Base_Cyan" then p.Material=Enum.Material.Neon end
if n=="Lantern_Luminous_Core" then
local light=Instance.new("PointLight")
light.Name="HalloweenWarmGlow"
light.Color=Color3.fromRGB(255,183,82)
light.Brightness=1.6
light.Range=22
light.Shadows=true
light.Parent=p
end
assert(p.CFrame==entry.cf and p.Size==entry.size and p.CanCollide==entry.collide and p.CanTouch==entry.touch and p.CanQuery==entry.query and p.Anchored==entry.anchor and p.Transparency==entry.transparency,"Geometry or physics changed")
if entry.mesh then assert(p.MeshId==entry.mesh,"Mesh changed") end
end
return game:GetService("HttpService"):JSONEncode({models=#models,parts=#parts,backup=backup:GetFullName(),lanternLight="255,183,82; brightness 1.6; range 22",geometryAndPhysicsUnchanged=true})
