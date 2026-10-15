import bpy,os,json
ROOT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\ChuninExamHall'
original=bpy.context.window.scene
validation=bpy.data.scenes.new('Chunin_FBX_Validation')
bpy.context.window.scene=validation
try:
 bpy.ops.import_scene.fbx(filepath=os.path.join(ROOT,'exports','Chunin_Exam_Hall_Roblox.fbx'))
 meshes=[o for o in validation.objects if o.type=='MESH']
 stats=[];zero=0
 for o in meshes:
  o.data.calc_loop_triangles()
  stats.append({'name':o.name,'triangles':len(o.data.loop_triangles),'uv':len(o.data.uv_layers)})
  zero+=sum(1 for p in o.data.polygons if p.area<1e-10)
 textures=set()
 for o in meshes:
  for m in o.data.materials:
   if m and m.use_nodes:
    for n in m.node_tree.nodes:
     if n.type=='TEX_IMAGE' and n.image and n.image.size[0]>0:textures.add(n.image.name)
 assert len(meshes)==15,len(meshes)
 assert all(x['uv'] for x in stats)
 assert max(x['triangles'] for x in stats)<=14000
 assert zero==0,zero
 report={'meshes':len(meshes),'triangles':sum(x['triangles'] for x in stats),'zero_area_faces':zero,'all_meshes_have_uv':True,'loaded_textures':sorted(textures),'round_trip':'passed','studio_import_tested':False}
 json.dump(report,open(os.path.join(ROOT,'exports','fbx_validation.json'),'w',encoding='utf-8'),indent=2)
 print(json.dumps(report))
finally:
 bpy.context.window.scene=original
 for o in list(validation.objects):bpy.data.objects.remove(o,do_unlink=True)
 bpy.data.scenes.remove(validation)
