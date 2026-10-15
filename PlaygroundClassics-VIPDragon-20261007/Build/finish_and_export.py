import bpy,bmesh,math,json,os,struct,zlib
from pathlib import Path
from mathutils import Vector,Quaternion
ROOT=Path(r'C:/Users/sandt/Documents/Local Projects/Roblox UI Assets/Btns/PlaygroundClassics-VIPDragon-20261007')
OUT=ROOT/'Blender';EXPORT=ROOT/'Roblox';EXPORT.mkdir(exist_ok=True)
scene=bpy.data.scenes['VIP Dragon Studio'];bpy.context.window.scene=scene
rig=bpy.data.objects['VIP_Dragon_Rig'];geometry=bpy.data.collections['VIP Dragon • Editable Geometry']

def rotation(name,axis,degrees):
    pb=rig.pose.bones[name];pb.rotation_mode='QUATERNION'
    rest=pb.bone.matrix_local.to_quaternion()
    pb.rotation_quaternion=rest.inverted()@Quaternion(Vector(axis),math.radians(degrees))@rest

rig.animation_data.action=bpy.data.actions['VIP_Flight_Loop']
for frame in range(1,28):
    scene.frame_set(frame);phase=(frame-1)/26*math.pi*2
    rotation('Body',(1,0,0),-11+3*math.sin(phase))
    rotation('Head',(1,0,0),8-2*math.sin(phase-.3))
    for side in ('L','R'):
        rotation('FrontPaw.'+side,(1,0,0),-24+4*math.sin(phase-.4))
        rotation('RearPaw.'+side,(1,0,0),22+3*math.sin(phase-.7))
    for name in ['Body','Head','FrontPaw.L','FrontPaw.R','RearPaw.L','RearPaw.R']:
        rig.pose.bones[name].keyframe_insert('rotation_quaternion',frame=frame,group=name)
rig.animation_data.action=bpy.data.actions['VIP_Hover_Loop'];scene.frame_set(11)
ink=bpy.data.materials['11 • Midnight ink'];ink.use_backface_culling_shadow=True;ink.use_backface_culling_lightprobe_volume=True
scene.eevee.taa_samples=64;scene.eevee.taa_render_samples=128

# A small lossless palette atlas transfers the approved colours to Roblox.
materials=sorted({m for o in geometry.objects if o.type=='MESH' for m in o.data.materials},key=lambda m:m.name)
palette={m.name:i for i,m in enumerate(materials)}
def srgb(v):return 12.92*v if v<=.0031308 else 1.055*v**(1/2.4)-.055
N=256;tile=64
colors=[]
for m in materials:
    p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    colors.append(tuple(round(max(0,min(1,srgb(v)))*255) for v in p.inputs['Base Color'].default_value[:3]))
while len(colors)<16:colors.append(colors[0])
raw=bytearray()
for y in range(N):
    raw.append(0)
    for x in range(N):raw.extend((*colors[((N-1-y)//tile)*4+x//tile],255))
def chunk(k,d):return struct.pack('>I',len(d))+k+d+struct.pack('>I',zlib.crc32(k+d)&0xffffffff)
atlas_path=EXPORT/'VIP-Dragon-Palette.png'
atlas_path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',N,N,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(bytes(raw),9))+chunk(b'IEND',b''))
atlas=bpy.data.images.load(str(atlas_path),check_existing=True)
atlasmat=bpy.data.materials.new('VIP Dragon • Roblox palette');atlasmat.use_nodes=True
p=next(n for n in atlasmat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');p.inputs['Roughness'].default_value=.38;p.inputs['Metallic'].default_value=.15
tex=atlasmat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=atlas;tex.interpolation='Closest'
atlasmat.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])

runtime=bpy.data.collections.new('Roblox Export • rigged palette meshes');scene.collection.children.link(runtime)
rig.data.pose_position='REST'
clones=[];triangles={}
for source in geometry.objects:
    if source.type!='MESH':continue
    ob=source.copy();ob.data=source.data.copy();ob.name='Export | '+source.name;runtime.objects.link(ob)
    bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
    for mod in list(ob.modifiers):
        if mod.type!='ARMATURE':bpy.ops.object.modifier_apply(modifier=mod.name)
    uv=ob.data.uv_layers.new(name='VIP_Palette')
    for face in ob.data.polygons:
        idx=palette[ob.data.materials[face.material_index].name]
        cell=((idx%4+.5)/4,(idx//4+.5)/4)
        for li in face.loop_indices:uv.data[li].uv=cell
        face.material_index=0
    ob.data.materials.clear();ob.data.materials.append(atlasmat)
    ob.data.calc_loop_triangles();triangles[ob.name]=len(ob.data.loop_triangles)
    clones.append(ob)

def family(ob):
    n=ob.name.lower()
    if any(t in n for t in ['wing','membrane','spar','forearm','knuckle']):return 'Wings'
    if 'tail' in n:return 'Tail'
    if any(t in n for t in ['paw',' leg.',' toe ']):return 'Paws'
    if any(t in n for t in ['crown','horn','ear.']):return 'Crown_Horns'
    if any(t in n for t in ['iris','pupil','catchlight','socket','nostril','smile','fang']):return 'Face'
    return 'Body_Head'
batches={}
for ob in clones:batches.setdefault(family(ob),[]).append(ob)
export_meshes=[]
for name,group in batches.items():
    parts=[];count=0;serial=1
    def join_batch(parts,serial):
        bpy.ops.object.select_all(action='DESELECT')
        for o in parts:o.select_set(True)
        bpy.context.view_layer.objects.active=parts[0]
        bpy.ops.object.join();joined=parts[0];joined.name='VIP_'+name+'_'+str(serial)
        joined.data.name=joined.name+'_Mesh';export_meshes.append(joined)
    for ob in group:
        if parts and count+triangles[ob.name]>8000:
            join_batch(parts,serial);parts=[];count=0;serial+=1
        parts.append(ob);count+=triangles[ob.name]
    if parts:join_batch(parts,serial)

options=dict(use_selection=True,global_scale=.01,apply_unit_scale=False,apply_scale_options='FBX_SCALE_NONE',
 axis_forward='-Z',axis_up='Y',use_space_transform=True,bake_space_transform=False,object_types={'ARMATURE','MESH'},
 use_mesh_modifiers=True,use_mesh_edges=False,mesh_smooth_type='FACE',add_leaf_bones=False,use_armature_deform_only=True,
 armature_nodetype='NULL',path_mode='COPY',embed_textures=True,bake_anim_use_all_bones=True,bake_anim_use_nla_strips=False,
 bake_anim_use_all_actions=False,bake_anim_force_startend_keying=True,bake_anim_step=1.0,bake_anim_simplify_factor=0.0)
def select_export():
    bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
    for ob in export_meshes:ob.select_set(True)
    bpy.context.view_layer.objects.active=rig
select_export()
bpy.ops.export_scene.fbx(filepath=str(EXPORT/'VIP-Dragon-Rigged.fbx'),bake_anim=False,**options)
rig.data.pose_position='POSE'
for name,end,filename in [('VIP_Hover_Loop',41,'VIP-Dragon-Hover.fbx'),('VIP_Flight_Loop',27,'VIP-Dragon-Fly.fbx')]:
    rig.animation_data.action=bpy.data.actions[name];scene.frame_start=1;scene.frame_end=end;scene.frame_set(1)
    select_export();bpy.ops.export_scene.fbx(filepath=str(EXPORT/filename),bake_anim=True,**options)
rig.animation_data.action=bpy.data.actions['VIP_Hover_Loop'];scene.frame_start=1;scene.frame_end=41;scene.frame_set(11)
runtime.hide_render=True;runtime.hide_viewport=True
for ob in bpy.context.scene.objects:ob.select_set(False)
rig.select_set(True);bpy.context.view_layer.objects.active=rig
atlas.pack()
report={'targetWingspanStuds':3,'sourceMeshCount':80,'runtimeMeshes':len(export_meshes),'bones':len(rig.data.bones),'exportGlobalScale':.01,
 'runtimeTriangles':sum(len(ob.data.loop_triangles) for ob in export_meshes),'actions':{'VIP_Hover_Loop':{'frames':41,'fps':30},'VIP_Flight_Loop':{'frames':27,'fps':30}},
 'runtimeMeshTriangles':{ob.name:len(ob.data.loop_triangles) for ob in export_meshes}}
(ROOT/'Validation-Model.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'PlaygroundClassics-VIP-Dragon.blend'))
scene.render.filepath=str(OUT/'VIP-Dragon-Preview.png');bpy.ops.render.render(write_still=True)
print(json.dumps(report))
