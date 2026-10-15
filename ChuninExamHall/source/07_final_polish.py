import bpy,bmesh,os,json
from mathutils import Vector
ROOT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\ChuninExamHall'
scene=bpy.context.scene
for ob in scene.objects:
 if ob.get('export_role')=='visual' and ob.name.startswith('10_Hand_Seal'):
  bm=bmesh.new();bm.from_mesh(ob.data);uv=bm.loops.layers.uv.active
  faces=[f for f in bm.faces if .5<sum(l[uv].uv.x for l in f.loops)/len(f.loops)<.75 and 0<sum(l[uv].uv.y for l in f.loops)/len(f.loops)<.25]
  bmesh.ops.delete(bm,geom=faces,context='FACES')
  orphan=[v for v in bm.verts if not v.link_faces]
  if orphan:bmesh.ops.delete(bm,geom=orphan,context='VERTS')
  bm.to_mesh(ob.data);bm.free();ob.data.update()
detail=bpy.data.objects['Camera_Hand_Detail'];detail.data.lens=35
detail.rotation_euler=(Vector((0,38,19))-detail.location).to_track_quat('-Z','Y').to_euler()
top=bpy.data.objects['Camera_Gameplay'];top.location=(0,-4,125)
scene.camera=detail;scene.render.resolution_x=1500;scene.render.resolution_y=1000
scene.render.filepath=os.path.join(ROOT,'previews','Hand_Seal_Detail.png');bpy.ops.render.render(write_still=True)
scene.camera=top;scene.render.resolution_x=1300;scene.render.resolution_y=1500
scene.render.filepath=os.path.join(ROOT,'previews','Chunin_Hall_Top.png');bpy.ops.render.render(write_still=True)
scene.camera=bpy.data.objects['Camera_Hall_Hero'];scene.render.resolution_x=1600;scene.render.resolution_y=1300
scene.render.filepath=os.path.join(ROOT,'previews','Chunin_Hall_Hero.png');bpy.ops.render.render(write_still=True)
visuals=[o for o in scene.objects if o.get('export_role')=='visual']
for o in bpy.context.selected_objects:o.select_set(False)
for o in visuals:o.select_set(True)
bpy.context.view_layer.objects.active=visuals[0]
bpy.ops.export_scene.fbx(filepath=os.path.join(ROOT,'exports','Chunin_Exam_Hall_Roblox.fbx'),use_selection=True,object_types={'MESH'},apply_scale_options='FBX_SCALE_UNITS',global_scale=1,axis_forward='Z',axis_up='Y',use_mesh_modifiers=True,mesh_smooth_type='FACE',add_leaf_bones=False,bake_anim=False,path_mode='COPY',embed_textures=True)
for o in bpy.context.selected_objects:o.select_set(False)
report=json.load(open(os.path.join(ROOT,'exports','mesh_report.json'),encoding='utf-8'))
for item in report['meshes']:
 ob=bpy.data.objects[item['name']];ob.data.calc_loop_triangles()
 item['triangles']=len(ob.data.loop_triangles);item['vertices']=len(ob.data.vertices)
report['total_triangles']=sum(o['triangles'] for o in report['meshes'])
json.dump(report,open(os.path.join(ROOT,'exports','mesh_report.json'),'w',encoding='utf-8'),indent=2)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'Chunin_Exam_Hall.blend'))
print("Final sculpture and preview framing refined.")
