local A = {
Background="rbxassetid://103501917264659",
Panel="rbxassetid://72544862064291",
Illustration="rbxassetid://116887281103925",
Back="rbxassetid://96886993260887",
Next="rbxassetid://93632318789794",
Battle="rbxassetid://86158857614070",
Claim="rbxassetid://77533410881843",
ArenaLabel="rbxassetid://130213598057000",
ProgressBorder="rbxassetid://115413418391737",
ProgressTrack="rbxassetid://77567001343105",
ProgressFill="rbxassetid://139530081645767",
Loss="rbxassetid://132921535710763",
Cash="rbxassetid://100493929583370",
Diamonds="rbxassetid://98525797130345",
Unit="rbxassetid://104636274552546",
Earned="rbxassetid://70981662299660",
CommonCircle="rbxassetid://93230072757852",
SilverCircle="rbxassetid://91358385296719",
CommonPack="rbxassetid://100641844953171",
SilverPack="rbxassetid://97770948696812",
}
local old=game.StarterGui:FindFirstChild("ArenaSelectGui")
if old then old:Destroy() end
local function make(class,name,parent,props)
 local o=Instance.new(class);o.Name=name
 for k,v in pairs(props or {}) do o[k]=v end
 o.Parent=parent;return o
end
local function image(name,parent,x,y,w,h,asset,button,z)
 return make(button and "ImageButton" or "ImageLabel",name,parent,{
  BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
  Image=A[asset],ZIndex=z or 2,
 })
end
local function label(name,parent,x,y,w,h,text,size)
 return make("TextLabel",name,parent,{
 BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
 Text=text,TextSize=size,Font=Enum.Font.PermanentMarker,TextColor3=Color3.new(1,1,1),
 TextStrokeColor3=Color3.fromRGB(20,12,27),TextStrokeTransparency=0,ZIndex=8,
 })
end
local gui=make("ScreenGui","ArenaSelectGui",game.StarterGui,{
 Enabled=false,ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=30,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
})
gui:SetAttribute("AutoFit",true)
gui:SetAttribute("FitMargin",24)
make("Frame","Dim",gui,{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=.45,BorderSizePixel=0})
local board=make("Frame","Board",gui,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(1132,689),BackgroundTransparency=1})
make("UIScale","FitToScreen",board,{Scale=.85})
image("Background",board,0,0,1132,689,"Background",false,1)
image("Panel",board,35,173,1062,462,"Panel",false,2)
image("Illustration",board,76,204,310,378,"Illustration",false,3)
local pill=image("ArenaNumber",board,405,213,158,61,"ArenaLabel",false,3)
label("Label",pill,0,0,158,54,"Arena 1",22)
local title=label("Title",board,413,272,530,49,"Tenkaichi",38)
title.TextXAlignment=Enum.TextXAlignment.Left
title.TextColor3=Color3.fromRGB(255,219,93)
local desc=label("Description",board,414,322,530,58,"Fight beneath tropical skies at the Tenkaichi martial arts tournament. Draft your team and take the ring.",19)
desc.Font=Enum.Font.GothamBold
desc.TextWrapped=true;desc.TextXAlignment=Enum.TextXAlignment.Left;desc.TextYAlignment=Enum.TextYAlignment.Top
image("ProgressBorder",board,404,426,544,105,"ProgressBorder",false,3)
image("ProgressTrack",board,424,445,504,65,"ProgressTrack",false,4)
local track=make("CanvasGroup","Progress",board,{BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(432,453),Size=UDim2.fromOffset(488,49),ZIndex=5})
make("UICorner","Corner",track,{CornerRadius=UDim.new(0,24)})
local loss=make("Frame","LossClip",track,{BackgroundTransparency=1,BorderSizePixel=0,ClipsDescendants=true,Size=UDim2.fromScale(0,1),ZIndex=5})
image("Image",loss,0,0,488,49,"Loss",false,5)
local fill=make("Frame","FillClip",track,{BackgroundTransparency=1,BorderSizePixel=0,ClipsDescendants=true,Size=UDim2.fromScale(0,1),ZIndex=6})
image("Image",fill,0,0,488,49,"ProgressFill",false,6)
label("ProgressText",board,424,445,504,65,"0/10",27)
local milestones=make("Folder","Milestones",board)
for i, data in ipairs({{2,"Cash"},{4,"Unit"},{8,"Diamonds"},{10,"Unit"}}) do
 local x=432+488*data[1]/10-30
 local reward=image("Reward"..i,milestones,x,387,60,60,data[2],true,7)
 reward.AutoButtonColor=false
 reward:SetAttribute("Wins",data[1])
 image("Check",reward,36,30,26,26,"Earned",false,9).Visible=false
 label("Wins",reward,0,-15,60,20,tostring(data[1]),14)
end
local daily=make("Folder","DailyRewards",board)
for i=1,4 do
 local pack=image("Reward"..i,daily,969,535-(i-1)*106,60,60,i==4 and "SilverCircle" or "CommonCircle",true,7)
 pack.AutoButtonColor=false;pack:SetAttribute("Slot",i)
 image("Pack",pack,1,1,58,58,i==4 and "SilverPack" or "CommonPack",false,8)
 image("Check",pack,39,38,28,28,"Earned",false,9).Visible=false
end
image("Action",board,518,523,286,90,"Battle",true,7).AutoButtonColor=false
image("Back",board,1047,49,48,48,"Back",true,7).AutoButtonColor=false
image("Next",board,1042,372,78,73,"Next",true,8).AutoButtonColor=false
local notice=label("Notice",board,405,605,540,26,"",15)
notice.Visible=false
local locked=label("Locked",board,90,330,280,100,"ARENA 2\nLOCKED",28)
locked.Visible=false
board.Progress.Corner.CornerRadius = UDim.new(.5, 0)
for _, spec in ipairs({{"FillClip", 230}, {"LossClip", 273}}) do
    local fillImage = board.Progress[spec[1]].Image
    fillImage.ScaleType = Enum.ScaleType.Slice
    fillImage.SliceCenter = Rect.new(25, 0, spec[2] - 1, 50)
    fillImage.SliceScale = board.Progress.Size.Y.Offset / 50
end
local pillText = board.ArenaNumber.Label
pillText.TextSize = 34
pillText.Position = UDim2.fromOffset(10, 0)
pillText.Size = UDim2.new(1, -20, 0, 54)
pillText.TextStrokeTransparency = 0
local title = board.Title
title.TextSize = 54
title.TextStrokeTransparency = 1
local old = board:FindFirstChild("TitleWhiteOutline")
if old then old:Destroy() end
local outline = title:Clone()
outline.Name = "TitleWhiteOutline"
outline.ZIndex = title.ZIndex - 1
outline.Parent = board
local outer = Instance.new("UIStroke")
outer.Name = "WhiteOuterStroke"
outer.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
outer.Color = Color3.new(1, 1, 1)
outer.Thickness = 5
outer.LineJoinMode = Enum.LineJoinMode.Round
outer.Parent = outline
local inner = title:FindFirstChild("DarkStroke") or Instance.new("UIStroke")
inner.Name = "DarkStroke"
inner.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
inner.Color = Color3.fromRGB(18, 10, 25)
inner.Thickness = 3
inner.LineJoinMode = Enum.LineJoinMode.Round
inner.Parent = title
return "Editable ArenaSelectGui created"

