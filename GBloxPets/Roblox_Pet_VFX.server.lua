-- Optional shared VFX setup for any GBlox_*_WithVFX.fbx import.
-- Place a copy inside the imported pet Model after setting its PrimaryPart.
local model = script.Parent
assert(model:IsA("Model"), "Place this Script inside an imported pet Model")

local cyan = Color3.fromRGB(24, 241, 255)
for _, part in model:GetDescendants() do
    if not part:IsA("MeshPart") or not part.Name:match("^VFX_") then
        continue
    end
    part.Material = Enum.Material.Neon
    part.Color = cyan
    part.CastShadow = false
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.Massless = true
    part.Transparency = part.Name:find("Underlight", 1, true) and 0.45 or 0.12

    local light = part:FindFirstChildOfClass("PointLight") or Instance.new("PointLight")
    light.Color = cyan
    light.Brightness = part.Name:find("Underlight", 1, true) and 0.7 or 1.25
    light.Range = part.Name:find("Underlight", 1, true) and 5 or 3
    light.Shadows = false
    light.Parent = part

    if part.Name:find("Jet", 1, true) or part.Name:find("SpeedRail", 1, true) then
        local width = math.max(0.04, math.min(part.Size.X, part.Size.Y, part.Size.Z) * 0.18)
        local a = Instance.new("Attachment")
        a.Name = "TrailA"
        a.Position = Vector3.new(-width, 0, 0)
        a.Parent = part
        local b = Instance.new("Attachment")
        b.Name = "TrailB"
        b.Position = Vector3.new(width, 0, 0)
        b.Parent = part
        local trail = Instance.new("Trail")
        trail.Name = "VelocityTrail"
        trail.Attachment0 = a
        trail.Attachment1 = b
        trail.Color = ColorSequence.new(cyan)
        trail.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.25),
            NumberSequenceKeypoint.new(1, 1),
        })
        trail.WidthScale = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        })
        trail.Lifetime = 0.18
        trail.MinLength = 0.025
        trail.FaceCamera = true
        trail.LightEmission = 1
        trail.Parent = part
    end
end
