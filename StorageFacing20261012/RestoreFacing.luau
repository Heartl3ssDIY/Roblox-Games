assert(not game:GetService("RunService"):IsRunning(), "Stop Play before restoring storage")
local backup = assert(game.ServerStorage:FindFirstChild("StorageFacingBackup20261012"))
assert(backup:GetAttribute("Installed") and not backup:GetAttribute("Restored"), "Storage backup is not available to restore")
local attributes = {"SchoolFacingVersion", "StorageFacingVersion", "SchoolFrontAxis"}
local count = 0
for _, original in backup.OriginalModels:GetChildren() do
 local target = assert(backup.Targets[original.Name].Value, "Missing storage target")
 for _, before in original:GetDescendants() do
  if before:IsA("BasePart") then
   local current = assert(target:FindFirstChild(before.Name, true), "Missing storage part")
   current.CFrame = before.CFrame
  end
 end
 target.WorldPivot = original:GetPivot()
 for _, name in attributes do target:SetAttribute(name, original:GetAttribute(name)) end
 count += 1
 if count % 8 == 0 then task.wait() end
end
backup:SetAttribute("Restored", true)
return "Restored storage transforms for " .. count .. " models"

