import bpy,os,json
ROOT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\HyperbolicTimeChamber'
sc=bpy.context.scene
expected=json.load(open(os.path.join(ROOT,'exports','mesh_report.json')))
test=bpy.data.scenes.new('TC_Export_Check');bpy.context.window.scene=test;existing=set(bpy.data.objects)
bpy.ops.import_scene.fbx(filepath=os.path.join(ROOT,'exports','Hyperbolic_Time_Chamber_Roblox.fbx'))
new=[o for o in bpy.data.objects if o not in existing];meshes=[o for o in new if o.type=='MESH'];textures={}
report={'visual_meshes':len(meshes),'triangles':0,'zero_area_triangles':0,'all_uv':all(bool(o.data.uv_layers) for o in meshes),'combat_area_obstructions':expected['combat_area_obstructions'],'studio_import_tested':False}
for o in meshes:
 o.data.calc_loop_triangles();report['triangles']+=len(o.data.loop_triangles);report['zero_area_triangles']+=sum(t.area<1e-10 for t in o.data.loop_triangles)
 for mat in o.data.materials:
  if mat and mat.use_nodes:
   for n in mat.node_tree.nodes:
    if n.type=='TEX_IMAGE' and n.image:textures[n.image.name]={'loaded':n.image.has_data,'size':list(n.image.size)}
report['textures']=textures
assert report['visual_meshes']==len(expected['visual_meshes']) and report['triangles']==expected['triangles'],report
assert report['all_uv'] and report['zero_area_triangles']==0 and len(textures)==3 and all(v['loaded'] for v in textures.values()),report
for o in new:bpy.data.objects.remove(o,do_unlink=True)
existing=set(bpy.data.objects)
bpy.ops.import_scene.fbx(filepath=os.path.join(ROOT,'exports','Hyperbolic_Time_Chamber_Collision.fbx'))
new=[o for o in bpy.data.objects if o not in existing];report['collision_meshes']=sum(o.type=='MESH' for o in new)
assert report['collision_meshes']==expected['collision_meshes'],report
bpy.context.window.scene=sc
for o in new:bpy.data.objects.remove(o,do_unlink=True)
bpy.data.scenes.remove(test)
report['result']='passed';open(os.path.join(ROOT,'exports','validation.json'),'w').write(json.dumps(report,indent=2))
for name,cam,w,h in [('Time_Chamber_Hero.png','TC_Camera_Hero',1800,1300),('Time_Chamber_Front.png','TC_Camera_Front',1800,950),('Time_Chamber_Layout.png','TC_Camera_Layout',1600,1300),('Time_Chamber_Top.png','TC_Camera_Top',1500,1500)]:
 sc.camera=bpy.data.objects[cam];sc.render.resolution_x=w;sc.render.resolution_y=h;sc.render.filepath=os.path.join(ROOT,'previews',name);bpy.ops.render.render(write_still=True)
sc.camera=bpy.data.objects['TC_Camera_Hero'];sc.render.resolution_x=1800;sc.render.resolution_y=1300;sc.render.filepath=os.path.join(ROOT,'previews','Time_Chamber_Hero.png')
bpy.data.libraries.write(os.path.join(ROOT,'Hyperbolic_Time_Chamber.blend'),{sc},fake_user=True,compress=True)
print(json.dumps(report,indent=2))
