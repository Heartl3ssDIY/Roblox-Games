local gui=game.StarterGui.GBloxAdminPanel
local panel=gui.Panel
assert(not gui:FindFirstChild("GiveawayPanel"))
assert(not panel:FindFirstChild("GiveawayChecker"))
local originalSize=panel.Size
local opener=panel.GiveTargetCash:Clone()
opener.Name="GiveawayChecker"
opener.Text="CHECK 10+ WINS"
opener.Position=UDim2.fromOffset(0,594)
opener.Size=UDim2.new(1,-5,0,38)
opener.Parent=panel
panel.Size=UDim2.fromOffset(originalSize.X.Offset,660)

local checker=panel:Clone()
checker.Name="GiveawayPanel"
for _,x in checker:GetChildren() do if x:IsA("GuiObject") then x:Destroy() end end
checker.Size=UDim2.fromOffset(550,620)
checker.Visible=false
checker.Parent=gui
local function label(name,text,position,size)
 local x=panel.Equipped:Clone()
 x.Name=name
 x.Text=text
 x.Position=position
 x.Size=size
 x.TextWrapped=true
 x.Parent=checker
 return x
end
local title=panel.Title:Clone()
title.Text="10+ WIN CHECKER"
title.Size=UDim2.new(1,-44,0,34)
title.Parent=checker
local close=panel.Close:Clone()
close.Parent=checker
label("Info","Saved wins across the whole game, including offline players. Community membership must be checked separately.",UDim2.fromOffset(0,44),UDim2.new(1,0,0,42)).TextSize=13
local function button(name,text,position,size)
 local x=panel.GiveTargetCash:Clone()
 x.Name=name
 x.Text=text
 x.Position=position
 x.Size=size
 x.Parent=checker
 return x
end
button("Refresh","REFRESH",UDim2.fromOffset(0,94),UDim2.new(.48,0,0,38))
button("Next","NEXT PAGE",UDim2.new(.52,0,0,94),UDim2.new(.48,0,0,38))
local status=label("Status","Refresh to load players with 10 or more saved wins.",UDim2.fromOffset(0,142),UDim2.new(1,0,0,36))
status.TextSize=13
status.TextColor3=Color3.fromRGB(104,244,255)
local list=Instance.new("ScrollingFrame")
list.Name="Rows"
list.BackgroundTransparency=1
list.Position=UDim2.fromOffset(0,184)
list.Size=UDim2.new(1,0,1,-314)
list.CanvasSize=UDim2.new()
list.AutomaticCanvasSize=Enum.AutomaticSize.Y
list.ScrollBarThickness=6
list.ScrollBarImageColor3=Color3.fromRGB(0,220,230)
list.ScrollingDirection=Enum.ScrollingDirection.Y
list.ZIndex=7
list.Parent=checker
local layout=Instance.new("UIListLayout")
layout.SortOrder=Enum.SortOrder.LayoutOrder
layout.Padding=UDim.new(0,6)
layout.Parent=list
local selected=panel.TargetPlayer:Clone()
selected.Name="SelectedPlayer"
selected.Position=UDim2.new(0,0,1,-116)
selected.AnchorPoint=Vector2.zero
selected.Size=UDim2.new(1,0,0,40)
selected.Text="Select a row to see its username and user ID."
selected.TextEditable=false
selected.TextSize=13
selected.Parent=checker
button("Back","BACK TO ADMIN",UDim2.new(0,0,1,-68),UDim2.new(1,0,0,38))
label("Pagination","PAGE 0  •  0 PLAYERS SHOWN",UDim2.new(0,0,1,-24),UDim2.new(1,0,0,24)).TextSize=12

local row=Instance.new("TextButton")
row.Name="RowTemplate"
row.BackgroundColor3=Color3.fromRGB(7,47,63)
row.BackgroundTransparency=.15
row.Text=""
row.Size=UDim2.new(1,-12,0,64)
row.Visible=false
row.ZIndex=8
row.Parent=checker
local corner=Instance.new("UICorner")
corner.CornerRadius=UDim.new(0,8)
corner.Parent=row
local function rowLabel(name,position,size,anchor,font,textSize,color)
 local x=Instance.new("TextLabel")
 x.Name=name
 x.BackgroundTransparency=1
 x.Position=position
 x.Size=size
 x.AnchorPoint=anchor
 x.TextXAlignment=Enum.TextXAlignment.Left
 x.Font=font
 x.TextSize=textSize
 x.TextColor3=color
 x.TextTruncate=Enum.TextTruncate.AtEnd
 x.ZIndex=9
 x.Parent=row
 return x
end
rowLabel("Username",UDim2.fromOffset(12,8),UDim2.new(1,-112,0,24),Vector2.zero,Enum.Font.GothamBold,16,Color3.new(1,1,1))
local wins=rowLabel("Wins",UDim2.new(1,-12,0,8),UDim2.fromOffset(92,24),Vector2.new(1,0),Enum.Font.Arcade,13,Color3.fromRGB(104,244,255))
wins.TextXAlignment=Enum.TextXAlignment.Right
rowLabel("Identity",UDim2.fromOffset(12,36),UDim2.new(1,-24,0,20),Vector2.zero,Enum.Font.GothamMedium,12,Color3.fromRGB(173,206,217))
return {opener=opener,checker=checker,originalSize=originalSize}
