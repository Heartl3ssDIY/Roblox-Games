exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\MarinefordFrozenBay\source\common.py',encoding='utf-8').read(),'common.py','exec'))
sc=bpy.context.scene
box('MF_Open_Sea',(0,25,-5),(1600,1600,1),15,'04_Outer_Sea')
# Distant frozen wave shoulders evoke the frozen tsunami without enclosing the combat area.
for side in [-1,1]:
 for j in range(7):
  crag('MF_Frozen_Wave', (side*(127+j*2.4),-3+j*13,-5),7+j*.35,13+8*sin(j*pi/7),random.choice([0,1,3]),'05_Frozen_Waves',n=7)
# All combat and spawn markers are non-rendering editable empties.
for name,loc in [('MF_Combat_Centre',(0,0,.03)),('MF_Spawn_A',(-18,0,.03)),('MF_Spawn_B',(18,0,.03)),('MF_Combat_Min',(-32,-32,.03)),('MF_Combat_Max',(32,32,.03))]:
 o=bpy.data.objects.new(name,None);collection('80_Gameplay_Markers').objects.link(o);o.location=loc;o.empty_display_size=2
 o['purpose']='Layout marker only; no match logic'
col=collection('85_Collision')
lathe('COL_Frozen_Bay',[(95.8,-3),(95.8,.012)],(0,0,0),0,'85_Collision',n=64)
angles=np.linspace(math.radians(-145),math.radians(145),43)
for i,(a,b) in enumerate(zip(angles,angles[1:])):
 pts=[(96*sin(a),96*cos(a)),(96*sin(b),96*cos(b)),(104*sin(b),104*cos(b)),(104*sin(a),104*cos(a))]
 slab('COL_Harbour_Wall_%02d'%i,pts,-3,18.3,4,'85_Collision')
slab('COL_Rear_Terrace',[(-113,90),(113,90),(124,136),(98,185),(58,202),(-58,202),(-98,185),(-124,136)],-5,18.6,4,'85_Collision')
box('COL_Fortress',(0,145,57),(86,47,80),5,'85_Collision')
for name,x,y,angle in [('West',-69,13,.22),('East',68,32,-.37)]:
 ob=box('COL_Frozen_Ship_'+name,(0,0,3),(9,19,6),8,'85_Collision')
 ob.matrix_world=Matrix.Translation((x,y,0))@Matrix.Rotation(angle,4,'Z')
for ob in col.objects:
 ob.hide_render=True;ob.display_type='WIRE';ob['Roblox_Anchored']=True;ob['Roblox_CanCollide']=True
col.hide_viewport=True
sc.world=bpy.data.worlds.new('Marineford | cold daylight');sc.world.use_nodes=True
bg=next(n for n in sc.world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.38,.53,.68,1);bg.inputs['Strength'].default_value=.5
def light(name,typ,loc,power,color,size=0):
 d=bpy.data.lights.new(name,typ);o=bpy.data.objects.new(name,d);collection('90_Presentation').objects.link(o);o.location=loc;d.energy=power;d.color=color
 o.rotation_euler=(Vector((0,55,0))-o.location).to_track_quat('-Z','Y').to_euler()
 if typ=='AREA':d.shape='DISK';d.size=size
 return o
sun=light('MF_Cold_Sun','SUN',(-100,-130,220),2.1,(.88,.95,1));sun.data.angle=.12
light('MF_Soft_Sky','AREA',(-60,-40,180),650000,(.8,.92,1),130)
light('MF_Fortress_Rim','AREA',(60,180,150),500000,(1,.94,.84),100)
hero=camera('MF_Camera_Hero',(210,-255,205),(0,48,32),ortho=340)
camera('MF_Camera_Bay',(0,-148,34),(0,110,44),lens=27)
camera('MF_Camera_Top',(0,42,380),(0,42,0),ortho=335)
sc.camera=hero
try:sc.render.engine='BLENDER_EEVEE'
except TypeError:pass
try:sc.view_settings.view_transform='AgX';sc.view_settings.look='None'
except:pass
sc.render.image_settings.file_format='PNG';sc.render.resolution_x=1200;sc.render.resolution_y=1100;sc.render.resolution_percentage=100
sc.render.film_transparent=False
sc.render.filepath=ROOT+'/previews/Marineford_Draft.png'
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':
   area.spaces.active.region_3d.view_distance=340
   area.spaces.active.region_3d.view_location=(0,45,25)
   area.spaces.active.region_3d.view_rotation=hero.rotation_euler.to_quaternion()
bpy.data.libraries.write(ROOT+'/Marineford_Frozen_Bay_Editable.blend',{sc},fake_user=True,compress=True)
bpy.ops.render.render(write_still=True)
print('Draft render and editable model saved')
