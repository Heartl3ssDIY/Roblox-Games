local sg=game:GetService("StarterGui")
assert(not sg:FindFirstChild("CurrencyHUD"),"CurrencyHUD already exists")
local function make(class,name,parent,props)
 local o=Instance.new(class);o.Name=name
 for k,v in props do o[k]=v end o.Parent=parent return o
end
local gui=make("ScreenGui","CurrencyHUD",sg,{ResetOnSpawn=false,IgnoreGuiInset=false,DisplayOrder=24,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
local holder=make("Frame","Counters",gui,{AnchorPoint=Vector2.new(0,1),Position=UDim2.new(0,20,1,-24),Size=UDim2.fromOffset(252,146),BackgroundTransparency=1})
make("UIScale","ResponsiveScale",holder,{Scale=1})
local function text(name,parent,value,pos,size,color,fontSize)
 return make("TextLabel",name,parent,{Text=value,Position=pos,Size=size,BackgroundTransparency=1,TextColor3=color,Font=Enum.Font.GothamBold,TextSize=fontSize,TextXAlignment=Enum.TextXAlignment.Left})
end
for i,name in {"Cash","Trophies"} do
 local accent=name=="Cash" and Color3.fromRGB(33,240,222) or Color3.fromRGB(255,212,83)
 local card=make("ImageLabel",name,holder,{Position=UDim2.fromOffset(0,(i-1)*78),Size=UDim2.fromOffset(252,68),BackgroundColor3=Color3.fromRGB(8,32,47),Image="rbxassetid://73899067954592",ImageTransparency=.62,ScaleType=Enum.ScaleType.Stretch})
 make("UICorner","Corners",card,{CornerRadius=UDim.new(0,16)})
 make("UIStroke","Border",card,{Color=accent,Thickness=1.5,Transparency=.18})
 local badge=make("Frame","Badge",card,{Position=UDim2.fromOffset(12,12),Size=UDim2.fromOffset(44,44),BackgroundColor3=Color3.fromRGB(8,31,44),BorderSizePixel=0})
 make("UICorner","Circle",badge,{CornerRadius=UDim.new(1,0)})
 if name=="Cash" then
 local t=text("Dollar",badge,"$",UDim2.new(),UDim2.fromScale(1,1),accent,30);t.TextXAlignment=Enum.TextXAlignment.Center
 else
 -- A vector-style trophy icon made of editable UI shapes.
 for _,x in {7,25} do
 local h=make("Frame","Handle",badge,{Position=UDim2.fromOffset(x,10),Size=UDim2.fromOffset(12,14),BackgroundTransparency=1})
 make("UICorner","Round",h,{CornerRadius=UDim.new(0,5)});make("UIStroke","Gold",h,{Color=accent,Thickness=3})
 end
 local cup=make("Frame","Cup",badge,{Position=UDim2.fromOffset(12,7),Size=UDim2.fromOffset(20,20),BackgroundColor3=accent,BorderSizePixel=0})
 make("UICorner","Round",cup,{CornerRadius=UDim.new(0,6)})
 make("Frame","Stem",badge,{Position=UDim2.fromOffset(20,25),Size=UDim2.fromOffset(4,8),BackgroundColor3=accent,BorderSizePixel=0})
 local base=make("Frame","Base",badge,{Position=UDim2.fromOffset(14,33),Size=UDim2.fromOffset(16,4),BackgroundColor3=accent,BorderSizePixel=0})
 make("UICorner","Round",base,{CornerRadius=UDim.new(0,2)})
 end
 text("Title",card,string.upper(name),UDim2.fromOffset(68,9),UDim2.fromOffset(170,18),accent,12)
 local amount=text("Amount",card,"—",UDim2.fromOffset(68,28),UDim2.fromOffset(170,30),Color3.new(1,1,1),26)
 amount.TextScaled=true;make("UITextSizeConstraint","ReadableSize",amount,{MinTextSize=14,MaxTextSize=26})
end
return "Created Cash and Trophies HUD at bottom-left."
