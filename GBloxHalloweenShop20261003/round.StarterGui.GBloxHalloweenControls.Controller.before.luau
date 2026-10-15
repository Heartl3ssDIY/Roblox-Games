local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local gui = script.Parent
local controls = gui:WaitForChild("Controls")
local splat = gui:WaitForChild("PumpkinSplat")
local artwork = splat:WaitForChild("Artwork")
local fallback = splat:WaitForChild("Fallback")
local status = controls:WaitForChild("Status")
local buttons = {Web = controls:WaitForChild("Web"), Pumpkin = controls:WaitForChild("Pumpkin")}
local remote = ReplicatedStorage:WaitForChild("GBloxHalloweenEvent", 10)
local theme = ReplicatedStorage:WaitForChild("GBloxCourseTheme", 10)
local settings = ReplicatedStorage:WaitForChild("GBloxHalloweenSettings", 10)

if not remote or not remote:IsA("RemoteEvent") or not theme or not settings then
	controls.Visible = false
	splat.Visible = false
	warn("Halloween Course 1 controls could not find their seasonal service")
	return
end

local connections = {}
local alive = true
local clockConnection
local clockAccumulator = 0
local active = false
local currentRound = player:GetAttribute("RunnerCourseVersion")
local currentCharacter = player.Character
local pending = {}
local resultCooldown = {}
local lastRequest = -math.huge
local splatUntil = 0
local graveUntil = 0
local messageUntil = 0
local message = ""
local actionNames = {Web = "GBloxHalloweenPlaceWeb", Pumpkin = "GBloxHalloweenThrowPumpkin"}
local cooldownAttributes = {Web = "GBloxHalloweenWebCooldownUntil", Pumpkin = "GBloxHalloweenPumpkinCooldownUntil"}
local refresh
local updateClock

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local function finite(value)
	return typeof(value) == "number" and value == value and math.abs(value) < math.huge
end

local function serverTime()
	return workspace:GetServerTimeNow()
end

local function available()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not character.Parent or not humanoid or humanoid.Health <= 0 then return false end
	return gui.Enabled
		and settings:GetAttribute("Enabled") == true
		and theme:GetAttribute("ActiveTheme") == "Halloween"
		and player:GetAttribute("RunnerCourseNumber") == 1
		and player:GetAttribute("RunnerStatus") == "Running"
end

local function cooldownUntil(action)
	local attribute = player:GetAttribute(cooldownAttributes[action])
	local result = resultCooldown[action]
	return math.max(finite(attribute) and attribute or 0, finite(result) and result or 0)
end

local function updateArtwork()
	fallback.Visible = gui:GetAttribute("FallbackSplatEnabled") ~= false and (artwork.Image == "" or not artwork.IsLoaded)
end

local function clearTransient()
	pending = {}
	resultCooldown = {}
	splatUntil = 0
	graveUntil = 0
	messageUntil = 0
	message = ""
	splat.Visible = false
	status.Text = ""
end

local function updateButtons(now)
	for action, button in pairs(buttons) do
		local requestExpiry = pending[action]
		if requestExpiry and now >= requestExpiry then
			pending[action] = nil
			message = "NO RESPONSE — TRY AGAIN"
			messageUntil = now + 2
		end
		local remaining = math.max(0, cooldownUntil(action) - now)
		button.Cooldown.Text = remaining > 0 and (tostring(math.ceil(remaining)) .. "s") or (pending[action] and "..." or "READY")
		button.Active = active and remaining <= 0 and not pending[action]
		button.AutoButtonColor = button.Active
	end
end

local function ensureClock()
	local needed = alive and (active or splat.Visible)
	if needed and not clockConnection then
		clockAccumulator = 0
		clockConnection = RunService.Heartbeat:Connect(function(delta)
			clockAccumulator += delta
			if clockAccumulator >= 0.1 then
				clockAccumulator = 0
				updateClock()
			end
		end)
	elseif not needed and clockConnection then
		clockConnection:Disconnect()
		clockConnection = nil
	end
end

updateClock = function()
	if not alive then return end
	if not available() then
		refresh()
		return
	end
	local now = serverTime()
	updateButtons(now)
	if splat.Visible and now >= splatUntil then splat.Visible = false end
	if graveUntil > now then
		status.Text = "ZOMBIE GRAB · " .. tostring(math.ceil(graveUntil - now)) .. "s"
	else
		status.Text = now < messageUntil and message or ""
	end
	ensureClock()
end

refresh = function()
	if not alive then return end
	local round = player:GetAttribute("RunnerCourseVersion")
	local character = player.Character
	local nextActive = available()
	if round ~= currentRound or character ~= currentCharacter or (active and not nextActive) then
		clearTransient()
	end
	currentRound = round
	currentCharacter = character
	active = nextActive
	controls.Visible = active
	if not active then splat.Visible = false end
	updateButtons(serverTime())
	ensureClock()
end

local function request(action)
	if not alive or not active or not available() or UserInputService:GetFocusedTextBox() then return end
	local now = serverTime()
	if now - lastRequest < 0.15 or pending[action] or cooldownUntil(action) > now then return end
	lastRequest = now
	pending[action] = now + 2
	updateButtons(now)
	remote:FireServer(action)
end

for action, button in pairs(buttons) do
	connect(button.Activated, function() request(action) end)
end

local function bind(action, keys)
	ContextActionService:BindActionAtPriority(actionNames[action], function(_, inputState)
		if not active or not available() or UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
		if inputState == Enum.UserInputState.Begin then request(action) end
		return Enum.ContextActionResult.Sink
	end, false, 3000, table.unpack(keys))
end
bind("Web", {Enum.KeyCode.V, Enum.KeyCode.ButtonL1})
bind("Pumpkin", {Enum.KeyCode.B, Enum.KeyCode.ButtonR1})

connect(remote.OnClientEvent, function(kind, packet)
	if not alive or typeof(packet) ~= "table" or not active or not available() then return end
	if kind == "HalloweenClear" then
		if packet.roundKey ~= nil and packet.roundKey ~= currentRound then return end
		clearTransient()
		updateClock()
		return
	end
	if packet.roundKey ~= currentRound then return end
	local now = serverTime()
	if kind == "HalloweenResult" then
		local action = packet.action
		if not buttons[action] then return end
		pending[action] = nil
		if finite(packet.cooldownUntil) then resultCooldown[action] = packet.cooldownUntil end
		if typeof(packet.message) == "string" then
			message = string.sub(packet.message, 1, 100)
			messageUntil = now + 2.5
		end
		updateClock()
	elseif kind == "PumpkinSplat" then
		local duration = finite(packet.duration) and math.clamp(packet.duration, 0, 5) or 3
		splatUntil = math.max(splatUntil, now + duration)
		splat.Visible = duration > 0
		updateArtwork()
		ensureClock()
	elseif kind == "GraveGrab" and packet.userId == player.UserId then
		graveUntil = finite(packet.untilTime) and math.clamp(packet.untilTime, now, now + 6) or now + 5
		updateClock()
	end
end)

for _, attribute in ipairs({"RunnerCourseNumber", "RunnerCourseVersion", "RunnerStatus", "GBloxHalloweenWebCooldownUntil", "GBloxHalloweenPumpkinCooldownUntil"}) do
	connect(player:GetAttributeChangedSignal(attribute), refresh)
end
connect(player.CharacterAdded, refresh)
connect(player.CharacterRemoving, function()
	clearTransient()
	active = false
	controls.Visible = false
	ensureClock()
end)
connect(settings:GetAttributeChangedSignal("Enabled"), refresh)
connect(theme:GetAttributeChangedSignal("ActiveTheme"), refresh)
connect(gui:GetPropertyChangedSignal("Enabled"), refresh)
connect(gui:GetAttributeChangedSignal("FallbackSplatEnabled"), updateArtwork)
connect(artwork:GetPropertyChangedSignal("Image"), updateArtwork)
connect(artwork:GetPropertyChangedSignal("IsLoaded"), updateArtwork)

connect(script.Destroying, function()
	alive = false
	if clockConnection then clockConnection:Disconnect() clockConnection = nil end
	for _, name in pairs(actionNames) do ContextActionService:UnbindAction(name) end
	for _, connection in ipairs(connections) do connection:Disconnect() end
	clearTransient()
	controls.Visible = false
end)

updateArtwork()
refresh()


