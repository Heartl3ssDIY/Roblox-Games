local Selection = game:GetService("Selection")
local seen = {}
local function configure(object)
    if seen[object] or not object:IsA("BasePart") then
        return
    end
    seen[object] = true
    if object.Name:match("^COL_") then
        object.Anchored = true
        object.Transparency = 1
        object.CanCollide = true
        object.CanTouch = true
        object.CanQuery = true
        if object:IsA("MeshPart") then
            object.CollisionFidelity = Enum.CollisionFidelity.Hull
        end
    elseif object.Name:match("^JH_") then
        object.Anchored = true
        object.CanCollide = false
        object.CanTouch = false
        object.CanQuery = false
    end
end
for _, root in Selection:Get() do
    configure(root)
    for _, object in root:GetDescendants() do
        configure(object)
    end
end
