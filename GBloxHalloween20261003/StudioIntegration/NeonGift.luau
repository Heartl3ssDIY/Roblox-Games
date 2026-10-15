local gift=workspace["Halloween lobby"]["Join community + Like game"]
local backup=gift:Clone()
backup.Name="HalloweenGiftBeforeNeon_"..os.date("%Y%m%d_%H%M%S")
backup.Parent=game.ServerStorage
local changes=0
for _,p in ipairs(gift:GetDescendants()) do
if p:IsA("BasePart") then
p:SetAttribute("HalloweenGiftOriginalColor",p.Color)
p:SetAttribute("HalloweenGiftOriginalMaterial",p.Material.Name)
local cf,size,collide,touch=p.CFrame,p.Size,p.CanCollide,p.CanTouch
if p.Name=="Wrapper/Box" then p.Color=Color3.fromRGB(112,43,179) p.Material=Enum.Material.SmoothPlastic
elseif p.Name=="Ribbon Piece" then p.Color=Color3.fromRGB(0,255,0) p.Material=Enum.Material.Neon
elseif p.Name=="Part" and p:FindFirstChildWhichIsA("SpecialMesh") then p.Color=Color3.fromRGB(255,112,25) p.Material=Enum.Material.Neon
else error("Unexpected gift part "..p.Name) end
assert(p.CFrame==cf and p.Size==size and p.CanCollide==collide and p.CanTouch==touch,"Gift geometry changed")
changes+=1
end end
return game:GetService("HttpService"):JSONEncode({parts=changes,backup=backup.Name})
