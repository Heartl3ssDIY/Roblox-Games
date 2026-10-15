import bpy, os, json, bmesh
from mathutils import Vector
ROOT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\ACULobbyCitadel'
source=bpy.data.scenes['ACU | Festival Citadel']
scene=bpy.data.scenes.new('ACU_Collision_Proxies')
bpy.context.window.scene=scene
selected=[]
sources=[]
def add_mesh(ob):
    me=ob.data.copy()
    cp=bpy.data.objects.new('COL_'+ob.name,me);scene.collection.objects.link(cp);cp.matrix_world=ob.matrix_world
    for m in list(me.materials): pass
    me.materials.clear()
    selected.append(cp);sources.append(ob.name)
for ob in source.objects:
    if ob.type!='MESH':continue
    n=ob.name.lower()
    if any(c.name.startswith(('ACU | 80','ACU | 81','ACU | 82','ACU | 90','ACU | 99')) for c in ob.users_collection):continue
    iswalk=(ob.name=='Expanded island top' or
            any(t in n for t in ('deckplank','deck_plank','walkway','bridge_deck','bridgedeck','court_deck','landing','galleryfloor','terracefloor','stone_tread','stepstone','steppingrock')) or
            ('stair' in n and 'stonelight' in n) or
            ('floor' in n and 'roof' not in n) or
            ('step' in n and 'gold' not in n and 'stair' not in n))
    if iswalk:add_mesh(ob)
# Building wall boxes remain separate and visible geometry remains non-colliding.
for ob in source.objects:
    if ob.type!='MESH':continue
    n=ob.name.lower()
    if any(t in n for t in ('retaining wall','boundary wall','outer wall pier')):add_mesh(ob)
bpy.ops.object.select_all(action='DESELECT')
for ob in selected:ob.select_set(True)
if selected:bpy.context.view_layer.objects.active=selected[0]
out=os.path.join(ROOT,'exports','ACU_Citadel_Collision.fbx')
bpy.ops.export_scene.fbx(filepath=out,use_selection=True,object_types={'MESH'},apply_unit_scale=True,apply_scale_options='FBX_SCALE_NONE',use_mesh_modifiers=False,mesh_smooth_type='FACE',axis_forward='-Z',axis_up='Y',bake_anim=False,add_leaf_bones=False)
with open(os.path.join(ROOT,'exports','collision_manifest.json'),'w',encoding='utf8') as f:
    json.dump({'file':out,'meshes':len(selected),'sourceMeshes':sources,'purpose':'Starter ground, steps, bridges and retaining-wall collision. Additional detailed building collision and gameplay tests are required in Studio.','robloxProperties':{'Anchored':True,'CanCollide':True,'Transparency':1}},f,indent=2)
print('COLLISION_EXPORT_COMPLETE',len(selected),flush=True)

