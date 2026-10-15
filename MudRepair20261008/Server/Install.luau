assert(not game:GetService("RunService"):IsRunning(), "Keep Studio in Edit mode")
assert(game.PlaceId == 95034648955135, "Unexpected place")
local scriptObject = game:GetService("ServerScriptService"):WaitForChild("StuckInTheMudService")
local function fingerprint(source)
 source = source:gsub("\r\n", "\n"):gsub("%s+$", "")
 local value = 5381
 for index = 1, #source do value = (value * 33 + string.byte(source, index)) % 4294967296 end
 return value
end
local source = scriptObject.Source
if fingerprint(source) == 3701468162 then return { alreadyApplied = true, cameraAllowance = 32 } end
assert(fingerprint(source) == 1582623843, "Mud service changed since inspection; review the current source first")
local old = "if (cameraOrigin - head.Position).Magnitude > 24 then return nil end"
local new = "if (cameraOrigin - head.Position).Magnitude > 32 then return nil end"
local first, last = source:find(old, 1, true)
assert(first and not source:find(old, last + 1, true), "Expected one camera validation")
local candidate = source:sub(1, first - 1) .. new .. source:sub(last + 1)
assert(fingerprint(candidate) == 3701468162, "Unexpected candidate source")
local backup = game:GetService("ServerStorage"):FindFirstChild("MudRepairBackup20261008")
if not backup then backup = Instance.new("Folder") backup.Name = "MudRepairBackup20261008" backup.Parent = game.ServerStorage end
assert(not backup:FindFirstChild("StuckInTheMudService"), "Existing Mud server backup; inspect before installing")
local saved = scriptObject:Clone()
saved.Parent = backup
local capabilities, sandboxed = scriptObject.Capabilities, scriptObject.Sandboxed
scriptObject.Source = candidate
assert(scriptObject.Source == candidate, "Source readback failed")
assert(scriptObject.Capabilities == capabilities and scriptObject.Sandboxed == sandboxed, "Permissions changed")
return { installed = true, cameraAllowance = 32, backup = saved:GetFullName(), capabilitiesPreserved = true }

