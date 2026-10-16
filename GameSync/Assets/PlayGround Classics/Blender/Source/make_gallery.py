from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,html,csv
ROOT=Path(__file__).resolve().parents[1]
records=[json.loads(p.read_text())for p in ROOT.glob('*/Metadata/*.json')]
records.sort(key=lambda r:r['id'])
font=ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf',18)
small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',13)
for category in sorted({r['category'] for r in records}):
    rows=[r for r in records if r['category']==category]
    w=256;h=298;cols=4
    sheet=Image.new('RGB',(cols*w,((len(rows)+cols-1)//cols)*h),'#dce5ed');draw=ImageDraw.Draw(sheet)
    for i,r in enumerate(rows):
        x=i%cols*w;y=i//cols*h
        im=Image.open(r['preview']).convert('RGBA');im.thumbnail((250,250))
        sheet.paste(im,(x+(w-im.width)//2,y),im)
        draw.text((x+12,y+251),r['id']+' '+r['name'],fill='#17213C',font=font if len(r['name'])<21 else small)
        draw.text((x+12,y+276),str(r['triangles'])+' triangles / '+str(r['parts'])+' editable parts',fill='#445166',font=small)
    sheet.save(ROOT/'Previews'/(category+'-contact-sheet.jpg'),quality=95)

cards=[]
for r in records:
    def rel(p):return html.escape(str(Path(p).relative_to(ROOT)).replace('\\','/'),quote=True)
    cards.append(f'''<article data-category="{r['category']}"><a href="{rel(r['preview'])}"><img loading="lazy" src="{rel(r['preview'])}" alt="{html.escape(r['name'])}"></a><div><small>{r['category']} · {r['id']}</small><h2>{html.escape(r['name'])}</h2><p>{r['parts']} editable parts · {r['triangles']:,} triangles</p><nav><a href="{rel(r['blend'])}">Blender source</a><a href="{rel(r['fbx'])}">FBX export</a></nav></div></article>''')
page='''<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Playground Classics model library</title><style>*{box-sizing:border-box}body{margin:0;background:#e6edf2;color:#17213c;font:16px Arial,sans-serif}header{padding:40px 5vw 24px;background:#17213c;color:#fff7de}h1{margin:0 0 12px;font-size:36px}header p{max-width:830px;line-height:1.6}button{border:1px solid #fff6d1;border-radius:18px;background:transparent;color:#fff6d1;padding:9px 15px;margin:5px 8px 0 0;cursor:pointer}button.active{background:#f2c13d;color:#17213c}main{padding:30px 5vw;display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:22px}article{background:white;border-radius:16px;overflow:hidden;border:2px solid #cbd4df}article img{width:100%;display:block;background:radial-gradient(#f8fbff,#c6d3df)}article div{padding:18px}h2{margin:8px 0;font-size:22px}small{color:#52647b}p{line-height:1.5}article p{font-size:13px;color:#52647b}nav{display:flex;gap:12px}a{color:#006db3;text-decoration:none;font-weight:bold;font-size:14px}footer{padding:20px 5vw 40px;color:#52647b}</style></head><body><header><h1>Playground Classics</h1><p>69 original-reference models. Open the individual Blender sources to edit named parts, materials and bevels. FBX exports have their own packed colour texture. Pets are static models; gameplay, rigging and collision setup are separate steps.</p><div id="filters"><button class="active" data-filter="All">All 69</button>'''
for c in sorted({r['category']for r in records}):page+=f'<button data-filter="{c}">{c} ({sum(r["category"]==c for r in records)})</button>'
page+='</div></header><main>'+''.join(cards)+'''</main><footer>Sources include packed references. Preview lighting is for review; Roblox appearance depends on the experience lighting and material setup.</footer><script>document.querySelectorAll('[data-filter]').forEach(b=>b.onclick=()=>{document.querySelectorAll('[data-filter]').forEach(x=>x.classList.toggle('active',x===b));document.querySelectorAll('article').forEach(c=>c.style.display=b.dataset.filter==='All'||b.dataset.filter===c.dataset.category?'':'none')})</script></body></html>'''
(ROOT/'Model-Gallery.html').write_text(page,encoding='utf-8')
(ROOT/'Asset-Manifest.json').write_text(json.dumps(records,indent=2),encoding='utf-8')
hero=Image.new('RGB',(1260,494),'#e5edf2');draw=ImageDraw.Draw(hero)
for i,ident in enumerate(['B01','P01','C01']):
    row=next(r for r in records if r['id']==ident)
    im=Image.open(row['preview']).convert('RGBA');im.thumbnail((410,410))
    hero.paste(im,(i*420+(420-im.width)//2,6),im)
    draw.text((i*420+24,432),row['name'],fill='#17213c',font=font)
    caption={'B01':'Inset grain + sculpted wrap','P01':'Connected head + shaped paws','C01':'Simple rim + raised dollar'}[ident]
    draw.text((i*420+24,462),caption,fill='#52647b',font=small)
hero.save(ROOT/'Previews'/'Revised-models.jpg',quality=95)
with (ROOT/'Asset-Manifest.csv').open('w',newline='',encoding='utf-8-sig')as f:
    keys=['id','name','category','parts','triangles','meshes','blend','fbx','texture','preview']
    writer=csv.DictWriter(f,fieldnames=keys,extrasaction='ignore');writer.writeheader();writer.writerows(records)
print('GALLERY',len(records))
