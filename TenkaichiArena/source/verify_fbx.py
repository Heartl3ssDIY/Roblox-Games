import bpy,bmesh,os,json
ROOT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\TenkaichiArena'
fresh=bpy.data.scenes.new('FBX_validation_only');bpy.context.window.scene=fresh
bpy.ops.import_scene.fbx(filepath=os.path.join(ROOT,'exports','Tenkaichi_Arena_Roblox.fbx'))
obs=[o for o in bpy.context.scene.objects if o.type=='MESH'];rows=[]
for ob in obs:
 ob.data.calc_loop_triangles()
 bm=bmesh.new();bm.from_mesh(ob.data)
 rows.append({'name':ob.name,'triangles':len(ob.data.loop_triangles),'uv_layers':len(ob.data.uv_layers),'zero_area_faces':sum(f.calc_area()<1e-9 for f in bm.faces),'boundary_edges':sum(e.is_boundary for e in bm.edges),'dimensions':list(ob.dimensions)})
 bm.free()
images=[{'name':im.name,'size':list(im.size),'packed':bool(im.packed_file),'path_exists':os.path.exists(bpy.path.abspath(im.filepath))} for im in bpy.data.images if im.type=='IMAGE']
report={'mesh_count':len(rows),'total_triangles':sum(r['triangles'] for r in rows),'largest_mesh':max(r['triangles'] for r in rows),'missing_uvs':[r['name'] for r in rows if not r['uv_layers']],'zero_area_faces':sum(r['zero_area_faces'] for r in rows),'meshes':rows,'images':images}
assert len(rows)==32
assert report['largest_mesh']<=20000
assert report['total_triangles']==160698
assert not report['missing_uvs']
assert all(r['boundary_edges']==0 for r in rows)
assert all(im['size'][0]>0 and (im['packed'] or im['path_exists']) for im in images)
with open(os.path.join(ROOT,'exports','fbx_validation.json'),'w',encoding='utf-8') as f:json.dump(report,f,indent=2)
print('FBX_VALIDATION',json.dumps({k:v for k,v in report.items() if k!='meshes'}))
