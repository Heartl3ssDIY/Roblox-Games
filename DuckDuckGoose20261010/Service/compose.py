from pathlib import Path

root = Path(__file__).resolve().parent
tag = (root.parent.parent / 'BatReach20261008/After/TagService.luau').read_text()
body = (root / 'DuckDuckGooseService.body.luau').read_text()
contact = tag[tag.index('local function sampleBatSwing'):tag.index('local function chaseGoal')]
ragdoll = tag[tag.index('function Service:_restoreRagdoll'):tag.index('function Service:', tag.index('function Service:_ragdoll') + 20)]
ragdoll = ragdoll.replace('TGRagdoll', 'DGRagdoll').replace('TGRagdolled', 'DGRagdolled')
ragdoll = ragdoll.replace('\tself:_stopBurst(record)\n', '\tself:_standUp(record)\n')
ragdoll = ragdoll.replace('Tag ragdoll could not start', 'Duck Duck Goose ragdoll could not start')
ragdoll = ragdoll.replace('if record.character == saved.character and record.participating then self:_movement(record) end', 'if record.character == saved.character and record.inRound then self:_movement(record) end')
source = body.replace('__BAT_CONTACT__', contact).replace('__RAGDOLL__', ragdoll)
(root / 'DuckDuckGooseService.luau').write_text(source)
for name in ['NativeChecks', 'InstallService']:
    template = root / f'{name}.template.luau'
    if template.exists(): (root / f'{name}.luau').write_text(template.read_text().replace('__SERVICE_SOURCE__', source))
before = root / 'BeforeInstalledSafetyFix.luau'
if before.exists():
    previous = before.read_text()
    if previous.endswith('\n\n'): previous = previous[:-1]
    digest = 5381
    for byte in previous.encode('utf-8'): digest = (digest * 33 + byte) % 4294967296
    update = (root / 'UpdateInstalledService.template.luau').read_text().replace('__SERVICE_SOURCE__', source)
    update = update.replace('__BEFORE_LENGTH__', str(len(previous.encode('utf-8')))).replace('__BEFORE_DIGEST__', str(digest))
    (root / 'UpdateInstalledService.luau').write_text(update)
print(f'Prepared {len(source)} characters, {source.count(chr(10))} lines')
