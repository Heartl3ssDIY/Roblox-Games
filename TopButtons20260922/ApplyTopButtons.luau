local backup = game.ServerStorage:FindFirstChild("TopButtonsBefore20260922")
if not backup then
    backup = Instance.new("Folder")
    backup.Name = "TopButtonsBefore20260922"
    backup.Parent = game.ServerStorage
end

local buttons = {
    {game.StarterGui.PlayButtonGui.PlayBtn, "rbxassetid://92073549830960"},
    {game.StarterGui.PacksButtonGui.PacksBtn, "rbxassetid://77256154527449"},
    {game.StarterGui.LobbyMenuGui.PvPBtn, "rbxassetid://96262979139533"},
}

local result = {}
for _, entry in ipairs(buttons) do
    local old, asset = entry[1], entry[2]
    if not backup:FindFirstChild(old.Name) then old:Clone().Parent = backup end
    local button = Instance.new("ImageButton")
    button.Name = old.Name
    button.Position = old.Position
    button.AnchorPoint = old.AnchorPoint
    button.Size = UDim2.new(old.Size.X.Scale, old.Size.X.Offset, 0, 56)
    button.Rotation = old.Rotation
    button.LayoutOrder = old.LayoutOrder
    button.ZIndex = old.ZIndex
    button.Visible = old.Visible
    button.Active = old.Active
    button.Selectable = old.Selectable
    button.BackgroundTransparency = 1
    button.BorderSizePixel = 0
    button.Image = asset
    button.ScaleType = Enum.ScaleType.Fit
    button.AutoButtonColor = true
    for key, value in pairs(old:GetAttributes()) do button:SetAttribute(key, value) end
    for _, child in ipairs(old:GetChildren()) do
        if not child:IsA("UICorner") and not child:IsA("UIStroke") and not child:IsA("UIGradient") then
            child:Clone().Parent = button
        end
    end
    local parent = old.Parent
    old:Destroy()
    button.Parent = parent
    table.insert(result, {path = button:GetFullName(), image = button.Image, class = button.ClassName})
end
return result