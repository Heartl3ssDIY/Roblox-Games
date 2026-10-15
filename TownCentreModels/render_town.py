import bpy,os
from mathutils import Vector
OUT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\TownCentreModels'
scene=bpy.data.scenes['To be rich - Town Centre'];bpy.context.window.scene=scene
cam=scene.camera
def shot(name,pos,target,scale,w=1800,h=1300):
    cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=scale
    scene.render.resolution_x=w;scene.render.resolution_y=h;scene.render.filepath=os.path.join(OUT,name+'.png');bpy.ops.render.render(write_still=True)
shot('TownCentre_Comparison',(88,-135,75),(0,-5,5),133,2200,1300)
shot('TownCentre_Crash',(76,-57,32),(43,-10,5),65)
hidden=[]
for ob in scene.objects:
    if ob.name.startswith(('TownCentre_Crashed','GiftTruck_Crashed')) or (ob.name.startswith('TownCentre_Normal') and ob.get('RigGroup')=='Roof'):
        if not ob.hide_render:hidden.append(ob);ob.hide_render=True
shot('TownCentre_Interior',(-10,-31,35),(-36,0,3),43)
for ob in hidden:ob.hide_render=False
gift=bpy.data.objects['GiftTruck_Crashed'];gift.location=(0,0,0);gift.rotation_euler=(0,0,0)
for ob in scene.objects:
    if ob.name.startswith(('TownCentre_Crashed','TownCentre_Normal')):ob.hide_render=True
shot('GiftTruck_Detail',(17,24,12),(0,0,4),27)
