exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\FujikasaneArena\source\common.py',encoding='utf-8').read(),'common.py','exec'))
sc=bpy.context.scene
collections=[c for c in sc.collection.children if c.name.startswith('FK | ') and not c.hide_render and c.name.split(' | ')[1][:2].isdigit() and int(c.name.split(' | ')[1][:2])<80]
# Clean only degenerate geometry, preserving intentional two-sided petals and banners.
for c in collections:
 for ob in list(c.objects):
  if ob.type!='MESH':continue
  bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.0000001)
  bad=[f for f in bm.faces if f.calc_area()<1e-10]
  if bad:bmesh.ops.delete(bm,geom=bad,context='FACES')
  bm.to_mesh(ob.data);bm.free();ob.data.update();ob.data.calc_loop_triangles()
  if len(ob.data.loop_triangles)<=13000:continue
  old=ob.data;triangles=list(old.loop_triangles);uv=old.uv_layers.active
  for chunk_index,start in enumerate(range(0,len(triangles),12500)):
   tris=triangles[start:start+12500];verts=[];faces=[];uvs=[];mats=[];smooth=[]
   for tri in tris:
    n=len(verts)
    verts.extend([tuple(old.vertices[v].co) for v in tri.vertices]);faces.append((n,n+1,n+2))
    uvs.extend([tuple(uv.data[li].uv) for li in tri.loops]);mats.append(old.polygons[tri.polygon_index].material_index);smooth.append(old.polygons[tri.polygon_index].use_smooth)
   me=bpy.data.meshes.new(ob.name+'_split');me.from_pydata(verts,[],faces);me.update()
   for mat in old.materials:me.materials.append(mat)
   layer=me.uv_layers.new(name='UVMap')
   for li,data in enumerate(uvs):layer.data[li].uv=data
   for p in me.polygons:p.material_index=mats[p.index];p.use_smooth=smooth[p.index]
   new=bpy.data.objects.new(ob.name+'_Chunk%02d'%(chunk_index+1),me);c.objects.link(new);new.matrix_world=ob.matrix_world.copy()
  bpy.data.objects.remove(ob,do_unlink=True)
# Consolidate nearby authored components into bounded batches.
for c in collections:
 obs=[o for o in c.objects if o.type=='MESH'];batch=[];count=0;batches=[]
 for ob in obs:
  ob.data.calc_loop_triangles();n=len(ob.data.loop_triangles)
  if batch and count+n>13200:batches.append(batch);batch=[];count=0
  batch.append(ob);count+=n
 if batch:batches.append(batch)
 for i,batch in enumerate(batches):
  ob=join_batch(batch,'FK_'+c.name.split(' | ')[1]+'_Part%02d'%(i+1));ob['Roblox_Anchored']=True;ob['Roblox_CanCollide']=False
visual=[o for c in collections for o in c.objects if o.type=='MESH']
report={'visual_meshes':[],'collision_meshes':len(collection('85_Collision').objects),'tree_count':15,'combat_bounds':[-32,32,-32,32],'post_spacing_width':76,'post_spacing_length':86,'studio_import_tested':False}
for ob in visual:
 ob.data.calc_loop_triangles()
 item={'name':ob.name,'triangles':len(ob.data.loop_triangles),'uv':bool(ob.data.uv_layers),'zero_area_triangles':sum(1 for t in ob.data.loop_triangles if t.area<1e-10)}
 assert item['uv'] and item['zero_area_triangles']==0 and item['triangles']<14000,item
 report['visual_meshes'].append(item)
report['triangles']=sum(i['triangles'] for i in report['visual_meshes'])
collection('85_Collision').hide_viewport=False
bpy.context.view_layer.update()
obstructions=[]
for ob in collection('85_Collision').objects:
 if ob.name.startswith(('COL_Clearing','COL_Approach','COL_Rear_Terrace')):continue
 pts=[ob.matrix_world@Vector(p) for p in ob.bound_box]
 lo=[min(p[j] for p in pts) for j in range(3)];hi=[max(p[j] for p in pts) for j in range(3)]
 if lo[0]<32 and hi[0]>-32 and lo[1]<32 and hi[1]>-32 and hi[2]>.15:obstructions.append(ob.name)
assert not obstructions,obstructions
report['combat_area_obstructions']=obstructions
collection('85_Collision').hide_viewport=True
def export(obs,name):
 bpy.ops.object.select_all(action='DESELECT')
 for ob in obs:ob.select_set(True)
 bpy.context.view_layer.objects.active=obs[0]
 bpy.ops.export_scene.fbx(filepath=os.path.join(ROOT,'exports',name),use_selection=True,object_types={'MESH'},axis_forward='Z',axis_up='Y',apply_scale_options='FBX_SCALE_UNITS',apply_unit_scale=True,mesh_smooth_type='FACE',use_mesh_modifiers=True,use_custom_props=True,bake_anim=False,path_mode='COPY',embed_textures=True,add_leaf_bones=False)
# Preserve both sides of petals and banners through FBX mesh validation.
for ob in visual:
 old=ob.data;old.calc_loop_triangles();normals=[tuple(n.vector) for n in old.corner_normals];uv=old.uv_layers.active
 verts=[];faces=[];uvs=[];ns=[];mi=[];sm=[]
 for tri in old.loop_triangles:
  n=len(verts);verts.extend(tuple(old.vertices[v].co) for v in tri.vertices);faces.append((n,n+1,n+2))
  uvs.extend(tuple(uv.data[li].uv) for li in tri.loops);ns.extend(normals[li] for li in tri.loops);mi.append(old.polygons[tri.polygon_index].material_index);sm.append(old.polygons[tri.polygon_index].use_smooth)
 me=bpy.data.meshes.new(ob.name+'_ExportMesh');me.from_pydata(verts,[],faces);me.update()
 for mat in old.materials:me.materials.append(mat)
 layer=me.uv_layers.new(name='UVMap')
 for i,value in enumerate(uvs):layer.data[i].uv=value
 for p in me.polygons:p.material_index=mi[p.index];p.use_smooth=sm[p.index]
 me.normals_split_custom_set(ns);ob.data=me
export(visual,'Fujikasane_Arena_Roblox.fbx')
col=collection('85_Collision');col.hide_viewport=False
export(list(col.objects),'Fujikasane_Arena_Collision.fbx');col.hide_viewport=True
bpy.ops.object.select_all(action='DESELECT')
open(os.path.join(ROOT,'exports','mesh_report.json'),'w').write(json.dumps(report,indent=2))
sc.camera=bpy.data.objects['FK_Camera_Hero']
bpy.data.libraries.write(os.path.join(ROOT,'Fujikasane_Arena.blend'),{sc},fake_user=True,compress=True)
print(json.dumps({'meshes':len(visual),'triangles':report['triangles'],'max_mesh':max(i['triangles'] for i in report['visual_meshes']),'collisions':report['collision_meshes'],'combat_area_clear':not obstructions}))
