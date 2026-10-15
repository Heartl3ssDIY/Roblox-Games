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
	local short = math.min(viewport.X,viewport.Y)
	local compact = viewport.X <= 900 or short <= 600
		or (short <= 1024 and math.max(viewport.X,viewport.Y) <= 1400)
	local portrait = compact and viewport.Y > viewport.X
	local participating = player:GetAttribute("BBParticipating") == true
		or player:GetAttribute("TGParticipating") == true or ( player:GetAttribute("MDParticipating") == true or player:GetAttribute("HSParticipating") == true or player:GetAttribute("DGParticipating") == true or player:GetAttribute("DGEliminated") == true or player:GetAttribute("SKParticipating") == true or player:GetAttribute("SKEliminated") == true )
	local shown = not participating and phase ~= "Playing"
	local shell = gui.Parent:FindFirstChild("PlaygroundShell")
	local toast = shell and shell:FindFirstChild("RewardToast")
	local backdrop = shell and shell:FindFirstChild("Backdrop")
	local session = gui.Parent:FindFirstChild("PlaygroundSessionControls")
	if backdrop and backdrop.Visible then shown = false end
	if session and (session:GetAttribute("UIHidden") == true or session:GetAttribute("SessionMenuOpen") == true) then shown = false end
	if compact and toast and toast.Visible then shown = false end
	for name, panels in pairs({ PlaygroundEmoteWheel = { "Panel" }, PlaygroundDonations = { "Panel" },
		PlaygroundAdminPanel = { "Panel", "CompactPanel", "AdminHub" } }) do
		local screen = gui.Parent:FindFirstChild(name)
		if screen and screen.Enabled then
			for _, name in ipairs(panels) do
				local panel = screen:FindFirstChild(name)
				if panel and panel.Visible then shown = false end
			end
		end
	end
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
	local compactDetail = detail
	if phase == "Waiting" then
		compactDetail = typeof(status) == "string" and string.find(string.lower(status),"data",1,true)
			and "Loading player data" or string.format("Players ready: %d/%d",state:GetAttribute("ReadyPlayerCount") or 0,state:GetAttribute("MinimumReadyPlayers") or 2)
	elseif phase == "Paused" then
		compactDetail = "Paused by an admin"
	elseif phase == "Voting" and status ~= nil and status ~= "Next round starts in" then
		compactDetail = "Retrying next round"
	end
	for _,card in {gui.Desktop,gui.Compact,gui.Portrait} do
		card.Visible = shown and (card == gui.Desktop and not compact
			or card == gui.Compact and compact and not portrait
			or card == gui.Portrait and portrait)
		card.Title.Text = card ~= gui.Desktop and phase == "Waiting" and "WAITING" or title
		card.Timer.Text = timer
		card.Detail.Text = card == gui.Desktop and detail or compactDetail
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
