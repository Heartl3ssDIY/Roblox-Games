import bpy, math, random, json, os, bmesh
from mathutils import Vector
from math import sin, cos, pi

OUT = r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\CatInTheHat'
random.seed(19)
scene = bpy.context.scene
if bpy.context.object and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
# Retain the starting scene in a hidden collection.
archive = bpy.data.collections.new('Original scene - preserved')
scene.collection.children.link(archive)
for o in list(scene.objects):
    for c in list(o.users_collection): c.objects.unlink(o)
    archive.objects.link(o)
archive.hide_render = True
archive.hide_viewport = True
root = bpy.data.collections.new('CAT IN THE HAT - editable base')
scene.collection.children.link(root)
collections = {}
for label in ['01 Body', '02 Face', '03 Hat', '04 Bow tie', '05 Gloves', '06 Tail']:
    c = bpy.data.collections.new(label)
    root.children.link(c)
    collections[label] = c

def mat(name, color, roughness=.65):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value = roughness
    return m

fur = mat('Fur - charcoal black', (.018,.022,.027), .88)
white = mat('Fur - warm white', (.84,.82,.75), .84)
red = mat('Hat - crimson', (.55,.014,.03), .68)
hatwhite = mat('Hat - ivory bands', (.93,.9,.8), .7)
bowred = mat('Bow - rich red', (.59,.016,.035), .6)
glovewhite = mat('Gloves - soft white', (.93,.91,.85), .68)
seammat = mat('Gloves - seam ivory', (.67,.65,.59), .78)
black = mat('Face - ink', (.007,.008,.01), .65)
eye = mat('Eyes - whites', (.9,.85,.74), .32)
iris = mat('Eyes - amber hazel', (.18,.085,.025), .35)
nosemat = mat('Nose - muted rose', (.27,.057,.059), .57)
inner = mat('Ears - warm grey', (.20,.17,.17), .9)
mouthmat = mat('Mouth - shadow', (.048,.007,.012), .74)
teeth = mat('Smile - ivory', (.86,.83,.74), .4)

def adopt(o, name, material, group, bone=None):
    o.name = name
    for c in list(o.users_collection): c.objects.unlink(o)
    collections[group].objects.link(o)
    if material:
        o.data.materials.clear()
        o.data.materials.append(material)
        o['RecolorRegion'] = material.name
    if bone: o['AttachTo'] = bone
    o['Asset'] = 'CatInTheHat_Base'
    return o

def mesh(name, verts, faces, material, group='01 Body', bone=None, smooth=True):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    bm=bmesh.new(); bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(me); bm.free()
    o=bpy.data.objects.new(name,me)
    collections[group].objects.link(o)
    adopt(o,name,material,group,bone)
    for p in me.polygons: p.use_smooth=smooth
    return o

def uvball(name, loc, scale, material, group='01 Body', bone=None, seg=24, rings=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, location=loc)
    o=bpy.context.object
    o.scale=scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    adopt(o,name,material,group,bone)
    for p in o.data.polygons:p.use_smooth=True
    return o

def loft(name, rows, material, group='01 Body', bone=None, n=32, waviness=0):
    # Rows are (x, y, z, width-radius, depth-radius).
    vs=[]; fs=[]
    for j,(x,y,z,rx,ry) in enumerate(rows):
        for k in range(n):
            a=2*pi*k/n
            w=1+waviness*sin(7*a+.55*j)
            vs.append((x+rx*cos(a)*w,y+ry*sin(a)*w,z))
    for j in range(len(rows)-1):
        for k in range(n):
            a=j*n+k;b=j*n+(k+1)%n
            fs.append((a,b,b+n,a+n))
    fs += [tuple(range(n-1,-1,-1)), tuple((len(rows)-1)*n+k for k in range(n))]
    return mesh(name,vs,fs,material,group,bone)

def catmull(points, steps=5):
    pts=[Vector(p) for p in points]
    ex=[pts[0]]+pts+[pts[-1]]
    result=[]
    for i in range(len(pts)-1):
        a,b,c,d=ex[i:i+4]
        for k in range(steps):
            t=k/steps
            result.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
    result.append(pts[-1])
    return result

def tube(name, points, radii, material, group='01 Body', bone=None, n=12, steps=4, aspect=1):
    ps=catmull(points,steps)
    rs=[]
    for i in range(len(radii)-1):
        for k in range(steps):rs.append(radii[i]+(radii[i+1]-radii[i])*k/steps)
    rs.append(radii[-1])
    vs=[]; fs=[]
    for i,(p,r) in enumerate(zip(ps,rs)):
        tangent=ps[min(i+1,len(ps)-1)]-ps[max(0,i-1)]
        tangent.normalize()
        ref=Vector((0,1,0)) if abs(tangent.y)<.9 else Vector((1,0,0))
        u=tangent.cross(ref).normalized();v=tangent.cross(u).normalized()
        for k in range(n):
            a=2*pi*k/n
            vs.append(p+r*(u*cos(a)+v*sin(a)*aspect))
    for j in range(len(ps)-1):
        for k in range(n):
            a=j*n+k;b=j*n+(k+1)%n
            fs.append((a,b,b+n,a+n))
    fs += [tuple(range(n-1,-1,-1)),tuple((len(ps)-1)*n+k for k in range(n))]
    return mesh(name,vs,fs,material,group,bone)

def join_group(objects, name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.join()
    objects[0].name=name
    return objects[0]

def solid_panel(name, outline, material, group, bone, depth=.07, bulge=.06):
    # Smooth convex pillow from a front-facing X/Y/Z outline.
    center=sum((Vector(p) for p in outline),Vector())/len(outline)
    vs=[tuple(center+Vector((0,-bulge,0)))];fs=[]
    n=len(outline)
    for fac in [.45,.8,1]:
        for p in outline:
            q=center+(Vector(p)-center)*fac
            q.y-=bulge*(1-fac*fac)
            vs.append(tuple(q))
    for k in range(n):fs.append((0,1+k,1+(k+1)%n))
    for j in range(2):
        for k in range(n):
            a=1+j*n+k;b=1+j*n+(k+1)%n
            fs.append((a,b,b+n,a+n))
    base=len(vs)
    for p in outline:vs.append((p[0],p[1]+depth,p[2]))
    for k in range(n):fs.append((1+2*n+k,1+2*n+(k+1)%n,base+(k+1)%n,base+k))
    fs.append(tuple(base+k for k in range(n-1,-1,-1)))
    return mesh(name,vs,fs,material,group,bone)

# Full body, built around a roughly six-stud-tall avatar silhouette.
lower_rows=[(0,0,2.48,.43,.32),(0,0,2.57,.60,.40),(0,-.015,2.77,.72,.49),(0,-.03,3.02,.79,.55),(0,-.035,3.3,.79,.55),(0,-.035,3.42,.765,.53)]
upper_rows=[(0,-.035,3.39,.77,.535),(0,-.03,3.58,.735,.50),(0,-.015,3.82,.69,.46),(0,0,4.04,.69,.415),(0,0,4.25,.78,.39),(0,0,4.42,.88,.365),(0,0,4.54,.78,.345),(0,0,4.66,.52,.29),(0,0,4.74,.30,.235)]
loft('LowerTorso_Fur',lower_rows,fur,bone='LowerTorso',waviness=.009)
loft('UpperTorso_Fur',upper_rows,fur,bone='UpperTorso',waviness=.009)
loft('Neck_Fur',[(0,0,4.61,.28,.23),(0,0,4.8,.28,.23),(0,0,4.97,.32,.25)],fur,bone='Head',n=24)

for s,side in [(1,'Left'),(-1,'Right')]:
    tube(side+'UpperLeg_Fur',[(s*.40,0,2.7),(s*.43,.02,2.42),(s*.47,.015,2.05),(s*.47,-.02,1.7)],[.34,.33,.265,.235],fur,bone=side+'UpperLeg',n=24,steps=4,aspect=.97)
    tube(side+'LowerLeg_Fur',[(s*.47,-.02,1.74),(s*.46,0,1.40),(s*.45,.03,1.02),(s*.44,.005,.58)],[.24,.255,.22,.245],fur,bone=side+'LowerLeg',n=24,steps=4,aspect=.98)
    tube(side+'Foot_CurledToes',[(s*.44,.16,.45),(s*.45,-.12,.32),(s*.48,-.48,.25),(s*.51,-.77,.29),(s*.55,-.99,.50)],[.27,.30,.30,.20,.018],fur,bone=side+'Foot',n=24,steps=5,aspect=.90)
    tube(side+'UpperArm_Fur',[(s*.78,0,4.45),(s*.98,0,4.24),(s*1.19,0,3.99),(s*1.36,-.015,3.77)],[.29,.275,.225,.205],fur,bone=side+'UpperArm',n=24,steps=4)
    tube(side+'LowerArm_Fur',[(s*1.35,-.015,3.79),(s*1.48,-.03,3.54),(s*1.62,-.035,3.30),(s*1.71,-.04,3.12)],[.21,.215,.18,.16],fur,bone=side+'LowerArm',n=24,steps=4)

# White bib follows the actual body surface instead of floating as an oval.
allrows=lower_rows[:-1]+upper_rows
def body_front(z,x):
    for i in range(len(allrows)-1):
        if allrows[i][2]<=z<=allrows[i+1][2]:
            a=allrows[i];b=allrows[i+1];t=(z-a[2])/(b[2]-a[2])
            cy=a[1]*(1-t)+b[1]*t;rx=a[3]*(1-t)+b[3]*t;ry=a[4]*(1-t)+b[4]*t
            return cy-ry*math.sqrt(max(.01,1-(x/rx)**2))-.02
    return -.24

def bib(name, rows, bone):
    vs=[];fs=[];nx=20
    for j,(z,w) in enumerate(rows):
        for k in range(nx+1):
            t=-1+2*k/nx;x=w*t
            zz=z + (.025*sin(j*3.1+k*1.8)*abs(t)**8 if j not in (0,len(rows)-1) else 0)
            vs.append((x,body_front(zz,x)-.008*(1-t*t),zz))
    for j in range(len(rows)-1):
        for k in range(nx):
            a=j*(nx+1)+k;fs.append((a,a+1,a+nx+2,a+nx+1))
    o=mesh(name,vs,fs,white,bone=bone)
    bpy.context.view_layer.objects.active=o
    mod=o.modifiers.new('Closed white fur panel','SOLIDIFY');mod.thickness=.045
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return o

bib('Belly_White',[(2.60,.03),(2.68,.20),(2.80,.34),(3,.435),(3.20,.46),(3.40,.44)],'LowerTorso')
bib('Chest_White',[(3.39,.44),(3.57,.39),(3.78,.335),(4.02,.27),(4.23,.215),(4.43,.18),(4.64,.16),(4.72,.12)],'UpperTorso')

# Large-scale fur locks carry the silhouette into Roblox without hair particles.
locks=[]
for s,side in [(1,'Left'),(-1,'Right')]:
    for j in range(5):
        z=4.50-j*.15;x=s*(.82-j*.035)
        locks.append(tube('Shoulder lock',[(x, .07,z),(x+s*.14,.085,z-.08),(x+s*.15,.08,z-.25)],[.13,.10,.008],fur,bone='UpperTorso',n=8,steps=2))
    for j in range(5):
        z=3.27-j*.12;x=s*(.78-j*.028)
        locks.append(tube('Hip lock',[(x,.08,z),(x+s*.06,.10,z-.11),(x+s*.04,.11,z-.23)],[.09,.075,.006],fur,bone='LowerTorso',n=8,steps=2))
lock_groups={bone:[o for o in locks if o.get('AttachTo')==bone] for bone in ['UpperTorso','LowerTorso']}
for bone,items in lock_groups.items():
    join_group(items,bone+'_FurTufts')

print('CAT_STAGE_BODY complete: '+str(len(list(root.all_objects)))+' mesh objects')
