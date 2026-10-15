-- G-Blox Cloud Club. Additive Studio build; existing lobby is untouched.
local Workspace=game:GetService("Workspace")
local History=game:GetService("ChangeHistoryService")
local oldFloor=assert(Workspace:FindFirstChild("Lobby"):FindFirstChild("Lobby floor"),"Original floor missing")
local NAME="G-Blox NEW Lobby - Cloud Club"
assert(not Workspace:FindFirstChild(NAME),"New lobby already exists; inspect before rebuilding")
local W,D=oldFloor.Size.X*2,oldFloor.Size.Z*2
local O=Vector3.new(oldFloor.Position.X+650,oldFloor.Position.Y+oldFloor.Size.Y/2,oldFloor.Position.Z)
local root=Instance.new("Model") root.Name=NAME
root:SetAttribute("Design","Cartoon Cloud Club - separate replacement lobby")
root:SetAttribute("OriginalLobbyUnchanged",true)
root:SetAttribute("FloorWidth",W) root:SetAttribute("FloorDepth",D)
root:SetAttribute("OffsetFromOldLobby",650)
local groups={}
for _,n in {"01 Floor and Paths","02 Walls and Arches","03 CLOSED Roof and Clouds","04 Cloud Stage and Stairs","05 Happy Gravity Statue","06 Practice Obby","07 Decorations","08 Lighting"} do
 local m=Instance.new("Model") m.Name=n m.Parent=root groups[string.sub(n,1,2)]=m
end
local C={
 cream=Color3.fromRGB(255,244,216), white=Color3.fromRGB(255,254,244),
 sky=Color3.fromRGB(113,220,244), cyan=Color3.fromRGB(0,192,222),
 blue=Color3.fromRGB(65,145,223), navy=Color3.fromRGB(43,67,118),
 pink=Color3.fromRGB(255,151,186), coral=Color3.fromRGB(255,112,123),
 yellow=Color3.fromRGB(255,214,82), lilac=Color3.fromRGB(182,163,242),
 mint=Color3.fromRGB(137,227,188), green=Color3.fromRGB(61,174,129),
 floor=Color3.fromRGB(220,244,239), dark=Color3.fromRGB(36,47,77)
}
local g=groups["01"]
local function part(n,size,pos,color,shape,solid)
 local p=Instance.new("Part") p.Name=n p.Size=size p.CFrame=CFrame.new(O+pos)
 p.Anchored=true p.CanCollide=(solid==true) p.CanTouch=false p.CanQuery=true
 p.Material=Enum.Material.SmoothPlastic p.Color=C[color] or color
 p.TopSurface=Enum.SurfaceType.Smooth p.BottomSurface=Enum.SurfaceType.Smooth
 if shape then p.Shape=shape end
 p.Parent=g return p
end
local function box(n,x,y,z,sx,sy,sz,c,solid)
 return part(n,Vector3.new(sx,sy,sz),Vector3.new(x,y,z),c,nil,solid)
end
local function ball(n,x,y,z,sx,sy,sz,c,solid)
 return part(n,Vector3.new(sx,sy,sz),Vector3.new(x,y,z),c,Enum.PartType.Ball,solid)
end
local function disc(n,x,y,z,r,h,c,solid)
 local p=part(n,Vector3.new(h,r*2,r*2),Vector3.new(x,y,z),c,Enum.PartType.Cylinder,solid)
 p.CFrame=CFrame.new(O+Vector3.new(x,y,z))*CFrame.Angles(0,0,math.pi/2) return p
end
local function rod(n,a,b,r,c,solid)
 local mid=(a+b)/2
 local p=part(n,Vector3.new((b-a).Magnitude,r*2,r*2),mid,c,Enum.PartType.Cylinder,solid)
 p.CFrame=CFrame.lookAt(O+mid,O+b)*CFrame.Angles(0,math.pi/2,0)
 return p
end
local function roundRect(n,x,y,z,sx,sy,sz,r,c,solid)
 box(n.." core",x,y,z,sx-2*r,sy,sz,c,solid)
 box(n.." cross",x,y,z,sx,sy,sz-2*r,c,solid)
 for _,a in {-1,1} do for _,b in {-1,1} do disc(n.." corner",x+a*(sx/2-r),y,z+b*(sz/2-r),r,sy,c,solid) end end
end
local function label(n,body,x,y,z,sx,sy,color,bg)
 local p=box(n,x,y,z,sx,sy,.35,bg or "white",false)
 local ui=Instance.new("SurfaceGui") ui.Name="Lettering" ui.Face=Enum.NormalId.Front ui.CanvasSize=Vector2.new(sx*32,sy*32) ui.LightInfluence=0.25 ui.Parent=p
 local t=Instance.new("TextLabel") t.Size=UDim2.fromScale(1,1) t.BackgroundTransparency=1 t.Text=body
 t.Font=Enum.Font.Arcade t.TextScaled=true t.TextColor3=C[color] t.Parent=ui
 return p
end
local function cloud(n,x,y,z,scale)
 ball(n.." base",x,y,z,scale*2.5,scale*.6,scale,"white")
 for i=-1,1 do ball(n.." puff",x+i*scale*.7,y+scale*.22,z,scale*(i==0 and 1.35 or 1),scale*(i==0 and 1 or .75),scale,"white") end
end
local function arch(n,x,z,base,r,c,t)
 local last=nil
 for i=0,18 do
  local a=math.pi*i/18
  local p=Vector3.new(x+math.cos(a)*r,base+math.sin(a)*r,z)
  if last then rod(n,last,p,t,c,false) end last=p
 end
end
-- Exact doubled footprint; fully solid main floor.
local floor=box("MAIN FLOOR - exact doubled footprint",0,-1.5,0,W,3,D,"floor",true)
root.PrimaryPart=floor
roundRect("Soft perimeter plinth",0,-2.8,0,W+1,1,D+1,10,"sky",true)
roundRect("Central cream promenade",0,.035,-4,86,.07,D-12,15,"cream")
roundRect("Central pastel carpet",0,.08,13,60,.08,110,16,"sky")
-- Empty furnishing bays: colour only, no replicated shop furniture.
for _,x in {-89,89} do
 for i,z in {-48,17} do
  roundRect("EMPTY furnishing bay",x,.04,z,64,.08,48,8,i==1 and "white" or "cream")
 end
end
for _,x in {-42,42} do for z=-78,67,17 do disc("Promenade confetti",x,.12,z,1.6,.09,((z+78)/17)%2==0 and "pink" or "yellow") end end
-- Fully closed shell, kept cream and bright rather than industrial.
g=groups["02"]
box("Left enclosed wall",-W/2+1.5,25,0,3,50,D,"cream",true)
box("Right enclosed wall",W/2-1.5,25,0,3,50,D,"cream",true)
box("Rear enclosed wall",0,25,D/2-1.5,W-6,50,3,"cream",true)
box("Front enclosed wall",0,25,-D/2+1.5,W-6,50,3,"cream",true)
local accents={"pink","lilac","sky","mint"}
for _,side in {-1,1} do
 local x=side*(W/2-4)
 for i,z in {-77,-26,26,77} do
  local c=accents[i]
  box("Pastel wall inset",x,22,z,1,31,41,c)
  -- Rounded outline of a playful tall wall arch; in the YZ plane.
  for _,zz in {z-17,z+17} do
   rod("Rounded arch upright",Vector3.new(x-side,4,zz),Vector3.new(x-side,27,zz),1.2,"white")
  end
  local last
  for j=0,16 do
   local a=math.pi*j/16
   local p=Vector3.new(x-side,27+math.sin(a)*14,z+math.cos(a)*17)
   if last then rod("Rounded arch crown",last,p,1.2,"white") end last=p
  end
  disc("Column foot",x-side*2,1.1,z-22,3.5,2.2,c,true)
  rod("Candy column",Vector3.new(x-side*2,2,z-22),Vector3.new(x-side*2,44,z-22),1.7,c,true)
  ball("Column bubble cap",x-side*2,44,z-22,5,5,5,"white")
 end
end
-- Cartoon rainbow on the rear wall. Wide empty side alcoves below.
for i,c in {"coral","yellow","mint","sky","lilac"} do arch("Rainbow band "..i,0,D/2-4.2,17,34-i*2,c,.85) end
cloud("Rear left cloud",-42,20,D/2-5,8)
cloud("Rear right cloud",42,20,D/2-5,8)
label("G-BLOX welcome sign","G-BLOX",0,41,D/2-7,58,9,"navy","cream")
label("Cloud club subtitle","CLOUD CLUB",0,32,D/2-7,35,3.5,"navy","cream")
-- Front pretend doors are decorative architecture, not a new teleport.
roundRect("Entry mat",0,.14,-83,37,.1,19,6,"lilac")
box("Entry panel",0,13,-D/2+3.5,33,26,1,"sky",true)
for _,x in {-16,16} do rod("Door surround",Vector3.new(x,1,-D/2+4.2),Vector3.new(x,26,-D/2+4.2),1.7,"yellow") end
arch("Rounded entrance",0,-D/2+4.2,26,16,"yellow",1.7)
box("Door seam",0,13,-D/2+4.2,.3,23,.2,"white")
for _,x in {-2,2} do ball("Door handle",x,12,-D/2+4.6,1.4,1.4,1.4,"navy") end
-- Closed blue ceiling and rounded candy beams. No open roof or skylight holes.
g=groups["03"]
box("CLOSED ROOF - hide this model to decorate",0,51,0,W,2,D,"blue",true)
for _,x in {-104,-52,0,52,104} do
 rod("Round ceiling ribbon",Vector3.new(x,48.5,-D/2+4),Vector3.new(x,48.5,D/2-4),1.2,"sky")
end
for i,z in {-70,-20,30,78} do
 rod("Pastel cross beam",Vector3.new(-W/2+4,47,z),Vector3.new(W/2-4,47,z),1.35,accents[i])
end
for i,p in {{-91,-53},{-41,42},{32,-42},{91,26},{70,72},{-106,57},{6,1}} do
 cloud("Ceiling cloud "..i,p[1],45.5,p[2],8+(i%3)*2)
end
-- Suspended chunky stars, made from two friendly rotated squares and a center bubble.
for i,p in {{-58,-62},{64,-64},{-84,7},{75,54},{-21,70},{32,21}} do
 local x,z=p[1],p[2]
 rod("Star string",Vector3.new(x,49,z),Vector3.new(x,39,z),.06,"white")
 local a=box("Hanging star",x,38,z,4,.8,4,"yellow")
 a.CFrame=CFrame.new(O+Vector3.new(x,38,z))*CFrame.Angles(math.pi/2,0,math.pi/4)
 local b=box("Hanging star",x,38,z,4,.8,4,"yellow")
 b.CFrame=CFrame.new(O+Vector3.new(x,38,z))*CFrame.Angles(math.pi/2,0,0)
 ball("Star center",x,38,z,3,3,1.2,"yellow")
end
-- Low cloud gallery: gently stepped, no tall industrial catwalk.
g=groups["04"]
roundRect("Cloud stage base",0,4,77,W-22,8,38,13,"lilac",true)
roundRect("Cloud stage rim",0,8.05,77,W-24,.35,36,12,"white",true)
roundRect("Cloud stage top",0,8.28,77,W-27,.12,33,11,"mint",true)
for _,x in {-95,95} do
 for i=1,8 do roundRect("Wide soft stair "..i,x,i*.5,35+i*2.6,21,i,2.8,.7,i%2==0 and "cream" or "pink",true) end
 for _,sx in {-12,12} do
  for i=1,8,2 do rod("Stair post",Vector3.new(x+sx,i,35+i*2.6),Vector3.new(x+sx,i+3.4,35+i*2.6),.4,"white",true) end
  rod("Bubble stair handrail",Vector3.new(x+sx,4.4,37.6),Vector3.new(x+sx,11.4,55.8),.65,"sky",true)
 end
end
for _,range in {{-128,-108},{-82,82},{108,128}} do
 local a,b=range[1],range[2]
 rod("Gallery candy rail",Vector3.new(a,12,58.5),Vector3.new(b,12,58.5),.75,"sky",true)
 for x=a,b,8 do
  rod("Gallery post",Vector3.new(x,8.4,58.5),Vector3.new(x,12,58.5),.35,"white",true)
  ball("Gallery bubble",x,12,58.5,1.8,1.8,1.8,"pink")
 end
end
-- Happy blocky Roblox-inspired mascot, not a gameplay NPC or copied asset.
g=groups["05"]
disc("Mascot bottom cushion",0,1.1,16,15,2.2,"pink",true)
disc("Mascot white cushion",0,2.4,16,13.6,.65,"white",true)
disc("Mascot mint cushion",0,3.2,16,12.7,.95,"mint",true)
local function limb(n,a,b,w,c)
 local mid=(a+b)/2
 local p=part(n,Vector3.new(w,w,(b-a).Magnitude),mid,c)
 p.CFrame=CFrame.lookAt(O+mid,O+b)
 ball(n.." rounded end",a.X,a.Y,a.Z,w,w,w,c)
 ball(n.." rounded end",b.X,b.Y,b.Z,w,w,w,c)
end
limb("Left trouser",Vector3.new(-2.4,11,16),Vector3.new(-4,5.9,15),3.5,"lilac")
roundRect("Left trainer",-4,4.75,13.8,4.2,2,6,1.1,"white")
limb("Raised trouser",Vector3.new(2.2,11,16),Vector3.new(5.5,8.7,14),3.5,"lilac")
limb("Raised shin",Vector3.new(5.5,8.7,14),Vector3.new(7,11,17),3.2,"lilac")
roundRect("Raised trainer",7,11,16,4,2,5.5,1,"white")
box("Mascot T-shirt",0,15,16,8.5,9,5.2,"sky")
ball("Left shoulder",-4,18,16,3.2,3.2,4,"sky")
ball("Right shoulder",4,18,16,3.2,3.2,4,"sky")
limb("Waving sleeve",Vector3.new(-5,17.5,16),Vector3.new(-8,20.5,16),3,"sky")
limb("Waving arm",Vector3.new(-8,20.5,16),Vector3.new(-8,24.5,16),2.8,"yellow")
ball("Waving hand",-8,25,16,3.5,3.5,3.5,"yellow")
limb("Right sleeve",Vector3.new(5,17,16),Vector3.new(8,14,15),3,"sky")
ball("Right hand",8,13.4,15,3.5,3.5,3.5,"yellow")
local head=disc("Happy yellow head",0,23,16,3.5,6,"yellow")
for _,x in {-1.25,1.25} do ball("Mascot eye",x,23.6,12.61,.62,.95,.2,"dark") end
-- Smile follows the front of the cylindrical face.
local prev
for i=0,12 do
 local a=math.pi+math.pi*i/12
 local p=Vector3.new(math.cos(a)*1.55,22.6+math.sin(a)*.8,12.54)
 if prev then rod("Happy smile",prev,p,.15,"dark") end prev=p
end
disc("Cap crown",0,26.3,16,3.7,1.6,"coral")
roundRect("Cap peak",0,26,13.3,6,.6,4,1,"coral")
label("Shirt G","G",0,15.5,13.25,4,4,"white","sky")
-- Thin pastel orbit around the statue.
local last
for i=0,48 do
 local a=math.pi*2*i/48 local p=Vector3.new(math.cos(a)*18,19+math.sin(a)*18,20)
 if last then rod("Gravity halo",last,p,.42,"yellow") end last=p
end
for i,p in {{-16,29,19},{16,10,19},{10,34,20}} do
 local q=box("Floating toy block "..i,p[1],p[2],p[3],3.2,3.2,3.2,accents[i])
 q.CFrame=q.CFrame*CFrame.Angles(.3,.4,.3)
end
label("Mascot plinth title","LET'S BOUNCE!",0,2,2.3,18,1.4,"navy","white")
-- Friendly practice path. No damage, no scripts, no rewards duplicated.
g=groups["06"]
local pads={{96,-76,1,11},{111,-68,1.8,10},{125,-56,2.7,10},{125,-40,3.6,9},{115,-26,4.5,10},{125,-11,5.4,10},{125,6,6.3,10},{120,23,7.2,11},{117,39,8,12}}
for i,p in pads do
 local x,z,h,r=p[1],p[2],p[3],p[4]/2 local c=accents[(i-1)%4+1]
 disc("Obby soft pedestal "..i,x,h/2,z,r*.66,h,c,true)
 disc("Obby white edge "..i,x,h-.25,z,r,.8,"white",true)
 disc("Obby landing "..i,x,h+.18,z,r-.45,.12,c,true)
 local top=box("Platform number "..i,x,h+.26,z,3,.06,3,c,false)
 local ui=Instance.new("SurfaceGui") ui.Face=Enum.NormalId.Top ui.CanvasSize=Vector2.new(128,128) ui.Parent=top
 local t=Instance.new("TextLabel") t.BackgroundTransparency=1 t.Size=UDim2.fromScale(1,1) t.Font=Enum.Font.Arcade t.Text=tostring(i) t.TextScaled=true t.TextColor3=C.navy t.Parent=ui
end
label("Practice sign","HOP! HOP!",113,6,-88,25,4,"navy","yellow")
for _,x in {99,127} do rod("Practice sign post",Vector3.new(x,0,-88),Vector3.new(x,8,-88),.5,"pink") end
-- Candy trees, benches, cloud motifs: new decorations only.
g=groups["07"]
for i,p in {{-125,-73},{-125,-22},{-125,30},{-63,84},{63,84},{129,74}} do
 local x,z=p[1],p[2] local base=z>60 and 8.4 or 0
 disc("Toy tree pot",x,base+1.6,z,3.8,3.2,"pink",true)
 disc("Pot lip",x,base+3.2,z,4.1,.7,"white")
 rod("Toy tree trunk",Vector3.new(x,base+3,z),Vector3.new(x,base+10,z),.8,"yellow",true)
 for j,q in {{-2.5,10,0},{2.5,11,0},{0,14,0}} do
  ball("Bubble tree crown",x+q[1],base+q[2],z,7,7,7,j==3 and "mint" or "green")
 end
end
for _,p in {{-122,-47,0},{-122,6,0},{-31,86,8.4},{31,86,8.4}} do
 local x,z,b=p[1],p[2],p[3]
 roundRect("Candy bench",x,b+2.9,z,15,1.4,5,2,"lilac",true)
 for _,dx in {-4.5,4.5} do disc("Bench leg",x+dx,b+1.2,z,1.1,2.4,"white",true) end
 rod("Bench backrest",Vector3.new(x-6,b+5,z+2),Vector3.new(x+6,b+5,z+2),1.1,"pink",true)
end
for _,x in {-78,78} do
 cloud("Rear wall fluffy cloud",x,29,D/2-4,9)
end
-- Native Roblox lighting, local to this model; existing Lighting service untouched.
g=groups["08"]
for _,x in {-105,-53,0,53,105} do for _,z in {-62,0,62} do
 local fixture=ball("Cloud lamp",x,44,z,4,1.8,4,"white")
 fixture.Material=Enum.Material.Neon
 local light=Instance.new("PointLight") light.Name="Soft indoor fill" light.Color=Color3.fromRGB(255,246,225) light.Brightness=1.8 light.Range=60 light.Shadows=false light.Parent=fixture
end end
for _,x in {-24,24} do
 local fixture=ball("Mascot lamp",x,24,0,1.4,1.4,1.4,"yellow")
 fixture.Material=Enum.Material.Neon
 local l=Instance.new("PointLight") l.Color=Color3.fromRGB(255,235,183) l.Range=35 l.Brightness=1.5 l.Shadows=false l.Parent=fixture
end
-- Publish only the new model into the edit data model. No scripts/spawns/teleports.
pcall(function() History:SetWaypoint("Before new G-Blox Cloud Club") end)
root.Parent=Workspace
root:PivotTo(root:GetPivot())
game:GetService("Selection"):Set({root})
Workspace.CurrentCamera.CFrame=CFrame.lookAt(O+Vector3.new(103,24,-85),O+Vector3.new(-8,20,27))
pcall(function() History:SetWaypoint("Built separate G-Blox Cloud Club") end)
local parts,lights=0,0
for _,o in root:GetDescendants() do if o:IsA("BasePart") then parts+=1 elseif o:IsA("Light") then lights+=1 end end
return game:GetService("HttpService"):JSONEncode({model=root.Name,parts=parts,lights=lights,origin={O.X,O.Y,O.Z},width=W,depth=D,originalLobbyPresent=Workspace:FindFirstChild("Lobby")~=nil})

