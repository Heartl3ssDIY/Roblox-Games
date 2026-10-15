local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Install in Edit mode only")
local lobby = workspace:FindFirstChild("Playground Lobby")
assert(lobby and lobby:FindFirstChild("Pond"), "Existing lobby pond is required")
local previous = lobby:FindFirstChild("PondFishing")
if previous then
    assert(previous:GetAttribute("BuildVersion") == "20261007.1", "Preserve unknown existing fishing model")
    return "Already installed; existing station positions preserved"
end

local palette = {
    ink = Color3.fromRGB(20, 31, 49),
    teal = Color3.fromRGB(56, 181, 183),
    cream = Color3.fromRGB(255, 244, 205),
    wood = Color3.fromRGB(192, 127, 73),
    gold = Color3.fromRGB(255, 200, 73),
    coral = Color3.fromRGB(252, 109, 107),
}
local scene = Instance.new("Model")
scene.Name = "PondFishing"
scene.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
scene:SetAttribute("BuildVersion", "20261007.1")
scene:SetAttribute("DailyCatches", 3)
scene:SetAttribute("MinutesPerCatch", 5)

local function part(parent, name, size, cf, color, shape)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.CFrame = cf
    p.Color = color
    p.Anchored = true
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.Material = Enum.Material.SmoothPlastic
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    if shape then p.Shape = shape end
    p.Parent = parent
    return p
end

local function rodSegment(parent, name, a, b, diameter, color)
    return part(parent, name, Vector3.new((b - a).Magnitude, diameter, diameter),
        CFrame.lookAt((a + b) * 0.5, b) * CFrame.Angles(0, math.pi / 2, 0), color, Enum.PartType.Cylinder)
end

local positions = {
    {Vector3.new(-82, 4, 58), Vector3.new(-82, 4.45, 70)},
    {Vector3.new(-42, 4, 58), Vector3.new(-42, 4.45, 70)},
    {Vector3.new(-82, 4, 106), Vector3.new(-82, 4.45, 94)},
    {Vector3.new(-42, 4, 106), Vector3.new(-42, 4.45, 94)},
}

for index, config in ipairs(positions) do
    local station = Instance.new("Model")
    station.Name = "Rod" .. index
    station.Parent = scene
    local position, water = config[1], config[2]
    local facing = CFrame.lookAt(position, Vector3.new(water.X, position.Y, water.Z))
    station:SetAttribute("StationId", index)
    station:SetAttribute("StandPosition", position + Vector3.new(0, 3, 0))
    station:SetAttribute("WaterPosition", water)
    station:SetAttribute("Busy", false)
    local rod = Instance.new("Model")
    rod.Name = "Rod"
    rod.Parent = station
    local function at(x, y, z) return facing * Vector3.new(x, y, z) end
    local plinth = part(rod, "StandInk", Vector3.new(2.25, 0.2, 2.3), facing * CFrame.new(1.3, 0.1, -0.1), palette.ink)
    part(rod, "StandTop", Vector3.new(2.03, 0.16, 2.08), plinth.CFrame * CFrame.new(0, 0.16, 0), palette.wood).TopSurface = Enum.SurfaceType.Studs
    part(rod, "StandPost", Vector3.new(0.32, 1.65, 0.32), facing * CFrame.new(1.3, 1.08, -0.1), palette.ink)
    part(rod, "RodCradle", Vector3.new(0.92, 0.22, 0.5), facing * CFrame.new(1.3, 1.88, -0.1), palette.gold)
    local a, b = at(1.3, 1.4, 0.45), at(1.3, 6.6, -5.5)
    local direction = (b - a).Unit
    rodSegment(rod, "Grip", a, a + direction * 1.6, 0.42, palette.ink)
    for ring = 0, 4 do
        local c = a + direction * (0.25 + ring * 0.25)
        rodSegment(rod, "GripWrap" .. ring, c, c + direction * 0.07, 0.44, palette.cream)
    end
    rodSegment(rod, "Shaft", a + direction * 1.58, b, 0.23, palette.teal)
    for joint = 1, 3 do
        local c = a:Lerp(b, 0.2 + joint * 0.22)
        rodSegment(rod, "ShaftBand" .. joint, c, c + direction * 0.13, 0.31, palette.ink)
    end
    local tip = at(1.3, 6.35, -7.0)
    local tipPart = rodSegment(rod, "FlexibleTip", b, tip, 0.15, palette.ink)
    local reelCF = facing * CFrame.new(1.0, 2.56, -0.7)
    part(rod, "ReelRim", Vector3.new(0.3, 1.05, 1.05), reelCF, palette.ink, Enum.PartType.Cylinder)
    part(rod, "ReelSpool", Vector3.new(0.38, 0.8, 0.8), reelCF, palette.gold, Enum.PartType.Cylinder)
    part(rod, "ReelHub", Vector3.new(0.43, 0.25, 0.25), reelCF, palette.ink, Enum.PartType.Cylinder)
    part(rod, "ReelHandle", Vector3.new(0.2, 0.62, 0.15), reelCF * CFrame.new(-0.26, -0.26, 0), palette.ink)
    part(rod, "ReelKnob", Vector3.new(0.45, 0.23, 0.23), reelCF * CFrame.new(-0.37, -0.52, 0), palette.cream, Enum.PartType.Cylinder)

    local bobber = part(station, "Bobber", Vector3.new(0.65, 0.65, 0.65), CFrame.new(water), palette.coral, Enum.PartType.Ball)
    bobber:SetAttribute("RestCFrame", bobber.CFrame)
    local lineStart = Instance.new("Attachment")
    lineStart.Name = "LineStart"
    lineStart.Position = tipPart.CFrame:PointToObjectSpace(tip)
    lineStart.Parent = tipPart
    local lineEnd = Instance.new("Attachment")
    lineEnd.Name = "LineEnd"
    lineEnd.Position = Vector3.new(0, 0.22, 0)
    lineEnd.Parent = bobber
    local line = Instance.new("Beam")
    line.Name = "FishingLine"
    line.Attachment0 = lineStart
    line.Attachment1 = lineEnd
    line.Width0 = 0.035
    line.Width1 = 0.035
    line.Color = ColorSequence.new(palette.cream)
    line.Transparency = NumberSequence.new(0.15)
    line.FaceCamera = true
    line.Segments = 10
    line.LightEmission = 0.1
    line.Parent = rod
    local interaction = part(station, "Interaction", Vector3.new(1, 1, 1), facing * CFrame.new(0, 2.6, 0), palette.ink)
    interaction.Transparency = 1
    station.PrimaryPart = interaction
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "Fish"
    prompt.ActionText = "Fish"
    prompt.ObjectText = "5-minute boost"
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
    prompt.HoldDuration = 0.4
    prompt.MaxActivationDistance = 9
    prompt.RequiresLineOfSight = false
    prompt.Parent = interaction
end

local sign = Instance.new("Model")
sign.Name = "FishingSign"
sign.Parent = scene
local signCF = CFrame.new(-95, 8, 57.5) * CFrame.Angles(0, math.rad(-22), 0)
part(sign, "Post", Vector3.new(0.6, 4.4, 0.6), signCF * CFrame.new(0, -1.8, 0), palette.ink)
local board = part(sign, "BoardInk", Vector3.new(9.4, 3.6, 0.48), signCF, palette.ink)
for _,side in ipairs({-1, 1}) do
    local face = part(sign, "Face", Vector3.new(9.12, 3.32, 0.06), signCF * CFrame.new(0, 0, side * 0.27), palette.cream)
    local gui = Instance.new("SurfaceGui")
    gui.Name = "FishingInformation"
    gui.Face = side < 0 and Enum.NormalId.Front or Enum.NormalId.Back
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 48
    gui.LightInfluence = 0
    gui.Parent = face
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.BackgroundTransparency = 1
    title.Size = UDim2.fromScale(1, 0.42)
    title.Position = UDim2.fromScale(0, 0.03)
    title.Font = Enum.Font.FredokaOne
    title.Text = "FISHING"
    title.TextColor3 = palette.teal
    title.TextSize = 44
    title.Parent = gui
    local stroke = Instance.new("UIStroke")
    stroke.Color = palette.ink
    stroke.Thickness = 2
    stroke.Parent = title
    local text = Instance.new("TextLabel")
    text.Name = "Details"
    text.BackgroundTransparency = 1
    text.Position = UDim2.fromScale(0.02, 0.45)
    text.Size = UDim2.fromScale(0.96, 0.49)
    text.Font = Enum.Font.FredokaOne
    text.TextSize = 23
    text.TextColor3 = palette.ink
    text.Text = "3 CATCHES A DAY\n+5 MIN • 2× COINS OR XP"
    text.Parent = gui
end
scene.Parent = lobby
return "Installed four fishing stations on the existing pond banks"
