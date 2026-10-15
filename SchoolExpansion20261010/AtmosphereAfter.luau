local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local player = Players.LocalPlayer
local baseline
local activeProfile
local elapsed = 0
local profiles = {
	Lobby = {
		Ambient = Color3.fromRGB(110, 122, 136),
		OutdoorAmbient = Color3.fromRGB(132, 145, 154),
		Brightness = 2.2, ExposureCompensation = 0, ClockTime = 13.5,
	},
	School = {
		Ambient = Color3.fromRGB(110, 108, 102),
		OutdoorAmbient = Color3.fromRGB(132, 129, 120),
		Brightness = 1.5, ExposureCompensation = -0.05, ClockTime = 13.5,
	},
}
local function restore()
	if baseline then
		for name, value in pairs(baseline) do Lighting[name] = value end
	end
	baseline, activeProfile = nil, nil
end
local function within(bounds, position)
	if not bounds or not bounds:IsA("BasePart") or not position then return false end
	local point = bounds.CFrame:PointToObjectSpace(position)
	local half = bounds.Size / 2
	return math.abs(point.X) <= half.X and math.abs(point.Y) <= half.Y and math.abs(point.Z) <= half.Z
end
local function boundsFor(name, partName)
	local model = workspace:FindFirstChild(name)
	local gameplay = model and model:FindFirstChild("Gameplay")
	return gameplay and gameplay:FindFirstChild(partName)
end
local function update()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	local schoolBounds = boundsFor("Hide and Seek", "ArenaBounds")
	local inSchool = within(schoolBounds, camera and camera.CFrame.Position)
		or (player:GetAttribute("HSParticipating") and within(schoolBounds, root and root.Position))
	local profile
	if inSchool then
		profile = "School"
	elseif within(boundsFor("Playground Lobby", "LobbyBounds"), root and root.Position)
		and not player:GetAttribute("BBParticipating") and not player:GetAttribute("TGParticipating")
		and not player:GetAttribute("MDParticipating") and not player:GetAttribute("HSParticipating") then
		profile = "Lobby"
	end
	if not profile then restore() return end
	if profile == activeProfile then return end
	if not baseline then
		baseline = {
			Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
			Brightness = Lighting.Brightness, ExposureCompensation = Lighting.ExposureCompensation, ClockTime = Lighting.ClockTime,
		}
	end
	for name, value in pairs(profiles[profile]) do Lighting[name] = value end
	activeProfile = profile
end
local heartbeat = RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed >= 0.3 then elapsed = 0 update() end
end)
script.Destroying:Connect(function() heartbeat:Disconnect() restore() end)
update()
