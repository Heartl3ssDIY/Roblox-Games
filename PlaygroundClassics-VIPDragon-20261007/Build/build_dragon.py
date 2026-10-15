import bpy, math, os, json
from mathutils import Vector, Quaternion
from pathlib import Path

ROOT = Path(r'C:/Users/sandt/Documents/Local Projects/Roblox UI Assets/Btns/PlaygroundClassics-VIPDragon-20261007')
OUT = ROOT / 'Blender'
OUT.mkdir(exist_ok=True)
scene = bpy.data.scenes.new('VIP Dragon Studio')
bpy.context.window.scene = scene
scene.unit_settings.system = 'NONE'
scene.unit_settings.scale_length = 1.0
COL = bpy.data.collections.new('VIP Dragon • Editable Geometry')
scene.collection.children.link(COL)
objects = []

def material(name, color, metallic=0.0, roughness=.34):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Metallic'].default_value = metallic
    p.inputs['Roughness'].default_value = roughness
    if 'Coat Weight' in p.inputs: p.inputs['Coat Weight'].default_value = .18
    return m

M = {
 'gold': material('01 • Royal marigold', (.94,.49,.035), .38),
 'gold_light': material('02 • Golden edges', (1,.69,.12), .38,.28),
 'gold_shadow': material('03 • Warm engraved gold', (.33,.12,.013), .24,.4),
 'cream': material('04 • Warm ivory', (1,.86,.48), .02,.42),
 'fang': material('05 • Porcelain fangs', (1,.96,.77), .04,.25),
 'ruby': material('06 • Ruby red', (.64,.008,.037), .3,.22),
 'ruby_light': material('07 • Ruby facets', (1,.045,.075), .27,.2),
 'ruby_dark': material('08 • Garnet facets', (.23,.002,.012), .3,.26),
 'crimson': material('09 • Crimson membranes', (.47,.007,.029), .1,.4),
 'scarlet': material('10 • Scarlet membrane facets', (.75,.018,.046), .12,.36),
 'ink': material('11 • Midnight ink', (.006,.009,.024), .05,.4),
 'pupil': material('12 • Glossy obsidian', (.007,.002,.009), .13,.16),
 'white': material('13 • Eye catchlights', (1,.99,.91), .0,.17),
}

def mesh(name, verts, faces, mat, bone='Body', smooth=True):
    data=bpy.data.meshes.new(name+' topology'); data.from_pydata(verts,[],faces); data.update()
    ob=bpy.data.objects.new(name,data); COL.objects.link(ob)
    ob.data.materials.append(M[mat] if isinstance(mat,str) else mat)
    for p in data.polygons: p.use_smooth=smooth
    ob['rig_bone']=bone
    objects.append(ob)
    return ob

def ellipsoid(name, center, radii, mat, bone='Body', segments=32, rings=20, rot=None, shape=None):
    verts=[]; faces=[]
    center=Vector(center)
    for j in range(rings+1):
        theta=math.pi*j/rings
        for i in range(segments):
            phi=2*math.pi*i/segments
            p=Vector((math.sin(theta)*math.cos(phi)*radii[0],math.sin(theta)*math.sin(phi)*radii[1],math.cos(theta)*radii[2]))
            if shape: p=shape(p)
            if rot: p=rot@p
            verts.append(tuple(center+p))
    for j in range(rings):
        for i in range(segments):
            k=j*segments+i; n=j*segments+(i+1)%segments
            faces.append((k,n,n+segments,k+segments))
    ob=mesh(name,verts,faces,mat,bone)
    return ob

def tube(name, points, radii, mat, bone='Body', sides=12):
    vs=[];fs=[]
    for i,co in enumerate(points):
        p=Vector(co); t=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(i-1,0)])
        t.normalize(); v=t.cross(Vector((0,1,0)))
        if v.length<.05: v=t.cross(Vector((1,0,0)))
        v.normalize(); w=t.cross(v).normalized()
        rad=radii[i] if isinstance(radii,(list,tuple)) else radii
        for j in range(sides):
            a=2*math.pi*j/sides
            vs.append(tuple(p+rad*(math.cos(a)*v+math.sin(a)*w)))
    for i in range(len(points)-1):
        for j in range(sides):
            k=i*sides+j; n=i*sides+(j+1)%sides;fs.append((k,n,n+sides,k+sides))
    fs.append(tuple(reversed(range(sides))));fs.append(tuple((len(points)-1)*sides+j for j in range(sides)))
    return mesh(name,vs,fs,mat,bone)

def bezier_points(p0,p1,p2,p3,n=20):
    p0,p1,p2,p3=map(Vector,(p0,p1,p2,p3))
    return [tuple((1-t)**3*p0+3*(1-t)**2*t*p1+3*(1-t)*t*t*p2+t**3*p3) for t in [i/n for i in range(n+1)]]

def horn(name, points, widths, depths, mat, bone='Head', sides=12):
    vs=[];fs=[]
    for i,p in enumerate(points):
        for k in range(sides):
            a=2*math.pi*k/sides
            vs.append((p[0]+widths[i]*math.cos(a),p[1]+depths[i]*math.sin(a),p[2]))
    for i in range(len(points)-1):
        for j in range(sides):
            a=i*sides+j; b=i*sides+(j+1)%sides; fs.append((a,b,b+sides,a+sides))
    fs.append(tuple(reversed(range(sides))));fs.append(tuple((len(points)-1)*sides+j for j in range(sides)))
    ob=mesh(name,vs,fs,mat,bone)
    sub=ob.modifiers.new('Editable smooth silhouette','SUBSURF');sub.levels=1;sub.render_levels=1
    return ob

ellipsoid('Body • rounded chest and haunch',(0,.10,.69),(.37,.34,.47),'gold')
ellipsoid('Neck • rising collar',(0,-.015,1.01),(.29,.27,.31),'gold')
ellipsoid('Head • sculpted cheek silhouette',(0,-.095,1.36),(.565,.438,.482),'gold','Head',40,28,
 shape=lambda p: Vector((p.x*(1-.08*max(0,p.z/.482)),p.y,p.z)))

# Conforming inset belly surface follows the body instead of intersecting as a separate sphere.
vs=[];fs=[]
for j in range(17):
    v=-1+2*j/16
    z=.66+v*.315
    width=.225*math.sqrt(max(.003,1-v*v))
    for i in range(17):
        u=-1+2*i/16;x=u*width
        y=.1-.343*math.sqrt(max(.03,1-(x/.37)**2-((z-.69)/.47)**2))-.007
        vs.append((x,y,z))
for j in range(16):
    for i in range(16):
        k=j*17+i;fs.append((k,k+1,k+18,k+17))
belly=mesh('Belly • inset cream bib',vs,fs,'cream')
sol=belly.modifiers.new('Belly edge thickness','SOLIDIFY');sol.thickness=.008

ellipsoid('Muzzle • friendly rounded snout',(0,-.477,1.115),(.352,.204,.205),'gold_light','Head',32,20)
for side in (-1,1):
    suffix='L' if side>0 else 'R'
    normal=Vector((side*.38,-.90,.08)).normalized()
    # Local sphere's negative-Y axis points outward from the head.
    q=Vector((0,-1,0)).rotation_difference(normal)
    center=Vector((side*.303,-.44,1.431))
    ellipsoid('Eye socket.'+suffix,center,(.168,.050,.229),'gold_shadow','Head',32,24,q)
    ellipsoid('Ruby iris.'+suffix,center+normal*.018,(.153,.051,.216),'ruby','Head',32,24,q)
    ellipsoid('Pupil.'+suffix,center+normal*.059+Vector((0,0,.019)),(.103,.018,.161),'pupil','Head',28,20,q)
    ellipsoid('Large catchlight.'+suffix,center+normal*.079+Vector((-.042,0,.110)),(.037,.012,.048),'white','Head',18,12,q)
    ellipsoid('Small catchlight.'+suffix,center+normal*.078+Vector((.047,0,-.087)),(.013,.009,.018),'white','Head',12,8,q)
    ellipsoid('Nostril inset.'+suffix,(side*.12,-.668,1.149),(.027,.009,.039),'gold_shadow','Head',16,10)
    mouth=bezier_points((side*.02,-.656,1.022),(side*.13,-.642,.997),(side*.24,-.582,1.006),(side*.294,-.546,1.048),16)
    tube('Smile crease.'+suffix,mouth,[.007]*17,'gold_shadow','Head',8)
    horn('Tiny ivory fang.'+suffix,[(side*.205,-.611,1.04),(side*.204,-.62,1.006),(side*.197,-.612,.957)], [.036,.028,.003],[.023,.021,.003],'fang','Head',10)
    horn('Tall royal horn.'+suffix,[(side*.40,.025,1.64),(side*.468,.032,1.76),(side*.526,.04,1.98),(side*.585,.06,2.18),(side*.592,.074,2.228)], [.112,.116,.090,.026,.002],[.096,.098,.069,.022,.002],'gold_light')
    horn('Cheek ear.'+suffix,[(side*.48,-.016,1.47),(side*.588,-.01,1.57),(side*.709,.008,1.735),(side*.789,.025,1.868)], [.115,.13,.08,.004],[.115,.093,.050,.004],'gold_light')
    for kind,y,z in [('Front',-.195,.385),('Rear',.34,.365)]:
        bone=kind+'Paw.'+suffix
        ellipsoid(kind+' leg.'+suffix,(side*.281,y,z+.075),(.151,.186,.213),'gold',bone,24,16)
        ellipsoid(kind+' paw.'+suffix,(side*.30,y-.065,z-.027),(.158,.207,.121),'gold_light',bone,24,16)
        for t in (-1,0,1):
            ellipsoid(kind+' toe '+str(t)+'.'+suffix,(side*.30+t*.066,y-.211,z-.022),(.041,.056,.081),'gold_light',bone,16,10)

# Thick crown with a continuous extruded, curved five-point silhouette.
N=96;vs=[];fs=[]
for ring in range(4):
    for i in range(N):
        a=2*math.pi*i/N
        wave=(.5+.5*math.cos(5*a))**3.5
        top=1.84+.265*wave
        z=1.758 if ring<2 else top
        rad=.274 if ring%2==0 else .248
        if ring>=2:rad+=.037
        vs.append((rad*math.sin(a),-.016-rad*math.cos(a),z))
for i in range(N):
    n=(i+1)%N
    fs.extend([(i,n,2*N+n,2*N+i),(N+n,N+i,3*N+i,3*N+n),(2*N+i,2*N+n,3*N+n,3*N+i),(n,i,N+i,N+n)])
crown=mesh('Crown • continuous extruded five points',vs,fs,'gold_light','Head')
bev=crown.modifiers.new('Rounded crown edges','BEVEL');bev.width=.007;bev.segments=2
for i in range(5):
    a=2*math.pi*i/5
    ellipsoid('Crown pearl '+str(i),( .311*math.sin(a),-.016-.311*math.cos(a),2.105),(.032,.032,.038),'gold_light','Head',16,10)
ring=[(.281*math.sin(2*math.pi*i/64),-.016-.281*math.cos(2*math.pi*i/64),1.774) for i in range(65)]
tube('Crown • raised lower rim',ring,.019,'gold','Head',10)
verts=[(0,-.325,1.827),(-.072,-.325,1.931),(0,-.325,2.029),(.072,-.325,1.931),(0,-.378,1.931),(0,-.30,1.931)]
faces=[(0,1,4),(1,2,4),(2,3,4),(3,0,4),(1,0,5),(2,1,5),(3,2,5),(0,3,5)]
gem=mesh('Crown • faceted ruby diamond',verts,faces,'ruby','Head',False)
for key in ('ruby_light','ruby_dark'):gem.data.materials.append(M[key])
for p,idx in zip(gem.data.polygons,[0,1,0,2,2,0,1,2]):p.material_index=idx

tailpoints=bezier_points((0,.34,.54),(.02,.62,.16),(.55,1.14,.22),(.84,.94,.47),28)
tail=tube('Tail • curved tapered extrusion',tailpoints,[.185*(1-i/28)**.8+.012 for i in range(29)],'gold','Tail.01',16)
for k,v in enumerate(tail.data.vertices):
    t=(k//16)/28
    weights={'Tail.01':max(0,1-2*t),'Tail.02':max(0,1-abs(2*t-1)),'Tail.03':max(0,2*t-1)}
    for name,w in weights.items():
        if w>0:
            group=tail.vertex_groups.get(name) or tail.vertex_groups.new(name=name);group.add([k],w,'REPLACE')
# Arrow tip: a bevelled flattened spade with a real extruded edge.
tip=Vector(tailpoints[-1]);direction=(tip-Vector(tailpoints[-4])).normalized()
up=Vector((0,0,1));right=direction.cross(up).normalized()
outline=[(-.06,-.02),(-.17,.12),(0,.34),(.17,.12),(.06,-.02),(0,.045)]
vs=[]
for thickness in (-.037,.037):
    for x,t in outline:vs.append(tuple(tip+right*x+direction*t+up*thickness))
n=len(outline);fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
ob=mesh('Tail • golden spade tip',vs,fs,'gold_light','Tail.03',False)
be=ob.modifiers.new('Spade bevel','BEVEL');be.width=.018;be.segments=2
for i in range(5):
    t=.19+i*.15;idx=int(t*28);p=Vector(tailpoints[idx]);r=.185*(1-t)**.8+.012
    bone='Tail.01' if t<.35 else 'Tail.02' if t<.7 else 'Tail.03'
    horn('Tail dorsal ridge '+str(i),[tuple(p+Vector((0,0,r*.8))),tuple(p+Vector((.012,.015,r+.085))),tuple(p+Vector((.025,.02,r+.14)))],[.071,.055,.002],[.091,.058,.002],'gold_light',bone,8)
for i,(y,z,r) in enumerate([(.357,1.06,.10),(.423,.93,.115)]):
    horn('Back dorsal ridge '+str(i),[(0,y,z),(0,y+.09,z+.05),(0,y+.15,z+.10)],[r,r*.6,.002],[.06,.045,.002],'gold_light','Body',8)

import importlib.util
spec=importlib.util.spec_from_file_location('vip_wings',str(ROOT/'Build'/'dragon_wings.py'))
wings_module=importlib.util.module_from_spec(spec);spec.loader.exec_module(wings_module)
objects.extend(wings_module.build_wings(COL,M))

# Bake native units: exported geometry is already a small companion.
allverts=[v.co for ob in objects if ob.type=='MESH' for v in ob.data.vertices]
width=max(v.x for v in allverts)-min(v.x for v in allverts)
S=3.0/width
for ob in objects:
    if ob.type=='MESH':
        for v in ob.data.vertices:v.co*=S
    for mod in ob.modifiers:
        if mod.type=='BEVEL':mod.width*=S
        if mod.type=='SOLIDIFY':mod.thickness*=S

armdata=bpy.data.armatures.new('VIP Dragon • deformation skeleton')
rig=bpy.data.objects.new('VIP_Dragon_Rig',armdata);COL.objects.link(rig)
bpy.context.view_layer.objects.active=rig;rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
bones={
 'Root':((0,0,0),(0,0,.20),None),
 'Body':((0,.10,.40),(0,.10,1.05),'Root'),
 'Head':((0,.0,1.05),(0,-.095,1.60),'Body'),
 'Tail.01':((0,.34,.54),(.15,.72,.29),'Body'),
 'Tail.02':((.15,.72,.29),(.47,.99,.28),'Tail.01'),
 'Tail.03':((.47,.99,.28),(.99,.89,.60),'Tail.02'),
}
for s,label in [(1,'L'),(-1,'R')]:
    bones['Wing.'+label]=((s*.30,.18,1.05),(s*1.12,.15,1.72),'Body')
    bones['WingTip.'+label]=((s*1.12,.15,1.72),(s*1.70,.23,1.14),'Wing.'+label)
    for kind,y in [('Front',-.195),('Rear',.34)]:
        bones[kind+'Paw.'+label]=((s*.24,y,.58),(s*.30,y-.04,.31),'Body')
for name,(head,tip,parent) in bones.items():
    bone=armdata.edit_bones.new(name);bone.head=Vector(head)*S;bone.tail=Vector(tip)*S
    if parent:bone.parent=armdata.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
for ob in objects:
    if ob.type!='MESH':continue
    if not ob.vertex_groups:
        group=ob.vertex_groups.new(name=ob.get('rig_bone','Body'));group.add(list(range(len(ob.data.vertices))),1,'REPLACE')
    ob.parent=rig
    mod=ob.modifiers.new('VIP flight skeleton','ARMATURE');mod.object=rig;mod.use_deform_preserve_volume=True
rig.show_in_front=True
rig['RobloxTargetWidthStuds']=3.0
rig['VIPOnly']=True
rig['MovementStyle']='Flying • hovering companion'
rig['PetHoverHeightStuds']=1.15
rig['PetFacingAxis']='-Y Blender / -Z Roblox'
rig['OutlineInRoblox']='Use black Occluded Highlight with FillTransparency=1; preview ink is not exported.'
rig['ExportGlobalScale']=.01
rig['ReferenceBrief']=str(ROOT/'Modeller-Notes.txt')

def pose_rotation(name, axis, degrees):
    pb=rig.pose.bones[name];pb.rotation_mode='QUATERNION'
    worldq=Quaternion(Vector(axis),math.radians(degrees))
    rest=pb.bone.matrix_local.to_quaternion()
    pb.rotation_quaternion=rest.inverted()@worldq@rest

def action(name,frames,fast=False):
    rig.animation_data_create();act=bpy.data.actions.new(name);rig.animation_data.action=act
    for frame in range(1,frames+1):
        t=(frame-1)/(frames-1);phase=2*math.pi*t
        for pb in rig.pose.bones:
            pb.rotation_mode='QUATERNION';pb.rotation_quaternion=Quaternion();pb.location=(0,0,0)
        body=rig.pose.bones['Body'];body.location=(0,.040*S*math.sin(phase-.3),0)
        pose_rotation('Body',(1,0,0),3+2*math.sin(phase))
        pose_rotation('Head',(1,0,0),-3-1.4*math.sin(phase-.3))
        for s,label in [(1,'L'),(-1,'R')]:
            pose_rotation('Wing.'+label,(0,1,0),s*(8+32*math.cos(phase)))
            pose_rotation('WingTip.'+label,(0,1,0),s*(7+17*math.cos(phase-.55)))
            pose_rotation('FrontPaw.'+label,(1,0,0),-13+4*math.sin(phase-.4))
            pose_rotation('RearPaw.'+label,(1,0,0),15+3*math.sin(phase-.7))
        for i,b in enumerate(['Tail.01','Tail.02','Tail.03']):
            pose_rotation(b,(0,0,1),(3+i*2)*math.sin(phase-i*.45))
        for pb in rig.pose.bones:
            pb.keyframe_insert('rotation_quaternion',frame=frame,group=pb.name)
            if pb.name=='Body':pb.keyframe_insert('location',frame=frame,group=pb.name)
    act.use_fake_user=True
    return act
scene.render.fps=30
hover=action('VIP_Hover_Loop',41)
fly=action('VIP_Flight_Loop',27,True)
rig.animation_data.action=hover
scene.frame_start=1;scene.frame_end=41;scene.frame_set(11)

# Reference and studio objects remain editable but are excluded from FBX selection.
studio=bpy.data.collections.new('Studio • preview only');scene.collection.children.link(studio)
def studio_obj(ob):
    for c in list(ob.users_collection):c.objects.unlink(ob)
    studio.objects.link(ob);return ob
world=bpy.data.worlds.new('Warm gallery');world.use_nodes=True
bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs[0].default_value=(.13,.17,.24,1);bg.inputs[1].default_value=.6
scene.world=world
camdata=bpy.data.cameras.new('Portrait Camera');cam=bpy.data.objects.new('Portrait Camera',camdata);studio.objects.link(cam)
cam.location=(3.55,-5.6,3.0);target=Vector((0,0,1.03*S));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();camdata.type='ORTHO';camdata.ortho_scale=3.95;scene.camera=cam
for name,loc,power,size in [('Softbox key',(-3,-4,6),650,5),('Fill',(4,-2,3),430,4),('Golden rim',(1,3,5),800,3)]:
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size
    ob=bpy.data.objects.new(name,data);ob.location=loc;ob.rotation_euler=(Vector((0,0,1))-ob.location).to_track_quat('-Z','Y').to_euler();studio.objects.link(ob)
scene.render.resolution_x=1000;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.render.film_transparent=True
try:scene.render.engine='BLENDER_EEVEE'
except TypeError:pass
try:scene.view_settings.view_transform='AgX'
except TypeError:pass
scene.render.image_settings.file_format='PNG'
scene.render.filepath=str(OUT/'VIP-Dragon-Preview.png')
scene['README']='Native wingspan 3 studs. Two seamless flight actions. Select armature and enter Pose Mode. Export mesh + rig only. See Import-Guide.txt.'
for ob in scene.objects:ob.select_set(False)
rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'PlaygroundClassics-VIP-Dragon.blend'))
print(json.dumps({'scene':scene.name,'objects':len(objects),'bones':len(bones),'scale_baked':S,'blend':bpy.data.filepath}))
