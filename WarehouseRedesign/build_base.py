import bpy, math, json, os
from mathutils import Vector, Matrix

OUT = r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\WarehouseRedesign'
os.makedirs(OUT, exist_ok=True)
scene = bpy.data.scenes.new('To be rich - Warehouse')
bpy.context.window.scene = scene
scene['SourcePlaceId'] = '80501113506293'
scene['RobloxOrigin'] = [0.0, 0.0, 0.0]
scene['LegacyPlotOrigin'] = [20.5, 8.375, 0.0]
scene['CoordinateMap'] = 'Roblox (x,y,z) = Blender (x,z,-y)'
scene['Description'] = 'Four dispatch bays, two receiving bays, office, removable roof. All meshes have one independently editable material.'
cols = {}
for key in ['Shell','Roof','Office','Docks','Structure','Lighting','Yard','Racking','Cargo','Forklift','OfficeFurniture','Teleporter','GameplayGuides','Presentation']:
    c = bpy.data.collections.new(key)
    scene.collection.children.link(c)
    cols[key] = c

palette = {
 'Wall': ('E8E6D8', .7, .0), 'Roof': ('294B61', .48, .35),
 'OfficeWall': ('4F98AD', .6, .05), 'Pillar': ('234355', .48, .3),
 'Trim': ('F0AB43', .43, .2), 'Neon': ('79EBF2', .3, .0),
 'Concrete': ('829299', .9, .0), 'Floor': ('506876', .85, .0),
 'Asphalt': ('384A57', .95, .0), 'Rubber': ('1E2D37', .9, .0),
 'Metal': ('7E9BA6', .42, .55), 'White': ('E8F4F2', .6, .0),
 'Glass': ('75B7CA', .2, .2), 'Wood': ('AA7950', .9, .0),
 'Cardboard': ('C99560', .9, .0), 'Tape': ('EED4A0', .8, .0),
 'Label': ('F5EDDD', .75, .0), 'Red': ('DC624E', .6, .0),
 'Green': ('599774', .8, .0), 'Screen': ('183C51', .35, .0),
 'Fabric': ('325A6C', .95, .0), 'Warm': ('FFE3A9', .4, .0)
}

def linear(v):
    return v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4

def material(name, key):
    hx, rough, metal = palette[key]
    rgb = tuple(linear(int(hx[i:i+2],16)/255) for i in (0,2,4))
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.diffuse_color = (*rgb,1)
    node = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    node.inputs['Base Color'].default_value = (*rgb,1)
    node.inputs['Roughness'].default_value = rough
    node.inputs['Metallic'].default_value = metal
    if key in ('Neon','Warm'):
        node.inputs['Emission Color'].default_value = (*rgb,1)
        node.inputs['Emission Strength'].default_value = 2.5 if key == 'Neon' else .65
    return m

def finish(ob, key, collection, group=None, bevel=.06):
    cols[collection].objects.link(ob)
    ob.data.materials.append(material(ob.name+' Paint', key))
    ob['Paint'] = key
    ob['Export'] = collection not in ('Presentation','GameplayGuides')
    ob['CanCollide'] = collection in ('Shell','Office','Structure','Racking','Yard')
    if group: ob['CustomGroup'] = group
    if bevel > 0 and ob.type == 'MESH':
        mod = ob.modifiers.new('Edge highlights', 'BEVEL')
        mod.width = bevel
        mod.segments = 2
    return ob

def mesh(name, vertices, faces, key, collection, group=None, bevel=.06):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices,[],faces)
    data.update()
    ob = bpy.data.objects.new(name,data)
    return finish(ob,key,collection,group,bevel)

def boxes(name, pieces, key, collection, group=None, bevel=.06):
    verts, faces = [], []
    for pos, size in pieces:
        x,y,z = pos; a,b,c = [v/2 for v in size]; n=len(verts)
        verts.extend([(x-a,y-b,z-c),(x+a,y-b,z-c),(x+a,y+b,z-c),(x-a,y+b,z-c),
                      (x-a,y-b,z+c),(x+a,y-b,z+c),(x+a,y+b,z+c),(x-a,y+b,z+c)])
        faces.extend([tuple(n+i for i in f) for f in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]])
    ob=mesh(name,verts,faces,key,collection,group,bevel)
    return ob

def box(name, pos, size, key, collection, group=None, bevel=.06):
    ob = boxes(name,[((0,0,0),size)],key,collection,group,bevel)
    ob.location = pos
    return ob

def beam(name, a, b, width, depth, key, collection, group=None):
    a,b=Vector(a),Vector(b)
    ob=box(name,(a+b)/2,(width,depth,(b-a).length),key,collection,group,.035)
    ob.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    return ob

def cylinder(name,pos,radius,depth,key,collection,group=None,axis='Z',sides=16):
    vertices=[]
    for z in (-depth/2,depth/2):
        vertices.extend([(radius*math.cos(i*math.tau/sides),radius*math.sin(i*math.tau/sides),z) for i in range(sides)])
    faces=[tuple(reversed(range(sides))),tuple(range(sides,2*sides))]
    faces += [(i,(i+1)%sides,(i+1)%sides+sides,i+sides) for i in range(sides)]
    ob=mesh(name,vertices,faces,key,collection,group,.035)
    ob.location=pos
    if axis=='X': ob.rotation_euler[1]=math.pi/2
    if axis=='Y': ob.rotation_euler[0]=math.pi/2
    return ob

def text(name, body, pos, size, key, collection, rotation=(math.pi/2,0,0)):
    curve=bpy.data.curves.new(name,'FONT')
    curve.body=body; curve.size=size; curve.extrude=.008; curve.resolution_u=4
    ob=bpy.data.objects.new(name,curve)
    finish(ob,key,collection,None,0)
    ob.location=pos; ob.rotation_euler=rotation
    bpy.context.view_layer.update()
    ob.location.x -= ob.dimensions.x/2
    return ob

def roof_z(x): return 23.0-abs(x)*7.0/56.0

box('FloorSurface',(0,0,-.55),(110,90,1.1),'Floor','Shell',bevel=.08)
box('Foundation',(0,0,-1.15),(113,93,.7),'Concrete','Shell',bevel=.15)
for i,x in enumerate((-44,-22,0,22,44)):
    box('FloorJoint_%02d'%i,(x,0,.009),(.04,89,.012),'Concrete','Shell',bevel=0)
for i,y in enumerate((-30,-10,10,30)):
    box('CrossJoint_%02d'%i,(0,y,.009),(109,.04,.012),'Concrete','Shell',bevel=0)

def wall_x(name,x,y0,y1,z0=0,z1=15.2,group='Wall'):
    ob=box(name,(x,(y0+y1)/2,(z0+z1)/2),(1,y1-y0,z1-z0),group,'Shell',group,.07)
    for i in range(int(y1-y0)//6):
        y=y0+3+i*6
        box(name+'_Rib%02d'%i,(x-.57 if x<0 else x+.57,y,(z0+z1)/2),(.18,.12,z1-z0-.35),group,'Shell',group,.02)
    return ob

wall_x('WestWall',-55,-45,45)
wall_x('EastWall_Rear',55,10,45)
wall_x('OfficeDivider_Front',55,-45,-20)
wall_x('OfficeDivider_DoorHeader',55,-20,-12,11,15.2)
wall_x('OfficeDivider_WindowSill',55,-12,10,0,3.2)
wall_x('OfficeDivider_WindowHeader',55,-12,10,10.5,15.2)
for i,y in enumerate((-9.15,-3.25,2.65,8.55)):
    box('OfficeWindow_%02d'%i,(55,y,6.85),(.2,5.6,7.1),'Glass','Office',bevel=.025)
for y in (-12,-6.1,-.2,5.7,10):
    box('OfficeWindowMullion',(54.4,y,6.85),(.25,.18,7.3),'Pillar','Office','Pillar',.02)

for side, y, segments in [('Dispatch',-45,[(-55,-46),(-32,-20),(-6,6),(20,32),(46,55)]),('Receiving',45,[(-55,-25),(-11,11),(25,55)])]:
    for j,(x0,x1) in enumerate(segments):
        box(side+'_Wall%02d'%j,((x0+x1)/2,y,7.6),(x1-x0,1,15.2),'Wall','Shell','Wall',.075)
        for n in range(int(x1-x0)//3):
            x=x0+1.5+3*n
            box(side+'_Rib%02d_%02d'%(j,n),(x,y+(-.58 if y<0 else .58),7.6),(.11,.18,14.8),'Wall','Shell','Wall',.018)
    vertices=[(-55,y-.5,15.2),(55,y-.5,15.2),(0,y-.5,22.9),(-55,y+.5,15.2),(55,y+.5,15.2),(0,y+.5,22.9)]
    mesh(side+'_Gable',vertices,[(0,2,1),(3,4,5),(0,1,4,3),(1,2,5,4),(2,0,3,5)],'Wall','Shell','Wall',.03)
    box(side+'_Lintel',(0,y,15.0),(111,1.55,.6),'Pillar','Structure','Pillar')
    for j,x in enumerate((-46,-35,-24,-13,0,13,24,35,46)):
        ht=max(.2,roof_z(x)-15.7)
        box(side+'_GableRib%02d'%j,(x,y+(-.62 if y<0 else .62),15.55+ht/2),(.14,.2,ht),'Wall','Shell','Wall',.02)

for y in (-45,45):
    beam('GableEdgeL',(-57,y,15.6),(0,y,23.1),.6,.6,'Trim','Roof','Trim')
    beam('GableEdgeR',(0,y,23.1),(57,y,15.6),.6,.6,'Trim','Roof','Trim')
for sign in (-1,1):
    for j in range(6):
        ya=-46+j*(92/6); yb=ya+92/6-.04
        xa,xb=(-56,0) if sign<0 else (0,56)
        za,zb=roof_z(xa),roof_z(xb)
        v=[(xa,ya,za),(xb,ya,zb),(xb,yb,zb),(xa,yb,za),(xa,ya,za-.3),(xb,ya,zb-.3),(xb,yb,zb-.3),(xa,yb,za-.3)]
        mesh('Roof_%s_%02d'%('West' if sign<0 else 'East',j+1),v,[(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],'Roof','Roof','Roof',.035)
        beam('StandingSeam', (xa,ya,za+.1),(xb,ya,zb+.1),.1,.13,'Roof','Roof','Roof')
    box('EaveFascia',(sign*56.1,0,15.8),(.5,94,.9),'Trim','Roof','Trim')
    box('RainGutter',(sign*56.8,0,15.45),(.55,93,.45),'Pillar','Roof','Pillar')
    for y in (-42,42):
        cylinder('Downpipe',(sign*56.8,y,7.6),.22,15.0,'Pillar','Structure','Pillar')
box('RidgeCap',(0,0,23.15),(1.2,94,.35),'Trim','Roof','Trim')

for j,y in enumerate((-40,-20,0,20,40)):
    for x in (-53.8,53.8):
        box('Portal_%02d_Foot'%j,(x,y,.4),(2.5,2.5,.8),'Concrete','Structure')
        box('Portal_%02d_Column'%j,(x,y,7.9),(1.25,1.4,15.0),'Pillar','Structure','Pillar')
        box('Portal_%02d_Guard'%j,(x,y,1.7),(1.5,1.65,1.8),'Trim','Structure','Trim')
    beam('Portal_%02d_RafterL'%j,(-54,y,15.5),(0,y,22.3),.7,.8,'Pillar','Structure','Pillar')
    beam('Portal_%02d_RafterR'%j,(0,y,22.3),(54,y,15.5),.7,.8,'Pillar','Structure','Pillar')
    beam('Portal_%02d_Tie'%j,(-54,y,15.5),(54,y,15.5),.45,.45,'Pillar','Structure','Pillar')
    for x in (-27,0,27):
        beam('Portal_%02d_Web'%j,(x,y,15.5),(x,y,roof_z(x)-.7),.22,.25,'Pillar','Structure','Pillar')

for x in (-54.3,54.3):
    box('WallAccent',(x,0,12.65),(.15,89,.35),'Neon','Lighting','Neon',.025)
for j,y in enumerate((-30,-10,10,30)):
    for k,x in enumerate((-30,0,30)):
        box('Light_%d%d_Housing'%(j,k),(x,y,14.8),(8.2,2.2,.45),'Pillar','Lighting','Pillar')
        box('Light_%d%d_Diffuser'%(j,k),(x,y,14.53),(7.6,1.75,.12),'Warm','Lighting',bevel=.02)

print('Shell complete:',len(scene.objects),'objects')
