import bpy
import io_scene_gltf2
import json
import math
import tempfile
from pathlib import Path
from mathutils import Vector

OUTPUT = Path(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\StuckInTheMud20261003\GunRefinement20261004')
SCENE = bpy.data.scenes['StuckInTheMud_Guns20261003']
assert SCENE.get('ManagedGunAssets') and SCENE.get('AssetVersion') == 2
assert bpy.context.mode == 'OBJECT'
file_before = bpy.data.filepath
selection_before = list(bpy.context.selected_objects)
layer = SCENE.view_layers[0]
active_before = layer.objects.active
camera = SCENE.camera
camera_pose = (camera.location.copy(),camera.rotation_euler.copy(),camera.data.ortho_scale)
collections = [bpy.data.collections['SITM_MudGun'],bpy.data.collections['SITM_HeatGun']]
hidden = {c:c.hide_render for c in collections}
old_tmp = bpy.context.preferences.filepaths.temporary_directory
old_tempfile = tempfile.tempdir
bpy.context.preferences.filepaths.temporary_directory = str(OUTPUT / 'Temp')
tempfile.tempdir = str(OUTPUT / 'Temp')
exports = {}

try:
    floor = SCENE.objects['SITM_PreviewFloor']
    floor.scale.x = floor.scale.y = 8
    floor.location.z = -.925
    SCENE.render.resolution_x = 1600
    SCENE.render.resolution_y = 1000
    SCENE.render.resolution_percentage = 100
    SCENE.render.filepath = str(OUTPUT / 'MudHeatGun_Preview.png')
    bpy.ops.render.render(write_still=True,scene=SCENE.name)
    for gun_name in ('MudGun','HeatGun'):
        for c in collections:
            c.hide_render = c.name != 'SITM_' + gun_name
        root = SCENE.objects[gun_name]
        target = root.location + Vector((0,-.40,.95))
        camera.location = root.location + Vector((6,-8,5.5))
        camera.rotation_euler = (target-camera.location).to_track_quat('-Z','Y').to_euler()
        camera.data.ortho_scale = 4.7
        SCENE.render.resolution_x = 1100
        SCENE.render.resolution_y = 1300
        SCENE.render.filepath = str(OUTPUT / (gun_name + '_Preview.png'))
        bpy.ops.render.render(write_still=True,scene=SCENE.name)
    for c,hide in hidden.items():
        c.hide_render = hide
    camera.location,camera.rotation_euler,camera.data.ortho_scale = camera_pose
    SCENE.render.resolution_x = 1600
    SCENE.render.resolution_y = 1000
    SCENE.render.filepath = str(OUTPUT / 'MudHeatGun_Preview.png')

    for gun_name in ('MudGun','HeatGun'):
        root = SCENE.objects[gun_name]
        objects = [root] + list(root.children_recursive)
        assert all(o.type in {'MESH','EMPTY'} for o in objects)
        pose = (root.location.copy(),root.rotation_euler.copy())
        for o in layer.objects:
            o.select_set(False,view_layer=layer)
        for o in objects:
            o.select_set(True,view_layer=layer)
        layer.objects.active = root
        root.location = (0,0,0)
        root.rotation_euler = (0,0,math.pi)
        layer.update()
        try:
            formats = [item[0] for item in io_scene_gltf2.get_format_items(None,bpy.context)]
            binary = next(x for x in formats if x == 'GLB')
            with bpy.context.temp_override(scene=SCENE,view_layer=layer,selected_objects=objects,active_object=root,object=root):
                fbx = bpy.ops.export_scene.fbx(filepath=str(OUTPUT / (gun_name+'.fbx')),use_selection=True,
                    object_types={'EMPTY','MESH'},use_mesh_modifiers=True,axis_forward='-Z',axis_up='Y',
                    apply_unit_scale=False,mesh_smooth_type='FACE',bake_anim=False,add_leaf_bones=False,path_mode='RELATIVE')
                glb = bpy.ops.export_scene.gltf(filepath=str(OUTPUT / (gun_name+'.glb')),export_format=binary,
                    use_selection=True,use_active_scene=True,export_apply=True,export_materials='EXPORT',
                    export_animations=False,export_yup=True,export_lights=False,export_cameras=False)
                deps = bpy.context.evaluated_depsgraph_get()
                triangles, maximum = 0, 0
                for o in objects:
                    if o.type != 'MESH':
                        continue
                    evaluated = o.evaluated_get(deps)
                    data = evaluated.to_mesh()
                    data.calc_loop_triangles()
                    triangles += len(data.loop_triangles)
                    maximum = max(maximum,len(data.loop_triangles))
                    evaluated.to_mesh_clear()
            exports[gun_name] = {'meshes':sum(o.type=='MESH' for o in objects),'triangles':triangles,
                'largestMeshTriangles':maximum,'gripOrigin':[0,0,0],'muzzleRoblox':[0,1,-2.65],
                'forwardAxis':'-Z','fbxFinished':list(fbx),'glbFinished':list(glb)}
        finally:
            root.location,root.rotation_euler = pose
            layer.update()
    for o in layer.objects:
        o.select_set(o in selection_before,view_layer=layer)
    layer.objects.active = active_before
finally:
    for c,hide in hidden.items():
        c.hide_render = hide
    camera.location,camera.rotation_euler,camera.data.ortho_scale = camera_pose
    bpy.context.preferences.filepaths.temporary_directory = old_tmp
    tempfile.tempdir = old_tempfile

blend = OUTPUT / 'MudHeatGuns_Refined.blend'
bpy.data.libraries.write(str(blend),{SCENE},path_remap='ABSOLUTE',fake_user=True,compress=True)
canonical = Path(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\StuckInTheMud20261003\MudHeatGuns.blend')
assert Path(file_before).resolve() == canonical.resolve(), 'Refined library saved; unrelated open file is preserved'
save = bpy.ops.wm.save_as_mainfile(filepath=str(canonical),check_existing=False,compress=True,relative_remap=False,show_save_modified_images_dialog=False)
exports['blend'] = str(blend)
exports['canonicalBlend'] = str(canonical)
exports['saveFinished'] = list(save)
exports['version'] = SCENE['AssetVersion']
exports['scene'] = SCENE.name
exports['selectionPreserved'] = set(bpy.context.selected_objects)==set(selection_before)
exports['gameplayRun'] = False
(OUTPUT / 'ExportManifest.json').write_text(json.dumps(exports,indent=2),encoding='utf-8')
print(json.dumps(exports))
