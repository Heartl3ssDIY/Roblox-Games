local Players = game:GetService("Players")
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
		or player:GetAttribute("PCPushed") == true or player:GetAttribute("HSParticipating") == true
		or player:GetAttribute("DGParticipating") == true or player:GetAttribute("DGEliminated") == true then return nil end
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
