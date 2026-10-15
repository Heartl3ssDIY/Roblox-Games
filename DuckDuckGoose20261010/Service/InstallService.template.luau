assert(not game:GetService("RunService"):IsRunning(), "Stop Play before installing Duck Duck Goose")
assert(game.PlaceId == 95034648955135 and game.GameId == 10769034155, "Wrong experience")
local services = game:GetService("ServerScriptService")
assert(not services:FindFirstChild("DuckDuckGooseService"), "Duck Duck Goose service already exists; inspect before reinstalling")
local template = services:FindFirstChild("HideAndSeekService")
assert(template and template:IsA("ModuleScript") and template.Sandboxed, "The existing game permission template is missing")
local arena = workspace:FindFirstChild("Duck Duck Goose")
assert(arena and arena:FindFirstChild("Gameplay") and arena.Gameplay:FindFirstChild("Seats"), "Build the fifth game island first")
local module = Instance.new("ModuleScript")
module.Name, module.Sandboxed, module.Capabilities = "DuckDuckGooseService", true, template.Capabilities
module.Source = [======[__SERVICE_SOURCE__]======]
module:SetAttribute("BuildDate", "2026-10-10")
module.Parent = services
local ok, exported = pcall(require, module)
if not ok or type(exported) ~= "table" or type(exported.new) ~= "function" or type(exported.StartRound) ~= "function"
	or type(exported.TryBatSwing) ~= "function" or type(exported.ClaimSeat) ~= "function" then
	module:Destroy()
	error("Duck Duck Goose installation failed: " .. tostring(exported))
end
return { path = module:GetFullName(), capabilities = tostring(module.Capabilities), sourceLength = #module.Source }
