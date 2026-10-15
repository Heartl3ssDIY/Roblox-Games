import bpy,os,sys
ROOT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\TenkaichiArena'
scene=bpy.context.scene
scene.render.engine='BLENDER_EEVEE'
scene.render.image_settings.file_format='PNG'
scene.render.resolution_percentage=100
for camera,file,w,h in [('Camera_Hero','Arena_Hero.png',1800,1350),('Camera_Front','Arena_Front.png',1800,1200),('Camera_Temple','Temple_Detail.png',1600,1200)]:
 if '--hero' in sys.argv and camera!='Camera_Hero':continue
 scene.camera=bpy.data.objects[camera];scene.render.resolution_x=w;scene.render.resolution_y=h
 scene.render.filepath=os.path.join(ROOT,'previews',file)
 bpy.ops.render.render(write_still=True)
 print('RENDER_DONE',file,flush=True)
