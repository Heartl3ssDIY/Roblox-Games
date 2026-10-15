assert(not game:GetService("RunService"):IsRunning(), "Stop Play before applying Duck Duck Goose safety checks")
assert(game.PlaceId == 95034648955135 and game.GameId == 10769034155, "Wrong experience")
local module = game.ServerScriptService:WaitForChild("DuckDuckGooseService")
local original = module.Source:gsub("\r\n", "\n")
local digest = 5381
for index = 1, #original do digest = (digest * 33 + string.byte(original, index)) % 4294967296 end
assert(#original == __BEFORE_LENGTH__ and digest == __BEFORE_DIGEST__, "Duck Duck Goose service changed; inspect before updating")
local storage = game:GetService("ServerStorage")
assert(not storage:FindFirstChild("DuckDuckGooseSafetyBackup20261010"), "Safety backup already exists; inspect before reinstalling")
local backup = Instance.new("Folder")
backup.Name = "DuckDuckGooseSafetyBackup20261010"
local saved = module:Clone()
saved.Name, saved.Parent = "DuckDuckGooseServiceBeforeSafety", backup
backup.Parent = storage
module.Source = [======[__SERVICE_SOURCE__]======]
return { path = module:GetFullName(), sourceLength = #module.Source, backup = backup:GetFullName(), capabilities = tostring(module.Capabilities) }
