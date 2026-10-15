from pathlib import Path
p=Path(__file__).parent
before=(p/'HideAndSeekService.before.luau').read_text(encoding='utf-8')
after=(p/'HideAndSeekService.luau').read_text(encoding='utf-8')
template='''assert(not game:GetService("RunService"):IsRunning(), "Stop Play before installing school prop hunt")
local source = game.ServerScriptService:FindFirstChild("HideAndSeekService")
local arena = workspace:FindFirstChild("Hide and Seek")
assert(source and source:IsA("ModuleScript") and arena, "Expected school and service are missing")
local expected = [======[__BEFORE__]======]
local replacement = [======[__AFTER__]======]
local function normalized(text) return text:gsub("\\r\\n", "\\n"):gsub("%s+$", "") end
assert(normalized(source.Source) == normalized(expected) or normalized(source.Source) == normalized(replacement), "HideAndSeekService changed after snapshot; inspect current source before merging")
local templates = game.ReplicatedStorage:FindFirstChild("SchoolPropTemplates")
assert(templates and templates:IsA("Folder"), "Install SchoolPropTemplates first")
local eligible = 0
for _, model in ipairs(templates:GetChildren()) do if model:IsA("Model") and model:GetAttribute("HSPropEligible") == true then eligible += 1 end end
assert(eligible > 0, "Install usable school prop templates first")
local storage = game.ServerStorage
local backup = storage:FindFirstChild("SchoolPropHuntServiceBackup20261011")
if not backup then
    backup = Instance.new("Folder") backup.Name = "SchoolPropHuntServiceBackup20261011"
    backup:SetAttribute("OriginalRoundDurationPresent", arena:GetAttribute("RoundDuration") ~= nil)
    if arena:GetAttribute("RoundDuration") ~= nil then backup:SetAttribute("OriginalRoundDuration", arena:GetAttribute("RoundDuration")) end
    local saved = source:Clone() saved.Name, saved.Parent = "HideAndSeekServiceBefore", backup
    backup.Parent = storage
end
local oldCapabilities, oldSandboxed = source.Capabilities, source.Sandboxed
source.Source = replacement
arena:SetAttribute("RoundDuration", 300)
local state = game.ReplicatedStorage:FindFirstChild("HideAndSeekState")
if state then state:SetAttribute("RoundDuration", 300) end
assert(source.Capabilities == oldCapabilities and source.Sandboxed == oldSandboxed, "Script permissions unexpectedly changed")
return { installed = true, templateCount = eligible, seekingSeconds = 300, hidingSeconds = arena:GetAttribute("HideSeconds"), backup = backup:GetFullName(), permissionsPreserved = true }
'''
(p/'InstallService.luau').write_text(template.replace('__BEFORE__',before).replace('__AFTER__',after),encoding='utf-8')
