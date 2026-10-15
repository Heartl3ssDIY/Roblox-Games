from pathlib import Path
from base64 import b64encode
from io import BytesIO
from PIL import Image
from xml.etree import ElementTree as ET
from math import hypot

ROOT = Path(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\BattlePassConcept20260927')
OUT = ROOT / 'figma-svg-edited'
OUT.mkdir(parents=True, exist_ok=True)
ASSETS = ROOT / 'preview' / 'assets'


def png_data(name):
    im = Image.open(ASSETS / name).convert('RGBA')
    im.thumbnail((240, 240), Image.Resampling.LANCZOS)
    buf = BytesIO()
    im.save(buf, format='PNG', optimize=True)
    return 'data:image/png;base64,' + b64encode(buf.getvalue()).decode('ascii')

coin_data = png_data('reward-coin.png')
diamond_data = png_data('reward-diamond.png')

font = 'Permanent Marker,Arial,sans-serif'
parts = []
append = parts.append
append('''<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="1095" height="729" viewBox="0 0 1095 729" role="img" aria-label="Anime Combat Units Battle Pass edited layout">''')
append('''<title>Anime Combat Units Battle Pass - user edited layout</title>
<defs>
<linearGradient id="boardBase" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#1b1b00"/><stop offset=".42" stop-color="#3b2700"/><stop offset=".77" stop-color="#471508"/><stop offset="1" stop-color="#130600"/></linearGradient>
<radialGradient id="boardFlash" cx=".49" cy=".54" r=".73"><stop stop-color="#f7c71a" stop-opacity=".32"/><stop offset=".56" stop-color="#7c3500" stop-opacity=".08"/><stop offset="1" stop-color="#000" stop-opacity=".45"/></radialGradient>
<linearGradient id="freeBlue" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#577cff"/><stop offset=".5" stop-color="#527fea"/><stop offset="1" stop-color="#004d9b"/></linearGradient>
<linearGradient id="paidPink" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#c57891"/><stop offset=".52" stop-color="#e28bc4"/><stop offset="1" stop-color="#a64287"/></linearGradient>
<linearGradient id="leftBlue" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#507cf7"/><stop offset="1" stop-color="#234377"/></linearGradient>
<linearGradient id="leftPink" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#c95883"/><stop offset="1" stop-color="#b0738b"/></linearGradient>
<linearGradient id="rail" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#9651ec"/><stop offset=".48" stop-color="#551b99"/><stop offset="1" stop-color="#3d126c"/></linearGradient>
<radialGradient id="cardGlow" cx=".45" cy=".38" r=".77"><stop stop-color="#867e24"/><stop offset=".62" stop-color="#43450c"/><stop offset="1" stop-color="#121507"/></radialGradient>
<linearGradient id="xpOrb" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#83d8ff"/><stop offset=".4" stop-color="#348acf"/><stop offset="1" stop-color="#106694"/></linearGradient>
<linearGradient id="price" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#39ee57"/><stop offset="1" stop-color="#058b28"/></linearGradient>
<clipPath id="boardClip"><rect x="67" y="83" width="972" height="580" rx="24"/></clipPath>
<clipPath id="freeClip"><rect x="204" y="279" width="804" height="130" rx="14"/></clipPath>
<clipPath id="paidClip"><rect x="204" y="450" width="804" height="133" rx="14"/></clipPath>
<filter id="innerLight" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="5"/></filter>
</defs>''')

# The entire gray editor canvas is intentionally excluded so the board imports into Figma as usable artwork.
append('<g id="board-frame">')
append('<rect x="60" y="77" width="985" height="593" rx="30" fill="#090900" stroke="#050400" stroke-width="3"/>')
append('<rect x="66" y="82" width="974" height="582" rx="23" fill="url(#boardBase)" stroke="#f5cc20" stroke-width="4"/>')
append('<rect x="72" y="88" width="962" height="570" rx="18" fill="none" stroke="#ffe975" stroke-opacity=".42" stroke-width="1"/>')
append('<g clip-path="url(#boardClip)">')
append('<rect x="66" y="82" width="974" height="582" fill="url(#boardFlash)"/>')
append('<path d="M-10 465L339 148 560 280 904 87 1114 192 1114 433 733 602 406 480 5 654Z" fill="#af2107" opacity=".51"/>')
append('<path d="M17 389L339 129 600 315 1021 99 1110 81 1110 184 754 427 1094 519 1023 632 494 460 121 686Z" fill="#ea8700" opacity=".21"/>')
# Draw all speed lines as independent vector shapes, editable in Figma.
center = (553, 357)
edge_points = [(70,91),(110,87),(170,86),(255,84),(335,84),(430,83),(535,82),(630,82),(745,82),(840,82),(945,84),(1038,105),
               (1038,170),(1038,245),(1038,320),(1038,390),(1038,472),(1038,560),(1038,650),(950,664),(850,663),(745,663),(635,663),
               (520,663),(415,663),(310,663),(200,663),(75,640),(66,560),(66,470),(66,390),(66,300),(66,220),(66,150)]
for idx,(ex,ey) in enumerate(edge_points):
    dx,dy=ex-center[0],ey-center[1]
    length=max(1,hypot(dx,dy))
    ox,oy=-dy/length,dx/length
    width=4+(idx*7)%17
    x2,y2=center[0]+dx*.18,center[1]+dy*.18
    fill=['#ffe238','#bb8b00','#493500','#f7d32f','#0e0c00'][idx%5]
    opacity=[.24,.27,.43,.16,.5][idx%5]
    append(f'<path id="speed-line-{idx+1}" d="M{ex-width*ox:.1f} {ey-width*oy:.1f}L{ex+width*ox:.1f} {ey+width*oy:.1f}L{x2:.1f} {y2:.1f}Z" fill="{fill}" opacity="{opacity}"/>')
append('</g></g>')

append('<g id="close-button"><rect x="989" y="89" width="40" height="38" rx="12" fill="#bd1717" stroke="#360800" stroke-width="4"/><path d="M1004 100l12 14m0-14l-12 14" stroke="#050608" stroke-width="7" stroke-linecap="round"/><path d="M1004 100l12 14m0-14l-12 14" stroke="#fff" stroke-width="3.2" stroke-linecap="round"/></g>')

# Header: arranged from the user's Figma screenshot, with title and progress separate and editable.
append('<g id="battle-pass-header"><rect x="93" y="132" width="915" height="84" rx="14" fill="#261446" stroke="#100a1c" stroke-width="7"/><rect x="95" y="134" width="911" height="79" rx="13" fill="none" stroke="#ffd428" stroke-width="6"/>')
append('<text id="season-one" x="108" y="156" fill="#e9d7ff" font-family="Arial,sans-serif" font-size="14" font-weight="800">SEASON ONE</text>')
append(f'<text id="battle-pass-title" x="105" y="192" fill="#fffefa" stroke="#080609" stroke-width="5" paint-order="stroke fill" font-family="{font}" font-size="35" font-weight="900" transform="skewX(-4)">BATTLE PASS</text>')
append(f'<text id="level-label" x="641" y="153" fill="#fff" stroke="#150b1f" stroke-width="2" paint-order="stroke fill" font-family="{font}" font-size="11">LEVEL</text>')
append('<text id="pass-xp-label" x="865" y="153" fill="#a9dcff" font-family="Arial,sans-serif" font-size="10" font-weight="800">PASS XP</text>')
append('<rect x="654" y="162" width="264" height="21" rx="10.5" fill="#111323" stroke="#171323" stroke-width="3"/><rect x="660" y="167" width="254" height="12" rx="6" fill="#333240"/>')
append('<circle id="level-orb-shadow" cx="654" cy="174" r="14" fill="#050e18" opacity=".55"/><circle id="level-orb" cx="654" cy="174" r="12" fill="url(#xpOrb)" stroke="#2fcbf8" stroke-width="2"/>')
append('</g>')

append('<g id="reward-track-banner"><rect x="93" y="223" width="915" height="47" rx="14" fill="#2a1247" stroke="#ffd829" stroke-width="3"/>')
append(f'<text id="reward-track-title" x="107" y="255" fill="#fff" stroke="#07050b" stroke-width="4" paint-order="stroke fill" font-family="{font}" font-size="19">REWARD TRACK</text></g>')

# Free lane, with individual small sparkle vectors.
append('<g id="free-reward-lane"><rect x="94" y="280" width="914" height="129" rx="15" fill="url(#freeBlue)" stroke="#f7da29" stroke-width="3"/>')
append('<g clip-path="url(#freeClip)">')
for row in range(7):
    y=286+row*20
    for col in range(43):
        x=210+col*19+(row%2)*9
        if x>1006: continue
        size=2.9+((row+col)%4)*.24
        opacity=.27+((row*3+col)%6)*.073
        append(f'<path id="free-star-{row+1}-{col+1}" d="M{x:.1f} {y-size*2:.1f}Q{x+size*.38:.1f} {y-size*.36:.1f} {x+size*2:.1f} {y:.1f}Q{x+size*.38:.1f} {y+size*.36:.1f} {x:.1f} {y+size*2:.1f}Q{x-size*.38:.1f} {y+size*.36:.1f} {x-size*2:.1f} {y:.1f}Q{x-size*.38:.1f} {y-size*.36:.1f} {x:.1f} {y-size*2:.1f}Z" fill="#e8e8ff" opacity="{opacity:.2f}"/>')
append('</g>')
append('<rect x="94" y="280" width="108" height="129" rx="13" fill="url(#leftBlue)" stroke="#ffe13a" stroke-width="3"/>')
append('<text x="148" y="327" fill="#fff1aa" font-family="Arial,sans-serif" font-size="24" text-anchor="middle">✦</text>')
append(f'<text id="free-lane-label" x="148" y="352" fill="#fff" stroke="#08050c" stroke-width="3" paint-order="stroke fill" font-family="{font}" font-size="16" text-anchor="middle">FREE</text>')
append('</g>')

# Level divider and visible first six tick marks.
append('<g id="level-rail"><rect x="94" y="414" width="914" height="35" rx="13" fill="url(#rail)" stroke="#ffd72f" stroke-width="3"/>')
append('<path d="M204 430H1008" stroke="#190b39" stroke-width="8"/><path d="M204 428H1008" stroke="#e0afea" stroke-width="3"/><rect x="94" y="414" width="108" height="35" rx="13" fill="#44127d" stroke="#ffe637" stroke-width="3"/>')
append(f'<text id="level-rail-label" x="148" y="438" fill="#fff" stroke="#0e0615" stroke-width="3" paint-order="stroke fill" font-family="{font}" font-size="15" text-anchor="middle">LEVEL</text>')
for n,x in enumerate([274,406,538,671,803,935],1):
    append(f'<g id="level-node-{n}"><circle cx="{x}" cy="431" r="17" fill="#20102f" stroke="#ffd632" stroke-width="2"/><circle cx="{x}" cy="431" r="13" fill="#6d28a5" stroke="#b870d5" stroke-width="2"/><text x="{x}" y="437" fill="#fff" stroke="#200a2c" stroke-width="1" paint-order="stroke fill" font-family="Arial,sans-serif" font-size="16" font-weight="800" text-anchor="middle">{n}</text></g>')
append('</g>')

# Pink lane uses individually editable halftone dots concentrated across the center.
append('<g id="paid-reward-lane"><rect x="94" y="450" width="914" height="132" rx="15" fill="url(#paidPink)" stroke="#f7d82a" stroke-width="3"/>')
append('<g clip-path="url(#paidClip)">')
for row in range(14):
    y=452+row*9.6
    for col in range(78):
        x=206+col*10.4+(row%2)*4
        if x>1004: continue
        radial=hypot((x-540)/390,(y-515)/95)
        r=max(.48,3.1-radial*1.1)+((col*3+row)%4)*.08
        opacity=max(.11,.81-radial*.33)
        append(f'<circle id="paid-dot-{row+1}-{col+1}" cx="{x:.1f}" cy="{y:.1f}" r="{r:.2f}" fill="#fff0f9" opacity="{opacity:.2f}"/>')
append('</g>')
append('<rect x="94" y="450" width="108" height="132" rx="13" fill="url(#leftPink)" stroke="#ffe13a" stroke-width="3"/>')
append('<text x="148" y="494" fill="#fff0a7" font-family="Arial,sans-serif" font-size="24" text-anchor="middle">✦</text>')
append(f'<text id="paid-lane-label" x="148" y="520" fill="#fff" stroke="#140715" stroke-width="3" paint-order="stroke fill" font-family="{font}" font-size="16" text-anchor="middle">PAID</text>')
append('<g id="paid-price"><rect x="108" y="543" width="78" height="24" rx="9" fill="url(#price)" stroke="#09481d" stroke-width="2"/><path d="M118 547h22l4 4v11h-26z" fill="#0d6b33" stroke="#032911" stroke-width="1"/><path d="M124 550h10v10h-10z" fill="none" stroke="#86ff9c" stroke-width="2"/><text x="163" y="559" fill="#fff" stroke="#030706" stroke-width="2.5" paint-order="stroke fill" font-family="Arial,sans-serif" font-size="14" font-weight="900" text-anchor="middle">1499</text></g></g>')

# Coin and diamond card art. All card geometry and labels remain editable; only currency illustrations are image layers.
def reward_card(id_prefix, y, image_uri, label):
    append(f'<g id="{id_prefix}-reward-card">')
    append(f'<rect x="211" y="{y}" width="124" height="112" rx="15" fill="#fff3a0" stroke="#514400" stroke-width="3"/>')
    append(f'<rect x="215" y="{y+4}" width="116" height="104" rx="12" fill="url(#cardGlow)" stroke="#ffdd13" stroke-width="3"/>')
    append(f'<path d="M219 {y+15}l103 89M218 {y+45}l76 61M240 {y+7}l81 71M218 {y+79}l35 29" stroke="#e5ce4b" stroke-opacity=".16" stroke-width="6"/>')
    append(f'<image id="{id_prefix}-currency-art" x="242" y="{y+8}" width="65" height="65" preserveAspectRatio="xMidYMid meet" xlink:href="{image_uri}"/>')
    append(f'<text id="{id_prefix}-reward-label" x="273" y="{y+85}" fill="#fff" stroke="#080609" stroke-width="2.5" paint-order="stroke fill" font-family="{font}" font-size="11" text-anchor="middle">{label}</text>')
    append(f'<rect x="233" y="{y+93}" width="82" height="14" rx="7" fill="#24125c" stroke="#ffe10f" stroke-width="2"/>')
    append(f'<text id="{id_prefix}-lock-label" x="274" y="{y+103}" fill="#fff" font-family="Arial,sans-serif" font-size="7.4" font-weight="900" text-anchor="middle">LOCKED</text>')
    append('</g>')
reward_card('free-first', 288, coin_data, 'COINS')
reward_card('paid-first', 460, diamond_data, 'DIAMONDS')

append('<g id="footer"><rect x="93" y="588" width="916" height="31" rx="15" fill="#1c1032" stroke="#f8dc2e" stroke-width="1.5"/><text id="footer-pass-rule" x="108" y="607" fill="#ffe239" font-family="Arial,sans-serif" font-size="9" font-weight="800">45 LEVELS ✦ 15 PASS XP EACH</text></g>')
append('</svg>')
main='\n'.join(parts)
font_data=b64encode((ASSETS/'PermanentMarker.ttf').read_bytes()).decode('ascii')
font_style="<style>@font-face{font-family:'Permanent Marker';src:url('data:font/ttf;base64,"+font_data+"') format('truetype')}</style>"
main=main.replace('<defs>', '<defs>'+font_style, 1)
(OUT/'battle-pass-edited.svg').write_text(main, encoding='utf-8')

# Component exports use editable SVG shapes and can be pulled apart in Figma.
start='''<svg xmlns="http://www.w3.org/2000/svg" width="985" height="593" viewBox="60 77 985 593"><defs><linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#222000"/><stop offset=".55" stop-color="#9f3d04"/><stop offset="1" stop-color="#120800"/></linearGradient></defs>'''
board_defs=parts[1].split('<defs>',1)[1].split('</defs>',1)[0]
board_start=next(i for i,p in enumerate(parts) if p=='<g id="board-frame">')
board_end=next(i for i,p in enumerate(parts) if p=='</g></g>')
board='<svg xmlns="http://www.w3.org/2000/svg" width="985" height="593" viewBox="60 77 985 593"><defs>'+board_defs+'</defs>'+''.join(parts[board_start:board_end+1])+'</svg>'
(OUT/'background-frame.svg').write_text(board,encoding='utf-8')

stars=['<svg xmlns="http://www.w3.org/2000/svg" width="804" height="130" viewBox="204 279 804 130"><defs><linearGradient id="blue" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#577cff"/><stop offset="1" stop-color="#004d9b"/></linearGradient></defs><rect x="204" y="279" width="804" height="130" rx="14" fill="url(#blue)"/>']
stars += [p for p in parts if 'free-star-' in p]
stars += ['</svg>']
(OUT/'free-lane-pattern.svg').write_text('\n'.join(stars), encoding='utf-8')

halftone=['<svg xmlns="http://www.w3.org/2000/svg" width="804" height="133" viewBox="204 450 804 133"><defs><linearGradient id="pink" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#c57891"/><stop offset="1" stop-color="#a64287"/></linearGradient></defs><rect x="204" y="450" width="804" height="133" rx="14" fill="url(#pink)"/>']
halftone += [p for p in parts if 'paid-dot-' in p]
halftone += ['</svg>']
(OUT/'paid-lane-pattern.svg').write_text('\n'.join(halftone), encoding='utf-8')

reward='''<svg xmlns="http://www.w3.org/2000/svg" width="124" height="112" viewBox="0 0 124 112"><defs><radialGradient id="card" cx=".45" cy=".38" r=".77"><stop stop-color="#867e24"/><stop offset=".62" stop-color="#43450c"/><stop offset="1" stop-color="#121507"/></radialGradient></defs><g id="editable-reward-slot"><rect x="0" y="0" width="124" height="112" rx="15" fill="#fff3a0" stroke="#514400" stroke-width="3"/><rect x="4" y="4" width="116" height="104" rx="12" fill="url(#card)" stroke="#ffdd13" stroke-width="3"/><rect id="art-placeholder" x="29" y="11" width="66" height="62" rx="5" fill="none" stroke="#ffdb70" stroke-opacity=".35" stroke-dasharray="3 3"/><text x="62" y="85" fill="#fff" stroke="#080609" stroke-width="2.5" paint-order="stroke fill" font-family="Permanent Marker,Arial,sans-serif" font-size="11" text-anchor="middle">REWARD</text><rect x="22" y="93" width="82" height="14" rx="7" fill="#24125c" stroke="#ffe10f" stroke-width="2"/><text x="63" y="103" fill="#fff" font-family="Arial,sans-serif" font-size="7.4" font-weight="900" text-anchor="middle">LOCKED</text></g></svg>'''
reward=reward.replace('<defs>', '<defs>'+font_style, 1)
(OUT/'reward-card-edited.svg').write_text(reward,encoding='utf-8')
(OUT/'PermanentMarker.ttf').write_bytes((ASSETS/'PermanentMarker.ttf').read_bytes())

for name in ['battle-pass-edited.svg','background-frame.svg','free-lane-pattern.svg','paid-lane-pattern.svg','reward-card-edited.svg']:
    ET.parse(OUT/name)
    print(name, (OUT/name).stat().st_size)
