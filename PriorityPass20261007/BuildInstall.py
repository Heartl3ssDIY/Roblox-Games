from pathlib import Path
import json

root=Path(__file__).resolve().parent
paths={
 'BritishBulldogService.luau':'game.ServerScriptService.BritishBulldogService',
 'BritishBulldogRules.luau':'game.ServerScriptService.BritishBulldogRules',
 'BritishBulldogHUD.MovementController.luau':'game.StarterGui.BritishBulldogHUD.MovementController',
 'StuckInTheMudService.luau':'game.ServerScriptService.StuckInTheMudService',
 'MudHUD.Controller.luau':'game.StarterGui.MudHUD.Controller',
 'PlaygroundCoordinator.luau':'game.ServerScriptService.PlaygroundCoordinator',
 'TagSprintService.luau':'game.ServerScriptService.TagSprintService',
 'TagHUD.SprintController.luau':'game.StarterGui.TagHUD.SprintController',
 'TagService.luau':'game.ServerScriptService.TagService',
 'TagHUD.Controller.luau':'game.StarterGui.TagHUD.Controller',
 'PlaygroundPodium.Controller.luau':'game.StarterGui.PlaygroundPodium.Controller',
 'PlaygroundCatalog.luau':'game.ReplicatedStorage.PlaygroundCatalog',
 'PlaygroundEquipmentService.luau':'game.ServerScriptService.PlaygroundEquipmentService',
 'PlaygroundPets.luau':'game.StarterPlayer.StarterPlayerScripts.PlaygroundPets',
 'PlaygroundToyService.luau':'game.ServerScriptService.PlaygroundToyService',
}
def literal(s):
    eq='='
    while ']'+eq+']' in s: eq+='='
    return '['+eq+'['+s+']'+eq+']'
rows=[]
for name,path in paths.items():
    before=(root/'Before'/name).read_text(encoding='utf-8')
    after=(root/'After'/name).read_text(encoding='utf-8')
    rows.append('{name='+json.dumps(name)+',target='+path+',before='+literal(before)+',after='+literal(after)+'}')
common='assert(not game.RunService:IsRunning(), "Edit mode required")\nlocal changes={\n'+',\n'.join(rows)+'\n}\n'
preflight=common+'''local result={}
for _,c in ipairs(changes) do
 local actual=c.target.Source
 table.insert(result,{name=c.name,actualBytes=#actual,beforeBytes=#c.before,exact=actual==c.before,trailingOnly=actual:gsub("\\n+$", "")==c.before:gsub("\\n+$", ""),capabilities=tostring(c.target.Capabilities)})
end
return game.HttpService:JSONEncode(result)
'''
(root/'PreflightSources.luau').write_text(preflight,encoding='utf-8',newline='\n')
install=common+'''for _,c in ipairs(changes) do assert(c.target.Source==c.before, "Source changed: "..c.name) end
local bb=workspace["British Bulldog game"]
local mud=workspace["Stuck in the Mud"]
local lobby=workspace["Playground Lobby"]
assert(bb:GetAttribute("DepartureSeconds")==5 and bb:GetAttribute("IntermissionSeconds")==12,"Bulldog settings changed")
assert(mud:GetAttribute("MinimumPlayers")==4 and mud:GetAttribute("TeamCount")==2 and mud:GetAttribute("MaxPlayers")==4 and mud:GetAttribute("MaxTeamSize")==2,"Mud settings changed")
assert(lobby:GetAttribute("IntermissionSeconds")==nil,"Lobby intermission changed")
local SS=game.ServerStorage
assert(not SS:FindFirstChild("PriorityPassBackup20261007"),"Already installed; inspect before repeating")
local backup=Instance.new("Folder") backup.Name="PriorityPassBackup20261007"
for _,c in ipairs(changes) do local old=c.target:Clone() old.Name=c.name old:SetAttribute("OriginalPath",c.target:GetFullName()) old.Parent=backup end
local settings=Instance.new("StringValue") settings.Name="PreviousConfiguration"
settings.Value=game.HttpService:JSONEncode({departure=5,bulldogIntermission=12,mudMinimum=4,mudMaxPlayers=4,mudMaxTeamSize=2,mudTeams=2,mouseLock=game.StarterPlayer.EnableMouseLockOption}) settings.Parent=backup
backup.Parent=SS
local report={}
for _,c in ipairs(changes) do c.target.Source=c.after assert(c.target.Source==c.after,"Source write mismatch: "..c.name) table.insert(report,c.name) end
bb:SetAttribute("DepartureSeconds",10) bb:SetAttribute("IntermissionSeconds",35)
lobby:SetAttribute("IntermissionSeconds",35)
mud:SetAttribute("MinimumPlayers",2) mud:SetAttribute("TeamCount",2) mud:SetAttribute("MaxPlayers",nil) mud:SetAttribute("MaxTeamSize",nil)
game.StarterPlayer.EnableMouseLockOption=true
game.StarterGui.PlaygroundPodium:SetAttribute("AvatarHeight",27.5)
for _,button in ipairs({game.StarterGui.BritishBulldogHUD.MovementControls.Dodge,game.StarterGui.TagHUD.Controls.Dodge}) do
 button:SetAttribute("PriorityPreviousVisible",button.Visible) button:SetAttribute("PriorityPreviousActive",button.Active) button:SetAttribute("PriorityPreviousInteractable",button.Interactable)
 button.Visible=false button.Active=false button.Interactable=false
end
game.ChangeHistoryService:SetWaypoint("Playground priorities October 7")
return game.HttpService:JSONEncode({installed=report,backup=backup:GetFullName(),play=game.RunService:IsRunning()})
'''
(root/'InstallSources.luau').write_text(install,encoding='utf-8',newline='\n')
print('Built guarded installation for',len(paths),'scripts')
