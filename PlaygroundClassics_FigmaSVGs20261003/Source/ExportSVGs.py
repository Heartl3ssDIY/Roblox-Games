import json, math, re, copy, html, hashlib, shutil
from pathlib import Path
import xml.etree.ElementTree as ET
from PIL import ImageFont

ROOT=Path(__file__).resolve().parents[1]
PROJECT=ROOT.parent
SNAPSHOT=json.loads((ROOT/'Source/NativeGuiSnapshot.json').read_text(encoding='utf-8'))
PRESETS=json.loads((ROOT/'Source/StatePresets.json').read_text(encoding='utf-8'))
FONT_DIR=Path(r'C:/Users/sandt/AppData/Local/Roblox/Versions/version-76e1a02649ad4f35/content/fonts')
FONTS={'Luckiest Guy':'LuckiestGuy-Regular.ttf','Fredoka One':'FredokaOne-Regular.ttf','Arimo':'Arimo-Regular.ttf'}
NODES={n['id']:n for g in SNAPSHOT['guis'] for n in g['nodes']}
SAMPLE_TEXT={
 'StarterGui.PlaygroundShell.LevelPanel.XP':'0 / 200 XP',
 'StarterGui.PlaygroundShell.CompactLevelPanel.XP':'0 / 200',
 'StarterGui.PlaygroundShell.Wallet.Coins':'150',
 'StarterGui.PlaygroundShell.Wallet.Wins':'0 wins',
 'StarterGui.PlaygroundShell.ShopPanel.Coins':'150 coins',
 'StarterGui.PlaygroundShell.RewardToast.Message':'+150 coins · +50 XP · Round won!'
}
for path,value in SAMPLE_TEXT.items(): NODES[path]['t']['value']=value
CHILDREN={}
for n in NODES.values(): CHILDREN.setdefault(n.get('p'),[]).append(n)
for rows in CHILDREN.values(): rows.sort(key=lambda n:(n.get('z',0),n.get('order',0),n['id']))
MANIFEST=[]
COVERED=set()
TEXT_FITS=[]
WARNINGS=[]

def num(x): return ('%.3f'%float(x)).rstrip('0').rstrip('.') or '0'
def esc(s): return html.escape(str(s),quote=True)
def sid(s): return re.sub(r'[^A-Za-z0-9_.-]','_',s)
def rgb(c): return tuple(int(c[i:i+2],16) for i in (1,3,5))
def tint(a,b): return '#'+''.join('%02x'%round(x*y/255) for x,y in zip(rgb(a),rgb(b)))
def shade(c,v): return '#'+''.join('%02x'%min(255,max(0,round(x*v))) for x in rgb(c))
def family(t):
 value=t['font'].split('/')[-1].split('.')[0]
 return {'LuckiestGuy':'Luckiest Guy','FredokaOne':'Fredoka One','LegacyArial':'Arimo','Arimo':'Arimo'}.get(value,'Arimo')
FONT_CACHE={}
def font(name,size):
 key=(name,round(size*4))
 if key not in FONT_CACHE: FONT_CACHE[key]=ImageFont.truetype(str(FONT_DIR/FONTS.get(name,FONTS['Arimo'])),key[1]/4)
 return FONT_CACHE[key]

def wrap(text,f,width,enabled):
 result=[]
 for raw in text.split('\n'):
  if not enabled or f.getlength(raw)<=width: result.append(raw);continue
  words=raw.split(' '); line=''
  for word in words:
   candidate=(line+' '+word).strip()
   if line and f.getlength(candidate)>width: result.append(line);line=word
   else: line=candidate
  result.append(line)
 return result or ['']

def fit_text(n,value):
 t=n['t']; x,y,w,h=n['r']; name=family(t)
 constraints=[v['textConstraint'] for v in CHILDREN.get(n['id'],[]) if 'textConstraint' in v]
 low,high=constraints[0] if constraints else (1,100)
 target=min(high,t['size']) if not t['scaled'] else high
 target=max(1,target)
 for size in [target-i*.25 for i in range(int((target-1)*4)+1)]:
  f=font(name,size); lines=wrap(value,f,max(1,w-2),t['wrapped'])
  boxes=[f.getbbox(line or ' ',anchor='ls') for line in lines]
  ink=max(b[3]-b[1] for b in boxes)
  line_height=max(size*1.12,ink)*t.get('line',1)
  block=ink+(len(lines)-1)*line_height
  if not t['scaled'] or (max(f.getlength(line) for line in lines)<=w-2 and block<=h-2): return name,size,f,lines,boxes,line_height,block
 return name,1,font(name,1),[value],[font(name,1).getbbox(value,anchor='ls')],1,1

def transform(cf,p):
 return [cf[i]+sum(cf[3+i*3+j]*p[j] for j in range(3)) for i in range(3)]
def camera_space(cf,p):
 delta=[p[i]-cf[i] for i in range(3)]
 return [sum(cf[3+j*3+i]*delta[j] for j in range(3)) for i in range(3)]
def dot(a,b): return sum(x*y for x,y in zip(a,b))
def sub(a,b): return [x-y for x,y in zip(a,b)]
def cross(a,b): return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]

ICONS={}
for asset,file in [('86080260918857','sprint-lightning.svg'),('99567482512995','dodge-swoosh.svg'),('99215209137796','level-star.svg')]:
 tree=ET.parse(PROJECT/'BritishBulldogMovement20261003'/file).getroot()
 ICONS[asset]=''.join(ET.tostring(e,encoding='unicode') for e in tree if e.tag.rsplit('}',1)[-1] not in ('style','defs'))

class Drawing:
 def __init__(self,roots,overrides=None,crop=False,expanded=False,label=''):
  self.roots=roots;self.crop=crop;self.expanded=expanded;self.label=label
  self.overrides=overrides or {};self.defs=[];self.texts=[];self.nodes=set()
  self.parts_count=0
  boxes=[NODES[r]['r'] for r in roots if 'r' in NODES[r]]
  if crop and boxes:
   x=min(b[0] for b in boxes)-8;y=min(b[1] for b in boxes)-8
   end_x=max(b[0]+b[2] for b in boxes)+8;end_y=max(b[1]+b[3] for b in boxes)+8
   if expanded:
    for root in roots:
     for n in NODES.values():
      if n['id'].startswith(root+'.') and 'r' in n and n['c'] not in ('ViewportFrame',):
       end_y=max(end_y,n['r'][1]+n['r'][3]+8);end_x=max(end_x,n['r'][0]+n['r'][2]+8)
   self.origin=(x,y);self.size=(end_x-x,end_y-y)
  else:self.origin=(0,0);self.size=tuple(SNAPSHOT['viewport'])
 def override(self,n):
  n=copy.deepcopy(n);o=self.overrides.get(n['id'],{})
  if 'text' in o and 't' in n:n['t']['value']=o['text']
  if 'color' in o and 't' in n:n['t']['color']=o['color']
  if 'bg' in o:n['bg']=o['bg']
  if 'stroke' in o and 'stroke' in n:n['stroke']['color']=o['stroke']
  for prop in ('visible','fill'): 
   if prop in o:n[prop]=o[prop]
  return n
 def clip(self,id,x,y,w,h,r=0):
  key='Clip_'+sid(id)
  self.defs.append('<clipPath id="'+key+'"><rect x="'+num(x)+'" y="'+num(y)+'" width="'+num(w)+'" height="'+num(h)+'" rx="'+num(r)+'"/></clipPath>')
  return key
 def rect(self,n):
  x,y,w,h=n['r']
  children=[self.override(c) for c in CHILDREN.get(n['id'],[])]
  radius=next((max(0,min(min(w,h)/2,c['radius'][0]*min(w,h)+c['radius'][1])) for c in children if 'radius' in c),0)
  base=n.get('bg','#ffffff');alpha=1-n.get('bt',1)
  stroke=next((c['stroke'] for c in children if c.get('stroke',{}).get('enabled') and c['stroke']['mode']=='Border'),None)
  if not stroke and n.get('border',0)>0 and alpha>0:stroke={'color':n['bc'],'width':n['border'],'alpha':1-alpha}
  if not stroke and n['c'] not in ('TextLabel','TextButton','TextBox'):
   stroke=next((c['stroke'] for c in children if c.get('stroke',{}).get('enabled')),None)
  gradient=next((c['gradient'] for c in children if c.get('gradient',{}).get('enabled')),None)
  if 'fill' in n:
   w*=max(0,min(1,n['fill']));gradient=None
  if gradient:
   key='Gradient_'+sid(n['id'])
   colors=gradient['colors'];alphas=gradient['alpha']
   stops=[]
   def interp(rows,t):
    for index in range(len(rows)-1):
     a,b=rows[index:index+2]
     if a[0]<=t<=b[0]:
      f=(t-a[0])/(b[0]-a[0]) if b[0]!=a[0] else 0
      return a[1]*(1-f)+b[1]*f
    return rows[-1][1]
   for t,col in colors:stops.append('<stop offset="'+num(t)+'" stop-color="'+tint(base,col)+'" stop-opacity="'+num(alpha*(1-interp(alphas,t)))+'"/>')
   self.defs.append('<linearGradient id="'+key+'" x1="0" y1="0" x2="1" y2="0" gradientTransform="rotate('+num(gradient['rot'])+' .5 .5)">' + ''.join(stops)+'</linearGradient>')
   fill='url(#'+key+')';alpha=1
  else:fill=base if alpha>0 else 'none'
  attrs='x="'+num(x)+'" y="'+num(y)+'" width="'+num(w)+'" height="'+num(h)+'" rx="'+num(radius)+'" fill="'+fill+'"'
  if alpha<1:attrs+=' fill-opacity="'+num(alpha)+'"'
  if stroke and stroke['alpha']<1:attrs+=' stroke="'+stroke['color']+'" stroke-width="'+num(stroke['width'])+'" stroke-opacity="'+num(1-stroke['alpha'])+'" stroke-linejoin="round"'
  if w<=0 or h<=0:return '',radius
  return '<rect id="'+sid(n['id']+'_Background')+'" '+attrs+'/>',radius
 def text(self,n):
  t=n['t'];value=re.sub(r'<[^>]+>','',t['value']) if t['rich'] else t['value']
  if not value or t['alpha']>=1:return ''
  name,size,f,lines,boxes,line_height,block=fit_text(n,value)
  x,y,w,h=n['r'];alignment=t['x'];vertical=t['y']
  top=y+(0 if vertical=='Top' else h-block if vertical=='Bottom' else (h-block)/2)
  clips=[];ancestor=n.get('p')
  while ancestor in NODES:
   parent=self.override(NODES[ancestor])
   included=any(ancestor==root or ancestor.startswith(root+'.') for root in self.roots)
   if included and parent.get('clip') and not (self.expanded and parent.get('scroll')) and 'r' in parent:
    px,py,pw,ph=parent['r']
    radius=next((max(0,min(min(pw,ph)/2,c['radius'][0]*min(pw,ph)+c['radius'][1])) for c in CHILDREN.get(ancestor,[]) if 'radius' in c),0)
    clips.append({'name':ancestor,'x':px-self.origin[0],'y':py-self.origin[1],'width':pw,'height':ph,'radius':radius})
   ancestor=parent.get('p')
  clips.reverse()
  pieces=[]
  stroke=next((self.override(c)['stroke'] for c in CHILDREN.get(n['id'],[]) if 'stroke' in c and c['stroke']['enabled'] and c['stroke']['mode']=='Contextual'),None)
  if not stroke and t['strokeAlpha']<1:stroke={'color':t['stroke'],'width':1,'alpha':t['strokeAlpha']}
  for index,(line,box) in enumerate(zip(lines,boxes)):
   tx=x+1 if alignment=='Left' else x+w-1 if alignment=='Right' else x+w/2
   anchor={'Left':'start','Right':'end','Center':'middle'}[alignment]
   baseline=top-box[1]+index*line_height
   attrs='x="'+num(tx)+'" y="'+num(baseline)+'" text-anchor="'+anchor+'" font-family="'+name+'" font-size="'+num(size)+'" font-weight="400" fill="'+t['color']+'" fill-opacity="'+num(1-t['alpha'])+'"'
   if stroke:attrs+=' stroke="'+stroke['color']+'" stroke-width="'+num(stroke['width'])+'" stroke-opacity="'+num(1-stroke['alpha'])+'" stroke-linejoin="round" paint-order="stroke fill"'
   pieces.append('<text id="'+sid(n['id']+'_Text_'+str(index+1))+'" '+attrs+'>'+esc(line)+'</text>')
   self.texts.append({'name':n['id']+'/Line'+str(index+1),'text':line,'x':x-self.origin[0],'y':top+index*line_height-self.origin[1],'width':w,'height':max(line_height,box[3]-box[1]),'fontFamily':name,'fontSize':size,'color':t['color'],'opacity':1-t['alpha'],'strokeColor':stroke['color'] if stroke else t['color'],'strokeWidth':stroke['width'] if stroke else 0,'strokeOpacity':1-stroke['alpha'] if stroke else 0,'align':{'Left':'LEFT','Right':'RIGHT','Center':'CENTER'}[alignment],'clips':clips,'rotation':n.get('rot',0),'rotationCenter':[x+w/2-self.origin[0],y+h/2-self.origin[1]]})
   TEXT_FITS.append({'path':n['id'],'text':line,'fontSize':size,'advance':f.getlength(line),'width':w,'overflow':f.getlength(line)>w+.5})
  return ''.join(pieces)
 def viewport(self,n):
  v=n['v'];cf=v['camera']
  if not cf:return ''
  x,y,w,h=n['r'];focal=h/(2*math.tan(math.radians(v['fov'])/2));shapes=[]
  def project(point):
   p=camera_space(cf,point)
   if p[2]>=-.02:return None
   return [x+w/2+p[0]*focal/-p[2],y+h/2-p[1]*focal/-p[2]]
  for part_index,part in enumerate(v['parts']):
   if part['alpha']>=1:continue
   self.parts_count+=1
   center=part['cf'][:3];depth=-camera_space(cf,center)[2]
   if depth<=0:continue
   color=part['color'];pid=sid(n['id']+'_VectorPreview_'+part['name']+'_'+str(part_index+1))
   if part['shape']=='Ball':
    p=project(center);r=max(part['size'])/2
    if p:
     radius=focal*r/depth
     shapes.append((depth,'<ellipse id="'+pid+'" cx="'+num(p[0])+'" cy="'+num(p[1])+'" rx="'+num(radius)+'" ry="'+num(radius)+'" fill="'+color+'" fill-opacity="'+num(1-part['alpha'])+'"/>'))
    continue
   sx,sy,sz=[s/2 for s in part['size']]
   if part['shape']=='Cylinder':
    points=[];segments=16
    for axis in (-sx,sx):
     for i in range(segments):
      angle=i*math.tau/segments;points.append([axis,math.cos(angle)*sy,math.sin(angle)*sz])
    faces=[list(range(segments)),list(range(segments,segments*2))]
    faces += [[i,(i+1)%segments,(i+1)%segments+segments,i+segments] for i in range(segments)]
   elif part['shape']=='WedgePart':
    points=[[-sx,-sy,-sz],[sx,-sy,-sz],[-sx,-sy,sz],[sx,-sy,sz],[-sx,sy,sz],[sx,sy,sz]]
    faces=[[0,2,3,1],[2,4,5,3],[0,1,5,4],[0,4,2],[1,3,5]]
   else:
    points=[[-sx,-sy,-sz],[sx,-sy,-sz],[sx,sy,-sz],[-sx,sy,-sz],[-sx,-sy,sz],[sx,-sy,sz],[sx,sy,sz],[-sx,sy,sz]]
    faces=[[0,3,2,1],[4,5,6,7],[0,4,7,3],[1,2,6,5],[0,1,5,4],[3,7,6,2]]
   global_points=[transform(part['cf'],p) for p in points]
   projected=[project(p) for p in global_points]
   for i,face in enumerate(faces):
    pts=[projected[j] for j in face]
    if any(p is None for p in pts):continue
    normal=cross(sub(global_points[face[1]],global_points[face[0]]),sub(global_points[face[2]],global_points[face[0]]))
    length=math.sqrt(dot(normal,normal)) or 1
    strength=.72+.28*abs(normal[1]/length)
    face_depth=sum(-camera_space(cf,global_points[j])[2] for j in face)/len(face)
    shapes.append((face_depth,'<polygon id="'+pid+'_Face'+str(i)+'" points="'+' '.join(num(p[0])+','+num(p[1]) for p in pts)+'" fill="'+shade(color,strength)+'" fill-opacity="'+num(1-part['alpha'])+'"/>'))
  clip=self.clip(n['id']+'_Preview',x,y,w,h,8)
  return '<g id="'+sid(n['id']+'_EditableVectorPreview')+'" clip-path="url(#'+clip+')">'+''.join(s for depth,s in sorted(shapes,key=lambda p:-p[0]))+'</g>'
 def node(self,path,force=False):
  n=self.override(NODES[path])
  if 'r' not in n:return ''.join(self.node(c['id'],force) for c in CHILDREN.get(path,[]) if 'r' in c)
  if not force and not n.get('visible',True):return ''
  self.nodes.add(path)
  x,y,w,h=n['r'];bg,radius=self.rect(n);content=bg
  if n.get('v'):content+=self.viewport(n)
  if n.get('image') and n['image']['alpha']<1:
   asset=n['image']['asset'].split('/')[-1]
   if asset in ICONS:
    scale=min(w,h)/64
    content+='<g id="'+sid(path+'_EditableIcon')+'" transform="translate('+num(x+(w-scale*64)/2)+' '+num(y+(h-scale*64)/2)+') scale('+num(scale)+')" opacity="'+num(1-n['image']['alpha'])+'">'+ICONS[asset]+'</g>'
   else:WARNINGS.append('Unknown image asset '+asset+' at '+path)
  if n.get('t'):content+=self.text(n)
  inner=''.join(self.node(c['id']) for c in CHILDREN.get(path,[]) if 'r' in c or c['c']=='Folder')
  if n.get('clip') and not (self.expanded and n.get('scroll')):
   clip=self.clip(path+'_Children',x,y,w,h,radius);inner='<g clip-path="url(#'+clip+')">'+inner+'</g>'
  content+=inner
  rotation=''
  if n.get('rot'):rotation=' transform="rotate('+num(n['rot'])+' '+num(x+w/2)+' '+num(y+h/2)+')"'
  return '<g id="'+sid(path)+'" data-roblox-path="'+esc(path)+'"'+rotation+'>'+content+'</g>'
 def svg(self):
  body=''.join(self.node(r,True) for r in sorted(self.roots,key=lambda r:NODES[r].get('z',0)))
  metadata=json.dumps({'version':1,'texts':self.texts},ensure_ascii=False,separators=(',',':')).replace(']]>','] ]>')
  width,height=self.size
  title='<title>'+esc(self.label)+'</title><desc>Editable vector export of authored Roblox UI. Text remains SVG text. Viewport previews are vector projections.</desc>'
  return '<svg xmlns="http://www.w3.org/2000/svg" width="'+num(width)+'" height="'+num(height)+'" viewBox="0 0 '+num(width)+' '+num(height)+'">'+title+'<metadata id="playground-text-layers"><![CDATA['+metadata+']]></metadata><defs>'+''.join(self.defs)+'</defs><g id="UI" transform="translate('+num(-self.origin[0])+' '+num(-self.origin[1])+')">'+body+'</g></svg>'

def output(file,roots,overrides=None,crop=True,expanded=False,label=None):
 for root in roots:assert root in NODES,root
 for key in (overrides or {}):assert key in NODES,'Unknown override '+key
 drawing=Drawing(roots,overrides,crop,expanded,label or file)
 svg=drawing.svg();path=ROOT/file;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(svg,encoding='utf-8')
 COVERED.update(drawing.nodes)
 MANIFEST.append({'file':file,'width':round(drawing.size[0],3),'height':round(drawing.size[1],3),'roots':roots,'guiObjects':len(drawing.nodes),'textLayers':len(drawing.texts),'vectorPreviewParts':drawing.parts_count,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})

def absolute(gui,relative):return 'StarterGui.'+gui+'.'+relative

for g in SNAPSHOT['guis']:
 gui=g['root'];prefix='StarterGui.'+gui
 for n in g['nodes']:
  if 'r' not in n:continue
  if n['p']==prefix and n['n']!='Main':
   output('Panels/'+gui+'/'+n['n']+'.svg',[n['id']])
  elif gui=='MudHUD' and n['p']==prefix+'.Main':
   output('Panels/'+gui+'/'+n['n']+'.svg',[n['id']])
 if gui=='PlaygroundShell':
  output('Templates/Shop_ItemCard.svg',[absolute(gui,'Templates.ItemCard')])
  for index in range(1,13):
   output('ShopItems/Slot%02d.svg'%index,[absolute(gui,'ShopPanel.Cards.Slot%02d'%index)])
  output('Panels/PlaygroundShell/Shop_All12Items.svg',[absolute(gui,'ShopPanel.Cards')],expanded=True)
  shop=absolute(gui,'ShopPanel')
  overrides={absolute(gui,'ShopPanel.Cards'):{'visible':True}}
  # Full-scroll artboard uses original geometry and expands only the export backplate.
  original=NODES[shop]['r'][3]
  NODES[shop]['r'][3]=930
  status=absolute(gui,'ShopPanel.Status');old=NODES[status]['r'][1]
  NODES[status]['r'][1]=NODES[shop]['r'][1]+886
  output('Panels/PlaygroundShell/Shop_CompleteExpanded.svg',[shop],overrides,expanded=True)
  NODES[shop]['r'][3]=original;NODES[status]['r'][1]=old
 if gui=='PlaygroundAdminPanel':
  for variant in ('Panel','CompactPanel'):
   parent=absolute(gui,variant);body=absolute(gui,variant+'.Body')
   panel_height=NODES[parent]['r'][3];body_height=NODES[body]['r'][3]
   delta=max(0,NODES[body]['scroll']['absolute'][1]-body_height)
   NODES[parent]['r'][3]+=delta;NODES[body]['r'][3]+=delta
   moved=[]
   if variant=='Panel':
    for name in ('StopRound','ToggleAutomatic','Message'):
     footer=absolute(gui,variant+'.'+name)
     for path,n in NODES.items():
      if 'r' in n and (path==footer or path.startswith(footer+'.')):n['r'][1]+=delta;moved.append(path)
   output('Panels/PlaygroundAdminPanel/'+variant+'_AllGamesExpanded.svg',[absolute(gui,variant)],expanded=True)
   NODES[parent]['r'][3]=panel_height;NODES[body]['r'][3]=body_height
   for path in moved:NODES[path]['r'][1]-=delta
   for game in ('BritishBulldog','TagYoureIt','StuckInTheMud'):
    output('Panels/PlaygroundAdminPanel/'+variant+'_'+game+'.svg',[absolute(gui,variant+'.Body.Content.'+game)])
 for n in g['nodes']:
  if n['c'] in ('TextButton','ImageButton') and not n['id'].startswith(prefix+'.ShopPanel.Cards.Slot'):
   relative=n['id'][len(prefix)+1:].replace('.','_')
   output('Controls/'+gui+'/'+relative+'.svg',[n['id']])

for preset in PRESETS:
 gui=preset['gui'];roots=[absolute(gui,r) for r in preset['roots']]
 overrides={absolute(gui,k):v for k,v in preset.get('overrides',{}).items()}
 output(preset['file'],roots,overrides,preset.get('crop',False),label=Path(preset['file']).stem.replace('_',' '))

icon_dir=ROOT/'Icons';icon_dir.mkdir(exist_ok=True)
for filename in ('sprint-lightning.svg','dodge-swoosh.svg','level-star.svg'):shutil.copy2(PROJECT/'BritishBulldogMovement20261003'/filename,icon_dir/filename)
ALL_GUI={n['id'] for n in NODES.values() if 'r' in n}
MISSING=sorted(ALL_GUI-COVERED)
# Include any hidden authored leaf or child absent from all panel/state outputs.
for path in MISSING:
 n=NODES[path]
 output('HiddenElements/'+n['id'].replace('StarterGui.','').replace('.','_')+'.svg',[path])
missing_after=sorted(ALL_GUI-COVERED)
assert not missing_after,missing_after
(ROOT/'SVGManifest.json').write_text(json.dumps({'date':SNAPSHOT['date'],'viewport':SNAPSHOT['viewport'],'screens':len(SNAPSHOT['guis']),'authoredGuiObjects':len(ALL_GUI),'coveredGuiObjects':len(COVERED),'files':MANIFEST,'icons':list(ICONS),'warnings':sorted(set(WARNINGS)),'source':'Source/NativeGuiSnapshot.json','representativeRuntimeText':SAMPLE_TEXT,'textPreserved':True,'rasterImagesEmbedded':False,'functional3DViewports':False,'missing':missing_after},ensure_ascii=False,indent=2),encoding='utf-8')
(ROOT/'Source/TextFitChecks.json').write_text(json.dumps({'measuredWith':'Installed Roblox TTFs via Pillow FreeType','samples':len(TEXT_FITS),'overflows':[t for t in TEXT_FITS if t['overflow']],'warnings':sorted(set(WARNINGS))},ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'svgFiles':len(MANIFEST)+3,'guiObjects':len(ALL_GUI),'covered':len(COVERED),'states':len(PRESETS),'overflows':sum(t['overflow'] for t in TEXT_FITS),'warnings':sorted(set(WARNINGS))}))

