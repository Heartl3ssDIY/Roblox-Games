exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\TournamentOfPower\source\common.py',encoding='utf-8').read(),'common.py','exec'))
sc=bpy.context.scene
visual=[o for o in sc.objects if o.type=='MESH' and o.name.startswith('TOP_') and not any('98_Construction' in c.name for c in o.users_collection)]
report={'visual_meshes':[],'floor_diameter':116,'stand_diameter':147,'floor_height':0.026,'pillar_height':38.7,'board_bounds':[-32,32,-32,32],'pillar_collision':False,'studio_import_tested':False}
for o in visual:
 o.data.calc_loop_triangles()
 item={'name':o.name,'triangles':len(o.data.loop_triangles),'uv':bool(o.data.uv_layers),'zero_area_faces':sum(1 for p in o.data.polygons if p.area<1e-9)}
 report['visual_meshes'].append(item)
 assert item['uv'] and item['zero_area_faces']==0,item
 assert item['triangles']<14000,item
report['triangles']=sum(i['triangles'] for i in report['visual_meshes'])
def export(obs,name):
 bpy.ops.object.select_all(action='DESELECT')
 for o in obs:o.select_set(True)
 bpy.context.view_layer.objects.active=obs[0]
 bpy.ops.export_scene.fbx(filepath=os.path.join(ROOT,'exports',name),use_selection=True,object_types={'MESH'},axis_forward='Z',axis_up='Y',apply_unit_scale=True,apply_scale_options='FBX_SCALE_UNITS',use_mesh_modifiers=True,mesh_smooth_type='FACE',use_custom_props=True,bake_anim=False,path_mode='COPY',embed_textures=True,add_leaf_bones=False)
export(visual,'Tournament_of_Power_Roblox.fbx')
col=collection('85_Collision');col.hide_viewport=False
export(list(col.objects),'Tournament_of_Power_Collision.fbx')
col.hide_viewport=True
bpy.ops.object.select_all(action='DESELECT')
open(os.path.join(ROOT,'exports','mesh_report.json'),'w').write(json.dumps(report,indent=2))
bpy.data.libraries.write(os.path.join(ROOT,'Tournament_of_Power.blend'),{sc},fake_user=True,compress=True)
with bpy.data.libraries.load(os.path.join(ROOT,'Tournament_of_Power.blend'),link=False) as (src,dst):
 print('Standalone blend scenes',src.scenes)
print(json.dumps(report,indent=2))
