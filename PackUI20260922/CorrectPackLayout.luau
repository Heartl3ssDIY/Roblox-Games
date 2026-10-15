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
return "Canvas mask and shared Units background installed"