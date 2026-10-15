from pathlib import Path
import json

root=Path(__file__).resolve().parent
manifest=json.loads((root/'InstallManifest.json').read_text())
def quote(s):
    eq='===='
    while ']'+eq+']' in s: eq+='='
    return '['+eq+'[\n'+s+']'+eq+']'
entries=[]
for entry in manifest:
    folder=root/entry.get('root','')
    before=(folder/'Before'/entry['file']).read_text(encoding='utf-8-sig')
    after=(folder/'After'/entry['file']).read_text(encoding='utf-8-sig')
    entries.append('{path='+json.dumps(entry['path'])+',before='+quote(before)+',after='+quote(after)+'}')
ui=(root/'InstallEmoteThumbnails.luau').read_text(encoding='utf-8-sig')
source='''assert(not game:GetService("RunService"):IsRunning(), "Install only in Edit mode")
assert(game.PlaceId == 95034648955135, "Wrong place")
local storage=game:GetService("ServerStorage")
assert(not storage:FindFirstChild("EmoteCatalogBackup20261005"), "Installation backup already exists; inspect before repeating")
local entries={
'''+',\n'.join(entries)+'''
}
local function normalize(source) return (source:gsub("\\r\\n", "\\n"):gsub("\\n+$", "")) end
for _,entry in ipairs(entries) do
    local node=game
    for name in entry.path:gmatch("[^%.]+") do node=node and node:FindFirstChild(name) end
    assert(node and node:IsA("LuaSourceContainer"), "Missing script: "..entry.path)
    assert(normalize(node.Source)==normalize(entry.before), "Source changed since snapshot: "..entry.path)
    entry.node=node
    entry.capabilities=tostring(node.Capabilities)
    entry.sandboxed=node.Sandboxed
end
local backup=Instance.new("Folder") backup.Name="EmoteCatalogBackup20261005"
for index,entry in ipairs(entries) do
    local copy=entry.node:Clone()
    copy.Name=string.format("%02d_",index)..entry.node.Name
    copy:SetAttribute("OriginalPath",entry.path)
    copy.Parent=backup
end
backup.Parent=storage
local ui=(function()
'''+ui+'''
end)()
local changed={}
local ok,problem=pcall(function()
    for _,entry in ipairs(entries) do
        entry.node.Source=entry.after
        table.insert(changed,entry)
        assert(normalize(entry.node.Source)==normalize(entry.after),"Source did not match: "..entry.path)
        assert(tostring(entry.node.Capabilities)==entry.capabilities and entry.node.Sandboxed==entry.sandboxed,"Permissions changed: "..entry.path)
    end
end)
if not ok then
    for _,entry in ipairs(changed) do entry.node.Source=entry.before end
    error(problem)
end
return game:GetService("HttpService"):JSONEncode({installed=#changed,ui=ui,backup=backup:GetFullName(),playStarted=false,permissionsChanged=false})
'''
(root/'Install.luau').write_text(source,encoding='utf-8')
print('Built guarded installation for',len(entries),'scripts.')
