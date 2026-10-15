import hashlib
import json
from pathlib import Path

from PackageUpgradeSupport import asset_fragment, default_fragment, entry, icon_assets, literal, read, support_files, verify_embedded, verify_upgrade_contract


root = Path(__file__).resolve().parent
expansion = root.parent / 'PlaygroundExpansion20261003'
bulldog = root.parent / 'BritishBulldog20261003'
sources = {
    'BritishBulldogService': bulldog / 'BritishBulldogService.lua',
    'BritishBulldogHUD': bulldog / 'BritishBulldogHUD.client.luau',
    'TagService': expansion / 'TagService.lua',
    'PlaygroundEconomyService': expansion / 'PlaygroundEconomyService.lua',
    'PlaygroundCoordinator': expansion / 'PlaygroundCoordinator.lua',
    'BBMovement': root / 'BBMovement.client.luau',
    'PlayerLevel': root / 'PlayerLevel.client.luau',
}
builders = {
    'upgradeBritishBulldogControls': root / 'UpgradeBritishBulldogControls.luau',
    'upgradePlayerLevel': root / 'UpgradePlayerLevel.luau',
}


def rebuild():
    manifest = {}
    parts = [
        'local RunService=game:GetService("RunService")\n',
        'assert(not RunService:IsRunning(),"Install movement and rewards in Studio edit mode")\n',
        'local sources={\n',
    ]
    for name, path in sources.items():
        source = read(path)
        manifest[name] = entry(path, source, 'source')
        parts.append(' ["' + name + '"]=' + literal(source) + ',\n')
    parts.append('}\n')
    for name, path in builders.items():
        source = read(path)
        manifest[name] = entry(path, source, 'builder')
        parts.append('local function ' + name + '()\n' + source + '\nend\n')
    parts.append('''local ServerScriptService=game:GetService("ServerScriptService")
local ServerStorage=game:GetService("ServerStorage")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local StarterGui=game:GetService("StarterGui")
local britishBulldog=assert(workspace:FindFirstChild("British Bulldog game"),"Install British Bulldog before this upgrade")
local lobby=assert(workspace:FindFirstChild("Playground Lobby"),"Install Playground Expansion before this upgrade")
local tag=assert(workspace:FindFirstChild("Tag You're It"),"Install Playground Expansion before this upgrade")
assert(britishBulldog:FindFirstChild("Gameplay") and lobby:FindFirstChild("Gameplay") and tag:FindFirstChild("Gameplay"),"Required game geometry is incomplete")
assert(lobby.Gameplay:FindFirstChild("LobbySpawn"),"Lobby spawn is missing")
for _,name in ipairs({"BritishBulldogRules","BritishBulldogService","TagService","PlaygroundEconomyService","PlaygroundCoordinator","PlaygroundAdminService"}) do
 local object=ServerScriptService:FindFirstChild(name)
 assert(object and object:IsA("ModuleScript") and object.Sandboxed,"Install the sandboxed Playground Expansion first: "..name)
end
for _,name in ipairs({"BritishBulldogState","TagState","PlaygroundState"}) do
 local object=ReplicatedStorage:FindFirstChild(name)
 assert(object and object:IsA("Folder"),"Install Playground Expansion first: "..name)
end
for _,name in ipairs({"PlaygroundAdminRequest","PlaygroundShopRequest","PlaygroundVoteRequest","TagMovementRequest"}) do
 local object=ReplicatedStorage:FindFirstChild(name)
 assert(object and object:IsA("RemoteFunction") and object.Sandboxed,"Install Playground Expansion first: "..name)
end
local britishBulldogHUD=assert(StarterGui:FindFirstChild("BritishBulldogHUD"),"Editable British Bulldog HUD is missing")
local shell=assert(StarterGui:FindFirstChild("PlaygroundShell"),"Editable Playground shell is missing")
assert(britishBulldogHUD:IsA("ScreenGui") and shell:IsA("ScreenGui"),"Editable HUDs must be ScreenGui objects")
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
local backups=ServerStorage:FindFirstChild("PlaygroundBeforeMovementRewards20261003")
if not backups then
 backups=Instance.new("Folder")
 backups.Name="PlaygroundBeforeMovementRewards20261003"
 backups.Parent=ServerStorage
end
assert(backups:IsA("Folder"),"Movement backup container must be a Folder")
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
 if guiBackups:FindFirstChild(gui.Name) then return end
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
saveGui(britishBulldogHUD)
saveGui(shell)
saveSource(bootstrap)
remote("BBMovementRequest")
''')
    parts.append(default_fragment())
    parts.append('''local movementResult=upgradeBritishBulldogControls()
local levelResult=upgradePlayerLevel()
assert(shell:FindFirstChild("LevelPanel") and shell:FindFirstChild("CompactLevelPanel"),"Existing level layout is incomplete and was preserved")
''')
    assets, raw, info = icon_assets(root)
    if info:
        manifest['IconAssetIds'] = info
    parts.append(asset_fragment(assets, raw))
    parts.append('''install("ModuleScript","BritishBulldogService",sources.BritishBulldogService,ServerScriptService,rpcCaps)
install("ModuleScript","TagService",sources.TagService,ServerScriptService,rpcCaps)
install("ModuleScript","PlaygroundEconomyService",sources.PlaygroundEconomyService,ServerScriptService,rpcCaps)
install("ModuleScript","PlaygroundCoordinator",sources.PlaygroundCoordinator,ServerScriptService,rpcCaps)
local clients={
 install("LocalScript","Controller",sources.BritishBulldogHUD,britishBulldogHUD,baseCaps),
 install("LocalScript","MovementController",sources.BBMovement,britishBulldogHUD,inputRpcCaps),
 install("LocalScript","PlayerLevelController",sources.PlayerLevel,shell,previewCaps),
}
for _,object in ipairs(clients) do object.Disabled=false end
local oldBootstrap=ServerScriptService:FindFirstChild("BritishBulldogBootstrap")
if oldBootstrap and oldBootstrap:IsA("Script") then
 saveSource(oldBootstrap)
 oldBootstrap.Disabled=true
end
if backups:GetAttribute("BritishBulldogAutoStart")==nil then backups:SetAttribute("BritishBulldogAutoStart",britishBulldog:GetAttribute("AutoStart")) end
britishBulldog:SetAttribute("AutoStart",false)
bootstrap:SetAttribute("Ready",false)
bootstrap.Disabled=false
backups:SetAttribute("MovementRewardsInstalled",true)
backups:SetAttribute("MovementRewardsVersion",1)
return {installed=true,scripts=#installed,movement=movementResult,levels=levelResult,authoredLayoutsPreserved=true,geometryPreserved=true,dataStoreCapabilityGranted=false,bootstrap=bootstrap:GetFullName()}
''')
    package = ''.join(parts)
    manifest['package'] = {
        'sha256': hashlib.sha256(package.encode()).hexdigest(),
        'bytes': len(package.encode()),
        'sources': len(sources),
        'builders': len(builders),
        'runtime_layout_writes': False,
        'new_remote_capabilities': ['RemoteEvent'],
        'input_scripts': ['BritishBulldogHUD.MovementController'],
        'animation_scripts': ['PlaygroundShell.PlayerLevelController'],
        'prior_expansion_required': True,
        'icon_assets': assets,
        'support_files': support_files(root),
    }
    verified = verify_embedded(package, manifest)
    verify_upgrade_contract(package)
    (root / 'InstallMovementRewards.luau').write_text(package, encoding='utf-8', newline='\n')
    (root / 'movement-package-manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    print(json.dumps({**manifest['package'], 'embedded_files_verified': verified}))


if __name__ == '__main__':
    rebuild()
