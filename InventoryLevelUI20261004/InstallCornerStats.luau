assert(not game:GetService("RunService"):IsRunning(), "Keep Play stopped")
local storage=game.ServerStorage
local backup=storage:FindFirstChild("InventoryLevelUIBackup20261004")
if not backup then backup=Instance.new("Folder") backup.Name="InventoryLevelUIBackup20261004" backup.Parent=storage end
local gui=game.StarterGui.PlaygroundShell
local wallet=gui.Wallet
if not backup:FindFirstChild("Wallet")then wallet:Clone().Parent=backup end
wallet.AnchorPoint=Vector2.new(1,0)
wallet.Position=UDim2.new(1,-18,0,14)
wallet.Size=UDim2.new(.26,0,0,64)
wallet.SizeLimit.MinSize=Vector2.new(180,64)
wallet.SizeLimit.MaxSize=Vector2.new(300,64)
wallet.Coin.Visible=false
local ink=Color3.fromRGB(27,45,61)
local white=Color3.fromRGB(255,249,224)
local specs={{"Wins","WINS","0"},{"Level","LEVEL","1"},{"Coins","COINS","..."}}
for index,spec in ipairs(specs)do
 local value=wallet:FindFirstChild(spec[1])
 if not value then value=wallet.Wins:Clone() value.Name=spec[1] value.Parent=wallet end
 value.AnchorPoint=Vector2.zero
 value.Position=UDim2.new((index-1)/3,6,0,25)
 value.Size=UDim2.new(1/3,-12,0,28)
 value.BackgroundTransparency=1
 value.Text=spec[3]
 value.TextWrapped=false
 value.TextScaled=true
 value.TextSize=25
 value.TextXAlignment=Enum.TextXAlignment.Center
 value.TextYAlignment=Enum.TextYAlignment.Center
 value.TextColor3=spec[1]=="Coins" and Color3.fromRGB(255,222,98) or white
 value.Font=Enum.Font.FredokaOne
 value.Visible=true
 local cap=value:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
 cap.Name="TextSizeLimit" cap.MinTextSize=8 cap.MaxTextSize=25 cap.Parent=value
 local stroke=value:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
 stroke.Name="TextOutline" stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual stroke.BorderStrokePosition=Enum.BorderStrokePosition.Outer stroke.StrokeSizingMode=Enum.StrokeSizingMode.FixedSize stroke.Color=ink stroke.Thickness=1.7 stroke.Parent=value
 local label=wallet:FindFirstChild(spec[1].."Caption") or Instance.new("TextLabel")
 label.Name=spec[1].."Caption"
 label.Position=UDim2.new((index-1)/3,6,0,9)
 label.Size=UDim2.new(1/3,-12,0,15)
 label.BackgroundTransparency=1 label.Text=spec[2]
 label.TextColor3=white label.Font=Enum.Font.FredokaOne label.TextSize=12 label.TextScaled=true
 label.ZIndex=value.ZIndex label.Parent=wallet
 local limit=label:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
 limit.Name="TextSizeLimit" limit.MinTextSize=9 limit.MaxTextSize=12 limit.Parent=label
 local textStroke=label:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
 textStroke.Name="TextOutline" textStroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual textStroke.BorderStrokePosition=Enum.BorderStrokePosition.Outer textStroke.StrokeSizingMode=Enum.StrokeSizingMode.FixedSize textStroke.Color=ink textStroke.Thickness=1.2 textStroke.Parent=label
end
return {path=wallet:GetFullName(),stats={"Wins","Level","Coins"},minWidth=180,maxWidth=300,authoredLayout=true,playStarted=false}
