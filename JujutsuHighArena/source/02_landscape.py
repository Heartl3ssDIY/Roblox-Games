exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\JujutsuHighArena\source\common.py',encoding='utf-8').read(),'common.py','exec'))
sc=bpy.context.scene;random.seed(933)
TREES=[]
def tree(name,x,y,h):
 z=-.4;canopy=h*.67
 tube(name+'_Trunk',[(x,y,z),(x+.6,y+.3,h*.27),(x-.5,y+.6,h*.56),(x+.4,y,h*.74)],[.9,.72,.46,.19],3,'40_Tree_Trunks',n=9)
 for j,(dx,dy,dz) in enumerate([(-5,0,.65),(4,3,.69),(1,-5,.66),(-3,4,.82),(4,-1,.86),(0,0,.96),(-4,-4,.79)]):
  scale=h/29;xx=x+dx*scale;yy=y+dy*scale;zz=h*dz
  tube(name+'_Branch',[(x,y,h*.36),(x+dx*.58*scale,y+dy*.58*scale,h*dz*.8),(xx,yy,zz)],[.4,.25,.07],4,'40_Tree_Trunks',n=7)
  ob=ico(name+'_Canopy',(xx,yy,zz),(6.4*scale,5.8*scale,4.5*scale),[9,8,9,10,9,10,8][j],'41_Tree_Canopies',sub=2)
  for p in ob.data.polygons:p.use_smooth=True
 TREES.append((x,y,.9,h*.6))
positions=[]
for side in [-1,1]:
 for y in [-92,-59,-17,28,72,113,153]:
  positions.append((side*random.uniform(100,126),y+random.uniform(-5,5),random.uniform(26,37)))
for y in [145,171]:
 for x in [-94,-65,-35,0,35,70,105]:
  positions.append((x+random.uniform(-7,7),y+random.uniform(-5,5),random.uniform(28,43)))
positions += [(-42,111,27),(76,110,30),(-89,-30,26),(88,-22,28),(-92,51,25),(94,53,29)]
for i,(x,y,h) in enumerate(positions):tree('JH_Maple_%02d'%i,x,y,h)
# Low garden planting, kept outside the walking courtyard.
for x in [-90,90]:
 for y in [-56,-33,-8,16,42,65]:
  for j in range(3):
   ob=ico('JH_Garden_Shrub',(x+random.uniform(-5,5),y+random.uniform(-4,4),1.5),(3.8,3.3,2.3),random.choice([8,9,10]),'42_Garden_Planting',2)
   for p in ob.data.polygons:p.use_smooth=True
for side in [-1,1]:
 for y in [-63,63]:
  box('JH_Garden_Bed',(side*101,y,-.15),(23,18,.5),9,'42_Garden_Planting')
# A few uncut stones echo the wooded campus grounds.
for x,y in [(-91,-77),(92,-78),(-100,104),(108,87),(-46,110),(74,103)]:
 ico('JH_Garden_Boulder',(x,y,1.2),(3.6,2.5,2.1),2,'43_Garden_Stones',1)
open(ROOT+'/source/tree_bounds.json','w').write(json.dumps(TREES))
# Collision proxies remain separate from the visual scenery.
box('COL_Main_Ground',(0,28,-2.7),(256,290,4.6),2,'85_Collision')
box('COL_Courtyard',(0,0,-.47),(96,132,1.04),2,'85_Collision')
box('COL_Rear_Terrace',(0,92,.55),(216,58,1.9),2,'85_Collision')
bounds=json.load(open(ROOT+'/source/building_bounds.json'))
for b in bounds:
 ob=box('COL_'+b['name'],(0,0,b['z']+b['h']/2),(b['w'],b['d'],b['h']),2,'85_Collision')
 ob.matrix_world=Matrix.Translation((b['x'],b['y'],0))@Matrix.Rotation(b['angle'],4,'Z')
for side in [-1,1]:
 box('COL_Front_Wall',(side*67,-77,3),(102,2.4,6),2,'85_Collision')
 box('COL_Side_Wall',(side*119,22,3),(2.4,199,6),2,'85_Collision')
for x in [-12,12]:box('COL_Entry_Post',(x,-77,7),(1.5,1.5,14),2,'85_Collision')
for x in [-43,43]:
 for y in [-48,48]:box('COL_Lantern',(x,y,3.2),(3.2,3.2,6.4),2,'85_Collision')
for x,y,r,h in TREES:lathe('COL_Tree',[(r,0),(r,h)],(x,y,-.4),3,'85_Collision',n=8)
for o in collection('85_Collision').objects:
 o.hide_render=True;o.display_type='WIRE';o['Roblox_Anchored']=True;o['Roblox_CanCollide']=True
collection('85_Collision').hide_viewport=True
for name,loc in [('JH_Combat_Centre',(0,0,.05)),('JH_Spawn_A',(-18,0,.05)),('JH_Spawn_B',(18,0,.05)),('JH_Combat_Min',(-32,-32,.05)),('JH_Combat_Max',(32,32,.05))]:
 o=bpy.data.objects.new(name,None);collection('80_Gameplay_Markers').objects.link(o);o.location=loc;o.empty_display_size=2;o['purpose']='Layout reference only'
# Render lighting.
sc.world=bpy.data.worlds.new('Jujutsu High | clear afternoon');sc.world.use_nodes=True
bg=next(n for n in sc.world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.57,.7,.83,1);bg.inputs['Strength'].default_value=.45
def light(name,typ,loc,energy,color,size=0):
 d=bpy.data.lights.new(name,typ);o=bpy.data.objects.new(name,d);collection('90_Presentation').objects.link(o);o.location=loc;d.energy=energy;d.color=color;o.rotation_euler=(Vector((0,35,0))-o.location).to_track_quat('-Z','Y').to_euler()
 if typ=='AREA':d.shape='DISK';d.size=size
 return o
sun=light('JH_Afternoon_Sun','SUN',(-130,-180,200),2.4,(1,.95,.81));sun.data.angle=.12
light('JH_Sky_Fill','AREA',(70,-20,170),550000,(.76,.87,1),130)
light('JH_Warm_Rim','AREA',(-40,180,170),480000,(1,1,.84),110)
hero=camera('JH_Camera_Hero',(212,-254,208),(0,30,12),ortho=330)
camera('JH_Camera_Courtyard',(0,-55,10),(0,85,17),lens=25)
camera('JH_Camera_Top',(0,30,380),(0,30,0),ortho=330)
sc.camera=hero
try:sc.render.engine='BLENDER_EEVEE'
except TypeError:pass
try:sc.view_settings.view_transform='AgX';sc.view_settings.look='None'
except:pass
sc.render.image_settings.file_format='PNG';sc.render.resolution_x=1200;sc.render.resolution_y=1100;sc.render.resolution_percentage=100;sc.render.film_transparent=False
sc.render.filepath=ROOT+'/previews/Jujutsu_High_Draft.png'
bpy.context.view_layer.update();bpy.ops.object.select_all(action='DESELECT')
bpy.data.libraries.write(ROOT+'/Jujutsu_High_Editable.blend',{sc},fake_user=True,compress=True)
bpy.ops.render.render(write_still=True)
print('Trees:',len(TREES),'Scene objects:',len(sc.objects))
