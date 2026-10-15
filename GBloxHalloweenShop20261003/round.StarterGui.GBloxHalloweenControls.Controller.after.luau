local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local gui = script.Parent
local controls = gui:FindFirstChild("Controls")
local splat = gui:WaitForChild("PumpkinSplat")
local artwork = splat:WaitForChild("Artwork")
local fallback = splat:WaitForChild("Fallback")
local remote = ReplicatedStorage:WaitForChild("GBloxHalloweenEvent", 10)

if controls then controls.Visible = false end
splat.Visible = false
if not remote or not remote:IsA("RemoteEvent") then
	warn("Pumpkin splat could not find its effect service")
	return
end

local connections = {}
local alive = true
local clockConnection
local clockAccumulator = 0
local currentRound = player:GetAttribute("RunnerCourseVersion")
local currentCharacter = player.Character
local splatUntil = 0

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local function finite(value)
	return typeof(value) == "number" and value == value and math.abs(value) < math.huge
end

local function available()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return gui.Enabled and character ~= nil and character.Parent ~= nil
		and humanoid ~= nil and humanoid.Health > 0
		and player:GetAttribute("RunnerStatus") == "Running"
end

local function updateArtwork()
	fallback.Visible = gui:GetAttribute("FallbackSplatEnabled") ~= false
		and (artwork.Image == "" or not artwork.IsLoaded)
end

local function stopClock()
	if clockConnection then clockConnection:Disconnect() clockConnection = nil end
end

local function clearSplat()
	splatUntil = 0
	splat.Visible = false
	stopClock()
end

local function refresh()
	if not alive then return end
	local round = player:GetAttribute("RunnerCourseVersion")
	local character = player.Character
	if round ~= currentRound or character ~= currentCharacter or not available() then clearSplat() end
	currentRound = round
	currentCharacter = character
end

local function ensureClock()
	if not alive or not splat.Visible or clockConnection then return end
	clockAccumulator = 0
	clockConnection = RunService.Heartbeat:Connect(function(delta)
		clockAccumulator += delta
		if clockAccumulator < 0.1 then return end
		clockAccumulator = 0
		refresh()
		if splat.Visible and workspace:GetServerTimeNow() >= splatUntil then clearSplat() end
	end)
end

connect(remote.OnClientEvent, function(kind, packet)
	if not alive or typeof(packet) ~= "table" then return end
	refresh()
	if kind == "HalloweenClear" then
		if packet.roundKey == nil or packet.roundKey == currentRound then clearSplat() end
		return
	end
	if kind ~= "PumpkinSplat" or packet.roundKey ~= currentRound or not available() then return end
	local now = workspace:GetServerTimeNow()
	local duration = finite(packet.duration) and math.clamp(packet.duration, 0, 4) or 4
	if duration <= 0 then return end
	splatUntil = math.min(now + 4, math.max(splatUntil, now + duration))
	splat.Visible = true
	updateArtwork()
	ensureClock()
end)

for _, attribute in ipairs({"RunnerCourseVersion", "RunnerStatus"}) do
	connect(player:GetAttributeChangedSignal(attribute), refresh)
end
connect(player.CharacterAdded, refresh)
connect(player.CharacterRemoving, clearSplat)
connect(gui:GetPropertyChangedSignal("Enabled"), refresh)
connect(gui:GetAttributeChangedSignal("FallbackSplatEnabled"), updateArtwork)
connect(artwork:GetPropertyChangedSignal("Image"), updateArtwork)
connect(artwork:GetPropertyChangedSignal("IsLoaded"), updateArtwork)
connect(script.Destroying, function()
	alive = false
	clearSplat()
	for _, connection in ipairs(connections) do connection:Disconnect() end
end)

updateArtwork()
refresh()
