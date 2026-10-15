from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent
INK = '#18233e'
PAPER = '#fffae2'
BLUE = '#2aa0ff'
RED = '#ff515c'
YELLOW = '#ffcc36'

def svg(width, height, body):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
<style>.heading{{font-family:'Luckiest Guy','Fredoka One',Impact,'Comic Sans MS',sans-serif;font-weight:400;fill:{INK}}}.body{{font-family:'Fredoka One','Comic Sans MS',Arial,sans-serif;font-weight:400;fill:{INK}}}</style>
{body}
</svg>'''

def lightning(x=0, y=0, scale=1):
    return f'<g transform="translate({x} {y}) scale({scale})"><path d="M36 5 12 34h17l-5 25 29-35H35z" fill="{YELLOW}" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/></g>'

def swoosh(x=0, y=0, scale=1):
    return f'<g transform="translate({x} {y}) scale({scale})"><path d="M8 40c13-21 25-24 43-13l-5-15 14 19-22 8 8-11c-12-6-22-2-33 13" fill="{BLUE}" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/><path d="m7 48 16-6M5 56l20-6" fill="none" stroke="{INK}" stroke-width="4" stroke-linecap="round"/></g>'

def star(x=0, y=0, scale=1):
    return f'<g transform="translate({x} {y}) scale({scale})"><path d="m32 5 8 17 19 3-14 13 4 20-17-10-17 10 4-20L5 25l19-3z" fill="{YELLOW}" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/></g>'

files = {
    'sprint-lightning.svg': svg(64, 64, lightning()),
    'dodge-swoosh.svg': svg(64, 64, swoosh()),
    'level-star.svg': svg(64, 64, star()),
    'Sprint.svg': svg(390, 120, f'''<g transform="translate(7 6)">
<rect width="375" height="48" rx="13" fill="{PAPER}" stroke="{INK}" stroke-width="4"/>
<text x="12" y="23" class="heading" font-size="20">RUNNER</text>
<text x="363" y="21" class="body" font-size="15" text-anchor="end">10.0s / 10s</text>
<rect x="12" y="29" width="351" height="10" rx="5" fill="#d3d9d8" stroke="{INK}" stroke-width="2"/>
<rect x="12" y="29" width="351" height="10" rx="5" fill="{BLUE}"/>
<rect y="60" width="195" height="40" rx="12" fill="{BLUE}" stroke="{INK}" stroke-width="3"/>
{lightning(6, 66, .40)}
<text x="115" y="79" class="heading" font-size="18" text-anchor="middle">SPRINT</text>
<text x="115" y="95" class="heading" font-size="14" text-anchor="middle">HOLD SHIFT</text>
</g>'''),
    'Dodge.svg': svg(110, 58, f'''<g transform="translate(7 7)"><rect width="94" height="40" rx="12" fill="{YELLOW}" stroke="{INK}" stroke-width="3"/>
{swoosh(5, 6, .4)}
<text x="60" y="18" class="heading" font-size="15" text-anchor="middle">DODGE</text>
<text x="60" y="33" class="heading" font-size="13" text-anchor="middle">[E]</text></g>'''),
    'Level.svg': svg(278, 94, f'''<g transform="translate(7 7)"><rect width="264" height="80" rx="16" fill="{PAPER}" stroke="{INK}" stroke-width="4"/>
<rect x="9" y="10" width="60" height="60" rx="11" fill="#c2e9f3" stroke="{INK}" stroke-width="2"/>
<g id="EditableAvatarPlaceholder"><rect x="20" y="22" width="38" height="35" rx="12" fill="#ffd591" stroke="{INK}" stroke-width="2"/>
<circle cx="30" cy="37" r="2.4" fill="{INK}"/><circle cx="47" cy="37" r="2.4" fill="{INK}"/><path d="M31 46q8 7 15 0" fill="none" stroke="{INK}" stroke-width="2.4" stroke-linecap="round"/></g>
{star(80, 10, .328125)}
<text x="105" y="30" class="heading" font-size="25">LEVEL 1</text>
<text x="82" y="50" class="body" font-size="15">0 / 100 XP</text>
<rect x="82" y="59" width="169" height="10" rx="5" fill="#d3d9d8" stroke="{INK}" stroke-width="2"/>
</g>'''),
    'TopHUD.svg': svg(614, 134, f'''<g transform="translate(7 7)"><rect width="600" height="120" rx="20" fill="{PAPER}" stroke="{INK}" stroke-width="5"/>
<text x="300" y="27" class="heading" font-size="22" text-anchor="middle">BRITISH BULLDOG</text>
<rect x="15" y="42" width="180" height="58" rx="12" fill="{RED}" stroke="{INK}" stroke-width="3"/>
<rect x="405" y="42" width="180" height="58" rx="12" fill="{BLUE}" stroke="{INK}" stroke-width="3"/>
<text x="105" y="70" class="heading" font-size="30" text-anchor="middle" style="fill:#fff">1</text>
<text x="105" y="91" class="heading" font-size="19" text-anchor="middle">BULLDOGS</text>
<text x="495" y="70" class="heading" font-size="30" text-anchor="middle" style="fill:#fff">23</text>
<text x="495" y="91" class="heading" font-size="19" text-anchor="middle">RUNNERS</text>
<text x="300" y="81" class="heading" font-size="51" text-anchor="middle">3:00</text>
<text x="300" y="109" class="body" font-size="15" text-anchor="middle">CROSSING</text></g>'''),
}

for name, content in files.items():
    ET.fromstring(content)
    (ROOT / name).write_text(content, encoding='utf-8')
print(f'Wrote {len(files)} editable SVG exports to {ROOT}')
