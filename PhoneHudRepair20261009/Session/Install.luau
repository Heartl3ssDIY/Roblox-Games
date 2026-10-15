assert(not game:GetService("RunService"):IsRunning(), "Stop Play before applying the authored HUD repair")
assert(game.PlaceId == 95034648955135, "Unexpected place")
local StarterGui = game:GetService("StarterGui")
local ServerStorage = game:GetService("ServerStorage")
local sources = {["PlaygroundSessionControls"]={before=[[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local gui = script.Parent
local dock = gui:WaitForChild("Dock")
local content = dock:WaitForChild("Body")
local toggle = gui:WaitForChild("Toggle")
local roundToggle = gui:WaitForChild("RoundToggle")
local backdrop = gui:WaitForChild("MenuBackdrop")
local panel = gui:WaitForChild("SpectatePanel")
local state = ReplicatedStorage:WaitForChild("PlaygroundState")
local remote = ReplicatedStorage:WaitForChild("PlaygroundSessionRequest")
local afkButton = content:WaitForChild("AFK")
local watchButton = gui:WaitForChild("Spectate")
local visibilityButton = content:WaitForChild("Visibility")
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
	content.Notice.Text = message
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
		content.Notice.Text = queued and "After this round" or requested and "Staying in the lobby" or ""
	end
	local controller = gamepadActive()
	content.Hint.Visible = controller
	content.Hint.Text = "D-PAD UP: SETTINGS  •  RIGHT: WATCH"
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
refresh()]],after=[[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local gui = script.Parent
local dock = gui:WaitForChild("Dock")
local content = dock:WaitForChild("Body")
local toggle = gui:WaitForChild("Toggle")
local roundToggle = gui:WaitForChild("RoundToggle")
local compactToggle = gui:WaitForChild("CompactToggle")
local portraitToggle = gui:WaitForChild("PortraitToggle")
local backdrop = gui:WaitForChild("MenuBackdrop")
local panel = gui:WaitForChild("SpectatePanel")
local state = ReplicatedStorage:WaitForChild("PlaygroundState")
local remote = ReplicatedStorage:WaitForChild("PlaygroundSessionRequest")
local afkButton = content:WaitForChild("AFK")
local watchButton = gui:WaitForChild("Spectate")
local compactWatch = gui:WaitForChild("CompactSpectate")
local portraitWatch = gui:WaitForChild("PortraitSpectate")
local settingsLaunchers = { toggle, compactToggle, portraitToggle }
local watchLaunchers = { watchButton, compactWatch, portraitWatch }
local visibilityButton = content:WaitForChild("Visibility")
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

local function compactLayout()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local short = math.min(viewport.X, viewport.Y)
	local long = math.max(viewport.X, viewport.Y)
	return viewport.X <= 900 or short <= 600 or (short <= 1024 and long <= 1400), viewport.Y > viewport.X
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
	content.Notice.Text = message
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
	local compact, portrait = compactLayout()
	local showSettings = gui.Enabled and not modal and not participating
	toggle.Visible = showSettings and not compact
	compactToggle.Visible = showSettings and compact and not portrait
	portraitToggle.Visible = showSettings and compact and portrait
	roundToggle.Visible = gui.Enabled and not modal and participating
	panel.Visible = watching and not modal
	local requested = player:GetAttribute("PCAFKRequested") == true
	local queued = player:GetAttribute("PCAFKQueued") == true
	panel.JoinStatus.Text = requested and "AFK ON • STAYING IN LOBBY" or "YOU WILL JOIN THE NEXT ROUND"
	afkButton.Label.Text = queued and "AFK NEXT ROUND" or requested and "AFK: ON" or "AFK: OFF"
	buttonState(afkButton, not busy, requested)
	for _, launcher in ipairs(settingsLaunchers) do buttonState(launcher, true) end
	buttonState(roundToggle, true)
	local uiHidden = gui:GetAttribute("UIHidden") == true
	visibilityButton.Label.Text = uiHidden and "SHOW UI" or "HIDE UI"
	buttonState(visibilityButton, true, uiHidden)
	local showWatch = gui.Enabled and not modal and not participating and not menuOpen
	watchButton.Visible = showWatch and not compact
	compactWatch.Visible = showWatch and compact and not portrait
	portraitWatch.Visible = showWatch and compact and portrait
	local canWatch = watching or (gameId ~= nil and #targetsFor(gameId) > 0)
	for _, launcher in ipairs(watchLaunchers) do
		launcher.Label.Text = watching and "STOP" or "SPECTATE"
		buttonState(launcher, canWatch)
	end
	watchButton.Label.Text = watching and "STOP WATCHING" or "SPECTATE"
	if os.clock() >= noticeUntil then
		content.Notice.Text = queued and "After this round" or requested and "Staying in the lobby" or ""
	end
	local controller = gamepadActive()
	content.Hint.Visible = controller
	content.Hint.Text = "D-PAD UP: SETTINGS  •  RIGHT: WATCH"
	panel.Controls.Text = controller and "L1 / R1: PLAYER   B / ○: EXIT" or "ARROWS: PLAYER   BACKSPACE: EXIT"
end

connect(afkButton.Activated, toggleAFK)
local function toggleSettings()
	if watching then exitSpectate() end
	if menuOpen then closeMenu() else menuOpen = true gui:SetAttribute("SessionMenuOpen", true) end
	refresh()
end
for _, launcher in ipairs(settingsLaunchers) do connect(launcher.Activated, toggleSettings) end
connect(roundToggle.Activated, toggleSettings)
connect(settingsClose.Activated, function() closeMenu() refresh() end)
connect(visibilityButton.Activated, function()
	gui:SetAttribute("UIHidden", gui:GetAttribute("UIHidden") ~= true)
	refresh()
end)
connect(backdrop.Activated, function() closeMenu() refresh() end)
for _, launcher in ipairs(watchLaunchers) do
	connect(launcher.Activated, function()
		if watching then exitSpectate() refresh() else startSpectate() end
	end)
end
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
refresh()]]},["PlaygroundEmoteWheel"]={before=[[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer
local gui = script.Parent
local panel = gui:WaitForChild("Panel")
local backdrop = gui:WaitForChild("Backdrop")
local toggle = gui:WaitForChild("Toggle")
local catalogObject = ReplicatedStorage:WaitForChild("PlaygroundCatalog", 10)
if not catalogObject then toggle.Visible = false return end
local catalog = require(catalogObject)
local alive = true
local connections = {}
local slots = {}
local owned = {}
local equipped = {}
local ready = false
local page = 1
local pageCount = 1
local dances = {}
local busy = false
local requestSerial = 0
local requestWorker
local refreshQueued = false
local lastFetch = -math.huge
local notice = ""
local noticeUntil = 0
local previousSelection
local nativeSuppressed = false
local savedNativeState
local render
local request
local setOpen
local actionName = "PlaygroundEmoteWheelControls"
local numberKeys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight }

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local function inRound()
	return player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or player:GetAttribute("MDParticipating") == true
end

local function otherModalOpen()
    local controls = player.PlayerGui:FindFirstChild("PlaygroundSessionControls")
    if controls and (controls:GetAttribute("Spectating") == true or controls:GetAttribute("UIHidden") == true or controls:GetAttribute("SessionMenuOpen") == true) then return true end
	if GuiService.MenuIsOpen then return true end
	local shell = player.PlayerGui:FindFirstChild("PlaygroundShell")
	if shell then
		for _, name in ipairs({ "ShopPanel", "VotePanel", "CompactVotePanel" }) do
			local object = shell:FindFirstChild(name)
			if object and object.Visible then return true end
		end
	end
	local admin = player.PlayerGui:FindFirstChild("PlaygroundAdminPanel")
	local hub = admin and admin:FindFirstChild("AdminHub")
	return admin and admin.Enabled and hub and hub.Visible or false
end

local function isPlaying()
	local status = player:GetAttribute("PCEmotePlaybackStatus")
	return (status == "playing" or status == "loading") and (player:GetAttribute("PCEmoteUntil") or 0) > workspace:GetServerTimeNow()
end

local function tell(message, seconds)
	notice = tostring(message or "")
	noticeUntil = os.clock() + (seconds or 4)
end

local function gamepadActive()
	return string.find(UserInputService:GetLastInputType().Name, "Gamepad", 1, true) ~= nil
end

local function buttonState(button, enabled, selected)
	button.Active = enabled
	button.Selectable = enabled
	local skin = button:FindFirstChild("ReusableSkin")
	local attribute = not enabled and "DisabledImage" or selected and "SelectedImage" or "NormalImage"
	local image = button:GetAttribute(attribute)
	if skin and typeof(image) == "string" then skin.Image = image end
end

local function restoreSelection()
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(gui) then
		GuiService.SelectedObject = previousSelection and previousSelection.Parent and previousSelection or nil
	end
	previousSelection = nil
end

local function selectFirst()
	if not gamepadActive() then return end
	for _, record in ipairs(slots) do
		if record.button.Visible and record.button.Selectable then GuiService.SelectedObject = record.button return end
	end
	GuiService.SelectedObject = panel.ShopButton
end

local function imageState(record)
	if not record.item then return end
	if record.button.Thumbnail.IsLoaded then
		record.imageStatus = ""
	else
		if panel.Visible and not record.imageStartedAt then record.imageStartedAt = os.clock() end
		record.imageStatus = record.imageStartedAt and os.clock() - record.imageStartedAt >= 8 and "IMAGE UNAVAILABLE" or "LOADING IMAGE"
	end
end

local function setImage(record, item)
	if record.item == item then imageState(record) return end
	record.item = item
	record.imageStartedAt = nil
	record.imageStatus = ""
	local thumbnail = record.button.Thumbnail
	thumbnail.Image = item and item.thumbnail or ""
	thumbnail.Visible = item ~= nil
	if not item then return end
	imageState(record)
end

render = function()
	if not alive then return end
	dances = {}
	for _, item in ipairs(catalog.Items) do
		if item.slot == "Emote" and item.playable == true and item.available ~= false and owned[item.id] == true then
			table.insert(dances, item)
		end
	end
	pageCount = math.max(1, math.ceil(#dances / 8))
	page = math.clamp(page, 1, pageCount)
	local active = isPlaying() and player:GetAttribute("PCEmoteAction") or ""
	for index, record in ipairs(slots) do
		local item = dances[(page - 1) * 8 + index]
		setImage(record, item)
		local button = record.button
		button.Visible = item ~= nil
		buttonState(button, item ~= nil and ready and not busy, item ~= nil and (active == item.id or record.hovered == true))
		button.ItemName.Text = item and item.name or ""
		record.selected.Visible = item ~= nil and (active == item.id or record.hovered == true)
		button.State.Text = item and (active == item.id and "PLAYING" or record.imageStatus ~= "" and record.imageStatus or equipped.Emote == item.id and "PODIUM EMOTE" or "") or ""
	end
	panel.PageLabel.Text = tostring(page) .. " / " .. tostring(pageCount)
	buttonState(panel.Previous, not busy and page > 1)
	buttonState(panel.Next, not busy and page < pageCount)
	buttonState(panel.StopButton, not busy and isPlaying())
	panel.StopButton.Visible = isPlaying()
	if notice ~= "" and os.clock() < noticeUntil then panel.Status.Text = notice
	elseif busy then panel.Status.Text = "Loading..."
	elseif not ready then panel.Status.Text = "Your emotes are getting ready."
	elseif #dances == 0 then panel.Status.Text = "No emotes yet. Unlock dances in the shop."
	else panel.Status.Text = tostring(#dances) .. " owned • Move or jump to stop" end
	panel.Hint.Text = not ready and "LOADING\nEMOTES" or #dances == 0 and "UNLOCK DANCES\nIN THE SHOP" or gamepadActive() and "A TO PLAY\nB TO CLOSE" or UserInputService.TouchEnabled and "TAP A\nDANCE" or "CLICK OR 1–8\nTO DANCE"
	local caption = toggle:FindFirstChild("LiveCaption")
	if caption then caption.Text = gamepadActive() and "EMOTES [D-PAD]" or UserInputService.TouchEnabled and "EMOTES" or "EMOTES [ . ]" end
end

local function acceptStatus(reply)
	if typeof(reply) ~= "table" then return false end
	if typeof(reply.owned) == "table" and typeof(reply.equipped) == "table" and typeof(reply.ready) == "boolean" then
		owned, equipped, ready = reply.owned, reply.equipped, reply.ready
		return true
	end
	return false
end

request = function(action, id)
	if not alive then return end
	if busy then
		if action == "GetStatus" then refreshQueued = true end
		return
	end
	local remote = ReplicatedStorage:FindFirstChild("PlaygroundShopRequest")
	if not remote or not remote:IsA("RemoteFunction") then tell("The emote shop is getting ready.") render() return end
	if action == "GetStatus" and os.clock() - lastFetch < 0.2 then
		refreshQueued = true
		return
	end
	busy = true
	requestSerial += 1
	local serial = requestSerial
	if action == "GetStatus" then lastFetch = os.clock() end
	render()
	task.delay(8, function()
		if not alive or serial ~= requestSerial or not busy then return end
		requestSerial += 1
		busy = false
		if requestWorker then pcall(task.cancel, requestWorker) requestWorker = nil end
		tell("That took too long. Open the wheel to try again.")
		render()
	end)
	requestWorker = task.spawn(function()
		local ok, reply = pcall(function() return remote:InvokeServer(action, id) end)
		if not alive or serial ~= requestSerial then return end
		requestWorker = nil
		busy = false
		local valid = ok and acceptStatus(reply)
		if not valid then
			tell("The emote shop could not respond. Try again.")
		elseif action == "UseEmote" and reply.ok == true then
			notice = ""
			setOpen(false)
		elseif action ~= "GetStatus" then
			tell(reply.message ~= "" and reply.message or (reply.ok and "Done." or "Try again in a moment."))
		end
		render()
		if panel.Visible then selectFirst() end
	end)
end

setOpen = function(show)
	if not alive then return end
	if show and (not gui.Enabled or inRound() or otherModalOpen()) then return end
	if show == panel.Visible then return end
	panel.Visible = show
	backdrop.Visible = show
	if show then
		previousSelection = GuiService.SelectedObject
		notice = ""
		render()
		selectFirst()
		request("GetStatus")
	else
		restoreSelection()
	end
end

local function playSlot(index)
	local record = slots[index]
	if not panel.Visible or busy or not ready or inRound() or otherModalOpen() or not record or not record.item then return end
	request("UseEmote", record.item.id)
end

for index = 1, 8 do
	local button = panel.Wheel:WaitForChild("Slot" .. tostring(index))
	local record = { button = button, selected = button:WaitForChild("Selected"), imageStatus = "", hovered = false }
	table.insert(slots, record)
	connect(button.Activated, function() playSlot(index) end)
	connect(button.MouseEnter, function() record.hovered = true render() end)
	connect(button.MouseLeave, function() record.hovered = false render() end)
	connect(button.SelectionGained, function() record.hovered = true render() end)
	connect(button.SelectionLost, function() record.hovered = false render() end)
	connect(button.Thumbnail:GetPropertyChangedSignal("IsLoaded"), function() imageState(record) render() end)
end

local function movePage(delta)
	if busy then return end
	page = math.clamp(page + delta, 1, pageCount)
	for _, record in ipairs(slots) do record.hovered = false end
	render()
	selectFirst()
end

connect(toggle.Activated, function() setOpen(not panel.Visible) end)
connect(panel.Close.Activated, function() setOpen(false) end)
connect(backdrop.Activated, function() setOpen(false) end)
connect(panel.Previous.Activated, function() movePage(-1) end)
connect(panel.Next.Activated, function() movePage(1) end)
connect(panel.StopButton.Activated, function() if not busy then request("StopEmote") end end)
connect(panel.ShopButton.Activated, function()
	local shell = player.PlayerGui:FindFirstChild("PlaygroundShell")
	if not shell then tell("The shop is getting ready.") render() return end
	setOpen(false)
	shell:SetAttribute("OpenEmoteShopSerial", (tonumber(shell:GetAttribute("OpenEmoteShopSerial")) or 0) + 1)
end)

local function inputAction(_, state, input)
	if not gui.Enabled or UserInputService:GetFocusedTextBox() or GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end
	local key = input.KeyCode
	if key == Enum.KeyCode.DPadDown and panel.Visible then return Enum.ContextActionResult.Pass end
	if key == Enum.KeyCode.Period or key == Enum.KeyCode.DPadDown then
		if inRound() or otherModalOpen() then return Enum.ContextActionResult.Pass end
		if state == Enum.UserInputState.Begin then setOpen(not panel.Visible) end
		return Enum.ContextActionResult.Sink
	end
	if not panel.Visible then return Enum.ContextActionResult.Pass end
	if state == Enum.UserInputState.Begin then
		if key == Enum.KeyCode.ButtonB then setOpen(false)
		elseif key == Enum.KeyCode.ButtonL1 then movePage(-1)
		elseif key == Enum.KeyCode.ButtonR1 then movePage(1)
		else
			local index = table.find(numberKeys, key)
			if index then playSlot(index) end
		end
	end
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindActionAtPriority(actionName, inputAction, false, Enum.ContextActionPriority.High.Value + 1, Enum.KeyCode.Period, Enum.KeyCode.DPadDown, Enum.KeyCode.ButtonB, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1, table.unpack(numberKeys))

for _, attribute in ipairs({ "BBParticipating", "TGParticipating", "MDParticipating" }) do
	connect(player:GetAttributeChangedSignal(attribute), function() if inRound() then setOpen(false) end render() end)
end
for _, attribute in ipairs({ "PCInventoryVersion", "PCDataReady" }) do
	connect(player:GetAttributeChangedSignal(attribute), function()
		if player:GetAttribute("PCDataReady") ~= true then ready = false end
		refreshQueued = true
		render()
	end)
end
for _, attribute in ipairs({ "PCEmotePlaybackStatus", "PCEmoteAction", "PCEmoteUntil", "PCEmote" }) do
	connect(player:GetAttributeChangedSignal(attribute), function()
		if attribute == "PCEmotePlaybackStatus" and player:GetAttribute(attribute) == "failed" then
			tell(player:GetAttribute("PCEmotePlaybackMessage") or "This dance could not load.", 5)
		end
		render()
	end)
end
connect(UserInputService.LastInputTypeChanged, function() render() end)
connect(player.CharacterAdded, function() setOpen(false) refreshQueued = true end)
connect(player.CharacterRemoving, function() setOpen(false) end)
connect(gui:GetPropertyChangedSignal("Enabled"), function() if not gui.Enabled then setOpen(false) end end)
connect(ReplicatedStorage.ChildAdded, function(child) if child.Name == "PlaygroundShopRequest" then refreshQueued = true end end)

panel.Visible = false
backdrop.Visible = false
render()
refreshQueued = true

task.spawn(function()
	for _ = 1, 10 do
		if not alive then return end
		local ok, previous = pcall(function() return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu) end)
		if ok then
			local applied = pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, false) end)
			if applied then savedNativeState = previous nativeSuppressed = true return end
		end
		task.wait(0.5)
	end
	warn("Playground emote wheel could not hide the native emote menu")
end)

local function refreshAvailability()
    local blocked = inRound() or otherModalOpen() or not gui.Enabled
    toggle.Visible = not blocked and not panel.Visible
    if blocked then setOpen(false) end
end
local spectatorConnection
local function bindSpectatorControls(controls)
    if controls.Name ~= "PlaygroundSessionControls" then return end
    if spectatorConnection then spectatorConnection:Disconnect() end
    spectatorConnection = connect(controls.AttributeChanged, function(name)
        if name == "Spectating" or name == "UIHidden" or name == "SessionMenuOpen" then refreshAvailability() end
    end)
    refreshAvailability()
end
connect(player.PlayerGui.ChildAdded, bindSpectatorControls)
local sessionControls = player.PlayerGui:FindFirstChild("PlaygroundSessionControls")
if sessionControls then bindSpectatorControls(sessionControls) end

task.spawn(function()
	while alive do
		refreshAvailability()
		if refreshQueued and not busy and os.clock() - lastFetch >= 0.2 then
			refreshQueued = false
			request("GetStatus")
		end
		if panel.Visible then render() end
		task.wait(0.2)
	end
end)

connect(script.Destroying, function()
	setOpen(false)
	alive = false
	requestSerial += 1
	if requestWorker then pcall(task.cancel, requestWorker) requestWorker = nil end
	ContextActionService:UnbindAction(actionName)
	for _, connection in ipairs(connections) do connection:Disconnect() end
	if nativeSuppressed then pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, savedNativeState) end) end
end)
]],after=[[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer
local gui = script.Parent
local panel = gui:WaitForChild("Panel")
local backdrop = gui:WaitForChild("Backdrop")
local toggle = gui:WaitForChild("Toggle")
local compactToggle = gui:WaitForChild("CompactEmoteToggle")
local portraitToggle = gui:WaitForChild("PortraitEmoteToggle")
local launchers = { toggle, compactToggle, portraitToggle }
local catalogObject = ReplicatedStorage:WaitForChild("PlaygroundCatalog", 10)
if not catalogObject then for _, launcher in ipairs(launchers) do launcher.Visible = false end return end
local catalog = require(catalogObject)
local alive = true
local connections = {}
local slots = {}
local owned = {}
local equipped = {}
local ready = false
local page = 1
local pageCount = 1
local dances = {}
local busy = false
local requestSerial = 0
local requestWorker
local refreshQueued = false
local lastFetch = -math.huge
local notice = ""
local noticeUntil = 0
local previousSelection
local nativeSuppressed = false
local savedNativeState
local render
local request
local setOpen
local actionName = "PlaygroundEmoteWheelControls"
local numberKeys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight }

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local function inRound()
	return player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or player:GetAttribute("MDParticipating") == true
end

local function otherModalOpen()
    local controls = player.PlayerGui:FindFirstChild("PlaygroundSessionControls")
    if controls and (controls:GetAttribute("Spectating") == true or controls:GetAttribute("UIHidden") == true or controls:GetAttribute("SessionMenuOpen") == true) then return true end
	if GuiService.MenuIsOpen then return true end
	local shell = player.PlayerGui:FindFirstChild("PlaygroundShell")
	if shell then
		for _, name in ipairs({ "ShopPanel", "VotePanel", "CompactVotePanel" }) do
			local object = shell:FindFirstChild(name)
			if object and object.Visible then return true end
		end
	end
	local admin = player.PlayerGui:FindFirstChild("PlaygroundAdminPanel")
	local hub = admin and admin:FindFirstChild("AdminHub")
	return admin and admin.Enabled and hub and hub.Visible or false
end

local function isPlaying()
	local status = player:GetAttribute("PCEmotePlaybackStatus")
	return (status == "playing" or status == "loading") and (player:GetAttribute("PCEmoteUntil") or 0) > workspace:GetServerTimeNow()
end

local function tell(message, seconds)
	notice = tostring(message or "")
	noticeUntil = os.clock() + (seconds or 4)
end

local function compactLayout()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local short = math.min(viewport.X, viewport.Y)
	local long = math.max(viewport.X, viewport.Y)
	return viewport.X <= 900 or short <= 600 or (short <= 1024 and long <= 1400), viewport.Y > viewport.X
end

local function gamepadActive()
	return string.find(UserInputService:GetLastInputType().Name, "Gamepad", 1, true) ~= nil
end

local function buttonState(button, enabled, selected)
	button.Active = enabled
	button.Selectable = enabled
	local skin = button:FindFirstChild("ReusableSkin")
	local attribute = not enabled and "DisabledImage" or selected and "SelectedImage" or "NormalImage"
	local image = button:GetAttribute(attribute)
	if skin and typeof(image) == "string" then skin.Image = image end
end

local function restoreSelection()
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(gui) then
		GuiService.SelectedObject = previousSelection and previousSelection.Parent and previousSelection or nil
	end
	previousSelection = nil
end

local function selectFirst()
	if not gamepadActive() then return end
	for _, record in ipairs(slots) do
		if record.button.Visible and record.button.Selectable then GuiService.SelectedObject = record.button return end
	end
	GuiService.SelectedObject = panel.ShopButton
end

local function imageState(record)
	if not record.item then return end
	if record.button.Thumbnail.IsLoaded then
		record.imageStatus = ""
	else
		if panel.Visible and not record.imageStartedAt then record.imageStartedAt = os.clock() end
		record.imageStatus = record.imageStartedAt and os.clock() - record.imageStartedAt >= 8 and "IMAGE UNAVAILABLE" or "LOADING IMAGE"
	end
end

local function setImage(record, item)
	if record.item == item then imageState(record) return end
	record.item = item
	record.imageStartedAt = nil
	record.imageStatus = ""
	local thumbnail = record.button.Thumbnail
	thumbnail.Image = item and item.thumbnail or ""
	thumbnail.Visible = item ~= nil
	if not item then return end
	imageState(record)
end

render = function()
	if not alive then return end
	dances = {}
	for _, item in ipairs(catalog.Items) do
		if item.slot == "Emote" and item.playable == true and item.available ~= false and owned[item.id] == true then
			table.insert(dances, item)
		end
	end
	pageCount = math.max(1, math.ceil(#dances / 8))
	page = math.clamp(page, 1, pageCount)
	local active = isPlaying() and player:GetAttribute("PCEmoteAction") or ""
	for index, record in ipairs(slots) do
		local item = dances[(page - 1) * 8 + index]
		setImage(record, item)
		local button = record.button
		button.Visible = item ~= nil
		buttonState(button, item ~= nil and ready and not busy, item ~= nil and (active == item.id or record.hovered == true))
		button.ItemName.Text = item and item.name or ""
		record.selected.Visible = item ~= nil and (active == item.id or record.hovered == true)
		button.State.Text = item and (active == item.id and "PLAYING" or record.imageStatus ~= "" and record.imageStatus or equipped.Emote == item.id and "PODIUM EMOTE" or "") or ""
	end
	panel.PageLabel.Text = tostring(page) .. " / " .. tostring(pageCount)
	buttonState(panel.Previous, not busy and page > 1)
	buttonState(panel.Next, not busy and page < pageCount)
	buttonState(panel.StopButton, not busy and isPlaying())
	panel.StopButton.Visible = isPlaying()
	if notice ~= "" and os.clock() < noticeUntil then panel.Status.Text = notice
	elseif busy then panel.Status.Text = "Loading..."
	elseif not ready then panel.Status.Text = "Your emotes are getting ready."
	elseif #dances == 0 then panel.Status.Text = "No emotes yet. Unlock dances in the shop."
	else panel.Status.Text = tostring(#dances) .. " owned • Move or jump to stop" end
	panel.Hint.Text = not ready and "LOADING\nEMOTES" or #dances == 0 and "UNLOCK DANCES\nIN THE SHOP" or gamepadActive() and "A TO PLAY\nB TO CLOSE" or UserInputService.TouchEnabled and "TAP A\nDANCE" or "CLICK OR 1–8\nTO DANCE"
	local caption = toggle:FindFirstChild("LiveCaption")
	if caption then caption.Text = gamepadActive() and "EMOTES [D-PAD]" or UserInputService.TouchEnabled and "EMOTES" or "EMOTES [ . ]" end
end

local function acceptStatus(reply)
	if typeof(reply) ~= "table" then return false end
	if typeof(reply.owned) == "table" and typeof(reply.equipped) == "table" and typeof(reply.ready) == "boolean" then
		owned, equipped, ready = reply.owned, reply.equipped, reply.ready
		return true
	end
	return false
end

request = function(action, id)
	if not alive then return end
	if busy then
		if action == "GetStatus" then refreshQueued = true end
		return
	end
	local remote = ReplicatedStorage:FindFirstChild("PlaygroundShopRequest")
	if not remote or not remote:IsA("RemoteFunction") then tell("The emote shop is getting ready.") render() return end
	if action == "GetStatus" and os.clock() - lastFetch < 0.2 then
		refreshQueued = true
		return
	end
	busy = true
	requestSerial += 1
	local serial = requestSerial
	if action == "GetStatus" then lastFetch = os.clock() end
	render()
	task.delay(8, function()
		if not alive or serial ~= requestSerial or not busy then return end
		requestSerial += 1
		busy = false
		if requestWorker then pcall(task.cancel, requestWorker) requestWorker = nil end
		tell("That took too long. Open the wheel to try again.")
		render()
	end)
	requestWorker = task.spawn(function()
		local ok, reply = pcall(function() return remote:InvokeServer(action, id) end)
		if not alive or serial ~= requestSerial then return end
		requestWorker = nil
		busy = false
		local valid = ok and acceptStatus(reply)
		if not valid then
			tell("The emote shop could not respond. Try again.")
		elseif action == "UseEmote" and reply.ok == true then
			notice = ""
			setOpen(false)
		elseif action ~= "GetStatus" then
			tell(reply.message ~= "" and reply.message or (reply.ok and "Done." or "Try again in a moment."))
		end
		render()
		if panel.Visible then selectFirst() end
	end)
end

setOpen = function(show)
	if not alive then return end
	if show and (not gui.Enabled or inRound() or otherModalOpen()) then return end
	if show == panel.Visible then return end
	panel.Visible = show
	backdrop.Visible = show
	if show then
		previousSelection = GuiService.SelectedObject
		notice = ""
		render()
		selectFirst()
		request("GetStatus")
	else
		restoreSelection()
	end
end

local function playSlot(index)
	local record = slots[index]
	if not panel.Visible or busy or not ready or inRound() or otherModalOpen() or not record or not record.item then return end
	request("UseEmote", record.item.id)
end

for index = 1, 8 do
	local button = panel.Wheel:WaitForChild("Slot" .. tostring(index))
	local record = { button = button, selected = button:WaitForChild("Selected"), imageStatus = "", hovered = false }
	table.insert(slots, record)
	connect(button.Activated, function() playSlot(index) end)
	connect(button.MouseEnter, function() record.hovered = true render() end)
	connect(button.MouseLeave, function() record.hovered = false render() end)
	connect(button.SelectionGained, function() record.hovered = true render() end)
	connect(button.SelectionLost, function() record.hovered = false render() end)
	connect(button.Thumbnail:GetPropertyChangedSignal("IsLoaded"), function() imageState(record) render() end)
end

local function movePage(delta)
	if busy then return end
	page = math.clamp(page + delta, 1, pageCount)
	for _, record in ipairs(slots) do record.hovered = false end
	render()
	selectFirst()
end

for _, launcher in ipairs(launchers) do connect(launcher.Activated, function() setOpen(not panel.Visible) end) end
connect(panel.Close.Activated, function() setOpen(false) end)
connect(backdrop.Activated, function() setOpen(false) end)
connect(panel.Previous.Activated, function() movePage(-1) end)
connect(panel.Next.Activated, function() movePage(1) end)
connect(panel.StopButton.Activated, function() if not busy then request("StopEmote") end end)
connect(panel.ShopButton.Activated, function()
	local shell = player.PlayerGui:FindFirstChild("PlaygroundShell")
	if not shell then tell("The shop is getting ready.") render() return end
	setOpen(false)
	shell:SetAttribute("OpenEmoteShopSerial", (tonumber(shell:GetAttribute("OpenEmoteShopSerial")) or 0) + 1)
end)

local function inputAction(_, state, input)
	if not gui.Enabled or UserInputService:GetFocusedTextBox() or GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end
	local key = input.KeyCode
	if key == Enum.KeyCode.DPadDown and panel.Visible then return Enum.ContextActionResult.Pass end
	if key == Enum.KeyCode.Period or key == Enum.KeyCode.DPadDown then
		if inRound() or otherModalOpen() then return Enum.ContextActionResult.Pass end
		if state == Enum.UserInputState.Begin then setOpen(not panel.Visible) end
		return Enum.ContextActionResult.Sink
	end
	if not panel.Visible then return Enum.ContextActionResult.Pass end
	if state == Enum.UserInputState.Begin then
		if key == Enum.KeyCode.ButtonB then setOpen(false)
		elseif key == Enum.KeyCode.ButtonL1 then movePage(-1)
		elseif key == Enum.KeyCode.ButtonR1 then movePage(1)
		else
			local index = table.find(numberKeys, key)
			if index then playSlot(index) end
		end
	end
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindActionAtPriority(actionName, inputAction, false, Enum.ContextActionPriority.High.Value + 1, Enum.KeyCode.Period, Enum.KeyCode.DPadDown, Enum.KeyCode.ButtonB, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1, table.unpack(numberKeys))

for _, attribute in ipairs({ "BBParticipating", "TGParticipating", "MDParticipating" }) do
	connect(player:GetAttributeChangedSignal(attribute), function() if inRound() then setOpen(false) end render() end)
end
for _, attribute in ipairs({ "PCInventoryVersion", "PCDataReady" }) do
	connect(player:GetAttributeChangedSignal(attribute), function()
		if player:GetAttribute("PCDataReady") ~= true then ready = false end
		refreshQueued = true
		render()
	end)
end
for _, attribute in ipairs({ "PCEmotePlaybackStatus", "PCEmoteAction", "PCEmoteUntil", "PCEmote" }) do
	connect(player:GetAttributeChangedSignal(attribute), function()
		if attribute == "PCEmotePlaybackStatus" and player:GetAttribute(attribute) == "failed" then
			tell(player:GetAttribute("PCEmotePlaybackMessage") or "This dance could not load.", 5)
		end
		render()
	end)
end
connect(UserInputService.LastInputTypeChanged, function() render() end)
connect(player.CharacterAdded, function() setOpen(false) refreshQueued = true end)
connect(player.CharacterRemoving, function() setOpen(false) end)
connect(gui:GetPropertyChangedSignal("Enabled"), function() if not gui.Enabled then setOpen(false) end end)
connect(ReplicatedStorage.ChildAdded, function(child) if child.Name == "PlaygroundShopRequest" then refreshQueued = true end end)

panel.Visible = false
backdrop.Visible = false
render()
refreshQueued = true

task.spawn(function()
	for _ = 1, 10 do
		if not alive then return end
		local ok, previous = pcall(function() return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu) end)
		if ok then
			local applied = pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, false) end)
			if applied then savedNativeState = previous nativeSuppressed = true return end
		end
		task.wait(0.5)
	end
	warn("Playground emote wheel could not hide the native emote menu")
end)

local function refreshAvailability()
    local blocked = inRound() or otherModalOpen() or not gui.Enabled
    local compact, portrait = compactLayout()
    local show = not blocked and not panel.Visible
    toggle.Visible = show and not compact
    compactToggle.Visible = show and compact and not portrait
    portraitToggle.Visible = show and compact and portrait
    if blocked then setOpen(false) end
end
local spectatorConnection
local function bindSpectatorControls(controls)
    if controls.Name ~= "PlaygroundSessionControls" then return end
    if spectatorConnection then spectatorConnection:Disconnect() end
    spectatorConnection = connect(controls.AttributeChanged, function(name)
        if name == "Spectating" or name == "UIHidden" or name == "SessionMenuOpen" then refreshAvailability() end
    end)
    refreshAvailability()
end
connect(player.PlayerGui.ChildAdded, bindSpectatorControls)
local sessionControls = player.PlayerGui:FindFirstChild("PlaygroundSessionControls")
if sessionControls then bindSpectatorControls(sessionControls) end

task.spawn(function()
	while alive do
		refreshAvailability()
		if refreshQueued and not busy and os.clock() - lastFetch >= 0.2 then
			refreshQueued = false
			request("GetStatus")
		end
		if panel.Visible then render() end
		task.wait(0.2)
	end
end)

connect(script.Destroying, function()
	setOpen(false)
	alive = false
	requestSerial += 1
	if requestWorker then pcall(task.cancel, requestWorker) requestWorker = nil end
	ContextActionService:UnbindAction(actionName)
	for _, connection in ipairs(connections) do connection:Disconnect() end
	if nativeSuppressed then pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, savedNativeState) end) end
end)
]]}}
for name, record in pairs(sources) do
	local gui = assert(StarterGui:FindFirstChild(name), name .. " missing")
	assert(gui.Controller.Source == record.before, name .. " controller changed; refresh the patch")
end
local backupName = "PhoneHudSessionBackup20261009"
assert(not ServerStorage:FindFirstChild(backupName), "HUD backup already exists")
local backup = Instance.new("Folder")
backup.Name = backupName
backup.Parent = ServerStorage
for name in pairs(sources) do StarterGui[name]:Clone().Parent = backup end
local session = StarterGui.PlaygroundSessionControls
local emotes = StarterGui.PlaygroundEmoteWheel
local function icon(target)
	target.Size = UDim2.fromOffset(44, 44)
	target.BackgroundTransparency = 1
	target.ReusableSkin.AnchorPoint = Vector2.new(0.5, 0)
	target.ReusableSkin.Position = UDim2.new(0.5, 0, 0, 0)
	target.ReusableSkin.Size = UDim2.fromOffset(32, 32)
	target.Label.AnchorPoint = Vector2.zero
	target.Label.Position = UDim2.fromOffset(0, 32)
	target.Label.Size = UDim2.fromOffset(44, 12)
	target.Label.TextScaled = true
	target.Label.TextWrapped = false
	for _, c in target.Label:GetChildren() do
		if c:IsA("UITextSizeConstraint") then c.MinTextSize = 8 c.MaxTextSize = 10 end
	end
	target:SetAttribute("PlacementNote", "Authored compact launcher with 44-pixel touch target")
end
local function addIcon(template, name, position, anchor)
	assert(not session:FindFirstChild(name), name .. " already exists")
	local button = template:Clone()
	button.Name = name
	button.AnchorPoint = anchor or Vector2.zero
	button.Position = position
	icon(button)
	button.Visible = false
	button.Parent = session
	return button
end
addIcon(session.Toggle, "CompactToggle", UDim2.fromOffset(8, 62))
addIcon(session.Spectate, "CompactSpectate", UDim2.fromOffset(60, 62))
addIcon(session.Toggle, "PortraitToggle", UDim2.new(0.5, -92, 0, 112))
addIcon(session.Spectate, "PortraitSpectate", UDim2.new(0.5, -40, 0, 112))
session.Toggle.Position = UDim2.fromOffset(18, 70)
session.Spectate.Position = UDim2.fromOffset(74, 70)
session.RoundToggle.Position = UDim2.new(1, -8, 0, 48)
icon(session.RoundToggle)
local function addEmote(name, position, anchor)
	assert(not emotes:FindFirstChild(name), name .. " already exists")
	local button = emotes.Toggle:Clone()
	button.Name = name
	button.AnchorPoint = anchor
	button.Position = position
	button.Size = UDim2.fromOffset(80, 44)
	local limit = button:FindFirstChild("MinimumHitSize")
	if limit then limit.MinSize = Vector2.new(80, 44) limit.MaxSize = Vector2.new(80, 44) end
	button.LiveCaption.Text = "EMOTES"
	button.LiveCaption.Position = UDim2.new(0.06, 0, 0.16, 0)
	button.LiveCaption.Size = UDim2.new(0.88, 0, 0.64, 0)
	for _, c in button.LiveCaption:GetChildren() do
		if c:IsA("UITextSizeConstraint") then c.MinTextSize = 10 c.MaxTextSize = 15 end
	end
	button.Visible = false
	button:SetAttribute("PlacementNote", "Authored compact launcher with 44-pixel touch target")
	button.Parent = emotes
end
addEmote("CompactEmoteToggle", UDim2.new(1, -8, 0, 62), Vector2.new(1, 0))
addEmote("PortraitEmoteToggle", UDim2.new(0.5, 12, 0, 112), Vector2.zero)
emotes.Toggle.Position = UDim2.new(0, 18, 1, -194)
emotes.Toggle.Size = UDim2.fromOffset(140, 48)
for name, record in pairs(sources) do StarterGui[name].Controller.Source = record.after end
return {ok=true,backup=backup:GetFullName(),launchers=6}
