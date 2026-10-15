import bpy, os
from mathutils import Vector
scene=bpy.context.scene
cam=scene.camera;cam.location=(3,-14,6.6)
cam.rotation_euler=(Vector((0,-.20,5.95))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.ortho_scale=4.65
bpy.data.objects['Preview ground'].hide_render=True
scene.render.resolution_x=1200;scene.render.resolution_y=1200
for name,energy,color in [('Key softbox',1050,(.78,.87,1)),('Fill softbox',260,(.60,.72,.85)),('Fur rim',1250,(1,.16,.065)),('Face lift',90,(1,.85,.65))]:
    o=bpy.data.objects.get(name)
    if o:o.data.energy=energy;o.data.color=color
scene.world.node_tree.nodes.get('Background').inputs[1].default_value=.12
scene.view_settings.exposure=-.65
scene.render.filepath=os.path.join(os.path.dirname(bpy.data.filepath),'CatInTheHat_Horror_Portrait.png')
bpy.ops.render.render(write_still=True)
