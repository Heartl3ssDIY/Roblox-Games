local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local gui = script.Parent
local dock = gui:WaitForChild("Dock")
local toggle = gui:WaitForChild("Toggle")
local roundToggle = gui:WaitForChild("RoundToggle")
local backdrop = gui:WaitForChild("MenuBackdrop")
local panel = gui:WaitForChild("SpectatePanel")
local state = ReplicatedStorage:WaitForChild("PlaygroundState")
local remote = ReplicatedStorage:WaitForChild("PlaygroundSessionRequest")
local afkButton = dock:WaitForChild("AFK")
local watchButton = gui:WaitForChild("Spectate")
local visibilityButton = dock:WaitForChild("Visibility")
local settingsClose = dock:WaitForChild("Close")
local connections = {}
local watching = false
local menuOpen = false
local target
local savedCamera
local savedSelection
local watchingGame
local watchingRound
local busy = false
local alive = true
local requestSerial = 0
local requestWorker
local controlsWorker
local playerControls
local controlsWereEnabled
local focusWorker
local focusSerial = 0
local focusStamp = 0
local lastFocusAt = -math.huge
local lastTargetChange = -math.huge
local loadingUntil = 0
local rejectedUntil = {}
local noticeUntil = 0
local actionName = "PlaygroundSessionControls"
local movementAction = "PlaygroundSpectateMovement"
local movementStep = "PlaygroundSpectateHoldPosition"
local participatingNames = { "BBParticipating", "TGParticipating", "MDParticipating" }
local roundStates = { BritishBulldog = "BritishBulldogState", TagYoureIt = "TagState", StuckInTheMud = "MudState" }
local roundAttributes = { BritishBulldog = "BBParticipating", TagYoureIt = "TGParticipating", StuckInTheMud = "MDParticipating" }
local refresh
local stepTarget

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local function inRound()
	for _, name in ipairs(participatingNames) do
		if player:GetAttribute(name) == true then return true end
	end
	return false
end

local function gamepadActive()
	return string.find(UserInputService:GetLastInputType().Name, "Gamepad", 1, true) ~= nil
end

local function otherModalOpen()
	if GuiService.MenuIsOpen then return true end
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then return false end
	for name, panels in pairs({
		PlaygroundShell = { "ShopPanel" },
		PlaygroundEmoteWheel = { "Panel" },
		PlaygroundAdminPanel = { "Panel", "CompactPanel", "AdminHub" },
	}) do
		local other = playerGui:FindFirstChild(name)
		if other and other.Enabled then
			for _, panelName in ipairs(panels) do
				local object = other:FindFirstChild(panelName)
				if object and object.Visible then return true end
			end
		end
	end
	return false
end

local function activeRound()
	local gameId = state:GetAttribute("ActiveGame")
	local roundState = roundStates[gameId] and ReplicatedStorage:FindFirstChild(roundStates[gameId])
	if state:GetAttribute("Phase") ~= "Playing" or not roundState then return nil end
	local phase = roundState:GetAttribute("Phase")
	if phase == "Waiting" or phase == "Results" or phase == "Intermission" then return nil end
	return gameId, roundState:GetAttribute("RoundNumber")
end

local function targetsFor(gameId)
	local result = {}
	local attribute = roundAttributes[gameId]
	if not attribute then return result end
	for _, candidate in ipairs(Players:GetPlayers()) do
		local character = candidate.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if candidate ~= player and candidate:GetAttribute(attribute) == true and (not humanoid or humanoid.Health > 0)
			and (rejectedUntil[candidate.UserId] or 0) <= os.clock() then
			table.insert(result, candidate)
		end
	end
	table.sort(result, function(a, b) return a.UserId < b.UserId end)
	return result
end

local function tell(message)
	dock.Notice.Text = message
	noticeUntil = os.clock() + 4
end

local function buttonState(button, enabled, selected)
	button.Active = enabled
	button.Interactable = enabled
	button.Selectable = enabled
	button.ReusableSkin.Image = button:GetAttribute(not enabled and "DisabledImage" or selected and "SelectedImage" or "NormalImage")
	if button:GetAttribute("IconButton") then button.ReusableSkin.ImageTransparency = enabled and 0 or 0.55 end
end

local function disableMovement()
	if playerControls and controlsWereEnabled == nil then
		controlsWereEnabled = playerControls.controlsEnabled ~= false
		if controlsWereEnabled then playerControls:Disable() end
	end
end

local function restoreMovement()
	if playerControls and controlsWereEnabled then playerControls:Enable() end
	controlsWereEnabled = nil
end

local function closeMenu()
	menuOpen = false
	gui:SetAttribute("SessionMenuOpen", false)
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(gui) then GuiService.SelectedObject = savedSelection and savedSelection.Parent and savedSelection or nil end
end

local function nextFocusStamp()
	focusStamp = math.max(focusStamp + 0.0001, workspace:GetServerTimeNow())
	return focusStamp
end

local function exitSpectate(message)
	if not watching then return end
	watching = false
	focusSerial += 1
	if focusWorker then pcall(task.cancel, focusWorker) focusWorker = nil end
	local stopStamp = nextFocusStamp()
	task.spawn(function() pcall(remote.InvokeServer, remote, "SetSpectate", 0, stopStamp) end)
	target = nil
	watchingGame = nil
	watchingRound = nil
	gui:SetAttribute("Spectating", false)
	gui:SetAttribute("SpectatingUserId", 0)
	ContextActionService:UnbindAction(movementAction)
	restoreMovement()
	local camera = workspace.CurrentCamera
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if camera then
		local subject = humanoid or (savedCamera and savedCamera.subject and savedCamera.subject.Parent and savedCamera.subject)
		camera.CameraSubject = subject
		camera.CameraType = inRound() and Enum.CameraType.Custom or (savedCamera and savedCamera.kind or Enum.CameraType.Custom)
		if savedCamera and not inRound() then
			camera.CFrame = savedCamera.cframe
			camera.Focus = savedCamera.focus
		end
	end
	savedCamera = nil
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(gui) then
		GuiService.SelectedObject = savedSelection and savedSelection.Parent and savedSelection or nil
	end
	savedSelection = nil
	panel.Visible = false
	if message then tell(message) end
end

local function applyTargetCamera(candidate)
	local humanoid = candidate and candidate.Character and candidate.Character:FindFirstChildOfClass("Humanoid")
	local root = candidate and candidate.Character and candidate.Character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if not camera or not humanoid or not root or humanoid.Health <= 0 then return false end
	target = candidate
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = humanoid
	gui:SetAttribute("SpectatingUserId", candidate.UserId)
	panel.PlayerName.Text = candidate.DisplayName
	panel.Username.Text = "@" .. candidate.Name
	return true
end

local function requestFocus(candidate)
	focusSerial += 1
	local serial = focusSerial
	if focusWorker then pcall(task.cancel, focusWorker) end
	local stamp = nextFocusStamp()
	lastFocusAt = os.clock()
	focusWorker = task.spawn(function()
		local ok, result = pcall(remote.InvokeServer, remote, "SetSpectate", candidate.UserId, stamp)
		if not alive or not watching or serial ~= focusSerial or target ~= candidate then return end
		focusWorker = nil
		if not ok or typeof(result) ~= "table" or not result.ok then
			rejectedUntil[candidate.UserId] = os.clock() + 3
			task.delay(0.25, function() if alive and watching and serial == focusSerial then stepTarget(1) end end)
		end
	end)
	task.delay(8, function()
		if alive and watching and serial == focusSerial and focusWorker then
			exitSpectate("Could not load the arena. Try again.")
			refresh()
		end
	end)
end

local function setTarget(candidate)
	target = candidate
	gui:SetAttribute("SpectatingUserId", candidate.UserId)
	panel.PlayerName.Text = candidate.DisplayName
	panel.Username.Text = "LOADING ARENA..."
	loadingUntil = os.clock() + 10
	requestFocus(candidate)
	applyTargetCamera(candidate)
end

stepTarget = function(direction)
	if not watching then return end
	if os.clock() - lastTargetChange < 0.25 then return end
	lastTargetChange = os.clock()
	local list = targetsFor(watchingGame)
	if #list == 0 then exitSpectate("No players left to watch.") return end
	local index = table.find(list, target)
	local nextIndex = index and ((index - 1 + direction) % #list + 1) or 1
	setTarget(list[nextIndex])
	panel.Counter.Text = string.format("%d / %d", nextIndex, #list)
end

local function startSpectate()
	if watching or inRound() or otherModalOpen() or not gui.Enabled then return end
	local gameId, roundNumber = activeRound()
	local list = targetsFor(gameId)
	local camera = workspace.CurrentCamera
	if not gameId or #list == 0 or not camera then tell("No round to watch yet.") return end
	savedCamera = { subject = camera.CameraSubject, kind = camera.CameraType, cframe = camera.CFrame, focus = camera.Focus }
	local selected = GuiService.SelectedObject
	if not selected or not selected:IsDescendantOf(gui) then savedSelection = selected end
	watching = true
	lastTargetChange = -math.huge
	closeMenu()
	disableMovement()
	watchingGame = gameId
	watchingRound = roundNumber
	gui:SetAttribute("Spectating", true)
	panel.Visible = true
	ContextActionService:BindActionAtPriority(movementAction, function()
		return watching and Enum.ContextActionResult.Sink or Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value + 2,
		Enum.PlayerActions.CharacterForward, Enum.PlayerActions.CharacterBackward,
		Enum.PlayerActions.CharacterLeft, Enum.PlayerActions.CharacterRight, Enum.PlayerActions.CharacterJump)
	stepTarget(1)
	if gamepadActive() then GuiService.SelectedObject = panel.Exit end
	refresh()
end

local function toggleAFK()
	if busy or not gui.Enabled then return end
	busy = true
	requestSerial += 1
	local serial = requestSerial
	refresh()
	requestWorker = task.spawn(function()
		local ok, response = pcall(remote.InvokeServer, remote, "SetAFK", player:GetAttribute("PCAFKRequested") ~= true)
		if not alive or serial ~= requestSerial then return end
		requestWorker = nil
		busy = false
		if ok and typeof(response) == "table" then tell(response.message or "AFK updated.") else tell("Could not update AFK. Try again.") end
		refresh()
	end)
	task.delay(8, function()
		if alive and busy and serial == requestSerial then
			requestSerial += 1
			busy = false
			if requestWorker then pcall(task.cancel, requestWorker) requestWorker = nil end
			tell("AFK request timed out. Try again.")
			refresh()
		end
	end)
end

refresh = function()
	if not alive then return end
	local modal = otherModalOpen()
	local participating = inRound()
	if modal or not gui.Enabled then closeMenu() end
	local gameId, roundNumber = activeRound()
	local localHumanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if watching then
		if participating or not gui.Enabled or modal or not localHumanoid or localHumanoid.Health <= 0 then
			exitSpectate()
		elseif not gameId or gameId ~= watchingGame or roundNumber ~= watchingRound then
			exitSpectate("The round has ended.")
		else
			disableMovement()
			local list = targetsFor(gameId)
			local index = table.find(list, target)
			if not index then
				stepTarget(1)
			else
				local camera = workspace.CurrentCamera
				local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
				local root = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
				if camera and humanoid and root then
					if camera.CameraSubject ~= humanoid or camera.CameraType ~= Enum.CameraType.Custom then applyTargetCamera(target) end
				elseif os.clock() >= loadingUntil then
					rejectedUntil[target.UserId] = os.clock() + 3
					stepTarget(1)
				end
				panel.Counter.Text = string.format("%d / %d", index, #list)
				if watching and target and not focusWorker and os.clock() - lastFocusAt >= 4 then requestFocus(target) end
			end
		end
	end
	dock.Visible = gui.Enabled and not modal and not watching and menuOpen
	backdrop.Visible = dock.Visible
	toggle.Visible = gui.Enabled and not modal and not participating
	roundToggle.Visible = gui.Enabled and not modal and participating
	panel.Visible = watching and not modal
	local requested = player:GetAttribute("PCAFKRequested") == true
	local queued = player:GetAttribute("PCAFKQueued") == true
	panel.JoinStatus.Text = requested and "AFK ON • STAYING IN LOBBY" or "YOU WILL JOIN THE NEXT ROUND"
	afkButton.Label.Text = queued and "AFK NEXT ROUND" or requested and "AFK: ON" or "AFK: OFF"
	buttonState(afkButton, not busy, requested)
	buttonState(toggle, true)
	buttonState(roundToggle, true)
	local uiHidden = gui:GetAttribute("UIHidden") == true
	visibilityButton.Label.Text = uiHidden and "SHOW UI" or "HIDE UI"
	buttonState(visibilityButton, true, uiHidden)
	watchButton.Visible = gui.Enabled and not modal and not participating and not menuOpen
	watchButton.Label.Text = watching and "STOP WATCHING" or "SPECTATE"
	buttonState(watchButton, watching or (gameId ~= nil and #targetsFor(gameId) > 0))
	if os.clock() >= noticeUntil then
		dock.Notice.Text = queued and "After this round" or requested and "Staying in the lobby" or ""
	end
	local controller = gamepadActive()
	dock.Hint.Visible = controller
	dock.Hint.Text = "D-PAD UP: SETTINGS  •  RIGHT: WATCH"
	panel.Controls.Text = controller and "L1 / R1: PLAYER   B / ○: EXIT" or "ARROWS: PLAYER   BACKSPACE: EXIT"
end

connect(afkButton.Activated, toggleAFK)
local function toggleSettings()
	if watching then exitSpectate() end
	if menuOpen then closeMenu() else menuOpen = true gui:SetAttribute("SessionMenuOpen", true) end
	refresh()
end
connect(toggle.Activated, toggleSettings)
connect(roundToggle.Activated, toggleSettings)
connect(settingsClose.Activated, function() closeMenu() refresh() end)
connect(visibilityButton.Activated, function()
	gui:SetAttribute("UIHidden", gui:GetAttribute("UIHidden") ~= true)
	refresh()
end)
connect(backdrop.Activated, function() closeMenu() refresh() end)
connect(watchButton.Activated, function()
	if watching then exitSpectate() refresh() else startSpectate() end
end)
connect(panel.Previous.Activated, function() stepTarget(-1) end)
connect(panel.Next.Activated, function() stepTarget(1) end)
connect(panel.Exit.Activated, function() exitSpectate() refresh() end)
ContextActionService:BindActionAtPriority(actionName, function(_, inputState, input)
	if not gui.Enabled or UserInputService:GetFocusedTextBox() or otherModalOpen() then return Enum.ContextActionResult.Pass end
	local key = input.KeyCode
	if key == Enum.KeyCode.DPadRight and not watching and not inRound() then
		if inputState == Enum.UserInputState.Begin then startSpectate() end
		return Enum.ContextActionResult.Sink
	end
	if key == Enum.KeyCode.DPadUp then
		if inputState == Enum.UserInputState.Begin then
			local selected = GuiService.SelectedObject
			if not selected or not selected:IsDescendantOf(gui) then savedSelection = selected end
			if not watching then menuOpen = true gui:SetAttribute("SessionMenuOpen", true) refresh() end
			GuiService.SelectedObject = watching and panel.Exit or afkButton
		end
		return Enum.ContextActionResult.Sink
	end
	if key == Enum.KeyCode.ButtonB and not watching then
		local selected = GuiService.SelectedObject
		if menuOpen or (selected and selected:IsDescendantOf(gui)) then
			if inputState == Enum.UserInputState.Begin then closeMenu() refresh() savedSelection = nil end
			return Enum.ContextActionResult.Sink
		end
	end
	if not watching then return Enum.ContextActionResult.Pass end
	if inputState == Enum.UserInputState.Begin then
		if key == Enum.KeyCode.ButtonB or key == Enum.KeyCode.Backspace then exitSpectate() refresh()
		elseif key == Enum.KeyCode.ButtonL1 or key == Enum.KeyCode.Left then stepTarget(-1)
		elseif key == Enum.KeyCode.ButtonR1 or key == Enum.KeyCode.Right then stepTarget(1) end
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value + 2, Enum.KeyCode.DPadUp, Enum.KeyCode.DPadRight, Enum.KeyCode.ButtonB, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1, Enum.KeyCode.Left, Enum.KeyCode.Right, Enum.KeyCode.Backspace)

for _, name in ipairs({ "PCAFK", "PCAFKRequested", "PCAFKQueued", table.unpack(participatingNames) }) do
	connect(player:GetAttributeChangedSignal(name), refresh)
end
connect(player.CharacterAdded, function() exitSpectate() refresh() end)
connect(player.CharacterRemoving, function() exitSpectate() refresh() end)
connect(Players.PlayerRemoving, function(candidate) if candidate == target then target = nil task.defer(refresh) end end)
connect(UserInputService.LastInputTypeChanged, refresh)
connect(gui:GetPropertyChangedSignal("Enabled"), refresh)
connect(gui:GetAttributeChangedSignal("UIHidden"), refresh)
connect(state:GetAttributeChangedSignal("ActiveGame"), refresh)
connect(state:GetAttributeChangedSignal("Phase"), refresh)
RunService:BindToRenderStep(movementStep, Enum.RenderPriority.Input.Value + 1, function()
	if not watching or inRound() then return end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid:Move(Vector3.zero, false) humanoid.Jump = false end
end)
local elapsed = 0
connect(RunService.Heartbeat, function(dt)
	elapsed += dt
	if elapsed >= 0.2 then elapsed = 0 refresh() end
end)
script.Destroying:Connect(function()
	alive = false
	requestSerial += 1
	if requestWorker then pcall(task.cancel, requestWorker) end
	if controlsWorker then pcall(task.cancel, controlsWorker) end
	exitSpectate()
	closeMenu()
	ContextActionService:UnbindAction(actionName)
	ContextActionService:UnbindAction(movementAction)
	RunService:UnbindFromRenderStep(movementStep)
	for _, connection in ipairs(connections) do connection:Disconnect() end
end)
controlsWorker = task.spawn(function()
	local playerScripts = player:WaitForChild("PlayerScripts", 10)
	local playerModule = playerScripts and playerScripts:WaitForChild("PlayerModule", 10)
	if playerModule then
		local ok, controls = pcall(function() return require(playerModule):GetControls() end)
		if ok and controls and alive then
			playerControls = controls
			if watching then disableMovement() end
		end
	end
	controlsWorker = nil
end)
gui:SetAttribute("Spectating", false)
gui:SetAttribute("SessionMenuOpen", false)
gui:SetAttribute("SpectatingUserId", 0)
panel.Visible = false
refresh()
