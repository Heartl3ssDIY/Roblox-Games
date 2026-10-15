import bpy, json, math, os
from mathutils import Vector, Matrix
OUT = r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\TruckModels'
scene = bpy.data.scenes['To be rich - Trucks']
bpy.context.window.scene = scene
scene.frame_set(1)
models = bpy.app.driver_namespace['truck_models']
for m in models:
    root = bpy.data.objects[m['name'] + '_Truck']
    offset = Vector(m['offset'])
    for name, info in m['groups'].items():
        pivot = bpy.data.objects.new(m['name'] + '_' + name + '_Pivot', None)
        root.users_collection[0].objects.link(pivot)
        pivot.parent = root
        p = info['pivot']
        pivot.location = (p[0], -p[2], p[1])
        pivot.empty_display_size = .35
        pivot['RigType'] = info['type']
        bpy.context.view_layer.update()
        for ob in m['objects']:
            if ob.get('RigGroup') == name:
                world = ob.matrix_world.copy()
                ob.parent = pivot
                ob.matrix_parent_inverse = Matrix.Identity(4)
                ob.matrix_world = world
        if info['type'] == 'door':
            for frame, fraction in [(1,0),(40,1),(70,1),(95,0),(160,0)]:
                pivot.rotation_euler.z = math.radians(info['openAngle']) * fraction
                pivot.keyframe_insert(data_path='rotation_euler', frame=frame)
        else:
            for frame, distance in [(1,0),(95,0),(160,24)]:
                pivot.rotation_euler.x = -distance / info['radius']
                pivot.keyframe_insert(data_path='rotation_euler', frame=frame)
    for frame, distance in [(1,0),(95,0),(160,24)]:
        root.location = offset + Vector((0,distance,0))
        root.keyframe_insert(data_path='location', frame=frame)
scene.frame_end = 160
scene.frame_set(1)
bpy.context.view_layer.update()
export_col = bpy.data.collections.new('Truck Export Temporary')
scene.collection.children.link(export_col)
report = []
for m in models:
    bpy.ops.object.select_all(action='DESELECT')
    copies, originals = [], []
    transform = Matrix.Rotation(math.pi,4,'Z') @ Matrix.Translation(-Vector(m['offset']))
    try:
        for ob in m['objects']:
            name = ob.name
            originals.append((ob,name))
            ob.name = name + '_authoring'
            mesh = ob.data.copy()
            mesh.transform(transform @ ob.matrix_world)
            copy = bpy.data.objects.new(name,mesh)
            export_col.objects.link(copy)
            copy.select_set(True)
            copies.append(copy)
        bpy.context.view_layer.objects.active = copies[0]
        bpy.ops.export_scene.fbx(filepath=os.path.join(OUT,'Truck_'+m['name']+'.fbx'),use_selection=True,object_types={'MESH'},apply_unit_scale=True,apply_scale_options='FBX_SCALE_UNITS',axis_forward='-Z',axis_up='Y',global_scale=1,mesh_smooth_type='FACE',bake_anim=False,add_leaf_bones=False,use_custom_props=False)
        report.append({'model':m['name'],'mesh_parts':len(copies),'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in copies),'moving_groups':len(m['groups'])})
    finally:
        for copy in copies:
            mesh = copy.data
            bpy.data.objects.remove(copy,do_unlink=True)
            bpy.data.meshes.remove(mesh)
        for ob,name in originals:ob.name=name
bpy.data.collections.remove(export_col)
scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
with open(os.path.join(OUT,'export_report.json'),'w') as f:json.dump(report,f,indent=2)
print(json.dumps(report))
