local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local player = Players.LocalPlayer
local baseline
local elapsed = 0
local function restore()
	if not baseline then return end
	for name, value in pairs(baseline) do Lighting[name] = value end
	baseline = nil
end
local function update()
	local lobby = workspace:FindFirstChild("Playground Lobby")
	local gameplay = lobby and lobby:FindFirstChild("Gameplay")
	local bounds = gameplay and gameplay:FindFirstChild("LobbyBounds")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local inside = false
	if bounds and root then
		local point = bounds.CFrame:PointToObjectSpace(root.Position)
		local half = bounds.Size / 2
		inside = math.abs(point.X) <= half.X and math.abs(point.Y) <= half.Y and math.abs(point.Z) <= half.Z
	end
	inside = inside and not player:GetAttribute("BBParticipating") and not player:GetAttribute("TGParticipating")
		and not player:GetAttribute("MDParticipating") and not player:GetAttribute("HSParticipating")
	if not inside then restore() return end
	if baseline then return end
	baseline = {
		Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
		Brightness = Lighting.Brightness, ExposureCompensation = Lighting.ExposureCompensation, ClockTime = Lighting.ClockTime,
	}
	Lighting.Ambient = Color3.fromRGB(110, 122, 136)
	Lighting.OutdoorAmbient = Color3.fromRGB(132, 145, 154)
	Lighting.Brightness = 2.2
	Lighting.ExposureCompensation = 0
	Lighting.ClockTime = 13.5
end
local heartbeat = RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed >= 0.3 then elapsed = 0 update() end
end)
script.Destroying:Connect(function() heartbeat:Disconnect() restore() end)
update()
