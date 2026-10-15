local gui=game.StarterGui.ArenaSelectGui
local board=gui.Board
assert(not board:FindFirstChild("Teleport") and not gui:FindFirstChild("ReturnToLobby"),"Buttons already exist")
local function style(b)
 b.BackgroundColor3=Color3.fromRGB(60,24,101);b.BorderSizePixel=0;b.TextColor3=Color3.fromRGB(255,233,143)
 b.FontFace=board.Title.FontFace;b.TextSize=28;b.AutoButtonColor=true;b.Visible=false
 local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,12);corner.Parent=b
 local stroke=Instance.new("UIStroke");stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;stroke.Thickness=3;stroke.Color=Color3.fromRGB(206,164,70);stroke.Parent=b
 b.BackgroundColor3=Color3.fromRGB(71,31,120);b.TextColor3=Color3.fromRGB(255,235,144);b.TextStrokeTransparency=.2;b.TextStrokeColor3=Color3.fromRGB(26,14,38)
end
local teleport=Instance.new("TextButton");teleport.Name="Teleport";teleport.Text="TELEPORT";teleport.Position=board.Action.Position;teleport.Size=board.Action.Size;teleport.AnchorPoint=board.Action.AnchorPoint;teleport.ZIndex=board.Action.ZIndex;style(teleport);teleport.Parent=board
local back=Instance.new("TextButton");back.Name="ReturnToLobby";back.Text="RETURN TO LOBBY";back.Position=UDim2.new(.5,0,1,-32);back.AnchorPoint=Vector2.new(.5,1);back.Size=UDim2.fromOffset(280,58);back.ZIndex=50;style(back);back.TextSize=22;back.Parent=gui
return "Created editable Teleport and Return buttons"