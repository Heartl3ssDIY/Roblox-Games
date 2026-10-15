local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local gui = script.Parent
local state = ReplicatedStorage:WaitForChild("HideAndSeekState")
local sprintRemote = ReplicatedStorage:WaitForChild("HideAndSeekSprintRequest")
local actionRemote = ReplicatedStorage:WaitForChild("HideAndSeekActionRequest")
local headers = { gui.DesktopHeader, gui.CompactHeader, gui.PortraitHeader }
local sprintButtons = { gui.DesktopSprint, gui.MobileSprint }
local connections = {}
local sprintRequested = false
local keysHeld = {}
local touchHeld = {}
local focused = true
local elapsed = 0
local nextLockerExit = 0
local function clock(seconds)
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end
local function canSprint()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local phase = state:GetAttribute("Phase")
	return focused and not GuiService.MenuIsOpen and not UserInputService:GetFocusedTextBox()
		and gui.Enabled and player:GetAttribute("HSParticipating") == true
		and (phase == "Hiding" or phase == "Seeking") and player:GetAttribute("HSHiding") ~= true
		and not (phase == "Hiding" and player:GetAttribute("HSRole") == "Seeker")
		and player:GetAttribute("HSRagdolled") ~= true and humanoid and humanoid.Health > 0
end
local function requestSprint(value)
	value = value == true and canSprint() == true
	if value == sprintRequested then return end
	sprintRequested = value
	sprintRemote:FireServer(value)
end
local function clearInputs()
	table.clear(keysHeld)
	table.clear(touchHeld)
	requestSprint(false)
end
local function leaveLocker()
	if not focused or GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox()
		or player:GetAttribute("HSParticipating") ~= true or player:GetAttribute("HSHiding") ~= true
		or os.clock() < nextLockerExit then return end
	nextLockerExit = os.clock() + 0.3
	actionRemote:FireServer("LeaveLocker")
end
local function refresh()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local short = math.min(viewport.X, viewport.Y)
	local compact = viewport.X <= 900 or short <= 600 or (short <= 1024 and math.max(viewport.X, viewport.Y) <= 1400)
	local selectedHeader = not compact and gui.DesktopHeader or viewport.Y > viewport.X and gui.PortraitHeader or gui.CompactHeader
	local session = gui.Parent:FindFirstChild("PlaygroundSessionControls")
	local muted = session and (session:GetAttribute("UIHidden") == true or session:GetAttribute("SessionMenuOpen") == true)
	local participating = player:GetAttribute("HSParticipating") == true
	local roundState = ReplicatedStorage:FindFirstChild("PlaygroundState")
	local watching = session and session:GetAttribute("Spectating") == true and roundState and roundState:GetAttribute("ActiveGame") == "HideAndSeek"
	local shown = (participating or watching) and not muted
	local phase = state:GetAttribute("Phase")
	local role = player:GetAttribute("HSRole")
	local now = workspace:GetServerTimeNow()
	local ending = phase == "Hiding" and state:GetAttribute("HidingEndsAt") or state:GetAttribute("EndsAt")
	local seconds = typeof(ending) == "number" and ending == ending and math.abs(ending) ~= math.huge and math.max(0, math.ceil(ending - now)) or 0
	local blindfold = participating and role == "Seeker" and phase == "Hiding"
	gui.SeekerBlindfold.Visible = blindfold
	gui.SeekerBlindfold.WaitingCard.Countdown.Text = clock(seconds)
	local instruction = "Find a hiding spot!"
	if phase == "Countdown" then instruction = "Get ready!"
	elseif phase == "Hiding" then instruction = role == "Seeker" and "Wait while players hide" or "Hide before the seeker is released"
	elseif phase == "Seeking" then instruction = role == "Seeker" and "Swing your bat to find hiders" or "Stay hidden or run from seekers"
	elseif phase == "Results" then instruction = state:GetAttribute("WinnersText") or "Round finished" end
	if player:GetAttribute("HSHiding") == true then instruction = "Hiding in a locker • Leave to run" end
	for _, header in headers do
		header.Visible = shown and not blindfold and header == selectedHeader
		header.Title.Text = phase == "Results" and "ROUND FINISHED" or "HIDE & SEEK"
		header.Timer.Text = phase == "Countdown" and tostring(state:GetAttribute("CountdownValue") or 3) or phase == "Results" and "" or clock(seconds)
		header.Role.Text = watching and "WATCHING" or role == "Seeker" and "SEEKER" or "HIDER"
		header.Role.TextColor3 = role == "Seeker" and Color3.fromRGB(245,83,117) or Color3.fromRGB(68,163,245)
		local hiders, seekers = state:GetAttribute("HiderCount") or 0, state:GetAttribute("SeekerCount") or 0
		header.Counts.Text = string.format("%d %s • %d %s", hiders, hiders == 1 and "hider" or "hiders", seekers, seekers == 1 and "seeker" or "seekers")
		header.Hint.Text = watching and "Watching the school round" or instruction
		header.Fallback.Visible = not header.ReusableSkin.IsLoaded
	end
	local active = canSprint() == true
	if not active then clearInputs() end
	for _, button in sprintButtons do
		button.Visible = participating and shown and (phase == "Hiding" or phase == "Seeking") and button == (UserInputService.TouchEnabled and gui.MobileSprint or gui.DesktopSprint)
		button.Active = active
		button.Selectable = not UserInputService.TouchEnabled and active
		local stamina = math.clamp((player:GetAttribute("HSStamina") or 0) / math.max(1, player:GetAttribute("HSMaxStamina") or 10), 0, 1)
		button.StaminaTrack.StaminaFill.Size = UDim2.fromScale(stamina, 1)
		button.StaminaText.Text = string.format("%.1f / 10", player:GetAttribute("HSStamina") or 0)
		button.ReusableSkin.ImageColor3 = active and Color3.new(1,1,1) or Color3.fromRGB(150,157,170)
		local fallback = button:FindFirstChild("ArtFallback") or button:FindFirstChild("Fallback")
		if fallback then fallback.Visible = not button.ReusableSkin.IsLoaded end
	end
	gui.LeaveLocker.Visible = shown and player:GetAttribute("HSHiding") == true
end
local function connect(signal, callback)
	table.insert(connections, signal:Connect(callback))
end
for _, button in sprintButtons do
	connect(button.InputBegan, function(input)
		if not button.Visible or not button.Active then return end
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			touchHeld[input] = true
			requestSprint(true)
		end
	end)
end
connect(UserInputService.InputEnded, function(input)
	if touchHeld[input] then touchHeld[input] = nil requestSprint(next(touchHeld) ~= nil or next(keysHeld) ~= nil) end
end)
connect(UserInputService.WindowFocusReleased, function() focused = false clearInputs() end)
connect(UserInputService.WindowFocused, function() focused = true refresh() end)
connect(gui.LeaveLocker.Activated, leaveLocker)
ContextActionService:BindAction("HideAndSeekSprint", function(_, inputState, input)
	if player:GetAttribute("HSParticipating") ~= true then return Enum.ContextActionResult.Pass end
	if inputState == Enum.UserInputState.Begin then keysHeld[input.KeyCode] = true requestSprint(true)
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then keysHeld[input.KeyCode] = nil requestSprint(next(keysHeld) ~= nil or next(touchHeld) ~= nil) end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL3)
ContextActionService:BindAction("HideAndSeekLeaveLocker", function(_, inputState)
	if player:GetAttribute("HSHiding") ~= true then return Enum.ContextActionResult.Pass end
	if inputState == Enum.UserInputState.Begin then leaveLocker() end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.E, Enum.KeyCode.ButtonY)
connect(state.AttributeChanged, refresh)
for _, name in { "HSParticipating", "HSRole", "HSHiding", "HSRagdolled", "HSStamina", "HSMaxStamina" } do connect(player:GetAttributeChangedSignal(name), refresh) end
connect(player.CharacterRemoving, clearInputs)
connect(RunService.Heartbeat, function(delta)
	elapsed += delta
	if elapsed >= 0.1 then elapsed = 0 refresh() end
end)
connect(script.Destroying, function()
	clearInputs()
	ContextActionService:UnbindAction("HideAndSeekSprint")
	ContextActionService:UnbindAction("HideAndSeekLeaveLocker")
	for _, connection in connections do connection:Disconnect() end
end)
refresh()

