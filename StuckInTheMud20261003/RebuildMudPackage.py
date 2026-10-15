import json
import sys
from pathlib import Path

from MudPackageSupport import (CLIENTS, MODULES, MUD_TEAM_PROFILES, all_games_text, approval_preflight, digest, file_entry, literal,
                               read, setting_fragment, text_entry, verify_all_games,
                               verify_embedded, verify_expansion_stage, verify_upgrade_contract)


root = Path(__file__).resolve().parent
expansion = root.parent / 'PlaygroundExpansion20261003'
sources = {name: root / (name + '.lua') for name in MODULES}
sources.update({name: root / (name + '.client.luau') for name in CLIENTS})
sources['PlaygroundBootstrap'] = root / 'PlaygroundBootstrap.server.lua'
builders = {
    'buildMudArena': root / 'BuildMudArena.luau',
    'repairMudArena': root / 'RepairMudArena.luau',
    'buildMudGunTemplates': root / 'BuildMudGunTemplates.luau',
    'buildMudHUD': root / 'BuildMudHUD.luau',
    'buildTagSprintUI': root / 'BuildTagSprintUI.luau',
    'upgradeThirdGameLobby': root / 'UpgradeThirdGameLobby.luau',
}
if (root / 'BuildSchoolScenery.luau').exists():
    builders['buildSchoolScenery'] = root / 'BuildSchoolScenery.luau'


def rebuild():
    include_preview_assets = '--include-preview-assets' in sys.argv
    manifest = {'files': {}}
    parts = ['local RunService=game:GetService("RunService")\n',
             'assert(not RunService:IsRunning(),"Install Stuck in the Mud in Studio edit mode")\n',
             approval_preflight(),
             'local sources={\n']
    for name, path in sources.items():
        source = read(path)
        manifest['files'][name] = text_entry(path, source, 'source')
        parts.append(' ["' + name + '"]=' + literal(source) + ',\n')
    parts.append('}\n')
    for name, path in builders.items():
        source = read(path)
        manifest['files'][name] = text_entry(path, source, 'builder')
        parts.append('local function ' + name + '()\n' + source + '\nend\n')
    parts.append('''local ServerScriptService=game:GetService("ServerScriptService")
local ServerStorage=game:GetService("ServerStorage")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local StarterGui=game:GetService("StarterGui")
local britishBulldog=assert(workspace:FindFirstChild("British Bulldog game"),"Install British Bulldog before this upgrade")
local lobby=assert(workspace:FindFirstChild("Playground Lobby"),"Install Playground Expansion before this upgrade")
local tag=assert(workspace:FindFirstChild("Tag You're It"),"Install Playground Expansion before this upgrade")
assert(britishBulldog:FindFirstChild("Gameplay") and lobby:FindFirstChild("Gameplay") and tag:FindFirstChild("Gameplay"),"Required existing game geometry is incomplete")
assert(lobby.Gameplay:FindFirstChild("LobbySpawn") and lobby.Gameplay:FindFirstChild("VoteZone") and lobby.Gameplay:FindFirstChild("VoteChoices"),"Lobby gameplay markers are incomplete")
assert(lobby:FindFirstChild("VotingAlcove"),"Lobby voting alcove is missing")
for _,name in ipairs({"BritishBulldogService","TagService","PlaygroundEconomyService","PlaygroundCoordinator","PlaygroundAdminService"}) do
 local object=ServerScriptService:FindFirstChild(name)
 assert(object and object:IsA("ModuleScript") and object.Sandboxed,"Install the sandboxed Playground Expansion first: "..name)
end
for _,name in ipairs({"BritishBulldogState","TagState","PlaygroundState"}) do
 local object=ReplicatedStorage:FindFirstChild(name)
 assert(object and object:IsA("Folder"),"Install Playground Expansion first: "..name)
end
for _,name in ipairs({"PlaygroundAdminRequest","PlaygroundShopRequest","PlaygroundVoteRequest","TagMovementRequest","BBMovementRequest"}) do
 local object=ReplicatedStorage:FindFirstChild(name)
 assert(object and object:IsA("RemoteFunction") and object.Sandboxed,"Install Playground Expansion and movement first: "..name)
end
local tagHUD=assert(StarterGui:FindFirstChild("TagHUD"),"Editable Tag HUD is missing")
local adminHUD=assert(StarterGui:FindFirstChild("PlaygroundAdminPanel"),"Editable admin panel is missing")
local shell=assert(StarterGui:FindFirstChild("PlaygroundShell"),"Editable Playground shell is missing")
for _,gui in ipairs({tagHUD,adminHUD,shell}) do assert(gui:IsA("ScreenGui"),gui.Name.." must be a ScreenGui") end
assert(shell:FindFirstChild("LevelPanel") and shell:FindFirstChild("CompactLevelPanel"),"Install movement and rewards before this upgrade")
assert(shell:FindFirstChild("VotePanel") and shell.VotePanel:FindFirstChild("TagYoureIt") and shell.VotePanel:FindFirstChild("VotesTagYoureIt"),"Authored vote UI is incomplete")
assert(adminHUD:FindFirstChild("Panel") and adminHUD.Panel:FindFirstChild("Body") and adminHUD.Panel.Body:FindFirstChild("Content") and adminHUD.Panel.Body.Content:FindFirstChild("TagYoureIt"),"Authored admin UI is incomplete")
local bootstrap=assert(ServerScriptService:FindFirstChild("PlaygroundBootstrap"),"Install Playground Expansion before this upgrade")
assert(bootstrap:IsA("Script") and bootstrap.Sandboxed,"PlaygroundBootstrap must retain its sandbox")
local baseCaps=SecurityCapabilities.new(
 Enum.SecurityCapability.RunServerScript,Enum.SecurityCapability.RunClientScript,
 Enum.SecurityCapability.AccessOutsideWrite,Enum.SecurityCapability.CreateInstances,
 Enum.SecurityCapability.Basic,Enum.SecurityCapability.Physics,Enum.SecurityCapability.UI,
 Enum.SecurityCapability.Players,Enum.SecurityCapability.AvatarBehavior,Enum.SecurityCapability.AvatarAppearance,
 Enum.SecurityCapability.Environment,Enum.SecurityCapability.LegacySound,Enum.SecurityCapability.Audio)
local remoteCaps=SecurityCapabilities.new(Enum.SecurityCapability.RemoteEvent)
local rpcCaps=baseCaps:Add(remoteCaps)
local inputRpcCaps=rpcCaps:Add(SecurityCapabilities.new(Enum.SecurityCapability.Input))
local previewCaps=baseCaps:Add(SecurityCapabilities.new(Enum.SecurityCapability.Animation))
local approvedMudCaps=approvedMudService.Capabilities
assert(inputRpcCaps:Contains(approvedMudCaps) and approvedMudCaps:Contains(inputRpcCaps),"Approved mud capabilities must match the reviewed base plus RemoteEvent and Input")
local backups=ServerStorage:FindFirstChild("PlaygroundBeforeMud20261003")
if not backups then
 backups=Instance.new("Folder")
 backups.Name="PlaygroundBeforeMud20261003"
 backups.Parent=ServerStorage
end
assert(backups:IsA("Folder"),"Mud backup container must be a Folder")
local function backupFolder(name)
 local object=backups:FindFirstChild(name)
 if not object then object=Instance.new("Folder") object.Name=name object.Parent=backups end
 assert(object:IsA("Folder"),name.." must be a Folder")
 return object
end
local savedSources=backupFolder("InstallerSourceBackups")
local guiBackups=backupFolder("AuthoredGuiBackups")
local configBackups=backupFolder("SettingsBeforeMud")
local installed={}
local function saveSource(object)
 local key=object:GetFullName():gsub("[^%w_]","_")
 if savedSources:FindFirstChild(key) then return end
 local value=Instance.new("StringValue")
 value.Name=key
 value.Value=object.Source
 value:SetAttribute("OriginalPath",object:GetFullName())
 value:SetAttribute("OriginalClass",object.ClassName)
 value:SetAttribute("Sandboxed",object.Sandboxed)
 value:SetAttribute("Capabilities",tostring(object.Capabilities))
 if object:IsA("BaseScript") then value:SetAttribute("Disabled",object.Disabled) end
 value.Parent=savedSources
end
local function saveGui(gui)
 if guiBackups:FindFirstChild(gui.Name) then return end
 local copy=assert(gui:Clone(),gui.Name.." must be archivable for the first backup")
 copy:SetAttribute("OriginalPath",gui:GetFullName())
 copy.Enabled=false
 for _,object in ipairs(copy:GetDescendants()) do if object:IsA("BaseScript") then object.Disabled=true end end
 copy.Parent=guiBackups
end
local function saveSettings(object)
 if configBackups:FindFirstChild(object.Name) then return end
 local copy=Instance.new("Folder")
 copy.Name=object.Name
 for name,value in pairs(object:GetAttributes()) do copy:SetAttribute(name,value) end
 copy:SetAttribute("OriginalPath",object:GetFullName())
 copy.Parent=configBackups
end
local function install(className,name,source,parent,caps)
 local object=parent:FindFirstChild(name)
 if name=="StuckInTheMudService" then
  assert(object==approvedMudService,"The approved mud service changed during installation")
  assert(object.Capabilities:Contains(approvedMudCaps) and approvedMudCaps:Contains(object.Capabilities),"Approved mud capabilities changed during installation")
 end
 if object then
  assert(object:IsA(className),name.." has an unexpected class")
  assert(object.Sandboxed,name.." must retain its sandbox")
  saveSource(object)
  if object~=approvedMudService then object.Capabilities=caps end
  object.Source=source
 else
  object=Instance.new(className)
  object.Name=name
  object.Capabilities=caps
  object.Sandboxed=true
  if object:IsA("BaseScript") then object.Disabled=true end
  object.Source=source
  object.Parent=parent
 end
 table.insert(installed,object:GetFullName())
 return object
end
local function remote(name)
 local object=ReplicatedStorage:FindFirstChild(name)
 if object then
  assert(object:IsA("RemoteFunction"),name.." must be a RemoteFunction")
  assert(object.Sandboxed,name.." must retain its sandbox")
  assert(remoteCaps:Contains(object.Capabilities) and object.Capabilities:Contains(remoteCaps),name.." must have only RemoteEvent capability")
 else
  object=Instance.new("RemoteFunction")
  object.Name=name
  object.Capabilities=remoteCaps
  object.Sandboxed=true
  object.Parent=ReplicatedStorage
 end
 return object
end
local function state(name)
 local object=ReplicatedStorage:FindFirstChild(name)
 if not object then object=Instance.new("Folder") object.Name=name object:SetAttribute("Phase","Waiting") object.Parent=ReplicatedStorage end
 assert(object:IsA("Folder"),name.." must be a Folder")
 return object
end
for _,gui in ipairs({tagHUD,adminHUD,shell}) do saveGui(gui) end
local previousMudHUD=StarterGui:FindFirstChild("MudHUD")
if previousMudHUD then assert(previousMudHUD:IsA("ScreenGui"),"MudHUD must be a ScreenGui") saveGui(previousMudHUD) end
saveSource(bootstrap)
saveSettings(lobby)
saveSettings(tag)
bootstrap.Disabled=true
remote("MudActionRequest")
remote("TagSprintRequest")
state("MudState")
local arenaResult=buildMudArena()
local mud=assert(workspace:FindFirstChild("Stuck in the Mud"),"Mud arena creation failed")
assert(mud:FindFirstChild("Gameplay") and mud:FindFirstChild("Geometry"),"Existing Mud arena geometry is incomplete and was preserved")
for _,name in ipairs({"ArenaBounds","StartPads","TeamSpawns","NavigationNodes","CoverVolumes","RescueAreas","PracticeSpawns"}) do
 assert(mud.Gameplay:FindFirstChild(name),"Mud Gameplay."..name.." is missing; existing geometry was preserved")
end
saveSettings(mud)
local repairResult=repairMudArena()
''')
    parts.append('local sceneryResult=buildSchoolScenery()\n' if 'buildSchoolScenery' in builders else 'local sceneryResult={included=false}\n')
    parts.append('''local toolsResult=buildMudGunTemplates()
local hudResult=buildMudHUD()
local sprintResult=buildTagSprintUI()
local voteResult=upgradeThirdGameLobby()
local mudHUD=assert(StarterGui:FindFirstChild("MudHUD"),"Editable Mud HUD is missing")
assert(mudHUD:IsA("ScreenGui") and mudHUD:FindFirstChild("Main"),"Existing Mud HUD is incomplete and was preserved")
assert(tagHUD:FindFirstChild("SprintPanel"),"Editable Tag sprint controls are missing")
assert(shell.VotePanel:FindFirstChild("StuckInTheMud") and adminHUD.Panel.Body.Content:FindFirstChild("StuckInTheMud"),"Editable third-game controls are missing")
assert(shell:FindFirstChild("CompactVotePanel"),"Editable compact voting panel is missing")
assert(adminHUD:FindFirstChild("CompactPanel") and adminHUD:FindFirstChild("CompactToggle"),"Editable compact admin controls are missing")
local assets=assert(ReplicatedStorage:FindFirstChild("MudAssets"),"Mud assets are missing")
for _,name in ipairs({"MudGun","HeatGun"}) do
 local tool=assets:FindFirstChild(name)
 assert(tool and tool:IsA("Tool") and tool:FindFirstChild("Handle") and tool.Handle:FindFirstChild("MuzzleAttachment"),name.." requires its native Handle and MuzzleAttachment")
end
''')
    parts.append(setting_fragment())
    for name in MODULES:
        caps = 'approvedMudCaps' if name == 'StuckInTheMudService' else 'rpcCaps'
        parts.append(f'install("ModuleScript","{name}",sources.{name},ServerScriptService,{caps})\n')
    parts.append('local clients={\n')
    for source, (name, parent, caps) in CLIENTS.items():
        parts.append(f' install("LocalScript","{name}",sources.{source},{parent},{caps}),\n')
    parts.append('''}
for _,object in ipairs(clients) do object.Disabled=false end
local oldBootstrap=ServerScriptService:FindFirstChild("BritishBulldogBootstrap")
if oldBootstrap and oldBootstrap:IsA("Script") then
 saveSource(oldBootstrap)
 oldBootstrap.Disabled=true
end
britishBulldog:SetAttribute("AutoStart",false)
lobby.Gameplay.LobbySpawn.Enabled=true
bootstrap=install("Script","PlaygroundBootstrap",sources.PlaygroundBootstrap,ServerScriptService,rpcCaps)
bootstrap:SetAttribute("Ready",false)
bootstrap.Disabled=false
backups:SetAttribute("MudInstalled",true)
backups:SetAttribute("MudVersion",1)
return {installed=true,scripts=#installed,arena=arenaResult,repair=repairResult,scenery=sceneryResult,tools=toolsResult,hud=hudResult,sprint=sprintResult,voting=voteResult,authoredLayoutsPreserved=true,dataStoreCapabilityGranted=false,bootstrap=bootstrap:GetFullName()}
''')
    package = ''.join(parts)
    excluded = set(sources.values()) | set(builders.values())
    generated = {'InstallStuckInTheMud.luau', 'InstallPlaygroundAllGames.luau', 'mud-package-manifest.json', 'package-validation.json'}
    volatile = {'NativeMudGeometry.json', 'MudArenaPreview.blend', 'MudArenaPreview.png'}
    supports = {path.name: file_entry(path) for path in sorted(root.iterdir())
                if path.is_file() and path not in excluded and path.name not in generated and path.name not in volatile
                and ('verification' not in path.name.lower() or path.name == 'VerificationReport.json') and 'arenapreview' not in path.name.lower()
                and (include_preview_assets or not path.name.lower().startswith('nativemud'))}
    if include_preview_assets:
        supports.update({path.name: file_entry(path) for path in sorted(root.iterdir())
                         if path.is_file() and (path.name in volatile or 'arenapreview' in path.name.lower())})
    for name, info in supports.items():
        if name == 'VerificationReport.json':
            info['kind'] = 'native_qa_report'
        elif name.lower().startswith('nativemud') or 'arenapreview' in name.lower():
            info['kind'] = 'isolated_blender_preview'
    manifest['package'] = {
        'file': str(root / 'InstallStuckInTheMud.luau'), 'sha256': digest(package.encode()),
        'bytes': len(package.encode()), 'sources': len(sources), 'builders': len(builders),
        'prior_expansion_and_movement_required': True, 'runtime_layout_writes': False,
        'installation_pending_explicit_input_approval': True,
        'server_input_grant_performed_by_installer': False,
        'available_mud_team_profiles': MUD_TEAM_PROFILES,
        'default_mud_team_profile': 'two_v_two',
        'new_remote_class': 'RemoteFunction', 'new_remote_capabilities': ['RemoteEvent'],
        'input_scripts': ['ServerScriptService.StuckInTheMudService', 'MudHUD.Controller', 'TagHUD.SprintController', 'TagHUD.Controller', 'PlaygroundAdminPanel.Controller'],
        'animation_scripts': ['PlaygroundShell.PlayerLevelController'],
        'support_files': supports,
        'preview_metadata_pending': not include_preview_assets,
        'preview_kind': 'isolated_blender_reconstruction_of_native_geometry',
        'preview_is_native_game_screenshot': False,
    }
    verified = verify_embedded(package, manifest)
    contracts = verify_upgrade_contract(package)
    prior_path = expansion / 'InstallPlaygroundExpansion.luau'
    prior = read(prior_path)
    prior_manifest_path = expansion / 'expansion-package-manifest.json'
    verify_expansion_stage(prior, prior_manifest_path)
    full = all_games_text(prior, package)
    manifest['all_games_package'] = {
        'file': str(root / 'InstallPlaygroundAllGames.luau'), 'sha256': digest(full.encode()),
        'bytes': len(full.encode()), 'stages': ['PlaygroundExpansion', 'StuckInTheMud'],
        'expansion_stage': text_entry(prior_path, prior, 'installer_stage'),
        'expansion_manifest': file_entry(prior_manifest_path, 'stage_manifest'),
        'mud_stage': text_entry(root / 'InstallStuckInTheMud.luau', package, 'installer_stage'),
        'existing_british_bulldog_geometry_required': True,
        'installation_pending_explicit_input_approval': True,
    }
    expansion_files_verified = verify_all_games(full, manifest, package)
    (root / 'InstallStuckInTheMud.luau').write_text(package, encoding='utf-8', newline='\n')
    (root / 'InstallPlaygroundAllGames.luau').write_text(full, encoding='utf-8', newline='\n')
    (root / 'mud-package-manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    print(json.dumps({'compact': {k: v for k, v in manifest['package'].items() if k != 'support_files'},
                      'all_games': manifest['all_games_package'], 'embedded_files_verified': verified,
                      'upgrade_contract_verified': contracts,
                      'expansion_stage_files_verified': expansion_files_verified,
                      'combined_stage_order_verified': True}))


if __name__ == '__main__':
    rebuild()
