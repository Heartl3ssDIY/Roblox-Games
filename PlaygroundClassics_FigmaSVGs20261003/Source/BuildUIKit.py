import json,copy,re,math,hashlib
from pathlib import Path
import xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1]
NS='http://www.w3.org/2000/svg'
ET.register_namespace('',NS)
def el(tag,attrs=None,text=None):
 e=ET.Element('{'+NS+'}'+tag,attrs or {})
 if text is not None:e.text=text
 return e
def local(tag):return tag.rsplit('}',1)[-1]
def number(value):return ('%.3f'%value).rstrip('0').rstrip('.') or '0'
ITEMS=[
 ('British Bulldog timer','Panels/BritishBulldogHUD/TopCard.svg'),
 ('British Bulldog movement','Panels/BritishBulldogHUD/MovementControls.svg'),
 ('Leave safe zone','Panels/BritishBulldogHUD/Departure.svg'),
 ('Tagged notice','Panels/BritishBulldogHUD/Tagged.svg'),
 ('British Bulldog results','Panels/BritishBulldogHUD/Results.svg'),
 ('Tag timer','Panels/TagHUD/Top.svg'),
 ('Tag sprint','Panels/TagHUD/SprintPanel.svg'),
 ('Vault and dodge','Panels/TagHUD/Controls.svg'),
 ('Tag results','Panels/TagHUD/Results.svg'),
 ('Mud timer and teams','Panels/MudHUD/Top.svg'),
 ('Mud guns and sprint','Panels/MudHUD/Controls.svg'),
 ('Stuck and rescue meter','Panels/MudHUD/Frozen.svg'),
 ('Mud results','Panels/MudHUD/Results.svg'),
 ('Team colour picker','Panels/MudHUD/ColourPicker.svg'),
 ('Lobby wallet','Panels/PlaygroundShell/Wallet.svg'),
 ('Shop and action dock','Panels/PlaygroundShell/Dock.svg'),
 ('Level and XP','Panels/PlaygroundShell/LevelPanel.svg'),
 ('Compact level and XP','Panels/PlaygroundShell/CompactLevelPanel.svg'),
 ('Three-game voting','Panels/PlaygroundShell/VotePanel.svg'),
 ('Compact voting','Panels/PlaygroundShell/CompactVotePanel.svg'),
 ('Shop - all 12 cards','Panels/PlaygroundShell/Shop_CompleteExpanded.svg'),
 ('Editable shop item template','Templates/Shop_ItemCard.svg'),
 ('Admin - all three games','Panels/PlaygroundAdminPanel/Panel_AllGamesExpanded.svg'),
 ('Compact admin - all games','Panels/PlaygroundAdminPanel/CompactPanel_AllGamesExpanded.svg'),
 ('Overhead tagged','WorldUI/Overhead-Tagged.svg'),
 ('Overhead tagger','WorldUI/Overhead-Youre-It.svg'),
 ('Overhead stuck','WorldUI/Overhead-Stuck.svg'),
 ('Star emoji bubble','WorldUI/Emoji-Bubble-Star.svg'),
 ('Heart emoji bubble','WorldUI/Emoji-Bubble-Heart.svg'),
 ('Round reward toast','Panels/PlaygroundShell/RewardToast.svg')
]
for _,f in ITEMS:assert (ROOT/f).is_file(),f
COLS=5;W=610;H=475;GAP=26;MARGIN=34;HEADER=122
WIDTH=COLS*(W+GAP)+MARGIN*2-GAP
HEIGHT=math.ceil(len(ITEMS)/COLS)*(H+GAP)+HEADER+MARGIN-GAP
svg=el('svg',{'width':str(WIDTH),'height':str(HEIGHT),'viewBox':'0 0 '+str(WIDTH)+' '+str(HEIGHT)})
svg.append(el('title',text='Playground Classics UI kit overview'))
svg.append(el('desc',text='Editable vector board containing major UI panels. Complete screens, every control and all alternate states are separate SVGs in this package.'))
metadata=el('metadata',{'id':'playground-text-layers'});svg.append(metadata)
svg.append(el('rect',{'id':'Kit_Background','width':str(WIDTH),'height':str(HEIGHT),'fill':'#e8eef3'}))
texts=[]
def heading(id,value,x,y,w,h,size,color,family='Fredoka One'):
 svg.append(el('text',{'id':id,'x':number(x),'y':number(y+size),'font-family':family,'font-size':str(size),'fill':color},value))
 texts.append({'name':id,'text':value,'x':x,'y':y,'width':w,'height':h,'fontFamily':family,'fontSize':size,'color':color,'opacity':1,'strokeColor':color,'strokeWidth':0,'strokeOpacity':0,'align':'LEFT','clips':[],'rotation':0,'rotationCenter':[x+w/2,y+h/2]})
heading('Kit_Title','PLAYGROUND CLASSICS - EDITABLE UI',MARGIN,22,WIDTH-2*MARGIN,48,40,'#18233e','Luckiest Guy')
heading('Kit_Subtitle','Major panels below. Screens, state variants, controls and all 12 shop cards are separate SVGs.',MARGIN,77,WIDTH-2*MARGIN,28,21,'#40516c','Arimo')
for index,(title,file) in enumerate(ITEMS):
 left=MARGIN+(index%COLS)*(W+GAP);top=HEADER+(index//COLS)*(H+GAP)
 tile=el('g',{'id':'Kit_Item_'+str(index+1)})
 tile.append(el('rect',{'x':str(left),'y':str(top),'width':str(W),'height':str(H),'rx':'16','fill':'#ffffff','stroke':'#cbd5e1','stroke-width':'2'}))
 svg.append(tile)
 heading('Kit_Label_'+str(index+1),title,left+18,top+10,W-36,32,21,'#18233e')
 source=ET.parse(ROOT/file).getroot()
 box=[float(v) for v in source.get('viewBox').split()]
 scale=min((W-38)/box[2],(H-65)/box[3],1.55)
 ox=left+(W-box[2]*scale)/2;oy=top+50+(H-65-box[3]*scale)/2
 transform=el('g',{'id':'Kit_Artwork_'+str(index+1),'transform':'translate('+number(ox)+' '+number(oy)+') scale('+number(scale)+') translate('+number(-box[0])+' '+number(-box[1])+')'})
 tile.append(transform)
 prefix='kit_'+str(index+1)+'_'
 ids={n.get('id'):prefix+n.get('id') for n in source.iter() if n.get('id')}
 for node in source.iter():
  if node.get('id'):node.set('id',ids[node.get('id')])
  for attr,value in list(node.attrib.items()):
   node.set(attr,re.sub(r'url\(#([^)]+)\)',lambda m:'url(#'+ids.get(m.group(1),m.group(1))+')',value))
   if attr.endswith('href') and value.startswith('#'):node.set(attr,'#'+ids.get(value[1:],value[1:]))
 for child in source:
  if local(child.tag) not in ('metadata','title','desc'):transform.append(copy.deepcopy(child))
 record_node=next((n for n in source if local(n.tag)=='metadata' and n.get('id')==prefix+'playground-text-layers'),None)
 if record_node is not None:
  records=json.loads(record_node.text)['texts']
  for record in records:
   record=copy.deepcopy(record)
   record['name']='Kit/'+title+'/'+record['name']
   record['x']=ox+record['x']*scale
   record['y']=oy+record['y']*scale
   for k in ('width','height','fontSize','strokeWidth'):record[k]*=scale
   for clip in record.get('clips',[]):
    clip['name']='Kit/'+title+'/'+clip['name'];clip['x']=ox+clip['x']*scale;clip['y']=oy+clip['y']*scale
    for k in ('width','height','radius'):clip[k]*=scale
   if record.get('rotationCenter'):record['rotationCenter']=[ox+record['rotationCenter'][0]*scale,oy+record['rotationCenter'][1]*scale]
   texts.append(record)
 else:assert False,'Text metadata missing for '+file
metadata.text=json.dumps({'version':1,'texts':texts},ensure_ascii=False,separators=(',',':'))
path=ROOT/'UI-Kit-Overview.svg'
ET.ElementTree(svg).write(path,encoding='utf-8',xml_declaration=True)
(ROOT/'Source/UIKitManifest.json').write_text(json.dumps({'file':path.name,'panels':len(ITEMS),'textLayers':len(texts),'width':WIDTH,'height':HEIGHT,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'items':ITEMS},indent=2),encoding='utf-8')
print(json.dumps({'file':path.name,'panels':len(ITEMS),'textLayers':len(texts),'width':WIDTH,'height':HEIGHT}))

