exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\HeavensArena\source\common.py',encoding='utf-8').read(),'common.py','exec'))
sc=bpy.context.scene
world=bpy.data.worlds.new('Heavens Arena | studio atmosphere');world.use_nodes=True
bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.1,.14,.18,1);bg.inputs['Strength'].default_value=.4;sc.world=world
for name,loc,target,energy,size,color in [
 ('HA_Overhead_Key',(-30,-25,120),(0,0,0),1900000,95,(.89,.95,1)),
 ('HA_North_Fill',(0,85,70),(0,10,8),550000,75,(.82,.92,1)),
 ('HA_South_Fill',(0,-85,70),(0,-10,8),550000,75,(1,.94,.81)),
 ('HA_East_Fill',(85,0,75),(15,0,10),600000,75,(.87,.97,1)),
 ('HA_West_Fill',(-85,0,75),(-15,0,10),600000,75,(1,.97,.89))]:
 d=bpy.data.lights.new(name,'AREA');d.energy=energy;d.shape='DISK';d.size=size;d.color=color;o=bpy.data.objects.new(name,d);collection('90_Presentation').objects.link(o);o.location=loc;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
camera('HA_Camera_Hero',(200,-250,270),(0,0,14),ortho=352)
camera('HA_Camera_Ringside',(0,-65,15),(0,25,12),lens=23)
camera('HA_Camera_Top',(0,0,340),(0,0,0),ortho=298)
sc.camera=bpy.data.objects['HA_Camera_Hero'];sc.render.resolution_x=1700;sc.render.resolution_y=1400;sc.render.resolution_percentage=100;sc.render.image_settings.file_format='PNG'
try:sc.view_settings.view_transform='AgX'
except Exception:pass
print('Color',sc.view_settings.view_transform,sc.view_settings.look)
sc.render.filepath=os.path.join(ROOT,'previews','Heavens_Arena_Hero.png')
bpy.context.view_layer.update()
bpy.data.libraries.write(os.path.join(ROOT,'Heavens_Arena_Editable.blend'),{sc},fake_user=True,compress=True)
bpy.ops.render.render(write_still=True)
print('Rendered hero')
