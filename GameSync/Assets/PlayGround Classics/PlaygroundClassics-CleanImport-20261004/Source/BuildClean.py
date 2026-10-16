import json, copy, re, hashlib, shutil
from pathlib import Path
import xml.etree.ElementTree as E
ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT.parent/'PlaygroundClassics-GlossyUI-20261004'
ORIGINAL=ROOT.parent/'PlaygroundClassics-Editable-UI-SVGs/PlaygroundClassics_FigmaSVGs20261003'
NS='http://www.w3.org/2000/svg';E.register_namespace('',NS)
def tag(t):return '{'+NS+'}'+t
def element(t,**attrs):return E.Element(tag(t),{k.replace('_','-'):str(v) for k,v in attrs.items()})
manifest=[];mapping=[];seen={}

def save(root,rel,category):
 path=ROOT/'Editable'/rel;path.parent.mkdir(parents=True,exist_ok=True);E.ElementTree(root).write(path,encoding='utf-8',xml_declaration=True)
 w,h=[float(v) for v in root.get('viewBox').split()[2:]]
 manifest.append({'svg':'Editable/'+rel,'png':'PNG/'+rel.replace('.svg','.png'),'logicalSize':[w,h],'scale':min(4,2048/max(w,h)),'category':category})

def extract(root,shape,name,category,sourcefile):
 rect=next(shape.iter(tag('rect'))) if shape.tag!=tag('rect') else shape
 x,y,w,h=[float(rect.get(a,'0')) for a in ['x','y','width','height']]
 if w<=0 or h<=0:return
 palette=shape.get('data-skin-theme',shape.get('fill','neutral'))
 signature=(category,round(w,2),round(h,2),rect.get('rx'),palette,any('EditableHalftone' in n.get('id','') for n in shape.iter()),any('DiagonalShade' in n.get('id','') for n in shape.iter()))
 if signature in seen:
  mapping.append({'source':sourcefile,'node':shape.get('id'),'asset':seen[signature]});return
 rel=category+'/'+name+'.svg';seen[signature]=rel
 new=element('svg',width=w+4,height=h+4,viewBox=f'0 0 {w+4} {h+4}')
 title=element('title');title.text=name;new.append(title)
 desc=element('desc');desc.text='Isolated empty UI artwork. No captions, counters, placeholder images or item contents.';new.append(desc)
 defs=element('defs');new.append(defs)
 ids={n.get('id'):n for n in root.iter() if n.get('id')};copied=set()
 def references(node):
  for n in node.iter():
   for value in n.attrib.values():
    for key in re.findall(r'url\(#([^)]*)\)',value):
     if key not in copied:
      copied.add(key);ref=copy.deepcopy(ids[key]);defs.append(ref);references(ref)
 references(shape)
 wrapper=element('g',transform=f'translate({2-x} {2-y})');wrapper.append(copy.deepcopy(shape));new.append(wrapper)
 assert not list(new.iter(tag('text'))) and not list(new.iter(tag('image')))
 save(new,rel,category);mapping.append({'source':sourcefile,'node':shape.get('id'),'asset':rel})

# Prioritise familiar, useful names; export only the backplate itself.
priority=[
 ('Panels/PlaygroundShell/LevelPanel.svg','StarterGui.PlaygroundShell.LevelPanel','level-panel','01-Empty-Panels'),
 ('Panels/PlaygroundShell/CompactLevelPanel.svg','StarterGui.PlaygroundShell.CompactLevelPanel','level-panel-compact','01-Empty-Panels'),
 ('Panels/PlaygroundShell/Wallet.svg','StarterGui.PlaygroundShell.Wallet','wallet-panel','01-Empty-Panels'),
 ('Panels/PlaygroundShell/ShopPanel.svg','StarterGui.PlaygroundShell.ShopPanel','shop-background','01-Empty-Panels'),
 ('Templates/Shop_ItemCard.svg','StarterGui.PlaygroundShell.Templates.ItemCard','item-frame','02-Item-Frame-Parts'),
 ('Templates/Shop_ItemCard.svg','StarterGui.PlaygroundShell.Templates.ItemCard.Preview','item-preview-background','02-Item-Frame-Parts'),
 ('Templates/Shop_ItemCard.svg','StarterGui.PlaygroundShell.Templates.ItemCard.Action','item-action-button','02-Item-Frame-Parts'),
 ('Panels/BritishBulldogHUD/MovementControls.svg','StarterGui.BritishBulldogHUD.MovementControls.Meter','runner-meter-background','01-Empty-Panels')]
for file,node,name,category in priority:
 root=E.parse(SRC/'Editable'/file).getroot();shape=next(n for n in root.iter(tag('g')) if n.get('id')==node+'_Background-Glossy');extract(root,shape,name,category,file)

original_manifest=json.loads((ORIGINAL/'SVGManifest.json').read_text())
for entry in original_manifest['files']:
 file=entry['file']
 if not file.startswith(('Panels/','Controls/')) or any(s in file for s in ['All12Items','CompleteExpanded','AllGamesExpanded']):continue
 root=E.parse(SRC/'Editable'/file).getroot()
 for node in entry['roots']:
  if '.Cards.' in node or '.FacePreview' in node:continue
  shape=next((n for n in root.iter(tag('g')) if n.get('id')==node+'_Background-Glossy'),None)
  if shape is None:continue
  category='03-Other-Blank-Buttons' if file.startswith('Controls/') else '01-Empty-Panels'
  name=file.split('/')[1]+'-'+Path(file).stem
  extract(root,shape,name,category,file)

# Meter layers are separate full-width assets, never a baked sample amount.
for file,prefix,base in [('Panels/PlaygroundShell/LevelPanel.svg','StarterGui.PlaygroundShell.LevelPanel.XPTrack','xp'),('Panels/BritishBulldogHUD/MovementControls.svg','StarterGui.BritishBulldogHUD.MovementControls.Meter.Track','stamina')]:
 root=E.parse(SRC/'Editable'/file).getroot()
 for suffix,label in [('_Background','track'),('.Fill_Background','fill')]:
  shape=next(n for n in root.iter(tag('rect')) if n.get('id')==prefix+suffix)
  extract(root,shape,base+'-'+label,'04-Meter-Parts',file)

for source_dir,dest,category in [
 ('StarterControls/Blanks','05-Favourite-Buttons-Blank','BlankFavourites'),
 ('StarterControls/Labelled','Optional-Labelled-Buttons','OptionalLabels'),
 ('GameCards/Blanks','06-Smooth-Game-Card-Blanks','BlankGameCards'),
 ('Reusable/NineSlice','07-Resizable-Skins','NineSlice')]:
 for source in sorted((SRC/'Editable'/source_dir).glob('*.svg')):
  root=E.parse(source).getroot()
  if category!='OptionalLabels':
   for parent in root.iter():
    for child in list(parent):
     if child.tag in (tag('metadata'),tag('text'),tag('image')):parent.remove(child)
  save(root,dest+'/'+source.name,category)

(ROOT/'Maps').mkdir(exist_ok=True)
(ROOT/'Maps/AssetManifest.json').write_text(json.dumps({'assets':manifest},indent=2))
(ROOT/'Maps/ComponentMap.json').write_text(json.dumps(mapping,indent=2))
shutil.copy2(SRC/'Maps/NineSlice.json',ROOT/'Maps/NineSlice-original-settings.json')
print(json.dumps({'assets':len(manifest),'blankAssets':sum(a['category']!='OptionalLabels' for a in manifest),'optionalLabelledButtons':sum(a['category']=='OptionalLabels' for a in manifest),'groups':sorted(set(a['category'] for a in manifest))}))
