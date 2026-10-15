local now = 100
local checks = 0
local function check(value, description)
    assert(value, description)
    checks += 1
end
local function signal()
    local object = {connections = {}}
    function object:Connect(callback)
        local connection = {Connected = true}
        function connection:Disconnect() self.Connected = false end
        connection.callback = callback
        table.insert(self.connections, connection)
        return connection
    end
    function object:Fire(...)
        for _, connection in ipairs(self.connections) do
            if connection.Connected then connection.callback(...) end
        end
    end
    function object:Count()
        local count = 0
        for _, connection in ipairs(self.connections) do
            if connection.Connected then count += 1 end
        end
        return count
    end
    return object
end
local layoutWrites = 0
local function object(name, class, properties, attributes)
    local data = properties or {}
    data.Name = name
    data.ClassName = class or "Folder"
    data.attributes = attributes or {}
    data.children = {}
    data.attributeSignals = {}
    data.propertySignals = {}
    local proxy = {}
    local methods = {}
    function methods:WaitForChild(child) return data.children[child] end
    function methods:FindFirstChildOfClass(wanted)
        for _, child in pairs(data.children) do
            if child.ClassName == wanted then return child end
        end
    end
    function methods:IsA(wanted) return data.ClassName == wanted end
    function methods:GetAttribute(key) return data.attributes[key] end
    function methods:SetAttribute(key, value)
        data.attributes[key] = value
        if data.attributeSignals[key] then data.attributeSignals[key]:Fire() end
    end
    function methods:GetAttributeChangedSignal(key)
        if not data.attributeSignals[key] then data.attributeSignals[key] = signal() end
        return data.attributeSignals[key]
    end
    function methods:GetPropertyChangedSignal(key)
        if not data.propertySignals[key] then data.propertySignals[key] = signal() end
        return data.propertySignals[key]
    end
    function methods:Add(child) data.children[child.Name] = child return child end
    return setmetatable(proxy, {
        __index = function(_, key)
            if methods[key] then return methods[key] end
            if data[key] ~= nil then return data[key] end
            return data.children[key]
        end,
        __newindex = function(_, key, value)
            if key == "Position" or key == "Size" then layoutWrites += 1 end
            data[key] = value
            if data.propertySignals[key] then data.propertySignals[key]:Fire() end
        end,
    })
end
local heartbeat = signal()
local gui = object("GBloxHalloweenControls", "ScreenGui", {Enabled = true}, {FallbackSplatEnabled = true})
local controls = gui:Add(object("Controls", "Frame", {Visible = false}))
local status = controls:Add(object("Status", "TextLabel", {Text = ""}))
local buttons = {}
for _, name in ipairs({"Web", "Pumpkin"}) do
    local button = controls:Add(object(name, "TextButton", {Activated = signal()}))
    button:Add(object("Cooldown", "TextLabel", {Text = ""}))
    buttons[name] = button
end
local splat = gui:Add(object("PumpkinSplat", "Frame", {Visible = false}))
local artwork = splat:Add(object("Artwork", "ImageLabel", {Image = "", IsLoaded = false}))
local fallback = splat:Add(object("Fallback", "Frame", {Visible = true}))
local player = object("Tester", "Player", {UserId = 123, CharacterAdded = signal(), CharacterRemoving = signal()}, {
    RunnerStatus = "Running", RunnerCourseNumber = 1, RunnerCourseVersion = 7,
})
local character = object("Character", "Model", {Parent = true})
character:Add(object("Humanoid", "Humanoid", {Health = 100}))
player.Character = character
local remote = object("GBloxHalloweenEvent", "RemoteEvent", {OnClientEvent = signal()})
local requests = {}
function remote:FireServer(...) table.insert(requests, {...}) end
local theme = object("GBloxCourseTheme", "ModuleScript", {}, {ActiveTheme = "Halloween"})
local settings = object("GBloxHalloweenSettings", "Folder", {}, {Enabled = true})
local storage = object("ReplicatedStorage")
storage:Add(remote) storage:Add(theme) storage:Add(settings)
local bindings = {}
local context = {}
function context:BindActionAtPriority(name, handler) bindings[name] = handler end
function context:UnbindAction(name) bindings[name] = nil end
local input = {}
function input:GetFocusedTextBox() return nil end
local services = {
    Players = {LocalPlayer = player}, ReplicatedStorage = storage, ContextActionService = context,
    UserInputService = input, RunService = {Heartbeat = heartbeat},
}
local fakeGame = {}
function fakeGame:GetService(name) return services[name] end
local fakeWorkspace = {}
function fakeWorkspace:GetServerTimeNow() return now end
local fakeScript = object("Controller", "LocalScript", {Parent = gui, Destroying = signal()})
local Enum = {
    KeyCode = {V = "V", B = "B", ButtonL1 = "L1", ButtonR1 = "R1"},
    ContextActionResult = {Pass = "Pass", Sink = "Sink"}, UserInputState = {Begin = "Begin"},
}
local env = setmetatable({
    game = fakeGame, workspace = fakeWorkspace, script = fakeScript, Enum = Enum,
    typeof = type, warn = function(message) error(message) end,
}, {__index = getfenv()})
local run = assert(loadstring([====[local Players = game:GetService("Players")
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

]====]))
setfenv(run, env)
run()
check(controls.Visible and heartbeat:Count() == 1, "Active course shows controls and starts one clock")
check(buttons.Web.Cooldown.Text == "READY", "Initial ability ready")
buttons.Web.Activated:Fire()
check(#requests == 1 and #requests[1] == 1 and requests[1][1] == "Web", "Only action is sent, no client target")
buttons.Web.Activated:Fire()
check(#requests == 1, "Pending request blocks repeat")
remote.OnClientEvent:Fire("HalloweenResult", {action = "Web", ok = true, cooldownUntil = 130, roundKey = 7})
check(buttons.Web.Cooldown.Text == "30s" and not buttons.Web.Active, "Server cooldown rendered")
now = 101
heartbeat:Fire(0.11)
check(buttons.Web.Cooldown.Text == "29s", "Server-clock countdown updated")
buttons.Web.Activated:Fire()
check(#requests == 1, "Cooldown blocks client request")
buttons.Pumpkin.Activated:Fire()
check(#requests == 2 and requests[2][1] == "Pumpkin", "Pumpkin button sends action")
remote.OnClientEvent:Fire("PumpkinSplat", {duration = 3, roundKey = 6})
check(not splat.Visible, "Stale splat ignored")
remote.OnClientEvent:Fire("PumpkinSplat", {duration = 3, roundKey = 7})
check(splat.Visible and fallback.Visible, "Current splat has visible fallback without artwork")
now = 102
remote.OnClientEvent:Fire("PumpkinSplat", {duration = 3, roundKey = 7})
now = 104
heartbeat:Fire(0.11)
check(splat.Visible, "Repeated hit extends rather than old timer hiding new splat")
now = 105
heartbeat:Fire(0.11)
check(not splat.Visible, "Splat expires after extended lifetime")
remote.OnClientEvent:Fire("PumpkinSplat", {duration = 3, roundKey = 7})
artwork.Image = "rbxassetid://123"
check(fallback.Visible, "Fallback remains during image load")
artwork.IsLoaded = true
check(not fallback.Visible, "Loaded authored artwork hides fallback")
remote.OnClientEvent:Fire("GraveGrab", {userId = 999, untilTime = 110, roundKey = 7})
check(not status.Text:find("ZOMBIE"), "Other player grab does not show local notice")
remote.OnClientEvent:Fire("GraveGrab", {userId = 123, untilTime = 110, roundKey = 7})
check(status.Text:find("ZOMBIE GRAB"), "Own grab notice shown")
theme:SetAttribute("ActiveTheme", "Normal")
check(not controls.Visible and not splat.Visible and heartbeat:Count() == 0, "Theme exit clears visuals and disconnects clock")
theme:SetAttribute("ActiveTheme", "Halloween")
player:SetAttribute("RunnerCourseNumber", 2)
check(not controls.Visible and heartbeat:Count() == 0, "Other courses never show controls")
player:SetAttribute("RunnerCourseNumber", 1)
check(controls.Visible and heartbeat:Count() == 1, "Returning course reuses one clock")
player:SetAttribute("RunnerCourseVersion", 8)
remote.OnClientEvent:Fire("HalloweenResult", {action = "Pumpkin", cooldownUntil = 200, roundKey = 7})
check(buttons.Pumpkin.Cooldown.Text == "READY", "Late previous-round result ignored")
remote.OnClientEvent:Fire("PumpkinSplat", {duration = 3, roundKey = 8})
remote.OnClientEvent:Fire("HalloweenClear", {roundKey = 8})
check(not splat.Visible, "Seasonal clear removes overlay")
settings:SetAttribute("Enabled", false)
check(not controls.Visible and heartbeat:Count() == 0, "Disabled service stops rendering clock")
settings:SetAttribute("Enabled", true)
player.CharacterRemoving:Fire()
check(not controls.Visible and heartbeat:Count() == 0, "Character removal clears controls")
player.Character = nil
player:SetAttribute("RunnerStatus", "Running")
check(controls.Visible == false and heartbeat:Count() == 0, "No character produces a boolean false visibility")
fakeScript.Destroying:Fire()
check(heartbeat:Count() == 0 and next(bindings) == nil, "Destroy removes clock and input bindings")
check(layoutWrites == 0, "Runtime preserves all authored positions and sizes")
print("Halloween client: " .. checks .. " checks passed")

