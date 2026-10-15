assert(not game:GetService("RunService"):IsRunning(), "Stop Play before installing.")
assert(game.PlaceId == 95034648955135 and game.GameId == 10769034155, "Wrong experience.")
local targets = {
 {script = game.ServerScriptService.PlaygroundBootstrap, expected = "RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | DataStore | Physics | UI | Animation | AvatarAppearance | Input | Environment | RemoteEvent | LegacySound | Players | Monetization | PromptExternalPurchase | AvatarBehavior"},
 {script = game.ServerScriptService.PlaygroundCommerceService, expected = "RunServerScript | AccessOutsideWrite | CreateInstances | Basic | DataStore | UI | RemoteEvent | Players | Monetization | PromptExternalPurchase"},
 {script = game.StarterGui.PlaygroundShell.CommerceController, expected = "RunClientScript | AccessOutsideWrite | Basic | UI | Input | RemoteEvent | Players | Monetization | PromptExternalPurchase"},
 {script = game.StarterGui.PlaygroundDonations.Controller, expected = "RunClientScript | AccessOutsideWrite | Basic | UI | Input | RemoteEvent | Players | Monetization | PromptExternalPurchase"},
}
local storage = game:GetService("ServerStorage")
assert(not storage:FindFirstChild("CommerceAvailabilityBackup20261008"), "Backup already exists; inspect before reinstalling.")
for _, target in targets do
 assert(target.script.Sandboxed and tostring(target.script.Capabilities) == target.expected, "Capabilities changed: " .. target.script:GetFullName())
 target.originalCapabilities = target.script.Capabilities
end
local backup = Instance.new("Folder")
backup.Name = "CommerceAvailabilityBackup20261008"
backup:SetAttribute("Purpose", "Before adding read-only AssetRead for product information and pass ownership")
backup.Parent = storage
for _, target in targets do
 local copy = target.script:Clone()
 copy.Name = target.script:GetFullName():gsub("%.", "_")
 copy:SetAttribute("OriginalCapabilities", tostring(target.script.Capabilities))
 copy:SetAttribute("OriginalPath", target.script:GetFullName())
 if copy:IsA("BaseScript") then
  copy:SetAttribute("OriginalEnabled", copy.Enabled)
  copy.Enabled = false
 end
 copy.Parent = backup
end
local read = SecurityCapabilities.new(Enum.SecurityCapability.AssetRead)
local ok, problem = pcall(function()
 for _, target in targets do target.script.Capabilities = target.originalCapabilities:Add(read) end
end)
if not ok then
 for _, target in targets do target.script.Capabilities = target.originalCapabilities end
 error(problem)
end
local result = {}
for _, target in targets do
 result[#result + 1] = {path = target.script:GetFullName(), capabilities = tostring(target.script.Capabilities)}
end
return game:GetService("HttpService"):JSONEncode(result)
