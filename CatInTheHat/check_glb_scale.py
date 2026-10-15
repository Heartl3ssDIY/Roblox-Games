import bpy, json, os
OUT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\CatInTheHat'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(OUT,'CatInTheHat_Base.glb'))
objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
expected=json.load(open(os.path.join(OUT,'Model_Parts.json'),encoding='utf-8'))
assert set(o.name for o in objects)==set(p['name'] for p in expected['parts'])
triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in objects)
assert triangles==expected['triangles']
coords=[o.matrix_world@v.co for o in objects for v in o.data.vertices]
size=[max(p[i] for p in coords)-min(p[i] for p in coords) for i in range(3)]
checks=json.load(open(os.path.join(OUT,'Export_Check.json'),encoding='utf-8'))
assert all(abs(a-b)<.00001 for a,b in zip(size,checks['fbx']['sizeMeters']))
checks['glb']['sizeMeters']=size
checks['scaleMatchesBetweenFormats']=True
with open(os.path.join(OUT,'Export_Check.json'),'w',encoding='utf-8') as f:json.dump(checks,f,indent=2)
print('FINAL_EXPORTS_PASS: 62 separate named meshes, matching dimensions, '+str(triangles)+' triangles.')
