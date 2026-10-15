local equipment = game.ServerScriptService.PlaygroundEquipmentService
assert(not game:GetService("RunService"):IsRunning(), "Stop Play before installing")
if equipment.Capabilities:Contains(Enum.SecurityCapability.AvatarAppearance) then return "Already installed" end
assert(game.ServerScriptService.PlaygroundBootstrap.Capabilities:Contains(Enum.SecurityCapability.AvatarAppearance))
local prior = equipment.Capabilities
local backup = Instance.new("Folder")
backup.Name = "EquipmentAccessoryPermissionBackup20261011"
backup.Parent = game.ServerStorage
equipment:Clone().Parent = backup
equipment.Capabilities = prior:Add(Enum.SecurityCapability.AvatarAppearance)
assert(equipment.Capabilities:Remove(Enum.SecurityCapability.AvatarAppearance) == prior)
return "Installed AvatarAppearance for equipment cleanup"
