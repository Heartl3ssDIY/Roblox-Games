import bpy,json,os
from mathutils import Vector
OUT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\ParcelModels'
with open(os.path.join(OUT,'parcel_manifest.json')) as f:manifest=json.load(f)
report=[]
for m in manifest['models']:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=os.path.join(OUT,m['file']))
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
    assert {o.name for o in objects}=={p['name'] for p in m['parts']}
    pts=[o.matrix_world@v.co for o in objects for v in o.data.vertices]
    lo=[min(p[i] for p in pts) for i in range(3)];hi=[max(p[i] for p in pts) for i in range(3)]
    for i,target in enumerate(m['dimensions_xyz_blender']):assert abs((hi[i]-lo[i])-target)<.05,(m['name'],lo,hi,target)
    body=next(o for o in objects if o.name.endswith('_Body'))
    assert body.data.uv_layers
    images=[n.image for n in body.active_material.node_tree.nodes if n.type=='TEX_IMAGE' and n.image]
    assert len(images)>=2,(m['name'],'Missing exported colour or normal map')
    assert all(im.size[0]==1024 for im in images)
    triangles=0
    for ob in objects:ob.data.calc_loop_triangles();triangles+=len(ob.data.loop_triangles)
    assert triangles==m['triangles']
    report.append({'name':m['name'],'parts':len(objects),'triangles':triangles,'bodyTextures':len(images),'result':'pass'})
with open(os.path.join(OUT,'export_validation.json'),'w') as f:json.dump(report,f,indent=2)
print('PARCEL_EXPORT_VALIDATION',json.dumps(report))
