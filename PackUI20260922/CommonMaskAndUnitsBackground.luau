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