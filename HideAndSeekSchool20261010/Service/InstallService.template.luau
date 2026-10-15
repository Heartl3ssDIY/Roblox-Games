assert(not game:GetService("RunService"):IsRunning(), "Stop Play before installing")
assert(game.PlaceId == 95034648955135 and game.GameId == 10769034155, "Wrong experience")
local services = game:GetService("ServerScriptService")
assert(not services:FindFirstChild("HideAndSeekService"), "Inspect the existing Hide and Seek service before reinstalling")
local template = services:FindFirstChild("TagService")
assert(template and template:IsA("ModuleScript") and template.Sandboxed, "Tag permission template is missing")
assert(tostring(template.Capabilities) == "RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | Animation | AvatarAppearance | Environment | RemoteEvent | LegacySound | Players | AvatarBehavior", "Existing capability template changed")
local arena = workspace:FindFirstChild("Hide and Seek")
assert(arena and arena:FindFirstChild("Gameplay"), "Build the school map first")
local module = Instance.new("ModuleScript")
module.Name = "HideAndSeekService"
module.Sandboxed = true
module.Capabilities = template.Capabilities:Add(SecurityCapabilities.new(Enum.SecurityCapability.Input))
module.Source = [======[__SERVICE_SOURCE__]======]
module:SetAttribute("BuildDate", "2026-10-10")
module:SetAttribute("NativeFixtureChecks", 131)
module.Parent = services
local ok, result = pcall(require, module)
if not ok or type(result) ~= "table" or type(result.new) ~= "function" or type(result.StartRound) ~= "function"
	or type(result.TryBatSwing) ~= "function" or type(result.ExitLocker) ~= "function" then
	module:Destroy()
	error("Hide and Seek installation failed: " .. tostring(result))
end
return { path = module:GetFullName(), capabilities = tostring(module.Capabilities), sourceLength = #module.Source, nativeChecks = 131 }
