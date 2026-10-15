import bpy, os, sys
ROOT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\ACULobbyCitadel'
s=bpy.data.scenes.get('ACU | Festival Citadel')
bpy.context.window.scene=s
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
names=args or ['CAM_02_Arrival','CAM_03_Champion','CAM_05_MoonGarden']
for name in names:
    s.camera=bpy.data.objects[name]
    s.render.resolution_x=1600;s.render.resolution_y=1000;s.render.resolution_percentage=80
    s.render.filepath=os.path.join(ROOT,'previews',name+'.png')
    bpy.ops.render.render(write_still=True)
print('REVIEW_RENDERS_COMPLETE',flush=True)

