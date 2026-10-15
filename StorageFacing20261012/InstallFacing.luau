local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Stop Play before correcting storage facing")
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")
local arena = assert(workspace:FindFirstChild("Hide and Seek"))
local spots = assert(arena.Gameplay:FindFirstChild("LockerSpots"))
local library = assert(game.ReplicatedStorage:FindFirstChild("SchoolPropTemplates"))
local version = "20261012-storage-facing-v1"
local frontParts = {SA21 = "SA21_B02_M02", SA22 = "SA22_B03_M02", SA23 = "SA23_B08_M02"}
local fields = {"Size", "Color", "Material", "MaterialVariant", "Transparency", "Anchored", "CanCollide", "CanTouch", "CanQuery", "Massless", "CastShadow", "CollisionGroup", "Reflectance"}
local attributes = {"SchoolFacingVersion", "StorageFacingVersion", "SchoolFrontAxis"}
local models, worldCount, alreadyCorrect = {}, 0, 0
for _, model in spots:GetChildren() do
 if model:IsA("Model") and frontParts[model:GetAttribute("HSPropId")] then
  table.insert(models, model)
  worldCount += 1
 end
end
for id in frontParts do table.insert(models, assert(library:FindFirstChild(id))) end
assert(worldCount == 76 and #models == 79, "Unexpected school storage count")
table.sort(models, function(a, b) return a:GetFullName() < b:GetFullName() end)
for _, model in models do
 if model:GetAttribute("StorageFacingVersion") == version then alreadyCorrect += 1 end
end
if alreadyCorrect == #models then return HttpService:JSONEncode({alreadyInstalled = true, models = #models}) end
assert(alreadyCorrect == 0, "Partially applied facing correction; inspect the existing backup")
assert(not ServerStorage:FindFirstChild("StorageFacingBackup20261012"), "An existing storage backup requires inspection")
local function sameCF(a, b)
 return (a.Position - b.Position).Magnitude < .008 and a.RightVector:Dot(b.RightVector) > .99999 and a.UpVector:Dot(b.UpVector) > .99999
end
local entries, meshCount, markerCount = {}, 0, 0
for _, model in models do
 assert(not model.PrimaryPart, "Storage must retain its independent model pivot")
 local pivot = model:GetPivot()
 local entry = {model = model, pivot = pivot, parts = {}, attrs = {}, path = model:GetFullName()}
 for _, name in attributes do entry.attrs[name] = model:GetAttribute(name) end
 local front = assert(model:FindFirstChild(frontParts[model:GetAttribute("HSPropId")], true))
 assert(pivot:PointToObjectSpace(front.Position).Z > .5, "Storage visual is already facing forward: " .. model.Name)
 entry.exception = model == spots:FindFirstChild("Room01_HidingStorage")
 entry.nextPivot = entry.exception and pivot * CFrame.Angles(0, math.pi, 0) or pivot
 entry.delta = pivot * CFrame.Angles(0, math.pi, 0) * pivot:Inverse()
 for _, part in model:GetDescendants() do
  if part:IsA("BasePart") then
   local state = {cf = part.CFrame, properties = {}, visual = part:IsA("MeshPart") and part.Name:match("^SA%d%d_") ~= nil}
   for _, name in fields do state.properties[name] = part[name] end
   if part:IsA("MeshPart") then state.meshId = part.MeshId state.textureId = part.TextureID end
   state.appearances = 0
   for _, child in part:GetChildren() do if child:IsA("SurfaceAppearance") then state.appearances += 1 end end
   if state.visual then meshCount += 1 else markerCount += 1 end
   state.nextCF = (entry.exception ~= state.visual) and entry.delta * state.cf or state.cf
   entry.parts[part] = state
  end
 end
 table.insert(entries, entry)
end
local exception = assert(spots:FindFirstChild("Room01_HidingStorage"))
local originalExceptionPivot = exception:GetPivot()
assert(math.abs(originalExceptionPivot.Position.X - 10943.79785) < .01 and math.abs(originalExceptionPivot.Position.Z - 4515.68799) < .01, "Room01 was moved again; recheck its clearance")
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include
overlap.FilterDescendantsInstances = {arena}
overlap.RespectCanCollide = true
local function exitClear(model, cf)
 for _, hit in workspace:GetPartBoundsInBox(CFrame.new(cf.Position), Vector3.new(2.5, 4.5, 2.5), overlap) do
  if not hit:IsDescendantOf(model) then return false, hit:GetFullName() end
 end
 return true
end
for _, entry in entries do
 if entry.model.Parent == spots then
  local exit = assert(entry.model:FindFirstChild("ExitPoint"))
  local clear, obstruction = exitClear(entry.model, entry.parts[exit].nextCF)
  assert(clear, "Proposed storage exit is blocked: " .. entry.model.Name .. " / " .. tostring(obstruction))
 end
end
local backup = Instance.new("Folder")
backup.Name = "StorageFacingBackup20261012"
backup:SetAttribute("Version", version)
backup.Parent = ServerStorage
local originals = Instance.new("Folder")
originals.Name = "OriginalModels"
originals.Parent = backup
local links = Instance.new("Folder")
links.Name = "Targets"
links.Parent = backup
for index, entry in entries do
 local copy = entry.model:Clone()
 copy.Name = string.format("%03d_%s", index, entry.model.Name)
 copy:SetAttribute("StorageRepairOriginalPath", entry.path)
 copy:SetAttribute("StorageRepairOriginalName", entry.model.Name)
 copy.Parent = originals
 local link = Instance.new("ObjectValue")
 link.Name = copy.Name
 link.Value = entry.model
 link.Parent = links
 entry.backupName = copy.Name
 if index % 8 == 0 then task.wait() end
end
local checks = 0
local function check(condition, message)
 assert(condition, message)
 checks += 1
end
local success, failure = pcall(function()
 for index, entry in entries do
  for part, state in entry.parts do part.CFrame = state.nextCF end
  entry.model.WorldPivot = entry.nextPivot
  entry.model:SetAttribute("StorageFacingVersion", version)
  entry.model:SetAttribute("SchoolFacingVersion", version)
  entry.model:SetAttribute("SchoolFrontAxis", "-Z")
  if index % 8 == 0 then task.wait() end
 end
 for _, entry in entries do
  check(sameCF(entry.model:GetPivot(), entry.nextPivot), "Unexpected model pivot")
  for part, state in entry.parts do
   check(sameCF(part.CFrame, state.nextCF), "Incorrect part transform: " .. part:GetFullName())
   for _, name in fields do check(part[name] == state.properties[name], "Storage property changed: " .. name) end
   if part:IsA("MeshPart") then check(part.MeshId == state.meshId and part.TextureID == state.textureId, "Mesh or texture changed") end
   local appearances = 0
   for _, child in part:GetChildren() do if child:IsA("SurfaceAppearance") then appearances += 1 end end
   check(appearances == state.appearances, "Surface appearance changed")
  end
  local model = entry.model
  local face = model:FindFirstChild(frontParts[model:GetAttribute("HSPropId")], true)
  check(model:GetPivot():PointToObjectSpace(face.Position).Z < -.5, "Visible storage front is still backwards")
  if model.Parent == spots then
   local door, hide, exit, hull = model.Door, model.HidePoint, model.ExitPoint, model.CollisionHull
   check(model:GetPivot():PointToObjectSpace(door.Position).Z < -.5, "Door does not match visible front")
   check(model:GetPivot():PointToObjectSpace(exit.Position).Z < -3, "Exit does not match visible front")
   check(exitClear(model, exit.CFrame), "Storage exit is blocked: " .. model.Name)
   check(sameCF(hull.CFrame, entry.parts[hull].nextCF) and hull.CanCollide, "Storage hull changed")
   check(sameCF(hide.CFrame, entry.parts[hide].nextCF), "Hide point changed unexpectedly")
   local prompt = door:FindFirstChildOfClass("ProximityPrompt")
   check(prompt and prompt.Enabled and prompt.ActionText == "Hide", "Hide prompt is missing")
   if not entry.exception then
    check(sameCF(door.CFrame, entry.parts[door].cf) and sameCF(hide.CFrame, entry.parts[hide].cf) and sameCF(exit.CFrame, entry.parts[exit].cf), "Existing safe interaction points moved")
   else
    check((entry.model:GetPivot().Position - entry.pivot.Position).Magnitude < .008, "Room01 placement moved")
    for part, state in entry.parts do if state.visual then check(sameCF(part.CFrame, state.cf), "Room01 user-facing appearance changed") end end
   end
  end
 end
end)
if not success then
 for _, entry in entries do
  for part, state in entry.parts do part.CFrame = state.cf end
  entry.model.WorldPivot = entry.pivot
  for _, name in attributes do entry.model:SetAttribute(name, entry.attrs[name]) end
 end
 backup:SetAttribute("RolledBack", true)
 backup:SetAttribute("Failure", tostring(failure))
 error("Storage repair rolled back: " .. tostring(failure))
end
local manifest = {}
for _, entry in entries do
 local parts = {}
 for part, state in entry.parts do
  table.insert(parts, {name = part.Name, cf = {state.cf:GetComponents()}, changed = not sameCF(state.cf, state.nextCF)})
 end
 table.sort(parts, function(a, b) return a.name < b.name end)
 table.insert(manifest, {path = entry.path, backupName = entry.backupName, pivot = {entry.pivot:GetComponents()}, attributes = entry.attrs, room01Exception = entry.exception, parts = parts})
end
local report = {version = version, worldStorage = worldCount, templates = #models - worldCount, visualMeshes = meshCount, helperParts = markerCount, validationChecks = checks, safeExits = 76, room01Exit = tostring(exception.ExitPoint.Position), room01PositionPreserved = true, room01AppearancePreserved = true, backup = backup:GetFullName(), published = false}
local result = Instance.new("Folder")
result.Name = "Manifest"
result.Parent = backup
local encoded = HttpService:JSONEncode({summary = report, models = manifest})
for index = 1, math.ceil(#encoded / 60000) do
 local chunk = Instance.new("StringValue")
 chunk.Name = string.format("Chunk%03d", index)
 chunk.Value = encoded:sub((index - 1) * 60000 + 1, index * 60000)
 chunk.Parent = result
end
backup:SetAttribute("Installed", true)
return HttpService:JSONEncode(report)

