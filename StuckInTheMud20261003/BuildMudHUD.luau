local StarterGui=game:GetService("StarterGui")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ink=Color3.fromRGB(24,35,62)
local paper=Color3.fromRGB(255,250,226)
local soil=Color3.fromRGB(161,108,62)
local orange=Color3.fromRGB(255,150,58)
local blue=Color3.fromRGB(42,160,255)
local headline=Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local body=Font.new("rbxasset://fonts/families/FredokaOne.json")
local function make(class,name,parent,props)
 local o=Instance.new(class) o.Name=name for key,value in pairs(props or {}) do o[key]=value end o.Parent=parent return o
end
local function finish(o,color,radius,thickness)
 o.BackgroundColor3=color o.BorderSizePixel=0
 make("UICorner","Corner",o,{CornerRadius=UDim.new(0,radius or 12)})
 make("UIStroke","Outline",o,{Color=ink,Thickness=thickness or 3,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
end
local function text(parent,name,value,position,size,font,maximum)
 local o=make("TextLabel",name,parent,{Position=position,Size=size,Text=value,FontFace=font or body,TextColor3=ink,BackgroundTransparency=1,TextScaled=true,TextWrapped=true,ZIndex=5})
 make("UITextSizeConstraint","TextLimit",o,{MinTextSize=9,MaxTextSize=maximum or 20}) return o
end
local function button(parent,name,value,position,size,color,maximum)
 local o=make("TextButton",name,parent,{Position=position,Size=size,Text=value,FontFace=headline,TextColor3=ink,TextScaled=true,TextWrapped=true,AutoButtonColor=true,ZIndex=5})
 finish(o,color)
 make("UITextSizeConstraint","TextLimit",o,{MinTextSize=10,MaxTextSize=maximum or 20}) return o
end
local function meter(parent,name,position,size,color)
 local track=make("Frame",name,parent,{Position=position,Size=size,BackgroundColor3=Color3.fromRGB(203,212,209),BorderSizePixel=0,ZIndex=5})
 make("UICorner","Corner",track,{CornerRadius=UDim.new(1,0)})
 local fill=make("Frame","Fill",track,{Size=UDim2.fromScale(1,1),BackgroundColor3=color,BorderSizePixel=0,ZIndex=6})
 make("UICorner","Corner",fill,{CornerRadius=UDim.new(1,0)})
 make("UIGradient","Progress",fill,{Transparency=NumberSequence.new(0)})
 return track
end
local assets=ReplicatedStorage:FindFirstChild("MudAssets")
if not assets then assets=make("Folder","MudAssets",ReplicatedStorage) end
if not assets:FindFirstChild("MuddyTemplate") then
 local marker=make("BillboardGui","MuddyTemplate",assets,{Size=UDim2.fromOffset(170,42),StudsOffset=Vector3.new(0,3.8,0),AlwaysOnTop=false,MaxDistance=160,Enabled=false})
 local card=make("Frame","Card",marker,{Size=UDim2.fromScale(1,1)})
 finish(card,paper,12,3)
 local title=text(card,"Title","STUCK!",UDim2.fromOffset(7,4),UDim2.new(1,-14,1,-8),headline,30)
 title.TextColor3=soil
end
if StarterGui:FindFirstChild("MudHUD") then return {preserved=true,muddyTemplate=true} end
local gui=make("ScreenGui","MudHUD",StarterGui,{Enabled=true,ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=17,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
gui:SetAttribute("LayoutVersion",1)
local main=make("Frame","Main",gui,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,Visible=true})
local top=make("Frame","Top",main,{AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,68),Size=UDim2.new(0.44,0,0,74),ZIndex=4})
finish(top,paper,14,4)
make("UISizeConstraint","SizeLimit",top,{MinSize=Vector2.new(290,74),MaxSize=Vector2.new(600,74)})
text(top,"Title","STUCK IN THE MUD",UDim2.fromScale(0.04,0.03),UDim2.fromScale(0.92,0.25),headline,24)
button(top,"Team","BLUE\n2 / 2 FREE",UDim2.fromScale(0.025,0.37),UDim2.fromScale(0.30,0.48),blue,15).TextColor3=Color3.new(1,1,1)
text(top,"Timer","5:00",UDim2.fromScale(0.35,0.28),UDim2.fromScale(0.30,0.53),headline,39)
text(top,"Other","TEAMS LEFT: 2",UDim2.fromScale(0.68,0.39),UDim2.fromScale(0.29,0.42),body,15)
local controls=make("Frame","Controls",main,{AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,1,-18),Size=UDim2.fromOffset(280,146),BackgroundTransparency=1,BorderSizePixel=0})
local charge=make("Frame","Meter",controls,{Size=UDim2.new(1,0,0,36),ZIndex=4})
finish(charge,paper,12)
text(charge,"Charge","SPRINT 10.0s / 10s",UDim2.fromOffset(10,3),UDim2.new(1,-20,0,19),body,17)
meter(charge,"Track",UDim2.fromOffset(10,26),UDim2.new(1,-20,0,6),blue)
button(controls,"Mud","MUD\n[1]",UDim2.fromOffset(0,44),UDim2.fromOffset(93,48),soil,19)
button(controls,"Heat","HEAT\n[2]",UDim2.fromOffset(100,44),UDim2.fromOffset(93,48),orange,19)
button(controls,"Fire","SPLAT!",UDim2.fromOffset(200,44),UDim2.fromOffset(80,48),Color3.fromRGB(255,205,77),18)
button(controls,"Sprint","SPRINT · HOLD SHIFT",UDim2.fromOffset(0,98),UDim2.fromOffset(280,48),blue,20)
local frozen=make("Frame","Frozen",main,{AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,1,-18),Size=UDim2.fromOffset(280,96),Visible=false,ZIndex=4})
finish(frozen,paper,15,4)
text(frozen,"Title","STUCK IN THE MUD!",UDim2.fromOffset(8,6),UDim2.new(1,-16,0,28),headline,25)
text(frozen,"Status","TEAMMATE HEAT: 0.0 / 5s",UDim2.fromOffset(10,39),UDim2.new(1,-20,0,22),body,17)
meter(frozen,"RescueTrack",UDim2.fromOffset(12,73),UDim2.new(1,-24,0,10),orange)
local countdown=text(main,"Countdown","3",UDim2.new(0.5,-110,0.5,-60),UDim2.fromOffset(220,120),headline,98)
countdown.Visible=false countdown.TextColor3=paper
make("UIStroke","Outline",countdown,{Thickness=5,Color=ink,ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual})
local aim=make("Frame","Crosshair",main,{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(14,14),BackgroundTransparency=1,BorderSizePixel=0})
make("Frame","Horizontal",aim,{Position=UDim2.fromOffset(0,6),Size=UDim2.fromOffset(14,2),BackgroundColor3=paper,BorderSizePixel=0})
make("Frame","Vertical",aim,{Position=UDim2.fromOffset(6,0),Size=UDim2.fromOffset(2,14),BackgroundColor3=paper,BorderSizePixel=0})
local results=make("Frame","Results",main,{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.52),Size=UDim2.new(0.65,0,0,190),Visible=false,ZIndex=10})
finish(results,paper,18,4)
make("UISizeConstraint","SizeLimit",results,{MinSize=Vector2.new(280,190),MaxSize=Vector2.new(630,190)})
text(results,"Title","YOUR TEAM WINS!",UDim2.fromScale(0.04,0.07),UDim2.fromScale(0.92,0.27),headline,35)
text(results,"Reason","EVERY OPPONENT IS STUCK",UDim2.fromScale(0.05,0.38),UDim2.fromScale(0.90,0.16),body,18)
text(results,"Rewards","+150 COINS · +50 XP",UDim2.fromScale(0.05,0.63),UDim2.fromScale(0.90,0.24),headline,26)
button(gui,"ColourToggle","TEAM",UDim2.new(0,300,1,-62),UDim2.fromOffset(44,44),paper,13)
local palette=make("Frame","ColourPicker",gui,{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.52),Size=UDim2.fromOffset(280,138),Visible=false,Active=true,ZIndex=20})
finish(palette,paper,15,4)
text(palette,"Title","TEAM COLOUR",UDim2.fromOffset(10,9),UDim2.fromOffset(209,24),headline,25).ZIndex=21
button(palette,"Close","X",UDim2.fromOffset(231,6),UDim2.fromOffset(40,40),Color3.new(1,1,1),22).ZIndex=22
local paletteColors={{"Red",Color3.fromRGB(255,81,92)},{"Blue",blue},{"Green",Color3.fromRGB(90,185,111)},{"Black",Color3.fromRGB(43,48,57)}}
for index,item in ipairs(paletteColors) do
 local b=button(palette,item[1],item[1]:upper(),UDim2.fromOffset(10+(index-1)*66,49),UDim2.fromOffset(60,48),item[2],14)
 b.TextColor3=Color3.new(1,1,1) b.ZIndex=22
end
text(palette,"Message","Pick a colour for your next team.",UDim2.fromOffset(10,108),UDim2.fromOffset(260,21),body,13).ZIndex=21
return {gui=gui:GetFullName(),editable=true}
