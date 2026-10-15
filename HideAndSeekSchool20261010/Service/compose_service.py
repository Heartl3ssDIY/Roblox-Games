from pathlib import Path

root = Path(__file__).resolve().parent
tag = (root.parent.parent / 'BatReach20261008/After/TagService.luau').read_text()
body = (root / 'HideAndSeekService.body.luau').read_text()
contact = tag[tag.index('local function sampleBatSwing'):tag.index('local function chaseGoal')]
ragdoll = tag[tag.index('function Service:_restoreRagdoll'):tag.index('function Service:', tag.index('function Service:_ragdoll') + 20)]
ragdoll = ragdoll.replace('TGRagdoll', 'HSRagdoll').replace('TGRagdolled', 'HSRagdolled')
ragdoll = ragdoll.replace('\tself:_stopBurst(record)\n', '')
ragdoll = ragdoll.replace('Tag ragdoll could not start', 'Hide and Seek ragdoll could not start')
ragdoll = ragdoll.replace('\tlocal character, humanoid, root = record.character, record.humanoid, record.root', '\tself:_releaseSeat(record)\n\tlocal character, humanoid, root = record.character, record.humanoid, record.root')
source = body.replace('__BAT_CONTACT__', contact).replace('__RAGDOLL__', ragdoll)
(root / 'HideAndSeekService.luau').write_text(source)
fixture = root / 'NativeChecks.template.luau'
if fixture.exists():
    (root / 'NativeChecks.luau').write_text(fixture.read_text().replace('__SERVICE_SOURCE__', source))
installer = root / 'InstallService.template.luau'
if installer.exists():
    (root / 'InstallService.luau').write_text(installer.read_text().replace('__SERVICE_SOURCE__', source))
print(f'Prepared {len(source)} characters, {source.count(chr(10))} lines')
