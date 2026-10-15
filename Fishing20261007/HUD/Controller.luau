local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local gui = script.Parent
local desktop = gui:WaitForChild("DesktopDock")
local compact = gui:WaitForChild("CompactDock")
local connections = {}
local attributes = { Coins = "PCFishingCoinsExpires", XP = "PCFishingXPExpires" }

local function remaining(expires, now)
	if typeof(expires) ~= "number" or expires ~= expires then return 0 end
	return math.max(0, math.ceil(expires - now))
end

local function formatTime(seconds)
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function refresh()
	local playerGui = gui.Parent
	local session = playerGui:FindFirstChild("PlaygroundSessionControls")
	local hidden = session and session:GetAttribute("UIHidden") == true
	local shell = playerGui:FindFirstChild("PlaygroundShell")
	local shop = shell and shell:FindFirstChild("ShopPanel")
	local donations = playerGui:FindFirstChild("PlaygroundDonations")
	local donationPanel = donations and donations:FindFirstChild("Panel")
	hidden = hidden or (shop and shop.Visible) or (donationPanel and donationPanel.Visible)
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local isCompact = UserInputService.TouchEnabled or viewport.X < 800 or viewport.Y < 500
	compact.LayoutScale.Scale = math.clamp(math.min(viewport.X / 390, viewport.Y / 340), 0.85, 1)
	desktop.Visible = not hidden and not isCompact
	compact.Visible = not hidden and isCompact
	local now = workspace:GetServerTimeNow()
	for name, attribute in pairs(attributes) do
		local seconds = remaining(player:GetAttribute(attribute), now)
		for _, dock in { desktop, compact } do
			local row = dock[name]
			row.Visible = seconds > 0
			row.Timer.Text = formatTime(seconds)
		end
	end
end

for _, attribute in pairs(attributes) do
	table.insert(connections, player:GetAttributeChangedSignal(attribute):Connect(refresh))
end
local elapsed = 0
table.insert(connections, RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed >= 0.25 then
		elapsed = 0
		refresh()
	end
end))
script.Destroying:Connect(function()
	for _, connection in connections do connection:Disconnect() end
end)
refresh()
