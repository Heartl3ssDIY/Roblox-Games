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
	buildModule.Source = [======[__BUILD__]======]
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
	local source = [======[__CONTROLLER__]======]
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
