import bpy, math, random, json, os, bmesh
import numpy as np
from pathlib import Path
from mathutils import Vector, Matrix

OUT = Path(__file__).resolve().parent
OUT.mkdir(exist_ok=True)
random.seed(3545)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for c in list(bpy.data.collections):
    if c.name != 'Collection': bpy.data.collections.remove(c)
scene = bpy.context.scene
scene.unit_settings.system='METRIC'
scene.unit_settings.scale_length=1.0
root=bpy.data.collections.new('HALLOWEEN PROPERTY - editable exterior')
scene.collection.children.link(root)
asset_collections={}
for name in ['House','Fence','Ground and pathways','Trees','Shrubs and groundcover','Small props']:
    col=bpy.data.collections.new(name);root.children.link(col);asset_collections[name]=col
studio=bpy.data.collections.new('Preview cameras and lighting')
scene.collection.children.link(studio)

# A single shared set of maps keeps the exported material portable.
palette=[
 ('Siding',(156,166,165),.85),('Trim',(207,205,187),.76),
 ('Roof',(46,50,52),.93),('RoofVariation',(56,59,58),.90),
 ('Shutter',(54,69,65),.82),('Door',(95,107,97),.80),
 ('DarkGlass',(28,41,46),.20),('WarmGlass',(162,115,63),.30),
 ('Concrete',(130,128,117),.97),('Foundation',(99,102,99),.98),
 ('Fence',(170,178,164),.87),('FenceWorn',(144,154,141),.92),
 ('Bark',(68,57,46),.99),('BarkLight',(84,72,57),.99),
 ('LeafDeep',(42,58,32),.96),('LeafGreen',(62,76,38),.94),
 ('LeafOlive',(86,91,45),.97),('LeafGold',(132,111,56),.93),
 ('LeafBrown',(99,74,44),.98),('Grass',(57,69,38),.99),
 ('DryGrass',(108,107,64),.99),('Earth',(66,57,43),1),
 ('Lawn',(63,72,43),1),('Metal',(38,42,39),.52),
 ('Pumpkin',(172,76,24),.76),('PumpkinShade',(140,57,19),.88),
 ('Lamp',(234,181,105),.35),('Brick',(104,75,59),.98),
 ('Curtain',(162,149,119),1),('Gravel',(111,106,92),.99),
 ('DeadLeaf',(120,83,41),.98),('Moss',(71,81,48),1),
 ('PinkFlower',(142,95,97),.90),('PaleFlower',(154,145,115),.93),
 ('PorchWood',(119,119,103),.89),('Interior',(70,65,55),1),
 ('Gutter',(96,108,105),.55),('Road',(48,50,49),1),
 ('Mortar',(163,161,147),1),('Black',(15,19,17),.90),
]
P={v[0]:i for i,v in enumerate(palette)}
SIZE=2048; CELL=256; PAD=.025
rng=np.random.default_rng(19)
color=np.ones((SIZE,SIZE,4),dtype=np.float32)
rough=np.ones((SIZE,SIZE,4),dtype=np.float32)
norm=np.ones((SIZE,SIZE,4),dtype=np.float32)
norm[:,:,:3]=(.5,.5,1)
for idx,(name,rgb,r) in enumerate(palette):
    x=(idx%8)*CELL; y=(idx//8)*CELL
    yy,xx=np.mgrid[0:CELL,0:CELL]
    coarse=rng.normal(0,1,(16,16)).repeat(16,0).repeat(16,1)
    grain=rng.normal(0,1,(CELL,CELL))
    field=.018*grain+.025*coarse+.018*np.sin(xx*.081+np.sin(yy*.027)*3)
    if name.startswith('Bark'):
        field+=.10*np.sin(xx*.18+3*np.sin(yy*.029))+ .04*np.sin(xx*.6+yy*.01)
    if name in ('Siding','Trim','Door','Fence','FenceWorn','PorchWood','Shutter'):
        field+=.017*np.sin(yy*.45+np.sin(xx*.013)*2)
    if name.startswith('Leaf') or name=='DeadLeaf':
        field+=.045*np.cos(xx*.02)+.025*np.sin(yy*.2+xx*.1)
    base=np.array(rgb)/255
    color[y:y+CELL,x:x+CELL,:3]=np.clip(base[None,None,:]*(1+field[:,:,None]),0,1)
    rough[y:y+CELL,x:x+CELL,:3]=np.clip(r+field[:,:,None]*.08,0,1)
    gy,gx=np.gradient(field)
    norm[y:y+CELL,x:x+CELL,0]=np.clip(.5-gx*.6,.05,.95)
    norm[y:y+CELL,x:x+CELL,1]=np.clip(.5-gy*.6,.05,.95)

def image_map(name,array,noncolor=False):
    img=bpy.data.images.new(name,width=SIZE,height=SIZE,alpha=True)
    if noncolor: img.colorspace_settings.name='Non-Color'
    img.pixels.foreach_set(array.ravel())
    img.filepath_raw=str(OUT/(name+'.png')); img.file_format='PNG'; img.save(); img.pack()
    return img
albedo=image_map('Property_Albedo',color)
roughness=image_map('Property_Roughness',rough,True)
normal=image_map('Property_Normal',norm,True)
mat=bpy.data.materials.new('Property surfaces - shared texture atlas')
mat.use_nodes=True
nt=mat.node_tree; bs=nt.nodes.get('Principled BSDF')
for img,slot in [(albedo,'Base Color'),(roughness,'Roughness')]:
    n=nt.nodes.new('ShaderNodeTexImage'); n.image=img
    nt.links.new(n.outputs['Color'],bs.inputs[slot])
n=nt.nodes.new('ShaderNodeTexImage');n.image=normal
nm=nt.nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.3
nt.links.new(n.outputs['Color'],nm.inputs['Color']);nt.links.new(nm.outputs['Normal'],bs.inputs['Normal'])

class Mesh:
    def __init__(self,name): self.name=name;self.v=[];self.f=[];self.p=[];self.s=[];self.components=[]
    def add(self,verts,faces,pal,smooth=False):
        self.components.append(list(range(len(self.f),len(self.f)+len(faces))))
        off=len(self.v);self.v.extend(tuple(v) for v in verts)
        self.f.extend(tuple(off+i for i in f) for f in faces)
        self.p.extend([P[pal] if isinstance(pal,str) else pal]*len(faces));self.s.extend([smooth]*len(faces))
    def box(self,c,d,pal,rot=None):
        c=Vector(c);dx,dy,dz=[q*.5 for q in d]
        verts=[Vector((x,y,z)) for x,y,z in [(-dx,-dy,-dz),(dx,-dy,-dz),(dx,dy,-dz),(-dx,dy,-dz),(-dx,-dy,dz),(dx,-dy,dz),(dx,dy,dz),(-dx,dy,dz)]]
        if rot:verts=[rot@v for v in verts]
        self.add([c+v for v in verts],[(0,3,2,1),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)],pal)
    def tube(self,a,b,r1,r2,pal,sides=8):
        a,b=Vector(a),Vector(b);axis=(b-a).normalized()
        u=axis.cross(Vector((0,0,1)))
        if u.length<.01:u=axis.cross(Vector((0,1,0)))
        u.normalize();v=axis.cross(u).normalized()
        vv=[c+r*(u*math.cos(i*2*math.pi/sides)+v*math.sin(i*2*math.pi/sides)) for c,r in ((a,r1),(b,r2)) for i in range(sides)]
        ff=[tuple(reversed(range(sides))),tuple(range(sides,2*sides))]
        ff +=[(i,(i+1)%sides,(i+1)%sides+sides,i+sides) for i in range(sides)]
        self.add(vv,ff,pal,True)
    def beam(self,a,b,width,depth,pal):
        a,b=Vector(a),Vector(b)
        rot=(b-a).to_track_quat('Z','Y').to_matrix()
        self.box((a+b)/2,(width,depth,(b-a).length),pal,rot)
    def ellipsoid(self,c,scale,pal,segments=12,rings=6,phase=0):
        c=Vector(c);sx,sy,sz=scale
        vv=[c+Vector((0,0,-sz)),c+Vector((0,0,sz))]
        for j in range(1,rings):
            ph=-math.pi/2+math.pi*j/rings
            for i in range(segments):
                t=i*2*math.pi/segments
                wob=1+.04*math.cos(t*7+phase)
                vv.append(c+Vector((sx*math.cos(ph)*math.cos(t)*wob,sy*math.cos(ph)*math.sin(t)*wob,sz*math.sin(ph))))
        ff=[]
        for i in range(segments):
            k=(i+1)%segments
            ff.append((0,2+k,2+i))
            ff.append((1,2+(rings-2)*segments+i,2+(rings-2)*segments+k))
        for j in range(rings-2):
            for i in range(segments):
                k=(i+1)%segments;a=2+j*segments;b=a+segments
                ff.append((a+i,a+k,b+k,b+i))
        self.add(vv,ff,pal,True)
    def leaf(self,c,length,width,pal,rotation=None):
        # A closed, thin folded leaf: no alpha textures or exposed backfaces.
        rot=rotation or Matrix.Rotation(random.random()*math.tau,3,'Z')@Matrix.Rotation(random.uniform(-1.1,1.1),3,'X')
        ring=[(0,-length*.5,0),(width*.43,-length*.19,0),(width*.5,length*.13,0),(0,length*.5,0),(-width*.5,length*.13,0),(-width*.43,-length*.19,0)]
        vv=[Vector(c)+rot@Vector(v) for v in ring+[(0,0,width*.10),(0,0,-max(.0015,width*.025))]]
        ff=[]
        for i in range(6):ff.extend([(6,i,(i+1)%6),(7,(i+1)%6,i)])
        self.add(vv,ff,pal)
    def finish(self,coll=root):
        if coll==root:
            group=('Trees' if self.name.startswith('Tree_') else
                   'Fence' if self.name.startswith('Fence_') else
                   'Ground and pathways' if self.name.startswith(('Ground_','Paths_')) else
                   'Shrubs and groundcover' if self.name.startswith(('Shrubs_','Grass_','Fallen_','Small_Flowering')) else
                   'Small props' if self.name.startswith('Porch_Pumpkins') else 'House')
            coll=asset_collections[group]
        # Split at component boundaries to stay under Roblox's per-mesh limit.
        chunks=[];cur=[];n=0
        for component in self.components:
            t=sum(len(self.f[i])-2 for i in component)
            if n+t>16500:chunks.append(cur);cur=[];n=0
            cur.extend(component);n+=t
        if cur:chunks.append(cur)
        objects=[]
        for part,indices in enumerate(chunks):
            used=sorted({v for i in indices for v in self.f[i]});remap={v:j for j,v in enumerate(used)}
            verts=[self.v[v] for v in used];faces=[tuple(remap[v] for v in self.f[i]) for i in indices]
            name=self.name+(f'_{part+1:02d}' if len(chunks)>1 else '')
            me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
            obj=bpy.data.objects.new(name,me);coll.objects.link(obj);me.materials.append(mat)
            uv=me.uv_layers.new(name='PropertyUV')
            for poly,src in zip(me.polygons,indices):
                idx=self.p[src];col=idx%8;row=idx//8
                points=[Vector(verts[vi]) for vi in poly.vertices]
                normal=poly.normal;drop=max(range(3),key=lambda j:abs(normal[j]));axes=[j for j in range(3) if j!=drop]
                lo=[min(v[a] for v in points) for a in axes];hi=[max(v[a] for v in points) for a in axes]
                for li,v in zip(poly.loop_indices,points):
                    u=(v[axes[0]]-lo[0])/max(hi[0]-lo[0],1e-7)
                    w=(v[axes[1]]-lo[1])/max(hi[1]-lo[1],1e-7)
                    uv.data[li].uv=((col+PAD+(1-2*PAD)*u)/8,(row+PAD+(1-2*PAD)*w)/8)
                poly.use_smooth=self.s[src]
            # Face orientation is repaired before export; texture UVs remain attached.
            bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
            obj['asset_group']=self.name;obj['reference']='YouTube Bc1hwOcs0JU at 3:35; approximate exterior reconstruction'
            objects.append(obj)
        return objects

# Dimensions in metres. Front of the property faces negative Y.
ground=Mesh('Ground_Lawn_and_PlantingBeds')
ground.box((0,0,-.24),(25,27,.48),'Earth')
ground.box((0,0,.015),(24.8,26.8,.055),'Lawn')
for c,d in [((-4.7,-3.9,.07),(4.4,2,.08)),((4.5,-3.5,.07),(4,2,.08)),((-10,2,.07),(2.9,19,.08)),((10,2,.07),(2.7,19,.08))]:ground.box(c,d,'Earth')
ground.finish()
hard=Mesh('Paths_Steps_Sidewalk')
for x in range(-12,12,2):hard.box((x+1,-12.5,.06),(1.98,1.7,.17),'Concrete')
for y in np.arange(-11.1,-4.1,1.25):hard.box((-.3,float(y),.085),(1.85,1.22,.17),'Concrete')
hard.box((0,-13.38,.01),(25,.18,.24),'Concrete')
for i in range(3):hard.box((-.3,-4.7+i*.34,.15+i*.15),(2,.70,.30+i*.30),'Concrete')
hard.box((0,-14.9,-.12),(25,2.8,.23),'Road')
hard.finish()

foundation=Mesh('House_Foundation_and_Floor')
foundation.box((0,2.5,.25),(14,9,.5),'Foundation')
foundation.box((0,2.5,.56),(13.6,8.6,.12),'Interior')
foundation.box((-2.8,-3.15,.28),(8.4,2.35,.56),'Foundation')
foundation.box((-2.8,-3.15,.59),(8.6,2.45,.12),'PorchWood')
foundation.finish()

walls=Mesh('House_Exterior_Walls')
# Actual openings in the front wall; window inserts seal them for the exterior shell.
front_openings=[(-5.6,-3.9,1.28,2.96),(-1.15,.05,.60,2.91),(2.1,4.3,1.30,2.90)]
def wall_courses(y,front=True):
    z=.62
    while z<3.8:
        h=min(.17,3.8-z);mid=z+h/2
        cuts=[(-7,7)]
        if front:
            for a,b,bottom,top in front_openings:
                if bottom<mid<top:
                    new=[]
                    for l,r in cuts:
                        if l<a<r:new.append((l,a))
                        if l<b<r:new.append((b,r))
                        if b<=l or a>=r:new.append((l,r))
                    cuts=new
        for l,r in cuts:
            if r-l>.01:walls.box(((l+r)/2,y,mid),(r-l,.18,h-.008),'Siding')
        z+=.17
wall_courses(-2,True);wall_courses(7,False)
for x in (-7,7):
    for z in np.arange(.62,3.79,.17):walls.box((x,2.5,float(z)+.08),(.18,9,.16),'Siding')
# Triangular gables at the ends of the long ridge.
for x in (-7,7):
    walls.add([(x-.08,-2,3.8),(x-.08,7,3.8),(x-.08,2.5,5.65),(x+.08,-2,3.8),(x+.08,7,3.8),(x+.08,2.5,5.65)],[(0,2,1),(3,4,5),(0,1,4,3),(1,2,5,4),(2,0,3,5)],'Siding')
walls.finish()
trim=Mesh('House_Corner_Trim_and_Eaves')
for x in (-7.08,7.08):
    for y in (-2.07,7.07):trim.box((x,y,2.19),(.15,.15,3.3),'Trim')
for y in (-2.3,7.3):trim.box((0,y,3.79),(14.8,.15,.22),'Trim')
for x in (-7.35,7.35):
    trim.beam((x,-2.4,3.83),(x,2.5,5.74),.17,.17,'Trim')
    trim.beam((x,2.5,5.74),(x,7.4,3.83),.17,.17,'Trim')
trim.finish()

roof=Mesh('House_Roof_Shingles')
angle=math.atan2(1.85,4.9);length=math.hypot(1.85,4.9)
for side in (-1,1):
    rot=Matrix.Rotation(-side*angle,3,'X')
    roof.box((0,2.5+side*2.45,4.72),(14.9,length,.12),'Roof',rot)
    # Overlapping shingle rows remain visible at gameplay distance.
    for row in range(17):
        f=(row+.5)/17;y=2.5+side*(4.94-f*4.94);z=3.8+f*1.88+.10
        for k in range(25):
            x=-7.38+(k+.5)*.591+(row%2)*.12
            if x>7.38:continue
            roof.box((x,y,z),(.584,length/17+.035,.024),random.choice(['Roof','Roof','RoofVariation']),rot)
roof.box((0,2.5,5.78),(14.93,.24,.11),'RoofVariation')
roof.finish()
porch=Mesh('Porch_Roof_and_Railings')
porch.box((-2.8,-3.2,3.38),(8.95,2.8,.15),'Roof',Matrix.Rotation(.10,3,'X'))
porch.box((-2.8,-4.62,3.23),(8.96,.16,.23),'Trim')
for x in (-7.10,1.48):
    porch.box((x,-3.2,3.36),(.17,2.9,.2),'Trim',Matrix.Rotation(.10,3,'X'))
for x in (-6.75,1.15):
    porch.box((x,-4.3,1.95),(.18,.18,2.64),'Trim')
    porch.box((x,-4.3,.76),(.29,.29,.22),'Trim')
    porch.box((x,-4.3,3.07),(.32,.32,.17),'Trim')
def railing(a,b):
    a,b=Vector(a),Vector(b);d=b-a
    for z in (.78,1.51):porch.beam(a+Vector((0,0,z)),b+Vector((0,0,z)),.09,.09,'Trim')
    for t in np.linspace(.05,.95,max(2,int(d.length/.19))):
        p=a+d*float(t);porch.box((p.x,p.y,1.15),(.055,.055,.70),'Trim')
railing((-6.75,-4.3,0),(-1.5,-4.3,0));railing((.8,-4.3,0),(1.15,-4.3,0))
railing((-6.75,-4.3,0),(-6.75,-2,0));railing((1.15,-4.3,0),(1.15,-2,0))
for i in range(21):porch.box((-6.95+i*.415,-3.2,.66),(.407,2.32,.035),'PorchWood')
porch.finish()

windows=Mesh('Windows_Frames_Shutters_and_Curtains')
def window(cx,y,cz,width,height,warm=False,side=False):
    local=Mesh('temp');local.box((0,0,0),(width,.065,height),'WarmGlass' if warm else 'DarkGlass')
    for x in (-width/2,width/2):local.box((x,-.06,0),(.095,.13,height+.18),'Trim')
    for z in (-height/2,height/2):local.box((0,-.06,z),(width+.18,.13,.095),'Trim')
    local.box((0,-.115,0),(.055,.07,height),'Trim')
    local.box((0,-.115,.1),(width,.07,.055),'Trim')
    local.box((0,-.16,-height/2-.09),(width+.32,.30,.09),'Trim')
    for sign in (-1,1):
        sx=sign*(width/2+.30)
        local.box((sx,.01,0),(.39,.095,height+.11),'Shutter')
        for iz in np.arange(-height/2+.07,height/2,.13):local.box((sx,-.055,float(iz)),(.32,.085,.058),'Shutter',Matrix.Rotation(.35,3,'X'))
    # Subtle interior curtains behind the reflective panes.
    for x in (-width*.36,width*.36):local.box((x,.065,0),(width*.19,.025,height*.91),'Curtain')
    rot=Matrix.Rotation(math.pi/2 if side else 0,3,'Z')
    windows.add([Vector((cx,y,cz))+rot@Vector(v) for v in local.v],local.f,0)
    windows.p[-len(local.p):]=local.p
window(-4.75,-2.13,2.12,1.65,1.66)
window(3.2,-2.13,2.1,2.16,1.56,True)
window(7.14,1,2.1,1.5,1.6,False,True)
window(7.14,4.8,2.1,1.45,1.55,True,True)
windows.finish()
door=Mesh('Front_Door_and_Details')
door.box((-.55,-2.055,1.755),(1.19,.09,2.3),'Door')
for z in (1.0,1.66,2.42):
    for x in (-.84,-.28):door.box((x,-2.12,z),(.43,.025,.48),'Shutter')
for x in (-1.22,.12):door.box((x,-2.14,1.77),(.12,.15,2.48),'Trim')
door.box((-.55,-2.14,3.0),(1.46,.15,.12),'Trim')
door.ellipsoid((-.08,-2.23,1.6),(.037,.065,.037),'Metal',8,4)
door.box((.59,-2.13,2.05),(.4,.16,.34),'Metal')
door.box((.59,-2.21,2.22),(.44,.16,.06),'Metal')
door.box((-.55,-2.9,.685),(.87,.51,.024),'Earth')
door.finish()

details=Mesh('Gutters_Chimney_and_Vents')
for y in (-2.36,7.36):details.tube((-7.3,y,3.74),(7.3,y,3.74),.057,.057,'Gutter',10)
for x,y in ((7.22,-2.36),(-7.22,7.36)):
    details.tube((x,y,.35),(x,y,3.70),.047,.047,'Gutter',8)
    details.tube((x,y,.35),(x,y-.36,.16),.047,.047,'Gutter',8)
details.box((4.8,4.8,5.30),(.85,.82,2.1),'Mortar')
for z in np.arange(4.28,6.30,.18):
    for x in (-.23,.23):
        for y in (-.435,.435):details.box((4.8+x,4.8+y,float(z)),(.43,.055,.162),'Brick')
    for x in (-.455,.455):details.box((4.8+x,4.8,float(z)),(.055,.82,.162),'Brick')
details.box((4.8,4.8,6.34),(1.03,1.0,.14),'Concrete')
details.box((4.8,4.8,6.425),(.54,.50,.045),'Black')
for x in (-7.15,7.15):
    for z in np.arange(4.15,4.6,.10):details.box((x,2.5,float(z)),(.08,.55,.04),'Shutter')
details.finish()

fence=Mesh('Fence_Front_Panels_and_Gateposts')
sidefence=Mesh('Fence_Side_and_Back_Panels')
def fence_run(mesh,a,b,gate=False):
    a,b=Vector(a),Vector(b);d=b-a;L=d.length;u=d/L;n=Vector((-u.y,u.x,0))
    angle=math.atan2(u.y,u.x);rot=Matrix.Rotation(angle,3,'Z')
    segments=max(1,round(L/2.1))
    for k in range(segments+1):
        p=a+d*k/segments;mesh.box(p+Vector((0,0,.64)),(.14,.14,1.28),'Fence',rot)
        mesh.box(p+Vector((0,0,1.28)),(.20,.20,.075),'Trim',rot)
    for z in (.38,.88):mesh.box((a+b)/2+Vector((0,0,z)),(L,.07,.105),'FenceWorn',rot)
    for t in np.arange(.08,L,.155):
        p=a+u*float(t)+n*.06;h=1.15+random.uniform(-.024,.024)
        vv=[(-.05,-.024,.13),(.05,-.024,.13),(.05,-.024,h-.08),(0,-.024,h),(-.05,-.024,h-.08),(-.05,.024,.13),(.05,.024,.13),(.05,.024,h-.08),(0,.024,h),(-.05,.024,h-.08)]
        faces=[(0,4,3,2,1),(5,6,7,8,9)]+[(i,(i+1)%5,(i+1)%5+5,i+5) for i in range(5)]
        mesh.add([p+rot@Vector(v) for v in vv],faces,random.choice(['Fence','Fence','FenceWorn']))
fence_run(fence,(-11.4,-10.9,0),(-1.35,-10.9,0))
fence_run(fence,(.8,-10.9,0),(11.4,-10.9,0))
fence.finish()
fence_run(sidefence,(-11.4,-10.9,0),(-11.4,11.5,0))
fence_run(sidefence,(11.4,-10.9,0),(11.4,11.5,0))
fence_run(sidefence,(-11.4,11.5,0),(11.4,11.5,0))
sidefence.finish()

lamps=Mesh('Porch_Lanterns')
def light(name,kind,location,color,energy,size=1):
    dat=bpy.data.lights.new(name,kind);dat.energy=energy;dat.color=color
    if kind=='AREA':dat.shape='DISK';dat.size=size
    if kind=='POINT':dat.shadow_soft_size=size
    obj=bpy.data.objects.new(name,dat);studio.objects.link(obj);obj.location=location
    return obj
for x in (-1.6,.65):
    lamps.box((x,-2.19,2.61),(.18,.11,.37),'Metal')
    lamps.box((x,-2.36,2.60),(.19,.20,.27),'Lamp')
    for xx in (-.12,.12):lamps.box((x+xx,-2.36,2.6),(.025,.24,.33),'Metal')
    for z in (2.41,2.79):lamps.box((x,-2.36,z),(.31,.29,.065),'Metal')
    light('Porch light '+str(x),'POINT',(x,-2.75,2.6),(1,.58,.25),35,.18)
lamps.finish()

def tree(name,position,height,radius,seed):
    rr=random.Random(seed);base=Vector(position)
    bark=Mesh(name+'_Branches');leaves=Mesh(name+'_Leaves')
    points=[base+Vector((.18*math.sin(i*.7),.13*math.sin(i),height*i/7)) for i in range(8)]
    # Continuous trunk rings avoid the bands and joints of stacked cylinders.
    trunk=[];trunkfaces=[];sides=12
    for j,point in enumerate(points):
        for i in range(sides):
            angle=i*math.tau/sides
            rad=radius*(1-j*.115)*(1+.05*math.sin(i*2.9+j*.2))
            trunk.append(point+Vector((math.cos(angle)*rad,math.sin(angle)*rad,0)))
    trunkfaces=[tuple(reversed(range(sides))),tuple(range(7*sides,8*sides))]
    for j in range(7):
        for i in range(sides):
            a=j*sides+i;b=j*sides+(i+1)%sides
            trunkfaces.append((a,b,b+sides,a+sides))
    bark.add(trunk,trunkfaces,'Bark',True)
    for k in range(7):
        ang=k*math.tau/7+.2
        end=base+Vector((math.cos(ang)*radius*3.6,math.sin(ang)*radius*3.6,.035))
        bark.tube(base+Vector((0,0,.24)),end,radius*.45,.04,'Bark',8)
    crown_points=[]
    for k in range(15):
        ang=k*2.4+rr.uniform(-.25,.25);z=height*rr.uniform(.30,.82)
        reach=height*rr.uniform(.29,.47)*(1-.4*z/height)
        start=base+Vector((0,0,z))
        elbow=start+Vector((math.cos(ang)*reach*.50,math.sin(ang)*reach*.5,height*.16))
        end=start+Vector((math.cos(ang)*reach,math.sin(ang)*reach,height*.26))
        bark.tube(start,elbow,radius*.36,radius*.17,'Bark',8)
        bark.tube(elbow,end,radius*.17,.035,'Bark',7)
        for twig in range(5):
            aa=ang+rr.uniform(-1,1);p=elbow.lerp(end,rr.uniform(.3,.9))
            q=p+Vector((math.cos(aa)*rr.uniform(.65,1.6),math.sin(aa)*rr.uniform(.65,1.6),rr.uniform(.3,1.4)))
            bark.tube(p,q,.034,.008,'BarkLight',6);crown_points.append(q)
    for center in crown_points:
        for spray in range(7):
            aa=rr.random()*math.tau
            end=center+Vector((math.cos(aa)*rr.uniform(.45,.95),math.sin(aa)*rr.uniform(.45,.95),rr.uniform(-.16,.53)))
            bark.tube(center,end,.010,.0025,'Bark',5)
            for j in range(5):
                p=center.lerp(end,(j+1)/5)
                size=rr.uniform(.19,.33)
                # Each leaf grows from a twig instead of floating in a volume.
                rot=Matrix.Rotation(aa+(-1 if j%2 else 1)*.75,3,'Z')@Matrix.Rotation(rr.uniform(-.6,.65),3,'X')
                centerleaf=p+rot@Vector((0,size*.43,0))
                leaves.leaf(centerleaf,size,size*.56,rr.choices(['LeafDeep','LeafGreen','LeafOlive','LeafGold','LeafBrown'],[2,5,6,2,1])[0],rot)
    bark.finish();leaves.finish()
tree('Tree_A_Front_Left',(-5.8,-7.3,.08),9.8,.31,3)
tree('Tree_B_Front_Right',(6.7,-6.2,.08),10.9,.38,32)
tree('Tree_C_Back_Left',(-9.6,6.8,.08),10.0,.34,85)
tree('Tree_D_Back_Right',(9.7,9.1,.08),8.8,.27,71)

shrubs=Mesh('Shrubs_Layered_Foundation_and_Fence')
def bush(c,size,count=200):
    c=Vector(c);sx,sy,sz=size
    for i in range(6):
        a=random.random()*math.tau
        shrubs.tube(c-Vector((0,0,sz*.6)),c+Vector((math.cos(a)*sx*.6,math.sin(a)*sy*.6,sz*.5)),.022,.009,'Bark',5)
    for i in range(count):
        phi=random.random()*math.tau;v=random.uniform(-.9,1);r=math.sqrt(1-v*v);s=random.random()**.22
        p=c+Vector((sx*math.cos(phi)*r*s,sy*math.sin(phi)*r*s,sz*v*s))
        l=random.uniform(.11,.25)
        shrubs.leaf(p,l,l*.65,random.choice(['LeafDeep','LeafGreen','LeafGreen','LeafOlive']))
for x,y,s in [(-5.5,-5.0,1.0),(-3.7,-5.0,.85),(3.0,-3.0,1.05),(5.1,-3.0,.9),(-8,-2,1.1),(8,1,1.1),(-8.6,-9.9,.75),(3.3,-10,.75),(5,-10,.65),(9.8,-8,.95),(-9.9,0,1),(9.9,5,1.0),(-10,9,1)]:
    bush((x,y,.52*s),(s,.70*s,.6*s),280)
shrubs.finish()
flowers=Mesh('Small_Flowering_Plants')
for cx,cy in [(-2.4,-4.9),(2,-3.5),(4.2,-10.2),(-8.7,-9.9)]:
    for k in range(13):
        x=cx+random.uniform(-.5,.5);y=cy+random.uniform(-.4,.4);z=random.uniform(.3,.75)
        flowers.tube((x,y,.08),(x,y,z),.007,.004,'LeafDeep',5)
        for j in range(5):
            a=j*math.tau/5
            flowers.leaf((x+math.cos(a)*.03,y+math.sin(a)*.03,z),.075,.045,random.choice(['PinkFlower','PaleFlower']),Matrix.Rotation(a,3,'Z'))
flowers.finish()

grass=Mesh('Grass_Tufts_and_Wild_Groundcover')
for i in range(1550):
    x=random.uniform(-11.2,11.2);y=random.uniform(-10.65,11.4)
    if -7.4<x<7.5 and -4.8<y<7.6:continue
    if -1.4<x<.85 and y<-4.5:continue
    for k in range(random.randint(3,5)):
        a=random.random()*math.tau;h=random.uniform(.07,.28);w=random.uniform(.008,.02)
        p=Vector((x+random.uniform(-.08,.08),y+random.uniform(-.08,.08),.075))
        u=Vector((math.cos(a),math.sin(a),0));tip=p+u*h*.4+Vector((0,0,h))
        grass.add([p-u*w,p+u*w,p+Vector((0,.007,.008)),tip],[(0,1,2),(0,3,1),(1,3,2),(2,3,0)],random.choice(['Grass','Grass','DryGrass']))
grass.finish()
litter=Mesh('Fallen_Leaves_and_Edge_Stones')
for i in range(900):
    if i<600:
        cx,cy=random.choice([(-5.8,-7.3),(6.7,-6.2),(-9.6,6.8),(9.7,9.1)])
        x=random.gauss(cx,1.7);y=random.gauss(cy,1.5)
    else:x=random.uniform(-11,11);y=random.uniform(-12.7,10.8)
    if abs(x)>12 or y>12 or y<-13:continue
    if -7.3<x<7.3 and -4.8<y<7.4:continue
    z=.17 if y<-11.6 or (-1.3<x<.8 and y<-4.5) else .085
    l=random.uniform(.10,.19);rot=Matrix.Rotation(random.random()*math.tau,3,'Z')@Matrix.Rotation(random.uniform(-.12,.12),3,'X')
    litter.leaf((x,y,z),l,l*.56,random.choice(['DeadLeaf','LeafGold','LeafBrown']),rot)
for i in range(55):
    x=random.choice([-1.4,.84])+random.uniform(-.03,.03);y=random.uniform(-10.8,-5)
    litter.ellipsoid((x,y,.1),(.08,.095,.055),'Gravel',7,4,random.random())
litter.finish()

props=Mesh('Porch_Pumpkins_and_Pots')
for x,y,s in [(-1.95,-4.13,.24),(1.21,-4.7,.30),(1.73,-10.1,.32),(2.29,-10.03,.23)]:
    z=.67 if y>-4.4 else .085
    props.ellipsoid((x,y,z+s*.75),(s,s*.87,s*.75),'Pumpkin',20,10)
    for j in range(9):
        a=j*math.tau/9;props.ellipsoid((x+math.cos(a)*s*.19,y+math.sin(a)*s*.19,z+s*.76),(s*.80,s*.72,s*.69),'PumpkinShade' if j%4==0 else 'Pumpkin',10,7)
    props.tube((x,y,z+s*1.43),(x+.035,y,z+s*1.72),.038,.022,'Bark',7)
props.finish()

# Neutral preview staging is deliberately excluded from the game exports.
stage=Mesh('Preview_only_floor');stage.box((0,0,-.53),(200,200,.1),'Road');stage.finish(studio)
world=bpy.data.worlds.new('Soft overcast evening');scene.world=world;world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.16,.20,.25,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.55
sun=light('Soft daylight','SUN',(0,0,12),(1,.84,.66),2.3)
sun.rotation_euler=(math.radians(28),math.radians(-23),math.radians(-32));sun.data.angle=.15
fill=light('Sky fill','AREA',(1,-5,15),(.56,.69,1),1600,20)
key=light('Façade fill','AREA',(-4,-13,9),(1,.84,.68),1100,13)
key.rotation_euler=(Vector((0,1,2))-key.location).to_track_quat('-Z','Y').to_euler()
camera_data=bpy.data.cameras.new('Property camera');camera=bpy.data.objects.new('Property camera',camera_data);studio.objects.link(camera);scene.camera=camera
def camera_at(pos,target,lens=47):
    camera.location=pos;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.lens=lens
camera_at((23,-35,20),(0,-.3,3),44)
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
try:
    cp=bpy.context.preferences.addons['cycles'].preferences
    cp.compute_device_type='OPTIX';cp.get_devices()
    available=[d for d in cp.devices if d.type=='OPTIX']
    if available:
        for d in cp.devices:d.use=d.type=='OPTIX'
        scene.cycles.device='GPU'
except Exception:pass
scene.render.resolution_x=1600;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.view_settings.view_transform='AgX'
scene.view_settings.exposure=.3
scene.render.film_transparent=False
scene.render.image_settings.color_mode='RGB'

models=[o for o in root.all_objects if o.type=='MESH']
# Triangulate without changing any dimensions; all export origins remain at lot centre.
report=[]
for o in models:
    bpy.context.view_layer.objects.active=o
    mod=o.modifiers.new('Export triangles','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=mod.name)
    bm=bmesh.new();bm.from_mesh(o.data)
    bad=sum(f.calc_area()<1e-12 for f in bm.faces);boundary=sum(e.is_boundary for e in bm.edges);bm.free()
    report.append({'name':o.name,'triangles':len(o.data.polygons),'vertices':len(o.data.vertices),'degenerateFaces':bad,'boundaryEdges':boundary})
assert max(x['triangles'] for x in report)<20000
assert not any(x['degenerateFaces'] for x in report),[x for x in report if x['degenerateFaces']]
assert not any(x['boundaryEdges'] for x in report),[x for x in report if x['boundaryEdges']]
# Large foliage groups may be split across object boundaries at export; faces are intact.
summary={'reference':'https://www.youtube.com/watch?v=Bc1hwOcs0JU&t=215s','interpretation':'Original exterior reconstruction from dark video frames at 3:35 and 3:45. Back elevation, dimensions and obscured details are inferred.','units':'metres','lotDimensionsMetres':[25,29.8],'houseFootprintMetres':[14,9],'interior':'Exterior shell with closed front door; no furnished or playable interior.','meshCount':len(models),'triangles':sum(x['triangles'] for x in report),'maxMeshTriangles':max(x['triangles'] for x in report),'parts':report}
(OUT/'Model_Report.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
bpy.ops.object.select_all(action='DESELECT')
for o in models:o.select_set(True)
bpy.context.view_layer.objects.active=models[0]
bpy.ops.export_scene.fbx(filepath=str(OUT/'Halloween_Property.fbx'),use_selection=True,object_types={'MESH'},apply_scale_options='FBX_SCALE_UNITS',axis_forward='-Z',axis_up='Y',add_leaf_bones=False,bake_anim=False,path_mode='COPY',embed_textures=True,use_custom_props=True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'Halloween_Property.glb'),export_format='GLB',use_selection=True,export_yup=True,export_extras=True)
bpy.ops.object.select_all(action='DESELECT')
# Set the saved viewport to show the entire scene on first open.
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_distance=38
        area.spaces.active.region_3d.view_location=(0,0,3)
        area.spaces.active.region_3d.view_rotation=camera.rotation_euler.to_quaternion()
        area.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Halloween_Property.blend'))
print('EXPORT_COMPLETE '+json.dumps({k:v for k,v in summary.items() if k!='parts'}),flush=True)
scene.render.filepath=str(OUT/'Property_Daylight.png');bpy.ops.render.render(write_still=True)
camera_at((.5,-32,6.3),(0,-.3,3.7),40)
scene.render.filepath=str(OUT/'Property_Front.png');bpy.ops.render.render(write_still=True)
sun.data.energy=.06;fill.data.energy=360;key.data.energy=130
world.node_tree.nodes['Background'].inputs[1].default_value=.09
scene.view_settings.look='AgX - Medium High Contrast'
scene.render.filepath=str(OUT/'Property_Night.png');bpy.ops.render.render(write_still=True)
print('ALL_RENDERS_COMPLETE',flush=True)
