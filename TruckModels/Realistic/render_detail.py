import bpy,os
from mathutils import Vector
scene=bpy.data.scenes['To be rich - Trucks'];bpy.context.window.scene=scene;scene.frame_set(1)
cam=scene.camera;cam.location=(17,25,12);cam.rotation_euler=(Vector((0,1,4))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=25
scene.render.resolution_x=1700;scene.render.resolution_y=1400
scene.render.filepath=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\TruckModels\Realistic\Basic_Detail.png'
bpy.ops.render.render(write_still=True)
scene.frame_set(40);cam.location=(14,-24,11);cam.rotation_euler=(Vector((0,-2,4))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=25
scene.render.filepath=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\TruckModels\Realistic\Rear_Detail.png'
bpy.ops.render.render(write_still=True)
