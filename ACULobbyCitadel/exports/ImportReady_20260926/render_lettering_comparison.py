import bpy,json,math
from pathlib import Path
ROOT=Path(r"C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\ACULobbyCitadel\exports\ImportReady_20260926")
sources=[bpy.data.objects.get(n) for n in ("CHAMPIONS_title","SUMMON_legend","Arena_06_HeavensArena_name")]
assert all(sources)
scene=bpy.data.scenes.new("ACU_Export_Text_Comparison")
bpy.context.window.scene=scene
world=bpy.data.worlds.new("QA_World");world.color=(0.035,0.045,0.065);scene.world=world
mat=bpy.data.materials.new("QA_Ivory");mat.diffuse_color=(0.95,0.82,0.52,1)
def addtext(name,cu,x,y):
    ob=bpy.data.objects.new(name,cu);scene.collection.objects.link(ob);ob.location=(x,y,0)
    cu.align_x="CENTER";cu.align_y="CENTER";cu.size=1
    cu.materials.clear();cu.materials.append(mat)
    return ob
for i,src in enumerate(sources):
    a=addtext("Original_"+src.name,src.data.copy(),-6.25,3.4-i*3.3)
    b=addtext("Optimized_"+src.name,src.data.copy(),6.25,3.4-i*3.3)
    b.data.resolution_u=4;b.data.render_resolution_u=4;b.data.bevel_resolution=1
    bpy.context.view_layer.update()
    scale=min(10.6/max(a.dimensions.x,.001),2.2/max(a.dimensions.y,.001))
    a.scale=(scale,)*3;b.scale=(scale,)*3
for title,x in (("ORIGINAL", -6.25),("IMPORT VERSION",6.25)):
    cu=bpy.data.curves.new(title,"FONT");cu.body=title;cu.font=sources[0].data.font;cu.resolution_u=4
    ob=addtext(title,cu,x,6.6);cu.size=.55
camdata=bpy.data.cameras.new("QA_Camera");cam=bpy.data.objects.new("QA_Camera",camdata);scene.collection.objects.link(cam)
cam.location=(0,0.8,25);cam.rotation_euler=(0,0,0);camdata.type="ORTHO";camdata.ortho_scale=26
scene.camera=cam
scene.render.engine="BLENDER_WORKBENCH"
scene.display.shading.light="STUDIO";scene.display.shading.color_type="MATERIAL"
scene.display.shading.background_type="WORLD";scene.display.shading.show_shadows=False
scene.display.shading.show_cavity=True
scene.render.resolution_x=1600;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.render.image_settings.file_format="PNG";scene.render.filepath=str(ROOT/"Lettering_Comparison.png")
scene.view_settings.view_transform="Standard"
bpy.ops.render.render(write_still=True)
print("TEXT_COMPARISON_COMPLETE")

