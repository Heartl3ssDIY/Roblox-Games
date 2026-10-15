import os
OUT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\WarehouseRedesign'
scene.render.engine='BLENDER_EEVEE'
scene.render.resolution_x=1600
scene.render.resolution_y=1100
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.film_transparent=False
world=bpy.data.worlds.new('Warehouse Studio World')
world.use_nodes=True
background=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND')
background.inputs['Color'].default_value=(.32,.40,.49,1)
background.inputs['Strength'].default_value=.7
scene.world=world
box('PresentationGround',(15,0,-1.9),(2000,2000,.5),'Concrete','Presentation',bevel=0)

def camera(name,pos,target,scale):
    data=bpy.data.cameras.new(name); data.type='ORTHO'; data.ortho_scale=scale; data.clip_end=3000
    ob=bpy.data.objects.new(name,data); cols['Presentation'].objects.link(ob)
    ob.location=pos; ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler()
    return ob

hero=camera('Exterior',(165,-175,128),(17,-4,4),194)
receiving=camera('Receiving Exterior',(-155,180,120),(12,5,5),190)
cutaway=camera('Interior Overview',(142,-165,185),(19,0,0),192)
interior=camera('Warehouse Interior',(-43,31,11.5),(22,-30,7.0),100)
interior.data.type='PERSP'; interior.data.lens=21
for name,pos,power,size in [('Key',(-80,-90,180),2200000,100),('Fill',(130,-10,95),1000000,80),('Rim',(0,125,160),1800000,85)]:
    data=bpy.data.lights.new(name,'AREA'); data.energy=power; data.shape='DISK' if 'DISK' in [i.identifier for i in data.bl_rna.properties['shape'].enum_items] else data.shape; data.size=size
    ob=bpy.data.objects.new(name,data); cols['Presentation'].objects.link(ob)
    ob.location=pos; ob.rotation_euler=(Vector((10,0,0))-ob.location).to_track_quat('-Z','Y').to_euler()
for x in (-32,0,32):
    for y in (-27,10,32):
        data=bpy.data.lights.new('Interior Area','AREA'); data.energy=1100; data.size=9
        ob=bpy.data.objects.new('Interior Area',data); cols['Presentation'].objects.link(ob)
        ob.location=(x,y,14.3)
scene.camera=hero
scene.render.filepath=os.path.join(OUT,'warehouse_exterior.png')
bpy.context.view_layer.update()
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            space=area.spaces.active
            space.clip_end=3000
            space.region_3d.view_perspective='CAMERA'
            space.region_3d.view_camera_zoom=0
            space.shading.type='MATERIAL'
            space.overlay.show_overlays=False
            area.tag_redraw()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'To_be_rich_Warehouse.blend'))
print('Presentation ready')
