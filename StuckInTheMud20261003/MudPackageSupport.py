import hashlib
import json
import re
from pathlib import Path


LOBBY_SETTINGS = {
    'WinnerCoins': 150, 'LoserCoins': 50, 'WinnerXP': 50, 'LoserXP': 50,
    'BaseLevelXP': 200, 'LevelXPStep': 50,
}
MUD_TEAM_PROFILES = {
    'two_v_two': {'TeamCount': 2, 'MaxTeamSize': 2, 'MaxPlayers': 4, 'MinimumPlayers': 4},
    'two_full_teams': {'TeamCount': 2, 'MaxTeamSize': 12, 'MaxPlayers': 24, 'MinimumPlayers': 2},
    'pairs_24': {'TeamCount': 12, 'MaxTeamSize': 2, 'MaxPlayers': 24, 'MinimumPlayers': 2},
}
MUD_DEFAULTS = {
    'TeamCount': 2, 'MaxTeamSize': 2, 'MaxPlayers': 4, 'MinimumPlayers': 4, 'RoundDuration': 300,
    'SprintSeconds': 10, 'SprintMultiplier': 2.5, 'SprintRefillSeconds': 15,
    'RescueSeconds': 5, 'ProjectileSpeed': 115, 'MudRange': 130,
    'MudCooldownSeconds': 0.65, 'HeatRange': 24,
}
TAG_DEFAULTS = {'SprintSeconds': 10, 'SprintMultiplier': 2.5, 'SprintRefillSeconds': 15}
CLIENTS = {
    'MudHUD': ('Controller', 'mudHUD', 'inputRpcCaps'),
    'TagSprint': ('SprintController', 'tagHUD', 'inputRpcCaps'),
    'TagHUD': ('Controller', 'tagHUD', 'inputRpcCaps'),
    'PlaygroundAdminPanel': ('Controller', 'adminHUD', 'inputRpcCaps'),
    'PlaygroundShell': ('Controller', 'shell', 'rpcCaps'),
    'PlayerLevel': ('PlayerLevelController', 'shell', 'previewCaps'),
}
MODULES = ('StuckInTheMudService', 'TagSprintService', 'PlaygroundCoordinator',
           'PlaygroundEconomyService', 'PlaygroundAdminService', 'TagService')


def approval_preflight():
    return '''local approvedMudService=game:GetService("ServerScriptService"):FindFirstChild("StuckInTheMudService")
local requiredMudInput=SecurityCapabilities.new(Enum.SecurityCapability.Input)
assert(approvedMudService and approvedMudService:IsA("ModuleScript") and approvedMudService.Sandboxed and approvedMudService.Capabilities:Contains(requiredMudInput),"Installation pending explicit approval: StuckInTheMudService must receive Input through the normal approval mechanism first; this installer cannot grant it")
'''


def read(path):
    return Path(path).read_text(encoding='utf-8-sig').replace('\r\n', '\n')


def literal(value):
    level = 1
    while ']' + '=' * level + ']' in value:
        level += 1
    return '[' + '=' * level + '[' + value + ']' + '=' * level + ']'


def digest(value):
    return hashlib.sha256(value).hexdigest()


def text_entry(path, source, kind):
    return {'file': str(path), 'sha256': digest(source.encode()),
            'bytes': len(source.encode()), 'kind': kind}


def file_entry(path, kind='support'):
    content = Path(path).read_bytes()
    return {'file': str(path), 'sha256': digest(content), 'bytes': len(content), 'kind': kind}


def setting_fragment():
    result = ''.join(f'lobby:SetAttribute("{key}",{value})\n' for key, value in LOBBY_SETTINGS.items())
    for object_name, defaults in (('mud', MUD_DEFAULTS), ('tag', TAG_DEFAULTS)):
        result += ''.join(f'if {object_name}:GetAttribute("{key}")==nil then {object_name}:SetAttribute("{key}",{value}) end\n'
                          for key, value in defaults.items())
    return result


def verify_embedded(package, manifest):
    checks = 0
    for name, info in manifest['files'].items():
        source = read(info['file'])
        assert digest(source.encode()) == info['sha256'], name + ' source changed since packaging'
        assert len(source.encode()) == info['bytes'], name + ' source byte count differs'
        if info['kind'] == 'source':
            match = re.search(r' \["' + re.escape(name) + r'"\]=\[(=+)\[', package)
            assert match, name + ' source missing from package'
            close = ']' + match.group(1) + ']'
            actual = package[match.end():package.index(close, match.end())]
            assert actual == source, name + ' embedded source differs'
            if name in CLIENTS:
                assert not re.search(r'\.(?:Position|Size|AnchorPoint)\s*=', source), name + ' changes an authored layout'
            if name == 'StuckInTheMudService':
                readiness = source[source.index('function Service:_weaponsReady()'):source.index('function Service:StartRound(selected)')]
                assert 'local ok, ready = pcall(function()' in readiness
                assert 'local mudEnabled, heatEnabled = mud.Enabled, heat.Enabled' in readiness
                assert 'return mudEnabled == true and heatEnabled == true' in readiness
                assert 'return ok and ready == true' in readiness
                assert 'script.Capabilities' not in readiness
                assert source.count('if not ready then return false, "Mud gun access is awaiting approval." end') == 2
        elif info['kind'] == 'builder':
            marker = 'local function ' + name + '()\n'
            start = package.index(marker) + len(marker)
            assert package[start:start + len(source)] == source, name + ' embedded builder differs'
        else:
            raise AssertionError(name + ' unknown embedded kind')
        checks += 1
    summary = manifest['package']
    assert sum(info['kind'] == 'source' for info in manifest['files'].values()) == summary['sources']
    assert sum(info['kind'] == 'builder' for info in manifest['files'].values()) == summary['builders']
    assert digest(package.encode()) == summary['sha256'], 'Compact package hash differs'
    assert len(package.encode()) == summary['bytes'], 'Compact package byte count differs'
    for name, info in summary['support_files'].items():
        content = Path(info['file']).read_bytes()
        assert digest(content) == info['sha256'], name + ' support file changed since packaging'
        assert len(content) == info['bytes'], name + ' support byte count differs'
    return checks


def verify_upgrade_contract(package):
    assert 'Enum.SecurityCapability.DataStore' not in package
    assert 'Enum.SecurityCapability.CapabilityControl' not in package
    assert 'assert(not RunService:IsRunning()' in package
    marker = 'local ServerScriptService=game:GetService("ServerScriptService")\nlocal ServerStorage=game:GetService("ServerStorage")'
    trailer = package[package.rindex(marker):]
    assert 'local remoteCaps=SecurityCapabilities.new(Enum.SecurityCapability.RemoteEvent)' in trailer
    assert 'local previewCaps=baseCaps:Add(SecurityCapabilities.new(Enum.SecurityCapability.Animation))' in trailer
    assert trailer.count('Enum.SecurityCapability.Animation') == 1
    assert trailer.count(',previewCaps)') == 1, 'Only PlayerLevelController may have preview capabilities'
    assert 'object.Capabilities=remoteCaps\n  object.Sandboxed=true\n  object.Parent=ReplicatedStorage' in trailer
    assert 'object.Capabilities=caps\n  object.Sandboxed=true' in trailer
    assert trailer.index('object.Capabilities=caps\n  object.Sandboxed=true') < trailer.index('object.Source=source\n  object.Parent=parent')
    assert 'remoteCaps:Contains(object.Capabilities) and object.Capabilities:Contains(remoteCaps)' in trailer
    assert 'PlaygroundBeforeMud20261003' in trailer
    assert 'if guiBackups:FindFirstChild(gui.Name) then return end' in trailer
    assert 'if savedSources:FindFirstChild(key) then return end' in trailer
    assert 'copy.Enabled=false' in trailer and 'object.Disabled=true' in trailer
    assert 'if configBackups:FindFirstChild(object.Name) then return end' in trailer
    assert 'bootstrap.Disabled=true' in trailer
    for remote in ('MudActionRequest', 'TagSprintRequest'):
        remote_at = trailer.index('remote("' + remote + '")')
        assert remote_at < trailer.index('sources.StuckInTheMudService,ServerScriptService,approvedMudCaps)')
        assert remote_at < trailer.index('sources.TagSprintService,ServerScriptService,rpcCaps)')
    assert 'state("MudState")' in trailer
    for module in MODULES:
        caps = 'approvedMudCaps' if module == 'StuckInTheMudService' else 'rpcCaps'
        assert f'install("ModuleScript","{module}",sources.{module},ServerScriptService,{caps})' in trailer
    for source, (name, parent, caps) in CLIENTS.items():
        assert f'install("LocalScript","{name}",sources.{source},{parent},{caps})' in trailer
    assert trailer.index('local hudResult=buildMudHUD()') < trailer.index('sources.MudHUD,mudHUD,inputRpcCaps)')
    assert trailer.index('local sprintResult=buildTagSprintUI()') < trailer.index('sources.TagSprint,tagHUD,inputRpcCaps)')
    assert trailer.index('local voteResult=upgradeThirdGameLobby()') < trailer.index('sources.PlaygroundShell,shell,rpcCaps)')
    assert trailer.index('local arenaResult=buildMudArena()') < trailer.index('local repairResult=repairMudArena()')
    assert trailer.index('local toolsResult=buildMudGunTemplates()') < trailer.index('sources.StuckInTheMudService,ServerScriptService,approvedMudCaps)')
    assert 'local approvedMudCaps=approvedMudService.Capabilities' in trailer
    assert 'inputRpcCaps:Contains(approvedMudCaps) and approvedMudCaps:Contains(inputRpcCaps)' in trailer
    assert 'assert(object==approvedMudService,"The approved mud service changed during installation")' in trailer
    assert 'if object~=approvedMudService then object.Capabilities=caps end' in trailer
    assert approval_preflight() in package
    assert package.index(approval_preflight()) < package.index('local sources={')
    assert 'sources.StuckInTheMudService,ServerScriptService,inputRpcCaps)' not in trailer
    assert trailer.index('oldBootstrap.Disabled=true') < trailer.index('bootstrap.Disabled=false')
    assert trailer.index('sources.PlaygroundBootstrap,ServerScriptService,rpcCaps)') < trailer.index('bootstrap.Disabled=false')
    for key, value in LOBBY_SETTINGS.items():
        assert f'lobby:SetAttribute("{key}",{value})' in trailer
    for obj, values in (('mud', MUD_DEFAULTS), ('tag', TAG_DEFAULTS)):
        for key, value in values.items():
            assert f'if {obj}:GetAttribute("{key}")==nil then {obj}:SetAttribute("{key}",{value}) end' in trailer
    assert 'if StarterGui:FindFirstChild("MudHUD") then return {preserved=true,muddyTemplate=true} end' in package
    assert package.index('if not assets:FindFirstChild("MuddyTemplate") then') < package.index('if StarterGui:FindFirstChild("MudHUD") then')
    assert 'if gui:FindFirstChild("SprintPanel") then' in package
    assert 'if (gui:GetAttribute("SprintLayoutVersion") or 0)<2 then authorNotices() return {preserved=true,noticesUpdated=true} end' in package
    assert 'local voteResult=upgradeThirdGameLobby()' in trailer
    assert trailer.index('local voteResult=upgradeThirdGameLobby()') < trailer.index('sources.PlaygroundAdminPanel,adminHUD,inputRpcCaps)')
    assert 'shell:FindFirstChild("CompactVotePanel")' in trailer
    assert 'adminHUD:FindFirstChild("CompactPanel") and adminHUD:FindFirstChild("CompactToggle")' in trailer
    assert 'if not vote:FindFirstChild("StuckInTheMud") then' in package
    assert 'if not content:FindFirstChild("StuckInTheMud") then' in package
    assert 'if not gameplay.VoteChoices:FindFirstChild("StuckInTheMud") then' in package
    assert 'if existing then return {built=false,preserved=true' in package
    assert 'MudGeometryRepairVersion' in package
    if 'local function buildSchoolScenery()' in package:
        assert trailer.index('local repairResult=repairMudArena()') < trailer.index('local sceneryResult=buildSchoolScenery()')
        assert trailer.index('local sceneryResult=buildSchoolScenery()') < trailer.index('local toolsResult=buildMudGunTemplates()')
        assert 'SchoolScenery' in package
    return True


def all_games_text(expansion, mud):
    return (approval_preflight() + 'local function installExpansion()\n' + expansion + '\nend\n'
            'local function installMud()\n' + mud + '\nend\n'
            'local expansionResult=installExpansion()\n'
            'local mudResult=installMud()\n'
            'return {installed=true,expansion=expansionResult,mud=mudResult,allThreeGames=true}\n')


def verify_expansion_stage(package, manifest_path):
    manifest = json.loads(Path(manifest_path).read_text(encoding='utf-8'))
    assert digest(package.encode()) == manifest['package']['sha256'], 'Prior expansion package differs from its manifest'
    assert len(package.encode()) == manifest['package']['bytes']
    checks = 0
    for name, info in manifest.items():
        if name == 'package':
            continue
        source = read(info['file'])
        assert digest(source.encode()) == info['sha256'], name + ' expansion source changed since packaging'
        assert len(source.encode()) == info['bytes']
        if info['kind'] == 'source':
            match = re.search(r' \["' + re.escape(name) + r'"\]=\[(=+)\[', package)
            assert match, name + ' missing from expansion stage'
            close = ']' + match.group(1) + ']'
            assert package[match.end():package.index(close, match.end())] == source
        elif info['kind'] == 'builder':
            marker = 'local function ' + name + '()\n'
            start = package.index(marker) + len(marker)
            assert package[start:start + len(source)] == source
        elif info['kind'] == 'asset_json':
            assert 'local iconAssetJson=' + literal(source) + '\n' in package
        else:
            raise AssertionError(name + ' unknown expansion manifest kind')
        checks += 1
    for name, info in manifest['package'].get('support_files', {}).items():
        source = read(info['file'])
        assert digest(source.encode()) == info['sha256'], name + ' expansion support file changed'
        assert len(source.encode()) == info['bytes']
    assert 'Enum.SecurityCapability.DataStore' not in package
    assert 'Enum.SecurityCapability.CapabilityControl' not in package
    assert sum(info.get('kind') == 'source' for info in manifest.values()) == manifest['package']['sources']
    assert sum(info.get('kind') == 'builder' for info in manifest.values()) == manifest['package']['builders']
    return checks


def verify_all_games(package, manifest, mud):
    summary = manifest['all_games_package']
    expansion_info = summary['expansion_stage']
    expansion = read(expansion_info['file'])
    assert digest(expansion.encode()) == expansion_info['sha256'], 'Prior expansion stage changed'
    assert len(expansion.encode()) == expansion_info['bytes']
    expansion_manifest = summary['expansion_manifest']
    content = Path(expansion_manifest['file']).read_bytes()
    assert digest(content) == expansion_manifest['sha256'], 'Expansion manifest changed'
    expansion_checks = verify_expansion_stage(expansion, expansion_manifest['file'])
    assert package == all_games_text(expansion, mud), 'Full installer stages or execution order differ'
    assert digest(package.encode()) == summary['sha256'], 'All-games package hash differs'
    assert len(package.encode()) == summary['bytes']
    assert package.rindex('local expansionResult=installExpansion()') < package.rindex('local mudResult=installMud()')
    assert package.endswith('return {installed=true,expansion=expansionResult,mud=mudResult,allThreeGames=true}\n')
    assert package.startswith(approval_preflight())
    return expansion_checks


def load_manifest(root):
    return json.loads((Path(root) / 'mud-package-manifest.json').read_text(encoding='utf-8'))
