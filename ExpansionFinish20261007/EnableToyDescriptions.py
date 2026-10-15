import json
import re
from pathlib import Path

root = Path(__file__).resolve().parent
before = (root / 'After/PlaygroundCatalog.luau').read_text(encoding='utf-8')
descriptions = {
    'M16': 'Lobby only. Take a sip and release a cheerful flurry of snow sparkles. Cosmetic effect.',
    'M17': 'Lobby only. Fire a playful snowball with a throwing pose. Cosmetic shot; no freeze or damage.',
    'M18': 'Lobby only. Blow a stream of floating cartoon bubbles. Cosmetic effect.',
    'M19': 'Lobby only. Place a banana prop that disappears after 5 seconds. Cosmetic prop; no slipping.',
    'M20': 'Lobby only. Swing a spring glove with a sparkling bonk. Cosmetic effect; no damage or knockback.',
    'M21': 'Lobby only. Toss a honey pot with a golden splat. Cosmetic effect; no slowing players.',
    'M22': 'Lobby only. Squeeze and shake a whoopee cushion with a playful puff. Cosmetic effect.',
    'M23': 'Lobby only. Aim a chunky magnet and create a sparkling arc. Cosmetic effect; no pulling players.',
    'M24': 'Lobby only. Throw a flyer that curves back toward you. Cosmetic effect.',
    'M25': 'Lobby only. Shake a surprise box to release colourful confetti. Cosmetic effect.',
}
after = before
for key, text in descriptions.items():
    pattern = r'(item\("' + key + r'"[^\n]*?nil, )"[^"]*"'
    after, count = re.subn(pattern, lambda m: m[1] + json.dumps(text), after)
    assert count == 1, key
after = after.replace('byId[string.format("M%02d", index)].toyActionPending = true', 'byId[string.format("M%02d", index)].cosmeticOnly = true')
(root / 'After/PlaygroundCatalog.luau').write_bytes(after.encode('utf-8'))
(root / 'ToyCatalogSnapshot.json').write_text(json.dumps({'before':before,'after':after},indent=2),encoding='utf-8')
schedule = json.loads((root / 'ExpansionUnlocks.json').read_text())
for item in schedule:
    if item['id'] in descriptions:
        item['toyActionPending'] = False
        item['cosmeticOnly'] = True
        item['description'] = descriptions[item['id']]
(root / 'ExpansionUnlocks.json').write_text(json.dumps(schedule,indent=2),encoding='utf-8')
print('Enabled catalog descriptions for ten cosmetic toy actions.')
