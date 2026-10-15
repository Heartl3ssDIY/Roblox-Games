-- Optional Studio Command Bar helper. Select ONLY the two imported arena Models.
-- Import both with identical scale and scene-position settings before running.
-- This configures the environment; it adds no combat scripts or asset uploads.
local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local roots = Selection:Get()
assert(#roots > 0, "Select the imported arena and collision Models first.")
for _, root in roots do
    assert(root:IsA("Model"), "Select only imported Models, not Workspace or individual parts.")
end
ChangeHistoryService:SetWaypoint("Before configuring imported arena")
local visuals, colliders = 0, 0
for _, root in roots do
    for _, part in root:GetDescendants() do
        if part:IsA("BasePart") then
            local isCollider = string.sub(part.Name, 1, 4) == "COL_"
            part.Anchored = true
            part.CanCollide = isCollider
            part.CanTouch = false
            part.CanQuery = isCollider
            if isCollider then
                part.Transparency = 1
                part.CastShadow = false
                if part:IsA("MeshPart") then
                    part.CollisionFidelity = Enum.CollisionFidelity.Box
                end
                colliders += 1
            else
                if part:IsA("MeshPart") then
                    part.RenderFidelity = Enum.RenderFidelity.Automatic
                end
                visuals += 1
            end
        end
    end
end
ChangeHistoryService:SetWaypoint("Configured imported arena")
print(string.format("Arena configured: %d visual parts, %d collision boxes.", visuals, colliders))
if colliders == 0 then
    warn("No COL_ collision boxes selected. Import and configure the collision FBX before playing.")
end
