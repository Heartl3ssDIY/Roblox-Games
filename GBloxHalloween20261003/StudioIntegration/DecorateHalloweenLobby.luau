local root=workspace["Halloween lobby"]
local lobby=root.Lobby
local templates=game.ServerStorage.HalloweenImportedModels
assert(#templates:GetChildren()==9,"Incomplete transfer")
assert(not root:FindFirstChild("Halloween Decor"),"Already decorated")
local unaffected={}
for _,p in ipairs(workspace:GetDescendants()) do if p:IsA("BasePart") and not p:IsDescendantOf(root) then unaffected[p]={p.Color,p.Material,p.CFrame,p.Size} end end
local palette={
["4,162,182"]={183,92,30},["0,202,214"]={255,156,54},["36,103,141"]={105,65,145},["60,139,148"]={140,91,170},["73,100,123"]={82,62,106},
["157,174,186"]={156,142,170},["211,225,233"]={235,226,204},["18,48,71"]={47,30,67},["94,113,128"]={83,70,96},["34,70,106"]={53,36,77},
["137,160,175"]={156,137,168},["14,37,58"]={47,30,67},["205,244,255"]={255,199,119}}
local changed,lights=0,0
for _,p in ipairs(lobby:GetDescendants()) do
if p:IsA("BasePart") then
local key=math.round(p.Color.R*255)..","..math.round(p.Color.G*255)..","..math.round(p.Color.B*255)
local rgb=palette[key]
if rgb then p:SetAttribute("HalloweenLobbyOriginalColor",p.Color) p.Color=Color3.fromRGB(table.unpack(rgb)) changed+=1 end
elseif p:IsA("Light") then
p:SetAttribute("HalloweenLobbyOriginalColor",p.Color) p:SetAttribute("HalloweenLobbyOriginalBrightness",p.Brightness)
p.Color=Color3.fromRGB(255,195,121)
p.Brightness=0.55
lights+=1
end
end
local decor=Instance.new("Folder") decor.Name="Halloween Decor" decor.Parent=root
local counts={}
local function place(name,label,x,y,z,scale,yaw)
local m=templates[name]:Clone() m.Name=label
m:ScaleTo(scale or 1)
local cf,size=m:GetBoundingBox()
local target=CFrame.new(x,y+size.Y/2,z)*CFrame.Angles(0,math.rad(yaw or 0),0)
m:PivotTo(target*cf:Inverse()*m:GetPivot())
m.Parent=decor
counts[name]=(counts[name] or 0)+1
return m
end
local cx,cz,ground=1061.5545654296875,5.979380130767822,0.9377454519271851
for _,side in ipairs({-1,1}) do
for j,z in ipairs({-68,-34,0,34,64}) do
local m=place("Ectoplasm_Lantern","Warm walkway lantern "..side.." "..j,cx+side*25,ground,cz+z,1.5,side==-1 and -90 or 90)
local light=m:FindFirstChild("HalloweenWarmGlow",true) light.Range=30 light.Brightness=1.8
end
end
for _,side in ipairs({-1,1}) do
for j,z in ipairs({-73,46}) do
local x=cx+side*55
place("Jack_O_Lantern","Pumpkin cluster "..side.." "..j,x,ground,cz+z,2,side*15)
place("Jack_O_Lantern","Small pumpkin "..side.." "..j,x+side*5,ground,cz+z+3,1.3,-side*20)
place("Throwable_Pumpkin","Mini pumpkin "..side.." "..j,x-side*4,ground,cz+z-2,1,side*35)
place("Ectoplasm_Lantern","Cluster lantern "..side.." "..j,x+side*8,ground,cz+z-1,1.25,0)
end
for j=1,3 do
place(j==2 and "Gravestone_Trap" or "Gravestone_Without_Hand","Haunted grave "..side.." "..j,cx+side*(94+(j-2)*9),ground,cz-78+((j%2)*3),1.65,180+side*(j-2)*12)
end
place("Last_Place_Chaser_Ghost","Floating decorative ghost "..side,cx+side*105,ground+13,cz-77,2,180+side*15)
place("Floor_Web_Trap","Decorative floor web "..side,cx+side*94,ground+0.06,cz-66,1.5,side*25)
end
for _,x in ipairs({cx-130,cx+130}) do
for _,z in ipairs({cz-92,cz+94}) do
place("Corner_Cobweb","Upper corner cobweb",x,36,z,2.5,z>cz and 0 or 180)
end
end
local checked=0
for p,old in pairs(unaffected) do
assert(p.Color==old[1] and p.Material==old[2] and p.CFrame==old[3] and p.Size==old[4],"Original lobby changed: "..p:GetFullName()) checked+=1
end
local meshCount,lightCount=0,0
for _,p in ipairs(decor:GetDescendants()) do
if p:IsA("MeshPart") then assert(p.Anchored and not p.CanCollide and not p.CanTouch,"Unsafe decorative part") meshCount+=1 end
if p:IsA("PointLight") then assert(p.Color==Color3.fromRGB(255,183,82),"Unexpected lantern colour") lightCount+=1 end
end
return game:GetService("HttpService"):JSONEncode({lobbyRecolouredParts=changed,warmExistingLights=lights,decorModels=#decor:GetChildren(),decorMeshes=meshCount,lanternLights=lightCount,placements=counts,unchangedOriginalParts=checked,templates=#templates:GetChildren()})
