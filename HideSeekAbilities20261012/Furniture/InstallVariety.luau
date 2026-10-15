local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Stop Play before changing school furniture")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local arena = assert(workspace:FindFirstChild("Hide and Seek"))
local school = assert(arena.Geometry:FindFirstChild("PlaygroundPrimarySchool"))
local props = assert(school:FindFirstChild("SchoolAssetProps"))
local version = "20261012-variety-v1"
assert(not school:GetAttribute("FurnitureVarietyVersion"), "Furniture variety is already installed")
assert(not ServerStorage:FindFirstChild("HideSeekFurnitureBackup20261012"), "Existing furniture backup")
local rooms, plan, removals, summary = {}, {}, {}, {rooms = 0, chairGaps = 0, deskGroups = 0, shiftedChairs = 0, plants = 0, plantsRelocated = 0, pianosCorrected = 0}
local studentCodes = {"111", "112", "121", "122", "211", "212", "221", "222"}
for _, room in school:GetChildren() do
 if room:IsA("Model") and room:GetAttribute("ClassroomNumber") then table.insert(rooms, room) end
end
table.sort(rooms, function(a, b) return a:GetAttribute("ClassroomNumber") < b:GetAttribute("ClassroomNumber") end)
assert(#rooms == 32, "Expected 32 classrooms")
local function add(model, newPivot, kind)
 assert(model and model:IsA("Model"), "Expected furniture model")
 local item = plan[model]
 if not item then
  item = {model = model, before = model:GetPivot(), after = model:GetPivot(), kind = kind}
  plan[model] = item
 end
 if newPivot then item.after = newPivot end
 return item
end
local function pivot(model)
 return plan[model] and plan[model].after or model:GetPivot()
end
for _, room in rooms do
 local number = room:GetAttribute("ClassroomNumber")
 local prefix = string.format("Room%02d_", number)
 local furniture
 for _, child in room:GetChildren() do if child:IsA("Model") and child:FindFirstChild("Table11") then furniture = child break end end
 assert(furniture, "Missing student desks")
 local firstGap = (number * 3 + 1) % 8 + 1
 local secondGap = (firstGap + 3) % 8 + 1
 for index, code in studentCodes do
  local chair = assert(props:FindFirstChild(prefix .. "Chair" .. code), "Missing student chair")
  assert(chair:GetAttribute("SchoolFacingVersion") == "20261011-facing-v2", "Chair facing fix missing")
  if index == firstGap or (number % 2 == 0 and index == secondGap) then
   removals[chair] = true
   add(chair, nil, "ChairGap")
   summary.chairGaps += 1
  end
 end
 for row = 1, 2 do
  for column = 1, 2 do
   local index = (row - 1) * 2 + column
   if (number + index) % 2 == 0 then
    local desk = assert(furniture:FindFirstChild("Table" .. row .. column))
    local center = desk.DeskTop.Position
    local sign = (number + row) % 2 == 0 and 1 or -1
    local angle = math.rad(sign * (5 + (number + column) % 3))
    local delta = CFrame.new(sign * 0.22, 0, (column == 1 and -1 or 1) * 0.16) * CFrame.new(center) * CFrame.Angles(0, angle, 0) * CFrame.new(-center)
    add(desk, delta * pivot(desk), "DeskGroup")
    for chairIndex = 1, 2 do
     local chair = assert(props:FindFirstChild(prefix .. "Chair" .. row .. column .. chairIndex))
     if not removals[chair] then add(chair, delta * pivot(chair), "StudentChair") end
    end
    summary.deskGroups += 1
   end
  end
 end
 for index, code in studentCodes do
  local chair = props:FindFirstChild(prefix .. "Chair" .. code)
  if not removals[chair] and (number + index) % 3 ~= 0 then
   local sign = (number + index) % 2 == 0 and 1 or -1
   local offset = CFrame.new(sign * 0.12, 0, 0.18 + index % 3 * 0.12) * CFrame.Angles(0, math.rad(sign * (3 + (number + index) % 6)), 0)
   add(chair, pivot(chair) * offset, "StudentChair")
   summary.shiftedChairs += 1
  end
 end
 local plant = assert(props:FindFirstChild(prefix .. "Plant"))
 local plantPivot = pivot(plant)
 if room:GetAttribute("Wing") == "Left" then
  local desk = furniture.Table11.DeskTop.Position
  local centerZ = desk.Z + 8.3
  plantPivot = CFrame.new(plantPivot.X, plantPivot.Y, centerZ - 3.5 + (number % 3 - 1) * 1.1)
  summary.plantsRelocated += 1
 end
 add(plant, plantPivot * CFrame.Angles(0, math.rad((number * 17) % 70 - 35), 0), "LoosePlant")
 local piano = props:FindFirstChild(prefix .. "Piano")
 if piano then
  local bench = assert(props:FindFirstChild(prefix .. "PianoBench"))
  local keys = assert(piano:FindFirstChild("SA17_B01_M05", true))
  local keyDirection = keys.Position - piano:GetPivot().Position
  local benchDirection = bench:GetPivot().Position - piano:GetPivot().Position
  assert(Vector3.new(keyDirection.X, 0, keyDirection.Z):Dot(Vector3.new(benchDirection.X, 0, benchDirection.Z)) < 0, "Piano is already facing its bench")
  add(piano, pivot(piano) * CFrame.Angles(0, math.pi, 0), "PianoFacing")
  summary.pianosCorrected += 1
 end
 summary.plants += 1
 summary.rooms += 1
end
for _, model in props:GetChildren() do
 if model:IsA("Model") and model.Name:match("^OutdoorPlant_") then
  local index = tonumber(model.Name:match("(%d+)$"))
  local sign = model.Name:find("West") and -1 or 1
  add(model, pivot(model) * CFrame.Angles(0, math.rad(sign * (8 + index * 3)), 0), "OutdoorPlant")
  summary.plants += 1
 end
end
local list, plannedParts = {}, {}
for _, item in plan do
 item.parts = {}
 for _, part in item.model:GetDescendants() do
  if part:IsA("BasePart") then
   item.parts[part] = {relative = item.before:ToObjectSpace(part.CFrame), size = part.Size, collide = part.CanCollide, query = part.CanQuery, anchored = part.Anchored}
   plannedParts[part] = true
  end
 end
 table.insert(list, item)
end
table.sort(list, function(a, b) return a.model:GetFullName() < b.model:GetFullName() end)
local untouched = {}
for _, part in arena:GetDescendants() do
 if part:IsA("BasePart") and not plannedParts[part] then
  untouched[part] = {cf = part.CFrame, size = part.Size, collide = part.CanCollide, query = part.CanQuery}
 end
end
local backup = Instance.new("Folder")
backup.Name = "HideSeekFurnitureBackup20261012"
backup:SetAttribute("Version", version)
backup:SetAttribute("OriginalSchoolPath", school:GetFullName())
backup.Parent = ServerStorage
local records = Instance.new("Folder")
records.Name = "Transforms"
records.Parent = backup
local removed = Instance.new("Folder")
removed.Name = "RemovedChairs"
removed.Parent = backup
local manifest = {}
for index, item in list do
 local record = Instance.new("CFrameValue")
 record.Name = string.format("%03d_%s", index, item.model.Name)
 record.Value = item.before
 record:SetAttribute("OriginalPath", item.model:GetFullName())
 record:SetAttribute("Kind", item.kind)
 local target = Instance.new("ObjectValue")
 target.Name = "Target"
 target.Value = item.model
 target.Parent = record
 local parent = Instance.new("ObjectValue")
 parent.Name = "OriginalParent"
 parent.Value = item.model.Parent
 parent.Parent = record
 record.Parent = records
 table.insert(manifest, {name = item.model.Name, path = item.model:GetFullName(), kind = item.kind, removed = removals[item.model] == true, before = {item.before:GetComponents()}, after = {item.after:GetComponents()}})
 if removals[item.model] then item.model.Parent = removed
 else item.model:PivotTo(item.after) end
 if index % 30 == 0 then task.wait() end
end
local checks = 0
local function check(condition, message)
 assert(condition, message)
 checks += 1
end
local function sameCF(a, b)
 return (a.Position - b.Position).Magnitude < 0.006 and a.RightVector:Dot(b.RightVector) > 0.99999 and a.UpVector:Dot(b.UpVector) > 0.99999
end
for _, item in list do
 local expected = removals[item.model] and item.before or item.after
 check(sameCF(item.model:GetPivot(), expected), "Model pivot mismatch: " .. item.model.Name)
 check(math.abs(item.model:GetPivot().Y - item.before.Y) < 0.006, "Furniture lifted off its floor")
 for part, state in item.parts do
  check(sameCF(part.CFrame, expected * state.relative), "Visual/collider drift: " .. part:GetFullName())
  check(part.Size == state.size and part.CanCollide == state.collide and part.CanQuery == state.query and part.Anchored == state.anchored, "Furniture properties changed")
 end
 if item.kind == "StudentChair" then
  check(item.model:GetPivot().LookVector.Z > 0.96, "Chair no longer faces teaching wall")
 end
end
for part, state in untouched do
 check(sameCF(part.CFrame, state.cf) and part.Size == state.size and part.CanCollide == state.collide and part.CanQuery == state.query, "Unrelated school geometry changed")
end
for _, room in rooms do
 local number = room:GetAttribute("ClassroomNumber")
 local prefix = string.format("Room%02d_", number)
 local count = 0
 for _, code in studentCodes do if props:FindFirstChild(prefix .. "Chair" .. code) then count += 1 end end
 check(count == (number % 2 == 0 and 6 or 7), "Incorrect chair gaps")
 check(props:FindFirstChild(prefix .. "TeacherChair") ~= nil, "Teacher chair was removed")
 check(props:FindFirstChild(prefix .. "TeachingBoard") ~= nil, "Teaching board was removed")
end
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include
overlap.FilterDescendantsInstances = {arena.Gameplay.LockerSpots}
overlap.RespectCanCollide = false
for _, item in list do
 if item.kind == "LoosePlant" then
  local cf, size = item.model:GetBoundingBox()
  check(#workspace:GetPartBoundsInBox(cf, size + Vector3.new(0.4, 0, 0.4), overlap) == 0, "Plant overlaps cupboard, locker entrance or exit: " .. item.model.Name)
 elseif item.kind == "PianoFacing" then
  local bench = props:FindFirstChild(item.model.Name .. "Bench")
  local keys = item.model:FindFirstChild("SA17_B01_M05", true)
  local toKeys = keys.Position - item.model:GetPivot().Position
  local toBench = bench:GetPivot().Position - item.model:GetPivot().Position
  check(Vector3.new(toKeys.X, 0, toKeys.Z):Dot(Vector3.new(toBench.X, 0, toBench.Z)) > 0, "Piano keyboard faces away from bench")
 end
end
school:SetAttribute("FurnitureVarietyVersion", version)
school:SetAttribute("EmptyStudentChairSpots", summary.chairGaps)
summary.modifiedModels = #list
summary.validationChecks = checks
summary.backup = backup:GetFullName()
summary.remainingStudentChairs = 256 - summary.chairGaps
local audit = Instance.new("StringValue")
audit.Name = "Manifest"
audit.Value = HttpService:JSONEncode({summary = summary, changes = manifest})
audit.Parent = backup
return audit.Value

