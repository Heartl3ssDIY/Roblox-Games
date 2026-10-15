local gui = game.StarterGui.MudHUD
local main = gui.Main
local ink = Color3.fromRGB(24,35,62)
local cream = Color3.fromRGB(255,249,224)
local red = Color3.fromRGB(255,81,92)
local blue = Color3.fromRGB(42,160,255)
local function text(object, value, size)
 object.Text, object.TextColor3, object.TextStrokeTransparency = value, cream, 1
 object.TextScaled, object.TextWrapped = true, true
 local limit = object:FindFirstChildWhichIsA("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
 limit.MinTextSize, limit.MaxTextSize, limit.Parent = 8, size, object
 local stroke = object:FindFirstChildWhichIsA("UIStroke") or Instance.new("UIStroke")
 stroke.Color, stroke.Thickness, stroke.ApplyStrokeMode, stroke.Parent = ink, 1.6, Enum.ApplyStrokeMode.Contextual, object
end
local function caption(button, value)
 button.Text = value
 if button:FindFirstChild("LiveCaption") then text(button.LiveCaption,value,18) end
end
local function label(parent, name, value, position, size, maximum)
 local l=Instance.new("TextLabel")
 l.Name,l.BackgroundTransparency,l.Font,l.Position,l.Size,l.ZIndex = name,1,Enum.Font.FredokaOne,position,size,8
 text(l,value,maximum)
 l.Parent=parent
 return l
end
if gui:FindFirstChild("ColourPicker")then gui.ColourPicker:Destroy()end
if gui:FindFirstChild("ColourToggle")then gui.ColourToggle:Destroy()end
main.Frozen:Destroy()
for _,controls in ipairs({main.Controls,main.DesktopControls})do
 controls.Mud:Destroy()
 controls.Heat:Destroy()
end
main.Controls.Meter:Destroy()
main.Controls.Sprint:Destroy()
main.DesktopControls.Fire:Destroy()
for _,d in ipairs(main:GetDescendants())do if d:IsA("UIScale") and d.Name=="ResponsiveHudScale"then d:Destroy()end end
local top=main.Top
top.Size,top.Position,top.AnchorPoint=UDim2.fromOffset(420,86),UDim2.new(0.5,0,0,12),Vector2.new(0.5,0)
top.SizeLimit:Destroy()
top.Title.Size,top.Title.Position=UDim2.new(1,-24,0,22),UDim2.fromOffset(12,5)
text(top.Title,"LASER TAG",21)
top.Team.Position,top.Team.Size=UDim2.new(0,12,0,29),UDim2.new(0.31,-12,0,28)
top.Team.Active,top.Team.Selectable=false,false
top.Team.TeamColour:Destroy()
top.Team.ReusableSkin.Position,top.Team.ReusableSkin.Size=UDim2.fromScale(0,0),UDim2.fromScale(1,1)
top.Team.ReusableSkin.Image="rbxassetid://96220174131051"
top.Team.ReusableSkin:SetAttribute("DefaultImage","rbxassetid://96220174131051")
top.Team.BackgroundColor3=red
top.Team.LiveCaption.Size,top.Team.LiveCaption.Position=UDim2.new(1,-10,1,-4),UDim2.fromOffset(5,2)
caption(top.Team,"RED\n0 ALIVE")
top.Timer.Position,top.Timer.Size=UDim2.new(0.34,0,0,27),UDim2.new(0.32,0,0,32)
text(top.Timer,"5:00",30)
top.Other.Position,top.Other.Size=UDim2.new(0.69,0,0,29),UDim2.new(0.31,-12,0,28)
text(top.Other,"BLUE\n0 ALIVE",17)
top.Other.TextColor3=blue
local lives=Instance.new("Frame")
lives.Name,lives.BackgroundTransparency,lives.Position,lives.Size,lives.AnchorPoint="Lives",1,UDim2.new(0.5,0,1,-25),UDim2.fromOffset(130,20),Vector2.new(0.5,0)
lives.Parent=top
local team=label(lives,"Team","RED",UDim2.fromOffset(0,2),UDim2.fromOffset(40,16),12)
for index=1,3 do
 local heart=label(lives,"Heart"..index,"♥",UDim2.fromOffset(46+(index-1)*26,0),UDim2.fromOffset(24,21),21)
 heart.TextColor3=red
end
local out=label(top,"Out","OUT · WATCH YOUR TEAM",UDim2.new(0.1,0,1,-24),UDim2.new(0.8,0,0,17),13)
out.Visible=false
local compact=top:Clone()
compact.Name,compact.Size,compact.Position= "CompactTop",UDim2.fromOffset(300,78),UDim2.new(0.5,0,0,56)
compact.Title.Size=UDim2.new(1,-24,0,18)
compact.Title:FindFirstChildWhichIsA("UITextSizeConstraint").MaxTextSize=17
compact.Team.Position,compact.Team.Size=UDim2.new(0,9,0,26),UDim2.new(0.31,-9,0,26)
compact.Other.Position,compact.Other.Size=UDim2.new(0.69,0,0,26),UDim2.new(0.31,-9,0,26)
compact.Team.LiveCaption:FindFirstChildWhichIsA("UITextSizeConstraint").MaxTextSize=13
compact.Other:FindFirstChildWhichIsA("UITextSizeConstraint").MaxTextSize=13
compact.Timer.Position,compact.Timer.Size=UDim2.new(0.34,0,0,24),UDim2.new(0.32,0,0,30)
compact.Timer:FindFirstChildWhichIsA("UITextSizeConstraint").MaxTextSize=26
compact.Lives.Position=UDim2.new(0.5,0,1,-23)
compact.Parent=main
local portrait=compact:Clone()
portrait.Name,portrait.Size,portrait.Position="PortraitTop",UDim2.fromOffset(280,78),UDim2.new(0.5,0,0,64)
portrait.Parent=main
main.Controls.Fire.Position,main.Controls.Fire.Size,main.Controls.Fire.AnchorPoint=UDim2.new(1,-16,1,-194),UDim2.fromOffset(100,46),Vector2.new(1,1)
caption(main.Controls.Fire,"FIRE")
main.MobileSprint.Position,main.MobileSprint.Size,main.MobileSprint.AnchorPoint=UDim2.new(1,-16,1,-142),UDim2.fromOffset(100,46),Vector2.new(1,1)
caption(main.MobileSprint,"SPRINT\n10.0/10s")
main.DesktopControls.Size,main.DesktopControls.Position,main.DesktopControls.AnchorPoint=UDim2.fromOffset(240,82),UDim2.new(1,-24,1,-24),Vector2.new(1,1)
main.DesktopControls.Meter.Position,main.DesktopControls.Meter.Size=UDim2.fromOffset(0,0),UDim2.new(1,0,0,32)
main.DesktopControls.Meter.Track.Position=UDim2.fromOffset(10,24)
main.DesktopControls.Meter.Charge:FindFirstChildWhichIsA("UITextSizeConstraint").MaxTextSize=15
main.DesktopControls.Sprint.Position,main.DesktopControls.Sprint.Size=UDim2.fromOffset(0,38),UDim2.new(1,0,0,44)
caption(main.DesktopControls.Sprint,"SPRINT · HOLD SHIFT")
label(main.DesktopControls,"InputHint","CLICK · FIRE   SHIFT · SPRINT",UDim2.fromOffset(0,-22),UDim2.new(1,0,0,18),13)
main.Countdown.Position,main.Countdown.Size,main.Countdown.AnchorPoint=UDim2.fromScale(0.5,0.5),UDim2.fromOffset(100,86),Vector2.new(0.5,0.5)
main.Results.Size,main.Results.Position=UDim2.new(0.78,0,0,166),UDim2.fromScale(0.5,0.48)
main.Results.SizeLimit.MinSize,main.Results.SizeLimit.MaxSize=Vector2.new(260,166),Vector2.new(520,166)
main.Results.Reason.Size,main.Results.Reason.Position=UDim2.new(0.88,0,0.22,0),UDim2.fromScale(0.06,0.36)
text(main.Results.Reason,"LAST TEAM STANDING",18)
main.Results.Rewards.Position=UDim2.fromScale(0.05,0.64)
gui:SetAttribute("GameTitle","Laser Tag")
main.Visible=false

