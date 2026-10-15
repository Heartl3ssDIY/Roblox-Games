from pathlib import Path
p = Path(__file__).parent
old = Path('SchoolExpansion20261010/TimingBell/NativeChecks.luau').read_text(encoding='utf-8')
prefix = old[:old.index('local ok, failure = xpcall(function()\n\tlocal Service = require(module)(env)')]
a = prefix.index('[======[')
b = prefix.index(']======]', a)
prefix = prefix[:a] + '[======[__SERVICE_SOURCE__]======]' + prefix[b+8:]
prefix = prefix.replace('HideSeekServiceNativeChecks20261010', 'PropHuntServiceNativeChecks20261011')
prefix = prefix.replace('RoundDuration = 180', 'RoundDuration = 300').replace('Search lasts exactly three minutes', 'Search lasts exactly five minutes').replace('service.endsAt - now - 180', 'service.endsAt - now - 300')
prefix = prefix.replace('module.Capabilities = game.ServerScriptService.TagService.Capabilities:Add(SecurityCapabilities.new(Enum.SecurityCapability.Input))', 'module.Capabilities = game.ServerScriptService.HideAndSeekService.Capabilities')
prefix = prefix.replace('local remote = {', '''local templates = Instance.new("Folder") templates.Name, templates.Parent = "SchoolPropTemplates", container
local function template(name, size, eligible)
    local model = Instance.new("Model") model.Name, model.Parent = name, templates
    model:SetAttribute("HSPropId", name) model:SetAttribute("HSPropEligible", eligible) model:SetAttribute("DisplayName", name)
    local body = part(model, "PropBody", Vector3.new(0, size.Y * 0.5, 0), size, true)
    model:PivotTo(CFrame.identity)
    return model
end
local usableTemplate = template("SA01 School chair", Vector3.new(3, 4, 3), true)
template("SA31 Broadleaf plant", Vector3.new(3, 4, 3), true)
template("SA09 Pencil", Vector3.new(0.2, 0.2, 3), true)
template("SA21 Wardrobe", Vector3.new(3, 5, 3), true)
template("SA22 Tray drawer", Vector3.new(4, 4, 3), true)
template("SA99 Tiny", Vector3.new(0.4, 1.5, 0.4), true)
template("SA20 Not enabled", Vector3.new(3, 4, 3), false)
lockerModel:SetAttribute("HSHidingSpotName", "Wardrobe")
local remote = {''')
prefix = prefix.replace('if name == "HideAndSeekState" then return state', 'if name == "SchoolPropTemplates" then return templates elseif name == "HideAndSeekState" then return state')
main = (p/'FixtureBody.luau').read_text(encoding='utf-8')
text = prefix + main
(p/'NativeChecks.template.luau').write_text(text, encoding='utf-8')
(p/'NativeChecks.luau').write_text(text.replace('__SERVICE_SOURCE__', (p/'HideAndSeekService.luau').read_text(encoding='utf-8')), encoding='utf-8')
