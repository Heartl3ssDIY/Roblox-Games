local Players = game:GetService("Players")
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
