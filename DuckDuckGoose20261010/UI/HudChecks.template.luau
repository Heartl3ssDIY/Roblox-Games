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
__CONTROLLER__
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
