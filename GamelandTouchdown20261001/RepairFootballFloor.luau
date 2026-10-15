local arena = workspace["Oni's Work"].FootballMayhem
local assets = game.ReplicatedStorage.FootballMayhem
local base = arena.FieldBase
assets.ArenaOrigin.Value = base.CFrame * CFrame.new(0, base.Size.Y / 2, 0)
local top = base.Position.Y + base.Size.Y / 2
for _, part in ipairs(arena.Rows:GetDescendants()) do
    if part:IsA("BasePart") then
        top = math.max(top, part.Position.Y + part.Size.Y / 2)
        part.CanCollide = false
    end
end
local floor = arena:FindFirstChild("SupportFloor") or Instance.new("Part")
floor.Name = "SupportFloor"
floor.Size = Vector3.new(base.Size.X, 4, base.Size.Z)
floor.CFrame = CFrame.new(base.Position.X, top + 0.01 - 2, base.Position.Z) * base.CFrame.Rotation
floor.Anchored = true
floor.Transparency = 1
floor.CanCollide = true
floor.CanTouch = false
floor.CanQuery = true
floor.TopSurface = Enum.SurfaceType.Smooth
floor.BottomSurface = Enum.SurfaceType.Smooth
floor.Parent = arena
arena.StartZone.CanCollide = false
arena.EndZone.CanCollide = false
base.CanCollide = true
return {floorTop = top + 0.01, origin = tostring(assets.ArenaOrigin.Value)}
