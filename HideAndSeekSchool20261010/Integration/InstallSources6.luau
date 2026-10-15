assert(not game:GetService("RunService"):IsRunning(), "Stop Play before integrating Hide and Seek.")
assert(game.PlaceId == 95034648955135, "Wrong experience.")
local entries = {
 { path = "StarterGui.PlaygroundSessionControls.Controller", expected = 363811733, source = [==[local Players = game:GetService("Players")
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
local compactRoundToggle = gui:WaitForChild("CompactRoundToggle")
local portraitRoundToggle = gui:WaitForChild("PortraitRoundToggle")
local roundLaunchers = { roundToggle, compactRoundToggle, portraitRoundToggle }
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
local participatingNames = { "BBParticipating", "TGParticipating", "MDParticipating", "HSParticipating" }
local roundStates = { BritishBulldog = "BritishBulldogState", TagYoureIt = "TagState", StuckInTheMud = "MudState", HideAndSeek = "HideAndSeekState" }
local roundAttributes = { BritishBulldog = "BBParticipating", TagYoureIt = "TGParticipating", StuckInTheMud = "MDParticipating", HideAndSeek = "HSParticipating" }
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
	local showRoundSettings = gui.Enabled and not modal and participating
	roundToggle.Visible = showRoundSettings and not compact
	compactRoundToggle.Visible = showRoundSettings and compact and not portrait
	portraitRoundToggle.Visible = showRoundSettings and compact and portrait
	panel.Visible = watching and not modal
	local requested = player:GetAttribute("PCAFKRequested") == true
	local queued = player:GetAttribute("PCAFKQueued") == true
	panel.JoinStatus.Text = requested and "AFK ON • STAYING IN LOBBY" or "YOU WILL JOIN THE NEXT ROUND"
	afkButton.Label.Text = queued and "AFK NEXT ROUND" or requested and "AFK: ON" or "AFK: OFF"
	buttonState(afkButton, not busy, requested)
	for _, launcher in ipairs(settingsLaunchers) do buttonState(launcher, true) end
	for _, launcher in ipairs(roundLaunchers) do buttonState(launcher, true) end
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
for _, launcher in ipairs(roundLaunchers) do connect(launcher.Activated, toggleSettings) end
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
refresh()]==] },
 { path = "StarterGui.PlaygroundEmoteWheel.Controller", expected = 1572849286, source = [==[local Players = game:GetService("Players")
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
	return player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or ( player:GetAttribute("MDParticipating") == true or player:GetAttribute("HSParticipating") == true )
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

for _, attribute in ipairs({ "BBParticipating", "TGParticipating", "MDParticipating", "HSParticipating" }) do
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
]==] },
 { path = "StarterGui.PlaygroundToyHotbar.Controller", expected = 78927462, source = [==[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer
local gui = script.Parent
local bar = gui:WaitForChild("Bar")
local catalogObject = ReplicatedStorage:WaitForChild("PlaygroundCatalog", 10)
if not catalogObject then bar.Visible = false return end
local catalog = require(catalogObject)
local connections = {}
local slots = {}
local alive = true
local pending = false
local requestToken = 0
local notice = ""
local noticeUntil = 0
local activeIndex = 0
local activeId = ""
local refresh
local backpackSuppressed = false
local savedBackpackState = nil

local function showNativeBackpack(show)
	if not show and not backpackSuppressed then
		local ok, previous = pcall(function() return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack) end)
		if not ok then return end
		local applied = pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)
		if applied then savedBackpackState = previous backpackSuppressed = true end
	elseif show and backpackSuppressed then
		local applied = pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, savedBackpackState) end)
		if applied then backpackSuppressed = false savedBackpackState = nil end
	end
end

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local function inRound()
	return player:GetAttribute("PCToyRoundPreparing") == true or player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or ( player:GetAttribute("MDParticipating") == true or player:GetAttribute("HSParticipating") == true )
end

local function modalOpen()
	local shell = player.PlayerGui:FindFirstChild("PlaygroundShell")
	if shell then
		for _, name in ipairs({ "ShopPanel", "VotePanel", "CompactVotePanel" }) do
			local panel = shell:FindFirstChild(name)
			if panel and panel.Visible then return true end
		end
	end
	local wheel = player.PlayerGui:FindFirstChild("PlaygroundEmoteWheel")
	local wheelPanel = wheel and wheel:FindFirstChild("Panel")
	if wheel and wheel.Enabled and wheelPanel and wheelPanel.Visible then return true end
	local admin = player.PlayerGui:FindFirstChild("PlaygroundAdminPanel")
	local adminHub = admin and admin:FindFirstChild("AdminHub")
	if admin and admin.Enabled and adminHub and adminHub.Visible then return true end
	return GuiService.MenuIsOpen
end

local function sessionControlsBusy()
	local controls = player.PlayerGui:FindFirstChild("PlaygroundSessionControls")
	return controls and (controls:GetAttribute("Spectating") == true or controls:GetAttribute("SessionMenuOpen") == true or controls:GetAttribute("UIHidden") == true)
end

local function usable()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return player:GetAttribute("PCDataReady") == true and not inRound() and not sessionControlsBusy() and humanoid and humanoid.Health > 0
end

local function tell(message, seconds)
	notice = tostring(message or "")
	noticeUntil = workspace:GetServerTimeNow() + (seconds or 3)
end

local function cooldownEndsAt(id)
	local now = workspace:GetServerTimeNow()
	local ember = tonumber(player:GetAttribute("PCToyEmberUntil")) or 0
	local attribute = id == "M07" and ember > now and "PCToyEmberShotUntil" or "PCToyCooldown_" .. id
	return tonumber(player:GetAttribute(attribute)) or 0
end

local function refreshThumbnail(record)
	if not alive or not record.button.Parent then return end
	local thumbnail = record.button.Thumbnail
	local note = record.button.PreviewNote
	note.Visible = thumbnail.Visible and (thumbnail.Image == "" or not thumbnail.IsLoaded)
	note.Text = (thumbnail.Image == "" or record.thumbnailTimedOut) and "NO PREVIEW" or "LOADING..."
end

local function preview(record, id)
	local item = catalog.ById[id]
	local image = item and typeof(item.thumbnail) == "string" and item.thumbnail or ""
	if record.id == id and record.button.Thumbnail.Image == image then return end
	record.id = id
	record.generation += 1
	local generation = record.generation
	record.thumbnailTimedOut = false
	record.button.Preview.Visible = false
	record.button.Thumbnail.Image = image
	record.button.Thumbnail.Visible = id ~= ""
	refreshThumbnail(record)
	if id ~= "" and image ~= "" and not record.button.Thumbnail.IsLoaded then
		task.delay(8, function()
			if alive and generation == record.generation and record.button.Parent and record.button.Thumbnail.Image == image then
				record.thumbnailTimedOut = true
				refreshThumbnail(record)
			end
		end)
	end
end

local function syncLoadout()
	if not alive then return end
	for index, record in ipairs(slots) do
		local id = player:GetAttribute("PCToySlot" .. tostring(index))
		if typeof(id) ~= "string" or not catalog.ById[id] then id = "" end
		preview(record, id)
		record.button.ItemName.Text = id ~= "" and catalog.ById[id].name or "EMPTY"
	end
	activeIndex = math.clamp(math.floor(tonumber(player:GetAttribute("PCToyIndex")) or 0), 0, 4)
	activeId = slots[activeIndex] and slots[activeIndex].id or ""
	refresh()
end

local function invoke(remoteName, action, payload, itemId)
	if pending or not alive then return end
	local remote = ReplicatedStorage:FindFirstChild(remoteName)
	if not remote or not remote:IsA("RemoteFunction") then tell("Toys are getting ready.") refresh() return end
	pending = true
	requestToken += 1
	local token = requestToken
	refresh()
	task.delay(8, function()
		if not alive or requestToken ~= token or not pending then return end
		requestToken += 1
		pending = false
		tell("That took too long. Try again.")
		refresh()
	end)
	task.spawn(function()
		local ok, reply = pcall(function() return remote:InvokeServer(action, payload) end)
		if not alive or requestToken ~= token then return end
		pending = false
		if ok and typeof(reply) == "table" then
			if reply.message then tell(reply.message) elseif not reply.ok then tell("That did not go through.") end
		else
			tell("That did not go through. Try again.")
		end
		refresh()
	end)
end

local function aimAt(screenPosition)
	local camera = workspace.CurrentCamera
	if not camera then return nil end
	local position = screenPosition or camera.ViewportSize * 0.5
	local ray = screenPosition and camera:ScreenPointToRay(position.X, position.Y) or camera:ViewportPointToRay(position.X, position.Y)
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	parameters.FilterDescendantsInstances = player.Character and { player.Character } or {}
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, parameters)
	return hit and hit.Position or ray.Origin + ray.Direction * 150
end

local function useToy(position)
	if not gui.Enabled or not bar.Visible or not usable() or modalOpen() or activeId == "" or pending then return end
	local item = catalog.ById[activeId]
	if item and item.toyActionPending then tell("This toy's action is coming soon.") refresh() return end
	if cooldownEndsAt(activeId) > workspace:GetServerTimeNow() then return end
	invoke("PlaygroundToyRequest", "Use", aimAt(position), activeId)
end

local function selectToy(index)
	local record = slots[index]
	if not gui.Enabled or not record or record.id == "" or not bar.Visible or not usable() or modalOpen() or pending then return end
	invoke("PlaygroundShopRequest", "SelectToy", index)
end

refresh = function()
	if not alive then return end
	local hasToy = false
	for _, record in ipairs(slots) do if record.id ~= "" then hasToy = true break end end
	local available = usable()
	bar.Visible = hasToy and player:GetAttribute("PCDataReady") == true and not inRound() and not sessionControlsBusy() and not modalOpen()
	showNativeBackpack(not (hasToy and player:GetAttribute("PCDataReady") == true and not inRound() and gui.Enabled))
	local now = workspace:GetServerTimeNow()
	local remaining = math.max(0, cooldownEndsAt(activeId) - now)
	local item = catalog.ById[activeId]
	local actionPending = item and item.toyActionPending == true
	local character = player.Character
	local heldTool = character and character:FindFirstChildOfClass("Tool")
	local heldId = heldTool and heldTool:GetAttribute("CatalogId")
	for index, record in ipairs(slots) do
		local selected = index == activeIndex and record.id ~= ""
		local selectionTag = record.button:FindFirstChild("Selected")
		selectionTag.Visible = selected
		selectionTag.Text = selected and heldId == record.id and "HELD" or "READY"
		record.button.Key.TextColor3 = selected and Color3.fromRGB(255, 215, 74) or Color3.fromRGB(255, 249, 224)
		record.button.Active = available and not pending and record.id ~= ""
		record.button.Selectable = record.button.Active
		record.button.ReusableSkin.ImageColor3 = record.id == "" and Color3.fromRGB(155, 155, 155) or Color3.new(1, 1, 1)
	end
	bar.Use.Active = available and not pending and activeId ~= "" and remaining <= 0 and not actionPending
	bar.Use.Selectable = bar.Use.Active
	local label = pending and "WAIT..." or actionPending and "SOON" or remaining > 0 and string.format("%.1fs", remaining) or "USE"
	bar.Use.Text = label
	bar.Use.LiveCaption.Text = label
	bar.Use.ReusableSkin.ImageColor3 = bar.Use.Active and Color3.new(1, 1, 1) or Color3.fromRGB(165, 165, 165)
	bar.Status.Text = now < noticeUntil and notice or not available and "Respawning..." or activeId == "" and "Select a toy" or actionPending and "Action coming soon" or UserInputService.TouchEnabled and "Tap a slot, then USE" or "1–4 select • click to use"
	local ember = tonumber(player:GetAttribute("PCToyEmberUntil")) or 0
	gui.Crosshair.Visible = bar.Visible and available and (activeId == "M10" or activeId == "M07" and ember > now)
end

for index = 1, 4 do
	local button = bar.Slots:WaitForChild("Slot" .. tostring(index))
	local record = { button = button, id = nil, generation = 0 }
	table.insert(slots, record)
	connect(button.Activated, function() selectToy(index) end)
	connect(button.Thumbnail:GetPropertyChangedSignal("IsLoaded"), function() refreshThumbnail(record) end)
end
connect(bar.Use.Activated, function() useToy(nil) end)
local numberKeys = { [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four] = 4 }
connect(UserInputService.InputBegan, function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	local index = numberKeys[input.KeyCode]
	if index then selectToy(index)
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then useToy(UserInputService:GetMouseLocation())
	elseif input.KeyCode == Enum.KeyCode.ButtonR2 then useToy(nil) end
end)
connect(UserInputService.TouchTapInWorld, function(position, processed)
	if not processed and not UserInputService:GetFocusedTextBox() then useToy(position) end
end)
connect(player:GetAttributeChangedSignal("PCToyLoadoutVersion"), syncLoadout)
for _, key in ipairs({ "PCDataReady", "PCToyRoundPreparing", "BBParticipating", "TGParticipating", "MDParticipating", "HSParticipating", "PCToyEmberUntil", "PCToyEmberShotUntil" }) do
	connect(player:GetAttributeChangedSignal(key), refresh)
end
for index = 1, 25 do connect(player:GetAttributeChangedSignal(string.format("PCToyCooldown_M%02d", index)), refresh) end
local elapsed = 0
connect(RunService.Heartbeat, function(delta)
	elapsed += delta
	if elapsed >= 0.1 then elapsed = 0 refresh() end
end)
connect(script.Destroying, function()
	alive = false
	showNativeBackpack(true)
	bar.Visible = false
	gui.Crosshair.Visible = false
	requestToken += 1
	for _, connection in ipairs(connections) do connection:Disconnect() end
	for _, record in ipairs(slots) do
		record.generation += 1
	end
end)
syncLoadout()


]==] },
 { path = "StarterGui.PlaygroundAdminPanel.Controller", expected = 1444279992, source = [==[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local gui = script.Parent
gui.Enabled = false
for _, name in ipairs({ "Toggle", "AdminHub", "Panel", "CompactPanel", "CompactToggle" }) do
	local object = gui:FindFirstChild(name)
	if object then object.Visible = false end
end
local hub = gui:WaitForChild("AdminHub")
local pages = hub.Pages
local itemsPage = pages.Items
local catalog = require(ReplicatedStorage:WaitForChild("PlaygroundCatalog"))
local connections = {}
local busy = false
local opened = false
local tab = "Items"
local category = "All"
local page = 1
local pageCount = 1
local selectedUserId = player.UserId
local targetData = nil
local roster = {}
local slots = {}
local states = {}
local gameControls = {}
local limits = { coinsPerGrant = 1000000, levelsPerGrant = 100, maxLevel = 1000 }
local gold = Color3.fromRGB(255, 211, 78)
local blue = Color3.fromRGB(89, 193, 244)
local muted = Color3.fromRGB(194, 201, 206)
local green = Color3.fromRGB(130, 225, 180)
local mudActions = { MudStart = true, MudShooter = true, MudMedic = true }
local phases = { Waiting = "Ready", Countdown = "Countdown", Crossing = "Playing", Playing = "Playing", Hiding = "Hide now", Seeking = "Seekers released", Results = "Round finished", Intermission = "Next round" }
local gameNames = { BritishBulldog = "Bulldog", TagYoureIt = "Tag", StuckInTheMud = "Mud", HideAndSeek = "Hide and Seek", All = "total" }
local request

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end
for _, fallback in ipairs(gui:GetDescendants()) do
	if fallback.Name == "ArtFallback" and fallback:IsA("Frame") then
		local skin = fallback.Parent:FindFirstChild("ReusableSkin")
		if skin and skin:IsA("ImageLabel") then
			local function updateFallback() fallback.Visible = not skin.IsLoaded end
			connect(skin:GetPropertyChangedSignal("IsLoaded"), updateFallback)
			connect(skin:GetPropertyChangedSignal("Image"), updateFallback)
			updateFallback()
		end
	end
end
local function admin()
	return player:GetAttribute("PlaygroundAdmin") == true
end
local function caption(object, text)
	object.Text = text
	local live = object:FindFirstChild("LiveCaption")
	if live then live.Text = text end
end
local function enabled(button, value, color)
	button.Active = value
	button.Selectable = value
	button.AutoButtonColor = false
	button.BackgroundColor3 = value and (color or button:GetAttribute("ReadyColor") or blue) or muted
end
local function message(text)
	hub.Message.Text = tostring(text or "")
end
local function syncVisibility()
	local allowed = admin()
	gui.Enabled = allowed
	if not allowed then opened = false end
	hub.Visible = allowed and opened
	gui.Panel.Visible = false
	gui.CompactPanel.Visible = false
	gui.CompactToggle.Visible = false
	gui.Toggle.Visible = allowed
	caption(gui.Toggle, opened and "CLOSE" or "ADMIN")
	for _, pageObject in ipairs(pages:GetChildren()) do
		if pageObject:IsA("GuiObject") then pageObject.Visible = pageObject.Name == tab end
	end
	for _, button in ipairs(hub.Tabs:GetChildren()) do
		if button:IsA("TextButton") then enabled(button, allowed, button.Name == tab and gold or blue) end
	end
end
local function sortedRoster(source)
	local result = {}
	for _, entry in ipairs(source) do
		if typeof(entry.userId) == "number" and typeof(entry.name) == "string" then table.insert(result, entry) end
	end
	table.sort(result, function(a, b)
		if a.userId == player.UserId then return b.userId ~= player.UserId end
		if b.userId == player.UserId then return false end
		return string.lower(a.name) < string.lower(b.name)
	end)
	return result
end
local function refreshLocalRoster()
	local list = {}
	for _, current in ipairs(Players:GetPlayers()) do
		table.insert(list, { userId = current.UserId, name = current.Name, displayName = current.DisplayName, ready = current:GetAttribute("PCDataReady") == true })
	end
	roster = sortedRoster(list)
end
local function selectedEntry()
	for index, entry in ipairs(roster) do if entry.userId == selectedUserId then return entry, index end end
	return nil, nil
end
local function rewardReady()
	return admin() and not busy and targetData ~= nil and targetData.ready == true
end
local function syncTarget()
	local entry = selectedEntry()
	local own = selectedUserId == player.UserId
	local name = entry and ((entry.displayName or entry.name) .. " (@" .. entry.name .. ")") or "Player unavailable"
	hub.Target.PlayerName.Text = (own and "SELF · " or "") .. name
	hub.Target.PlayerStats.Text = targetData and targetData.ready and (tostring(targetData.coins or 0) .. " coins · Level " .. tostring(targetData.level or 1)) or "Profile loading..."
	enabled(hub.Target.Previous, admin() and not busy and #roster > 1)
	enabled(hub.Target.Next, admin() and not busy and #roster > 1)
	enabled(hub.Target.Self, admin() and not busy, own and gold or blue)
	enabled(pages.Rewards.Coins.GrantCoins, rewardReady())
	enabled(pages.Rewards.Levels.AddLevels, rewardReady())
	local entitlements = targetData and targetData.entitlements or {}
	for _, kind in ipairs({ "VIP", "BetaTester" }) do
		local button = pages.Rewards.Entitlements["Grant" .. kind]
		local granted = entitlements[kind] == true
		local label = kind == "VIP" and "VIP" or "BETA TESTER"
		caption(button, busy and "WAIT..." or granted and (label .. " ACTIVE") or ("GRANT " .. label))
		enabled(button, rewardReady() and not granted, kind == "VIP" and gold or green)
	end
end
local function unlockText(item)
	local unlock = item.unlock
	if not unlock or unlock.kind == "Starter" then return "Starter reward" end
	if unlock.kind == "Coins" then return tostring(item.price) .. " coins" end
	if unlock.kind == "Level" then return "Level " .. tostring(unlock.amount) end
	if unlock.kind == "VIP" then return "VIP reward" end
	if unlock.kind == "BetaTester" then return "Beta Tester reward" end
	return tostring(unlock.amount) .. " " .. (gameNames[unlock.gameId] or "total") .. " wins"
end
local function syncItems()
	local query = string.lower(string.sub(itemsPage.Search.Value.Text, 1, 100))
	local matches = {}
	for _, item in ipairs(catalog.Items) do
		if (category == "All" or item.category == category) and (query == "" or string.find(string.lower(item.id .. " " .. item.name), query, 1, true)) then table.insert(matches, item) end
	end
	pageCount = math.max(1, math.ceil(#matches / #slots))
	page = math.clamp(page, 1, pageCount)
	itemsPage.Empty.Visible = #matches == 0
	itemsPage.Pager.PageLabel.Text = tostring(page) .. " / " .. tostring(pageCount)
	enabled(itemsPage.Pager.Previous, page > 1 and not busy)
	enabled(itemsPage.Pager.Next, page < pageCount and not busy)
	for index, record in ipairs(slots) do
		local item = matches[(page - 1) * #slots + index]
		record.item = item
		record.row.Visible = item ~= nil
		if item then
			record.row:SetAttribute("CatalogId", item.id)
			local owned = targetData and targetData.owned and targetData.owned[item.id] == true
			local equipped = targetData and targetData.equipped and targetData.equipped[item.slot] == item.id
			record.row.ItemName.Text = item.id .. " · " .. item.name
			record.row.Detail.Text = item.category .. " · " .. (equipped and "Equipped" or owned and "Owned" or unlockText(item))
			caption(record.row.Grant, busy and "WAIT..." or owned and "OWNED" or "GRANT")
			caption(record.row.GrantEquip, busy and "WAIT..." or equipped and "EQUIPPED" or owned and "EQUIP" or "GRANT + EQUIP")
			enabled(record.row.Grant, rewardReady() and not owned and item.available ~= false)
			enabled(record.row.GrantEquip, rewardReady() and not equipped and item.available ~= false, green)
		end
	end
	for _, id in ipairs({ "All", "Bats", "Pets", "Toys" }) do enabled(itemsPage.Filters[id], admin(), id == category and gold or blue) end
end
local function syncRounds()
	local mud = states.MudState
	for action, button in pairs(gameControls) do
		local allowed = admin() and not busy and (not mudActions[action] or mud and mud:GetAttribute("GunAccessReady") == true)
		enabled(button, allowed)
	end
	for id, stateName in pairs({ BritishBulldog = "BritishBulldogState", TagYoureIt = "TagState", StuckInTheMud = "MudState", HideAndSeek = "HideAndSeekState" }) do
		local state = states[stateName]
		local phase = state and state:GetAttribute("Phase") or "Waiting"
		local mode = state and state:GetAttribute("Mode") or ""
		local text = (string.find(mode, "Practice", 1, true) and "Solo practice · " or "") .. (phases[phase] or phase)
		if id == "StuckInTheMud" and (not mud or mud:GetAttribute("GunAccessReady") ~= true) then text = "Gun access pending" end
		pages.Rounds[id].Status.Text = text
	end
	local state = states.PlaygroundState
	caption(gameControls.ToggleAutomatic, state and state:GetAttribute("AutomaticRounds") == true and "AUTO ROUNDS: ON" or "AUTO ROUNDS: OFF")
end
local function sync()
	syncVisibility()
	syncTarget()
	syncItems()
	syncRounds()
end
local function applyReply(reply, requestedTarget)
	if typeof(reply.players) == "table" then roster = sortedRoster(reply.players) end
	if typeof(reply.limits) == "table" then
		for key in pairs(limits) do if typeof(reply.limits[key]) == "number" then limits[key] = reply.limits[key] end end
	end
	if requestedTarget == selectedUserId and typeof(reply.target) == "table" and reply.target.userId == selectedUserId then targetData = reply.target end
end
request = function(action, payload, quiet)
	if not admin() or busy then return end
	if mudActions[action] and (not states.MudState or states.MudState:GetAttribute("GunAccessReady") ~= true) then return end
	local remote = ReplicatedStorage:FindFirstChild("PlaygroundAdminRequest")
	if not remote or not remote:IsA("RemoteFunction") then message("Admin controls are getting ready.") return end
	local requestedTarget = selectedUserId
	payload = payload or {}
	payload.targetUserId = requestedTarget
	busy = true
	sync()
	task.spawn(function()
		local ok, reply = pcall(function() return remote:InvokeServer(action, payload) end)
		busy = false
		if not gui.Parent then return end
		if ok and typeof(reply) == "table" then
			applyReply(reply, requestedTarget)
			if not quiet or not reply.ok then message(reply.message or (reply.ok and "Done." or "Request did not complete.")) end
		else message("Server unavailable. Try again.") end
		sync()
		if requestedTarget ~= selectedUserId and admin() then task.defer(function() request("GetStatus", nil, true) end) end
	end)
end
local function selectTarget(userId)
	if busy then return end
	selectedUserId = userId
	targetData = nil
	message("Rewards will go to the selected player.")
	sync()
	request("GetStatus", nil, true)
end
local function cycleTarget(direction)
	if busy or #roster == 0 then return end
	local _, index = selectedEntry()
	selectTarget(roster[((index or 1) - 1 + direction) % #roster + 1].userId)
end
for _, row in ipairs(itemsPage.Rows:GetChildren()) do
	if row:IsA("Frame") and row:FindFirstChild("Grant") then table.insert(slots, { row = row }) end
end
table.sort(slots, function(a, b) return a.row.Name < b.row.Name end)
for _, record in ipairs(slots) do
	connect(record.row.Grant.Activated, function()
		if record.item and record.row.Grant.Active then request("GrantItem", { itemId = record.item.id, equip = false }) end
	end)
	connect(record.row.GrantEquip.Activated, function()
		if record.item and record.row.GrantEquip.Active then request("GrantItem", { itemId = record.item.id, equip = true }) end
	end)
end
for _, id in ipairs({ "All", "Bats", "Pets", "Toys" }) do
	connect(itemsPage.Filters[id].Activated, function() category = id page = 1 itemsPage.Rows.CanvasPosition = Vector2.zero syncItems() end)
end
connect(itemsPage.Search.Value:GetPropertyChangedSignal("Text"), function() page = 1 itemsPage.Rows.CanvasPosition = Vector2.zero syncItems() end)
for _, spec in ipairs({ { "Previous", -1 }, { "Next", 1 } }) do
	connect(itemsPage.Pager[spec[1]].Activated, function()
		if busy then return end
		page = math.clamp(page + spec[2], 1, pageCount)
		itemsPage.Rows.CanvasPosition = Vector2.zero
		syncItems()
	end)
end
local function grantAmount(action, box, maximum)
	if not rewardReady() then return end
	local amount = tonumber(box.Text)
	if not amount or amount ~= amount or amount % 1 ~= 0 or amount < 1 or amount > maximum then
		message("Enter a whole number from 1 to " .. tostring(maximum) .. ".")
		return
	end
	request(action, { amount = amount })
end
connect(pages.Rewards.Coins.GrantCoins.Activated, function() grantAmount("GrantCoins", pages.Rewards.Coins.Amount.Value, limits.coinsPerGrant) end)
connect(pages.Rewards.Levels.AddLevels.Activated, function() grantAmount("AddLevels", pages.Rewards.Levels.Amount.Value, limits.levelsPerGrant) end)
for _, kind in ipairs({ "VIP", "BetaTester" }) do
	local button = pages.Rewards.Entitlements["Grant" .. kind]
	connect(button.Activated, function()
		if button.Active and rewardReady() then request("Grant" .. kind) end
	end)
end
connect(hub.Target.Previous.Activated, function() cycleTarget(-1) end)
connect(hub.Target.Next.Activated, function() cycleTarget(1) end)
connect(hub.Target.Self.Activated, function() selectTarget(player.UserId) end)
for _, button in ipairs(hub.Tabs:GetChildren()) do
	if button:IsA("TextButton") then connect(button.Activated, function() tab = button.Name syncVisibility() end) end
end
for _, name in ipairs({ "BBStart", "BBRunner", "BBBulldog", "TagStart", "TagRunner", "TagTagger", "MudStart", "MudShooter", "MudMedic", "HSStart", "StopRound", "ToggleAutomatic" }) do
	local control = pages.Rounds:FindFirstChild(name, true)
	gameControls[name] = control
	connect(control.Activated, function() if control.Active then request(name) end end)
end
local function toggle()
	if not admin() then return end
	opened = not opened
	syncVisibility()
	if opened then refreshLocalRoster() request("GetStatus", nil, true) end
end
connect(gui.Toggle.Activated, toggle)
connect(hub.Close.Activated, function() opened = false syncVisibility() end)
connect(UserInputService.InputBegan, function(input, processed)
	if not processed and not UserInputService:GetFocusedTextBox() and input.KeyCode == Enum.KeyCode.F6 then toggle() end
end)
connect(player:GetAttributeChangedSignal("PlaygroundAdmin"), sync)
connect(Players.PlayerAdded, function() refreshLocalRoster() syncTarget() end)
connect(Players.PlayerRemoving, function(leaving)
	for index = #roster, 1, -1 do if roster[index].userId == leaving.UserId then table.remove(roster, index) end end
	if leaving.UserId == selectedUserId then selectedUserId = player.UserId targetData = nil message("Player left. Rewards now target you.") end
	sync()
	if opened and not busy then request("GetStatus", nil, true) end
end)
local function bindState(object)
	if not ({ PlaygroundState = true, BritishBulldogState = true, TagState = true, MudState = true, HideAndSeekState = true })[object.Name] or states[object.Name] == object then return end
	states[object.Name] = object
	connect(object.AttributeChanged, syncRounds)
	syncRounds()
end
for _, name in ipairs({ "PlaygroundState", "BritishBulldogState", "TagState", "MudState", "HideAndSeekState" }) do
	local object = ReplicatedStorage:FindFirstChild(name)
	if object then bindState(object) end
end
connect(ReplicatedStorage.ChildAdded, bindState)
connect(script.Destroying, function() for _, connection in ipairs(connections) do connection:Disconnect() end end)
refreshLocalRoster()
sync()
]==] },
}
local function fingerprint(source)
 source = string.gsub(source, "\r\n", "\n")
 local value = 0
 for index = 1, #source do value = (value * 31 + string.byte(source,index)) % 2147483647 end
 return value
end
local objects = {}
for _, entry in entries do
 local object = game
 for name in string.gmatch(entry.path, "[^.]+") do object = object:FindFirstChild(name) assert(object, "Missing " .. entry.path) end
 assert(object:IsA("LuaSourceContainer"), "Invalid script " .. entry.path)
 assert(fingerprint(object.Source) == entry.expected, "Source changed: " .. entry.path)
 objects[entry.path] = object
end
local storage = game:GetService("ServerStorage")
local backup = storage:FindFirstChild("HideAndSeekIntegrationBackup20261010")
if not backup then backup = Instance.new("Folder") backup.Name, backup.Parent = "HideAndSeekIntegrationBackup20261010",storage end
for _, entry in entries do
 local object = objects[entry.path]
 local snapshot = object:Clone()
 snapshot.Name = entry.path
 if snapshot:IsA("BaseScript") then snapshot.Enabled = false end
 snapshot.Parent = backup
 object.Source = entry.source
 object:SetAttribute("HideAndSeekIntegrated20261010",true)
end
return { patched = #entries, capabilitiesPreserved = true, backup = backup:GetFullName() }

