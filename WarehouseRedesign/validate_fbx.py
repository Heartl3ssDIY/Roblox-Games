import bpy, json, os
from mathutils import Vector
folder=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\WarehouseRedesign'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=os.path.join(folder,'To_be_rich_Warehouse.fbx'))
expected=json.load(open(os.path.join(folder,'parts_manifest.json'),encoding='utf-8'))
meshes={o.name:o for o in bpy.context.scene.objects if o.type=='MESH'}
missing=[];position_error=[];size_error=[];material_error=[];triangles=0;max_err=0
for p in expected['objects']:
    ob=meshes.get(p['name'])
    if ob is None:missing.append(p['name']);continue
    target=Vector((p['position'][0],-p['position'][2],p['position'][1]))
    delta=(ob.location-target).length;max_err=max(max_err,delta)
    if delta>.002:position_error.append([ob.name,delta])
    target_size=Vector((p['size'][0],p['size'][2],p['size'][1]))
    if (ob.dimensions-target_size).length>.003:size_error.append([ob.name,list(ob.dimensions),list(target_size)])
    if len(ob.data.materials)!=1:material_error.append(ob.name)
    ob.data.calc_loop_triangles();triangles+=len(ob.data.loop_triangles)
result={'expected_meshes':len(expected['objects']),'imported_meshes':len(meshes),'triangles':triangles,'missing':missing,'position_errors':position_error,'size_errors':size_error,'material_errors':material_error,'max_position_error':max_err}
with open(os.path.join(folder,'validation.json'),'w') as f:json.dump(result,f,indent=2)
print(json.dumps(result))
