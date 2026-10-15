local Selection = game:GetService("Selection")
for _, root in ipairs(Selection:Get()) do
    local objects = root:GetDescendants()
    if root:IsA("BasePart") then table.insert(objects, root) end
    for _, object in ipairs(objects) do
        if object:IsA("BasePart") then
            local collision = string.sub(object.Name, 1, 4) == "COL_"
            object.Anchored = true
            object.CanCollide = collision
            object.CanTouch = false
            object.CanQuery = collision
            if collision then
                object.Transparency = 1
                object.CastShadow = false
            end
        end
    end
end
