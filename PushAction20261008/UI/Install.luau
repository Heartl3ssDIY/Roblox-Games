assert(not game:GetService("RunService"):IsRunning(), "Edit only")
assert(game.GameId == 10769034155, "Wrong experience")
local starterGui = game:GetService("StarterGui")
local tagPanel = assert(starterGui:FindFirstChild("TagHUD")).SprintPanel
local bulldogPanel = assert(starterGui:FindFirstChild("BritishBulldogHUD")).MovementControls
local template = assert(starterGui:FindFirstChild("PlaygroundBatControls")).Swing
assert(not starterGui:FindFirstChild("PlaygroundPushControls"), "Push UI already installed")
assert(not tagPanel:FindFirstChild("Push") and not bulldogPanel:FindFirstChild("Push"), "Push slot already occupied")
assert(not starterGui.TagHUD.Controls:FindFirstChild("Vault"), "Vault has unexpectedly returned; review before replacing")
assert(not bulldogPanel.Dodge.Visible and not starterGui.TagHUD.Controls.Dodge.Visible, "Dodge visibility changed; review first")
assert(template.ReusableSkin.Image == "rbxassetid://84589903135132", "Reusable artwork changed")
local backup = Instance.new("Folder")
backup.Name = "PushUiBackup20261008"
assert(not game.ServerStorage:FindFirstChild(backup.Name), "UI backup already exists")
for name, object in { TagSprintPanel = tagPanel, BulldogMovementControls = bulldogPanel, SwingTemplate = template } do
	local copy = object:Clone()
	copy.Name = name
	copy.Parent = backup
end
backup:SetAttribute("CreatedAt", DateTime.now().UnixTimestamp)
backup.Parent = game.ServerStorage
local gui = Instance.new("ScreenGui")
gui.Name = "PlaygroundPushControls"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 23
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = true
local made
local ok, failure = xpcall(function()
	gui.Parent = starterGui
	local build = (function()
return function(starterGui)
	local tagPanel = assert(starterGui:FindFirstChild("TagHUD")).SprintPanel
	local bulldogPanel = assert(starterGui:FindFirstChild("BritishBulldogHUD")).MovementControls
	assert(not tagPanel:FindFirstChild("Push") and not bulldogPanel:FindFirstChild("Push"), "Push buttons already exist")
	local template = assert(starterGui:FindFirstChild("PlaygroundBatControls")).Swing
	local pushGui = assert(starterGui:FindFirstChild("PlaygroundPushControls"))
	local function make(parent, position, size)
		local button = template:Clone()
		button.Name = "Push"
		button:SetAttribute("MobileBatAction", nil)
		button:SetAttribute("PlaygroundPushAction", true)
		button.AnchorPoint = Vector2.zero
		button.Position = position
		button.Size = size
		button.ZIndex = 5
		button.Fallback.ZIndex = 5
		button.ReusableSkin.ZIndex = 6
		button.Caption.ZIndex = 7
		button.Hint.ZIndex = 7
		button.Caption.Text = "PUSH"
		button.Caption.UITextSizeConstraint.MaxTextSize = 21
		button.Hint.Text = "[Q]"
		button.Visible = false
		button.Active = false
		button.Interactable = false
		button.Selectable = false
		button.Parent = parent
		return button
	end
	local mobile = make(pushGui, UDim2.new(1, -140, 0.5, 0), UDim2.fromOffset(104, 68))
	mobile.Name = "MobilePush"
	mobile.AnchorPoint = Vector2.new(1, 0.5)
	mobile.Caption.UITextSizeConstraint.MaxTextSize = 23
	return {
		Tag = make(tagPanel, UDim2.fromOffset(186, 68), UDim2.fromOffset(94, 48)),
		Bulldog = make(bulldogPanel, UDim2.new(0.56, 0, 0, 60), UDim2.new(0.25, 0, 0, 48)),
		Mobile = mobile,
	}
end

	end)()
	made = build(starterGui)
	local controller = Instance.new("LocalScript")
	controller.Name = "Controller"
	controller.Sandboxed = true
	controller.Capabilities = SecurityCapabilities.new(
		Enum.SecurityCapability.RunClientScript, Enum.SecurityCapability.Basic,
		Enum.SecurityCapability.Players, Enum.SecurityCapability.Input, Enum.SecurityCapability.UI,
		Enum.SecurityCapability.Physics, Enum.SecurityCapability.RemoteEvent, Enum.SecurityCapability.AccessOutsideWrite,
		Enum.SecurityCapability.AvatarBehavior)
	controller.Source = [======[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local gui = script.Parent
local playerGui = gui.Parent
local tagGui = playerGui:WaitForChild("TagHUD")
local bulldogGui = playerGui:WaitForChild("BritishBulldogHUD")
local buttons = {
	Tag = { gui = tagGui, button = tagGui:WaitForChild("SprintPanel"):WaitForChild("Push") },
	Bulldog = { gui = bulldogGui, button = bulldogGui:WaitForChild("MovementControls"):WaitForChild("Push") },
	Mobile = { gui = gui, button = gui:WaitForChild("MobilePush") },
}
local connections = {}
local actionName = "PlaygroundPush"
local alive, focused, bound = true, true, false
local nextTapAt, elapsed = 0, 0

local function activeGame()
	if player:GetAttribute("PCDataReady") ~= true or player:GetAttribute("MDParticipating") == true
		or player:GetAttribute("BBRagdolled") == true or player:GetAttribute("TGRagdolled") == true
		or player:GetAttribute("PCPushed") == true then return nil end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or humanoid.Sit then return nil end
	local now = workspace:GetServerTimeNow()
	if player:GetAttribute("BBParticipating") == true then
		local state = ReplicatedStorage:FindFirstChild("BritishBulldogState")
		local role = player:GetAttribute("BBRole")
		local status = player:GetAttribute("BBStatus")
		if state and state:GetAttribute("Phase") == "Crossing"
			and (role == "Runner" and status == "Crossing" or role == "Bulldog" and status == "Bulldog") then return "Bulldog" end
	elseif player:GetAttribute("TGParticipating") == true then
		local state = ReplicatedStorage:FindFirstChild("TagState")
		local role = player:GetAttribute("TGRole")
		local protected = player:GetAttribute("TGProtectedEndsAt")
		if state and state:GetAttribute("Phase") == "Playing" and (role == "Runner" or role == "Tagger")
			and (typeof(protected) ~= "number" or protected <= now) then return "Tag" end
	end
	return nil
end

local function remainingCooldown()
	local readyAt = player:GetAttribute("PCPushReadyAt")
	local serverRemaining = typeof(readyAt) == "number" and readyAt == readyAt
		and readyAt < math.huge and readyAt - workspace:GetServerTimeNow() or 0
	return math.max(0, serverRemaining, nextTapAt - os.clock())
end

local function inputHint()
	local last = UserInputService:GetLastInputType()
	if string.find(last.Name, "Gamepad", 1, true) then
		local label = UserInputService:GetStringForKeyCode(Enum.KeyCode.ButtonX)
		return (label == "ButtonSquare" or label == "Square") and "[\u{25A1}]" or "[X]"
	end
	if last == Enum.UserInputType.Touch or UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then return "TAP" end
	return "[Q]"
end

local function inputReady()
	return alive and gui.Enabled and focused and not GuiService.MenuIsOpen and not UserInputService:GetFocusedTextBox()
end

local refresh
local function push()
	local gameId = activeGame()
	local entry = gameId and (UserInputService.TouchEnabled and buttons.Mobile or buttons[gameId])
	if not entry or not entry.gui.Enabled or not entry.button.Visible or not inputReady() or remainingCooldown() > 0 then return end
	local remote = ReplicatedStorage:FindFirstChild("PlaygroundPushRequest")
	if not remote or not remote:IsA("RemoteEvent") then return end
	nextTapAt = os.clock() + 0.35
	local ok = pcall(function() remote:FireServer() end)
	if not ok then nextTapAt = 0 end
	refresh()
end

local function action(_, inputState)
	if not activeGame() or not inputReady() then return Enum.ContextActionResult.Pass end
	if inputState == Enum.UserInputState.Begin then push() end
	return Enum.ContextActionResult.Sink
end

refresh = function()
	local gameId = activeGame()
	local displayId = gameId and (UserInputService.TouchEnabled and "Mobile" or gameId)
	local remaining = remainingCooldown()
	local ready = gameId ~= nil and inputReady() and remaining <= 0
	for id, entry in pairs(buttons) do
		local button = entry.button
		button.Visible = gui.Enabled and id == displayId
		button.Active = id == displayId and ready
		button.Interactable = button.Active
		button.Selectable = button.Active
		button.Hint.Text = remaining > 0 and string.format("%.1fs", remaining) or inputHint()
		button.ReusableSkin.ImageColor3 = ready and Color3.new(1, 1, 1) or Color3.fromRGB(164, 170, 184)
		button.Fallback.Visible = not button.ReusableSkin.IsLoaded
	end
	if gameId and gui.Enabled and not bound then
		ContextActionService:BindActionAtPriority(actionName, action, false, 3000, Enum.KeyCode.Q, Enum.KeyCode.ButtonX)
		bound = true
	elseif (not gameId or not gui.Enabled) and bound then
		ContextActionService:UnbindAction(actionName)
		bound = false
	end
end

local function connect(signal, callback)
	table.insert(connections, signal:Connect(callback))
end
for _, entry in pairs(buttons) do connect(entry.button.Activated, push) end
connect(UserInputService.WindowFocusReleased, function() focused = false refresh() end)
connect(UserInputService.WindowFocused, function() focused = true refresh() end)
connect(UserInputService.LastInputTypeChanged, refresh)
connect(player.CharacterRemoving, function() nextTapAt = 0 for _, entry in pairs(buttons) do entry.button.Visible = false end end)
connect(player.CharacterAdded, function() nextTapAt = 0 refresh() end)
connect(player.AttributeChanged, refresh)
connect(gui:GetPropertyChangedSignal("Enabled"), refresh)
connect(RunService.Heartbeat, function(delta)
	elapsed += delta
	if elapsed >= 0.05 then elapsed = 0 refresh() end
end)
connect(script.Destroying, function()
	alive = false
	if bound then ContextActionService:UnbindAction(actionName) end
	for _, connection in connections do connection:Disconnect() end
	for _, entry in pairs(buttons) do entry.button.Visible = false end
end)
refresh()
]======]
	controller.Parent = gui
end, debug.traceback)
if not ok then
	for _, panel in { tagPanel, bulldogPanel } do
		local button = panel:FindFirstChild("Push")
		if button and button:GetAttribute("PlaygroundPushAction") == true then button:Destroy() end
	end
	gui:Destroy()
	error(failure)
end
return { gui=gui:GetFullName(), tag=made.Tag:GetFullName(), bulldog=made.Bulldog:GetFullName(), mobile=made.Mobile:GetFullName(), backup=backup:GetFullName() }

