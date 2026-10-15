assert(not game:GetService("RunService"):IsRunning(), "Edit only")
local storage = game:GetService("ServerStorage")
local fixture = Instance.new("Folder")
fixture.Name = "PushUiNativeFixture20261008"
fixture.Parent = storage
local report = { checks = {}, errors = {}, geometry = {} }
local rendered
local function check(name, passed)
	table.insert(report.checks, { name = name, passed = passed == true })
	assert(passed, name)
end
local function signal()
	local handlers = {}
	local object = {}
	function object:Connect(callback)
		local entry = { callback = callback, active = true }
		table.insert(handlers, entry)
		return { Disconnect = function() entry.active = false end }
	end
	function object:Fire(...)
		for _, entry in handlers do if entry.active then entry.callback(...) end end
	end
	return object
end
local ok, failure = xpcall(function()
	for _, name in { "TagHUD", "BritishBulldogHUD", "PlaygroundBatControls" } do
		local clone = game.StarterGui[name]:Clone()
		for _, child in clone:GetDescendants() do if child:IsA("BaseScript") then child:Destroy() end end
		clone.Enabled = true
		clone.Parent = fixture
	end
	local buildModule = Instance.new("ModuleScript")
	buildModule.Source = [======[return function(starterGui)
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
]======]
	buildModule.Parent = fixture
	local gui = Instance.new("ScreenGui")
	gui.Name = "PlaygroundPushControls"
	gui.Parent = fixture
	local buttonSet = require(buildModule)(fixture)
	local character = Instance.new("Model")
	character.Parent = fixture
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = character
	local attrs = { PCDataReady = true, BBParticipating = true, BBRole = "Runner", BBStatus = "Crossing" }
	local player = { Character = character, CharacterAdded = signal(), CharacterRemoving = signal(), AttributeChanged = signal() }
	function player:GetAttribute(name) return attrs[name] end
	local states = {}
	for name, phase in { BritishBulldogState = "Crossing", TagState = "Playing" } do
		local state = Instance.new("Folder")
		state.Name = name
		state:SetAttribute("Phase", phase)
		state.Parent = fixture
		states[name] = state
	end
	local requests, requestedArguments = 0, 0
	local remote = {}
	function remote:IsA(kind) return kind == "RemoteEvent" end
	function remote:FireServer(...) requests += 1 requestedArguments = select("#", ...) end
	states.PlaygroundPushRequest = remote
	local textFocus, lastInput = nil, Enum.UserInputType.Keyboard
	local input = { TouchEnabled = false, KeyboardEnabled = true, WindowFocusReleased = signal(), WindowFocused = signal(), LastInputTypeChanged = signal() }
	function input:GetFocusedTextBox() return textFocus end
	function input:GetLastInputType() return lastInput end
	function input:GetStringForKeyCode(key) assert(key == Enum.KeyCode.ButtonX) return "X" end
	local menu = { MenuIsOpen = false }
	local heartbeat = signal()
	local clock, serverClock = 40, 200
	local actionCallback, binds, unbinds = nil, 0, 0
	local context = {}
	function context:BindActionAtPriority(name, callback, touch, priority, first, second)
		check("Action binds Q and X with no auto-generated touch button", name == "PlaygroundPush" and first == Enum.KeyCode.Q and second == Enum.KeyCode.ButtonX and touch == false)
		actionCallback = callback binds += 1
	end
	function context:UnbindAction(name) actionCallback = nil unbinds += 1 end
	local activation = { TagHUD = signal(), BritishBulldogHUD = signal(), PushUiNativeFixture20261008 = signal() }
	local destroying = signal()
	local services = {
		Players = { LocalPlayer = player }, UserInputService = input, GuiService = menu,
		RunService = { Heartbeat = heartbeat }, ContextActionService = context,
		ReplicatedStorage = { FindFirstChild = function(_, name) return states[name] end },
	}
	local env = {
		game = { GetService = function(_, name) return assert(services[name], name) end },
		workspace = { GetServerTimeNow = function() return serverClock end },
		os = { clock = function() return clock end },
		script = { Parent = gui, Destroying = destroying }, activation = activation,
	}
	local source = [======[local Players = game:GetService("Players")
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
		return UserInputService:GetStringForKeyCode(Enum.KeyCode.ButtonX)
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
	local replaced, replacements = source:gsub("connect%(entry%.button%.Activated, push%)", "connect(env.activation[entry.button.Parent.Parent.Name], push)")
	check("Only native click signals substituted", replacements == 1)
	local module = Instance.new("ModuleScript")
	module.Name = "ExactControllerCapabilityFixture"
	module.Sandboxed = true
	module.Capabilities = SecurityCapabilities.new(
		Enum.SecurityCapability.RunClientScript, Enum.SecurityCapability.RunServerScript, Enum.SecurityCapability.Basic,
		Enum.SecurityCapability.Players, Enum.SecurityCapability.Input, Enum.SecurityCapability.UI,
		Enum.SecurityCapability.Physics, Enum.SecurityCapability.RemoteEvent, Enum.SecurityCapability.AccessOutsideWrite,
		Enum.SecurityCapability.AvatarBehavior)
	module.Source = "return function(env)\nlocal game = env.game\nlocal workspace = env.workspace\nlocal script = env.script\nlocal os = env.os\n" .. replaced .. "\nreturn { refresh=refresh }\nend"
	module.Parent = fixture
	local controller = require(module)(env)
	local authored = {}
	for id, button in buttonSet do authored[id] = { button.Position, button.Size, button.AnchorPoint } end
	local function advance(seconds)
		clock += seconds serverClock += seconds heartbeat:Fire(0.1)
	end
	check("Bulldog Runner shows Push at editable authored location", buttonSet.Bulldog.Visible and buttonSet.Bulldog.Active and not buttonSet.Tag.Visible)
	check("Desktop hint is Q", buttonSet.Bulldog.Hint.Text == "[Q]")
	activation.BritishBulldogHUD:Fire()
	check("Tap sends one no-argument request", requests == 1 and requestedArguments == 0)
	activation.BritishBulldogHUD:Fire()
	check("Rapid repeat blocked", requests == 1 and not buttonSet.Bulldog.Active)
	advance(0.36)
	check("Server rejection without cooldown unlocks after short debounce", buttonSet.Bulldog.Active)
	attrs.PCPushReadyAt = serverClock + 3
	controller.refresh()
	check("Server cooldown governs button", not buttonSet.Bulldog.Active and buttonSet.Bulldog.Hint.Text == "3.0s")
	attrs.PCPushReadyAt = nil controller.refresh()
	local function hidden(name, change, restore)
		change() controller.refresh()
		check(name .. " hides and unbinds", not buttonSet.Bulldog.Visible and not buttonSet.Tag.Visible and not buttonSet.Mobile.Visible and actionCallback == nil)
		local before = requests activation.BritishBulldogHUD:Fire() activation.TagHUD:Fire()
		check(name .. " cannot send request", requests == before)
		restore() controller.refresh()
	end
	hidden("Lobby", function() attrs.BBParticipating = false end, function() attrs.BBParticipating = true end)
	hidden("Mud", function() attrs.MDParticipating = true end, function() attrs.MDParticipating = nil end)
	hidden("Countdown", function() states.BritishBulldogState:SetAttribute("Phase", "Countdown") end, function() states.BritishBulldogState:SetAttribute("Phase", "Crossing") end)
	hidden("Safe zone", function() attrs.BBStatus = "Safe" end, function() attrs.BBStatus = "Crossing" end)
	hidden("Not departed", function() attrs.BBStatus = "Leave the safe zone" end, function() attrs.BBStatus = "Crossing" end)
	hidden("Tagged prisoner", function() attrs.BBRole = "Tagged" end, function() attrs.BBRole = "Runner" end)
	hidden("Dead player", function() humanoid.Health = 0 end, function() humanoid.Health = 100 end)
	hidden("Seated player", function() humanoid.Sit = true end, function() humanoid.Sit = false end)
	for _, attribute in { "BBRagdolled", "TGRagdolled", "PCPushed" } do
		hidden(attribute, function() attrs[attribute] = true end, function() attrs[attribute] = nil end)
	end
	attrs.BBRole, attrs.BBStatus = "Bulldog", "Bulldog" controller.refresh()
	check("Bulldog role also gets Push", buttonSet.Bulldog.Active)
	hidden("Frozen forfeiting Bulldog", function() attrs.BBStatus = "Departure expired" end, function() attrs.BBStatus = "Bulldog" end)
	attrs.BBParticipating, attrs.TGParticipating, attrs.TGRole = false, true, "Runner" controller.refresh()
	check("Tag Runner Playing gets Push", buttonSet.Tag.Active and not buttonSet.Bulldog.Visible)
	hidden("Protected Tag player", function() attrs.TGProtectedEndsAt = serverClock + 2 end, function() attrs.TGProtectedEndsAt = nil end)
	attrs.TGRole = "Tagger" controller.refresh()
	check("Tagger Playing gets Push", buttonSet.Tag.Active)
	local before = requests
	actionCallback("PlaygroundPush", Enum.UserInputState.Begin)
	actionCallback("PlaygroundPush", Enum.UserInputState.End)
	check("Keyboard/gamepad only sends on Begin", requests == before + 1)
	advance(6.1)
	lastInput = Enum.UserInputType.Gamepad1 controller.refresh()
	check("Gamepad hint follows Roblox platform key label", buttonSet.Tag.Hint.Text == "X")
	lastInput = Enum.UserInputType.Touch input.TouchEnabled = true input.KeyboardEnabled = false controller.refresh()
	check("Phone shows authored large TAP button and hides bottom-slot button", buttonSet.Mobile.Hint.Text == "TAP" and buttonSet.Mobile.Visible and not buttonSet.Tag.Visible and not buttonSet.Bulldog.Visible)
	before = requests menu.MenuIsOpen = true controller.refresh() activation.PushUiNativeFixture20261008:Fire()
	check("Roblox menu blocks input", not buttonSet.Mobile.Active and requests == before)
	menu.MenuIsOpen = false textFocus = {} controller.refresh() activation.PushUiNativeFixture20261008:Fire()
	check("Typing blocks input and passes key through", not buttonSet.Mobile.Active and requests == before and actionCallback("PlaygroundPush", Enum.UserInputState.Begin) == Enum.ContextActionResult.Pass)
	textFocus = nil input.WindowFocusReleased:Fire() activation.PushUiNativeFixture20261008:Fire()
	check("Unfocused window blocks input", not buttonSet.Mobile.Active and requests == before)
	input.WindowFocused:Fire()
	check("Returning focus re-enables", buttonSet.Mobile.Active)
	states.PlaygroundPushRequest = nil activation.PushUiNativeFixture20261008:Fire()
	check("Absent remote sends nothing", requests == before)
	states.PlaygroundPushRequest = remote
	for id, button in buttonSet do
		check(id .. " preserves authored geometry", button.Position == authored[id][1] and button.Size == authored[id][2] and button.AnchorPoint == authored[id][3])
	end
	destroying:Fire()
	check("Cleanup disconnects and unbinds", not buttonSet.Tag.Visible and not buttonSet.Bulldog.Visible and not buttonSet.Mobile.Visible and actionCallback == nil)
	rendered = Instance.new("ScreenGui")
	rendered.Name = "PushUiNativeGeometry20261008"
	rendered.Enabled = false
	rendered.Parent = game:GetService("CoreGui")
	local viewportFrame = Instance.new("Frame") viewportFrame.Parent = rendered
	local tagPanel, bulldogPanel = fixture.TagHUD.SprintPanel, fixture.BritishBulldogHUD.MovementControls
	tagPanel.Parent = viewportFrame bulldogPanel.Parent = viewportFrame
	buttonSet.Mobile.Parent = viewportFrame
	local swing = fixture.PlaygroundBatControls.Swing
	swing.Parent = viewportFrame
	local function overlap(a, b)
		return a.AbsolutePosition.X < b.AbsolutePosition.X + b.AbsoluteSize.X and a.AbsolutePosition.X + a.AbsoluteSize.X > b.AbsolutePosition.X
			and a.AbsolutePosition.Y < b.AbsolutePosition.Y + b.AbsoluteSize.Y and a.AbsolutePosition.Y + a.AbsoluteSize.Y > b.AbsolutePosition.Y
	end
	for _, size in { Vector2.new(320,568), Vector2.new(375,667), Vector2.new(568,320), Vector2.new(667,375), Vector2.new(768,1024), Vector2.new(1024,768), Vector2.new(1920,1080) } do
		viewportFrame.Size = UDim2.fromOffset(size.X, size.Y)
		local profile = (size.X <= 900 or math.min(size.X, size.Y) <= 600) and "PhoneScale" or math.max(size.X,size.Y) <= 1400 and "TabletScale" or "DesktopScale"
		for _, panel in { tagPanel, bulldogPanel } do panel.ResponsiveHudScale.Scale = panel.ResponsiveHudScale:GetAttribute(profile) end
		task.wait()
		for id, button in buttonSet do
			local p, s = button.AbsolutePosition - viewportFrame.AbsolutePosition, button.AbsoluteSize
			local panel = id == "Tag" and tagPanel or bulldogPanel
			local contained = p.X >= 0 and p.Y >= 0 and p.X+s.X <= size.X and p.Y+s.Y <= size.Y
			local separate = id == "Mobile" and not overlap(button, swing) or id ~= "Mobile" and not overlap(button, panel.Sprint)
			if id == "Bulldog" then separate = separate and not overlap(button, panel.EscapeBoost) end
			if id == "Mobile" then
				local jumpLeft, jumpTop = size.X - 128, size.Y - 144
				local outsideJump = p.X + s.X <= jumpLeft or p.Y + s.Y <= jumpTop
				separate = separate and outsideJump
			end
			check(id .. " fits viewport without other control overlap " .. tostring(size), contained and separate and s.X >= 44 and s.Y >= 44)
			table.insert(report.geometry, { game=id, viewport=tostring(size), position=tostring(p), size=tostring(s), contained=contained, noControlOverlap=separate })
		end
	end
end, debug.traceback)
if not ok then table.insert(report.errors, tostring(failure)) end
if rendered then rendered:Destroy() end
fixture:Destroy()
report.cleaned = storage:FindFirstChild("PushUiNativeFixture20261008") == nil
report.passed = ok
return game:GetService("HttpService"):JSONEncode(report)

