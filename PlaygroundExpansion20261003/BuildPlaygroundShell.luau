local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local existing = StarterGui:FindFirstChild("PlaygroundShell")
local catalog = require(assert(ReplicatedStorage:FindFirstChild("PlaygroundCatalog"),"Install PlaygroundCatalog before the shell"))
local ink = Color3.fromRGB(27,45,61)
local cream = Color3.fromRGB(255,247,219)
local white = Color3.fromRGB(255,255,248)
local blue = Color3.fromRGB(89,193,244)
local gold = Color3.fromRGB(255,211,78)
local mint = Color3.fromRGB(130,225,180)
local pink = Color3.fromRGB(255,153,166)
local headline = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local body = Font.new("rbxasset://fonts/families/FredokaOne.json")
local function make(className,name,parent,properties)
 local object = Instance.new(className)
 object.Name = name
 for key,value in pairs(properties or {}) do object[key]=value end
 object.Parent = parent
 return object
end
local function corner(parent,radius)
 return make("UICorner","Corner",parent,{CornerRadius=UDim.new(0,radius)})
end
local function stroke(parent,thickness,color)
 return make("UIStroke","Outline",parent,{Color=color or ink,Thickness=thickness or 3,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,LineJoinMode=Enum.LineJoinMode.Round})
end
local function text(parent,name,value,position,size,font,maxSize,color,z)
 local object = make("TextLabel",name,parent,{BackgroundTransparency=1,BorderSizePixel=0,Position=position,Size=size,Text=value,TextColor3=color or ink,FontFace=font or body,TextScaled=true,TextWrapped=true,ZIndex=z or 4})
 make("UITextSizeConstraint","TextSizeLimit",object,{MinTextSize=9,MaxTextSize=maxSize or 22})
 return object
end
local function button(parent,name,value,position,size,color,maxSize,z)
 local object = make("TextButton",name,parent,{Position=position,Size=size,BackgroundColor3=color or gold,BorderSizePixel=0,Text=value,TextColor3=ink,FontFace=headline,TextScaled=true,TextWrapped=true,AutoButtonColor=true,ZIndex=z or 4})
 make("UITextSizeConstraint","TextSizeLimit",object,{MinTextSize=9,MaxTextSize=maxSize or 24})
 make("UIPadding","TextPadding",object,{PaddingLeft=UDim.new(0,5),PaddingRight=UDim.new(0,5),PaddingTop=UDim.new(0,3),PaddingBottom=UDim.new(0,3)})
 corner(object,11)
 stroke(object,3)
 return object
end
local assets = ReplicatedStorage:FindFirstChild("PlaygroundCosmeticAssets") or make("Folder","PlaygroundCosmeticAssets",ReplicatedStorage)
local assetCount = 0
local function modelPart(model,name,size,position,color,shape,transparency)
 local object = make("Part",name,model,{Size=size,Position=position,Color=color,Material=Enum.Material.SmoothPlastic,Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,CastShadow=false,Transparency=transparency or 0,TopSurface=Enum.SurfaceType.Smooth,BottomSurface=Enum.SurfaceType.Smooth})
 if shape then object.Shape=shape end
 if not model.PrimaryPart then model.PrimaryPart=object end
 return object
end
local function ball(model,name,size,position,color,transparency)
 return modelPart(model,name,size,position,color,Enum.PartType.Ball,transparency)
end
local function rod(model,name,a,b,width,color)
 local p = modelPart(model,name,Vector3.new(width,width,(b-a).Magnitude),(a+b)/2,color)
 p.CFrame=CFrame.lookAt(p.Position,b)
 return p
end
local function triangle(model,a,b,c,color,thickness)
 local ab,ac,bc=b-a,c-a,c-b
 if ab.Magnitude>ac.Magnitude and ab.Magnitude>bc.Magnitude then c,a=a,c
 elseif ac.Magnitude>bc.Magnitude then a,b=b,a end
 ab,ac,bc=b-a,c-a,c-b
 local right=ac:Cross(ab).Unit
 local back=bc.Unit
 local up=bc:Cross(right).Unit
 local height=math.abs(ab:Dot(up))
 local p=make("WedgePart","StarFacet",model,{Size=Vector3.new(thickness,height,math.abs(ab:Dot(back))),CFrame=CFrame.fromMatrix((a+b)/2,right,up,back),Color=color,Material=Enum.Material.SmoothPlastic,Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,CastShadow=false})
 local q=p:Clone()
 q.Size=Vector3.new(thickness,height,math.abs(ac:Dot(back)))
 q.CFrame=CFrame.fromMatrix((a+c)/2,-right,up,-back)
 q.Parent=model
 if not model.PrimaryPart then model.PrimaryPart=p end
end
local function star(model,origin,scale,color,thickness)
 local points={}
 for index=1,10 do
  local angle=math.pi/2+(index-1)*math.pi/5
  local radius=index%2==1 and 2*scale or 0.88*scale
  points[index]=origin+Vector3.new(math.cos(angle)*radius,math.sin(angle)*radius,0)
 end
 for index=1,10 do triangle(model,origin,points[index],points[index%10+1],color,thickness or 0.32) end
end
local function avatar(model,pose,outlineColor,rainbow)
 local skin=Color3.fromRGB(255,213,145)
 local shirt=Color3.fromRGB(88,179,232)
 local torso=modelPart(model,"Torso",Vector3.new(1.7,1.8,0.85),Vector3.new(0,0,0),shirt)
 local head=ball(model,"Head",Vector3.new(1.5,1.5,1.5),Vector3.new(0,1.63,0),skin)
 modelPart(model,"LeftLeg",Vector3.new(0.68,1.4,0.8),Vector3.new(-0.44,-1.6,0),ink)
 modelPart(model,"RightLeg",Vector3.new(0.68,1.4,0.8),Vector3.new(0.44,-1.6,0),ink)
 local leftA,leftB=Vector3.new(-1.03,0.58,0),Vector3.new(-1.25,-0.83,0)
 local rightA,rightB=Vector3.new(1.03,0.58,0),Vector3.new(1.25,-0.83,0)
 if pose=="Wave" or pose=="Cheer" then rightB=Vector3.new(1.62,2.25,0) end
 if pose=="Cheer" then leftB=Vector3.new(-1.62,2.25,0) end
 rod(model,"LeftArm",leftA,leftB,0.58,skin)
 rod(model,"RightArm",rightA,rightB,0.58,skin)
 ball(model,"LeftEye",Vector3.new(0.15,0.18,0.10),Vector3.new(-0.27,1.73,0.71),ink)
 ball(model,"RightEye",Vector3.new(0.15,0.18,0.10),Vector3.new(0.27,1.73,0.71),ink)
 modelPart(model,"Smile",Vector3.new(0.30,0.08,0.10),Vector3.new(0,1.40,0.75),ink)
 if outlineColor then
  for index,p in ipairs({torso,head,model.LeftLeg,model.RightLeg,model.LeftArm,model.RightArm}) do
   local shell=p:Clone()
   shell.Name=p.Name.."Outline"
   shell.Size=p.Size+Vector3.new(0.24,0.24,0.24)
   shell.Color=rainbow and ({gold,mint,pink,Color3.fromRGB(185,153,242),blue,Color3.fromRGB(255,156,76)})[index] or outlineColor
   shell.CFrame=p.CFrame-Vector3.new(0,0,0.16)
   shell.Parent=model
  end
 end
end
local function createAsset(item)
 local old=assets:FindFirstChild(item.id)
 if old then return old end
 local model=make("Model",item.id,assets)
 model:SetAttribute("CatalogId",item.id)
 model:SetAttribute("Category",item.category)
 if item.preview=="Bee" then
  ball(model,"Body",Vector3.new(2.7,2.1,2.0),Vector3.zero,item.color)
  for _,side in ipairs({-1,1}) do
   local band=modelPart(model,"BeeStripe",Vector3.new(0.18,2.13,2.03),Vector3.new(side*0.60,0,0),ink,Enum.PartType.Cylinder)
   band.CFrame=CFrame.new(band.Position)
   local wing=ball(model,"Wing",Vector3.new(1.55,0.24,1.8),Vector3.new(side*1.05,1.00,-0.45),white,0.12)
   wing.CFrame=wing.CFrame*CFrame.Angles(0,0,side*0.25)
   ball(model,"Eye",Vector3.new(0.20,0.25,0.13),Vector3.new(side*0.45,0.30,0.97),ink)
   rod(model,"Antenna",Vector3.new(side*0.50,0.90,0.35),Vector3.new(side*0.72,1.70,0.35),0.11,ink)
   ball(model,"AntennaTip",Vector3.new(0.25,0.25,0.25),Vector3.new(side*0.72,1.70,0.35),gold)
  end
  modelPart(model,"Smile",Vector3.new(0.35,0.10,0.10),Vector3.new(0,-0.03,1.02),ink)
 elseif item.preview=="Cloud" then
  for index,q in ipairs({Vector3.zero,Vector3.new(-0.8,0.22,0),Vector3.new(0.8,0.22,0),Vector3.new(0,0.65,-0.12)}) do
   ball(model,"CloudPuff"..index,Vector3.new(1.8,1.7,1.65),q,index%2==0 and white or item.color)
  end
  for _,side in ipairs({-1,1}) do
   ball(model,"Ear",Vector3.new(0.68,1.30,0.65),Vector3.new(side*1.15,1.00,0.2),Color3.fromRGB(124,191,232))
   ball(model,"Eye",Vector3.new(0.18,0.22,0.12),Vector3.new(side*0.47,0.47,0.87),ink)
   ball(model,"Paw",Vector3.new(0.62,0.53,0.63),Vector3.new(side*0.78,-0.79,0.45),white)
  end
  ball(model,"Muzzle",Vector3.new(0.98,0.64,0.52),Vector3.new(0,0.1,0.85),white)
  ball(model,"Nose",Vector3.new(0.23,0.18,0.16),Vector3.new(0,0.28,1.12),ink)
 elseif item.preview=="Wave" or item.preview=="Cheer" then
  avatar(model,item.preview)
 elseif item.preview=="Star" then
  star(model,Vector3.new(0,0,-0.13),1.05,ink,0.38)
  star(model,Vector3.new(0,0,0.12),0.94,item.color,0.33)
  ball(model,"Shine",Vector3.new(0.23,0.23,0.10),Vector3.new(-0.45,0.70,0.32),white)
 elseif item.preview=="Heart" then
  triangle(model,Vector3.new(-1.45,0.30,0),Vector3.new(1.45,0.30,0),Vector3.new(0,-1.50,0),item.color,0.7)
  for _,side in ipairs({-1,1}) do ball(model,"HeartLobe",Vector3.new(1.65,1.55,0.90),Vector3.new(side*0.69,0.57,0),item.color) end
  ball(model,"HeartShine",Vector3.new(0.18,0.45,0.09),Vector3.new(-0.91,0.85,0.44),white)
 elseif item.preview=="Ribbon" or item.preview=="Rainbow" then
  local colors={Color3.fromRGB(255,106,138),Color3.fromRGB(255,170,68),gold,mint,blue,Color3.fromRGB(143,131,245)}
  for index=1,12 do
   local t0,t1=(index-1)/12,index/12
   local a=Vector3.new(-2.15+t0*4.3,math.sin(t0*math.pi*2)*0.65,-0.45+t0*0.9)
   local b=Vector3.new(-2.15+t1*4.3,math.sin(t1*math.pi*2)*0.65,-0.45+t1*0.9)
   local color=item.preview=="Rainbow" and colors[math.floor(t0*#colors)+1] or item.color:Lerp(pink,t0)
   rod(model,"RibbonSegment",a,b,0.40,color)
  end
  ball(model,"RibbonSpark",Vector3.new(0.5,0.5,0.5),Vector3.new(2.15,0,0.45),white)
 elseif item.preview=="Outline" then
  avatar(model,"Idle",item.color,item.id=="RainbowOutline")
 elseif item.preview=="Potion" then
  local bottle=modelPart(model,"Bottle",Vector3.new(2.0,1.55,1.55),Vector3.new(0,-0.05,0),item.color,Enum.PartType.Cylinder,0.32)
  bottle.CFrame=bottle.CFrame*CFrame.Angles(0,0,math.pi/2)
  local liquid=modelPart(model,"SnowLiquid",Vector3.new(1.35,1.33,1.33),Vector3.new(0,-0.28,0),blue,Enum.PartType.Cylinder)
  liquid.CFrame=liquid.CFrame*CFrame.Angles(0,0,math.pi/2)
  local neck=modelPart(model,"BottleNeck",Vector3.new(0.55,0.64,0.64),Vector3.new(0,1.15,0),item.color,Enum.PartType.Cylinder,0.22)
  neck.CFrame=neck.CFrame*CFrame.Angles(0,0,math.pi/2)
  local cork=modelPart(model,"Cork",Vector3.new(0.27,0.74,0.74),Vector3.new(0,1.53,0),ink,Enum.PartType.Cylinder)
  cork.CFrame=cork.CFrame*CFrame.Angles(0,0,math.pi/2)
  for index=1,3 do
   local angle=index*math.pi/3
   rod(model,"Snowflake",Vector3.new(-math.cos(angle)*0.40,-math.sin(angle)*0.40,0.82),Vector3.new(math.cos(angle)*0.40,math.sin(angle)*0.40,0.82),0.07,white)
  end
 elseif item.preview=="Wand" then
  rod(model,"WandHandle",Vector3.new(-0.95,-1.80,0),Vector3.new(0.67,1.05,0),0.23,ink)
  rod(model,"WandGrip",Vector3.new(-0.90,-1.72,0.01),Vector3.new(-0.53,-1.06,0.01),0.30,pink)
  star(model,Vector3.new(0.79,1.26,0),0.57,item.color,0.28)
 end
 assetCount+=1
 return model
end
for _,item in ipairs(catalog.Items) do createAsset(item) end
if existing then return {built=false,reason="Existing editable PlaygroundShell preserved",createdAssets=assetCount} end

local gui=make("ScreenGui","PlaygroundShell",StarterGui,{Enabled=true,ResetOnSpawn=false,IgnoreGuiInset=false,DisplayOrder=25,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
gui:SetAttribute("LayoutVersion",1)
local wallet=make("Frame","Wallet",gui,{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-18,0,14),Size=UDim2.new(0.24,0,0,64),BackgroundColor3=cream,BorderSizePixel=0,ZIndex=3})
make("UISizeConstraint","SizeLimit",wallet,{MinSize=Vector2.new(158,58),MaxSize=Vector2.new(248,64)})
corner(wallet,16) stroke(wallet,4)
local coin=make("Frame","Coin",wallet,{Position=UDim2.fromOffset(12,12),Size=UDim2.fromOffset(37,37),BackgroundColor3=gold,BorderSizePixel=0,ZIndex=4})
corner(coin,100) stroke(coin,3)
text(coin,"Symbol","★",UDim2.fromScale(0.08,0.04),UDim2.fromScale(0.84,0.84),body,25,ink,5)
text(wallet,"Coins","...",UDim2.fromOffset(58,8),UDim2.new(1,-68,0,29),headline,27).TextXAlignment=Enum.TextXAlignment.Left
text(wallet,"Wins","0 wins",UDim2.fromOffset(59,37),UDim2.new(1,-69,0,17),body,14).TextXAlignment=Enum.TextXAlignment.Left
local dock=make("Frame","Dock",gui,{AnchorPoint=Vector2.new(0,1),Position=UDim2.new(0,18,1,-18),Size=UDim2.fromOffset(268,48),BackgroundTransparency=1,ZIndex=3})
button(dock,"Shop","SHOP",UDim2.fromOffset(0,0),UDim2.fromOffset(118,46),gold,27)
button(dock,"Emote","HI!",UDim2.fromOffset(132,0),UDim2.fromOffset(56,46),blue,20)
button(dock,"Emoji","♥",UDim2.fromOffset(202,0),UDim2.fromOffset(56,46),pink,27)
local toast=make("Frame","RewardToast",gui,{AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,84),Size=UDim2.new(0.38,0,0,50),BackgroundColor3=gold,BorderSizePixel=0,Visible=false,ZIndex=12})
make("UISizeConstraint","SizeLimit",toast,{MinSize=Vector2.new(240,50),MaxSize=Vector2.new(420,50)})
corner(toast,14) stroke(toast,4)
text(toast,"Message","+15 COINS",UDim2.fromScale(0.03,0.1),UDim2.fromScale(0.94,0.8),headline,25,ink,13)
local backdrop=make("TextButton","Backdrop",gui,{Size=UDim2.fromScale(1,1),BackgroundColor3=ink,BackgroundTransparency=0.38,Text="",AutoButtonColor=false,BorderSizePixel=0,Visible=false,ZIndex=20})
local shop=make("Frame","ShopPanel",gui,{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromScale(0.92,0.86),BackgroundColor3=cream,BorderSizePixel=0,Visible=false,ZIndex=21})
make("UISizeConstraint","SizeLimit",shop,{MinSize=Vector2.new(310,300),MaxSize=Vector2.new(1120,750)})
corner(shop,21) stroke(shop,5)
text(shop,"Title","GOODIES",UDim2.fromOffset(20,9),UDim2.new(1,-190,0,39),headline,31,ink,22).TextXAlignment=Enum.TextXAlignment.Left
text(shop,"Coins","... coins",UDim2.new(1,-162,0,17),UDim2.fromOffset(101,25),body,18,ink,22)
button(shop,"Close","X",UDim2.new(1,-51,0,12),UDim2.fromOffset(36,36),white,23,22)
local categories=make("ScrollingFrame","Categories",shop,{Position=UDim2.fromOffset(16,58),Size=UDim2.new(1,-32,0,42),BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.fromScale(0,0),AutomaticCanvasSize=Enum.AutomaticSize.X,ScrollingDirection=Enum.ScrollingDirection.X,ScrollBarThickness=3,ScrollBarImageColor3=ink,ZIndex=22})
make("UIListLayout","CategoryLayout",categories,{FillDirection=Enum.FillDirection.Horizontal,HorizontalAlignment=Enum.HorizontalAlignment.Left,VerticalAlignment=Enum.VerticalAlignment.Center,Padding=UDim.new(0,9),SortOrder=Enum.SortOrder.LayoutOrder})
for index,category in ipairs(catalog.Categories) do
 local b=button(categories,category,string.upper(category),UDim2.fromOffset(0,0),UDim2.fromOffset(category=="Highlights" and 123 or category=="All" and 64 or 95,33),category=="All" and gold or white,18,23)
 b.LayoutOrder=index
end
local cards=make("ScrollingFrame","Cards",shop,{Position=UDim2.fromOffset(14,113),Size=UDim2.new(1,-28,1,-169),BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.fromScale(0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y,ScrollBarThickness=5,ScrollBarImageColor3=ink,ZIndex=22})
make("UIPadding","CardPadding",cards,{PaddingTop=UDim.new(0,5),PaddingBottom=UDim.new(0,8),PaddingLeft=UDim.new(0,5),PaddingRight=UDim.new(0,5)})
make("UIGridLayout","CardLayout",cards,{CellSize=UDim2.fromOffset(242,238),CellPadding=UDim2.fromOffset(12,12),FillDirectionMaxCells=4,HorizontalAlignment=Enum.HorizontalAlignment.Center,SortOrder=Enum.SortOrder.LayoutOrder})
text(shop,"Status","Pick a little something for your next round.",UDim2.new(0,20,1,-42),UDim2.new(1,-40,0,31),body,17,ink,22)
local templates=make("Folder","Templates",gui)
local template=make("Frame","ItemCard",templates,{Size=UDim2.fromOffset(242,238),BackgroundColor3=white,BorderSizePixel=0,Visible=false,ZIndex=23})
corner(template,15) stroke(template,3)
text(template,"Name","ITEM",UDim2.fromOffset(12,8),UDim2.fromOffset(218,28),headline,22,ink,24)
local viewport=make("ViewportFrame","Preview",template,{Position=UDim2.fromOffset(12,43),Size=UDim2.fromOffset(218,122),BackgroundColor3=Color3.fromRGB(210,239,232),BorderSizePixel=0,Ambient=Color3.fromRGB(195,199,205),LightColor=Color3.fromRGB(255,255,255),LightDirection=Vector3.new(-0.4,-1,-0.5),ZIndex=24})
corner(viewport,11)
local world=make("WorldModel","World",viewport)
local camera=make("Camera","Camera",viewport,{FieldOfView=37,CFrame=CFrame.lookAt(Vector3.new(5,3.0,7),Vector3.new(0,0.05,0))})
viewport.CurrentCamera=camera
local pedestal=make("Part","PreviewPedestal",world,{Size=Vector3.new(0.22,4.8,4.8),CFrame=CFrame.new(0,-2.38,0)*CFrame.Angles(0,0,math.pi/2),Color=cream,Material=Enum.Material.SmoothPlastic,Shape=Enum.PartType.Cylinder,Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,CastShadow=false})
text(template,"Price","45 coins",UDim2.fromOffset(12,174),UDim2.fromOffset(105,19),body,15,ink,24).TextXAlignment=Enum.TextXAlignment.Left
text(template,"Category","PETS",UDim2.fromOffset(127,175),UDim2.fromOffset(103,17),body,12,Color3.fromRGB(85,111,112),24).TextXAlignment=Enum.TextXAlignment.Right
button(template,"Action","BUY",UDim2.fromOffset(12,202),UDim2.fromOffset(158,27),gold,18,24)
button(template,"Try","USE",UDim2.fromOffset(179,202),UDim2.fromOffset(51,27),blue,14,24).Visible=false
for index,item in ipairs(catalog.Items) do
 local card=template:Clone()
 card.Name=string.format("Slot%02d",index)
 card.LayoutOrder=index
 card.Visible=true
 card:SetAttribute("CatalogId",item.id)
 card:SetAttribute("Category",item.category)
 card:FindFirstChild("Name").Text=item.name
 card.Price.Text=tostring(item.price).." coins"
 card.Category.Text=string.upper(item.category)
 card.Preview.BackgroundColor3=item.color:Lerp(white,0.67)
 local preview=createAsset(item):Clone()
 preview.Name="ItemModel"
 preview.Parent=card.Preview.World
 card.Preview.CurrentCamera=card.Preview.Camera
 if item.available==false then card.Action.Text="COMING SOON" card.Action.BackgroundColor3=Color3.fromRGB(221,227,218) end
 card.Parent=cards
end
local vote=make("Frame","VotePanel",gui,{AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,1,-82),Size=UDim2.new(0.62,0,0.29,0),BackgroundColor3=cream,BorderSizePixel=0,Visible=false,ZIndex=8})
make("UISizeConstraint","SizeLimit",vote,{MinSize=Vector2.new(280,176),MaxSize=Vector2.new(660,222)})
corner(vote,18) stroke(vote,4)
text(vote,"Title","PICK THE NEXT ROUND",UDim2.fromScale(0.04,0.04),UDim2.fromScale(0.72,0.18),headline,24,ink,9).TextXAlignment=Enum.TextXAlignment.Left
text(vote,"Timer","12s",UDim2.fromScale(0.80,0.06),UDim2.fromScale(0.16,0.14),headline,23,ink,9)
local bb=button(vote,"BritishBulldog","BRITISH\nBULLDOG",UDim2.fromScale(0.04,0.28),UDim2.fromScale(0.44,0.45),blue,24,9)
local tag=button(vote,"TagYoureIt","TAG\nYOU'RE IT",UDim2.fromScale(0.52,0.28),UDim2.fromScale(0.44,0.45),pink,24,9)
text(vote,"VotesBritishBulldog","0 votes",UDim2.fromScale(0.04,0.77),UDim2.fromScale(0.44,0.13),body,16,ink,9)
text(vote,"VotesTagYoureIt","0 votes",UDim2.fromScale(0.52,0.77),UDim2.fromScale(0.44,0.13),body,16,ink,9)
text(vote,"Message","Step onto a card to vote, or tap it here.",UDim2.fromScale(0.03,0.91),UDim2.fromScale(0.94,0.065),body,12,ink,9)
return {built=true,gui=gui:GetFullName(),slots=#catalog.Items,viewportFrames=#catalog.Items,createdAssets=assetCount,authoredTemplate=template:GetFullName()}
