from pathlib import Path
import json

root = Path(__file__).resolve().parent
source = (root / 'Before/HideAndSeekService.luau').read_text()
assert source.count('self:_setting("HideSeconds", 20, 5, 60)') == 2
patched = source.replace('self:_setting("HideSeconds", 20, 5, 60)', 'self:_setting("HideSeconds", 30, 5, 60)')
needle = '\tself.bounds = self.gameplay:WaitForChild("ArenaBounds")\n'
assert patched.count(needle) == 1
patched = patched.replace(needle, needle + '\tlocal bell = arena:FindFirstChild("SchoolBell", true)\n\tself.schoolBell = bell and bell:IsA("Sound") and bell or nil\n')
needle = 'function Service:_phase(phase)\n'
assert patched.count(needle) == 1
patched = patched.replace(needle, 'function Service:_ringSchoolBell()\n\tlocal bell = self.schoolBell\n\tif not bell or not bell.Parent then return end\n\tbell:Stop()\n\tbell.TimePosition = 0\n\tbell:Play()\nend\n\n' + needle)
needle = '\t\tself:_phase("Seeking")\n'
assert patched.count(needle) == 1
patched = patched.replace(needle, '\t\tself:_ringSchoolBell()\n' + needle)
needle = '\tif token and token ~= self.currentRound then return end\n'
assert patched.count(needle) == 1
patched = patched.replace(needle, needle + '\tif self.schoolBell and self.schoolBell.Parent then self.schoolBell:Stop() end\n')
after = root / 'After'
after.mkdir(exist_ok=True)
(after / 'HideAndSeekService.luau').write_text(patched)

digest = 5381
for byte in source.encode('utf-8'):
    digest = (digest * 33 + byte) % (2**32)
installer = (root / 'Install.template.luau').read_text()
installer = installer.replace('__SOURCE__', patched).replace('__BEFORE_LENGTH__', str(len(source.encode('utf-8')))).replace('__BEFORE_DIGEST__', str(digest))
(root / 'Install.luau').write_text(installer)

base = root.parent.parent / 'HideAndSeekSchool20261010/Service/NativeChecks.template.luau'
fixture = base.read_text().replace('__SERVICE_SOURCE__', patched)
fixture = fixture.replace('HideSeconds = 20,', 'HideSeconds = 30,')
fixture = fixture.replace('local service\nlocal function character', 'local bellCalls = { play = 0, stop = 0 }\nlocal fakeBell = { Parent = true, TimePosition = 0 }\nfunction fakeBell:Play() bellCalls.play += 1 end\nfunction fakeBell:Stop() bellCalls.stop += 1 end\nlocal service\nlocal function character')
fixture = fixture.replace('service = Service.new(arena, state)\n\tservice:Start()', 'service = Service.new(arena, state)\n\tservice.schoolBell = fakeBell\n\tservice:Start()')
needle = '\tnow += 20 service:_tick(0.05)\n'
assert fixture.count(needle) == 1
fixture = fixture.replace(needle, '''\tlocal beforeRelease = bellCalls.play
\tcheck("Hiding grace is exactly 30 seconds", math.abs(service.hidingEndsAt - now - 30) < 0.001)
\tnow += 29.9 service:_tick(0.05)
\tcheck("Seekers remain held before thirty seconds", service.phase == "Hiding" and seeker.frozen and seeker.root.Anchored)
\tcheck("Bell is silent before release", bellCalls.play == beforeRelease)
\tnow += 0.1 service:_tick(0.05)
\tcheck("Bell rings once at seeker release", bellCalls.play == beforeRelease + 1 and fakeBell.TimePosition == 0)
\tservice:_tick(0.05)
\tcheck("Heartbeat does not replay bell", bellCalls.play == beforeRelease + 1)
''')
fixture = fixture.replace('\tservice:Stop()\n\tcheck("Service stops and disconnects"', '\tlocal stopCount = bellCalls.stop\n\tservice:Stop()\n\tcheck("Service shutdown stops bell", bellCalls.stop > stopCount)\n\tcheck("Service stops and disconnects"')
(root / 'NativeChecks.luau').write_text(fixture)
print(json.dumps({'beforeLength':len(source),'afterLength':len(patched),'guard':digest,'hudSourceUnchanged':True}))
