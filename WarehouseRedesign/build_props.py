import json, random
source=json.load(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\WarehouseRedesign\source_warehouse.json',encoding='utf-8'))
random.seed(14)
convert=Matrix(((1,0,0),(0,0,-1),(0,1,0)))

def from_source(p, name, key, collection, bevel=.04):
    pos=(p['cf'][0],-p['cf'][2],p['cf'][1])
    size=(p['size'][0],p['size'][2],p['size'][1])
    ob=box(name,pos,size,key,collection,bevel=bevel)
    r=Matrix((p['cf'][3:6],p['cf'][6:9],p['cf'][9:12]))
    ob.rotation_euler=(convert @ r @ convert.transposed()).to_euler()
    ob['SourcePath']=p['path']
    return ob

for i,p in enumerate(source['parts']):
    if '.Props.' not in p['path']: continue
    x,y,z=p['cf'][0],-p['cf'][2],p['cf'][1]
    sx,sy,sz=p['size'][0],p['size'][2],p['size'][1]
    if p['name'] in ('Upright','Beam'):
        from_source(p,'Rack_%s_%03d'%(p['name'],i),'Pillar' if p['name']=='Upright' else 'Trim','Racking')
    elif p['name']=='Pallet':
        pieces=[]
        for j in range(5):
            pieces.append(((0,-sy/2+sy/10+j*sy/5,sz*.25),(sx,sy*.16,sz*.5)))
        for j in (-1,0,1):
            pieces.append(((j*sx*.35,0,-sz*.25),(sx*.13,sy,sz*.5)))
        ob=boxes('Pallet_%03d'%i,pieces,'Wood','Cargo',bevel=.025)
        ob.location=(x,y,z)
    elif p['name']=='Box':
        ob=from_source(p,'Parcel_%03d'%i,'Cardboard','Cargo',.08)
        tape=box('Parcel_%03d_Tape'%i,(x,y,z+sz/2+.013),(sx,.24,.025),'Tape','Cargo',bevel=.006)
        label=box('Parcel_%03d_Label'%i,(x,y-sy/2-.015,z),(.65,.025,.42),'Label','Cargo',bevel=.008)
        box('Parcel_%03d_LabelPrint'%i,(x,y-sy/2-.032,z),(.36,.009,.06),'Rubber','Cargo',bevel=0)
    elif p['name'] in ('Body','Handle','Nozzle','Neck','Bracket','Hose','Label') and 'Extinguisher' in p['path']:
        from_source(p,'Safety_%s_%03d'%(p['name'],i),'Red' if p['name']=='Body' else 'Rubber','Cargo')

for x in (-50,50):
    for y in (-23,23):
        boxes('RackBackBrace',[((x,y,z),(4.5,.16,.18)) for z in (4.5,8.9)],'Metal','Racking',bevel=.025)

box('Forklift_Chassis',(18,-8,.95),(3.7,5.3,.9),'Pillar','Forklift',bevel=.16)
box('Forklift_Counterweight',(18,-6.45,1.7),(3.7,2,1.8),'Trim','Forklift','Trim',.22)
box('Forklift_Hood',(18,-7.5,2.55),(3.4,1.75,.65),'Trim','Forklift','Trim',.15)
box('Forklift_Floor',(18,-8.9,1.5),(3.4,1.5,.3),'Metal','Forklift')
box('Forklift_Seat',(18,-8.4,2.7),(1.8,1.6,.45),'Rubber','Forklift',bevel=.12)
box('Forklift_Backrest',(18,-7.8,3.3),(1.8,.4,1.3),'Rubber','Forklift',bevel=.12)
for dx in (-1.45,1.45):
    for yy in (-6.3,-9.8):
        cylinder('Forklift_Tyre',(18+dx,yy,.92),.92,.6,'Rubber','Forklift',axis='X',sides=16)
        cylinder('Forklift_Hub',(18+dx+(.32 if dx>0 else -.32),yy,.92),.45,.055,'Metal','Forklift',axis='X',sides=12)
    beam('Forklift_CagePost',(18+dx,-6.9,2.5),(18+dx,-6.9,5.6),.16,.18,'Pillar','Forklift','Pillar')
    beam('Forklift_CageFront',(18+dx,-9.65,1.7),(18+dx,-9.65,5.6),.16,.18,'Pillar','Forklift','Pillar')
box('Forklift_OverheadGuard',(18,-8.2,5.65),(3.4,3.4,.2),'Trim','Forklift','Trim')
for dx in (-1.0,1.0):
    box('Forklift_Mast',(18+dx,-10.55,3.5),(.35,.5,6.2),'Pillar','Forklift','Pillar')
    box('Forklift_Fork',(18+dx,-12.15,.32),(.3,3.5,.25),'Metal','Forklift',bevel=.03)
box('Forklift_Carriage',(18,-10.9,1.3),(2.8,.3,1.7),'Metal','Forklift')
beam('Forklift_SteeringColumn',(18,-9.2,1.7),(18,-9.65,3.4),.16,.16,'Rubber','Forklift')
cylinder('Forklift_SteeringWheel',(18,-9.65,3.4),.45,.12,'Rubber','Forklift',sides=12)
cylinder('Forklift_Beacon',(18,-7.2,5.95),.22,.4,'Trim','Forklift','Trim',sides=12)

for p in source['parts']:
    if '.OfficeFurniture.' not in p['path']: continue
    name=p['name']
    if name.startswith('InvChair') or name in ('OfficeSign','PlantFoliage','PlantPot'): continue
    key='Wood' if name.startswith('Desk') or name=='ShelfBoard' else 'Pillar'
    if name=='Rug': key='Fabric'
    if name=='Binder': key=random.choice(['Red','OfficeWall','Trim','Fabric'])
    if name=='Drawer': key='OfficeWall'
    ob=from_source(p,'Office_'+name,key,'OfficeFurniture',.05)
    if name=='Drawer':
        x,y,z=ob.location
        box('DrawerHandle',(x,y+.12,z),(.75,.18,.1),'Metal','OfficeFurniture',bevel=.035)
    if name=='Binder':
        x,y,z=ob.location
        box('BinderLabel',(x,y+.52,z),(.28,.04,.55),'Label','OfficeFurniture',bevel=.018)

box('DeskEdge',(78,-11,3.15),(9.2,4.2,.18),'Trim','OfficeFurniture','Trim')
for x in (93,60):
    yy=-4 if x==93 else -28
    cylinder('Planter',(x,yy,.85),1,1.7,'Concrete','OfficeFurniture',sides=12)
    for j in range(5):
        a=j*math.tau/5
        beam('PlantStem',(x,yy,1.6),(x+math.cos(a)*.85,yy+math.sin(a)*.85,3.1+(j%2)*.7),.14,.12,'Green','OfficeFurniture')
        ob=box('PlantLeaf',(x+math.cos(a)*.75,yy+math.sin(a)*.75,3.0+(j%2)*.7),(.8,.3,1.65),'Green','OfficeFurniture',bevel=.13)
        ob.rotation_euler=(.3*math.cos(a),.4*math.sin(a),a)

tx,ty=88.66403198242188,-26.830001831054688
cylinder('TeleporterBase',(tx,ty,.6),4.5,1.0,'Pillar','Teleporter','Pillar',sides=32)
cylinder('TeleporterPad',(tx,ty,1.15),3.85,.15,'Screen','Teleporter',sides=32)
def ring(name,pos,rout,rin,depth,key,collection,group=None):
    n=48; verts=[]
    for zz in (-depth/2,depth/2):
        for radius in (rout,rin):
            verts.extend([(radius*math.cos(i*math.tau/n),radius*math.sin(i*math.tau/n),zz) for i in range(n)])
    faces=[]
    for i in range(n):
        j=(i+1)%n
        faces.extend([(i,j,j+n,i+n),(i+2*n,i+3*n,j+3*n,j+2*n),(i,i+2*n,j+2*n,j),(i+n,j+n,j+3*n,i+3*n)])
    ob=mesh(name,verts,faces,key,collection,group,.02); ob.location=pos
    return ob
ring('TeleporterLightRing',(tx,ty,1.28),3.65,3.3,.12,'Neon','Teleporter','Neon')
for dx in (-4.3,4.3):
    box('TeleporterSidePillar',(tx+dx,ty,3.3),(.5,.8,5.5),'Trim','Teleporter','Trim')
    box('TeleporterPillarLight',(tx+dx,ty-.43,3.3),(.18,.06,4.6),'Neon','Teleporter','Neon',.015)
box('TeleporterSign',(tx,-33.35,6.15),(12,.35,3.6),'Screen','Teleporter')
box('TeleporterSignEdge',(tx,-33.15,6.15),(12.6,.25,4.15),'Trim','Teleporter','Trim')
text('TeleporterText','VISIT PLOTS',(tx,-33.55,5.8),.9,'White','Teleporter')

for p in source['parts']:
    important=(p['name'] in ('Staging','SpawnLocation','SpawnPad','LaptopAnchor','PlayerChairAnchor','InvestorChairAnchor','NameSign') or '.LoadBays.' in p['path'] or '.OffloadBays.' in p['path'] or '.CameraSlots.' in p['path'] or '.BaySigns.' in p['path'])
    if not important: continue
    ob=bpy.data.objects.new('GUIDE_'+p['name'],None)
    cols['GameplayGuides'].objects.link(ob)
    r=Matrix((p['cf'][3:6],p['cf'][6:9],p['cf'][9:12]))
    ob.location=(p['cf'][0],-p['cf'][2],p['cf'][1])
    ob.rotation_euler=(convert @ r @ convert.transposed()).to_euler()
    ob.empty_display_size=1.1
    ob['SourcePath']=p['path']; ob['RobloxCFrame']=p['cf']; ob['RobloxSize']=p['size']
    ob['Export']=False
    for k,v in (p['attrs'].items() if isinstance(p['attrs'],dict) else []):
        ob[k]=v
cols['GameplayGuides'].hide_render=True
cols['GameplayGuides'].hide_viewport=True
print('Props and preserved guides complete:',len(scene.objects),'objects')
