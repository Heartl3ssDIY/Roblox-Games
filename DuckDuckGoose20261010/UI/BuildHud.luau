assert(not game:GetService("RunService"):IsRunning(), "Stop Play before installing the new HUD")
assert(game.PlaceId == 95034648955135, "Wrong experience")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
assert(not StarterGui:FindFirstChild("DuckDuckGooseHUD"), "Duck Duck Goose HUD already exists")
local gui = StarterGui.HideAndSeekHUD:Clone()
gui.Name = "DuckDuckGooseHUD"
gui:SetAttribute("GameId", "DuckDuckGoose")
gui:SetAttribute("EditableGameHUD", true)
gui:SetAttribute("UIAuthoringVersion", "20261010")
gui.Controller.Enabled = false
gui.SeekerBlindfold:Destroy()
local choose = gui.LeaveLocker
choose.Name = "ChooseGoose"
choose.Text = ""
choose.Caption.Text = "GOOSE!"
choose.Hint.Text = "CHOOSE NEARBY"
choose.Size = UDim2.fromOffset(100, 44)
choose.Position = UDim2.new(1, -24, 1, -192)
choose.Visible = false
choose:SetAttribute("MobileBatAction", nil)
for _, header in {gui.DesktopHeader, gui.CompactHeader, gui.PortraitHeader} do
	header.Title.Text = "DUCK DUCK GOOSE"
	header.Role.Text = "DUCK"
	header.Timer.Text = "3:00"
	header.Counts.Text = "16 still in"
	header.Hint.Text = "Stay seated until you are chosen"
	header.Visible = false
end
for _, button in {gui.DesktopSprint, gui.MobileSprint} do
	button.StaminaText.Text = "5.0 / 5"
	button.Visible = false
	local fallback = Instance.new("Frame")
	fallback.Name = "ArtFallback"
	fallback.Size = UDim2.fromScale(1, 1)
	fallback.BackgroundColor3 = Color3.fromRGB(39, 169, 227)
	fallback.BorderSizePixel = 0
	fallback.ZIndex = 1
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = fallback
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.fromRGB(24, 35, 62)
	outline.Thickness = 2
	outline.Parent = fallback
	fallback.Visible = false
	fallback.Parent = button
end
for _, item in gui:GetDescendants() do
	if item:IsA("ImageLabel") then item:SetAttribute("UISkinTargetPath", nil) end
end
for _, name in {"DuckDuckGooseSprintRequest", "DuckDuckGooseActionRequest"} do
	local existing = ReplicatedStorage:FindFirstChild(name)
	assert(not existing or existing:IsA("RemoteEvent"), "Invalid game remote")
	if not existing then
		local remote = Instance.new("RemoteEvent")
		remote.Name, remote.Parent = name, ReplicatedStorage
	end
end
if not ReplicatedStorage:FindFirstChild("DuckDuckGooseState") then
	local state = Instance.new("Folder")
	state.Name = "DuckDuckGooseState"
	state:SetAttribute("Phase", "Waiting")
	state:SetAttribute("TurnPhase", "Choosing")
	state:SetAttribute("AliveCount", 0)
	state:SetAttribute("ParticipantCount", 0)
	state.Parent = ReplicatedStorage
end
gui.Parent = StarterGui
return {hud = gui:GetFullName(), authoredHeaders = 3, mobileSprint = "RightAboveJump"}
