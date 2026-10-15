import bpy,json,os,math
from mathutils import Vector
OUT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\TruckModels\Realistic'
with open(os.path.join(OUT,'realistic_manifest.json')) as f:models=json.load(f)
report=[]
for m in models:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=os.path.join(OUT,'Realistic_'+m['name']+'.fbx'))
    objects={ob.name:ob for ob in bpy.context.scene.objects if ob.type=='MESH'}
    assert set(objects)=={p['name'] for p in m['parts']},m['name']+' names differ'
    for p in m['parts']:
        ob=objects[p['name']];coords=[ob.matrix_world@v.co for v in ob.data.vertices]
        assert all(math.isfinite(q) for v in coords for q in v)
        assert len(ob.data.uv_layers)>0
        mini=Vector([min(v[i] for v in coords) for i in range(3)]);maxi=Vector([max(v[i] for v in coords) for i in range(3)])
        target=Vector((-p['center'][0],p['center'][2],p['center'][1]))
        assert ((mini+maxi)/2-target).length<.003,(p['name'],'centre',list((mini+maxi)/2),list(target))
        targetsize=Vector((p['size'][0],p['size'][2],p['size'][1]))
        assert ((maxi-mini)-targetsize).length<.003,(p['name'],'size')
        assert sum(len(poly.vertices)-2 for poly in ob.data.polygons)<=8000
        assert ob.data.materials
        node=next(n for n in ob.data.materials[0].node_tree.nodes if n.type=='BSDF_PRINCIPLED')
        node.inputs['Roughness'].default_value=p['roughness'];node.inputs['Metallic'].default_value=p['metallic']
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,'Realistic_'+m['name']+'.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_animations=False,export_extras=False)
    with open(os.path.join(OUT,'Realistic_'+m['name']+'.glb'),'rb') as f:
        import struct
        f.read(12);n,kind=struct.unpack('<II',f.read(8));gltf=json.loads(f.read(n))
    mesh_nodes=[n for n in gltf['nodes'] if 'mesh' in n]
    assert {n['name'] for n in mesh_nodes}==set(objects),'GLB contains unexpected content'
    report.append({'name':m['name'],'meshParts':len(objects),'triangles':m['triangles'],'maxTrianglesPerMesh':max(p['triangles'] for p in m['parts']),'geometry_names_uv_materials':'passed','glb_content':'truck only'})
with open(os.path.join(OUT,'validation.json'),'w') as f:json.dump(report,f,indent=2)
print(json.dumps(report))
