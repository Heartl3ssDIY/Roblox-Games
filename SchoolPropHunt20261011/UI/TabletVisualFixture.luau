assert(not game:GetService("RunService"):IsRunning())
local old=game.StarterGui:FindFirstChild("UIPlacementPreview20261011") if old then old:Destroy() end
local width,height=1024,768
local left,right,top,bottom=0,0,58,20
local gui=Instance.new("ScreenGui") gui.Name="UIPlacementPreview20261011" gui.IgnoreGuiInset=true gui.DisplayOrder=1000 gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
local background=Instance.new("Frame") background.Name="Canvas" background.BackgroundColor3=Color3.fromRGB(112,144,126) background.Size=UDim2.fromScale(1,1) background.Parent=gui
local frame=Instance.new("Frame") frame.Name="Device" frame.BackgroundTransparency=1 frame.Size=UDim2.fromOffset(width,height) frame.Position=UDim2.fromScale(.5,.5) frame.AnchorPoint=Vector2.new(.5,.5) frame.Parent=background
local scale=Instance.new("UIScale") scale.Scale=.96 scale.Parent=frame
local panels={PlaygroundShell={"CompactLevelPanel","Wallet","CompactDock"},PlaygroundIntermissionHUD={"Compact"},PlaygroundSessionControls={"CompactToggle","CompactSpectate"},PlaygroundEmoteWheel={"CompactEmoteToggle"}}
for screen,names in panels do
 local original=game.StarterGui[screen]
 local f=Instance.new("Frame") f.Name=screen f.BackgroundTransparency=1 f.Position=UDim2.fromOffset(left,top) f.Size=UDim2.fromOffset(width-left-right,height-top-bottom) f.ZIndex=original.DisplayOrder f.Parent=frame
 for _,name in names do local c=original[name]:Clone() c.Visible=true
  for _,d in c:GetDescendants() do if d:IsA("LuaSourceContainer") then d:Destroy() elseif d:IsA("UIScale") and d.Name=="ResponsiveHudScale" then d.Scale=d:GetAttribute("TabletScale") or 1 end end
  c.Parent=f
 end
end
frame.PlaygroundIntermissionHUD.Compact.Title.Text="WAITING"
frame.PlaygroundIntermissionHUD.Compact.Timer.Text=""
frame.PlaygroundIntermissionHUD.Compact.Detail.Text="Players ready: 1/2"
frame.PlaygroundShell.Wallet.Coins.Text="20,935"
local function reserve(name,x,y,w,h)
 local f=Instance.new("Frame") f.Name=name f.Position=UDim2.fromOffset(x,y) f.Size=UDim2.fromOffset(w,h) f.BackgroundColor3=Color3.fromRGB(25,30,35) f.BackgroundTransparency=.45 f.ZIndex=100 f.Parent=frame
 local c=Instance.new("UICorner") c.CornerRadius=UDim.new(.5,0) c.Parent=f
 local l=Instance.new("TextLabel") l.Text=name l.TextSize=16 l.Font=Enum.Font.GothamBold l.TextColor3=Color3.new(1,1,1) l.BackgroundTransparency=1 l.Size=UDim2.fromScale(1,1) l.Parent=f
end
reserve("ROBLOX",8,8,160,44)
reserve("MOVE",8,height-bottom-120,120,120)
reserve("JUMP",width-right-130,height-bottom-128,128,128)
gui.Parent=game.StarterGui task.wait(1) return "Tablet preview ready"
