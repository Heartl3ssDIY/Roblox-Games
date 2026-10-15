exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\LoguetownArena\source\common.py',encoding='utf-8').read(),'common.py','exec'))
bpy.data.objects['Entrance_crossbeam'].location.y=-59.15
atlas_uv(bpy.data.objects['Square_stone_base'],8)
box('Rear_civic_foundation',(0,82,-2.7),(148,18,5.4),1,'01_Foundation',.3)
for ob in collection('36_Palms').objects:
 center=sum((ob.matrix_world@Vector(p) for p in ob.bound_box),Vector())/8
 if center.y<-70:ob.location.z-=4.1
# Separate opaque roof backfaces are retained for robust game import.
for group in ['36_Palms','34_Market_West','35_Market_East']:
 for ob in collection(group).objects:
  if 'frond' in ob.name or 'canopy' in ob.name:
   me=ob.data;bm=bmesh.new();bm.from_mesh(me)
   faces=list(bm.faces)
   dup=bmesh.ops.duplicate(bm,geom=faces)['geom']
   for f in [x for x in dup if isinstance(x,bmesh.types.BMFace)]:f.normal_flip()
   bm.to_mesh(me);bm.free()
sun=bpy.data.lights.new('LT_Afternoon_Sun','SUN');sun.energy=1.35;sun.color=(1,.90,.75);sun.angle=.12
o=bpy.data.objects.new('LT_Afternoon_Sun',sun);collection('90_Presentation').objects.link(o);o.rotation_euler=(Vector((0,0,0))-Vector((-65,-100,150))).to_track_quat('-Z','Y').to_euler()
sc=bpy.context.scene
bg=next(n for n in sc.world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Strength'].default_value=.4
hero=bpy.data.objects['LT_Camera_Hero'];hero.location=(77,-233,178);hero.rotation_euler=(Vector((0,-3,11))-hero.location).to_track_quat('-Z','Y').to_euler();hero.data.lens=43
# Collision is independent of decorative detail.
g='85_Collision'
box('COL_Main_Square',(0,1,-1.5),(148,138,3.24),8,g)
box('COL_Rear_Base',(0,79,-1.5),(148,18,3.24),8,g)
box('COL_Quay',(0,-79,-5),(148,20,2),8,g)
for i in range(12):
 height=(i+1)*.35
 box('COL_Entrance_Step_%02d'%i,(0,-82+i*1.08,-4.1+height/2),(28,1.1,height),8,g)
for x in [-63,63]:
 for j,y in enumerate([-45,-15,15,45]):box('COL_Building',(x,y,16),(18,26,32),8,g)
box('COL_Civic_Hall',(0,76,16),(88,20,32),8,g)
for x in [-43,43]:
 lathe('COL_Fountain',[(.001,0),(7.1,0),(7.1,2),(.001,2)],(x,-18,.12),8,g,16)
for x in [-19,19]:box('COL_Gate_Column',(x,-60,7.5),(2.8,2.8,15),8,g)
for x in [-47,47]:box('COL_Quay_Wall',(x,-68.7,-1.1),(54,2.7,6.45),8,g)
for x in [-26,26]:box('COL_Dock',(x,-89.5,-4.2),(12,18.5,.45),8,g)
for x in [-4.6,4.6]:
 for y in [43.4,52.6]:box('COL_Scaffold_Post',(x,y,10),(.8,.8,20),8,g)
box('COL_Execution_Deck',(0,48,19.9),(12,12,.8),8,g)
collection(g).hide_render=True;collection(g).hide_viewport=True
for name,cam,w,h in [('Loguetown_Hero.png','LT_Camera_Hero',1700,1400),('Loguetown_Entrance.png','LT_Camera_Entrance',1700,1100),('Loguetown_Top.png','LT_Camera_Top',1500,1700)]:
 sc.camera=bpy.data.objects[cam];sc.render.resolution_x=w;sc.render.resolution_y=h;sc.render.filepath=os.path.join(ROOT,'previews',name);bpy.ops.render.render(write_still=True)
sc.camera=hero;sc.render.resolution_x=1700;sc.render.resolution_y=1400;sc.render.filepath=os.path.join(ROOT,'previews','Loguetown_Hero.png')
bpy.data.libraries.write(os.path.join(ROOT,'Loguetown_Arena_Editable.blend'),{sc},fake_user=True,compress=True)
print('Finished entrance, landscaping, lighting and collision setup')
