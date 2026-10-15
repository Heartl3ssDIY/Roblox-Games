assert(not game:GetService("RunService"):IsRunning(), "Install in Edit mode")
local podium = workspace["Playground Lobby"].WinnerPodium
local top = podium.Rank1.Top
assert(not top:FindFirstChild("FirstPlaceGlow"), "First-place glow is already installed")
local root = Instance.new("Attachment")
root.Name = "FirstPlaceGlow"
root.Position = Vector3.new(0, top.Size.Y * 0.5 + 0.05, 0)
root:SetAttribute("GlowVersion", 20261007)
root.Parent = top
for index, offset in ipairs({ Vector3.new(-4.7, 0, -2.8), Vector3.new(4.7, 0, -2.8), Vector3.new(-4.7, 0, 2.8), Vector3.new(4.7, 0, 2.8) }) do
	local bottom = Instance.new("Attachment")
	bottom.Name = "RayBase" .. index
	bottom.Position = offset
	bottom.Parent = root
	local peak = Instance.new("Attachment")
	peak.Name = "RayPeak" .. index
	peak.Position = Vector3.new(offset.X * 1.25, 18, offset.Z * 1.25)
	peak.Parent = root
	local beam = Instance.new("Beam")
	beam.Name = "GoldenRay" .. index
	beam.Attachment0 = bottom
	beam.Attachment1 = peak
	beam.FaceCamera = true
	beam.Width0 = 0.35
	beam.Width1 = 2.6
	beam.Segments = 8
	beam.LightEmission = 0.8
	beam.LightInfluence = 0
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 201, 70), Color3.fromRGB(255, 243, 178))
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.12, 0.82), NumberSequenceKeypoint.new(0.45, 0.89), NumberSequenceKeypoint.new(1, 1) })
	beam.Parent = root
end
local light = Instance.new("PointLight")
light.Name = "WinnerWarmGlow"
light.Color = Color3.fromRGB(255, 213, 113)
light.Brightness = 0.6
light.Range = 17
light.Shadows = false
light.Parent = root
return { beams = 4, lights = 1, path = root:GetFullName(), podiumMoved = false }
