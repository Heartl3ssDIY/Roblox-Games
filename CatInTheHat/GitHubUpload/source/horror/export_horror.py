import bpy, os, json, math, bmesh
from mathutils import Vector
OUT=os.path.dirname(bpy.data.filepath)
scene=bpy.context.scene
root=bpy.data.collections['CAT IN THE HAT - editable base']
models=[o for o in root.all_objects if o.type=='MESH']
if bpy.context.object and bpy.context.object.mode!='OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.select_all(action='DESELECT')
newdetails=[o for o in models if not o.data.uv_layers]
# New eyelids, brows, and teeth use solid colour materials without sampling
# unrelated regions of the existing surface-normal atlas.
copies={}
for o in newdetails:
    old=o.data.materials[0]
    if old.name not in copies:
        m=old.copy();m.name=old.name+' - horror detail'
        shader=m.node_tree.nodes.get('Principled BSDF')
        for link in list(shader.inputs['Normal'].links):m.node_tree.links.remove(link)
        copies[old.name]=m
    o.data.materials.clear();o.data.materials.append(copies[old.name])
    o.select_set(True)
if newdetails:
    bpy.context.view_layer.objects.active=newdetails[0]
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.01)
    bpy.ops.object.mode_set(mode='OBJECT')
normal=bpy.data.images.get('Cat_SurfaceNormal')
if normal:
    normal.filepath_raw=os.path.join(OUT,'Cat_SurfaceNormal.png');normal.file_format='PNG';normal.save();normal.pack()

def to_srgb(c):return c*12.92 if c<=.0031308 else 1.055*c**(1/2.4)-.055
parts=[]
for o in models:
    bpy.context.view_layer.objects.active=o
    m=o.modifiers.new('Export triangles','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=m.name)
    o.data.name=o.name
    bm=bmesh.new();bm.from_mesh(o.data)
    bad=sum(not e.is_manifold for e in bm.edges);tiny=sum(f.calc_area()<1e-10 for f in bm.faces);bm.free()
    assert bad==0 and tiny==0,(o.name,bad,tiny)
    assert len(o.data.polygons)<=20000
    rgb=[round(max(0,min(1,to_srgb(c)))*255) for c in o.data.materials[0].diffuse_color[:3]]
    o['ColorRGB']=','.join(map(str,rgb));o['RecolorRegion']=o.data.materials[0].name
    parts.append({'name':o.name,'triangles':len(o.data.polygons),'material':o.data.materials[0].name,'colorRGB':rgb})
report={'variant':'Horror','meshObjects':len(models),'triangles':sum(p['triangles'] for p in parts),'maxMeshTriangles':max(p['triangles'] for p in parts),'nonmanifoldEdges':0,'degenerateFaces':0,'rigged':False,'parts':parts}
with open(os.path.join(OUT,'Horror_Model_Parts.json'),'w',encoding='utf-8') as f:json.dump(report,f,indent=2)
bpy.ops.object.select_all(action='DESELECT')
for o in models:o.select_set(True)
bpy.context.view_layer.objects.active=models[0]
bpy.ops.export_scene.fbx(filepath=os.path.join(OUT,'CatInTheHat_Horror.fbx'),use_selection=True,object_types={'MESH'},apply_scale_options='FBX_SCALE_UNITS',axis_forward='-Z',axis_up='Y',add_leaf_bones=False,bake_anim=False,path_mode='COPY',embed_textures=True,use_custom_props=True)
for o in models:o.scale=(.28,.28,.28)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,'CatInTheHat_Horror.glb'),export_format='GLB',use_selection=True,export_yup=True,export_extras=True)
for o in models:o.scale=(1,1,1)
bpy.ops.object.select_all(action='DESELECT')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'CatInTheHat_Horror.blend'))

# Studio-lit model view, followed by a horror-lit portrait for expression detail.
scene.render.filepath=os.path.join(OUT,'CatInTheHat_Horror_Studio.png')
bpy.ops.render.render(write_still=True)
cam=scene.camera;cam.location=(3.0,-14,6.6)
cam.rotation_euler=(Vector((0,-.20,5.95))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.ortho_scale=4.65
bpy.data.objects['Preview ground'].hide_render=True
scene.render.resolution_x=1200;scene.render.resolution_y=1200
for name,energy,color in [('Key softbox',1050,(.78,.87,1)),('Fill softbox',260,(.60,.72,.85)),('Fur rim',1250,(1,.16,.065)),('Face lift',90,(1,.85,.65))]:
    o=bpy.data.objects.get(name)
    if o:o.data.energy=energy;o.data.color=color
scene.world.node_tree.nodes.get('Background').inputs[1].default_value=.12
scene.view_settings.exposure=-.65
scene.render.filepath=os.path.join(OUT,'CatInTheHat_Horror_Portrait.png')
bpy.ops.render.render(write_still=True)

checks={}
for ext in ['fbx','glb']:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    p=os.path.join(OUT,'CatInTheHat_Horror.'+ext)
    if ext=='fbx':bpy.ops.import_scene.fbx(filepath=p,use_image_search=False)
    else:bpy.ops.import_scene.gltf(filepath=p)
    objs=[o for o in bpy.context.scene.objects if o.type=='MESH']
    assert set(o.name for o in objs)==set(p['name'] for p in parts)
    total=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in objs)
    assert total==report['triangles']
    coords=[o.matrix_world@v.co for o in objs for v in o.data.vertices]
    size=[max(p[i] for p in coords)-min(p[i] for p in coords) for i in range(3)]
    checks[ext]={'objects':len(objs),'triangles':total,'sizeMeters':size,'namesMatch':True}
assert all(abs(a-b)<1e-5 for a,b in zip(checks['fbx']['sizeMeters'],checks['glb']['sizeMeters']))
with open(os.path.join(OUT,'Horror_Export_Check.json'),'w',encoding='utf-8') as f:json.dump(checks,f,indent=2)
print('HORROR_EXPORT_PASS '+json.dumps(checks))
