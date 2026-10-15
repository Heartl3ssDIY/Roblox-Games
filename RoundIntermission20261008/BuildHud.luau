assert(not game:GetService("RunService"):IsRunning(),"Edit only")
assert(game.PlaceId==95034648955135,"Wrong place")
assert(not game.StarterGui:FindFirstChild("PlaygroundIntermissionHUD"),"Timer already exists")
local gui=Instance.new("ScreenGui")
gui.Name="PlaygroundIntermissionHUD"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=false
gui.DisplayOrder=20
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
local navy=Color3.fromRGB(24,35,62)
local cream=Color3.fromRGB(255,249,224)
local function label(parent,name,position,size,fontSize,color,outline)
	local t=Instance.new("TextLabel")
	t.Name=name;t.Position=position;t.Size=size
	t.BackgroundTransparency=1;t.Text="";t.TextScaled=true
	t.Font=Enum.Font.FredokaOne;t.TextColor3=color;t.ZIndex=3
	local constraint=Instance.new("UITextSizeConstraint")
	constraint.MinTextSize=10;constraint.MaxTextSize=fontSize;constraint.Parent=t
	if outline then local s=Instance.new("UIStroke");s.Color=navy;s.Thickness=1.4;s.Parent=t end
	t.Parent=parent
	return t
end
for _,compact in {false,true} do
	local card=Instance.new("Frame")
	card.Name=compact and "Compact" or "Desktop"
	card.AnchorPoint=Vector2.new(compact and 1 or .5,0)
	card.Position=compact and UDim2.new(1,-18,0,82) or UDim2.new(.5,0,0,12)
	card.Size=compact and UDim2.new(.7,0,0,60) or UDim2.fromOffset(360,68)
	card.BackgroundTransparency=1;card.BorderSizePixel=0;card.Visible=not compact
	local limit=Instance.new("UISizeConstraint")
	limit.MaxSize=Vector2.new(compact and 320 or 360,68);limit.Parent=card
	local fallback=Instance.new("Frame")
	fallback.Name="Fallback";fallback.Size=UDim2.fromScale(1,1);fallback.BackgroundColor3=cream;fallback.BorderSizePixel=0;fallback.Visible=false
	local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,13);corner.Parent=fallback
	local stroke=Instance.new("UIStroke");stroke.Color=navy;stroke.Thickness=2;stroke.Parent=fallback
	fallback.Parent=card
	local image=game.StarterGui.PlaygroundShell.Wallet.ReusableSkin:Clone()
	image.Name="ReusableSkin";image.AnchorPoint=Vector2.zero;image.Position=UDim2.fromScale(0,0);image.Size=UDim2.fromScale(1,1);image.ZIndex=2;image.Parent=card
	label(card,"Title",UDim2.new(.035,0,.10,0),UDim2.new(.68,0,.43,0),compact and 18 or 22,cream,true).Text="INTERMISSION"
	label(card,"Timer",UDim2.new(.72,0,.06,0),UDim2.new(.245,0,.52,0),compact and 25 or 32,Color3.fromRGB(255,212,70),true).Text="0:35"
	label(card,"Detail",UDim2.new(.05,0,.58,0),UDim2.new(.9,0,.26,0),compact and 12 or 15,navy,false).Text="Vote for the next game!"
	card.Parent=gui
end
gui.Parent=game.StarterGui
return gui
