exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\ChuninExamHall\source\common.py',encoding='utf-8').read(),'common.py','exec'))
scene=bpy.context.scene
for ob in list(scene.objects):
 if ob.type!='MESH' or ob.get('surface') is None or ob.get('export_role')=='collision':continue
 ob.data.calc_loop_triangles()
 if len(ob.data.loop_triangles)>14000:
  for o in bpy.context.selected_objects:o.select_set(False)
  ob.select_set(True);bpy.context.view_layer.objects.active=ob
  mod=ob.modifiers.new('Final mesh budget','DECIMATE');mod.ratio=13500/len(ob.data.loop_triangles)
  bpy.ops.object.modifier_apply(modifier=mod.name)
 bm=bmesh.new();bm.from_mesh(ob.data)
 bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001)
 bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=.000001)
 bad=[f for f in bm.faces if f.calc_area()<1e-10]
 if bad:bmesh.ops.delete(bm,geom=bad,context='FACES')
 bmesh.ops.triangulate(bm,faces=list(bm.faces))
 bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
 bm.to_mesh(ob.data);bm.free();ob.data.update()
def merge_batch(obs,name):
 for o in bpy.context.selected_objects:o.select_set(False)
 for o in obs:o.select_set(True)
 bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join();ob=obs[0];ob.name=name
 bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
 ob['export_role']='visual'
 return ob
for c in list(scene.collection.children):
 if not c.name[:2].isdigit() or int(c.name[:2])>=80:continue
 obs=sorted([o for o in c.objects if o.type=='MESH'],key=lambda o:o.name)
 batch=[];count=0;index=1
 for ob in obs:
  triangles=len(ob.data.polygons)
  if count+triangles>14000 and batch:
   merge_batch(batch,c.name+'_Part%02d'%index);index+=1;batch=[];count=0
  batch.append(ob);count+=triangles
 if batch:merge_batch(batch,c.name+'_Part%02d'%index)
visuals=[o for o in scene.objects if o.get('export_role')=='visual']
settings=dict(use_selection=True,object_types={'MESH'},apply_scale_options='FBX_SCALE_UNITS',global_scale=1,axis_forward='Z',axis_up='Y',use_mesh_modifiers=True,mesh_smooth_type='FACE',add_leaf_bones=False,bake_anim=False,path_mode='COPY',embed_textures=True)
for o in bpy.context.selected_objects:o.select_set(False)
for o in visuals:o.select_set(True)
bpy.context.view_layer.objects.active=visuals[0]
bpy.ops.export_scene.fbx(filepath=os.path.join(ROOT,'exports','Chunin_Exam_Hall_Roblox.fbx'),**settings)
for o in bpy.context.selected_objects:o.select_set(False)
collision=collection('85_CollisionProxies');collision.hide_viewport=False
for o in collision.objects:o.select_set(True)
bpy.context.view_layer.objects.active=list(collision.objects)[0]
settings['embed_textures']=False
bpy.ops.export_scene.fbx(filepath=os.path.join(ROOT,'exports','Chunin_Hall_Collision.fbx'),**settings)
for o in bpy.context.selected_objects:o.select_set(False)
collision.hide_viewport=True
stats=[]
for o in visuals:
 o.data.calc_loop_triangles()
 stats.append({'name':o.name,'triangles':len(o.data.loop_triangles),'vertices':len(o.data.vertices),'uv_layers':len(o.data.uv_layers)})
report={'asset':'Chunin Exam Hall','visual_mesh_count':len(stats),'total_triangles':sum(o['triangles'] for o in stats),'largest_mesh_triangles':max(o['triangles'] for o in stats),'clear_combat_area':[64,64],'combat_center':[0,-20,.2],'footprint':[82,110],'collision_mesh_count':len(collision.objects),'meshes':stats,'studio_import_tested':False}
assert report['largest_mesh_triangles']<=14000
assert all(o['uv_layers'] for o in stats)
with open(os.path.join(ROOT,'exports','mesh_report.json'),'w',encoding='utf-8') as f:json.dump(report,f,indent=2)
scene.camera=bpy.data.objects['Camera_Hall_Hero']
scene.render.filepath=os.path.join(ROOT,'previews','Chunin_Hall_Hero.png')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'Chunin_Exam_Hall.blend'))
print(json.dumps({k:v for k,v in report.items() if k!='meshes'}))
