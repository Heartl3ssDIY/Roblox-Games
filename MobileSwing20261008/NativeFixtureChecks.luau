assert(not game:GetService("RunService"):IsRunning(), "Edit only")
local storage = game:GetService("ServerStorage")
local fixture = Instance.new("Folder")
fixture.Name = "MobileSwingNativeFixture20261008"
fixture.Parent = storage
local gui
local report = { checks = {}, errors = {}, geometry = {} }
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
		for _, entry in handlers do
			if entry.active then entry.callback(...) end
		end
	end
	return object
end
local ok, failure = xpcall(function()
	local installed = game.StarterGui.PlaygroundBatControls.Controller
	gui = installed.Parent:Clone()
	gui.Name = "MobileSwingNativeFixtureGui20261008"
	for _, child in gui:GetDescendants() do if child:IsA("BaseScript") then child:Destroy() end end
	gui.Enabled = false
	gui.Enabled = true
	gui.Parent = fixture
	local button = gui.Swing
	local authoredPosition, authoredSize, authoredAnchor = button.Position, button.Size, button.AnchorPoint
	local model = Instance.new("Model")
	model.Name = "NativeCharacter"
	model.Parent = fixture
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = model
	local nativeTool = Instance.new("Tool")
	nativeTool.Name = "NativeBat"
	nativeTool.RequiresHandle = false
	nativeTool:SetAttribute("PCBatWeapon", true)
	nativeTool:SetAttribute("WeaponGame", "BritishBulldog")
	nativeTool.Parent = model
	local states = {}
	for name, phase in pairs({ BritishBulldogState = "Crossing", TagState = "Playing" }) do
		local state = Instance.new("Folder")
		state.Name = name
		state:SetAttribute("Phase", phase)
		state.Parent = fixture
		states[name] = state
	end
	local attrs = { PCDataReady = true, BBParticipating = true, BBRole = "Bulldog" }
	local player = { CharacterAdded = signal(), CharacterRemoving = signal() }
	function player:GetAttribute(name) return attrs[name] end
	local activateCount, deactivateCount = 0, 0
	local batAttrs = { PCBatWeapon = true, WeaponGame = "BritishBulldog" }
	local bat = { Enabled = true }
	function bat:IsA(kind) return kind == "Tool" end
	function bat:GetAttribute(name) return batAttrs[name] end
	function bat:Activate() activateCount += 1 end
	function bat:Deactivate() deactivateCount += 1 end
	local children = { bat }
	player.Character = {
		FindFirstChildOfClass = function(_, className) return className == "Humanoid" and humanoid or nil end,
		GetChildren = function() return children end,
	}
	local textFocus = nil
	local input = { TouchEnabled = true, WindowFocusReleased = signal(), WindowFocused = signal() }
	local touchSignal = signal()
	function input:GetFocusedTextBox() return textFocus end
	function input:GetPropertyChangedSignal() return touchSignal end
	local menu = { MenuIsOpen = false }
	local heartbeat = signal()
	local clock, serverClock = 40, 200
	local activation, destroying = signal(), signal()
	local services = {
		Players = { LocalPlayer = player }, UserInputService = input, GuiService = menu,
		RunService = { Heartbeat = heartbeat },
		ReplicatedStorage = { FindFirstChild = function(_, name) return states[name] end },
	}
	local env = {
		game = { GetService = function(_, name) return assert(services[name], name) end },
		workspace = { GetServerTimeNow = function() return serverClock end },
		os = { clock = function() return clock end },
		script = { Parent = gui, Destroying = destroying }, Activated = activation,
	}
	local module = Instance.new("ModuleScript")
	module.Name = "ExactControllerCapabilityFixture"
	module.Capabilities = installed.Capabilities
	module.Sandboxed = installed.Sandboxed
	local replaced, replacements = installed.Source:gsub("connect%(button%.Activated, swing%)", "connect(env.Activated, swing)")
	check("Only Activated signal substituted for native click fixture", replacements == 1)
	module.Source = "return function(env)\nlocal game = env.game\nlocal workspace = env.workspace\nlocal script = env.script\nlocal os = env.os\n" .. replaced .. "\nreturn { refresh=refresh, probeNativeTool=function(tool) tool:Activate() tool:Deactivate() end }\nend"
	module.Parent = fixture
	local required, factory = pcall(require, module)
	if not required then
		report.firstRequireFailure = tostring(factory)
		assert(tostring(factory):find("RunServerScript"), "Unexpected exact-capability require failure: " .. tostring(factory))
		module.Capabilities = installed.Capabilities:Add(SecurityCapabilities.new(Enum.SecurityCapability.RunServerScript))
		local replacementModule = module:Clone()
		replacementModule.Name = "EditRequireFixture"
		replacementModule.Parent = fixture
		module = replacementModule
		factory = require(module)
		report.temporaryRunServerScript = true
	end
	report.capabilities = tostring(module.Capabilities)
	report.installedCapabilities = tostring(installed.Capabilities)
	report.sandboxed = module.Sandboxed
	local controller = factory(env)
	check("Native GUI and Humanoid accessed inside installed sandbox", button.Visible and button.Active)
	local probeOk, probeError = pcall(controller.probeNativeTool, nativeTool)
	report.nativeToolProbe = probeOk
	if not probeOk then report.nativeToolProbeError = tostring(probeError) end
	check("Native Tool Activate and Deactivate authorized", probeOk)
	check("Bulldog Crossing shows touch SWING", button.Visible and button.Active)
	activation:Fire()
	check("One tap invokes exactly one Activate and one Deactivate", activateCount == 1 and deactivateCount == 1)
	activation:Fire()
	check("Repeated tap blocked by cooldown", activateCount == 1 and not button.Active)
	clock += 0.8
	serverClock += 0.8
	heartbeat:Fire(0.1)
	check("Cooldown expires and re-enables", button.Visible and button.Active)
	attrs.PCBatSwingAt = serverClock
	controller.refresh()
	check("Server cooldown blocks even after client cooldown", not button.Active and button.Visible)
	attrs.PCBatSwingAt = nil
	controller.refresh()
	local function hidden(name, change, restore)
		change()
		controller.refresh()
		check(name, not button.Visible and not button.Active)
		local before = activateCount
		activation:Fire()
		check(name .. " cannot invoke Tool", activateCount == before)
		restore()
		controller.refresh()
	end
	hidden("Desktop hides", function() input.TouchEnabled = false end, function() input.TouchEnabled = true end)
	hidden("Unready data hides", function() attrs.PCDataReady = false end, function() attrs.PCDataReady = true end)
	hidden("Runner hides", function() attrs.BBRole = "Runner" end, function() attrs.BBRole = "Bulldog" end)
	hidden("Lobby hides", function() attrs.BBParticipating = false end, function() attrs.BBParticipating = true end)
	hidden("Mud hides", function() attrs.MDParticipating = true end, function() attrs.MDParticipating = nil end)
	hidden("Dead humanoid hides", function() humanoid.Health = 0 end, function() humanoid.Health = 100 end)
	hidden("Bulldog ragdoll hides", function() attrs.BBRagdolled = true end, function() attrs.BBRagdolled = nil end)
	hidden("Tag ragdoll hides", function() attrs.TGRagdolled = true end, function() attrs.TGRagdolled = nil end)
	hidden("Wrong game bat hides", function() batAttrs.WeaponGame = "TagYoureIt" end, function() batAttrs.WeaponGame = "BritishBulldog" end)
	hidden("Unmarked tool hides", function() batAttrs.PCBatWeapon = false end, function() batAttrs.PCBatWeapon = true end)
	hidden("Disabled tool hides", function() bat.Enabled = false end, function() bat.Enabled = true end)
	hidden("Unequipped bat hides", function() children = {} end, function() children = { bat } end)
	hidden("Countdown hides", function() states.BritishBulldogState:SetAttribute("Phase", "Countdown") end, function() states.BritishBulldogState:SetAttribute("Phase", "Crossing") end)
	attrs.BBParticipating, attrs.BBRole = false, "Spectator"
	attrs.TGParticipating, attrs.TGRole = true, "Tagger"
	batAttrs.WeaponGame = "TagYoureIt"
	controller.refresh()
	check("Tagger Playing shows touch SWING", button.Visible and button.Active)
	activation:Fire()
	check("Tagger tap activates once", activateCount == 2 and deactivateCount == 2)
	clock += 0.8
	serverClock += 0.8
	controller.refresh()
	local before = activateCount
	menu.MenuIsOpen = true
	controller.refresh()
	activation:Fire()
	check("Open Roblox menu blocks activation", button.Visible and not button.Active and activateCount == before)
	menu.MenuIsOpen = false
	textFocus = {}
	controller.refresh()
	activation:Fire()
	check("Focused text field blocks activation", not button.Active and activateCount == before)
	textFocus = nil
	input.WindowFocusReleased:Fire()
	activation:Fire()
	check("Window loses focus blocks activation", not button.Active and activateCount == before)
	input.WindowFocused:Fire()
	check("Focus restored re-enables", button.Active)
	gui.Enabled = false
	activation:Fire()
	check("Disabled ScreenGui blocks activation", activateCount == before)
	check("Runtime does not rewrite authored geometry", button.Position == authoredPosition and button.Size == authoredSize and button.AnchorPoint == authoredAnchor)
	destroying:Fire()
	check("Controller cleanup hides button", not button.Visible)
	gui.Parent = game:GetService("CoreGui")
	local frame = Instance.new("Frame")
	frame.Name = "ViewportFixture"
	frame.BackgroundTransparency = 1
	frame.Parent = gui
	button.Parent = frame
	local viewports = { Vector2.new(320,568), Vector2.new(375,667), Vector2.new(568,320), Vector2.new(667,375), Vector2.new(768,1024), Vector2.new(1024,768), Vector2.new(1366,767) }
	for _, viewport in viewports do
		frame.Size = UDim2.fromOffset(viewport.X, viewport.Y)
		task.wait()
		local size, position = button.AbsoluteSize, button.AbsolutePosition - frame.AbsolutePosition
		local contained = position.X >= 0 and position.Y >= 0 and position.X + size.X <= viewport.X and position.Y + size.Y <= viewport.Y
		table.insert(report.geometry, { viewport = tostring(viewport), position = tostring(position), size = tostring(size), contained = contained })
		check("Native geometry fits " .. tostring(viewport), contained and size.X >= 100 and size.Y >= 64)
	end
end, debug.traceback)
if not ok then table.insert(report.errors, tostring(failure)) end
if gui then gui:Destroy() end
fixture:Destroy()
report.cleaned = storage:FindFirstChild("MobileSwingNativeFixture20261008") == nil and game:GetService("CoreGui"):FindFirstChild("MobileSwingNativeFixtureGui20261008") == nil
report.passed = ok
return game:GetService("HttpService"):JSONEncode(report)
