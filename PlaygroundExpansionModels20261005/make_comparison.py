from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,sys,math
ROOT=Path(__file__).resolve().parent
REF=Path('C:/Users/sandt/Documents/Local Projects/Roblox UI Assets/PlayGround Classics/PlaygroundClassics-ExpansionReferences-20261005/PlaygroundClassics-ExpansionReferences-20261005')
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',17)
titlefont=ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf',25)
category=sys.argv[1]
specs=[s for s in json.loads((REF/'Source/Catalog.json').read_text(encoding='utf-8-sig')) if s['category']==category]
cols=3;cw=424;ch=260
sheet=Image.new('RGB',(cols*cw,math.ceil(len(specs)/cols)*ch+55),(233,240,246))
d=ImageDraw.Draw(sheet);d.text((20,13),category+' / reference and Blender render',font=titlefont,fill=(23,33,60))
for i,s in enumerate(specs):
    x=(i%cols)*cw;y=(i//cols)*ch+55
    d.rounded_rectangle((x+6,y+4,x+cw-7,y+ch-6),radius=15,fill='white',outline=(199,212,228),width=1)
    for n,p in enumerate([REF/s['reference'],ROOT/'Blender'/category/'Previews'/(s['slug']+'.png')]):
        if p.exists():
            im=Image.open(p).convert('RGBA');im.thumbnail((200,212))
            sheet.paste(im,(x+7+n*208+(200-im.width)//2,y+8+(212-im.height)//2),im)
    d.text((x+15,y+225),s['id']+' '+s['name'],font=font,fill=(23,33,60))
dest=ROOT/'Review';dest.mkdir(exist_ok=True)
sheet.save(dest/(category+'-comparison.png'))
print(dest/(category+'-comparison.png'))
