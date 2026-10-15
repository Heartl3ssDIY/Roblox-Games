from pathlib import Path
import json,xml.etree.ElementTree as ET
from PIL import ImageFont
ROOT=Path(__file__).resolve().parents[1]
style=ROOT.parent/'PlaygroundClassics-GlossyUI-20261004/Source/BuildGlossy.py'
namespace={'__file__':str(style)}
exec(style.read_text().split('manifest=[];node_map={}')[0],namespace)
Skin=namespace['Skin'];el=namespace['el'];add=namespace['add'];PALETTES=namespace['PALETTES'];PALETTES['bronze']='#c38350'
NS='http://www.w3.org/2000/svg';ET.register_namespace('',NS)
records=[]
def save(root,name,w,h,folder='Figma-DragDrop'):
 path=ROOT/folder/(name+'.svg');ET.ElementTree(root).write(path,encoding='utf-8',xml_declaration=True)
 records.append({'name':name,'svg':folder+'/'+name+'.svg','logicalSize':[w,h],'scale':min(4,2048/max(w,h)),'png':('Resizable/' if folder=='Resizable' else 'PNG/')+name+'.png'})
def skin(name,w,h,col,kind='button',radius=14,folder='Figma-DragDrop'):
 root=el('svg',width=w,height=h,viewBox=f'0 0 {w} {h}');draw=Skin(root);g,_=draw.surface(1,1,w-2,h-2,PALETTES[col],r=radius,pattern=False,facets=False,kind=kind);root.append(g);save(root,name,w,h,folder);return root
skin('board-background',720,1000,'panel','panel',26)
header=skin('header-background',684,128,'blue',radius=22)
skin('player-row',672,67,'panel','panel',13)
for name,col in [('rank-gold','gold'),('rank-silver','silver'),('rank-bronze','bronze'),('rank-fourth-onwards','black')]:skin(name,47,47,col,radius=12)
# Transparent central opening. The border sits above the live avatar viewport.
root=el('svg',width=53,height=53,viewBox='0 0 53 53')
add(root,'rect',x='4',y='4',width='45',height='45',rx='11',fill='none',stroke='#20263d',stroke_width='7')
add(root,'rect',x='4',y='3.2',width='45',height='45',rx='11',fill='none',stroke='#acd9ed',stroke_width='3')
add(root,'path',d='M 8 8 Q 8 5 13 5 H 39',fill='none',stroke='#f0fbff',stroke_width='1.7',stroke_linecap='round')
save(root,'avatar-border',53,53)
for name,col,kind in [('row-resizable','panel','panel'),('board-resizable','panel','panel'),('header-resizable','blue','button')]:skin(name,128,80,col,kind,16,'Resizable')
# Static wording is PNG-only. No live text is placed in the drag-and-drop files.
fontdir=Path(r'C:/Users/sandt/AppData/Local/Roblox/Versions/version-76e1a02649ad4f35/content/fonts')
fontpath=fontdir/'LuckiestGuy-Regular.ttf'
labels=[('HIGHEST LEVEL',42),('ALL TIME · TOP 10',22)]
fonts=[ImageFont.truetype(str(fontpath),size) for _,size in labels]
boxes=[f.getbbox(text,anchor='ls') for f,(text,size) in zip(fonts,labels)]
block=sum(b[3]-b[1] for b in boxes)+9;top=62-block/2
textroot=el('svg',width=584,height=128,viewBox='0 0 584 128')
for (text,size),font,b in zip(labels,fonts,boxes):
 x=292+font.getlength(text)/2-(b[0]+b[2])/2
 t=add(textroot,'text',x=x,y=top-b[1],font_family='Luckiest Guy',font_size=size,text_anchor='middle',fill='#d5f2ff',stroke='#20263d',stroke_width='2.4' if size==42 else '1.3',stroke_linejoin='round',paint_order='stroke fill');t.text=text
 top+=b[3]-b[1]+9
ET.ElementTree(textroot).write(ROOT/'Source/HeaderText-RenderOnly.svg',encoding='utf-8',xml_declaration=True)
records.append({'name':'highest-level-lettering','svg':'Source/HeaderText-RenderOnly.svg','logicalSize':[584,128],'scale':2,'png':'Optional-Fixed-Header/highest-level-lettering.png'})
(ROOT/'Source/AssetManifest.json').write_text(json.dumps(records,indent=2))
(ROOT/'Layout-Notes.json').write_text(json.dumps({'referenceCanvas':[720,1000],'header':{'position':[18,18],'size':[684,128],'iconSuggestedRect':[22,24,76,76],'letteringOverlay':{'position':[100,0],'size':[584,128]}},'repeatedRow':{'size':[672,67],'rowGap':7,'rankRect':[8,10,47,47],'avatarRect':[69,7,53,53],'playerNameArea':[137,8,410,51],'levelArea':[558,8,96,51]},'nineSlice':{'imagePixels':[512,320],'SliceCenter':[88,88,424,232],'SliceScale':0.25}},indent=2))
print(json.dumps({'blankParts':8,'resizableSkins':3,'optionalLettering':1}))
