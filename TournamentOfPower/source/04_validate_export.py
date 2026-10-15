import bpy,os,json
ROOT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\TournamentOfPower'
original_scene=bpy.context.scene
validation=bpy.data.scenes.new('TOP_Export_Validation')
bpy.context.window.scene=validation
existing=set(bpy.data.objects)
bpy.ops.import_scene.fbx(filepath=os.path.join(ROOT,'exports','Tournament_of_Power_Roblox.fbx'))
imported=[o for o in bpy.data.objects if o not in existing]
meshes=[o for o in imported if o.type=='MESH']
images={}
for o in meshes:
 for m in o.data.materials:
  if m and m.use_nodes:
   for n in m.node_tree.nodes:
    if n.type=='TEX_IMAGE' and n.image:
     images[n.image.name]={'loaded':n.image.has_data,'size':list(n.image.size)}
report={'mesh_count':len(meshes),'triangles':0,'all_uv':all(bool(o.data.uv_layers) for o in meshes),'zero_area_faces':0,'textures':images,'studio_import_tested':False}
for o in meshes:
 o.data.calc_loop_triangles();report['triangles']+=len(o.data.loop_triangles)
 report['zero_area_faces']+=sum(1 for p in o.data.polygons if p.area<1e-9)
pillars=[o for o in meshes if 'Center_Pillar' in o.name]
report['pillar_separate']=len(pillars)==1
report['pillar_noncollide_metadata']=pillars[0].get('Roblox_CanCollide')==False if pillars else False
assert report['mesh_count']==6 and report['triangles']==25970 and report['all_uv'] and report['zero_area_faces']==0,report
assert len(images)==3 and all(v['loaded'] for v in images.values()),report
assert report['pillar_separate'] and report['pillar_noncollide_metadata'],report
report['result']='passed'
open(os.path.join(ROOT,'exports','validation.json'),'w').write(json.dumps(report,indent=2))
bpy.context.window.scene=original_scene
for o in imported:bpy.data.objects.remove(o,do_unlink=True)
bpy.data.scenes.remove(validation)
print(json.dumps(report,indent=2))
