exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\HyperbolicTimeChamber\source\common.py',encoding='utf-8').read(),'common.py','exec'))
sc=bpy.context.scene
collections=[c for c in sc.collection.children if c.name.startswith('TC | ') and int(c.name.split(' | ')[1][:2])<80]
# Remove coincident vertices and tiny clipped-edge slivers before exporting.
for c in collections:
 for ob in c.objects:
  if ob.type!='MESH':continue
  bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7)
  bad=[f for f in bm.faces if f.calc_area()<1e-9]
  if bad:bmesh.ops.delete(bm,geom=bad,context='FACES')
  bm.to_mesh(ob.data);bm.free();ob.data.update()
for c in collections:
 for ob in list(c.objects):
  if ob.type!='MESH':continue
  old=ob.data;old.calc_loop_triangles()
  if len(old.loop_triangles)<=12000:continue
  tris=list(old.loop_triangles);uv=old.uv_layers.active;norms=[tuple(n.vector) for n in old.corner_normals]
  for chunk,start in enumerate(range(0,len(tris),12000)):
   v=[];f=[];uvs=[];mats=[];ns=[];smooth=[]
   for tri in tris[start:start+12000]:
    n=len(v);v.extend(tuple(old.vertices[i].co) for i in tri.vertices);f.append((n,n+1,n+2));uvs.extend(tuple(uv.data[i].uv) for i in tri.loops);ns.extend(norms[i] for i in tri.loops);mats.append(old.polygons[tri.polygon_index].material_index);smooth.append(old.polygons[tri.polygon_index].use_smooth)
   me=bpy.data.meshes.new(ob.name+'_Chunk');me.from_pydata(v,[],f);me.update()
   for m in old.materials:me.materials.append(m)
   layer=me.uv_layers.new(name='UVMap')
   for i,q in enumerate(uvs):layer.data[i].uv=q
   for p in me.polygons:p.material_index=mats[p.index];p.use_smooth=smooth[p.index]
   me.normals_split_custom_set(ns)
   obj=bpy.data.objects.new(ob.name+'_Chunk%02d'%(chunk+1),me);c.objects.link(obj);obj.matrix_world=ob.matrix_world.copy()
  bpy.data.objects.remove(ob,do_unlink=True)
for c in collections:
 obs=[o for o in c.objects if o.type=='MESH'];batches=[];batch=[];count=0
 for ob in obs:
  ob.data.calc_loop_triangles();n=len(ob.data.loop_triangles)
  if batch and count+n>12000:batches.append(batch);batch=[];count=0
  batch.append(ob);count+=n
 if batch:batches.append(batch)
 for i,batch in enumerate(batches):
  bpy.ops.object.select_all(action='DESELECT')
  for o in batch:o.select_set(True)
  bpy.context.view_layer.objects.active=batch[0]
  if len(batch)>1:bpy.ops.object.join()
  ob=bpy.context.view_layer.objects.active;ob.name='TC_'+c.name.split(' | ')[1]+'_Part%02d'%(i+1);ob['Roblox_Anchored']=True;ob['Roblox_CanCollide']=False
visual=[o for c in collections for o in c.objects if o.type=='MESH']
report={'visual_meshes':[],'combat_bounds':[-32,32,-32,32],'combat_surface_height':0,'collision_meshes':len(collection('85_Collision').objects),'studio_import_tested':False,'white_floor_size':[2000,2000]}
for ob in visual:
 ob.data.calc_loop_triangles()
 item={'name':ob.name,'triangles':len(ob.data.loop_triangles),'uv':bool(ob.data.uv_layers),'zero_area_triangles':sum(t.area<1e-10 for t in ob.data.loop_triangles)}
 assert item['uv'] and not item['zero_area_triangles'] and item['triangles']<=12000,item
 report['visual_meshes'].append(item)
report['triangles']=sum(i['triangles'] for i in report['visual_meshes'])
def export(obs,name):
 bpy.ops.object.select_all(action='DESELECT')
 for o in obs:o.select_set(True)
 bpy.context.view_layer.objects.active=obs[0]
 bpy.ops.export_scene.fbx(filepath=os.path.join(ROOT,'exports',name),use_selection=True,object_types={'MESH'},axis_forward='Z',axis_up='Y',apply_scale_options='FBX_SCALE_UNITS',apply_unit_scale=True,mesh_smooth_type='FACE',use_mesh_modifiers=True,use_custom_props=True,bake_anim=False,path_mode='COPY',embed_textures=True,add_leaf_bones=False)
export(visual,'Hyperbolic_Time_Chamber_Roblox.fbx')
col=collection('85_Collision');col.hide_viewport=False;bpy.context.view_layer.update()
obstructions=[]
for ob in col.objects:
 if ob.name=='COL_White_Training_Floor':continue
 pts=[ob.matrix_world@Vector(p) for p in ob.bound_box];lo=[min(p[j] for p in pts) for j in range(3)];hi=[max(p[j] for p in pts) for j in range(3)]
 if lo[0]<32 and hi[0]>-32 and lo[1]<32 and hi[1]>-32 and hi[2]>.05:obstructions.append(ob.name)
assert not obstructions,obstructions
report['combat_area_obstructions']=obstructions
export(list(col.objects),'Hyperbolic_Time_Chamber_Collision.fbx');col.hide_viewport=True
bpy.ops.object.select_all(action='DESELECT')
open(os.path.join(ROOT,'exports','mesh_report.json'),'w').write(json.dumps(report,indent=2))
bpy.data.libraries.write(os.path.join(ROOT,'Hyperbolic_Time_Chamber.blend'),{sc},fake_user=True,compress=True)
print(json.dumps({'meshes':len(visual),'triangles':report['triangles'],'collisions':report['collision_meshes'],'largest_mesh':max(i['triangles'] for i in report['visual_meshes'])}))
