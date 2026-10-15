local S=game.StarterGui
local g=S.PackRevealGui
g.Enabled=false
g.Dim.BackgroundColor3=Color3.new(0,0,0)
g.Dim.BackgroundTransparency=.45
local gradient=g.Dim:FindFirstChildOfClass("UIGradient");if gradient then gradient:Destroy() end
for _,v in {g:FindFirstChild("Atmosphere"),g:FindFirstChild("Flash"),g.Board:FindFirstChild("Halo")} do if v then v:Destroy() end end
g.Board.Focus.Shade.Visible=false
for _,card in g.Templates:GetChildren() do
 if card:IsA("ImageLabel") then
  local finish=card:FindFirstChild("Finish");if finish then finish:Destroy() end
  local stroke=card:FindFirstChild("RarityEdge") or card:FindFirstChild("CardStroke") or Instance.new("UIStroke",card)
  stroke.Name="CardStroke";stroke.Color=Color3.fromRGB(14,14,18);stroke.Thickness=2;stroke.Transparency=0
 end
end
local button=g.Board.Results.Continue
local gloss=button:FindFirstChildOfClass("UIGradient");if gloss then gloss:Destroy() end
button.BackgroundColor3=Color3.fromRGB(28,181,60)
local units=S.UnitsGui
local grid=units.Overlay.Board.Panel.CollectionBackground.Grid
local layout=grid:FindFirstChildOfClass("UIGridLayout")
layout.CellSize=UDim2.fromOffset(138,138)
layout.CellPadding=UDim2.fromOffset(5,8)
local padding=grid:FindFirstChildOfClass("UIPadding")
padding.PaddingTop=UDim.new(0,8)
padding.PaddingRight=UDim.new(0,8)
local card=units.Templates.UnitCard
card.Selection.Thickness=1
card.Selection.Transparency=.35
card.Selection.Color=Color3.new(1,1,1)
card.MasteryBadge.Size=UDim2.fromOffset(28,28)
card.MasteryBadge.Position=UDim2.new(1,3,0,-2)
card.MasteryBadge.AnchorPoint=Vector2.new(.85,.15)
card.MasteryBadge.Level.TextSize=14
return "Plain XP cards, no coloured opening background, compact three-column collection"