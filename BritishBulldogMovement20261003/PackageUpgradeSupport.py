import hashlib
import json
import re
from pathlib import Path


LOBBY_DEFAULTS = {
    'WinnerCoins': 150,
    'LoserCoins': 50,
    'WinnerXP': 100,
    'LoserXP': 25,
    'BaseLevelXP': 100,
    'LevelXPStep': 50,
}
MOVEMENT_DEFAULTS = {
    'RunnerSprintSeconds': 10,
    'InitialBulldogSprintSeconds': 15,
    'SprintRefillSeconds': 15,
    'SprintMultiplier': 2.5,
    'DodgeCooldownSeconds': 4,
    'DodgeBoostMultiplier': 2,
    'DodgeBoostSeconds': 1.5,
}


def read(path):
    return Path(path).read_text(encoding='utf-8-sig').replace('\r\n', '\n')


def literal(value):
    level = 1
    while ']' + '=' * level + ']' in value:
        level += 1
    return '[' + '=' * level + '[' + value + ']' + '=' * level + ']'


def entry(path, source, kind):
    return {
        'file': str(path),
        'sha256': hashlib.sha256(source.encode()).hexdigest(),
        'bytes': len(source.encode()),
        'kind': kind,
    }


def support_files(folder):
    return {path.name: entry(path, read(path), 'support_svg') for path in sorted(Path(folder).glob('*.svg'))}


def icon_assets(folder):
    path = Path(folder) / 'IconAssetIds.json'
    if not path.exists():
        return {}, None, None
    source = read(path)
    content = json.loads(source)
    assert isinstance(content, dict), 'IconAssetIds.json must be an object'
    values = content.get('assets', content)
    assert isinstance(values, dict), 'IconAssetIds.json assets must be an object'
    assets = {}
    for name in ('Sprint', 'Dodge', 'Level'):
        value = values.get(name, values.get(name.lower()))
        if value is None:
            continue
        if isinstance(value, dict):
            value = value.get('assetId', value.get('id', value.get('url')))
        assert not isinstance(value, bool), name + ' icon must use a positive asset ID'
        if isinstance(value, (int, float)):
            assert int(value) == value and value > 0, name + ' icon asset ID is invalid'
            value = 'rbxassetid://' + str(int(value))
        assert isinstance(value, str) and re.fullmatch(r'rbxassetid://[1-9][0-9]*', value), name + ' icon URL is invalid'
        assets[name] = value
    info = entry(path, source, 'asset_json')
    info['normalized_assets'] = assets
    return assets, source, info


def default_fragment():
    def line(object_name, name, value):
        return f'if {object_name}:GetAttribute("{name}")==nil then {object_name}:SetAttribute("{name}",{value}) end\n'
    return ''.join(line('lobby', key, value) for key, value in LOBBY_DEFAULTS.items()) + ''.join(
        line('britishBulldog', key, value) for key, value in MOVEMENT_DEFAULTS.items())


def asset_fragment(assets, raw):
    text = 'local iconAssetJson=' + literal(raw or '') + '\n'
    text += 'local iconAssets={\n'
    for name, value in assets.items():
        text += ' ["' + name + '"]=' + literal(value) + ',\n'
    text += '''}
local function importIcon(parent,imageName,key)
 local image=parent and parent:FindFirstChild(imageName)
 if not image then return end
 assert(image:IsA("ImageLabel"),key.." icon must be an ImageLabel")
 if image.Image=="" and iconAssets[key] then image.Image=iconAssets[key] end
 local fallback=parent:FindFirstChild("IconFallback")
 if fallback and image.Image~="" then fallback.Visible=false end
end
local movementControls=assert(britishBulldogHUD:FindFirstChild("MovementControls"),"Movement controls are missing")
importIcon(movementControls:FindFirstChild("Sprint"),"Icon","Sprint")
importIcon(movementControls:FindFirstChild("Dodge"),"Icon","Dodge")
importIcon(shell:FindFirstChild("LevelPanel"),"LevelIcon","Level")
'''
    return text


def verify_embedded(package, manifest):
    checks = 0
    for name, info in manifest.items():
        if name == 'package':
            continue
        source = read(info['file'])
        assert hashlib.sha256(source.encode()).hexdigest() == info['sha256'], name + ' source changed since packaging'
        assert len(source.encode()) == info['bytes'], name + ' source byte count differs'
        if info['kind'] == 'source':
            match = re.search(r' \["' + re.escape(name) + r'"\]=\[(=+)\[', package)
            assert match, name + ' missing from package'
            closing = ']' + match.group(1) + ']'
            actual = package[match.end():package.index(closing, match.end())]
            assert actual == source, name + ' embedded source differs'
            if name in ('BBMovement', 'PlayerLevel', 'BritishBulldogHUD'):
                assert not re.search(r'\.(?:Position|Size|AnchorPoint)\s*=', source), name + ' must preserve authored layout properties'
        elif info['kind'] == 'builder':
            marker = 'local function ' + name + '()\n'
            start = package.index(marker) + len(marker)
            assert package[start:start + len(source)] == source, name + ' embedded builder differs'
        elif info['kind'] == 'asset_json':
            assert 'local iconAssetJson=' + literal(source) + '\n' in package, name + ' embedded icon JSON differs'
            for key, value in info['normalized_assets'].items():
                assert ' ["' + key + '"]=' + literal(value) + ',\n' in package, key + ' embedded icon ID differs'
        else:
            raise AssertionError(name + ' has unknown manifest kind')
        checks += 1
    summary = manifest['package']
    assert sum(info.get('kind') == 'source' for info in manifest.values()) == summary['sources']
    assert sum(info.get('kind') == 'builder' for info in manifest.values()) == summary['builders']
    assert hashlib.sha256(package.encode()).hexdigest() == summary['sha256'], 'Package hash differs'
    assert len(package.encode()) == summary['bytes'], 'Package byte count differs'
    for name, info in summary.get('support_files', {}).items():
        source = read(info['file'])
        assert hashlib.sha256(source.encode()).hexdigest() == info['sha256'], name + ' support file changed since packaging'
        assert len(source.encode()) == info['bytes'], name + ' support byte count differs'
    return checks


def verify_upgrade_contract(package):
    assert 'Enum.SecurityCapability.DataStore' not in package
    assert 'Enum.SecurityCapability.CapabilityControl' not in package
    assert 'local remoteCaps=SecurityCapabilities.new(Enum.SecurityCapability.RemoteEvent)' in package
    assert '"BBMovementRequest"' in package
    assert 'object.Capabilities=remoteCaps\n  object.Sandboxed=true\n  object.Parent=ReplicatedStorage' in package
    assert 'sources.BritishBulldogService,ServerScriptService,rpcCaps)' in package
    assert '"MovementController",sources.BBMovement,britishBulldogHUD,inputRpcCaps)' in package
    assert 'local previewCaps=baseCaps:Add(SecurityCapabilities.new(Enum.SecurityCapability.Animation))' in package
    assert '"PlayerLevelController",sources.PlayerLevel,shell,previewCaps)' in package
    assert 'upgradeBritishBulldogControls()' in package and 'upgradePlayerLevel()' in package
    assert 'oldBootstrap.Disabled=true' in package
    assert 'bootstrap.Disabled=false' in package
    assert 'object.Capabilities=caps or baseCaps\n  object.Sandboxed=true' in package
    for key, value in LOBBY_DEFAULTS.items():
        assert f'if lobby:GetAttribute("{key}")==nil then lobby:SetAttribute("{key}",{value}) end' in package
    for key, value in MOVEMENT_DEFAULTS.items():
        assert f'if britishBulldog:GetAttribute("{key}")==nil then britishBulldog:SetAttribute("{key}",{value}) end' in package
    assert 'if image.Image=="" and iconAssets[key] then image.Image=iconAssets[key] end' in package
    assert ('gui:FindFirstChild("MovementControls") then return {created=false,preserved=true}' in package
            or 'if existing then addBoost(existing) return {created=false,preserved=true} end' in package)
    assert 'gui:FindFirstChild("LevelPanel") then return {created=false,preserved=true}' in package
    assert 'if gui:FindFirstChild("CompactDeparture") then return end' in package
    assert 'compact.Size=UDim2.fromOffset(115,52)' in package
    assert 'compact.Position=UDim2.new(0,16,1,-140)' in package
    assert 'Position=UDim2.new(0,16,1,-201),Size=UDim2.fromOffset(115,52)' in package
    assert '(camera.ViewportSize.X < 980 or camera.ViewportSize.Y < 450)' in package
    assert '(camera.ViewportSize.X<980 or camera.ViewportSize.Y<450)' in package
    assert 'compactDeparture.Visible = showDeparture and useCompactDeparture == true' in package
    assert 'local visible=inputContext() and role~="Tagged"' in package
    assert 'gui.RolePill.Visible = phase ~= "Results" and not gui:FindFirstChild("MovementControls")' in package
    trailer = package[package.rindex('local ServerScriptService=game:GetService("ServerScriptService")'):]
    assert trailer.count('Enum.SecurityCapability.Animation') == 1, 'Only preview capabilities may add Animation'
    assert trailer.count('shell,previewCaps)') == 1 and trailer.count(',previewCaps)') == 1, 'Only PlayerLevelController may use preview capabilities'
    assert trailer.index('"BBMovementRequest"') < trailer.index('sources.BritishBulldogService,ServerScriptService,rpcCaps)'), 'Movement remote must exist before service installation'
    assert trailer.index('local movementResult=upgradeBritishBulldogControls()') < trailer.index('"MovementController",sources.BBMovement'), 'Editable controls must exist before client installation'
    assert trailer.index('local levelResult=upgradePlayerLevel()') < trailer.index('"PlayerLevelController",sources.PlayerLevel'), 'Editable level panels must exist before client installation'
    assert trailer.index('object.Capabilities=caps or baseCaps\n  object.Sandboxed=true') < trailer.index('object.Source=source\n  object.Parent=parent'), 'New scripts must retain restricted capabilities before parenting'
    assert trailer.index('object.Capabilities=remoteCaps\n  object.Sandboxed=true') < trailer.index('object.Parent=ReplicatedStorage'), 'New remotes must retain restricted capabilities before parenting'
    assert trailer.index('oldBootstrap.Disabled=true') < trailer.index('bootstrap.Disabled=false'), 'Legacy bootstrap must be disabled before coordinated bootstrap starts'
