assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
local C = Enum.SecurityCapability
local catalog = game.ReplicatedStorage.PlaygroundCatalog
local equipment = game.ServerScriptService.PlaygroundEquipmentService
local pets = game.StarterPlayer.StarterPlayerScripts.PlaygroundPets
local backup = game.ServerStorage.AssetIntegrationBackup20261004
for _,object in {catalog, equipment, pets} do
	local name = "PermissionsBefore_" .. object.Name
	if not backup:FindFirstChild(name) then
		local record = Instance.new("ObjectValue")
		record.Name = name
		record.Value = object
		record:SetAttribute("Sandboxed", object.Sandboxed)
		record:SetAttribute("CapabilitiesText", tostring(object.Capabilities))
		record.Parent = backup
	end
end
catalog.Capabilities = SecurityCapabilities.new(C.Basic, C.RunClientScript, C.RunServerScript)
equipment.Capabilities = SecurityCapabilities.new(C.RunServerScript, C.Basic, C.AccessOutsideWrite, C.CreateInstances, C.Physics, C.UI, C.Players, C.AvatarBehavior, C.Input)
equipment.Sandboxed = true
pets.Capabilities = SecurityCapabilities.new(C.Basic, C.AccessOutsideWrite, C.CreateInstances, C.RunClientScript, C.Physics, C.UI, C.Players, C.AvatarBehavior)
pets.Sandboxed = true
return {catalog = tostring(catalog.Capabilities), equipment = tostring(equipment.Capabilities), pets = tostring(pets.Capabilities)}
