import bpy,os,json
from mathutils import Vector
ROOT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\ChuninExamHall'
scene=bpy.context.scene
defaults=bpy.data.collections.get('Collection')
if defaults:defaults.name='99_Original_Defaults';defaults.hide_render=True;defaults.hide_viewport=True
hero=bpy.data.objects['Camera_Hall_Hero']
hero.location=(0,-115,88)
hero.rotation_euler=(Vector((0,0,10))-hero.location).to_track_quat('-Z','Y').to_euler()
hero.data.lens=34
scene.camera=hero;scene.render.resolution_x=1600;scene.render.resolution_y=1300
scene.render.filepath=os.path.join(ROOT,'previews','Chunin_Hall_Hero.png')
bpy.ops.render.render(write_still=True)
scene.camera=bpy.data.objects['Camera_Hand_Detail'];scene.render.resolution_x=1500;scene.render.resolution_y=1000
scene.render.filepath=os.path.join(ROOT,'previews','Hand_Seal_Detail.png')
bpy.ops.render.render(write_still=True)
scene.camera=bpy.data.objects['Camera_Gameplay']
scene.camera.location=(0,-20,125)
scene.camera.rotation_euler=(0,0,0)
scene.camera.data.type='ORTHO';scene.camera.data.ortho_scale=125
scene.render.resolution_x=1300;scene.render.resolution_y=1500
scene.render.filepath=os.path.join(ROOT,'previews','Chunin_Hall_Top.png')
bpy.ops.render.render(write_still=True)
scene.camera=hero;scene.render.resolution_x=1600;scene.render.resolution_y=1300
scene.render.filepath=os.path.join(ROOT,'previews','Chunin_Hall_Hero.png')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'Chunin_Exam_Hall.blend'))
print("Hero, sculpture detail and top view saved.")
