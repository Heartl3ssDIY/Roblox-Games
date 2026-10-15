import bpy, math, random, numpy as np, bmesh, os
from mathutils import Vector, Matrix
from math import sin, cos, pi
ROOT = r"C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\ACULobbyCitadel"
PALETTE = {
'stone':(.27,.32,.43),'stoneDark':(.065,.085,.16),'stoneLight':(.57,.64,.73),
'wood':(.12,.048,.055),'red':(.62,.028,.065),'roof':(.035,.065,.14),
'purple':(.23,.025,.48),'gold':(.83,.43,.095),'goldLight':(1,.74,.28),
'ivory':(.83,.81,.7),'leaf':(.045,.22,.13),'leafLight':(.18,.42,.21),
'blossom':(.72,.07,.31),'blossomLight':(1,.31,.56),'cyan':(.025,.51,.68),
'cyanGlow':(.09,.8,1),'purpleGlow':(.47,.09,1),'goldGlow':(1,.46,.07),
'water':(.035,.21,.27),'glass':(.07,.2,.31),'rock':(.10,.13,.22),
'moss':(.13,.23,.13),'black':(.013,.018,.036),'holo':(.12,.49,.73)}
MATS={}
KEYS=list(PALETTE)
FONT=None
def init():
    global FONT
    for key,col in PALETTE.items():
        m=bpy.data.materials.get('ACU_'+key) or bpy.data.materials.new('ACU_'+key)
        m.diffuse_color=(*col,1)
        m.use_nodes=True
        bs=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
        bs.inputs['Base Color'].default_value=(*col,1)
        bs.inputs['Roughness'].default_value=.7
        bs.inputs['Metallic'].default_value=.0
        if key in ('gold','goldLight'): bs.inputs['Metallic'].default_value=.65; bs.inputs['Roughness'].default_value=.29
        if key in ('cyanGlow','purpleGlow','goldGlow','holo'):
            bs.inputs['Emission Color'].default_value=(*col,1)
            bs.inputs['Emission Strength'].default_value=2 if key!='holo' else .8
        if key=='water': bs.inputs['Metallic'].default_value=.45; bs.inputs['Roughness'].default_value=.19
        if key=='glass': bs.inputs['Metallic'].default_value=.5; bs.inputs['Roughness'].default_value=.14
        MATS[key]=m
    f=os.path.join(ROOT,'textures','PermanentMarker-Regular.ttf')
    if os.path.exists(f): FONT=bpy.data.fonts.load(f,check_existing=True)
def collection(group):
    name='ACU | '+group
    c=bpy.data.collections.get(name)
    if c is None:
        c=bpy.data.collections.new(name); bpy.context.scene.collection.children.link(c)
    return c
def material(mat):
    return MATS[mat] if isinstance(mat,str) else mat
def mesh(name,verts,faces,mat,group):
    me=bpy.data.meshes.new(name); me.from_pydata(verts,[],faces); me.update()
    bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
    ob=bpy.data.objects.new(name,me); collection(group).objects.link(ob)
    ma=material(mat); me.materials.append(ma)
    ob['ACU_Material']=ma.name.replace('ACU_','')
    # A tiny palette UV island on each polygon keeps the asset fully portable.
    k=KEYS.index(ob['ACU_Material']) if ob['ACU_Material'] in KEYS else 0
    u=(k%8+.5)/8; v=(k//8+.5)/4
    uv=me.uv_layers.new(name='PaletteUV')
    for p in me.polygons:
        for li in p.loop_indices: uv.data[li].uv=(u,v)
    return ob
def box(name,loc,size,mat,group,bevel=0):
    x,y,z=[v/2 for v in size]
    v=[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]
    ob=mesh(name,v,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],mat,group)
    ob.location=loc
    if bevel:
        mod=ob.modifiers.new('Soft crafted edges','BEVEL'); mod.width=bevel; mod.segments=1
    return ob
def cylinder(name,loc,radius,depth,mat,group,vertices=32):
    n=vertices;v=[(radius*cos(2*pi*i/n),radius*sin(2*pi*i/n),z) for z in (-depth/2,depth/2) for i in range(n)]
    f=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    f += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    ob=mesh(name,v,f,mat,group);ob.location=loc;return ob
def ico(name,loc,scale,mat,group,subdivisions=1):
    me=bpy.data.meshes.new(name); bm=bmesh.new()
    bmesh.ops.create_icosphere(bm,subdivisions=subdivisions,radius=1)
    bm.to_mesh(me);bm.free()
    ob=bpy.data.objects.new(name,me);collection(group).objects.link(ob)
    ob.location=loc;ob.scale=scale;ma=material(mat);me.materials.append(ma)
    ob['ACU_Material']=ma.name.replace('ACU_','')
    uv=me.uv_layers.new(name='PaletteUV');k=KEYS.index(ob['ACU_Material']);c=((k%8+.5)/8,(k//8+.5)/4)
    for p in me.polygons:
        for li in p.loop_indices:uv.data[li].uv=c
    return ob
def tube(name,points,radii,mat,group,sides=8):
    pts=[Vector(p) for p in points]
    if isinstance(radii,(int,float)): radii=[radii]*len(pts)
    verts=[]
    for i,p in enumerate(pts):
        d=(pts[min(i+1,len(pts)-1)]-pts[max(i-1,0)]).normalized()
        ref=Vector((0,0,1)) if abs(d.z)<.95 else Vector((0,1,0))
        u=d.cross(ref).normalized();v=d.cross(u).normalized()
        for j in range(sides):
            q=p+max(.001,radii[i])*(cos(2*pi*j/sides)*u+sin(2*pi*j/sides)*v);verts.append(tuple(q))
    f=[tuple(reversed(range(sides))),tuple(range((len(pts)-1)*sides,len(pts)*sides))]
    for i in range(len(pts)-1):
        for j in range(sides):a=i*sides+j;b=i*sides+(j+1)%sides;f.append((a,b,b+sides,a+sides))
    return mesh(name,verts,f,mat,group)
def ring(name,loc,outer,inner,depth,mat,group,segments=64):
    n=segments
    v=[(r*cos(2*pi*i/n),r*sin(2*pi*i/n),z) for z in (-depth/2,depth/2) for r in (outer,inner) for i in range(n)]
    f=[]
    for i in range(n):
        j=(i+1)%n
        f += [(i,j,j+2*n,i+2*n),(i+n,i+3*n,j+3*n,j+n),(i+2*n,j+2*n,j+3*n,i+3*n),(i,i+n,j+n,j)]
    ob=mesh(name,v,f,mat,group);ob.location=loc;return ob
def text(name,body,loc,size,mat,group,rotation=(pi/2,0,0),align='CENTER'):
    cu=bpy.data.curves.new(name,'FONT');cu.body=body;cu.size=size;cu.align_x=align;cu.align_y='CENTER';cu.extrude=.015;cu.bevel_depth=.003
    if FONT:cu.font=FONT
    ob=bpy.data.objects.new(name,cu);collection(group).objects.link(ob);ob.location=loc;ob.rotation_euler=rotation;cu.materials.append(material(mat));ob['ACU_Material']=material(mat).name.replace('ACU_','');return ob
def marker(name,loc,role):
    ob=bpy.data.objects.new(name,None);collection('90_InteractionMarkers').objects.link(ob);ob.location=loc;ob.empty_display_type='ARROWS';ob.empty_display_size=1.5
    ob['ACU_Role']=role;ob['ACU_Wired']=False;return ob
def transform_group(group,offset,angle):
    bpy.context.view_layer.update()
    T=Matrix.Translation(Vector(offset))@Matrix.Rotation(angle,4,'Z')
    for ob in list(collection(group).objects):ob.matrix_world=T@ob.matrix_world
def point_light(name,loc,color,energy=120,radius=2):
    d=bpy.data.lights.new(name,'POINT');d.energy=energy;d.color=color;d.shadow_soft_size=radius
    ob=bpy.data.objects.new(name,d);collection('80_Lighting').objects.link(ob);ob.location=loc;return ob
def path_strip(name,a,b,width,mat='stoneLight',z=1.27):
    a=Vector(a);b=Vector(b);d=b-a;mid=(a+b)/2
    ob=box(name,(mid.x,mid.y,z),(width,d.length,.16),mat,'11_Paths')
    ob.rotation_euler.z=-math.atan2(d.x,d.y)
    return ob
init()

