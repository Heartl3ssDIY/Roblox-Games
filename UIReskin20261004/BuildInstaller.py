import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent

def literal(value):
    for count in range(1, 12):
        equals = '=' * count
        if ']' + equals + ']' not in value:
            return '[' + equals + '[' + value + ']' + equals + ']'
    raise ValueError('Cannot quote source')

def read(name):
    return (ROOT / name).read_text(encoding='utf-8-sig')

plan = json.loads(read('SkinPlan.json'))
for entry in plan['mappings'] + plan['meterFills']:
    for key in ['reason', 'originalClass', 'originalAbsoluteSize', 'currentColorRGB', 'gradientSource']:
        entry.pop(key, None)
plan = {key: plan[key] for key in ['mappings', 'meterFills', 'icons', 'libraryAssets', 'clearShadows', 'clearIconFallbacks']}
source_paths = ['ReplicatedStorage.PlaygroundCatalog', 'ServerScriptService.PlaygroundEconomyService', 'StarterGui.PlaygroundShell.Controller']
replacements = {path: {'before': read('Before/' + path + '.luau'), 'after': read('After/' + path + '.luau')} for path in source_paths}
payload = {
    'assets': json.loads(read('AllAssetIds.json')),
    'plan': plan,
    'replacements': replacements,
    'controller': read('ReusableSkinController.client.luau'),
    'builders': {name: read(name + '.luau') for name in ['RemovePlaceholderContent', 'ApplyScreenSkins', 'ApplyLeaderboardSkins', 'ApplyWorldSkins', 'ApplySkinRefinement']},
}
installer = 'local data = game:GetService("HttpService"):JSONDecode(' + literal(json.dumps(payload, ensure_ascii=False, separators=(',', ':'))) + ')\n' + read('InstallerBody.luau')
(ROOT / 'InstallUIReskin.luau').write_text(installer, encoding='utf-8')
print(json.dumps({'path': str(ROOT / 'InstallUIReskin.luau'), 'characters': len(installer)}))
