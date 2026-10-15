local HttpService = game:GetService("HttpService")
local backup = assert(game.ServerStorage:FindFirstChild("StorageFacingBackup20261012"))
local arena = workspace["Hide and Seek"]
local spots = arena.Gameplay.LockerSpots
local version = "20261012-storage-facing-v1"
local frontParts = {SA21 = "SA21_B02_M02", SA22 = "SA22_B03_M02", SA23 = "SA23_B08_M02"}
local fields = {"Size", "Color", "Material", "MaterialVariant", "Transparency", "Anchored", "CanCollide", "CanTouch", "CanQuery", "Massless", "CastShadow", "CollisionGroup", "Reflectance"}
local attributes = {"SchoolFacingVersion", "StorageFacingVersion", "SchoolFrontAxis"}
local checks, worldCount, templates, meshes, helpers = 0, 0, 0, 0, 0
local function check(condition, message)
 assert(condition, message)
 checks += 1
end
local function sameCF(a, b)
 return (a.Position - b.Position).Magnitude < .008 and a.RightVector:Dot(b.RightVector) > .99999 and a.UpVector:Dot(b.UpVector) > .99999
end
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include
overlap.FilterDescendantsInstances = {arena}
overlap.RespectCanCollide = true
local originals = backup.OriginalModels:GetChildren()
table.sort(originals, function(a, b) return a.Name < b.Name end)
local manifest = {}
for _, original in originals do
 local model = assert(backup.Targets[original.Name].Value)
 local pivot = original:GetPivot()
 local exception = model == spots:FindFirstChild("Room01_HidingStorage")
 local nextPivot = exception and pivot * CFrame.Angles(0, math.pi, 0) or pivot
 local delta = pivot * CFrame.Angles(0, math.pi, 0) * pivot:Inverse()
 local parts = {}
 local attrs = {}
 for _, name in attributes do attrs[name] = original:GetAttribute(name) end
 check(sameCF(model:GetPivot(), nextPivot), "Storage model pivot changed")
 check(model:GetAttribute("StorageFacingVersion") == version, "Facing version missing")
 check(#model:GetDescendants() == #original:GetDescendants(), "Storage descendants changed")
 for _, before in original:GetDescendants() do
  if before:IsA("BasePart") then
   local after = assert(model:FindFirstChild(before.Name, true))
   local visual = before:IsA("MeshPart") and before.Name:match("^SA%d%d_") ~= nil
   local expected = (exception ~= visual) and delta * before.CFrame or before.CFrame
   check(sameCF(after.CFrame, expected), "Storage part facing changed unexpectedly: " .. after:GetFullName())
   for _, name in fields do check(after[name] == before[name], "Storage property changed: " .. name) end
   if before:IsA("MeshPart") then
    check(after.MeshId == before.MeshId and after.TextureID == before.TextureID, "Mesh or texture changed")
    meshes += 1
   else helpers += 1 end
   local priorAppearance, currentAppearance = before:FindFirstChildOfClass("SurfaceAppearance"), after:FindFirstChildOfClass("SurfaceAppearance")
   check((priorAppearance == nil) == (currentAppearance == nil), "Surface appearance was removed or added")
   table.insert(parts, {name = before.Name, cf = {before.CFrame:GetComponents()}, changed = not sameCF(before.CFrame, after.CFrame)})
  elseif before:IsA("ProximityPrompt") then
   local after = model:FindFirstChild(before.Name, true)
   check(after and after.Enabled == before.Enabled and after.ActionText == before.ActionText and after.MaxActivationDistance == before.MaxActivationDistance and after.RequiresLineOfSight == before.RequiresLineOfSight and after.KeyboardKeyCode == before.KeyboardKeyCode and after.GamepadKeyCode == before.GamepadKeyCode, "Storage interaction changed")
  end
 end
 local face = assert(model:FindFirstChild(frontParts[model:GetAttribute("HSPropId")], true))
 check(model:GetPivot():PointToObjectSpace(face.Position).Z < -.5, "Visible storage front is backwards")
 if model.Parent == spots then
  worldCount += 1
  check(model:GetPivot():PointToObjectSpace(model.Door.Position).Z < -.5, "Door is behind the visible front")
  check(model:GetPivot():PointToObjectSpace(model.ExitPoint.Position).Z < -3, "Exit is behind the visible front")
  local blockers = {}
  for _, hit in workspace:GetPartBoundsInBox(CFrame.new(model.ExitPoint.Position), Vector3.new(2.5, 4.5, 2.5), overlap) do
   if not hit:IsDescendantOf(model) then table.insert(blockers, hit:GetFullName()) end
  end
  check(#blockers == 0, "Blocked exit: " .. model.Name .. " " .. table.concat(blockers, ", "))
  if not exception then
   for _, name in {"Door", "HidePoint", "ExitPoint", "CollisionHull"} do check(sameCF(model[name].CFrame, original[name].CFrame), "Safe helper moved: " .. model.Name .. "." .. name) end
  else
   check((model:GetPivot().Position - pivot.Position).Magnitude < .008, "User storage position moved")
  end
 else templates += 1 end
 table.sort(parts, function(a, b) return a.name < b.name end)
 table.insert(manifest, {path = model:GetFullName(), backupName = original.Name, pivot = {pivot:GetComponents()}, attributes = attrs, room01Exception = exception, parts = parts})
end
check(worldCount == 76 and templates == 3, "Unexpected corrected storage count")
local report = {version = version, worldStorage = worldCount, templates = templates, visualMeshes = meshes, helperParts = helpers, validationChecks = checks, safeExits = 76, room01Exit = tostring(spots.Room01_HidingStorage.ExitPoint.Position), room01PositionPreserved = true, room01AppearancePreserved = true, backup = backup:GetFullName(), published = false}
if not backup:FindFirstChild("Manifest") then
 local folder = Instance.new("Folder")
 folder.Name = "Manifest"
 folder.Parent = backup
 local encoded = HttpService:JSONEncode({summary = report, models = manifest})
 for index = 1, math.ceil(#encoded / 60000) do
  local chunk = Instance.new("StringValue")
  chunk.Name = string.format("Chunk%03d", index)
  chunk.Value = encoded:sub((index - 1) * 60000 + 1, index * 60000)
  chunk.Parent = folder
 end
end
backup:SetAttribute("Installed", true)
return HttpService:JSONEncode(report)

