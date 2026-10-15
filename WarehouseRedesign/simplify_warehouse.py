import bpy, json, math, os
from mathutils import Vector, Matrix
OUT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\WarehouseRedesign'
scene=bpy.data.scenes['To be rich - Warehouse']
bpy.context.window.scene=scene
cols={c.name:c for c in scene.collection.children}
for ob in list(scene.objects):
    if ob.get('Export') or (ob.type=='FONT' and ob.name.startswith('WarehouseName')):
        bpy.data.objects.remove(ob,do_unlink=True)
src=open(os.path.join(OUT,'build_base.py'),encoding='utf-8').read()
exec(src[src.index('palette = {'):src.index("box('FloorSurface'")])
palette.update({'Wall':('E3E5E8',1,0),'Roof':('466489',1,0),'OfficeWall':('7EA5C5',1,0),'Pillar':('35689D',1,0),'Trim':('528CC0',1,0),'Neon':('70CDE4',1,0),'Floor':('707A88',1,0),'Concrete':('9299A2',1,0),'Wood':('B88756',1,0),'Cardboard':('B98E61',1,0),'Glass':('9FCBDE',1,0),'Metal':('738194',1,0),'Warm':('EEF2E5',1,0)})

def finish(ob,key,collection,group=None,bevel=0):
    cols[collection].objects.link(ob)
    mat=material(ob.name+' Paint',key)
    node=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    node.inputs['Roughness'].default_value=1
    node.inputs['Metallic'].default_value=0
    node.inputs['Specular IOR Level'].default_value=0
    node.inputs['Emission Strength'].default_value=.15 if key in ('Neon','Warm') else 0
    ob.data.materials.append(mat)
    ob['Paint']=key;ob['Export']=collection not in ('Presentation','GameplayGuides')
    ob['CanCollide']=collection in ('Shell','Office','Structure','Racking','OfficeFurniture','Yard')
    if group:ob['CustomGroup']=group
    return ob

def solid(name,pieces,key,collection,group=None):
    axes=[sorted(set(round(pos[i]+sign*size[i]/2,6) for pos,size in pieces for sign in (-1,1))) for i in range(3)]
    occupied=set()
    for ix in range(len(axes[0])-1):
     for iy in range(len(axes[1])-1):
      for iz in range(len(axes[2])-1):
       index=(ix,iy,iz);mid=[(axes[a][index[a]]+axes[a][index[a]+1])/2 for a in range(3)]
       if any(all(abs(mid[a]-p[a])<s[a]/2+1e-7 for a in range(3)) for p,s in pieces):occupied.add(index)
    vertices=[];faces=[];lookup={}
    for ix,iy,iz in occupied:
     coords=[(axes[0][ix+dx],axes[1][iy+dy],axes[2][iz+dz]) for dx,dy,dz in [(0,0,0),(1,0,0),(1,1,0),(0,1,0),(0,0,1),(1,0,1),(1,1,1),(0,1,1)]]
     for delta,face in [((0,0,-1),(0,3,2,1)),((0,0,1),(4,5,6,7)),((0,-1,0),(0,1,5,4)),((1,0,0),(1,2,6,5)),((0,1,0),(2,3,7,6)),((-1,0,0),(3,0,4,7))]:
      if (ix+delta[0],iy+delta[1],iz+delta[2]) in occupied:continue
      ids=[]
      for i in face:
       v=coords[i]
       if v not in lookup:lookup[v]=len(vertices);vertices.append(v)
       ids.append(lookup[v])
      faces.append(tuple(ids))
    ob=mesh(name,vertices,faces,key,collection,group,0)
    ob['Cells']=json.dumps(pieces)
    return ob

box('FloorSurface',(0,0,-.2),(111,91,.4),'Floor','Shell')
box('WallLeft',(-55,0,7.5),(1,89,15),'Wall','Shell','Wall')
for side,y,openings in [('Dispatch',-45,[(-46,-32),(-20,-6),(6,20),(32,46)]),('Receiving',45,[(-25,-11),(11,25)])]:
    pieces=[((0,y,12.75),(111,1,4.5))]
    last=-55.5
    for a,b in openings+[(55.5,55.5)]:
        if a>last:pieces.append((((last+a)/2,y,5.25),(a-last,1,10.5)))
        last=b
    solid('Wall'+side,pieces,'Wall','Shell','Wall')
solid('WallOfficeDivider',[
 ((55,0,13.25),(1,89,3.5)),((55,-32.25,5.75),(1,24.5,11.5)),
 ((55,28.25,5.75),(1,32.5,11.5)),((55,0,1.6),(1,24,3.2)),
 ((55,0,10.7),(1,24,1.6))], 'OfficeWall','Shell','OfficeWall')
box('Roof',(0,0,15.3),(112,.0+92,.6),'Roof','Roof','Roof')
box('OfficeFloor',(75.5,-16,-.2),(40,36,.4),'Floor','Office')
box('OfficeWallFront',(75.5,-34,5.775),(40,1,11.55),'OfficeWall','Office','OfficeWall')
box('OfficeWallBack',(75.5,2,5.775),(40,1,11.55),'OfficeWall','Office','OfficeWall')
box('OfficeWallEast',(96,-16,5.775),(1,37,11.55),'OfficeWall','Office','OfficeWall')
box('OfficeRoof',(75.75,-16,11.8),(40.5,37,.5),'Roof','Roof','Roof')
box('OfficeWindow',(55,0,6.55),(.18,23.6,6.7),'Glass','Office')
solid('OfficeWindowFrame',[
 ((54.39,0,3.35),(.2,24,.3)),((54.39,0,9.75),(.2,24,.3)),
 ((54.39,-11.85,6.55),(.2,.3,6.1)),((54.39,11.85,6.55),(.2,.3,6.1)),
 ((54.39,0,6.55),(.2,.2,6.1))],'Trim','Office','Trim')
box('OfficeDoor',(55,-16,5.45),(.2,7.4,10.9),'Glass','Office')['CanCollide']=False
solid('OfficeDoorFrame',[
 ((54.38,-19.85,5.65),(.22,.3,11.3)),((54.38,-12.15,5.65),(.22,.3,11.3)),
 ((54.38,-16,11.45),(.22,8,.3))],'Trim','Office','Trim')
box('OfficeDoorHandle',(54.75,-13.25,5),(.25,.12,1.5),'Metal','Office')
box('OfficeDoorSign',(54.35,-16,12.7),(.2,7,1.4),'Pillar','Office','Pillar')

for x in (-48,48):
 for y in (-20,0,20):
    box('Pillar',(x,y,7.5),(2.6,2.6,15),'Pillar','Structure','Pillar')
for x in (-54.39,54.39):
    box('WallColourBand',(x,0,12.5),(.2,88.8,.7),'Neon','Lighting','Neon')
for x in (-30,0,30):
 for y in (-30,-10,10,30):
    box('CeilingLight',(x,y,14.8),(10,3,.3),'Warm','Lighting')
for x in (65,87):
 for y in (-5,-24):box('OfficeLight',(x,y,11.4),(7,2.4,.25),'Warm','Lighting')

for side,y,xs in [('Load',-45,[-39,-13,13,39]),('Receive',45,[-18,18])]:
 for index,x in enumerate(xs,1):
    direction=-1 if y<0 else 1
    yy=y+direction*.8
    solid(side+str(index)+'_Frame',[
     ((x-7.2,yy,5.3),(.35,.45,10.6)),((x+7.2,yy,5.3),(.35,.45,10.6)),
     ((x,yy,10.8),(14.75,.45,.4))],'Trim','Docks','Trim')
    box(side+str(index)+'_Sign',(x,y-direction*.65,13),(13,.2,2.4),'Pillar','Docks','Pillar')
    box(side+str(index)+'_Shutter',(x,y,10.15),(13.8,.6,.65),'Roof','Docks','Roof')
    for dx in (-8,8):box(side+'_Bollard',(x+dx,y+direction*1.6,1.1),(.55,.55,2.2),'Trim','Docks','Trim')
    cy=-32 if y<0 else 32; depth=12 if y<0 else 10
    solid(side+str(index)+'_BayOutline',[
     ((x-7.15,cy,.04),(.3,depth+.6,.08)),((x+7.15,cy,.04),(.3,depth+.6,.08)),
     ((x,cy-depth/2-.15,.04),(14,.3,.08)),((x,cy+depth/2+.15,.04),(14,.3,.08))],'White','Yard')
solid('StagingOutline',[
 ((-21,6,.04),(.25,32.5,.08)),((21,6,.04),(.25,32.5,.08)),
 ((0,-10.125,.04),(41.75,.25,.08)),((0,22.125,.04),(41.75,.25,.08))],'Neon','Yard','Neon')
box('DispatchApron',(0,-110.25,-.6),(120,129.5,1),'Asphalt','Yard')
box('ReceivingApron',(0,110.25,-.6),(60,129.5,1),'Asphalt','Yard')
for side,sign,xs in [('Load',-1,[-39,-13,13,39]),('Receive',1,[-18,18])]:
 for x in xs:
    boxes(side+'_RoadLines',[((x+dx,sign*109,-.07),(.2,119,.04)) for dx in (-8,8)],'White','Yard',bevel=0)
box('WarehouseNameBoard',(0,46,17.5),(44,.6,7),'Pillar','Docks','Pillar')

for rack,(x,y) in enumerate([(-51.5,-30),(-51.5,-16),(-51.5,16),(-51.5,30),(51.5,16),(51.5,30)],1):
    posts=[((x+dx,y+dy,6.25),(.35,.35,12.5)) for dx in (-1.825,1.825) for dy in (-5.325,5.325)]
    rails=[((x+dx,y,z),(.35,10.3,.35)) for dx in (-1.825,1.825) for z in (4.35,8.7,12.325)]
    solid('Rack%d_Frame'%rack,posts+rails,'Pillar','Racking','Pillar')
    for level,z in enumerate((.45,4.7,9.05)):
        box('Rack%d_Shelf%d'%(rack,level),(x,y,z),(3.3,10.3,.3),'Wood','Racking')
        for k,dy in enumerate((-2.5,2.5)):
            hh=2.5 if (rack+k+level)%3 else 2
            box('Rack%d_Parcel%d_%d'%(rack,level,k),(x,y+dy,z+.15+hh/2),(2.7,3.3,hh),'Cardboard','Cargo')
            box('Rack%d_Label%d_%d'%(rack,level,k),(x+(-1.365 if x>0 else 1.365),y+dy,z+.15+hh*.6),(.025,1,.5),'Label','Cargo')

for i,(x,y) in enumerate([(-30,2),(30,-4),(-12,24)],1):
    solid('Pallet%d'%i,[((x+dx,y,.13),(.55,4,.26)) for dx in (-1.6,0,1.6)]+[((x,y+dy,.38),(4,.65,.24)) for dy in (-1.65,-.825,0,.825,1.65)],'Wood','Cargo')
    box('Cargo%d_Bottom'%i,(x,y,1.75),(3.3,3.3,2.5),'Cardboard','Cargo')
    box('Cargo%d_Top'%i,(x+.25,y+.15,4),(2.7,2.8,2),'Cardboard','Cargo')
    box('Cargo%d_Label'%i,(x,y-1.667,1.9),(1,.025,.55),'Label','Cargo')

box('ForkliftBody',(18,-8,1.5),(3.4,4.8,1.6),'Trim','Forklift','Trim')
box('ForkliftSeat',(18,-8.1,2.55),(1.6,1.4,.5),'Rubber','Forklift')
box('ForkliftSeatBack',(18,-7.2,3),(1.6,.4,1.4),'Rubber','Forklift')
for dx in (-1.99,1.99):
 for yy in (-6.6,-9.4):cylinder('ForkliftWheel',(18+dx,yy,.7),.7,.55,'Rubber','Forklift',axis='X',sides=12)
solid('ForkliftCage', [((18+dx,yy,3.8),(.16,.16,3)) for dx in (-1.45,1.45) for yy in (-6.3,-9.7)]+[((18,-8,5.38),(3.2,3.8,.16))],'Pillar','Forklift','Pillar')
solid('ForkliftForks', [((18+dx,-10.65,3),(.3,.3,5.8)) for dx in (-1,1)]+[((18+dx,-12.2,.2),(.3,2.8,.2)) for dx in (-1,1)]+[((18,-10.65,1),(2.3,.3,.3))],'Metal','Forklift')

print('Simplified shell and warehouse:',sum(bool(o.get('Export')) for o in scene.objects),'parts')
bpy.app.driver_namespace['warehouse_simple']=globals().copy()
