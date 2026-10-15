exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\LoguetownArena\source\common.py',encoding='utf-8').read(),'common.py','exec'))
for x in [-68.3,68.3]:box('Paving_edge_course',(x,0,.105),(3.5,136,.06),0,'02_Paving')
box('Paving_entry_course',(0,-67.3,.105),(138,1.6,.06),0,'02_Paving')
box('Paving_rear_course',(0,66.8,.105),(138,2.8,.06),0,'02_Paving')
collection('85_Collision').hide_viewport=False
box('COL_Entrance_Landing',(0,-67.3,-.1),(28,6,.4),8,'85_Collision')
for ob in collection('85_Collision').objects:
 if ob.name.startswith('COL_Dock'):
  ob.location.y=-87.5;ob.dimensions.y=18.62
collection('85_Collision').hide_viewport=True
# Portable surface maps.
size=1024;tile=256;normal=np.ones((size,size,4),np.float32);rough=np.ones((size,size,4),np.float32);rng=np.random.default_rng(411)
y,x=np.mgrid[0:tile,0:tile]/tile
for k in range(16):
 h=.009*np.sin(x*73+y*32)*np.cos(y*51)+rng.normal(0,.002,(tile,tile))
 if k==11:h+=.025*np.sin(x*120+np.sin(y*13)*1.5)
 if k in [6,7]:h+=.009*np.sin(y*8*2*pi)
 dy,dx=np.gradient(h);v=np.stack([-dx*2,-dy*2,np.ones_like(h)],axis=2);v/=np.linalg.norm(v,axis=2)[:,:,None]
 row,col=divmod(k,4);normal[row*tile:(row+1)*tile,col*tile:(col+1)*tile,:3]=v*.5+.5
 roughval=.26 if k==13 else .42 if k in [8,9,10,14] else .81
 rough[row*tile:(row+1)*tile,col*tile:(col+1)*tile,:3]=np.clip(roughval+h,.1,1)[:,:,None]
bs=next(n for n in MAT.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
for name,arr in [('LT_NormalAtlas',normal),('LT_RoughnessAtlas',rough)]:
 im=bpy.data.images.new(name,width=size,height=size,alpha=False);im.colorspace_settings.name='Non-Color';im.pixels.foreach_set(arr.ravel());im.filepath_raw=os.path.join(ROOT,'textures',name+'.png');im.file_format='PNG';im.save();im.pack()
 tex=MAT.node_tree.nodes.new('ShaderNodeTexImage');tex.image=im
 if name=='LT_NormalAtlas':
  nm=MAT.node_tree.nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.4;MAT.node_tree.links.new(tex.outputs['Color'],nm.inputs['Color']);MAT.node_tree.links.new(nm.outputs['Normal'],bs.inputs['Normal'])
 else:MAT.node_tree.links.new(tex.outputs['Color'],bs.inputs['Roughness'])
sc=bpy.context.scene
# Preserve the component-level model before consolidation.
bpy.data.libraries.write(os.path.join(ROOT,'Loguetown_Arena_Editable.blend'),{sc},fake_user=True,compress=True)
# Consolidate each authored collection into mesh batches below 14k triangles.
visual_collections=[c for c in sc.collection.children if c.name.startswith('LT | ') and c.name.split(' | ')[1][:2].isdigit() and int(c.name.split(' | ')[1][:2])<80]
for c in visual_collections:
 obs=[o for o in c.objects if o.type=='MESH'];batches=[];batch=[];count=0
 for ob in obs:
  bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000001)
  bad=[f for f in bm.faces if f.calc_area()<1e-10]
  if bad:bmesh.ops.delete(bm,geom=bad,context='FACES')
  bm.to_mesh(ob.data);bm.free();ob.data.calc_loop_triangles()
  n=len(ob.data.loop_triangles)
  if count+n>13500 and batch:batches.append(batch);batch=[];count=0
  batch.append(ob);count+=n
 if batch:batches.append(batch)
 for i,batch in enumerate(batches):
  bpy.ops.object.select_all(action='DESELECT')
  for o in batch:o.select_set(True)
  bpy.context.view_layer.objects.active=batch[0]
  if len(batch)>1:bpy.ops.object.join()
  ob=batch[0];ob.name='LT_'+c.name.split(' | ')[1]+'_Part%02d'%(i+1)
  bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
  ob['Roblox_CanCollide']=False;ob['Roblox_Anchored']=True
visual=[o for o in sc.objects if o.type=='MESH' and not o.name.startswith('COL_')]
report={'visual_meshes':[],'studio_import_tested':False,'combat_area':{'minimum':[-32,-32,.12],'maximum':[32,32,.12],'size':[64,64]},'collision_meshes':len(collection('85_Collision').objects)}
for o in visual:
 o.data.calc_loop_triangles()
 r={'name':o.name,'triangles':len(o.data.loop_triangles),'uv':bool(o.data.uv_layers),'zero_area_triangles':sum(1 for p in o.data.loop_triangles if p.area<1e-9)}
 report['visual_meshes'].append(r)
 assert r['triangles']<14000,r
 assert r['uv'] and r['zero_area_triangles']==0,r
report['triangles']=sum(x['triangles'] for x in report['visual_meshes'])
def export(obs,name):
 bpy.ops.object.select_all(action='DESELECT')
 for o in obs:o.select_set(True)
 bpy.context.view_layer.objects.active=obs[0]
 bpy.ops.export_scene.fbx(filepath=os.path.join(ROOT,'exports',name),use_selection=True,object_types={'MESH'},axis_forward='Z',axis_up='Y',apply_scale_options='FBX_SCALE_UNITS',apply_unit_scale=True,mesh_smooth_type='FACE',use_mesh_modifiers=True,use_custom_props=True,bake_anim=False,path_mode='COPY',embed_textures=True,add_leaf_bones=False)
export(visual,'Loguetown_Arena_Roblox.fbx')
col=collection('85_Collision');col.hide_viewport=False
export(list(col.objects),'Loguetown_Arena_Collision.fbx');col.hide_viewport=True
bpy.ops.object.select_all(action='DESELECT')
open(os.path.join(ROOT,'exports','mesh_report.json'),'w').write(json.dumps(report,indent=2))
bpy.data.libraries.write(os.path.join(ROOT,'Loguetown_Arena.blend'),{sc},fake_user=True,compress=True)
print(json.dumps({'meshes':len(visual),'triangles':report['triangles'],'largest_mesh':max(x['triangles'] for x in report['visual_meshes']),'collisions':report['collision_meshes']}))
