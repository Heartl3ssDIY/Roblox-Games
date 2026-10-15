local S=game:GetService("StarterGui")
local function image(parent,name,id,pos,size,class)
 local v=Instance.new(class or "ImageLabel")
 v.Name=name;v.Image=id;v.BackgroundTransparency=1;v.BorderSizePixel=0
 v.Position=pos;v.Size=size;v.ScaleType=Enum.ScaleType.Fit;v.Parent=parent
 return v
end
local function badge(parent,size)
 local b=image(parent,"MasteryBadge","rbxassetid://122724395505127",UDim2.new(1,5,0,-9),UDim2.fromOffset(size,size))
 b.AnchorPoint=Vector2.new(0.8,0.1);b.ZIndex=8
 local t=Instance.new("TextLabel");t.Name="Level";t.BackgroundTransparency=1;t.Size=UDim2.fromScale(1,1)
 t.Text="1";t.Font=Enum.Font.PermanentMarker;t.TextSize=math.floor(size*.44);t.TextColor3=Color3.new(1,1,1)
 t.TextStrokeColor3=Color3.fromRGB(12,9,33);t.TextStrokeTransparency=0;t.ZIndex=9;t.Parent=b
 return b
end
badge(S.UnitsGui.Templates.UnitCard,44)
badge(S.UnitsGui.Overlay.Board.Panel.Detail.Portrait,54)
for i=1,4 do badge(S.ArenaHUD.EquippedBar["Slot"..i],34) end
local g=Instance.new("ScreenGui");g.Name="ModePickerGui";g.Enabled=false;g.ResetOnSpawn=false
g.DisplayOrder=25;g.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;g.IgnoreGuiInset=false;g:SetAttribute("AutoFit",true);g.Parent=S
local dim=Instance.new("Frame");dim.Name="Dim";dim.Size=UDim2.fromScale(1,1);dim.BorderSizePixel=0
dim.BackgroundColor3=Color3.new(0,0,0);dim.BackgroundTransparency=.42;dim.Parent=g
local p=Instance.new("Frame");p.Name="Panel";p.AnchorPoint=Vector2.new(.5,.5);p.Position=UDim2.fromScale(.5,.5)
p.Size=UDim2.fromOffset(1132,689);p.BackgroundTransparency=1;p.BorderSizePixel=0;p.Parent=g
local fit=Instance.new("UIScale");fit.Name="FitToScreen";fit.Scale=.82;fit.Parent=p
local content=Instance.new("CanvasGroup");content.Name="Content";content.Size=UDim2.fromScale(1,1)
content.Position=UDim2.fromScale(.5,.5);content.AnchorPoint=Vector2.new(.5,.5)
content.BackgroundTransparency=1;content.BorderSizePixel=0;content.Parent=p
local motion=Instance.new("UIScale");motion.Name="Motion";motion.Parent=content
image(content,"Background","rbxassetid://137764674480602",UDim2.fromOffset(0,0),UDim2.fromScale(1,1))
for i,spec in {{name="Main",id="rbxassetid://132998460838171",x=280},{name="UnderConstruction",id="rbxassetid://124757061807194",x=840}} do
 local btn=image(content,spec.name,spec.id,UDim2.fromOffset(spec.x,403),UDim2.fromOffset(440,450),"ImageButton")
 btn.AnchorPoint=Vector2.new(.5,.5);btn.AutoButtonColor=false;btn.ZIndex=2
 btn:SetAttribute("Locked",i==2)
 local scale=Instance.new("UIScale");scale.Name="HoverScale";scale.Parent=btn
 local mask=Instance.new("CanvasGroup");mask.Name="Finish";mask.Position=UDim2.fromOffset(9,9)
 mask.Size=UDim2.new(1,-18,1,-18);mask.BackgroundTransparency=1;mask.BorderSizePixel=0;mask.ZIndex=3;mask.Parent=btn
 local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,18);corner.Parent=mask
 local gloss=Instance.new("Frame");gloss.Name="Gloss";gloss.BorderSizePixel=0;gloss.Size=UDim2.fromScale(1,.48)
 gloss.BackgroundColor3=Color3.new(1,1,1);gloss.ZIndex=3;gloss.Parent=mask
 local grad=Instance.new("UIGradient");grad.Rotation=90;grad.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.87),NumberSequenceKeypoint.new(.75,.99),NumberSequenceKeypoint.new(1,1)});grad.Parent=gloss
 local shine=Instance.new("Frame");shine.Name="Shine";shine.Size=UDim2.fromScale(1,1);shine.BorderSizePixel=0
 shine.BackgroundColor3=Color3.new(1,1,1);shine.ZIndex=4;shine.Parent=mask
 local sweep=Instance.new("UIGradient");sweep.Name="Sweep";sweep.Rotation=22;sweep.Offset=Vector2.new(-1.3,0)
 sweep.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.4,1),NumberSequenceKeypoint.new(.5,.7),NumberSequenceKeypoint.new(.6,1),NumberSequenceKeypoint.new(1,1)});sweep.Parent=shine
end
local close=image(content,"Close","rbxassetid://120222408397408",UDim2.fromOffset(1057,27),UDim2.fromOffset(50,51),"ImageButton");close.ZIndex=5
local grid=game.StarterGui.UnitsGui.Overlay.Board.Panel.CollectionBackground.Grid
local padding=Instance.new("UIPadding")
padding.Name="MasteryBadgeClearance"
padding.PaddingTop=UDim.new(0,16)
padding.PaddingRight=UDim.new(0,16)
padding.Parent=grid
return "Created editable mode picker and mastery badges"