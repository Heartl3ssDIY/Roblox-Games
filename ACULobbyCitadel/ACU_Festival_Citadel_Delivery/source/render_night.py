import bpy, os
ROOT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\ACULobbyCitadel'
s=bpy.data.scenes['ACU | Festival Citadel'];bpy.context.window.scene=s
s.camera=bpy.data.objects['CAM_13_CivicCourt']
bg=next(n for n in s.world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Strength'].default_value=.012
for ob in s.objects:
    if ob.type=='LIGHT':
        if ob.data.type=='SUN':ob.data.energy=.18
        elif ob.name=='Warm hero softbox':ob.data.energy=9500
        elif ob.name=='Blue sky rim':ob.data.energy=25000
s.view_settings.exposure=.7
s.render.resolution_x=2400;s.render.resolution_y=1500;s.render.resolution_percentage=100
s.eevee.taa_render_samples=160
s.render.filepath=os.path.join(ROOT,'previews','08_Festival_Night.png')
bpy.ops.render.render(write_still=True)
print('NIGHT_PREVIEW_COMPLETE',flush=True)

