import bpy
import json
from pathlib import Path
from mathutils import Vector

OUTPUT=Path(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\StuckInTheMud20261003')
scene=bpy.data.scenes['StuckInTheMud_Guns20261003']
assert scene.get('ManagedGunAssets')
camera=scene.camera
old_location=camera.location.copy()
old_rotation=camera.rotation_euler.copy()
old_scale=camera.data.ortho_scale
old_filepath=scene.render.filepath
old_resolution=(scene.render.resolution_x,scene.render.resolution_y)
original_scene=bpy.context.scene
original_window=bpy.context.window
old_tmp=bpy.context.preferences.filepaths.temporary_directory
collections=[bpy.data.collections['SITM_MudGun'],bpy.data.collections['SITM_HeatGun']]
hidden={collection:collection.hide_render for collection in collections}
paths=[]
try:
    bpy.context.preferences.filepaths.temporary_directory=str(OUTPUT/'Temp')
    scene.render.resolution_x=1200
    scene.render.resolution_y=1400
    for gun_name in ('MudGun','HeatGun'):
        for collection in collections:
            collection.hide_render=collection.name!='SITM_'+gun_name
        root=scene.objects[gun_name]
        target=root.location+Vector((0,-.45,1.06))
        camera.location=root.location+Vector((6,-8,5.5))
        camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
        camera.data.ortho_scale=5.3
        scene.render.filepath=str(OUTPUT/(gun_name+'_Preview.png'))
        bpy.ops.render.render(write_still=True,scene=scene.name)
        paths.append(scene.render.filepath)
finally:
    for collection,value in hidden.items(): collection.hide_render=value
    camera.location=old_location
    camera.rotation_euler=old_rotation
    camera.data.ortho_scale=old_scale
    scene.render.filepath=old_filepath
    scene.render.resolution_x,scene.render.resolution_y=old_resolution
    bpy.context.preferences.filepaths.temporary_directory=old_tmp
    if original_window and original_window.scene!=original_scene:
        original_window.scene=original_scene
print(json.dumps({'renders':paths,'userSceneStillActive':bpy.context.scene.name,'userFilepath':bpy.data.filepath}))
