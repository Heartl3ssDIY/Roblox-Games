import bpy,json,os
from mathutils import Vector
OUT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\LaptopModels'
with open(os.path.join(OUT,'laptop_manifest.json')) as f:manifest=json.load(f)
report=[]
for m in manifest['models']:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=os.path.join(OUT,m['file']))
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
    pts=[o.matrix_world@v.co for o in objects for v in o.data.vertices]
    lo=[min(p[i] for p in pts) for i in range(3)];hi=[max(p[i] for p in pts) for i in range(3)]
    names={o.name for o in objects}
    assert names=={p['name'] for p in m['parts']},(m['brand'],'Names do not match')
    assert abs((hi[0]-lo[0])*m['slot_scale']-m['runtime_width'])<.015,(m['brand'],lo,hi)
    assert abs(lo[2])<.001,(m['brand'],'Feet not at zero',lo)
    assert (hi[2]-lo[2])*m['slot_scale']>1.7,(m['brand'],'Lid height lost')
    screen=next(o for o in objects if o.name==m['brand']+'_Screen')
    assert screen.active_material.diffuse_color[0]<.001
    triangles=0
    for ob in objects:ob.data.calc_loop_triangles();triangles+=len(ob.data.loop_triangles)
    assert triangles==m['triangles']
    report.append({'brand':m['brand'],'parts':len(objects),'triangles':triangles,'bounds':{'min':lo,'max':hi},'result':'pass'})
with open(os.path.join(OUT,'export_validation.json'),'w') as f:json.dump(report,f,indent=2)
print('EXPORT_VALIDATION',json.dumps(report))
