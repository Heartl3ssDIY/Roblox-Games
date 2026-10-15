local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local gui = script.Parent
local state = ReplicatedStorage:WaitForChild("DuckDuckGooseState")
local sprintRemote = ReplicatedStorage:WaitForChild("DuckDuckGooseSprintRequest")
local actionRemote = ReplicatedStorage:WaitForChild("DuckDuckGooseActionRequest")
local headers = {gui.DesktopHeader, gui.CompactHeader, gui.PortraitHeader}
local sprintButtons = {gui.DesktopSprint, gui.MobileSprint}
local connections, keysHeld, pointersHeld = {}, {}, {}
local focused, sprintRequested = true, false
local sprintContext
local elapsed, nextChoose = 0, 0
local Guidance = require(gui:WaitForChild("Guidance"))
local guidance = Guidance.Start(gui, state, player)
local function finite(value, fallback)
	return typeof(value) == "number" and value == value and math.abs(value) ~= math.huge and value or fallback
end
local function clock(seconds)
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end
local function sessionFlags()
	local session = gui.Parent:FindFirstChild("PlaygroundSessionControls")
	local muted = session and (session:GetAttribute("UIHidden") == true or session:GetAttribute("SessionMenuOpen") == true)
	local round = ReplicatedStorage:FindFirstChild("PlaygroundState")
	local watching = session and session:GetAttribute("Spectating") == true
		and round and round:GetAttribute("ActiveGame") == "DuckDuckGoose"
	return muted == true, watching == true
end
local function inputReady()
	return focused and gui.Enabled and not GuiService.MenuIsOpen and not UserInputService:GetFocusedTextBox()
end
local function canSprint()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local role = player:GetAttribute("DGRole")
	local muted, watching = sessionFlags()
	return inputReady() and not muted and not watching and player:GetAttribute("DGParticipating") == true
		and state:GetAttribute("Phase") == "Playing" and (role == "Picker" or role == "Runner" or role == "Goose")
		and player:GetAttribute("DGRagdolled") ~= true and humanoid and humanoid.Health > 0
end
local function requestSprint(value, force)
	value = value == true and canSprint() == true
	if value == sprintRequested and not force then return end
	sprintRequested = value
	sprintRemote:FireServer(value)
end
local function clearInputs()
	table.clear(keysHeld)
	table.clear(pointersHeld)
	requestSprint(false)
end
local function canChoose()
	local muted, watching = sessionFlags()
	return inputReady() and not muted and not watching and player:GetAttribute("DGParticipating") == true
		and player:GetAttribute("DGRole") == "Picker" and state:GetAttribute("Phase") == "Playing"
		and state:GetAttribute("TurnPhase") == "Choosing"
end
local function nearestDuck()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local nearest, distance = nil, 10
	for _, other in Players:GetPlayers() do
		if other ~= player and other:GetAttribute("DGParticipating") == true and other:GetAttribute("DGRole") == "Duck" then
			local targetRoot = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
			local humanoid = other.Character and other.Character:FindFirstChildOfClass("Humanoid")
			if targetRoot and humanoid and humanoid.Health > 0 then
				local separation = (targetRoot.Position - root.Position).Magnitude
				if separation <= distance then nearest, distance = other, separation end
			end
		end
	end
	return nearest
end
local function chooseGoose()
	if not canChoose() or os.clock() < nextChoose then return end
	local target = nearestDuck()
	if not target then return end
	nextChoose = os.clock() + 0.35
	actionRemote:FireServer("ChooseGoose", target.UserId)
end
local function refreshPrompts()
	local arena = workspace:FindFirstChild("Duck Duck Goose")
	local seats = arena and arena:FindFirstChild("Gameplay") and arena.Gameplay:FindFirstChild("Seats")
	if not seats then return end
	local enabled = canChoose()
	for _, model in seats:GetChildren() do
		local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt and prompt:GetAttribute("DGGoosePrompt") == true then
			local occupant = model:GetAttribute("DGSeatedUserId")
			prompt.Enabled = enabled and typeof(occupant) == "number" and occupant > 0 and occupant ~= player.UserId
		end
	end
end
local function refresh()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local short = math.min(viewport.X, viewport.Y)
	local compact = viewport.X <= 900 or short <= 600 or (short <= 1024 and math.max(viewport.X, viewport.Y) <= 1400)
	local selectedHeader = not compact and gui.DesktopHeader or viewport.Y > viewport.X and gui.PortraitHeader or gui.CompactHeader
	local muted, watching = sessionFlags()
	local phase, turn = state:GetAttribute("Phase"), state:GetAttribute("TurnPhase")
	local participating = player:GetAttribute("DGParticipating") == true
	local eliminated = player:GetAttribute("DGEliminated") == true and phase ~= "Waiting"
	local shown = gui.Enabled and (participating or eliminated or watching) and not muted
	local role = player:GetAttribute("DGRole") or "Duck"
	local now = workspace:GetServerTimeNow()
	local seconds = math.max(0, math.ceil(finite(state:GetAttribute("EndsAt"), now) - now))
	local alive = finite(state:GetAttribute("AliveCount"), 0)
	local ownLap = role == "Runner" or role == "Goose"
	local lap = math.clamp(finite(ownLap and player:GetAttribute("DGLapProgress") or state:GetAttribute("LapProgress"), 0), 0, 1)
	local _, instruction = Guidance.Describe(role, player:GetAttribute("DGRouteStatus"),
		player:GetAttribute("DGSeatReady") == true, eliminated)
	if turn == "FinalDuck" and participating and not eliminated then instruction = "You are the last duck standing!" end
	if watching then instruction = "Watching Duck Duck Goose" end
	if phase == "Countdown" then instruction = "Get ready! One player will choose a goose"
	elseif phase == "Results" then instruction = state:GetAttribute("WinnersText") or "Round finished" end
	local counts = string.format("%d still in", alive)
	if phase == "Playing" and turn == "Chasing" then counts = string.format("%d in · LAP %d%%", alive, math.floor(lap * 100))
	elseif phase == "Playing" and turn == "Choosing" then
		local choiceSeconds = math.max(0, math.ceil(finite(state:GetAttribute("TurnEndsAt"), now) - now))
		counts = string.format("%d in · Choose: %ds", alive, choiceSeconds)
	end
	for _, header in headers do
		header.Visible = shown and header == selectedHeader
		header.Title.Text = phase == "Results" and "ROUND FINISHED" or "DUCK DUCK GOOSE"
		header.Timer.Text = phase == "Countdown" and tostring(state:GetAttribute("CountdownValue") or 8)
			or phase == "Results" and "" or clock(seconds)
		header.Role.Text = watching and "WATCHING" or eliminated and "OUT" or role == "Goose" and "CHASER" or string.upper(role)
		header.Role.TextColor3 = (role == "Picker" or role == "Runner") and Color3.fromRGB(185, 55, 73)
			or role == "Goose" and Color3.fromRGB(152, 94, 27) or Color3.fromRGB(38, 105, 133)
		header.Counts.Text, header.Hint.Text = counts, instruction
		header.Fallback.Visible = not header.ReusableSkin.IsLoaded
	end
	local active = canSprint() == true
	local context = tostring(phase) .. ":" .. tostring(turn) .. ":" .. role
	if not active then
		clearInputs()
	elseif sprintContext ~= context then
		requestSprint(next(keysHeld) ~= nil or next(pointersHeld) ~= nil, true)
	end
	sprintContext = context
	for _, button in sprintButtons do
		button.Visible = shown and participating and phase == "Playing" and (role == "Picker" or role == "Runner" or role == "Goose")
			and button == (UserInputService.TouchEnabled and gui.MobileSprint or gui.DesktopSprint)
		button.Active = active
		button.Selectable = not UserInputService.TouchEnabled and active
		local maximum = math.max(0.1, finite(player:GetAttribute("DGMaxStamina"), 5))
		local current = math.clamp(finite(player:GetAttribute("DGStamina"), 0), 0, maximum)
		button.StaminaTrack.StaminaFill.Size = UDim2.fromScale(current / maximum, 1)
		button.StaminaText.Text = string.format("%.1f / %d", current, maximum)
		button.ReusableSkin.ImageColor3 = active and Color3.new(1, 1, 1) or Color3.fromRGB(150, 157, 170)
		button.ArtFallback.Visible = not button.ReusableSkin.IsLoaded
	end
	gui.ChooseGoose.Visible = shown and participating and role == "Picker" and phase == "Playing" and turn == "Choosing"
	gui.ChooseGoose.Active = canChoose() and nearestDuck() ~= nil
	gui.ChooseGoose.Selectable = gui.ChooseGoose.Active
	gui.ChooseGoose.Hint.Text = gui.ChooseGoose.Active and "CHOOSE NEARBY" or "MOVE CLOSER"
	gui.ChooseGoose.Fallback.Visible = not gui.ChooseGoose.ReusableSkin.IsLoaded
	refreshPrompts()
	guidance.Update({shown = shown, phase = phase, turn = turn, role = role, eliminated = eliminated,
		compact = compact, portrait = compact and viewport.Y > viewport.X, touch = UserInputService.TouchEnabled})
end
local function connect(signal, callback)
	table.insert(connections, signal:Connect(callback))
end
for _, button in sprintButtons do
	connect(button.InputBegan, function(input)
		if not button.Visible or not button.Active then return end
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			pointersHeld[input] = true
			requestSprint(true)
		end
	end)
end
connect(UserInputService.InputEnded, function(input)
	if pointersHeld[input] then
		pointersHeld[input] = nil
		requestSprint(next(pointersHeld) ~= nil or next(keysHeld) ~= nil)
	end
end)
connect(UserInputService.WindowFocusReleased, function() focused = false clearInputs() end)
connect(UserInputService.WindowFocused, function() focused = true refresh() end)
connect(gui.ChooseGoose.Activated, chooseGoose)
ContextActionService:BindAction("DuckDuckGooseSprint", function(_, inputState, input)
	if player:GetAttribute("DGParticipating") ~= true then return Enum.ContextActionResult.Pass end
	if inputState == Enum.UserInputState.Begin then
		keysHeld[input.KeyCode] = true
		requestSprint(true)
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		keysHeld[input.KeyCode] = nil
		requestSprint(next(keysHeld) ~= nil or next(pointersHeld) ~= nil)
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL3)
connect(state.AttributeChanged, refresh)
for _, name in {"DGParticipating", "DGRole", "DGEliminated", "DGRagdolled", "DGStamina", "DGMaxStamina", "DGRouteStatus", "DGSeatReady", "DGReturnPoint", "DGLapProgress"} do
	connect(player:GetAttributeChangedSignal(name), refresh)
end
connect(player.CharacterRemoving, clearInputs)
connect(gui:GetPropertyChangedSignal("Enabled"), refresh)
connect(RunService.Heartbeat, function(delta)
	elapsed += delta
	if elapsed >= 0.1 then elapsed = 0 refresh() end
end)
connect(script.Destroying, function()
	guidance.Destroy()
	clearInputs()
	ContextActionService:UnbindAction("DuckDuckGooseSprint")
	for _, connection in connections do connection:Disconnect() end
end)
refresh()
