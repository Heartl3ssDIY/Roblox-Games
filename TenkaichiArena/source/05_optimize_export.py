exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\TenkaichiArena\source\common.py',encoding='utf-8').read(),'common.py','exec'))
scene=bpy.context.scene;bpy.ops.object.select_all(action='DESELECT')
# Apply geometry-only reductions and clean collapsed faces on each construction part.
deps=bpy.context.evaluated_depsgraph_get()
for ob in list(scene.objects):
 if ob.type!='MESH':continue
 if ob.modifiers:
  ev=ob.evaluated_get(deps);me=bpy.data.meshes.new_from_object(ev,depsgraph=deps);ob.modifiers.clear();ob.data=me
 bm=bmesh.new();bm.from_mesh(ob.data)
 short=[e for e in bm.edges if e.calc_length()<.00001]
 if short:
  bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001)
  bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=.000001)
 bad=[f for f in bm.faces if f.calc_area()<1e-10]
 if bad:bmesh.ops.delete(bm,geom=bad,context='FACES')
 bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(ob.data);bm.free();ob.data.update()
def join_subset(obs,name):
 bpy.ops.object.select_all(action='DESELECT')
 for o in obs:o.select_set(True)
 bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join();ob=obs[0];ob.name=name
 bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
 ob['export_role']='visual';return ob
for c in list(scene.collection.children):
 if c.name=='90_Presentation':continue
 obs=sorted([o for o in c.objects if o.type=='MESH'],key=lambda o:o.name)
 batch=[];count=0;idx=1
 for ob in obs:
  tri=len(ob.data.polygons)
  if count+tri>14000 and batch:
   join_subset(batch,c.name+'_Part%02d'%idx);idx+=1;batch=[];count=0
  batch.append(ob);count+=tri
 if batch:join_subset(batch,c.name+'_Part%02d'%idx)
# Explicit gameplay markers are non-rendering references, excluded from mesh export.
for name,loc in [('Team_A_Spawn',(-13,-4,2.56)),('Team_B_Spawn',(13,-4,2.56)),('Arena_Center',(0,-4,2.56)),('Spectator_Camera',(0,-70,52))]:
 ob=bpy.data.objects.new(name,None);collection('80_GameplayMarkers').objects.link(ob);ob.location=loc;ob.empty_display_size=1;ob['purpose']='Reference marker only; no game logic'
# Collision proxies export separately; no detailed decorative mesh needs precise collision.
g='85_CollisionProxies'
box('COL_Ground',(0,10,-.3),(157.5,153.5,.9),0,g)
box('COL_Ring',(0,-4,1.27),(64.5,64.5,2.54),0,g)
box('COL_TempleFloor',(0,51,1.25),(80,26,2.5),0,g)
box('COL_EntryWalk',(0,33.5,1.25),(10,11,2.5),0,g)
for side in [-1,1]:
 for row in range(8):
  top=1+row*1.42
  box('COL_Stand_'+('West' if side<0 else 'East')+'_%02d'%row,(side*(44.5+row*2.8),-4,top/2),(2.8,66,top),0,g)
 for k in range(4):
  top=.6*(k+1);box('COL_RingStair_'+str(side)+'_'+str(k),(side*(32.5+.65*(4-k)),-27,top/2),(1.3,6,top),0,g)
 for row in range(4):
  top=.8+row*1.3;box('COL_FrontStand_'+str(side)+'_'+str(row),(side*24,-49-row*2.7,top/2),(30,2.7,top),0,g)
for ob in collection(g).objects:ob['export_role']='collision';ob.hide_render=True;ob.display_type='WIRE'
collection(g).hide_render=True;collection(g).hide_viewport=True
# Export visual meshes using Roblox's documented FBX unit-scale conversion.
visuals=[o for o in scene.objects if o.type=='MESH' and o.get('export_role')=='visual']
bpy.ops.object.select_all(action='DESELECT')
for ob in visuals:ob.select_set(True)
bpy.context.view_layer.objects.active=visuals[0]
settings=dict(use_selection=True,object_types={'MESH'},apply_scale_options='FBX_SCALE_UNITS',global_scale=1,axis_forward='Z',axis_up='Y',use_mesh_modifiers=True,mesh_smooth_type='FACE',add_leaf_bones=False,bake_anim=False,path_mode='COPY',embed_textures=True)
bpy.ops.export_scene.fbx(filepath=os.path.join(ROOT,'exports','Tenkaichi_Arena_Roblox.fbx'),**settings)
# Collision FBX contains untextured boxes and should be imported with identical settings.
bpy.ops.object.select_all(action='DESELECT');collection(g).hide_viewport=False
for ob in collection(g).objects:ob.select_set(True)
bpy.context.view_layer.objects.active=list(collection(g).objects)[0]
settings['embed_textures']=False
bpy.ops.export_scene.fbx(filepath=os.path.join(ROOT,'exports','Tenkaichi_Collision.fbx'),**settings)
collection(g).hide_viewport=True;bpy.ops.object.select_all(action='DESELECT')
# Budget report and output verification.
stats=[]
for ob in visuals:
 ob.data.calc_loop_triangles()
 stats.append({'name':ob.name,'triangles':len(ob.data.loop_triangles),'vertices':len(ob.data.vertices),'uv_layers':len(ob.data.uv_layers)})
report={'asset':'Tenkaichi tropical arena','visual_mesh_count':len(stats),'total_triangles':sum(o['triangles'] for o in stats),'largest_mesh_triangles':max(o['triangles'] for o in stats),'ring_size_studs':[64,64],'scene_units':'1 Blender unit intended as 1 Roblox stud; import Scale Unit Stud','collision_mesh_count':len(collection(g).objects),'meshes':stats,'studio_import_tested':False}
assert report['largest_mesh_triangles']<=20000
assert all(o['uv_layers'] for o in stats)
with open(os.path.join(ROOT,'exports','mesh_report.json'),'w',encoding='utf-8') as f:json.dump(report,f,indent=2)
scene.camera=bpy.data.objects['Camera_Hero'];scene.render.resolution_x=1800;scene.render.resolution_y=1350
scene.render.filepath=os.path.join(ROOT,'previews','Arena_Hero.png')
screenshot_view()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'Tenkaichi_Arena.blend'))
print(json.dumps({k:v for k,v in report.items() if k!='meshes'}))
