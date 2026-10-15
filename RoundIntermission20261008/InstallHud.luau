assert(not game:GetService("RunService"):IsRunning(),"Edit only")
assert(game.PlaceId==95034648955135,"Wrong place")
assert(not game.StarterGui:FindFirstChild("PlaygroundIntermissionHUD"),"Timer already exists")
local gui
local ok, problem = pcall(function()
	gui = (function()
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

	end)()
	local controller = Instance.new("LocalScript")
	controller.Name = "Controller"
	controller.Sandboxed = true
	controller.Capabilities = SecurityCapabilities.new(Enum.SecurityCapability.RunClientScript,
		Enum.SecurityCapability.AccessOutsideWrite,Enum.SecurityCapability.Basic,
		Enum.SecurityCapability.UI,Enum.SecurityCapability.Physics,Enum.SecurityCapability.Players)
	controller.Source = [====[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local gui = script.Parent
local state = ReplicatedStorage:WaitForChild("PlaygroundState")
local connections = {}
local elapsed = 0

local function render()
	local phase = state:GetAttribute("Phase")
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280,720)
	local compact = viewport.X < 900 or viewport.Y < 600
	local participating = player:GetAttribute("BBParticipating") == true
		or player:GetAttribute("TGParticipating") == true or player:GetAttribute("MDParticipating") == true
	local shown = not participating and phase ~= "Playing"
	local shell = gui.Parent:FindFirstChild("PlaygroundShell")
	local toast = shell and shell:FindFirstChild("RewardToast")
	local backdrop = shell and shell:FindFirstChild("Backdrop")
	local session = gui.Parent:FindFirstChild("PlaygroundSessionControls")
	if backdrop and backdrop.Visible then shown = false end
	if session and (session:GetAttribute("UIHidden") == true or session:GetAttribute("SessionMenuOpen") == true) then shown = false end
	if compact and toast and toast.Visible then shown = false end
	local title, timer, detail = "NEXT ROUND", "", "Preparing the lobby..."
	local status = state:GetAttribute("IntermissionStatus")
	if phase == "Voting" then
		local endsAt = state:GetAttribute("VotingEndsAt")
		if typeof(endsAt) == "number" and endsAt == endsAt and math.abs(endsAt) < math.huge then
			local seconds = math.max(0,math.ceil(endsAt-workspace:GetServerTimeNow()))
			timer = string.format("%d:%02d",math.floor(seconds/60),seconds%60)
		end
		title = "INTERMISSION"
		detail = status == "Next round starts in" and "Vote for the next game!" or status or "Vote for the next game!"
	elseif phase == "Paused" then
		title, detail = "ROUNDS PAUSED", "Automatic rounds paused by an admin"
	elseif phase == "Waiting" then
		title = "WAITING FOR PLAYERS"
		local count = state:GetAttribute("ReadyPlayerCount") or 0
		local minimum = state:GetAttribute("MinimumReadyPlayers") or 2
		detail = typeof(status) == "string" and status ~= "" and status or string.format("%d / %d players ready",count,minimum)
	end
	for _,card in {gui.Desktop,gui.Compact} do
		card.Visible = shown and (card == gui.Compact) == compact
		card.Title.Text = card == gui.Compact and phase == "Waiting" and "WAITING" or title
		card.Timer.Text, card.Detail.Text = timer, detail
		card.Fallback.Visible = not card.ReusableSkin.IsLoaded
	end
end

table.insert(connections,state.AttributeChanged:Connect(render))
table.insert(connections,player.AttributeChanged:Connect(render))
table.insert(connections,RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed >= 0.1 then elapsed=0 render() end
end))
table.insert(connections,script.Destroying:Connect(function()
	for _,connection in connections do connection:Disconnect() end
end))
render()
]====]
	controller.Parent = gui
end)
if not ok then
	if gui then gui:Destroy() end
	error(problem)
end
return game:GetService("HttpService"):JSONEncode({installed=gui:GetFullName(),controller=gui.Controller:GetFullName(),capabilities=tostring(gui.Controller.Capabilities)})
