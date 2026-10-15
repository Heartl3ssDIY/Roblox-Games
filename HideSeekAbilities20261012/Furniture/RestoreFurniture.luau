local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Stop Play before restoring school furniture")
local backup = assert(game:GetService("ServerStorage"):FindFirstChild("HideSeekFurnitureBackup20261012"))
assert(not backup:GetAttribute("Restored"), "This backup was already restored")
local records = backup.Transforms:GetChildren()
table.sort(records, function(a, b) return a.Name < b.Name end)
for index, record in records do
 local target = assert(record.Target.Value, "Missing furniture target")
 local originalParent = assert(record.OriginalParent.Value, "Missing original furniture parent")
 target:PivotTo(record.Value)
 target.Parent = originalParent
 if index % 30 == 0 then task.wait() end
end
local school = workspace["Hide and Seek"].Geometry.PlaygroundPrimarySchool
school:SetAttribute("FurnitureVarietyVersion", nil)
school:SetAttribute("EmptyStudentChairSpots", nil)
backup:SetAttribute("Restored", true)
return "Restored " .. #records .. " furniture models"

