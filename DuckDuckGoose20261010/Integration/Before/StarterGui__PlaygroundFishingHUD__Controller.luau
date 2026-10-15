local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local gui = script.Parent
local desktop = gui:WaitForChild("DesktopDock")
local compact = gui:WaitForChild("CompactDock")
local portrait = gui:WaitForChild("PortraitDock")
local round = gui:WaitForChild("RoundDock")
local docks = { desktop, compact, portrait, round }
local connections = {}
local attributes = { Coins = "PCFishingCoinsExpires", XP = "PCFishingXPExpires" }

local function remaining(expires, now)
	if typeof(expires) ~= "number" or expires ~= expires or math.abs(expires) == math.huge then return 0 end
	return math.max(0, math.ceil(expires - now))
end

local function formatTime(seconds)
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function modalOpen(playerGui)
	local panels = {
		PlaygroundShell = { "ShopPanel", "VotePanel", "CompactVotePanel" },
		PlaygroundEmoteWheel = { "Panel" },
		PlaygroundDonations = { "Panel" },
		PlaygroundAdminPanel = { "Panel", "CompactPanel", "AdminHub" },
		PlaygroundSessionControls = { "Dock" },
		MudHUD = { "ColourPicker" },
	}
	for name, children in pairs(panels) do
		local screen = playerGui:FindFirstChild(name)
		if screen and screen.Enabled then
			for _, child in ipairs(children) do
				local panel = screen:FindFirstChild(child)
				if panel and panel.Visible then return true end
			end
		end
	end
	return false
end

local function refresh()
	local playerGui = gui.Parent
	local session = playerGui:FindFirstChild("PlaygroundSessionControls")
	local hidden = session and (session:GetAttribute("UIHidden") == true
		or session:GetAttribute("Spectating") == true or session:GetAttribute("SessionMenuOpen") == true)
	hidden = hidden or modalOpen(playerGui)
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280,720)
	local short = math.min(viewport.X,viewport.Y)
	local isCompact = viewport.X <= 900 or short <= 600
		or (short <= 1024 and math.max(viewport.X,viewport.Y) <= 1400)
	local participating = player:GetAttribute("BBParticipating") == true
		or player:GetAttribute("TGParticipating") == true or ( player:GetAttribute("MDParticipating") == true or player:GetAttribute("HSParticipating") == true )
	local selected = not isCompact and desktop or participating and round
		or viewport.Y > viewport.X and portrait or compact
	for _, dock in docks do dock.Visible = not hidden and dock == selected end
	local now = workspace:GetServerTimeNow()
	for name, attribute in pairs(attributes) do
		local seconds = remaining(player:GetAttribute(attribute),now)
		for _, dock in docks do
			local row = dock[name]
			row.Visible = seconds > 0
			row.Timer.Text = formatTime(seconds)
		end
	end
end

for _, attribute in pairs(attributes) do
	table.insert(connections,player:GetAttributeChangedSignal(attribute):Connect(refresh))
end
for _, attribute in ipairs({ "BBParticipating", "TGParticipating", "MDParticipating", "HSParticipating" }) do
	table.insert(connections,player:GetAttributeChangedSignal(attribute):Connect(refresh))
end
local elapsed = 0
table.insert(connections,RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed >= 0.25 then elapsed = 0 refresh() end
end))
script.Destroying:Connect(function()
	for _, connection in connections do connection:Disconnect() end
end)
refresh()
