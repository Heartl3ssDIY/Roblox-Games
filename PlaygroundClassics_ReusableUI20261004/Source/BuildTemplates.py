from pathlib import Path
import copy
import json
import re
import xml.etree.ElementTree as ET
from PIL import ImageFont

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT.parent
NS = 'http://www.w3.org/2000/svg'
ET.register_namespace('', NS)
INK = '#1b2d3d'
CREAM = '#fff7db'
WHITE = '#fffff8'
BLUE = '#59c1f4'
GOLD = '#ffd34e'
PINK = '#ff99a6'
MINT = '#82e1b4'
MUTED = '#536b7b'
FONT_ROOTS = list(Path(r'C:/Users/sandt/AppData/Local/Roblox/Versions').glob('version-*/content/fonts'))
FONT_DIR = next(p for p in FONT_ROOTS if (p / 'LuckiestGuy-Regular.ttf').exists())
FONT_FILES = {'Luckiest Guy': 'LuckiestGuy-Regular.ttf', 'Fredoka One': 'FredokaOne-Regular.ttf'}

def n(value):
    return f'{value:.3f}'.rstrip('0').rstrip('.')

def el(tag, attrs=None, text=None):
    node = ET.Element(f'{{{NS}}}{tag}', {k: str(v) for k, v in (attrs or {}).items()})
    if text is not None:
        node.text = text
    return node

def rect(parent, name, x, y, width, height, fill=CREAM, radius=14, stroke=INK, weight=4):
    node = el('rect', {'id': name, 'x': x, 'y': y, 'width': width, 'height': height, 'rx': radius,
                      'fill': fill, 'stroke': stroke, 'stroke-width': weight, 'stroke-linejoin': 'round'})
    parent.append(node)
    return node

def path(parent, name, data, fill='none', stroke=INK, weight=4):
    node = el('path', {'id': name, 'd': data, 'fill': fill, 'stroke': stroke,
                      'stroke-width': weight, 'stroke-linecap': 'round', 'stroke-linejoin': 'round'})
    parent.append(node)
    return node

def circle(parent, name, x, y, radius, fill=GOLD, weight=3):
    parent.append(el('circle', {'id': name, 'cx': x, 'cy': y, 'r': radius,
                               'fill': fill, 'stroke': INK, 'stroke-width': weight}))

def text(parent, name, value, x, y, width, height, size=24, color=INK,
         family='Luckiest Guy', align='CENTER', outlined=False, record=True):
    font = ImageFont.truetype(str(FONT_DIR / FONT_FILES[family]), size)
    while font.getlength(value) > width - 4 and size > 9:
        size -= 0.5
        font = ImageFont.truetype(str(FONT_DIR / FONT_FILES[family]), size)
    box = font.getbbox(value, anchor='ls')
    baseline = y + (height - box[1] - box[3]) / 2
    tx = x if align == 'LEFT' else x + width if align == 'RIGHT' else x + width / 2
    attrs = {'id': name, 'x': n(tx), 'y': n(baseline), 'font-family': family,
             'font-size': n(size), 'font-weight': '400', 'fill': color,
             'text-anchor': {'LEFT': 'start', 'RIGHT': 'end', 'CENTER': 'middle'}[align]}
    if outlined:
        attrs.update({'stroke': INK, 'stroke-width': '3', 'stroke-linejoin': 'round', 'paint-order': 'stroke fill'})
    node = el('text', attrs, value)
    parent.append(node)
    if record:
        TEXTS.append({'name': name, 'text': value, 'x': x, 'y': y, 'width': width, 'height': height,
                      'fontFamily': family, 'fontSize': size, 'color': color, 'align': align,
                      'strokeColor': INK if outlined else color, 'strokeWidth': 3 if outlined else 0,
                      'strokeOpacity': 1 if outlined else 0, 'opacity': 1, 'clips': [], 'rotation': 0,
                      'rotationCenter': [x + width / 2, y + height / 2]})
    return node

TEXTS = []
COMPONENTS = []
REUSE = {
    'button': ['Sprint', 'Dodge', 'Vault', 'Shop', 'Admin', 'Buy / Use', 'Start / Stop',
               'Voting choices', 'Team colors', 'Shop categories', 'Icon actions'],
    'panel': ['Shop', 'Admin panel', 'Voting panel', 'Round results', 'Team picker', 'World signs'],
    'round-header': ['British Bulldog timer and counts', "Tag You're It timer and counts", 'Stuck in the Mud timer and counts'],
    'meter': ['Stamina', 'Stamina recharge', 'XP', 'Rescue progress', 'Gun heat'],
    'player-card': ['Avatar and level', 'Player identity', 'Compact player profile'],
    'info-card': ['Coins and wins', 'Round rewards', 'Currency and statistic summaries'],
    'item-card': ['All 12 shop slots', 'Pet preview', 'Emote preview', 'Trail preview', 'Highlight preview', 'Cosmetic gear preview'],
    'status-text': ['Countdown numbers', 'BULLDOG call', 'Role label', 'Cooldown', 'Win / Loss message', 'Overhead label'],
    'icons': ['Sprint lightning', 'Dodge swoosh', 'Level / reward star', 'Heart', 'Coin', 'Crosshair', 'Emoji bubble'],
    'compact-badge': ['Role label', 'Tagged / Frozen notice', 'Leave safe zone countdown', 'Escape boost', 'Protection / movement notice'],
    'scrollbar': ['Shop categories', 'Shop cards', 'Admin sections', 'Round winners'],
}

svg = el('svg', {'width': 2160, 'height': 1450, 'viewBox': '0 0 2160 1450'})
svg.append(el('title', text='Playground Classics — reusable UI templates'))
svg.append(el('desc', text='Eleven reusable design groups audited against the current five ScreenGuis. One button, editable labels and colors, optional placement guides. Repeated actions and screen states reuse these masters.'))
metadata = el('metadata', {'id': 'playground-reusable-templates'})
svg.append(metadata)
rect(svg, 'BoardBackground', 0, 0, 2160, 1450, '#edf2f5', 0, 'none', 0)
guides = el('g', {'id': 'GuideLabels', 'data-guide': 'true'})
svg.append(guides)
text(guides, 'GuideTitle', 'PLAYGROUND CLASSICS / REUSABLE UI', 52, 26, 1800, 58, 44, align='LEFT', record=False)
text(guides, 'GuideSubtitle', 'Edit each master once. Reuse it with a different label, color or value.', 54, 92, 2000, 34, 21,
     color=MUTED, family='Fredoka One', align='LEFT', record=False)

def master(key, title, col, row, width, height):
    x = 56 + col * 700
    y = 204 + row * 350
    text(guides, 'Guide_' + key, title, x, y - 54, 644, 36, 22, align='LEFT', record=False)
    group = el('g', {'id': 'Template_' + key.replace('-', '_'), 'data-template': key,
                     'data-width': width, 'data-height': height, 'transform': f'translate({x} {y})'})
    svg.append(group)
    COMPONENTS.append({'key': key, 'name': title, 'id': group.get('id'), 'x': x, 'y': y,
                       'width': width, 'height': height, 'reuse': REUSE[key], 'texts': []})
    return group

def finish():
    COMPONENTS[-1]['texts'] = copy.deepcopy(TEXTS)
    TEXTS.clear()

g = master('button', '01 / BUTTON', 0, 0, 380, 72)
rect(g, 'Button_Surface', 4, 4, 372, 64, BLUE, 13)
slot = rect(g, 'Button_IconSlot', 19, 18, 36, 36, 'none', 8, '#536b7b', 1.5)
slot.set('data-slot', 'optional-icon')
slot.set('data-guide', 'true')
slot.set('stroke-dasharray', '4 3')
text(g, 'Button_Label', 'ACTION LABEL', 67, 14, 209, 44, 27)
text(g, 'Button_Hint', '[KEY]', 286, 20, 75, 31, 16, family='Fredoka One').set('data-slot', 'optional-hint')
finish()

g = master('panel', '02 / PANEL SHELL', 1, 0, 640, 284)
rect(g, 'Panel_Surface', 4, 4, 632, 276, CREAM, 20)
text(g, 'Panel_Title', 'PANEL TITLE', 26, 17, 530, 47, 31, align='LEFT')
path(g, 'Panel_CloseGlyph', 'M596 25 612 41 M612 25 596 41', weight=4)
path(g, 'Panel_Divider', 'M28 72 H612', stroke='#c4c5ac', weight=2)
finish()

g = master('round-header', '03 / ROUND HEADER', 2, 0, 640, 156)
rect(g, 'RoundHeader_Surface', 4, 4, 632, 148, CREAM, 20)
text(g, 'RoundHeader_Title', 'GAME TITLE', 26, 13, 588, 30, 25)
rect(g, 'RoundHeader_LeftStat', 20, 56, 174, 80, PINK, 13, weight=3)
text(g, 'RoundHeader_LeftCount', '1', 30, 62, 154, 35, 32).set('data-slot', 'left-count')
text(g, 'RoundHeader_LeftLabel', 'LEFT TEAM', 30, 102, 154, 25, 19)
text(g, 'RoundHeader_Time', '3:00', 204, 50, 232, 59, 54)
text(g, 'RoundHeader_Phase', 'ROUND PHASE', 204, 117, 232, 24, 16, family='Fredoka One').set('data-slot', 'phase')
rect(g, 'RoundHeader_RightStat', 446, 56, 174, 80, BLUE, 13, weight=3)
text(g, 'RoundHeader_RightCount', '23', 456, 62, 154, 35, 32).set('data-slot', 'right-count')
text(g, 'RoundHeader_RightLabel', 'RIGHT TEAM', 456, 102, 154, 25, 19)
finish()

g = master('meter', '04 / METER', 0, 1, 380, 80)
text(g, 'Meter_Label', 'METER LABEL', 4, 2, 224, 33, 22, align='LEFT')
text(g, 'Meter_Value', '75%', 266, 2, 110, 33, 22, align='RIGHT')
rect(g, 'Meter_Track', 4, 44, 372, 29, WHITE, 13, weight=3)
rect(g, 'Meter_Fill', 9, 49, 271.5, 19, BLUE, 9, 'none', 0)
finish()

g = master('player-card', '05 / PLAYER CARD', 1, 1, 380, 142)
rect(g, 'PlayerCard_Surface', 4, 4, 372, 134, CREAM, 18)
rect(g, 'PlayerCard_AvatarSlot', 17, 18, 82, 82, '#cceaf8', 17, weight=3)
circle(g, 'PlayerCard_PreviewHead', 58, 45, 14, '#ffffff', weight=2)
path(g, 'PlayerCard_PreviewBody', 'M34 83 C34 56 82 56 82 83 Z', '#ffffff', weight=2)
text(g, 'PlayerCard_Level', 'LEVEL 1', 116, 17, 242, 45, 30, align='LEFT')
text(g, 'PlayerCard_XP', '120 / 200 XP', 118, 66, 236, 31, 20, family='Fredoka One', align='LEFT')
rect(g, 'PlayerCard_XPTrack', 118, 109, 238, 17, WHITE, 8, weight=2).set('data-slot', 'xp-track')
rect(g, 'PlayerCard_XPFill', 122, 113, 138, 9, BLUE, 4, 'none', 0).set('data-slot', 'xp-fill')
finish()

g = master('info-card', '06 / INFO CARD', 2, 1, 380, 118)
rect(g, 'InfoCard_Surface', 4, 4, 372, 110, CREAM, 18)
circle(g, 'InfoCard_IconSlot', 58, 59, 32, GOLD)
text(g, 'InfoCard_IconPlaceholder', 'ICON', 30, 40, 56, 31, 14)
text(g, 'InfoCard_Value', '150', 112, 17, 242, 45, 34, align='LEFT')
text(g, 'InfoCard_Caption', 'CAPTION / VALUE', 114, 66, 240, 31, 18, family='Fredoka One', align='LEFT')
finish()

g = master('item-card', '07 / ITEM CARD', 0, 2, 224, 278)
rect(g, 'ItemCard_Surface', 4, 4, 216, 270, WHITE, 15, weight=3)
text(g, 'ItemCard_Name', 'ITEM NAME', 16, 13, 192, 31, 22)
rect(g, 'ItemCard_3DPreviewSlot', 16, 54, 192, 120, '#e3eff4', 12, '#bad2de', 2)
text(g, 'ItemCard_PreviewLabel', '3D PREVIEW', 26, 95, 172, 37, 22, color=MUTED)
text(g, 'ItemCard_Category', 'CATEGORY', 16, 180, 192, 24, 16, color=MUTED, family='Fredoka One')
text(g, 'ItemCard_Price', '150 COINS', 16, 207, 192, 24, 20)
for name, label, x in [('Action', 'ACTION', 16), ('Try', 'TRY', 116)]:
    slot = rect(g, 'ItemCard_' + name + 'Slot', x, 238, 92, 28, 'none', 5, MUTED, 1)
    slot.set('data-slot', 'button')
    slot.set('data-guide', 'true')
    slot.set('stroke-dasharray', '4 3')
    text(g, 'ItemCard_' + name + 'GuideLabel', label, x + 4, 241, 84, 20, 12, color=MUTED, family='Fredoka One').set('data-guide', 'true')
finish()

g = master('status-text', '08 / STATUS TEXT', 1, 2, 640, 106)
text(g, 'StatusText_Label', 'STATUS TEXT', 4, 4, 632, 96, 63, color=WHITE, outlined=True)
finish()

g = master('icons', '09 / ICON PALETTE', 2, 2, 640, 244)
for i, (stem, label) in enumerate([('sprint-lightning', 'SPRINT'), ('dodge-swoosh', 'DODGE'), ('level-star', 'STAR')]):
    icon = ET.parse(PROJECT / 'BritishBulldogMovement20261003' / (stem + '.svg')).getroot()
    group = el('g', {'id': 'Icon_' + stem, 'transform': f'translate({24 + i * 116} 4)'})
    g.append(group)
    for j, child in enumerate(icon):
        if child.tag.rsplit('}', 1)[-1] in ('style', 'defs', 'title', 'desc'):
            continue
        clone = copy.deepcopy(child)
        for k, node in enumerate(clone.iter()):
            node.set('id', f'Icon_{stem}_{j}_{k}')
            for attr, value in list(node.attrib.items()):
                node.set(attr, value.replace('#18233e', INK).replace('#ffcc36', GOLD).replace('#2aa0ff', BLUE))
        group.append(clone)
    text(g, 'Icon_Label_' + stem, label, 16 + i * 116, 75, 80, 24, 15)
path(g, 'Icon_Heart', 'M410 58 C401 50 378 35 378 20 C378 1 401 0 410 15 C419 0 442 1 442 20 C442 35 419 50 410 58 Z', PINK)
text(g, 'Icon_Label_Heart', 'HEART', 370, 75, 80, 24, 15)
circle(g, 'Icon_Coin', 534, 32, 28, GOLD, weight=4)
circle(g, 'Icon_CoinInner', 534, 32, 17, 'none', weight=2)
path(g, 'Icon_CoinMark', 'M534 21 V43', weight=3)
text(g, 'Icon_Label_Coin', 'COIN', 494, 75, 80, 24, 15)
path(g, 'Icon_Crosshair', 'M44 135 V151 M44 169 V185 M19 160 H35 M53 160 H69', weight=4)
circle(g, 'Icon_CrosshairCenter', 44, 160, 4, WHITE, weight=2)
text(g, 'Icon_Label_Crosshair', 'AIM', 4, 195, 80, 24, 15)
path(g, 'Icon_Bubble', 'M145 135 H217 Q227 135 227 145 V177 Q227 187 217 187 H182 L164 204 V187 H145 Q135 187 135 177 V145 Q135 135 145 135 Z', WHITE, weight=3)
text(g, 'Icon_Label_Bubble', 'BUBBLE', 128, 210, 110, 24, 15)
finish()

g = master('compact-badge', '10 / STATUS BADGE', 0, 3, 500, 112)
rect(g, 'CompactBadge_Surface', 4, 4, 492, 104, GOLD, 18)
text(g, 'CompactBadge_Title', 'STATUS LABEL', 20, 14, 360, 42, 30)
text(g, 'CompactBadge_Support', 'Optional supporting text', 20, 62, 360, 30, 18, family='Fredoka One').set('data-slot', 'optional-support')
rect(g, 'CompactBadge_CountBox', 402, 20, 72, 72, WHITE, 13, weight=3).set('data-slot', 'optional-count')
text(g, 'CompactBadge_Count', '5', 412, 27, 52, 56, 42)
finish()

g = master('scrollbar', '11 / SCROLLBAR', 1, 3, 380, 40)
rect(g, 'Scrollbar_Track', 4, 4, 372, 32, '#dce5e9', 15, weight=2).set('data-slot', 'scroll-track')
rect(g, 'Scrollbar_Thumb', 9, 9, 130, 22, BLUE, 10, weight=2).set('data-slot', 'scroll-thumb')
finish()
text(guides, 'Guide_ScrollbarUse', 'Resize the track; rotate for vertical lists.', 756, 1321, 640, 27, 17, color=MUTED, family='Fredoka One', align='LEFT', record=False)
text(guides, 'Guide_SlotUse', 'Dashed boxes mark optional icon / button placements.', 54, 1400, 2050, 25, 18, color=MUTED, family='Fredoka One', align='LEFT', record=False)

metadata.text = json.dumps({'version': 2, 'components': COMPONENTS,
                            'colors': {'ink': INK, 'cream': CREAM, 'white': WHITE, 'blue': BLUE,
                                       'gold': GOLD, 'pink': PINK, 'mint': MINT}}, separators=(',', ':'))
ET.indent(svg, space='  ')
ROOT.mkdir(parents=True, exist_ok=True)
ET.ElementTree(svg).write(ROOT / 'Playground-UI-Templates.svg', encoding='utf-8', xml_declaration=True)
(ROOT / 'TemplateReuseMap.json').write_text(json.dumps({
    'templateCount': len(COMPONENTS), 'buttonMasterCount': 1,
    'coverageAudit': {'screenGuiCount': 5, 'guiObjectCount': 327,
                      'screens': {'BritishBulldogHUD': 57, 'TagHUD': 28, 'PlaygroundAdminPanel': 54,
                                  'PlaygroundShell': 151, 'MudHUD': 37},
                      'scope': 'Current reusable visual families. Full screens compose these masters; plain container frames and dim overlays use layout and fill settings.'},
    'templates': [{k: v for k, v in c.items() if k != 'texts'} for c in COMPONENTS],
    'principle': 'Change labels, colors and values on reuse. Do not create another design file for each action, game, number, item or state.'
}, indent=2), encoding='utf-8')
print(json.dumps({'svg': str(ROOT / 'Playground-UI-Templates.svg'), 'templates': len(COMPONENTS),
                  'textLayers': sum(len(c['texts']) for c in COMPONENTS), 'fontDirectory': str(FONT_DIR)}))
