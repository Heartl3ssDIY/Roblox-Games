import bpy,os,json,math
from mathutils import Vector,Matrix
from collections import defaultdict
OUT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\TruckModels\Realistic'
scene=bpy.data.scenes['To be rich - Trucks'];bpy.context.window.scene=scene;scene.frame_set(1);bpy.context.view_layer.update()
models=bpy.app.driver_namespace['real_trucks'];deps=bpy.context.evaluated_depsgraph_get()
temp=bpy.data.collections.new('RealTruck export temporary');scene.collection.children.link(temp)
manifest=[]
def xyz(v):return [v.x,v.z,-v.y]
for m in models:
    spec=m['spec'];tier=spec['name'];offset=Vector(spec['offset']);buckets=defaultdict(list);copies=[]
    for ob in m['objects']:
        ma=ob.data.materials[0];short=ma.name.split('RealTruck_')[-1].split('.')[0]
        part=ob.get('PartName','');group=ob.get('RigGroup','Body');separate=''
        if part.startswith(('CargoWall','CargoRoof','CargoFront','CargoDeck','CabDoorLower','CabRoof','AerodynamicRoofDeflector')):separate=part
        buckets[(group,short,separate)].append(ob)
    partinfo=[]
    for (group,short,separate),sources in buckets.items():
        batch=[];tris=0;chunk=0
        batches=[]
        for ob in sources:
            ev=ob.evaluated_get(deps);mesh=bpy.data.meshes.new_from_object(ev,preserve_all_data_layers=True,depsgraph=deps)
            mesh.transform(Matrix.Translation(-offset) @ ob.matrix_world)
            ntris=sum(len(p.vertices)-2 for p in mesh.polygons)
            if batch and tris+ntris>8000:batches.append(batch);batch=[];tris=0
            copy=bpy.data.objects.new('EXPORT_COMPONENT',mesh);temp.objects.link(copy);batch.append(copy);tris+=ntris
        if batch:batches.append(batch)
        for batch in batches:
            bpy.ops.object.select_all(action='DESELECT')
            for ob in batch:ob.select_set(True)
            bpy.context.view_layer.objects.active=batch[0]
            bpy.ops.object.join();ob=batch[0];chunk+=1
            ob.name=tier+'__'+group+'__'+(separate or short)+('_'+str(chunk) if len(batches)>1 else '')
            bpy.context.view_layer.update()
            # Compact UVs allow later paint/roughness textures without rebuilding the meshes.
            bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=1.151917,island_margin=.015);bpy.ops.object.mode_set(mode='OBJECT')
            coords=[v.co for v in ob.data.vertices]
            minimum=Vector([min(p[i] for p in coords) for i in range(3)]);maximum=Vector([max(p[i] for p in coords) for i in range(3)])
            ma=ob.data.materials[0];node=next(n for n in ma.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
            partinfo.append({'name':ob.name,'group':group,'material':short,'rgb':list(ma.get('RGB',[128,128,128])),'roughness':float(node.inputs['Roughness'].default_value),'metallic':float(node.inputs['Metallic'].default_value),'isBody':short in [tier+'Paint',tier+'Cargo'],'center':xyz((minimum+maximum)/2),'size':[maximum.x-minimum.x,maximum.z-minimum.z,maximum.y-minimum.y],'triangles':sum(len(p.vertices)-2 for p in ob.data.polygons)})
            ob.data.transform(Matrix.Rotation(math.pi,4,'Z'));copies.append(ob)
    bpy.ops.object.select_all(action='DESELECT')
    for ob in copies:ob.select_set(True)
    bpy.context.view_layer.objects.active=copies[0]
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT,'Realistic_'+tier+'.fbx'),use_selection=True,object_types={'MESH'},apply_unit_scale=True,apply_scale_options='FBX_SCALE_UNITS',axis_forward='-Z',axis_up='Y',global_scale=1,mesh_smooth_type='FACE',bake_anim=False,add_leaf_bones=False,use_custom_props=False)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,'Realistic_'+tier+'.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_animations=False,export_extras=False)
    manifest.append({'name':tier,'width':spec['width'],'height':spec['height'],'length':spec['length'],'groups':spec['groups'],'cargo':spec['cargo'],'rear':spec['rear'],'parts':partinfo,'triangles':sum(p['triangles'] for p in partinfo),'meshParts':len(partinfo)})
    for ob in copies:
        mesh=ob.data;bpy.data.objects.remove(ob,do_unlink=True);bpy.data.meshes.remove(mesh)
    print(tier,len(partinfo),manifest[-1]['triangles'],flush=True)
bpy.data.collections.remove(temp)
with open(os.path.join(OUT,'realistic_manifest.json'),'w') as f:json.dump(manifest,f,indent=2)
bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
print('Export complete')
