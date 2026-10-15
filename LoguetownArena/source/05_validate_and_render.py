import bpy,os,json
from mathutils import Vector
ROOT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\LoguetownArena'
sc=bpy.context.scene
obstructions=[]
for o in sc.objects:
 if not o.name.startswith('COL_'):continue
 if o.name.startswith(('COL_Main_Square','COL_Rear_Base','COL_Quay','COL_Dock','COL_Entrance')):continue
 pts=[o.matrix_world@Vector(p) for p in o.bound_box]
 lo=[min(p[i] for p in pts) for i in range(3)];hi=[max(p[i] for p in pts) for i in range(3)]
 if lo[0]<32 and hi[0]>-32 and lo[1]<32 and hi[1]>-32 and hi[2]>.13:obstructions.append(o.name)
assert not obstructions,obstructions
expected=json.load(open(os.path.join(ROOT,'exports','mesh_report.json')))
validation=bpy.data.scenes.new('LT_Export_Check');bpy.context.window.scene=validation
existing=set(bpy.data.objects)
bpy.ops.import_scene.fbx(filepath=os.path.join(ROOT,'exports','Loguetown_Arena_Roblox.fbx'))
new=[o for o in bpy.data.objects if o not in existing];meshes=[o for o in new if o.type=='MESH']
textures={}
report={'mesh_count':len(meshes),'triangles':0,'all_uv':all(bool(o.data.uv_layers) for o in meshes),'zero_area_triangles':0,'combat_area_obstructions':obstructions,'studio_import_tested':False}
for o in meshes:
 o.data.calc_loop_triangles();report['triangles']+=len(o.data.loop_triangles);report['zero_area_triangles']+=sum(1 for p in o.data.loop_triangles if p.area<1e-9)
 for m in o.data.materials:
  if m and m.use_nodes:
   for n in m.node_tree.nodes:
    if n.type=='TEX_IMAGE' and n.image:textures[n.image.name]={'loaded':n.image.has_data,'size':list(n.image.size)}
report['textures']=textures
assert report['mesh_count']==len(expected['visual_meshes']) and report['triangles']==expected['triangles'],report
assert report['all_uv'] and report['zero_area_triangles']==0 and len(textures)==3 and all(v['loaded'] for v in textures.values()),report
report['result']='passed'
open(os.path.join(ROOT,'exports','validation.json'),'w').write(json.dumps(report,indent=2))
bpy.context.window.scene=sc
for o in new:bpy.data.objects.remove(o,do_unlink=True)
bpy.data.scenes.remove(validation)
for name,cam,w,h in [('Loguetown_Hero.png','LT_Camera_Hero',1700,1400),('Loguetown_Entrance.png','LT_Camera_Entrance',1700,1100),('Loguetown_Top.png','LT_Camera_Top',1500,1700)]:
 sc.camera=bpy.data.objects[cam];sc.render.resolution_x=w;sc.render.resolution_y=h;sc.render.filepath=os.path.join(ROOT,'previews',name);bpy.ops.render.render(write_still=True)
sc.camera=bpy.data.objects['LT_Camera_Hero'];sc.render.resolution_x=1700;sc.render.resolution_y=1400;sc.render.filepath=os.path.join(ROOT,'previews','Loguetown_Hero.png')
bpy.data.libraries.write(os.path.join(ROOT,'Loguetown_Arena.blend'),{sc},fake_user=True,compress=True)
print(json.dumps(report,indent=2))
