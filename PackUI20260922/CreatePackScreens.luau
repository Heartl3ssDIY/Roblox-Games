local A = {
    Background = "rbxassetid://100230056947062",
    Title = "rbxassetid://117319706315768",
    Close = "rbxassetid://120222408397408",
    Notification = "rbxassetid://140490410313144",
    Common = "rbxassetid://73606499921543",
    Silver = "rbxassetid://118796124465923",
    Gold = "rbxassetid://107366517958284",
    Diamond = "rbxassetid://110308903192424",
    CommonMax = "rbxassetid://138160374358069",
    SilverMax = "rbxassetid://75411512888668",
    GoldMax = "rbxassetid://74323494771542",
    DiamondMax = "rbxassetid://124705740193814",
    BuyRobux = "rbxassetid://72323792354298",
    BuyDiamond = "rbxassetid://134314911325016",
    XPCommon = "rbxassetid://120964141847007",
    XPRare = "rbxassetid://114944696844696",
    XPEpic = "rbxassetid://117478940416668",
    XPLegendary = "rbxassetid://140136040218916",
    XPMythic = "rbxassetid://107470295828679",
    XPFill = "rbxassetid://127592419746151",
    XPTrack = "rbxassetid://140644676430211",
    Level = "rbxassetid://75803692100084",
}
local function make(class,name,parent,props)
    local o=Instance.new(class)
    o.Name=name
    for k,v in pairs(props or {}) do o[k]=v end
    o.Parent=parent
    return o
end
local function bounds(o,x,y,w,h)
    o.Position=UDim2.fromOffset(x,y)
    o.Size=UDim2.fromOffset(w,h)
    return o
end
local function image(parent,name,asset,x,y,w,h,button)
    return bounds(make(button and "ImageButton" or "ImageLabel",name,parent,{
        Image=asset,BackgroundTransparency=1,BorderSizePixel=0,ScaleType=Enum.ScaleType.Fit,
    }),x,y,w,h)
end
local function text(parent,name,value,x,y,w,h,size)
    local label=bounds(make("TextLabel",name,parent,{
        Text=value,Font=Enum.Font.PermanentMarker,TextSize=size,TextColor3=Color3.new(1,1,1),
        BackgroundTransparency=1,BorderSizePixel=0,TextWrapped=true,
    }),x,y,w,h)
    make("UIStroke","TextOutline",label,{Color=Color3.new(),Thickness=2})
    return label
end
local function frame(parent,name,x,y,w,h)
    return bounds(make("Frame",name,parent,{BackgroundTransparency=1,BorderSizePixel=0}),x,y,w,h)
end
assert(not game.StarterGui:FindFirstChild("PackShopGui"),"PackShopGui already exists")
assert(not game.StarterGui:FindFirstChild("PackRevealGui"),"PackRevealGui already exists")
local gui=make("ScreenGui","PackShopGui",game.StarterGui,{
    Enabled=false,ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=35,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
})
gui:SetAttribute("AutoFit",true)
local dim=make("Frame","Dim",gui,{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(),BackgroundTransparency=0.35,BorderSizePixel=0})
local board=frame(gui,"Board",0,0,1280,770)
board.AnchorPoint=Vector2.new(0.5,0.5)
board.Position=UDim2.fromScale(0.5,0.5)
make("UIScale","FitToScreen",board)
local panel=image(board,"Panel",A.Background,140,70,1132,689)
image(board,"Title",A.Title,0,0,965,159).ZIndex=5
image(panel,"Close",A.Close,1057,27,50,51,true).ZIndex=6
for _,data in ipairs({{"silver","Silver",226,100},{"gold","Gold",576,200},{"diamond","Diamond",936,500}}) do
    local id,kind,cost=data[1],data[2],data[4]
    local center=data[3]
    local group=frame(panel,kind,center-145,84,290,454)
    text(group,"Title",kind.." Unit\nPack",0,0,290,62,29)
    image(group,"Pack",A[kind],56,66,178,294,true)
    image(group,"Maximum",A[kind.."Max"],70,364,150,48)
    local buy=image(group,"Buy",A.BuyDiamond,58,412,174,50,true)
    text(buy,"Price",tostring(cost),73,0,92,47,33)
    text(group,"Availability","",0,460,290,23,15).Visible=false
end
local common=frame(panel,"Common",278,508,590,173)
image(common,"PackOne",A.Common,35,5,98,160,true).Rotation=-12
image(common,"PackTwo",A.Common,143,5,98,160,true).Rotation=8
image(common,"Maximum",A.CommonMax,326,3,150,48)
text(common,"Remaining","2/2 remaining",286,53,230,32,23)
image(common,"Buy",A.BuyRobux,295,91,213,61,true)
local notice=text(panel,"Notice","",40,656,1050,28,20)
notice.TextColor3=Color3.fromRGB(255,225,145)
notice.Visible=false
notice.ZIndex=15
local tooltip=frame(panel,"Tooltip",360,150,355,420)
tooltip.BackgroundTransparency=0.04
tooltip.BackgroundColor3=Color3.fromRGB(25,15,42)
tooltip.Visible=false
tooltip.ZIndex=20
make("UICorner","Corners",tooltip,{CornerRadius=UDim.new(0,14)})
make("UIStroke","Border",tooltip,{Color=Color3.fromRGB(180,100,255),Thickness=2})
text(tooltip,"Title","Pack details",14,10,327,35,25)
local body=text(tooltip,"Body","",16,50,323,350,18)
body.Font=Enum.Font.PermanentMarker
body.TextXAlignment=Enum.TextXAlignment.Left
body.TextYAlignment=Enum.TextYAlignment.Top
body.TextStrokeTransparency=1
body.TextOutline.Thickness=1

local reveal=make("ScreenGui","PackRevealGui",game.StarterGui,{
    Enabled=false,ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=50,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
})
reveal:SetAttribute("AutoFit",true)
make("Frame","Dim",reveal,{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(),BackgroundTransparency=0.25,BorderSizePixel=0})
local revealBoard=frame(reveal,"Board",0,0,1080,700)
revealBoard.AnchorPoint=Vector2.new(0.5,0.5)
revealBoard.Position=UDim2.fromScale(0.5,0.5)
make("UIScale","FitToScreen",revealBoard)
local opening=frame(revealBoard,"Opening",0,0,1080,700)
local pack=image(opening,"Pack",A.Common,447,170,186,305,true)
make("UIScale","Pulse",pack)
pack.AnchorPoint=Vector2.new(0.5,0.5)
pack.Position=UDim2.fromOffset(540,320)
text(opening,"Title","Common Pack",290,495,500,50,34)
text(opening,"Hint","Tap to open",340,548,400,32,23)
local results=frame(revealBoard,"Results",0,0,1080,700)
results.Visible=false
text(results,"Title","YOU GOT:",20,10,1040,62,42).TextColor3=Color3.fromRGB(255,219,82)
local holder=bounds(make("ScrollingFrame","Cards",results,{
    BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.new(),
    AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=6,ScrollBarImageColor3=Color3.fromRGB(176,100,255),
}),20,90,1040,480)
make("UIGridLayout","Layout",holder,{
    CellSize=UDim2.fromOffset(186,292),CellPadding=UDim2.fromOffset(18,24),
    SortOrder=Enum.SortOrder.LayoutOrder,HorizontalAlignment=Enum.HorizontalAlignment.Center,
})
make("UIPadding","Padding",holder,{PaddingTop=UDim.new(0,4),PaddingBottom=UDim.new(0,12),PaddingLeft=UDim.new(0,6),PaddingRight=UDim.new(0,6)})
text(results,"Empty","No eligible unit rewards in this pack.",130,240,820,70,30).Visible=false
local continueButton= bounds(make("TextButton","Continue",results,{
    Text="CONTINUE",Font=Enum.Font.PermanentMarker,TextSize=30,TextColor3=Color3.new(1,1,1),
    BackgroundColor3=Color3.fromRGB(20,175,55),BorderSizePixel=0,
}),390,610,300,58)
make("UICorner","Corners",continueButton,{CornerRadius=UDim.new(0,16)})
make("UIStroke","Border",continueButton,{Color=Color3.fromRGB(0,75,25),Thickness=3,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
local templates=make("Folder","Templates",reveal)
for _,rarity in ipairs({"Common","Rare","Epic","Legendary","Mythic"}) do
    local card=image(templates,rarity,A["XP"..rarity],0,0,186,292)
    card.ScaleType=Enum.ScaleType.Stretch
    card.Visible=false
    text(card,"Amount","+31",12,8,162,39,32)
    make("ViewportFrame","UnitModel",card,{
        Position=UDim2.fromOffset(12,46),Size=UDim2.fromOffset(162,164),
        BackgroundTransparency=1,BorderSizePixel=0,Ambient=Color3.fromRGB(190,190,190),
        LightColor=Color3.new(1,1,1),LightDirection=Vector3.new(-1,-1,-2),
    })
    local name=text(card,"UnitName","Unit Name",8,213,170,30,23)
    name.TextScaled=true
    make("UITextSizeConstraint","TextLimit",name,{MinTextSize=12,MaxTextSize=23})
    local track=image(card,"XPTrack",A.XPTrack,23,247,163,35)
    track.ScaleType=Enum.ScaleType.Stretch
    local clip=frame(track,"Progress",0,0,163,35)
    clip.ClipsDescendants=true
    image(clip,"Fill",A.XPFill,0,0,163,35).ScaleType=Enum.ScaleType.Stretch
    text(track,"Value","0/5 XP",23,1,133,29,15).ZIndex=3
    local star=image(card,"LevelStar",A.Level,-15,233,60,56)
    star.ZIndex=4
    text(star,"Value","1",13,15,36,31,24)
    local fresh=text(card,"NewUnit","NEW!",25,177,136,28,23)
    fresh.TextColor3=Color3.fromRGB(255,224,87)
    fresh.Visible=false
end
local g=game.StarterGui.PackShopGui
g.IgnoreGuiInset=false
g.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets
g:SetAttribute("FitMargin",48)
local p=g.Board.Panel
for _,name in {"Silver","Gold","Diamond"} do
 local group=p[name]
 group.Title.Position=UDim2.fromOffset(0,-6)
 group.Title.Size=UDim2.fromOffset(290,52)
 group.Pack.Position=UDim2.fromOffset(61,50)
 group.Pack.Size=UDim2.fromOffset(168,280)
 group.Maximum.Position=UDim2.fromOffset(70,332)
 group.Buy.Position=UDim2.fromOffset(58,388)
 group.Buy.ImageColor3=Color3.new(1,1,1)
 group.Buy.ZIndex=4
 group.Buy.Price.ZIndex=5
end
local c=p.Common
local art=c:FindFirstChild("Art") or Instance.new("Frame")
art.Name="Art"
art.BackgroundTransparency=1
art.BorderSizePixel=0
art.Position=UDim2.fromOffset(-14,14)
art.Size=UDim2.fromOffset(344,159)
art.ClipsDescendants=true
art.Parent=c
local one=c:FindFirstChild("PackOne") or art.PackOne
local two=c:FindFirstChild("PackTwo") or art.PackTwo
one.Parent=art
two.Parent=art
one.Position=UDim2.fromOffset(12,25)
one.Size=UDim2.fromOffset(190,313)
one.Rotation=-22
one.ZIndex=2
two.Position=UDim2.fromOffset(128,25)
two.Size=UDim2.fromOffset(190,313)
two.Rotation=-20
two.ZIndex=3
c.Maximum.Position=UDim2.fromOffset(402,20)
c.Remaining.Position=UDim2.fromOffset(364,71)
c.Remaining.Size=UDim2.fromOffset(230,27)
c.Remaining.TextSize=21
c.Buy.Position=UDim2.fromOffset(373,105)
p.Notice.Position=UDim2.fromOffset(160,235)
p.Notice.Size=UDim2.fromOffset(812,62)
p.Notice.BackgroundTransparency=0.08
p.Notice.BackgroundColor3=Color3.fromRGB(25,15,42)
local corner=p.Notice:FindFirstChildOfClass("UICorner") or Instance.new("UICorner",p.Notice)
corner.CornerRadius=UDim.new(0,12)
local p=game.StarterGui.PackShopGui.Board.Panel
local c=p.Common
local old=c.Art
if not old:IsA("CanvasGroup") then
 local art=Instance.new("CanvasGroup")
 art.Name="Art"
 art.BackgroundTransparency=1
 art.BorderSizePixel=0
 art.ClipsDescendants=true
 art.ZIndex=1
 for _,child in old:GetChildren() do child.Parent=art end
 old:Destroy()
 art.Parent=c
end
c.Art.Position=UDim2.fromOffset(2,14)
c.Art.Size=UDim2.fromOffset(324,153)
c.Art.PackOne.Position=UDim2.fromOffset(-4,25)
c.Art.PackTwo.Position=UDim2.fromOffset(112,25)
c.Remaining.Position=UDim2.fromOffset(364,70)
c.Remaining.Size=UDim2.fromOffset(230,34)
c.Remaining.TextSize=17
local lip=p:FindFirstChild("CommonFrameLip")
if lip then lip:Destroy() end
game.StarterGui.UnitsGui.Overlay.Board.Panel.Image=p.Image
return {shop=#gui:GetDescendants(),reveal=#reveal:GetDescendants()}
