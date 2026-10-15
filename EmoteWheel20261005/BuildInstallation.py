import json,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parent
icons=json.loads((ROOT/'ItemIconAssets.json').read_text(encoding='utf-8-sig'))
assert len(icons)==56 and all(x['fetchStatus']=='Enum.AssetFetchStatus.Success' for x in icons)
active=[x for x in icons if x['category'] in ['Bats','Pets','Miscellaneous']]
assert len(active)==50 and len({x['id'] for x in active})==50
catalog=(ROOT/'Before/PlaygroundCatalog.luau').read_text(encoding='utf-8-sig')
mapping='local suppliedThumbnails = {\n'+''.join(f'\t["{x["id"]}"] = "{x["assetId"]}",\n' for x in active)+'}\nfor _, entry in ipairs(items) do\n\tif suppliedThumbnails[entry.id] then\n\t\tentry.thumbnail = suppliedThumbnails[entry.id]\n\t\tentry.thumbnailSource = "UI-512"\n\tend\nend\n\n'
assert catalog.count('local byId = {}')==1
catalog=catalog.replace('local byId = {}',mapping+'local byId = {}')
(ROOT/'After/PlaygroundCatalog.luau').write_text(catalog,encoding='utf-8')
entries=[('ReplicatedStorage.PlaygroundCatalog','PlaygroundCatalog.luau'),('ServerScriptService.PlaygroundEconomyService','PlaygroundEconomyService.luau'),('StarterGui.PlaygroundShell.Controller','Shell.Controller.luau'),('StarterGui.PlaygroundToyHotbar.Controller','PlaygroundToyHotbar.Controller.client.luau')]
def quote(text):
    assert ']========]' not in text
    return '[========[\n'+text+']========]'
records=[]
for path,filename in entries:
    before=(ROOT/'Before'/filename).read_text(encoding='utf-8-sig')
    after=(ROOT/'After'/filename).read_text(encoding='utf-8-sig')
    records.append('{path='+json.dumps(path)+',before='+quote(before)+',after='+quote(after)+'}')
body='''assert(not game:GetService("RunService"):IsRunning(), "Install only in Edit mode")
assert(game.PlaceId == 95034648955135, "Wrong place")
local storage = game:GetService("ServerStorage")
local starterGui = game:GetService("StarterGui")
assert(not storage:FindFirstChild("EmoteWheelBackup20261005"), "Backup exists; inspect before repeating")
assert(not starterGui:FindFirstChild("PlaygroundEmoteWheel"), "Existing wheel must be preserved")
local entries = {
'''+',\n'.join(records)+'''
}
local function resolve(path)
    local node = game
    for name in string.gmatch(path, "[^.]+") do node = assert(node:FindFirstChild(name), path .. " missing") end
    return node
end
local function normalized(source) return (source:gsub("\\r\\n", "\\n")) end
for _, entry in ipairs(entries) do
    entry.object = resolve(entry.path)
    assert(normalized(entry.object.Source) == normalized(entry.before), "Source changed: " .. entry.path)
end
local backup = Instance.new("Folder")
backup.Name = "EmoteWheelBackup20261005"
backup:SetAttribute("CreatedFor", "Custom emote wheel and original UI-512 thumbnails")
backup.Parent = storage
for index, entry in ipairs(entries) do
    local copy = entry.object:Clone()
    copy.Name = "Source" .. tostring(index)
    copy:SetAttribute("OriginalPath", entry.path)
    copy.Parent = backup
end
for _, name in ipairs({ "PlaygroundShell", "PlaygroundToyHotbar" }) do
    local copy = starterGui[name]:Clone()
    copy.Name = name .. "UI"
    copy.Parent = backup
end
local ok, result = xpcall(function()
    local buildWheel = function()
'''+(ROOT/'CreateEmoteWheelUI.luau').read_text(encoding='utf-8-sig')+'''
    end
    local wheelResult = buildWheel()
    local buildThumbnails = function()
'''+(ROOT/'InstallItemThumbnails.luau').read_text(encoding='utf-8-sig')+'''
    end
    local thumbnailResult = buildThumbnails()(starterGui)
    for _, entry in ipairs(entries) do entry.object.Source = entry.after end
    local controller = starterGui.PlaygroundToyHotbar.Controller:Clone()
    controller.Name = "Controller"
    controller.Source = '''+quote((ROOT/'After/EmoteWheel.Controller.client.luau').read_text(encoding='utf-8-sig'))+'''
    controller.Parent = starterGui.PlaygroundEmoteWheel
    backup:SetAttribute("Installed", true)
    return { wheel = wheelResult, thumbnails = thumbnailResult, existingScriptCapabilitiesUnchanged = true, controllerCapabilities = tostring(controller.Capabilities), running = false }
end, debug.traceback)
if not ok then
    for _, entry in ipairs(entries) do pcall(function() entry.object.Source = entry.before end) end
    local wheel = starterGui:FindFirstChild("PlaygroundEmoteWheel")
    if wheel then wheel:Destroy() end
    for _, name in ipairs({ "PlaygroundShell", "PlaygroundToyHotbar" }) do
        local current = starterGui:FindFirstChild(name)
        if current then current:Destroy() end
        local restored = backup[name .. "UI"]:Clone()
        restored.Name = name
        restored.Parent = starterGui
    end
    backup:SetAttribute("InstallationError", tostring(result))
    error(result)
end
return game:GetService("HttpService"):JSONEncode(result)
'''
(ROOT/'Install.luau').write_text(body,encoding='utf-8')
manifest={path:{'beforeSHA256':hashlib.sha256((ROOT/'Before'/name).read_bytes()).hexdigest(),'afterSHA256':hashlib.sha256((ROOT/'After'/name).read_bytes()).hexdigest()} for path,name in entries}
(ROOT/'Source-Manifest.json').write_text(json.dumps(manifest,indent=2))
print('Installer prepared:',len(entries),'existing scripts, 1 new controller, 50 catalog PNGs, 56 supplied images verified')
