import bpy, math, os, json, random, bmesh
from mathutils import Vector, Matrix
from math import pi, sin, cos
random.seed(32)
BASE=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\CatInTheHat'
OUT=os.path.join(BASE,'Horror')
os.makedirs(OUT,exist_ok=True)
scene=bpy.context.scene
# Capture the current live state, including any work since the original delivery.
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'Before_Horror.blend'),copy=True)
root=bpy.data.collections['CAT IN THE HAT - editable base']
facecoll=bpy.data.collections['02 Face']

def recolor(name,rgb,rough=None):
    m=bpy.data.materials[name];m.diffuse_color=(*rgb,1)
    shader=m.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value=(*rgb,1)
    if rough is not None:shader.inputs['Roughness'].default_value=rough
    return m

fur=recolor('Fur - charcoal black',(.005,.006,.008),.94)
ivory=recolor('Fur - warm white',(.56,.53,.43),.91)
recolor('Hat - crimson',(.21,.002,.006),.85)
recolor('Hat - ivory bands',(.60,.56,.45),.86)
recolor('Bow - rich red',(.235,.003,.009),.84)
recolor('Gloves - soft white',(.64,.60,.49),.84)
recolor('Nose - muted rose',(.14,.02,.025),.76)
recolor('Eyes - whites',(.63,.56,.39),.48)
recolor('Eyes - amber hazel',(.34,.22,.048),.42)
recolor('Mouth - shadow',(.004,.001,.002),.95)
toothmat=recolor('Smile - ivory',(.67,.61,.45),.58)
shadow=bpy.data.materials.new('Horror - eye hollows')
shadow.diffuse_color=(.024,.017,.014,1);shadow.use_nodes=True
shader=shadow.node_tree.nodes.get('Principled BSDF')
shader.inputs['Base Color'].default_value=shadow.diffuse_color
shader.inputs['Roughness'].default_value=.98

def warp(o, fn):
    world=o.matrix_world.copy();inverse=world.inverted()
    for v in o.data.vertices:v.co=inverse@Vector(fn(world@v.co))
    o.data.update()

def scale_at(name,c,scales):
    o=bpy.data.objects[name];c=Vector(c)
    warp(o,lambda p:c+Vector(((p.x-c.x)*scales[0],(p.y-c.y)*scales[1],(p.z-c.z)*scales[2])))

def newmesh(name,verts,faces,mat):
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
    bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
    o=bpy.data.objects.new(name,me);facecoll.objects.link(o);me.materials.append(mat)
    for p in me.polygons:p.use_smooth=True
    o['Asset']='CatInTheHat_Horror';o['AttachTo']='Head';o['RecolorRegion']=mat.name
    return o

def tube(name,points,radii,mat,n=10,steps=5):
    pts=[Vector(p) for p in points];ext=[pts[0]]+pts+[pts[-1]];ps=[];rs=[]
    for i in range(len(pts)-1):
        a,b,c,d=ext[i:i+4]
        for j in range(steps):
            t=j/steps
            ps.append(.5*(2*b+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
            rs.append(radii[i]*(1-t)+radii[i+1]*t)
    ps.append(pts[-1]);rs.append(radii[-1]);verts=[];faces=[]
    for i,p in enumerate(ps):
        tangent=(ps[min(i+1,len(ps)-1)]-ps[max(0,i-1)]).normalized()
        ref=Vector((0,1,0)) if abs(tangent.y)<.9 else Vector((1,0,0))
        u=tangent.cross(ref).normalized();v=tangent.cross(u).normalized()
        for k in range(n):
            a=2*pi*k/n;verts.append(p+rs[i]*(u*cos(a)+v*sin(a)*.7))
    for j in range(len(ps)-1):
        for k in range(n):
            a=j*n+k;b=j*n+(k+1)%n;faces.append((a,b,b+n,a+n))
    faces.extend([tuple(range(n-1,-1,-1)),tuple((len(ps)-1)*n+k for k in range(n))])
    return newmesh(name,verts,faces,mat)

for s,side in [(1,'Left'),(-1,'Right')]:
    x=s*.245
    socket=bpy.data.objects[side+'Eye_Socket'];socket.data.materials.clear();socket.data.materials.append(shadow)
    scale_at(side+'Eye_Socket',(x,-.435,5.67),(1.12,1.20,1.08))
    scale_at(side+'Eye_White',(x,-.492,5.665),(.86,1,.73))
    scale_at(side+'Eye_Iris',(x-s*.018,-.548,5.668),(.72,1,.80))
    scale_at(side+'Eye_Pupil',(x-s*.018,-.568,5.668),(.36,1,.9))
    scale_at(side+'Eye_Catchlight',(x-s*.018,-.568,5.668),(.46,1,.48))
    for name in [side+'Eye_UpperLid',side+'Eye_LowerLid',side+'Eyebrow']:
        bpy.data.objects.remove(bpy.data.objects[name],do_unlink=True)
    tube(side+'Eye_UpperLid',[(s*.115,-.51,5.68),(s*.22,-.54,5.716),(s*.34,-.50,5.746),(s*.402,-.458,5.711)],[.014,.028,.029,.009],ivory)
    tube(side+'Eye_LowerLid',[(s*.114,-.499,5.637),(s*.235,-.536,5.590),(s*.358,-.484,5.63)],[.012,.018,.008],ivory)
    tube(side+'Eyebrow',[(s*.077,-.476,5.803),(s*.21,-.47,5.827),(s*.35,-.415,5.884),(s*.446,-.346,5.905)],[.026,.050,.036,.003],fur)
    tube(side+'Eye_HollowCrease',[(s*.112,-.49,5.581),(s*.23,-.49,5.536),(s*.35,-.429,5.557),(s*.425,-.355,5.59)],[.006,.014,.016,.001],shadow,n=8)

# Stretch the small smile into a fixed crescent with raised corners.
def grin(p):
    x=p.x*1.55
    return (x,p.y-.022,5.185+(p.z-5.185)*1.13+.075*(abs(p.x)/.253)**2)
warp(bpy.data.objects['Smile_Opening'],grin)
warp(bpy.data.objects['Smile_LowerLip'],grin)
bpy.data.objects.remove(bpy.data.objects['Smile_UpperTeeth'],do_unlink=True)

# A single separately recolourable upper set and lower set of uneven teeth.
for upper in [True,False]:
    verts=[];faces=[]
    xs=[-.30,-.23,-.155,-.078,0,.078,.155,.23,.30] if upper else [-.25,-.15,-.05,.05,.15,.25]
    for i,x in enumerate(xs):
        curve=.075*(x/.392)**2
        rootz=(5.255 if upper else 5.098)+curve
        length=(.080 if upper else .051)+random.uniform(-.014,.018)
        tipz=rootz+(-length if upper else length)
        width=.035 if upper else .029
        y=-.565+abs(x)*.082
        # Chisel-shaped teeth with solid, shallow volume and blunted points.
        off=len(verts)
        verts += [(x-width,y,rootz),(x+width,y,rootz),(x+.014,y-.012,tipz),(x-.014,y-.012,tipz),
                  (x-width,y+.038,rootz),(x+width,y+.038,rootz),(x+.014,y+.026,tipz),(x-.014,y+.026,tipz)]
        faces += [tuple(off+k for k in f) for f in [(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)]]
    newmesh('Smile_UpperTeeth' if upper else 'Smile_LowerTeeth',verts,faces,toothmat)
for s,side in [(1,'Left'),(-1,'Right')]:
    tube(side+'Grin_Corner',[(s*.31,-.523,5.25),(s*.415,-.415,5.33),(s*.453,-.363,5.417)],[.014,.013,.002],shadow,n=8)

# Slim the waist and draw the shoulders, head and arms into a stalking posture.
def bodywarp(p):
    x,y,z=p
    if abs(x)<.93 and 2.58<z<4.48:
        strength=sin(pi*(z-2.58)/1.90)**2
        x*=1-.11*strength
    if z>3.75:
        y-=.15*min(1,(z-3.75)/1.1)
        z+=.055*math.exp(-((abs(x)-.8)/.30)**2)*math.exp(-((z-4.38)/.3)**2)
    if abs(x)>1.0 and z>2.65:
        t=min(1,(abs(x)-1)/.75)
        z-=.22*t
        y-=.035*t
    return (x,y,z)
for name in ['Body_BlackFur','Body_WhiteBib']:
    warp(bpy.data.objects[name],bodywarp)
for o in bpy.data.collections['04 Bow tie'].objects:warp(o,bodywarp)

for o in bpy.data.collections['05 Gloves'].objects:
    s=1 if o.name.startswith('Left') else -1
    center=Vector((s*1.86,-.06,2.91));down=Vector((s*.35,-.03,-.94)).normalized()
    def handwarp(p):
        delta=p-center;t=delta.dot(down)
        if t>.09:p+=down*(t-.09)*.68
        p.z-=.22;p.y-=.035
        return p
    warp(o,handwarp)

# Sharpen the lateral fur silhouette; keep all colour pieces aligned.
for name in ['Head_BlackFur','Face_WhiteFur']:
    o=bpy.data.objects[name]
    def cheekwarp(p):
        if abs(p.x)>.50 and 5.13<p.z<5.78:
            p.x*=1+.11*min(1,(abs(p.x)-.50)/.20)
        return p
    warp(o,cheekwarp)

# Head leans forward and tilts slightly, with the hat traveling with it.
pivot=Vector((0,0,4.86))
rotation=Matrix.Rotation(math.radians(8),3,'X')@Matrix.Rotation(math.radians(-3.5),3,'Y')
for coll in [facecoll,bpy.data.collections['03 Hat']]:
    for o in coll.objects:
        if o.type=='MESH':warp(o,lambda p:pivot+rotation@(p-pivot)+Vector((0,-.13,0)))
for o in bpy.data.collections['03 Hat'].objects:
    if o.name.startswith('Hat_Band'):
        warp(o,lambda p:(p.x-.12*max(0,(p.z-6.1)/1.9)**2,p.y,p.z))

# Keep the first preview clearly lit so the shape changes are easy to judge.
scene.cycles.samples=40
scene.render.resolution_x=1200;scene.render.resolution_y=1400
cam=scene.camera;cam.location=(6.0,-23,8.0)
cam.rotation_euler=(Vector((0,-.04,3.96))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.ortho_scale=8.85
scene.render.filepath=os.path.join(OUT,'CatInTheHat_Horror_Studio.png')
for o in root.all_objects:o['Variant']='Horror'
root['Description']='Horror variant: sunken eyes, slit pupils, fixed grin, long glove fingers, hunched posture. Unrigged.'
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'CatInTheHat_Horror.blend'))
print('Horror geometry and materials created; original base remains available.')
