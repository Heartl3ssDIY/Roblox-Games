assert(not game:GetService("RunService"):IsRunning(), "Checks run in Edit mode")
local existing = game.StarterGui:FindFirstChild("DuckDuckGooseHUD")
assert(existing, "Install the authored HUD before checks")
local root = Instance.new("Folder")
local gui = existing:Clone()
gui.Enabled = true
gui.Parent = root
local session = Instance.new("Folder")
session.Name, session.Parent = "PlaygroundSessionControls", root
local failures, count = {}, 0
local function check(condition, message)
	count += 1
	if not condition then table.insert(failures, message) end
end
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, callback)
			callbacks[callback] = true
			return {Disconnect = function() callbacks[callback] = nil end}
		end,
		Fire = function(_, ...)
			for callback in pairs(callbacks) do callback(...) end
		end,
	}
end
local signals = {}
local function makePlayer(id, role, position)
	local character = Instance.new("Model")
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = character
	local part = Instance.new("Part")
	part.Name, part.Position, part.Parent = "HumanoidRootPart", position, character
	local value = {UserId = id, Character = character, CharacterRemoving = signal(), attrs = {DGParticipating = true, DGRole = role, DGStamina = 5, DGMaxStamina = 5}}
	function value:GetAttribute(name) return self.attrs[name] end
	function value:GetAttributeChangedSignal(name)
		local key = tostring(id) .. name
		signals[key] = signals[key] or signal()
		return signals[key]
	end
	return value
end
local player = makePlayer(1, "Picker", Vector3.new(0, 3, 0))
local duck = makePlayer(2, "Duck", Vector3.new(0, 3, 5))
local players = {LocalPlayer = player, GetPlayers = function() return {player, duck} end}
local state = Instance.new("Folder")
state:SetAttribute("Phase", "Playing")
state:SetAttribute("TurnPhase", "Choosing")
state:SetAttribute("EndsAt", 1180)
state:SetAttribute("TurnEndsAt", 1015)
state:SetAttribute("AliveCount", 16)
local round = Instance.new("Folder")
round:SetAttribute("ActiveGame", "DuckDuckGoose")
local calls, actions = {}, {}
local remotes = {
	DuckDuckGooseState = state,
	PlaygroundState = round,
	DuckDuckGooseSprintRequest = {FireServer = function(_, value) table.insert(calls, value) end},
	DuckDuckGooseActionRequest = {FireServer = function(_, ...) table.insert(actions, {...}) end},
}
local storage = {WaitForChild = function(_, name) return assert(remotes[name], name) end, FindFirstChild = function(_, name) return remotes[name] end}
local textBox
local input = {TouchEnabled = false, InputEnded = signal(), WindowFocusReleased = signal(), WindowFocused = signal(), GetFocusedTextBox = function() return textBox end}
local bindings = {}
local context = {BindAction = function(_, name, callback) bindings[name] = callback end, UnbindAction = function(_, name) bindings[name] = nil end}
local menu = {MenuIsOpen = false}
local heartbeat = signal()
local arena = Instance.new("Folder")
arena.Name = "Duck Duck Goose"
local gameplay = Instance.new("Folder") gameplay.Name, gameplay.Parent = "Gameplay", arena
local seats = Instance.new("Folder") seats.Name, seats.Parent = "Seats", gameplay
local seat = Instance.new("Model") seat.Name, seat.Parent = "Seat01", seats
seat:SetAttribute("DGSeatedUserId", 2)
local seatPart = Instance.new("Seat") seatPart.Parent = seat
local prompt = Instance.new("ProximityPrompt") prompt:SetAttribute("DGGoosePrompt", true) prompt.Parent = seatPart
local world = {CurrentCamera = {ViewportSize = Vector2.new(1920, 1080)}, GetServerTimeNow = function() return 1000 end, FindFirstChild = function(_, name) return name == arena.Name and arena or nil end}
local services = {Players = players, ReplicatedStorage = storage, UserInputService = input, ContextActionService = context, GuiService = menu, RunService = {Heartbeat = heartbeat}}
local mockGame = {GetService = function(_, name) return assert(services[name], name) end}
local destroying = signal()
local authored = {}
for _, name in {"DesktopHeader", "CompactHeader", "PortraitHeader", "DesktopSprint", "MobileSprint", "ChooseGoose"} do
	local item = gui[name]
	authored[name] = {Position = item.Position, Size = item.Size, AnchorPoint = item.AnchorPoint}
end
local function refresh() heartbeat:Fire(.11) end
local ok, problem = xpcall(function()
	local controllerApi = (function(script, game, workspace)
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
	local lap = math.clamp(finite(state:GetAttribute("LapProgress"), 0), 0, 1)
	local instruction = "Stay seated until you are chosen"
	if role == "Picker" then instruction = "Walk to a duck and call GOOSE!"
	elseif role == "Runner" then instruction = lap >= 1 and "Take the gold seat!" or "Run a full lap, then take the gold seat"
	elseif role == "Goose" then instruction = "Swing your bat to catch the runner" end
	if eliminated then instruction = "You are out. Watch the remaining ducks!" end
	if turn == "FinalDuck" then instruction = "You are the last duck standing!" end
	if watching then instruction = "Watching Duck Duck Goose" end
	if phase == "Countdown" then instruction = "Get ready! One player will choose a goose"
	elseif phase == "Results" then instruction = "Surviving ducks win the round" end
	local counts = string.format("%d still in", alive)
	if phase == "Playing" and turn == "Chasing" then counts = string.format("%d in · LAP %d%%", alive, math.floor(lap * 100))
	elseif phase == "Playing" and turn == "Choosing" then
		local choiceSeconds = math.max(0, math.ceil(finite(state:GetAttribute("TurnEndsAt"), now) - now))
		counts = string.format("%d in · Choose: %ds", alive, choiceSeconds)
	end
	for _, header in headers do
		header.Visible = shown and header == selectedHeader
		header.Title.Text = phase == "Results" and "ROUND FINISHED" or "DUCK DUCK GOOSE"
		header.Timer.Text = phase == "Countdown" and tostring(state:GetAttribute("CountdownValue") or 3)
			or phase == "Results" and "" or clock(seconds)
		header.Role.Text = watching and "WATCHING" or eliminated and "OUT" or string.upper(role)
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
for _, name in {"DGParticipating", "DGRole", "DGEliminated", "DGRagdolled", "DGStamina", "DGMaxStamina"} do
	connect(player:GetAttributeChangedSignal(name), refresh)
end
connect(player.CharacterRemoving, clearInputs)
connect(gui:GetPropertyChangedSignal("Enabled"), refresh)
connect(RunService.Heartbeat, function(delta)
	elapsed += delta
	if elapsed >= 0.1 then elapsed = 0 refresh() end
end)
connect(script.Destroying, function()
	clearInputs()
	ContextActionService:UnbindAction("DuckDuckGooseSprint")
	for _, connection in connections do connection:Disconnect() end
end)
refresh()

		return {Choose = chooseGoose}
	end)({Parent = gui, Destroying = destroying}, mockGame, world)
	check(gui.DesktopHeader.Visible and not gui.CompactHeader.Visible, "Desktop header selected")
	check(gui.DesktopHeader.Timer.Text == "3:00", "Three-minute timer displayed")
	check(gui.DesktopHeader.Role.Text == "PICKER", "Picker role displayed")
	check(gui.ChooseGoose.Visible and gui.ChooseGoose.Active, "Picker can choose nearby duck")
	check(prompt.Enabled, "Picker sees occupied duck prompt")
	controllerApi.Choose()
	check(#actions == 1 and actions[1][1] == "ChooseGoose" and actions[1][2] == 2, "Goose button requests the nearby seated player")
	local sprint = assert(bindings.DuckDuckGooseSprint)
	local key = {KeyCode = Enum.KeyCode.LeftShift}
	sprint(nil, Enum.UserInputState.Begin, key)
	check(calls[#calls] == true, "Shift starts sprint")
	player.attrs.DGStamina = 0 refresh()
	check(calls[#calls] == true, "Empty stamina does not clear held input")
	player.attrs.DGStamina = .1 refresh()
	check(calls[#calls] == true, "Partial recharge remains usable while held")
	local priorCalls = #calls
	player.attrs.DGRole = "Runner" state:SetAttribute("TurnPhase", "Chasing") refresh()
	check(#calls > priorCalls and calls[#calls] == true, "Held sprint reasserts after Picker becomes Runner")
	player.attrs.DGRole = "Goose" refresh()
	priorCalls = #calls
	player.attrs.DGRole = "Picker" state:SetAttribute("TurnPhase", "Choosing") refresh()
	check(#calls > priorCalls and calls[#calls] == true, "Held sprint reasserts after Goose becomes Picker")
	sprint(nil, Enum.UserInputState.End, key)
	check(calls[#calls] == false, "Shift release stops sprint")
	for _, viewport in {Vector2.new(568, 320), Vector2.new(844, 390), Vector2.new(1024, 768), Vector2.new(1366, 1024), Vector2.new(320, 568)} do
		world.CurrentCamera.ViewportSize = viewport
		input.TouchEnabled = true
		refresh()
		local selected = viewport.Y > viewport.X and gui.PortraitHeader or gui.CompactHeader
		check(selected.Visible and not gui.DesktopHeader.Visible, "Compact header selected " .. tostring(viewport))
		check(gui.MobileSprint.Visible and not gui.DesktopSprint.Visible, "Touch sprint selected " .. tostring(viewport))
		local button = gui.MobileSprint
		local width, height = button.Size.X.Offset, button.Size.Y.Offset
		local right, bottom = viewport.X + button.Position.X.Offset, viewport.Y + button.Position.Y.Offset
		check(right - width > viewport.X * .5 and right <= viewport.X and bottom - height >= 0, "Sprint safely on right " .. tostring(viewport))
		check(width >= 44 and height >= 44 and bottom <= viewport.Y - 100, "Touch target clear of jump area " .. tostring(viewport))
		check(selected.Size.X.Offset <= viewport.X - 24 and selected.Size.Y.Offset <= 80, "Header stays compact " .. tostring(viewport))
	end
	player.attrs.DGRole = "Runner"
	state:SetAttribute("TurnPhase", "Chasing")
	state:SetAttribute("LapProgress", .5)
	refresh()
	check(not gui.ChooseGoose.Visible and not prompt.Enabled, "Runner cannot choose another goose")
	controllerApi.Choose()
	check(#actions == 1, "Runner cannot send another choice")
	check(gui.PortraitHeader.Counts.Text:find("50%%") ~= nil, "Lap progress displayed")
	state:SetAttribute("LapProgress", 1) refresh()
	check(gui.PortraitHeader.Hint.Text == "Take the gold seat!", "Completed lap gives seat instruction")
	player.attrs.DGRole = "Goose" refresh()
	check(gui.MobileSprint.Visible and gui.PortraitHeader.Hint.Text:find("bat") ~= nil, "Goose has chase controls")
	player.attrs.DGRole = "Duck" refresh()
	check(not gui.MobileSprint.Visible and not gui.ChooseGoose.Visible and not prompt.Enabled, "Seated duck controls hidden")
	player.attrs.DGRole, player.attrs.DGParticipating, player.attrs.DGEliminated = "Spectator", false, true
	refresh()
	check(gui.PortraitHeader.Visible and gui.PortraitHeader.Role.Text == "OUT", "Eliminated player sees spectator status")
	player.attrs.DGEliminated = false session:SetAttribute("Spectating", true) refresh()
	check(gui.PortraitHeader.Visible and gui.PortraitHeader.Role.Text == "WATCHING", "External spectator sees game status")
	session:SetAttribute("Spectating", false) refresh()
	check(not gui.PortraitHeader.Visible, "Unrelated lobby player has no game HUD")
	player.attrs.DGParticipating, player.attrs.DGRole = true, "Picker"
	state:SetAttribute("TurnPhase", "Choosing") refresh()
	sprint(nil, Enum.UserInputState.Begin, key)
	session:SetAttribute("SessionMenuOpen", true) refresh()
	check(calls[#calls] == false and not gui.PortraitHeader.Visible, "Menu stops sprint and hides game HUD")
	session:SetAttribute("SessionMenuOpen", false) refresh()
	sprint(nil, Enum.UserInputState.Begin, key)
	input.WindowFocusReleased:Fire()
	check(calls[#calls] == false, "Focus loss stops sprint")
	input.WindowFocused:Fire()
	textBox = {} sprint(nil, Enum.UserInputState.Begin, key)
	check(calls[#calls] == false, "Typing cannot start sprint")
	textBox = nil
	gui.Enabled = false refresh()
	check(not gui.MobileSprint.Visible and not prompt.Enabled, "Disabled GUI leaves no controls active")
	gui.Enabled = true refresh()
	for name, properties in pairs(authored) do
		for property, original in pairs(properties) do check(gui[name][property] == original, name .. " authored " .. property .. " preserved") end
	end
	destroying:Fire()
	check(bindings.DuckDuckGooseSprint == nil, "Sprint binding cleaned up")
end, debug.traceback)
if not ok then table.insert(failures, problem) end
destroying:Fire()
root:Destroy() arena:Destroy() state:Destroy() round:Destroy()
player.Character:Destroy() duck.Character:Destroy()
return {passed = #failures == 0, checks = count, failures = failures, livePlayersChanged = false}
