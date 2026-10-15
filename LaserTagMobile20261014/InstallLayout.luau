assert(not game:GetService("RunService"):IsRunning(),"Stop Play before editing HUD.")
local gui=game.StarterGui.MudHUD
local main=gui.Main
local backup=Instance.new("Folder")
backup.Name="LaserTagMobileLayoutBackup20261014"
main:Clone().Parent=backup
backup.Parent=game.ServerStorage
local function label(l, text, maximum)
 l.Text=text l.TextScaled=true l.TextWrapped=false
 local limit=l:FindFirstChildWhichIsA("UITextSizeConstraint")
 if limit then limit.MinTextSize=9 limit.MaxTextSize=maximum end
end
local shoot=main.Controls.Fire
shoot.Position=UDim2.new(1,-18,0.88,-166)
shoot.Size=UDim2.fromOffset(104,54)
shoot.AnchorPoint=Vector2.new(1,1)
shoot.Text="SHOOT"
shoot:SetAttribute("ActionLabel","Shoot")
shoot.Modal=false
shoot.Active=true
shoot.Selectable=true
shoot.LiveCaption.Position=UDim2.fromScale(0.1,0.16)
shoot.LiveCaption.Size=UDim2.fromScale(0.8,0.64)
label(shoot.LiveCaption,"SHOOT",21)
local sprint=main.MobileSprint
sprint.Position=UDim2.new(1,-18,0.88,-110)
sprint.Size=UDim2.fromOffset(104,48)
sprint.AnchorPoint=Vector2.new(1,1)
sprint.Modal=false
sprint.LiveCaption.Position=UDim2.fromScale(0.09,0.12)
sprint.LiveCaption.Size=UDim2.fromScale(0.82,0.72)
sprint.LiveCaption.TextWrapped=true
local limit=sprint.LiveCaption:FindFirstChildWhichIsA("UITextSizeConstraint")
if limit then limit.MinTextSize=10 limit.MaxTextSize=16 end
for _,header in {main.CompactTop,main.PortraitTop} do
 header.Size=UDim2.fromOffset(260,66)
 header.Position=UDim2.new(0.5,0,0,52)
 header.Title.Position=UDim2.fromOffset(8,3)
 header.Title.Size=UDim2.new(1,-16,0,16)
 label(header.Title,"LASER TAG",15)
 header.Team.Position=UDim2.fromOffset(8,22)
 header.Team.Size=UDim2.fromOffset(72,24)
 header.Team.LiveCaption.TextWrapped=true
 header.Team.LiveCaption:FindFirstChildWhichIsA("UITextSizeConstraint").MaxTextSize=11
 header.Other.Position=UDim2.fromOffset(180,22)
 header.Other.Size=UDim2.fromOffset(72,24)
 header.Other.TextWrapped=true
 header.Other:FindFirstChildWhichIsA("UITextSizeConstraint").MaxTextSize=11
 header.Timer.Position=UDim2.fromOffset(86,20)
 header.Timer.Size=UDim2.fromOffset(88,26)
 label(header.Timer,"5:00",24)
 header.Lives.Position=UDim2.new(0.5,0,0,45)
 header.Lives.Size=UDim2.fromOffset(130,17)
 header.Lives.Team.Position=UDim2.fromOffset(0,1)
 header.Lives.Team.Size=UDim2.fromOffset(40,14)
 for i=1,3 do
  local heart=header.Lives["Heart"..i]
  heart.Position=UDim2.fromOffset(46+(i-1)*26,0)
  heart.Size=UDim2.fromOffset(24,17)
  heart:FindFirstChildWhichIsA("UITextSizeConstraint").MaxTextSize=17
 end
 header.Out.Position=UDim2.fromOffset(8,47)
 header.Out.Size=UDim2.new(1,-16,0,16)
 header.Out:FindFirstChildWhichIsA("UITextSizeConstraint").MaxTextSize=11
end
local crosshair=main.Crosshair
crosshair.Size=UDim2.fromOffset(20,20)
crosshair.Position=UDim2.fromScale(0.5,0.5)
crosshair.ZIndex=30
crosshair.Active=false
crosshair.Horizontal.Size=UDim2.fromOffset(20,2)
crosshair.Horizontal.Position=UDim2.fromOffset(0,9)
crosshair.Vertical.Size=UDim2.fromOffset(2,20)
crosshair.Vertical.Position=UDim2.fromOffset(9,0)
for _,bar in {crosshair.Horizontal,crosshair.Vertical} do
 bar.BackgroundColor3=Color3.new(1,1,1)
 bar.BorderSizePixel=0 bar.Active=false bar.ZIndex=31
 local stroke=bar:FindFirstChild("AimOutline") or Instance.new("UIStroke")
 stroke.Name="AimOutline" stroke.Color=Color3.fromRGB(18,24,37) stroke.Thickness=1.2
 stroke.Parent=bar
end
gui:SetAttribute("MobileAimRevision","20261014")
return {backup=backup:GetFullName(),shoot=shoot:GetFullName(),shootLabel=shoot.LiveCaption.Text}

