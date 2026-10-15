assert(not game:GetService("RunService"):IsRunning(), "Edit only; do not change an active test")
local targets = {
 { object = game.ServerScriptService.PlaygroundBootstrap, expected = "RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | DataStore | Physics | UI | Animation | AvatarAppearance | Input | Environment | RemoteEvent | LegacySound | Players | Monetization | AvatarBehavior" },
 { object = game.ServerScriptService.PlaygroundCommerceService, expected = "RunServerScript | AccessOutsideWrite | CreateInstances | Basic | DataStore | UI | RemoteEvent | Players | Monetization" },
 { object = game.StarterGui.PlaygroundShell.CommerceController, expected = "RunClientScript | AccessOutsideWrite | Basic | UI | Input | RemoteEvent | Players | Monetization" },
 { object = game.StarterGui.PlaygroundDonations.Controller, expected = "RunClientScript | AccessOutsideWrite | Basic | UI | Input | RemoteEvent | Players | Monetization" },
}
local added = SecurityCapabilities.new(Enum.SecurityCapability.PromptExternalPurchase)
for _, entry in targets do
 assert(entry.object.Sandboxed, entry.object:GetFullName() .. " no longer sandboxed")
 assert(tostring(entry.object.Capabilities) == entry.expected, entry.object:GetFullName() .. " capabilities changed since audit")
 entry.before = entry.object.Capabilities
end
local backupName = "DonationPermissionsBackup20261008"
assert(not game.ServerStorage:FindFirstChild(backupName), "Permission backup already exists; inspect before repeating")
local backup = Instance.new("Folder")
backup.Name, backup.Parent = backupName, game.ServerStorage
for index, entry in targets do
 local clone = entry.object:Clone()
 clone.Name = tostring(index) .. "_" .. entry.object.Name
 clone:SetAttribute("OriginalPath", entry.object:GetFullName())
 clone.Parent = backup
end
local ok, err = pcall(function()
 for _, entry in targets do entry.object.Capabilities = entry.before:Add(added) end
end)
if not ok then
 for _, entry in targets do pcall(function() entry.object.Capabilities = entry.before end) end
 error(err)
end
local report = {}
for _, entry in targets do
 assert(tostring(entry.object.Capabilities):find("PromptExternalPurchase", 1, true), "Permission was not applied")
 table.insert(report, { path = entry.object:GetFullName(), before = entry.expected, after = tostring(entry.object.Capabilities) })
end
return { installed = true, changes = report, backup = backup:GetFullName(), playStarted = false, purchasePrompted = false, sourcesChanged = false }

