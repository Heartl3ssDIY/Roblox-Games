import bpy, os, json
from mathutils import Vector
OUT=os.path.dirname(bpy.data.filepath)
scene=bpy.context.scene
root=bpy.data.collections['CAT IN THE HAT - editable base']
models=[o for o in root.all_objects if o.type=='MESH']
# Seat the crown securely in the uneven brim, including at the back.
o=bpy.data.objects['Hat_Band_1_Red']
for v in o.data.vertices:
    if v.co.z<6.23:v.co.z-=.075*max(0,(6.23-v.co.z)/.14)
for o in models:o.data.name=o.name
bpy.ops.object.select_all(action='DESELECT')
for o in models:o.select_set(True)
bpy.context.view_layer.objects.active=models[0]
bpy.ops.export_scene.fbx(filepath=os.path.join(OUT,'CatInTheHat_Base.fbx'),use_selection=True,object_types={'MESH'},apply_scale_options='FBX_SCALE_UNITS',axis_forward='-Z',axis_up='Y',use_mesh_modifiers=True,add_leaf_bones=False,bake_anim=False,path_mode='COPY',embed_textures=True,use_custom_props=True)
for o in models:o.scale=(.28,.28,.28)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,'CatInTheHat_Base.glb'),export_format='GLB',use_selection=True,export_yup=True,export_extras=True)
for o in models:o.scale=(1,1,1)
bpy.ops.object.select_all(action='DESELECT')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'CatInTheHat_Base.blend'))
cam=scene.camera
for filename,pos,target in [('CatInTheHat_ThreeQuarter.png',(7,-23,9),(0,0,3.97)),('CatInTheHat_Front.png',(0,-24,4.1),(0,0,4.1)),('CatInTheHat_Back.png',(-8,23,8),(0,0,3.97))]:
    cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=os.path.join(OUT,filename)
    bpy.ops.render.render(write_still=True)

# Reimport both formats into a temporary empty Blender scene and check names,
# object counts, polygon counts and material separation.
expected=json.load(open(os.path.join(OUT,'Model_Parts.json'),encoding='utf-8'))
checks={}
for ext in ['fbx','glb']:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    path=os.path.join(OUT,'CatInTheHat_Base.'+ext)
    if ext=='fbx':bpy.ops.import_scene.fbx(filepath=path,use_image_search=False)
    else:bpy.ops.import_scene.gltf(filepath=path)
    objs=[o for o in bpy.context.scene.objects if o.type=='MESH']
    assert set(o.name for o in objs)==set(p['name'] for p in expected['parts'])
    tris=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in objs)
    assert tris==expected['triangles']
    assert all(len(o.data.materials)==1 for o in objs)
    assert all(len(o.data.uv_layers)>0 for o in objs)
    coords=[o.matrix_world@v.co for o in objs for v in o.data.vertices]
    size=[max(p[i] for p in coords)-min(p[i] for p in coords) for i in range(3)]
    checks[ext]={'meshObjects':len(objs),'triangles':tris,'meshNamesMatch':True,'separateMaterials':True,'uvsPresent':True,'sizeMeters':size}
with open(os.path.join(OUT,'Export_Check.json'),'w',encoding='utf-8') as f:json.dump(checks,f,indent=2)
print('ROUNDTRIP_CHECK_PASSED '+json.dumps(checks))
