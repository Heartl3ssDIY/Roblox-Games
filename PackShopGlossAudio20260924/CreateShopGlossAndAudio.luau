local gui = game.StarterGui.PackShopGui
local panel = gui.Board.Panel
local function finish(button, isPack)
    local old = button:FindFirstChild("ShopFinish")
    if old then old:Destroy() end
    local layer = Instance.new("CanvasGroup")
    layer.Name = "ShopFinish"
    layer.BackgroundTransparency = 1
    layer.BorderSizePixel = 0
    layer.Active = false
    layer.Selectable = false
    layer.Position = isPack and UDim2.fromScale(.075, .14) or UDim2.fromScale(.06, .12)
    layer.Size = isPack and UDim2.fromScale(.85, .70) or UDim2.fromScale(.88, .76)
    layer.ZIndex = button.ZIndex + 1
    layer.Parent = button
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, isPack and 2 or 10)
    corner.Parent = layer
    local glass = Instance.new("Frame")
    glass.Name = "Glass"
    glass.BorderSizePixel = 0
    glass.BackgroundColor3 = Color3.new(1, 1, 1)
    glass.BackgroundTransparency = isPack and .87 or .92
    glass.Size = UDim2.fromScale(1, 1)
    glass.ZIndex = layer.ZIndex
    glass.Parent = layer
    local gradient = Instance.new("UIGradient")
    gradient.Rotation = 100
    gradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, .25),
        NumberSequenceKeypoint.new(.35, .78),
        NumberSequenceKeypoint.new(.6, 1),
        NumberSequenceKeypoint.new(1, 1),
    })
    gradient.Parent = glass
    local shine = Instance.new("Frame")
    shine.Name = "Shine"
    shine.BorderSizePixel = 0
    shine.BackgroundColor3 = Color3.new(1, 1, 1)
    shine.Size = UDim2.fromScale(1, 1)
    shine.ZIndex = layer.ZIndex + 1
    shine.Parent = layer
    local sweep = Instance.new("UIGradient")
    sweep.Name = "Sweep"
    sweep.Rotation = 24
    sweep.Offset = Vector2.new(-1.25, 0)
    sweep.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(.32, 1),
        NumberSequenceKeypoint.new(.47, .9),
        NumberSequenceKeypoint.new(.5, isPack and .64 or .79),
        NumberSequenceKeypoint.new(.53, .9),
        NumberSequenceKeypoint.new(.68, 1),
        NumberSequenceKeypoint.new(1, 1),
    })
    sweep.Parent = shine
end
for _, name in ipairs({"Silver", "Gold", "Diamond"}) do
    finish(panel[name].Pack, true)
    finish(panel[name].Buy, false)
end
finish(panel.Common.Art.PackOne, true)
finish(panel.Common.Art.PackTwo, true)
finish(panel.Common.Buy, false)
local sounds = game.SoundService:FindFirstChild("PackShopSounds")
if not sounds then
    sounds = Instance.new("Folder")
    sounds.Name = "PackShopSounds"
    sounds.Parent = game.SoundService
end
for name, id in pairs({
    Hover = "139719503904449",
    Click = "88442833509532",
    Confirm = "116995696565929",
    Unavailable = "87519554692663",
}) do
    if not sounds:FindFirstChild(name) then
        local sound = Instance.new("Sound")
        sound.Name = name
        sound.SoundId = "rbxassetid://" .. id
        sound.Parent = sounds
    end
end
local settings = {
    {"UI_3_Clicks_02_Hover", "Hover", .13, 1.1},
    {"ui-simple-button-click", "Click", .23, 1},
    {"UI - Confirm 1", "Confirm", .28, 1},
    {"ui-simple-negative-error", "Unavailable", .19, 1},
}
for _, data in ipairs(settings) do
    local sound = sounds:FindFirstChild(data[1]) or sounds:FindFirstChild(data[2])
    sound.Name = data[2]
    sound.Volume = data[3]
    sound.PlaybackSpeed = data[4]
    sound.Looped = false
    sound.PlayOnRemove = false
end
gui:SetAttribute("GlossInterval", 7)
return "Shop gloss and quiet audio authored"
