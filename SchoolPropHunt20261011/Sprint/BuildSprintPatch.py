from pathlib import Path
p = Path(__file__).resolve().parent
names = ['BritishBulldogService','StuckInTheMudService','TagService','TagSprintService']
defs = []
for name in names:
    old=(p/'Before'/f'{name}.luau').read_text(encoding='utf-8')
    new=(p/'After'/f'{name}.luau').read_text(encoding='utf-8')
    defs.append('{name="'+name+'",before=[======['+old+']======],after=[======['+new+']======]}')
code='''assert(not game:GetService("RunService"):IsRunning(), "Stop Play before installing sprint changes")
local patches={__PATCHES__}
local sources={}
for _, patch in ipairs(patches) do
    local source=assert(game.ServerScriptService:FindFirstChild(patch.name), patch.name .. " missing")
    local text=source.Source:gsub("\\r\\n", "\\n")
    local old=patch.before:gsub("%s+$", "")
    local new=patch.after:gsub("%s+$", "")
    local start,finish=text:find(old,1,true)
    assert(start and not text:find(old,finish+1,true), patch.name .. " changed since audit or already patched")
    sources[patch.name]={instance=source,source=text:sub(1,start-1)..new..text:sub(finish+1)}
end
local storage=game.ServerStorage
assert(not storage:FindFirstChild("SprintPartialRechargeBackup20261011"), "Sprint backup already exists")
local backup=Instance.new("Folder") backup.Name="SprintPartialRechargeBackup20261011" backup.Parent=storage
local changed={}
for _, patch in ipairs(patches) do
    local update=sources[patch.name]
    local old=update.instance:Clone() old.Parent=backup
    local capabilities,sandboxed=update.instance.Capabilities,update.instance.Sandboxed
    update.instance.Source=update.source
    assert(update.instance.Capabilities==capabilities and update.instance.Sandboxed==sandboxed,"Permissions changed")
    table.insert(changed,patch.name)
end
return {changed=changed,backup=backup:GetFullName(),partialRechargeAllowed=true,durationsPreserved=true,permissionsPreserved=true}
'''
(p/'InstallSprint.luau').write_text(code.replace('__PATCHES__',',\n'.join(defs)),encoding='utf-8')
