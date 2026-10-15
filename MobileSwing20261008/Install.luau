assert(not game.RunService:IsRunning(), "Edit only")
assert(game.GameId == 10769034155, "Wrong experience")
assert(not game.StarterGui:FindFirstChild("PlaygroundBatControls"), "Bat controls already exist")
local gui = Instance.new("ScreenGui")
gui.Name = "PlaygroundBatControls"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 23
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local button = Instance.new("TextButton")
button.Name = "Swing"
button.AnchorPoint = Vector2.new(1, 0.5)
button.Position = UDim2.new(1, -24, 0.5, 0)
button.Size = UDim2.fromOffset(104, 68)
button.BackgroundTransparency = 1
button.BorderSizePixel = 0
button.Text = ""
button.AutoButtonColor = false
button.Selectable = false
button.Visible = false
button.Active = false
button.ZIndex = 1
button:SetAttribute("MobileBatAction", true)
button.Parent = gui
local fallback = Instance.new("Frame")
fallback.Name = "Fallback"
fallback.Size = UDim2.fromScale(1, 1)
fallback.BackgroundColor3 = Color3.fromRGB(255, 203, 61)
fallback.BorderSizePixel = 0
fallback.ZIndex = 1
fallback.Parent = button
local corner = Instance.new("UICorner") corner.CornerRadius = UDim.new(0, 17) corner.Parent = fallback
local stroke = Instance.new("UIStroke") stroke.Color = Color3.fromRGB(24, 35, 62) stroke.Thickness = 3 stroke.Parent = fallback
local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new(Color3.fromRGB(255,239,165),Color3.fromRGB(247,182,37))
gradient.Rotation = 90 gradient.Parent = fallback
local skin = Instance.new("ImageLabel")
skin.Name = "ReusableSkin"
skin.Size = UDim2.fromScale(1, 1)
skin.BackgroundTransparency = 1
skin.Image = "rbxassetid://84589903135132"
skin.ScaleType = Enum.ScaleType.Slice
skin.SliceCenter = Rect.new(88,88,424,232)
skin.SliceScale = 0.25
skin.ZIndex = 2
skin.Parent = button
local label = Instance.new("TextLabel")
label.Name = "Caption"
label.BackgroundTransparency = 1
label.Position = UDim2.fromScale(0.08,0.08)
label.Size = UDim2.fromScale(0.84,0.56)
label.Font = Enum.Font.FredokaOne
label.Text = "SWING"
label.TextScaled = true
label.TextColor3 = Color3.fromRGB(255,249,224)
label.ZIndex = 3
label.Parent = button
local textLimit = Instance.new("UITextSizeConstraint") textLimit.MaxTextSize = 23 textLimit.MinTextSize = 14 textLimit.Parent = label
local textStroke = Instance.new("UIStroke") textStroke.Color = Color3.fromRGB(24,35,62) textStroke.Thickness = 2 textStroke.Parent = label
local hint = label:Clone()
hint.Name = "Hint"
hint.Position = UDim2.fromScale(0.08,0.62)
hint.Size = UDim2.fromScale(0.84,0.23)
hint.Text = "TAP"
hint.UITextSizeConstraint.MaxTextSize = 13
hint.UITextSizeConstraint.MinTextSize = 10
hint.UIStroke.Thickness = 1.5
hint.Parent = button
local controller = Instance.new("LocalScript")
controller.Name = "Controller"
controller.Sandboxed = true
controller.Capabilities = SecurityCapabilities.new(
 Enum.SecurityCapability.RunClientScript, Enum.SecurityCapability.Basic,
 Enum.SecurityCapability.Players, Enum.SecurityCapability.Input, Enum.SecurityCapability.UI,
 Enum.SecurityCapability.Physics, Enum.SecurityCapability.AccessOutsideWrite, Enum.SecurityCapability.AvatarBehavior)
controller.Source = [====[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local gui = script.Parent
local button = gui:WaitForChild("Swing")
local skin = button:WaitForChild("ReusableSkin")
local fallback = button:WaitForChild("Fallback")
local connections = {}
local nextTapAt = 0
local focused = true
local elapsed = 0

local function equippedBat()
	if not UserInputService.TouchEnabled or player:GetAttribute("PCDataReady") ~= true
		or player:GetAttribute("MDParticipating") == true then return nil end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or player:GetAttribute("BBRagdolled") == true
		or player:GetAttribute("TGRagdolled") == true then return nil end
	local gameId
	if player:GetAttribute("BBParticipating") == true and player:GetAttribute("BBRole") == "Bulldog" then
		local state = ReplicatedStorage:FindFirstChild("BritishBulldogState")
		if state and state:GetAttribute("Phase") == "Crossing" then gameId = "BritishBulldog" end
	elseif player:GetAttribute("TGParticipating") == true and player:GetAttribute("TGRole") == "Tagger" then
		local state = ReplicatedStorage:FindFirstChild("TagState")
		if state and state:GetAttribute("Phase") == "Playing" then gameId = "TagYoureIt" end
	end
	if not gameId then return nil end
	for _, tool in character:GetChildren() do
		if tool:IsA("Tool") and tool.Enabled and tool:GetAttribute("PCBatWeapon") == true
			and tool:GetAttribute("WeaponGame") == gameId then return tool end
	end
	return nil
end

local function remainingCooldown()
	local at = player:GetAttribute("PCBatSwingAt")
	local serverRemaining = typeof(at) == "number" and at > 0 and at + 0.75 - workspace:GetServerTimeNow() or 0
	return math.max(0, nextTapAt - os.clock(), serverRemaining)
end

local function refresh()
	local bat = equippedBat()
	button.Visible = bat ~= nil
	local ready = bat ~= nil and focused and not GuiService.MenuIsOpen
		and not UserInputService:GetFocusedTextBox() and remainingCooldown() <= 0
	button.Active = ready
	button.Selectable = false
	skin.ImageColor3 = ready and Color3.new(1, 1, 1) or Color3.fromRGB(164, 170, 184)
	button.Hint.Text = remainingCooldown() > 0 and string.format("%.1fs", remainingCooldown()) or "TAP"
	fallback.Visible = not skin.IsLoaded
end

local function swing()
	local bat = equippedBat()
	if not button.Visible or not gui.Enabled or not bat or not focused or GuiService.MenuIsOpen
		or UserInputService:GetFocusedTextBox() or remainingCooldown() > 0 then return end
	nextTapAt = os.clock() + 0.75
	local ok = pcall(function()
		bat:Activate()
		bat:Deactivate()
	end)
	if not ok then nextTapAt = 0 end
	refresh()
end

local function connect(signal, callback)
	table.insert(connections, signal:Connect(callback))
end
connect(button.Activated, swing)
connect(UserInputService.WindowFocusReleased, function() focused = false refresh() end)
connect(UserInputService.WindowFocused, function() focused = true refresh() end)
connect(UserInputService:GetPropertyChangedSignal("TouchEnabled"), refresh)
connect(player.CharacterRemoving, function() nextTapAt = 0 button.Visible = false end)
connect(player.CharacterAdded, function() nextTapAt = 0 refresh() end)
connect(RunService.Heartbeat, function(delta)
	elapsed += delta
	if elapsed >= 0.05 then elapsed = 0 refresh() end
end)
connect(script.Destroying, function()
	for _, connection in connections do connection:Disconnect() end
	button.Visible = false
end)
refresh()
]====]
controller.Parent = gui
gui.Parent = game.StarterGui
return {path=gui:GetFullName(),buttonSize=tostring(button.Size),position=tostring(button.Position),desktopHidden=true}

