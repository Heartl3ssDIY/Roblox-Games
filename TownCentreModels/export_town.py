import bpy,json,os,math
from mathutils import Vector,Matrix
from collections import defaultdict
OUT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\TownCentreModels'
scene=bpy.data.scenes['To be rich - Town Centre'];bpy.context.window.scene=scene;bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get()
records=bpy.app.driver_namespace['town_models'];temp=bpy.data.collections.new('Town export temporary');scene.collection.children.link(temp)
manifest=[]
def rgb_of(ma):
    if 'RGB' in ma:return list(ma['RGB'])
    rgb=next(n for n in ma.node_tree.nodes if n.type=='BSDF_PRINCIPLED').inputs['Base Color'].default_value
    return [round(255*(12.92*c if c<=.0031308 else 1.055*c**(1/2.4)-.055)) for c in rgb[:3]]
for rec in records:
    name=rec['name'];root=rec['root'];inverse=root.matrix_world.inverted();buckets=defaultdict(list);copies=[];partinfo=[]
    for ob in rec['objects']:
        if ob.hide_render:continue
        group=ob.get('RigGroup','Shell');part=ob['PartName'];ma=ob.data.materials[0]
        separate=rec['kind']=='building' or part.startswith(('CargoWall','CargoRoof','CargoFront','CargoDeck'))
        key=(group,part) if separate else (group,ma.name)
        buckets[key].append(ob)
    for (group,key),sources in buckets.items():
        batch=[];ntris=0;batches=[]
        for ob in sources:
            mesh=bpy.data.meshes.new_from_object(ob.evaluated_get(deps),preserve_all_data_layers=True,depsgraph=deps);mesh.transform(inverse@ob.matrix_world)
            tris=sum(len(p.vertices)-2 for p in mesh.polygons)
            if batch and ntris+tris>8000:batches.append(batch);batch=[];ntris=0
            copy=bpy.data.objects.new('TOWN_EXPORT_COMPONENT',mesh);temp.objects.link(copy);copy['Solid']=ob.get('Solid',False) or (rec['kind']=='truck' and ob['PartName'].startswith(('CargoWall','CargoRoof','CargoFront','CargoDeck')));batch.append(copy);ntris+=tris
        if batch:batches.append(batch)
        for number,batch in enumerate(batches,1):
            bpy.ops.object.select_all(action='DESELECT')
            for ob in batch:ob.select_set(True)
            bpy.context.view_layer.objects.active=batch[0]
            solid=any(o.get('Solid') for o in batch)
            if len(batch)>1:bpy.ops.object.join()
            ob=batch[0];suffix=key.replace('RealTruck_','').replace('Town_','').split('.')[0]
            ob.name=name+'__'+group+'__'+suffix+('_'+str(number) if len(batches)>1 else '')
            if len(ob.data.uv_layers)==0:
                bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=1.151917,island_margin=.015);bpy.ops.object.mode_set(mode='OBJECT')
            coords=[v.co for v in ob.data.vertices];lo=Vector([min(v[i] for v in coords) for i in range(3)]);hi=Vector([max(v[i] for v in coords) for i in range(3)]);c=(lo+hi)/2;s=hi-lo
            ma=ob.data.materials[0];node=next(n for n in ma.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
            partinfo.append({'name':ob.name,'group':group,'part':suffix,'rgb':rgb_of(ma),'transparency':1-float(node.inputs['Alpha'].default_value),'roughness':float(node.inputs['Roughness'].default_value),'metallic':float(node.inputs['Metallic'].default_value),'solid':bool(solid),'center':[c.x,c.z,-c.y],'size':[s.x,s.z,s.y],'triangles':sum(len(p.vertices)-2 for p in ob.data.polygons)})
            ob.data.transform(Matrix.Rotation(math.pi,4,'Z'));copies.append(ob)
    bpy.ops.object.select_all(action='DESELECT')
    for ob in copies:ob.select_set(True)
    bpy.context.view_layer.objects.active=copies[0]
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT,name+'.fbx'),use_selection=True,object_types={'MESH'},apply_unit_scale=True,apply_scale_options='FBX_SCALE_UNITS',axis_forward='-Z',axis_up='Y',global_scale=1,mesh_smooth_type='FACE',bake_anim=False,add_leaf_bones=False,use_custom_props=False)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,name+'.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_animations=False,export_extras=False)
    data={k:value for k,value in rec.items() if k not in ['root','objects','offset']};data['parts']=partinfo;data['meshParts']=len(partinfo);data['triangles']=sum(p['triangles'] for p in partinfo)
    if rec['kind']=='truck':data['exportPose']='rear doors already open; front wheels turned; ground-centred pivot'
    manifest.append(data)
    for ob in copies:
        mesh=ob.data;bpy.data.objects.remove(ob,do_unlink=True);bpy.data.meshes.remove(mesh)
    print(name,len(partinfo),data['triangles'],flush=True)
bpy.data.collections.remove(temp)
with open(os.path.join(OUT,'town_manifest.json'),'w') as f:json.dump(manifest,f,indent=2)
bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
print('Town models exported')
