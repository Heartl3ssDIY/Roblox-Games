import hashlib
import json
import sys
from pathlib import Path

root = Path(__file__).resolve().parent
bulldog = root.parent / 'BritishBulldog20261003'
movement = root.parent / 'BritishBulldogMovement20261003'
sys.path.insert(0, str(movement))
from PackageUpgradeSupport import asset_fragment, default_fragment, icon_assets, support_files, verify_embedded, verify_upgrade_contract

sources = {
    'BritishBulldogRules': bulldog / 'BritishBulldogRules.lua',
    'BritishBulldogService': bulldog / 'BritishBulldogService.lua',
    'BritishBulldogHUD': bulldog / 'BritishBulldogHUD.client.luau',
    'BritishBulldogCamera': bulldog / 'BritishBulldogCamera.client.luau',
    'TagService': root / 'TagService.lua',
    'PlaygroundCatalog': root / 'PlaygroundCatalog.lua',
    'PlaygroundEconomyService': root / 'PlaygroundEconomyService.lua',
    'PlaygroundCoordinator': root / 'PlaygroundCoordinator.lua',
    'PlaygroundAdminService': root / 'PlaygroundAdminService.lua',
    'PlaygroundBootstrap': root / 'PlaygroundBootstrap.server.lua',
    'PlaygroundAdminController': root / 'PlaygroundAdminPanel.client.luau',
    'TagHUDController': root / 'TagHUD.client.luau',
    'PlaygroundShellController': root / 'PlaygroundShell.client.luau',
    'PlaygroundEmotes': root / 'PlaygroundEmotes.client.luau',
    'PlaygroundLobbyAtmosphere': root / 'PlaygroundLobbyAtmosphere.client.luau',
    'BBMovement': movement / 'BBMovement.client.luau',
    'PlayerLevel': movement / 'PlayerLevel.client.luau',
}
builders = {
    'buildLobby': root / 'BuildPlaygroundLobby.luau',
    'buildLobbyDepth': root / 'AddLobbyDepth.luau',
    'buildTagArena': root / 'BuildTagArena.luau',
    'buildBritishBulldogHUD': bulldog / 'BuildBritishBulldogHUD.luau',
    'buildTagHUD': root / 'BuildTagHUD.luau',
    'buildAdmin': root / 'BuildExpandedAdminPanel.luau',
    'buildShell': root / 'BuildPlaygroundShell.luau',
    'upgradeBritishBulldogControls': movement / 'UpgradeBritishBulldogControls.luau',
    'upgradePlayerLevel': movement / 'UpgradePlayerLevel.luau',
}

def read(path):
    return path.read_text(encoding='utf-8-sig').replace('\r\n', '\n')

def literal(value):
    level = 1
    while ']'+'='*level+']' in value:
        level += 1
    return '['+'='*level+'['+value+']'+'='*level+']'

manifest = {}
parts = [
    'local RunService=game:GetService("RunService")\n',
    'assert(not RunService:IsRunning(),"Install Playground Expansion in Studio edit mode")\n',
    'local sources={\n',
]
for name, path in sources.items():
    source = read(path)
    manifest[name] = {'file': str(path), 'sha256': hashlib.sha256(source.encode()).hexdigest(),
                      'bytes': len(source.encode()), 'kind': 'source'}
    parts.append(' ["'+name+'"]='+literal(source)+',\n')
parts.append('}\n')
for name, path in builders.items():
    source = read(path)
    manifest[name] = {'file': str(path), 'sha256': hashlib.sha256(source.encode()).hexdigest(),
                      'bytes': len(source.encode()), 'kind': 'builder'}
    parts.append('local function '+name+'()\n'+source+'\nend\n')

parts.append('''local ServerScriptService=game:GetService("ServerScriptService")
local ServerStorage=game:GetService("ServerStorage")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local StarterGui=game:GetService("StarterGui")
local StarterPlayerScripts=game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local britishBulldog=assert(workspace:FindFirstChild("British Bulldog game"),"Existing British Bulldog arena is required")
assert(britishBulldog:FindFirstChild("Gameplay"),"British Bulldog Gameplay is missing; existing geometry was preserved")
for _,name in ipairs({"ArenaBounds","SafeNorth","SafeSouth","RunnersNorth","RunnersSouth","BulldogSpawns","NorthLine","SouthLine"}) do
 assert(britishBulldog.Gameplay:FindFirstChild(name),"British Bulldog Gameplay."..name.." is missing; existing geometry was preserved")
end
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
local backups=ServerStorage:FindFirstChild("PlaygroundBeforeExpansion20261003")
if not backups then
 backups=Instance.new("Folder")
 backups.Name="PlaygroundBeforeExpansion20261003"
 backups.Parent=ServerStorage
end
assert(backups:IsA("Folder"),"Expansion backup container must be a Folder")
local savedSources=backups:FindFirstChild("InstallerSourceBackups")
if not savedSources then
 savedSources=Instance.new("Folder")
 savedSources.Name="InstallerSourceBackups"
 savedSources.Parent=backups
end
assert(savedSources:IsA("Folder"),"Source backup container must be a Folder")
local guiBackups=backups:FindFirstChild("AuthoredGuiBackups")
if not guiBackups then
 guiBackups=Instance.new("Folder")
 guiBackups.Name="AuthoredGuiBackups"
 guiBackups.Parent=backups
end
assert(guiBackups:IsA("Folder"),"GUI backup container must be a Folder")
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
 if not gui or guiBackups:FindFirstChild(gui.Name) then return end
 assert(gui:IsA("ScreenGui"),gui.Name.." must be a ScreenGui")
 local copy=assert(gui:Clone(),gui.Name.." must be archivable for the first backup")
 copy:SetAttribute("OriginalPath",gui:GetFullName())
 copy.Enabled=false
 for _,object in ipairs(copy:GetDescendants()) do if object:IsA("BaseScript") then object.Disabled=true end end
 copy.Parent=guiBackups
end
local function install(className,name,source,parent,caps)
 local object=parent:FindFirstChild(name)
 if object then
  assert(object:IsA(className),name.." has an unexpected class")
  assert(object.Sandboxed,name.." must retain its sandbox")
  saveSource(object)
  object.Capabilities=caps or baseCaps
  object.Source=source
 else
  object=Instance.new(className)
  object.Name=name
  object.Capabilities=caps or baseCaps
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
for _,name in ipairs({"PlaygroundAdminRequest","PlaygroundShopRequest","PlaygroundVoteRequest","TagMovementRequest","BBMovementRequest"}) do remote(name) end
local state=ReplicatedStorage:FindFirstChild("PlaygroundState")
if not state then
 state=Instance.new("Folder")
 state.Name="PlaygroundState"
 for name,value in pairs({Phase="Waiting",VotingEndsAt=0,VotesBritishBulldog=0,VotesTagYoureIt=0,AutomaticRounds=true}) do state:SetAttribute(name,value) end
 state.Parent=ReplicatedStorage
else assert(state:IsA("Folder"),"PlaygroundState must be a Folder") end
for _,name in ipairs({"BritishBulldogState","TagState"}) do
 local object=ReplicatedStorage:FindFirstChild(name)
 if not object then
  object=Instance.new("Folder")
  object.Name=name
  object:SetAttribute("Phase","Waiting")
  object.Parent=ReplicatedStorage
 else assert(object:IsA("Folder"),name.." must be a Folder") end
end
local config=ServerStorage:FindFirstChild("PlaygroundAdminConfig")
if not config then
 config=Instance.new("Folder")
 config.Name="PlaygroundAdminConfig"
 config.Parent=ServerStorage
end
assert(config:IsA("Folder"),"PlaygroundAdminConfig must be a Folder")
if config:GetAttribute("AdminUserId")==nil then config:SetAttribute("AdminUserId",1201803949) end
if config:GetAttribute("ExtraAdminUserIds")==nil then config:SetAttribute("ExtraAdminUserIds","") end
for _,name in ipairs({"BritishBulldogHUD","TagHUD","PlaygroundAdminPanel","PlaygroundShell"}) do saveGui(StarterGui:FindFirstChild(name)) end
install("ModuleScript","PlaygroundCatalog",sources.PlaygroundCatalog,ReplicatedStorage,baseCaps)
local lobbyResult=buildLobby()
local lobby=assert(workspace:FindFirstChild("Playground Lobby"),"Lobby creation failed")
assert(lobby:FindFirstChild("Gameplay") and lobby.Gameplay:FindFirstChild("LobbySpawn"),"Lobby gameplay spawn is missing")
local depthResult=buildLobbyDepth()
local improvements=lobby:FindFirstChild("Improvements20261003")
assert(improvements and improvements:GetAttribute("Applied")==true,"Existing lobby depth pass is incomplete; it was preserved")
local tagResult=buildTagArena()
local tag=assert(workspace:FindFirstChild("Tag You're It"),"Tag arena creation failed")
assert(tag:FindFirstChild("Gameplay") and tag.Gameplay:FindFirstChild("ArenaBounds"),"Existing Tag geometry lacks required Gameplay; it was preserved")
for _,name in ipairs({"StartPads","TaggerSpawn","NavigationNodes"}) do
 assert(tag.Gameplay:FindFirstChild(name),"Tag Gameplay."..name.." is missing; existing geometry was preserved")
end
if not StarterGui:FindFirstChild("BritishBulldogHUD") then buildBritishBulldogHUD() end
buildTagHUD()
buildAdmin()
buildShell()
local cosmeticAssets=assert(ReplicatedStorage:FindFirstChild("PlaygroundCosmeticAssets"),"Cosmetic asset folder missing")
assert(cosmeticAssets:IsA("Folder"),"PlaygroundCosmeticAssets must be a Folder")
local britishBulldogHUD=assert(StarterGui:FindFirstChild("BritishBulldogHUD"),"British Bulldog HUD missing")
local tagHUD=assert(StarterGui:FindFirstChild("TagHUD"),"Tag HUD missing")
local adminHUD=assert(StarterGui:FindFirstChild("PlaygroundAdminPanel"),"Admin panel missing")
local shell=assert(StarterGui:FindFirstChild("PlaygroundShell"),"Playground shell missing")
''')
parts.append(default_fragment())
parts.append('''local movementResult=upgradeBritishBulldogControls()
local levelResult=upgradePlayerLevel()
assert(shell:FindFirstChild("LevelPanel") and shell:FindFirstChild("CompactLevelPanel"),"Existing level layout is incomplete and was preserved")
''')
assets, raw_assets, asset_info = icon_assets(movement)
if asset_info:
    manifest['IconAssetIds'] = asset_info
parts.append(asset_fragment(assets, raw_assets))
parts.append('''
install("ModuleScript","BritishBulldogRules",sources.BritishBulldogRules,ServerScriptService,baseCaps)
install("ModuleScript","BritishBulldogService",sources.BritishBulldogService,ServerScriptService,rpcCaps)
install("ModuleScript","TagService",sources.TagService,ServerScriptService,rpcCaps)
install("ModuleScript","PlaygroundEconomyService",sources.PlaygroundEconomyService,ServerScriptService,rpcCaps)
install("ModuleScript","PlaygroundCoordinator",sources.PlaygroundCoordinator,ServerScriptService,rpcCaps)
install("ModuleScript","PlaygroundAdminService",sources.PlaygroundAdminService,ServerScriptService,rpcCaps)
local clientScripts={
 install("LocalScript","Controller",sources.BritishBulldogHUD,britishBulldogHUD,baseCaps),
 install("LocalScript","BritishBulldogCamera",sources.BritishBulldogCamera,StarterPlayerScripts,baseCaps),
 install("LocalScript","Controller",sources.TagHUDController,tagHUD,inputRpcCaps),
 install("LocalScript","Controller",sources.PlaygroundAdminController,adminHUD,inputRpcCaps),
 install("LocalScript","Controller",sources.PlaygroundShellController,shell,rpcCaps),
 install("LocalScript","PlaygroundEmotes",sources.PlaygroundEmotes,StarterPlayerScripts,baseCaps),
 install("LocalScript","PlaygroundLobbyAtmosphere",sources.PlaygroundLobbyAtmosphere,StarterPlayerScripts,baseCaps),
 install("LocalScript","MovementController",sources.BBMovement,britishBulldogHUD,inputRpcCaps),
 install("LocalScript","PlayerLevelController",sources.PlayerLevel,shell,previewCaps),
}
for _,object in ipairs(clientScripts) do object.Disabled=false end
local oldBootstrap=ServerScriptService:FindFirstChild("BritishBulldogBootstrap")
if oldBootstrap and oldBootstrap:IsA("Script") then
 if backups:GetAttribute("LegacyBootstrapDisabled")==nil then backups:SetAttribute("LegacyBootstrapDisabled",oldBootstrap.Disabled) end
 saveSource(oldBootstrap)
 oldBootstrap.Disabled=true
end
local oldSpawn=workspace:FindFirstChild("SpawnLocation")
if oldSpawn and oldSpawn:IsA("SpawnLocation") then
 if backups:GetAttribute("LegacySpawnEnabled")==nil then backups:SetAttribute("LegacySpawnEnabled",oldSpawn.Enabled) end
 oldSpawn.Enabled=false
end
lobby.Gameplay.LobbySpawn.Enabled=true
if backups:GetAttribute("BritishBulldogAutoStart")==nil then backups:SetAttribute("BritishBulldogAutoStart",britishBulldog:GetAttribute("AutoStart")) end
britishBulldog:SetAttribute("AutoStart",false)
local bootstrap=install("Script","PlaygroundBootstrap",sources.PlaygroundBootstrap,ServerScriptService,rpcCaps)
bootstrap:SetAttribute("Ready",false)
bootstrap.Disabled=false
backups:SetAttribute("ExpansionInstalled",true)
backups:SetAttribute("ExpansionVersion",1)
backups:SetAttribute("MovementRewardsInstalled",true)
return {installed=true,scripts=#installed,lobby=lobbyResult,depth=depthResult,tag=tagResult,movement=movementResult,levels=levelResult,authoredLayoutsPreserved=true,britishBulldogGeometryPreserved=true,dataStoreCapabilityGranted=false,bootstrap=bootstrap:GetFullName()}
''')
output = ''.join(parts)
manifest['package'] = {'sha256': hashlib.sha256(output.encode()).hexdigest(),
                       'bytes': len(output.encode()), 'sources': len(sources),
                       'builders': len(builders), 'runtime_layout_writes': False,
                       'new_remote_capabilities': ['RemoteEvent'],
                       'input_scripts': ['TagHUD.Controller', 'PlaygroundAdminPanel.Controller', 'BritishBulldogHUD.MovementController'],
                       'animation_scripts': ['PlaygroundShell.PlayerLevelController'],
                       'icon_assets': assets, 'support_files': support_files(movement)}
verified = verify_embedded(output, manifest)
verify_upgrade_contract(output)
(root / 'InstallPlaygroundExpansion.luau').write_text(output, encoding='utf-8', newline='\n')
(root / 'expansion-package-manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
print(json.dumps({**manifest['package'], 'embedded_files_verified': verified}))
