local SG=game:GetService("StarterGui")
assert(not SG:FindFirstChild("GBloxPlaytimeRewards"),"Playtime UI already exists; inspect before rebuilding")
local function make(class,name,parent,props)
 local v=Instance.new(class) v.Name=name
 for k,value in props or {} do v[k]=value end
 v.Parent=parent return v
end
local gui=make("ScreenGui","GBloxPlaytimeRewards",SG,{ResetOnSpawn=false,IgnoreGuiInset=false,DisplayOrder=52,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
local clock=make("ImageButton","Clock",gui,{BackgroundTransparency=1,Image="rbxassetid://111112888067419",Size=UDim2.fromOffset(52,52),Position=UDim2.new(0,144,1,-12),AnchorPoint=Vector2.new(0,1),AutoButtonColor=false})
local badge=make("TextLabel","Available",clock,{Size=UDim2.fromOffset(19,19),Position=UDim2.new(1,0,0,0),AnchorPoint=Vector2.new(.7,.1),BackgroundColor3=Color3.fromRGB(0,229,224),Text="!",TextColor3=Color3.fromRGB(0,23,47),Font=Enum.Font.Arcade,TextSize=15,Visible=false})
make("UICorner","Round",badge,{CornerRadius=UDim.new(1,0)})
make("TextLabel","Tooltip",clock,{BackgroundTransparency=1,Size=UDim2.fromOffset(130,18),Position=UDim2.new(.5,0,0,-20),AnchorPoint=Vector2.new(.5,0),Text="Playtime",TextColor3=Color3.new(1,1,1),TextStrokeTransparency=0,Font=Enum.Font.Arcade,TextSize=14,Visible=false})
make("TextButton","Shade",gui,{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=.42,Text="",AutoButtonColor=false,Visible=false,ZIndex=2,Selectable=false})
local panel=make("ImageLabel","Panel",gui,{BackgroundTransparency=1,Image="rbxassetid://77751697171816",Size=UDim2.fromOffset(1100,706),Position=UDim2.fromScale(.5,.5),AnchorPoint=Vector2.new(.5,.5),Visible=false,ZIndex=3})
make("UIScale","ResponsiveScale",panel,{Scale=1})
local content=make("Frame","Content",panel,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1})
local function label(name,parent,size,pos,text,textSize)
 return make("TextLabel",name,parent,{BackgroundTransparency=1,Size=size,Position=pos,Text=text,Font=Enum.Font.Arcade,TextSize=textSize,TextColor3=Color3.new(1,1,1),TextStrokeColor3=Color3.new(0,0,0),TextStrokeTransparency=0})
end
-- Atlases are 970 x 890, each card 310 x 410, gutters 20 x 70.
local art={{"a",0,0},{"a",330,0},{"a",660,0},{"b",0,0},{"b",330,0},{"b",660,0},{"a",0,480},{"a",330,480},{"a",660,480},{"b",0,480},{"b",330,480},{"b",660,480}}
local ids={a="rbxassetid://79244377911173",b="rbxassetid://112387490142388"}
local times={"05:00","10:00","15:00","25:00","30:00","45:00","60:00","1:10:00","1:20:00","1:30:00","1:45:00","2:00:00"}
for i,v in art do
 local col=(i-1)%6 local row=math.floor((i-1)/6)
 local card=make("ImageLabel","Reward"..i,content,{BackgroundTransparency=1,Image=ids[v[1]],ImageRectOffset=Vector2.new(v[2],v[3]),ImageRectSize=Vector2.new(310,410),Position=UDim2.fromOffset(32+174*col,161+254*row),Size=UDim2.fromOffset(164,217)})
 label("Timer",card,UDim2.new(1,-8,0,31),UDim2.fromOffset(4,6),times[i],36)
 local stamp=make("ImageLabel","Claimed",card,{BackgroundTransparency=1,Image="rbxassetid://109737046735883",Size=UDim2.fromScale(.9,.9),Position=UDim2.fromScale(.5,.5),AnchorPoint=Vector2.new(.5,.5),ScaleType=Enum.ScaleType.Fit,Visible=false,ZIndex=4})
 local claim=make("ImageButton","Claim",card,{BackgroundTransparency=1,Image="rbxassetid://116217914349484",Size=UDim2.fromOffset(119,29),Position=UDim2.new(.5,0,1,2),AnchorPoint=Vector2.new(.5,0),AutoButtonColor=false,Visible=false})
 make("UIScale","PopScale",claim,{Scale=1})
end
label("Status",content,UDim2.fromOffset(1010,26),UDim2.fromOffset(45,665),"Playtime continues through multiplayer rounds.",15)
local close=SG.GBloxDailyRewards.Panel.Close:Clone() close.Name="Close" close.Parent=panel
return "Built original-art 12-card playtime panel and clock button."
