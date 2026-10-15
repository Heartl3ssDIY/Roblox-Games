-- OPTIONAL: After importing GBlox_Falcon_WithGlow.fbx, put this Script inside
-- the imported pet Model. Meshes remain separate and recolourable.
-- Trails become visible when your pet-follow system moves the model.
local model = script.Parent
assert(model:IsA("Model"), "Place this script inside the imported Falcon Model")

local cyan = Color3.fromRGB(23, 245, 255)
for _, part in model:GetDescendants() do
    if not part:IsA("MeshPart") or not part.Name:match("^VFX_") then
        continue
    end
    part.Material = Enum.Material.Neon
    part.CastShadow = false
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    local isCore = part.Name:find("White_Core", 1, true) ~= nil
    part.Color = isCore and Color3.fromRGB(200, 255, 255) or cyan
    -- Optional emission parts intentionally use plain Neon, not an imported
    -- SurfaceAppearance that could prevent part.Color from taking effect.
    for _, child in part:GetChildren() do
        if child:IsA("SurfaceAppearance") then
            child:Destroy()
        end
    end
    if part.Name:find("Cyan_Jet", 1, true) then
        part.Transparency = 0.12
        local halfWidth = math.min(part.Size.X, part.Size.Y, part.Size.Z) * 0.22
        local a = part:FindFirstChild("FalconTrailA") or Instance.new("Attachment")
        a.Name = "FalconTrailA"
        a.Position = Vector3.new(-halfWidth, 0, 0)
        a.Parent = part
        local b = part:FindFirstChild("FalconTrailB") or Instance.new("Attachment")
        b.Name = "FalconTrailB"
        b.Position = Vector3.new(halfWidth, 0, 0)
        b.Parent = part
        local trail = part:FindFirstChild("FalconSpeedTrail") or Instance.new("Trail")
        trail.Name = "FalconSpeedTrail"
        trail.Attachment0 = a
        trail.Attachment1 = b
        trail.Color = ColorSequence.new(cyan)
        trail.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.3),
            NumberSequenceKeypoint.new(1, 1),
        })
        trail.WidthScale = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        })
        trail.Lifetime = 0.18
        trail.MinLength = 0.02
        trail.FaceCamera = true
        trail.LightEmission = 1
        trail.Parent = part
    end
end
