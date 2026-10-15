local lobby = workspace["Playground Lobby"]
local scene = assert(lobby:FindFirstChild("PondFishing"))
local checks, stations = {}, {}
local function check(name, passed)
    table.insert(checks, {name = name, passed = passed})
    assert(passed, name)
end
check("Edit mode preserved", not game:GetService("RunService"):IsRunning())
check("Atomic streaming keeps each pond set intact", scene.ModelStreamingMode == Enum.ModelStreamingMode.Atomic)
local ray = RaycastParams.new()
ray.FilterType = Enum.RaycastFilterType.Exclude
ray.FilterDescendantsInstances = {scene}
ray.RespectCanCollide = true
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
overlap.FilterDescendantsInstances = {scene}
overlap.RespectCanCollide = true
for index = 1, 4 do
    local station = assert(scene:FindFirstChild("Rod" .. index))
    local interaction = assert(station:FindFirstChild("Interaction"))
    local prompt = assert(interaction:FindFirstChild("Fish"))
    local bobber = assert(station:FindFirstChild("Bobber"))
    local stand = station:GetAttribute("StandPosition")
    local support = workspace:Raycast(stand + Vector3.new(0, 6, 0), Vector3.new(0, -12, 0), ray)
    check("Rod " .. index .. " stands on existing dry grass", support and support.Instance == lobby.Island.MainGrass and math.abs(support.Position.Y - 4) < 0.01)
    check("Rod " .. index .. " avatar space is clear", #workspace:GetPartBoundsInBox(CFrame.new(stand), Vector3.new(3.5, 5.5, 3.5), overlap) == 0)
    check("Rod " .. index .. " has accessible keyboard/gamepad/touch prompt", prompt.KeyboardKeyCode == Enum.KeyCode.E and prompt.GamepadKeyCode == Enum.KeyCode.ButtonX and prompt.MaxActivationDistance == 9 and math.abs(prompt.HoldDuration - 0.4) < 0.001)
    local line = assert(station.Rod:FindFirstChild("FishingLine"))
    check("Rod " .. index .. " line follows bobber", line.Attachment1.Parent == bobber and line.Attachment0:IsDescendantOf(station.Rod))
    check("Rod " .. index .. " bobber lies over the pond", bobber.Position.Y > 4.24 and bobber.Position.Y < 4.6 and math.abs(bobber.Position.X + 62) <= 22 and math.abs(bobber.Position.Z - 82) < 18.5)
    table.insert(stations, {name = station.Name, interaction = {interaction.Position.X, interaction.Position.Y, interaction.Position.Z}, bobber = {bobber.Position.X, bobber.Position.Y, bobber.Position.Z}, stand = {stand.X, stand.Y, stand.Z}})
end
local parts, highlights, badPhysics = 0, 0, 0
for _,object in ipairs(scene:GetDescendants()) do
    if object:IsA("Highlight") then highlights += 1 end
    if object:IsA("BasePart") then
        parts += 1
        if not object.Anchored or object.CanCollide or object.CanTouch or object.CanQuery then badPhysics += 1 end
    end
end
check("All decorative parts are anchored and collision-free", badPhysics == 0)
check("No scarce Highlight slots used", highlights == 0)
return game:GetService("HttpService"):JSONEncode({passed = true, checks = checks, stations = stations, parts = parts, waterSurface = 4.24})
