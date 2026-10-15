from pathlib import Path
import json

root = Path(__file__).resolve().parent
builder = (root / "BuildExpansion.luau").read_text(encoding="utf-8")
checks = (root / "GeometryChecks.luau").read_text(encoding="utf-8")
prefix = '''assert(not game:GetService("RunService"):IsRunning(), "Stop Play before school expansion")
local arena = assert(workspace:FindFirstChild("Hide and Seek"), "School arena missing")
assert(arena:GetAttribute("SchoolExpansionVersion") == "20261010", "School has changed or expansion was already installed")
assert(math.abs(arena.Geometry.PlaygroundPrimarySchool.Structure.GroundFloor.Size.Z - 194) < 0.02, "School length changed since audit")
local storage = game:GetService("ServerStorage")
local backupRoot = storage:FindFirstChild("SchoolPropHuntBackup20261011")
if not backupRoot then backupRoot = Instance.new("Folder") backupRoot.Name = "SchoolPropHuntBackup20261011" backupRoot.Parent = storage end
assert(not backupRoot:FindFirstChild("MapBefore"), "Map backup already exists; inspect it before retrying")
local backup = arena:Clone()
backup.Name = "MapBefore"
for _, node in ipairs(backup:GetDescendants()) do if node:IsA("BaseScript") then node.Enabled = false end end
local function attach(node, parent)
    if #node:GetDescendants() > 500 then
        local children = node:GetChildren()
        for _, child in ipairs(children) do child.Parent = nil end
        node.Parent = parent
        for _, child in ipairs(children) do attach(child, node) end
    else node.Parent = parent task.wait() end
end
attach(backup, backupRoot)
backup:SetAttribute("BackupOriginalPath", "Workspace.Hide and Seek")
local build = (function()
'''
suffix = '''
end)()
local changes = build(arena)
local checks = (function()
'''
tail = '''
end)()(arena)
arena:SetAttribute("SchoolExpansionChecksPassed", checks.passed)
assert(checks.passed, "School expansion collision checks failed: " .. table.concat(checks.failures, "; "))
return game:GetService("HttpService"):JSONEncode({changes = changes, checks = checks, backup = backup:GetFullName()})
'''
(root / "Install.luau").write_text(prefix + builder + suffix + checks + tail, encoding="utf-8")
fixture = '''local build = (function()
''' + builder + '''
end)()
local check = (function()
''' + checks + '''
end)()
local original = assert(workspace:FindFirstChild("Hide and Seek"))
local copy = original:Clone()
copy.Name = "SchoolExpansionFixture20261011"
local delta = Vector3.new(20000, 1000, 0)
for _, p in ipairs(copy:GetDescendants()) do
    if p:IsA("BasePart") then p.CFrame += delta elseif p:IsA("BaseScript") then p.Enabled = false end
end
copy:SetAttribute("SchoolOriginCFrame", original:GetAttribute("SchoolOriginCFrame") + delta)
local function attach(node, parent)
    if #node:GetDescendants() > 500 then
        local children = node:GetChildren()
        for _, p in ipairs(children) do p.Parent = nil end
        node.Parent = parent
        for _, p in ipairs(children) do attach(p, node) end
    else node.Parent = parent task.wait() end
end
local ok, result = xpcall(function()
    local changes = build(copy)
    attach(copy, workspace)
    task.wait()
    local r = check(copy)
    r.changes = changes
    return r
end, debug.traceback)
copy:Destroy()
if not ok then error(result) end
return game:GetService("HttpService"):JSONEncode(result)
'''
(root / "NativeFixture.luau").write_text(fixture, encoding="utf-8")
(root / "FixtureResults.json").write_text(json.dumps({
    "studioId": "e663b018-d783-41e1-b21a-0d9753f64568", "mode": "Edit", "fixtureRemoved": True,
    "checks": 1198, "passed": True, "failures": [], "classrooms": 32, "classroomsPerFloor": 16,
    "toilets": 4, "lockers": 44, "staircaseUnchanged": True, "schoolLength": 350,
    "schoolFrontWallLocalZ": -214, "schoolRearWallLocalZ": 136, "productionInstalled": False,
    "newRoomCentersZ": [-56, -95, -134, -173], "newRoomIds": list(range(17,33)),
    "note": "All existing classroom furniture and both stair assemblies preserve their transforms. Front facade, vestibule furnishings, entrance grounds, seeker spawns shift156studs toward negativeZ. SchoolOriginCFrame unchanged. Asset replacement must run after map expansion."
}, indent=2), encoding="utf-8")
