import bpy, json, os
from mathutils import Vector, Matrix
OUT = r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\TruckModels'
with open(os.path.join(OUT,'truck_manifest.json')) as f: models=json.load(f)
report=[]
for m in models:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=os.path.join(OUT,'Truck_'+m['name']+'.fbx'))
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
    names={o.name for o in objects}
    expected={m['name']+'_'+p['name'] for p in m['parts']}
    assert names==expected,(m['name'],names.symmetric_difference(expected))
    corners=[o.matrix_world @ Vector(c) for o in objects for c in o.bound_box]
    dims=[max(v[i] for v in corners)-min(v[i] for v in corners) for i in range(3)]
    assert abs(dims[2]-m['height'])<.02,(m['name'],dims)
    assert m['width'] < dims[0] < m['width']+2,(m['name'],dims)
    assert m['length'] < dims[1] < m['length']+2,(m['name'],dims)
    assert all(o.data.materials for o in objects)
    report.append({'model':m['name'],'parts':len(objects),'dimensions':dims,'names_and_materials':'passed'})
with open(os.path.join(OUT,'export_validation.json'),'w') as f:json.dump(report,f,indent=2)
print(json.dumps(report))
