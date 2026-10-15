import bpy, os
scene=bpy.data.scenes['To be rich - Warehouse']
bpy.context.window.scene=scene
folder=os.path.dirname(bpy.data.filepath)
bpy.data.collections['Roof'].hide_viewport=False
for cam,filename,cutaway in [('Exterior','warehouse_exterior.png',False),('Receiving Exterior','warehouse_receiving.png',False),('Interior Overview','warehouse_cutaway.png',True),('Warehouse Interior','warehouse_interior.png',False),('Office Detail','warehouse_office.png',True)]:
    bpy.data.collections['Roof'].hide_render=cutaway
    scene.camera=bpy.data.objects[cam]
    scene.render.filepath=os.path.join(folder,filename)
    bpy.ops.render.render(write_still=True)
