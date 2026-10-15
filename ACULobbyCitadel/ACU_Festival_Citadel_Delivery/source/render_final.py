import bpy, os
ROOT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\ACULobbyCitadel'
s=bpy.data.scenes['ACU | Festival Citadel'];bpy.context.window.scene=s
s.render.resolution_x=2400;s.render.resolution_y=1500;s.render.resolution_percentage=100
s.eevee.taa_render_samples=160
views=[('CAM_13_CivicCourt','01_Civic_Court'),('CAM_08_ExpandedCity','02_Complete_City'),('CAM_09_MarketStreet','03_Merchant_Street'),('CAM_10_Waterfall','04_Waterfall_Garden'),('CAM_11_Pagoda','05_Celestial_Pagoda'),('CAM_12_GrandEntrance','06_Grand_Entrance'),('CAM_05_MoonGarden','07_Moon_Garden')]
for camera,label in views:
    s.camera=bpy.data.objects[camera]
    s.render.filepath=os.path.join(ROOT,'previews',label+'.png')
    bpy.ops.render.render(write_still=True)
    print('FINISHED '+label,flush=True)
print('FINAL_RENDERS_COMPLETE',flush=True)

