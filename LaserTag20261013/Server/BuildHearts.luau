assert(not game:GetService("RunService"):IsRunning(),"Stop Play first")
local assets=game.ReplicatedStorage:FindFirstChild("MudAssets")
assert(assets,"MudAssets missing")
local existing=assets:FindFirstChild("LaserLivesTemplate")
if existing then assert(existing:IsA("BillboardGui"),"Conflicting lives template") return "Lives template already exists" end
local gui=Instance.new("BillboardGui") gui.Name="LaserLivesTemplate"
gui.Size=UDim2.fromOffset(104,48) gui.StudsOffsetWorldSpace=Vector3.new(0,2.5,0)
gui.AlwaysOnTop=false gui.MaxDistance=120 gui.Enabled=false gui.LightInfluence=0
local team=Instance.new("TextLabel")team.Name="TeamName"team.Size=UDim2.new(1,0,0,18)
team.BackgroundTransparency=1 team.Font=Enum.Font.GothamBold team.TextSize=13
team.Text="RED" team.TextColor3=Color3.fromRGB(255,66,85)team.TextStrokeColor3=Color3.fromRGB(10,12,23)team.TextStrokeTransparency=0.15 team.Parent=gui
for i=1,3 do local heart=Instance.new("TextLabel")heart.Name="Heart"..i
 heart.BackgroundTransparency=1 heart.Position=UDim2.fromOffset(3+(i-1)*33,17) heart.Size=UDim2.fromOffset(32,30)
 heart.Font=Enum.Font.GothamBold heart.Text="♥" heart.TextSize=27
 heart.TextColor3=Color3.fromRGB(255,82,97)heart.TextStrokeColor3=Color3.fromRGB(10,12,23)heart.TextStrokeTransparency=0.1 heart.Parent=gui end
gui.Parent=assets
return "Editable LaserLivesTemplate created"