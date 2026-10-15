local m=workspace["Halloween lobby"].Abilities_Shop
local backup=m:Clone() backup.Name="HalloweenAbilitiesBeforeNeon_"..os.date("%Y%m%d_%H%M%S") backup.Parent=game.ServerStorage
local purple=Color3.fromRGB(112,43,179)
local dark=Color3.fromRGB(53,36,77)
local green=Color3.fromRGB(0,255,0)
local orange=Color3.fromRGB(255,112,25)
local count=0
for _,p in ipairs(m:GetDescendants()) do if p:IsA("BasePart") then
local n=p.Name:gsub("^Abilities_Shop_","")
local color,material
if n=="CanopyStripe" or n:match("^PillarTrim") or n=="TerminalScreen" then color,material=green,Enum.Material.Neon
elseif n=="CounterStripe" or n=="DisplayBolt" then color,material=orange,Enum.Material.Neon
elseif n=="DisplayGravityRing" then color,material=Color3.fromRGB(135,64,230),Enum.Material.Neon
elseif n=="CounterBody" or n=="BackWall" or n:match("^Pillar_") then color,material=purple,Enum.Material.SmoothPlastic
elseif n=="Canopy" or n=="Foundation" or n=="SignBoard" or n=="Terminal" then color,material=dark,Enum.Material.SmoothPlastic end
if color then
local cf,size=p.CFrame,p.Size
p:SetAttribute("HalloweenCounterOriginalColor",p.Color)
p:SetAttribute("HalloweenCounterOriginalMaterial",p.Material.Name)
p.Color=color p.Material=material
assert(p.CFrame==cf and p.Size==size,"Geometry changed")
count+=1
end end end
return game:GetService("HttpService"):JSONEncode({parts=count,backup=backup.Name})
