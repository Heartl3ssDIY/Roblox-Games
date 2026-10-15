local g=game.StarterGui.PackRevealGui
local b=g.Board
g.IgnoreGuiInset=false
local function frame(parent,name,pos,size,color,trans,z)
 local f=Instance.new("Frame");f.Name=name;f.Position=pos;f.Size=size;f.BackgroundColor3=color or Color3.new(1,1,1)
 f.BackgroundTransparency=trans or 1;f.BorderSizePixel=0;f.ZIndex=z or 1;f.Parent=parent;return f
end
local function text(parent,name,value,pos,size,fontSize,z)
 local t=Instance.new("TextLabel");t.Name=name;t.Text=value;t.Position=pos;t.Size=size;t.BackgroundTransparency=1
 t.Font=Enum.Font.PermanentMarker;t.TextSize=fontSize;t.TextColor3=Color3.new(1,1,1);t.TextStrokeTransparency=0
 t.TextStrokeColor3=Color3.fromRGB(26,12,45);t.ZIndex=z or 2;t.Parent=parent;return t
end
g.Dim.BackgroundColor3=Color3.fromRGB(36,15,64);g.Dim.BackgroundTransparency=0
local gradient=Instance.new("UIGradient");gradient.Color=ColorSequence.new(Color3.fromRGB(81,36,138),Color3.fromRGB(22,9,46));gradient.Rotation=90;gradient.Parent=g.Dim
local backdrop=frame(g,"Atmosphere",UDim2.fromScale(.5,.5),UDim2.fromOffset(1200,1200),nil,1,1)
backdrop.AnchorPoint=Vector2.new(.5,.5)
for i=1,14 do
 local ray=frame(backdrop,"Ray"..i,UDim2.fromScale(.5,.5),UDim2.fromOffset(35+(i%3)*16,780),Color3.fromRGB(215,169,255),.88,1)
 ray.AnchorPoint=Vector2.new(.5,1);ray.Rotation=i*360/14
 local gr=Instance.new("UIGradient");gr.Rotation=90;gr.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.4,.3),NumberSequenceKeypoint.new(1,1)});gr.Parent=ray
end
b.ZIndex=2
local opening=b.Opening
local pack=opening.Pack
pack.Size=UDim2.fromOffset(232,380)
local scale=Instance.new("UIScale");scale.Name="Motion";scale.Parent=pack
local sealed=Instance.new("CanvasGroup");sealed.Name="Seal";sealed.BackgroundTransparency=1;sealed.BorderSizePixel=0
sealed.Size=UDim2.fromScale(1,.14);sealed.Parent=pack;sealed.Visible=false
local sealArt=Instance.new("ImageLabel");sealArt.Name="Artwork";sealArt.Size=UDim2.fromScale(1,1/.14)
sealArt.BackgroundTransparency=1;sealArt.ScaleType=Enum.ScaleType.Stretch;sealArt.Parent=sealed
local body=Instance.new("CanvasGroup");body.Name="Body";body.BackgroundTransparency=1;body.BorderSizePixel=0
body.Position=UDim2.fromScale(0,.14);body.Size=UDim2.fromScale(1,.86);body.Parent=pack;body.Visible=false
local bodyArt=Instance.new("ImageLabel");bodyArt.Name="Artwork";bodyArt.BackgroundTransparency=1
bodyArt.Position=UDim2.fromScale(0,-.14/.86);bodyArt.Size=UDim2.fromScale(1,1/.86);bodyArt.ScaleType=Enum.ScaleType.Stretch;bodyArt.Parent=body
opening.Hint.Text="TAP TO OPEN";opening.Hint.TextSize=23
local focus=frame(b,"Focus",UDim2.fromOffset(0,0),UDim2.fromScale(1,1),nil,1,10);focus.Visible=false
frame(focus,"Shade",UDim2.fromOffset(0,0),UDim2.fromScale(1,1),Color3.fromRGB(28,10,48),.22,10)
text(focus,"Title","",UDim2.fromOffset(140,26),UDim2.fromOffset(800,65),35,11)
text(focus,"Hint","",UDim2.fromOffset(290,530),UDim2.fromOffset(500,44),24,11)
local target=frame(focus,"CardAnchor",UDim2.fromOffset(540,305),UDim2.fromOffset(186,292),nil,1,11)
target.AnchorPoint=Vector2.new(.5,.5)
local mystery=Instance.new("ImageLabel");mystery.Name="Mystery";mystery.Image="rbxassetid://114944696844696"
mystery.Position=UDim2.fromScale(.5,.5);mystery.AnchorPoint=Vector2.new(.5,.5);mystery.Size=UDim2.fromOffset(186,292)
mystery.BackgroundTransparency=1;mystery.Image= g.Templates.Rare.Image;mystery.ZIndex=12;mystery.Parent=focus
local q=text(mystery,"Question","?",UDim2.fromScale(0,0),UDim2.fromScale(1,1),110,13)
local ms=Instance.new("UIScale");ms.Name="Motion";ms.Parent=mystery
local skip=Instance.new("TextButton");skip.Name="Skip";skip.Text="TAP TO SKIP";skip.Font=Enum.Font.PermanentMarker
skip.TextSize=22;skip.TextColor3=Color3.new(1,1,1);skip.TextStrokeTransparency=0;skip.BackgroundTransparency=1
skip.Position=UDim2.fromOffset(370,642);skip.Size=UDim2.fromOffset(340,44);skip.ZIndex=25;skip.Parent=b
local particles=frame(b,"Particles",UDim2.fromScale(0,0),UDim2.fromScale(1,1),nil,1,20)
local flash=frame(g,"Flash",UDim2.fromScale(0,0),UDim2.fromScale(1,1),Color3.new(1,1,1),1,30)
local slot=frame(g.Templates,"RewardSlot",UDim2.fromScale(0,0),UDim2.fromOffset(186,292),nil,1,1);slot.Visible=false
local particle=frame(g.Templates,"Confetti",UDim2.fromScale(0,0),UDim2.fromOffset(8,13),Color3.new(1,1,1),0,20)
particle.Visible=false;particle.AnchorPoint=Vector2.new(.5,.5)
for _,template in g.Templates:GetChildren() do
 if template:IsA("ImageLabel") then
  local motion=Instance.new("UIScale");motion.Name="Motion";motion.Parent=template
 end
end
local padding=b.Results.Cards:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding",b.Results.Cards)
padding.PaddingLeft=UDim.new(0,18);padding.PaddingTop=UDim.new(0,10);padding.PaddingBottom=UDim.new(0,12)
local g=game.StarterGui.PackRevealGui
local b=g.Board
local backup=Instance.new("Folder");backup.Name="BeforePackVisualRefinement20260924";backup.Parent=game.ServerStorage
g:Clone().Parent=backup;game.ReplicatedStorage.PackReveal:Clone().Parent=backup
g.Dim.BackgroundColor3=Color3.new(1,1,1)
g.Dim.UIGradient.Color=ColorSequence.new(Color3.fromRGB(24,14,45),Color3.fromRGB(7,8,19))
for _,child in g.Atmosphere:GetChildren() do child:Destroy() end
g.Atmosphere.Visible=false
local glow=Instance.new("Frame");glow.Name="Halo";glow.BackgroundTransparency=1;glow.BorderSizePixel=0
glow.Position=UDim2.fromOffset(540,315);glow.Size=UDim2.fromOffset(760,760);glow.AnchorPoint=Vector2.new(.5,.5);glow.ZIndex=1;glow.Parent=b
for i=1,38 do
 local ring=Instance.new("Frame");ring.Name="SoftLayer"..i;ring.Size=UDim2.fromScale(1-i/42,1-i/42)
 ring.Position=UDim2.fromScale(.5,.5);ring.AnchorPoint=Vector2.new(.5,.5);ring.BorderSizePixel=0
 ring.BackgroundColor3=Color3.fromRGB(255,182,67);ring.BackgroundTransparency=.981;ring.Parent=glow
 local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(1,0);corner.Parent=ring
end
b.Opening.ZIndex=3;b.Results.ZIndex=4
local pack=b.Opening.Pack
pack.ZIndex=3
pack.Size=UDim2.fromOffset(250,410)
b.Opening.Title.Position=UDim2.fromOffset(290,540)
b.Opening.Title.TextSize=28
b.Opening.Hint.Position=UDim2.fromOffset(340,586)
b.Opening.Hint.TextSize=17
b.Opening.Hint.TextColor3=Color3.fromRGB(186,177,207)
b.Opening.Title.Text="GOLD PACK"
local function finish(parent,left,top,right,bottom,z)
 local f=Instance.new("CanvasGroup");f.Name="Finish";f.BackgroundTransparency=1;f.BorderSizePixel=0
 f.Position=UDim2.fromOffset(left,top);f.Size=UDim2.new(1,-left-right,1,-top-bottom);f.ZIndex=z;f.Parent=parent
 local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,10);corner.Parent=f
 local glass=Instance.new("Frame");glass.Name="Glass";glass.BackgroundColor3=Color3.new(1,1,1)
 glass.BorderSizePixel=0;glass.Size=UDim2.fromScale(1,1);glass.ZIndex=z;glass.Parent=f
 local gloss=Instance.new("UIGradient");gloss.Rotation=32
 gloss.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.79),NumberSequenceKeypoint.new(.32,.94),NumberSequenceKeypoint.new(.5,1),NumberSequenceKeypoint.new(.75,1),NumberSequenceKeypoint.new(1,.95)});gloss.Parent=glass
 local streak=glass:Clone();streak.Name="Streak";streak.Parent=f
 streak.UIGradient.Name="Sweep";streak.Sweep.Offset=Vector2.new(-1.1,0);streak.Sweep.Rotation=24
 streak.Sweep.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.35,1),NumberSequenceKeypoint.new(.46,.93),NumberSequenceKeypoint.new(.51,.48),NumberSequenceKeypoint.new(.58,.90),NumberSequenceKeypoint.new(.72,1),NumberSequenceKeypoint.new(1,1)})
 return f
end
finish(pack,12,39,12,37,6)
local seam=Instance.new("Frame");seam.Name="Seam";seam.BackgroundColor3=Color3.fromRGB(255,241,191)
seam.BorderSizePixel=0;seam.Position=UDim2.fromScale(.04,.14);seam.Size=UDim2.fromScale(.92,.006)
seam.BackgroundTransparency=1;seam.ZIndex=7;seam.Parent=pack
for _,card in g.Templates:GetChildren() do
 if card:IsA("ImageLabel") then
  finish(card,5,5,5,24,2)
  card.Amount.ZIndex=3;card.UnitName.ZIndex=3;card.NewUnit.ZIndex=4
  local stroke=Instance.new("UIStroke");stroke.Name="RarityEdge";stroke.Thickness=1.5;stroke.Transparency=.45;stroke.Color=Color3.fromRGB(189,198,220);stroke.Parent=card
  local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,18);corner.Parent=card
 end
end
b.Results.Title.Text="PACK REWARDS"
b.Results.Title.TextSize=34
b.Skip.TextSize=16
b.Skip.TextColor3=Color3.fromRGB(186,177,207)
b.Results.Continue.BackgroundColor3=Color3.fromRGB(33,173,85)
local grad=Instance.new("UIGradient");grad.Color=ColorSequence.new(Color3.fromRGB(174,255,169),Color3.fromRGB(45,186,84));grad.Rotation=90;grad.Parent=b.Results.Continue
b.Focus.Shade.BackgroundColor3=Color3.fromRGB(12,8,25)
local g=game.StarterGui.PackRevealGui
local old=g.Board.Halo
local halo=Instance.new("CanvasGroup");halo.Name="Halo";halo.Size=old.Size;halo.Position=old.Position;halo.AnchorPoint=old.AnchorPoint
halo.BackgroundTransparency=1;halo.BorderSizePixel=0;halo.ZIndex=1;halo.GroupColor3=Color3.fromRGB(255,191,58)
old:Destroy();halo.Parent=g.Board
for i=1,120 do
 local ring=Instance.new("Frame");ring.Name="SoftLayer"..i;ring.Size=UDim2.fromScale(1-i/126,1-i/126)
 ring.Position=UDim2.fromScale(.5,.5);ring.AnchorPoint=Vector2.new(.5,.5);ring.BorderSizePixel=0
 ring.BackgroundColor3=Color3.new(1,1,1);ring.BackgroundTransparency=.994;ring.Parent=halo
 local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(1,0);corner.Parent=ring
end
local pack=g.Board.Opening.Pack
pack.Finish.Glass.BackgroundTransparency=.55
local bodyFinish=pack.Finish:Clone()
bodyFinish.Position=UDim2.fromOffset(12,0);bodyFinish.Size=UDim2.new(1,-24,1,-37);bodyFinish.Parent=pack.Body
g.Enabled=false
local g=game.StarterGui.PackRevealGui
g.IgnoreGuiInset=true
g.ScreenInsets=Enum.ScreenInsets.None
g.Board.Focus.Shade.Position=UDim2.fromScale(-2,-2)
g.Board.Focus.Shade.Size=UDim2.fromScale(5,5)
local button=g.Board.Results.Continue
button.Text=""
local t=Instance.new("TextLabel");t.Name="Label";t.Text="CONTINUE";t.Size=UDim2.fromScale(1,1)
t.BackgroundTransparency=1;t.TextColor3=Color3.new(1,1,1);t.TextStrokeColor3=Color3.fromRGB(13,56,23);t.TextStrokeTransparency=0
t.Font=Enum.Font.PermanentMarker;t.TextSize=25;t.ZIndex=3;t.Parent=button
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