import bpy
import io_scene_gltf2
import json
import math
import os
import tempfile
import struct
from pathlib import Path
from mathutils import Vector

OUTPUT=Path(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\StuckInTheMud20261003')
scene=bpy.data.scenes['StuckInTheMud_Guns20261003']
assert scene.get('ManagedGunAssets'), 'Only the new managed asset scene may be exported'
original_scene=bpy.context.scene
original_window=bpy.context.window
original_filepath=bpy.data.filepath
original_selection=[object.name for object in bpy.context.selected_objects]
original_active=bpy.context.view_layer.objects.active
original_matrices={object.name:object.matrix_world.copy() for object in original_scene.objects}
layer=scene.view_layers[0]
old_tmp=bpy.context.preferences.filepaths.temporary_directory
old_tempfile=tempfile.tempdir
temp_path=str(OUTPUT/'Temp')
bpy.context.preferences.filepaths.temporary_directory=temp_path
tempfile.tempdir=temp_path
exports={}
try:
    for gun_name in ('MudGun','HeatGun'):
        root=scene.objects[gun_name]
        objects=[root]+list(root.children_recursive)
        assert all(object.name.startswith('SITM_') or object==root for object in objects)
        old_location=root.location.copy()
        old_rotation=root.rotation_euler.copy()
        for object in layer.objects:
            object.select_set(False,view_layer=layer)
        for object in objects:
            object.select_set(True,view_layer=layer)
        layer.objects.active=root
        root.location=(0,0,0)
        root.rotation_euler=(0,0,math.pi)
        layer.update()
        try:
            fbx=OUTPUT/(gun_name+'.fbx')
            glb=OUTPUT/(gun_name+'.glb')
            if fbx.exists():
                content=fbx.read_bytes()
                assert content.startswith(b'Kaydara FBX Binary') and gun_name.encode() in content, 'Unexpected existing FBX is preserved'
            if glb.exists():
                content=glb.read_bytes()
                assert content[:4]==b'glTF', 'Unexpected existing GLB is preserved'
                length,kind=struct.unpack_from('<II',content,12)
                prior=json.loads(content[20:20+length])
                assert any(node.get('name')==gun_name for node in prior.get('nodes',[])), 'Unexpected existing GLB is preserved'
            formats=[item[0] for item in io_scene_gltf2.get_format_items(None,bpy.context)]
            binary_format=next(identifier for identifier in formats if identifier=='GLB')
            with bpy.context.temp_override(scene=scene,view_layer=layer,selected_objects=objects,active_object=root,object=root):
                result_fbx=bpy.ops.export_scene.fbx(filepath=str(fbx),use_selection=True,object_types={'EMPTY','MESH'},
                    use_mesh_modifiers=True,axis_forward='-Z',axis_up='Y',apply_unit_scale=False,
                    mesh_smooth_type='FACE',bake_anim=False,add_leaf_bones=False,path_mode='RELATIVE')
                result_glb=bpy.ops.export_scene.gltf(filepath=str(glb),export_format=binary_format,use_selection=True,
                    use_active_scene=True,export_apply=True,export_materials='EXPORT',export_animations=False,export_yup=True)
                depsgraph=bpy.context.evaluated_depsgraph_get()
                triangles=0
                max_part_triangles=0
                for object in objects:
                    if object.type!='MESH': continue
                    evaluated=object.evaluated_get(depsgraph)
                    data=evaluated.to_mesh()
                    data.calc_loop_triangles()
                    triangles+=len(data.loop_triangles)
                    max_part_triangles=max(max_part_triangles,len(data.loop_triangles))
                    evaluated.to_mesh_clear()
            exports[gun_name]={'fbx':str(fbx),'glb':str(glb),'fbxBytes':fbx.stat().st_size,'glbBytes':glb.stat().st_size,
                'meshes':sum(object.type=='MESH' for object in objects),'triangles':triangles,'largestMeshTriangles':max_part_triangles,
                'gripOrigin':[0,0,0],'muzzleBlender':[0,-2.65,1],'muzzleRoblox':[0,1,-2.65],
                'exportForwardAxis':'-Z','authoringToExportRotationDegrees':180,
                'fbxFinished':list(result_fbx),'glbFinished':list(result_glb)}
        finally:
            root.location=old_location
            root.rotation_euler=old_rotation
            for object in objects:
                object.select_set(False,view_layer=layer)
            layer.objects.active=None
            layer.update()
    blend=OUTPUT/'MudHeatGuns.blend'
    if not blend.exists():
        bpy.data.libraries.write(str(blend),{scene},path_remap='ABSOLUTE',fake_user=True,compress=True)
    else:
        with bpy.data.libraries.load(str(blend),link=False) as (source,target):
            assert source.scenes==[scene.name] and 'Cube' not in source.objects, 'Unexpected existing blend is preserved'
    exports['blend']={'filepath':str(blend),'bytes':blend.stat().st_size,'containsOnlyManagedScene':True}
finally:
    bpy.context.preferences.filepaths.temporary_directory=old_tmp
    tempfile.tempdir=old_tempfile
    if original_window and original_window.scene!=original_scene:
        original_window.scene=original_scene
assert bpy.context.scene==original_scene and bpy.data.filepath==original_filepath, 'User file or active scene changed'
assert [object.name for object in bpy.context.selected_objects]==original_selection, 'User selection changed'
assert bpy.context.view_layer.objects.active==original_active, 'User active object changed'
assert set(original_matrices)==set(object.name for object in original_scene.objects), 'User scene membership changed'
assert all(object.matrix_world==original_matrices[object.name] for object in original_scene.objects), 'User object transform changed'
exports['preserved']={'scene':original_scene.name,'filepath':original_filepath,'objects':list(original_matrices),'selection':original_selection,'activeObject':original_active.name if original_active else None}
(OUTPUT/'gun-export-manifest.json').write_text(json.dumps(exports,indent=2),encoding='utf-8')
print(json.dumps(exports))
