exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\TenkaichiArena\source\common.py',encoding='utf-8').read(),'common.py','exec'))
old=bpy.context.scene
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'Before_Arena.blend'))
scene=bpy.data.scenes.new('Tenkaichi | Tropical Tournament'); bpy.context.window.scene=scene
scene.unit_settings.system='NONE'
MAT=make_atlas()
scene.world=bpy.data.worlds.new('Tropical daylight'); scene.world.use_nodes=True
bg=next(n for n in scene.world.node_tree.nodes if n.type=='BACKGROUND'); bg.inputs['Color'].default_value=(.43,.66,.84,1); bg.inputs['Strength'].default_value=.65
scene.render.engine='BLENDER_EEVEE'
scene.render.resolution_x=1600; scene.render.resolution_y=1200; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
sun=bpy.data.lights.new('Afternoon sun','SUN'); sun.energy=2.7; sun.angle=.12
o=bpy.data.objects.new('Afternoon sun',sun); collection('90_Presentation').objects.link(o); o.rotation_euler=(.5,-.45,-.6)
scene.camera=camera('Camera_Hero',(145,-193,150),(0,10,6),48)
camera('Camera_Front',(0,-119,62),(0,28,12),40)
camera('Camera_Overview',(5,-95,172),(0,10,0),44)
camera('Camera_Temple',(69,-30,49),(0,42,17),51)
# Ground plinth and an inset paved promenade.
box('Ground_landmass',(0,10,-1.4),(158,154,2.8),5,'01_Ground',.6)
box('Tropical_lawn',(0,10,.05),(157.6,153.6,.2),9,'01_Ground',.12)
for x in [-37.7,37.7]:box('Side_promenade',(x,-4,.20),(8.4,68,.22),10,'01_Ground',.12)
box('Front_promenade',(0,-42,.20),(82,8,.22),10,'01_Ground',.12)
box('Rear_garden_path',(0,73,.20),(85,5,.22),10,'01_Ground',.10)
# Arena has a continuous base under individually bevelled stone pavers.
box('Ring_blue_foundation',(0,-4,1.05),(64.5,64.5,2.1),4,'02_Ring',.12)
box('Ring_red_edge',(0,-4,2.14),(64.55,64.55,.20),1,'02_Ring',.06)
box('Ring_grout_bed',(0,-4,2.30),(64,64,.16),5,'02_Ring',.03)
for j in range(16):
 for i in range(16):box('Ring_paver_%02d_%02d'%(i,j),(-30+4*i,-34+4*j,2.43),(3.94,3.94,.22),3,'02_Ring',.045)
for side in [-1,1]:
 for k in range(4):
  box('Side_access_step',(side*(32.5+(.65*(4-k))),-27,.3+.5*k),(1.3,6,.60+.5*k),5,'02_RingSteps',.07)
# Building foundation, divided facade leaves a real doorway.
box('Temple_terrace',(0,51,1.05),(82,27,2.1),5,'03_TempleShell',.15)
box('Temple_floor',(0,51,2.18),(78,24,.26),3,'03_TempleShell',.07)
for side in [-1,1]:
 box('Temple_front_wing',(side*22,40.5,9.8),(34,1.5,15),0,'03_TempleShell',.1)
 box('Temple_side_wall',(side*38.25,51.5,9.8),(1.5,23,15),0,'03_TempleShell',.1)
 for x in [side*6,side*17,side*28,side*38]:box('Red_timber_post',(x,39.62,9.7),(.48,.35,14.6),1,'03_TempleShell',.035)
box('Temple_back_wall',(0,62.3,9.8),(78,1.5,15),0,'03_TempleShell',.1)
box('Temple_front_lintel',(0,40.5,15.55),(10,1.5,3.5),0,'03_TempleShell',.06)
box('Dark_entry_recess',(0,47,8),(10,.3,11.7),14,'03_TempleShell')
for z in [3.0,13.0,16.7]:box('Temple_facade_red_band',(0,39.65,z),(78,.38,.42),1,'03_TempleShell',.045)
for side in [-1,1]:
 for i in range(3):
  x=side*(12+10.3*i)
  box('Window_sandstone_frame',(x,39.28,14.85),(8.3,.45,1.9),5,'03_TempleDetails',.07)
  box('Window_red_reveal',(x,38.99,14.85),(7.8,.15,1.45),1,'03_TempleDetails',.035)
  box('Window_blue_glass',(x,38.89,14.85),(7.22,.12,.98),11,'03_TempleDetails',.03)
  for u in [-2.4,0,2.4]:box('Window_mullion',(x+u,38.78,14.85),(.10,.15,1.0),6,'03_TempleDetails')
# Arch trim surrounding the open passage.
pts=[(-5,39.2,2.4),(-5,39.2,9.5)]+[(5*cos(pi-i*pi/16),39.2,9.5+5*sin(pi-i*pi/16)) for i in range(17)]+[(5,39.2,2.4)]
tube('Entry_arch_red',pts,.30,1,'03_TempleDetails',10)
for k in range(4):box('Temple_entry_step',(0,36.3+k*.9,.35+k*.52),(10,1.8,.6+k*.52),5,'03_TempleDetails',.06)
box('Temple_entry_path',(0,33.5,2.42),(10,9,.18),3,'03_TempleDetails',.03)
# Roof constructed from overlapping courses, with a curved silhouette.
def hip_roof(prefix,cx,cy,w,d,z,h,group):
 profiles=[(1,0),(.91,.12),(.72,.57),(.57,1)]
 for j in range(3):
  s0,t0=profiles[j];s1,t1=profiles[j+1]
  low=[(cx-w/2*s0,cy-d/2*s0,z+h*t0),(cx+w/2*s0,cy-d/2*s0,z+h*t0),(cx+w/2*s0,cy+d/2*s0,z+h*t0),(cx-w/2*s0,cy+d/2*s0,z+h*t0)]
  # Ridge is long and narrow, characteristic of the reference.
  sy1=(1-t1)*d/2
  high=[(cx-w/2*s1,cy-sy1,z+h*t1+.12),(cx+w/2*s1,cy-sy1,z+h*t1+.12),(cx+w/2*s1,cy+sy1,z+h*t1+.12),(cx-w/2*s1,cy+sy1,z+h*t1+.12)]
  if j>0:
   sy0=(1-t0)*d/2
   low=[(cx-w/2*s0,cy-sy0,z+h*t0-.15),(cx+w/2*s0,cy-sy0,z+h*t0-.15),(cx+w/2*s0,cy+sy0,z+h*t0-.15),(cx-w/2*s0,cy+sy0,z+h*t0-.15)]
  for side in range(4):
   a,b=low[side],low[(side+1)%4];c,e=high[(side+1)%4],high[side]
   n=max(8,int((Vector(b)-Vector(a)).length/.75))
   for i in range(n):
    u=i/n;v=(i+1)/n
    p0=Vector(a).lerp(Vector(b),u);p1=Vector(a).lerp(Vector(b),v);p2=Vector(e).lerp(Vector(c),v);p3=Vector(e).lerp(Vector(c),u)
    drop=random.uniform(.02,.24);p0.z-=drop;p1.z-=drop
    vs=[tuple(p) for p in [p0,p1,p2,p3]]+[tuple(p-Vector((0,0,.28))) for p in [p0,p1,p2,p3]]
    mesh(prefix+'_thatch_course',vs,[(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],2,group)
 # Pale cap and underside fascia.
 beam(prefix+'_ridge',(cx-w*.29,cy,z+h+.2),(cx+w*.29,cy,z+h+.2),.32,0,group,10)
 for a,b in [((cx-w/2,cy-d/2,z-.12),(cx+w/2,cy-d/2,z-.12)),((cx-w/2,cy+d/2,z-.12),(cx+w/2,cy+d/2,z-.12))]:beam(prefix+'_eave',a,b,.25,6,group)
hip_roof('Main_roof',0,51,87,33,17.8,11.6,'04_ThatchRoof')
box('Pavilion_body',(0,51,31.2),(16,10,8.2),0,'05_Pavilion',.12)
for x in [-7.7,7.7]:box('Pavilion_timber',(x,45.85,31.4),(.6,.35,8.3),1,'05_Pavilion',.03)
box('Pavilion_red_sill',(0,45.8,28.5),(16,.35,.45),1,'05_Pavilion',.03)
hip_roof('Pavilion_roof',0,51,20,14,35.5,5.5,'05_Pavilion')
# Sign plaque layers; characteristic tapered lower corners.
coords=[(-22,26),(22,26),(20.6,21.1),(-20.6,21.1)]
extrude_profile('Tournament_sign_gold',coords,37,1,12,'06_Sign')
extrude_profile('Tournament_sign_red',[(-21.3,25.4),(21.3,25.4),(20.0,21.65),(-20,21.65)],36.44,.16,1,'06_Sign')
extrude_profile('Tournament_sign_ivory',[(-20.7,25),(20.7,25),(19.55,22.04),(-19.55,22.04)],36.33,.12,15,'06_Sign')
font=bpy.data.fonts.load(r'C:\Windows\Fonts\YuGothB.ttc')
title=text_obj('Tournament_calligraphy','天下一武道会',(0,36.23,22.43),4.2,14,'06_Sign',font)
lo=[min(v.co[i] for v in title.data.vertices) for i in range(3)];hi=[max(v.co[i] for v in title.data.vertices) for i in range(3)]
title.scale=(36/(hi[0]-lo[0]),2.36/(hi[1]-lo[1]),1)
title.location.x=-(lo[0]+hi[0])*.5*title.scale.x; title.location.z=22.35-lo[1]*title.scale.y
# Checkpoint.
scene['design']='Dragon Ball Tenkaichi Budokai inspired modular Roblox arena; 64 stud ring; no characters'
scene['scale_reference']='Ring tile surface = 64 x 64 Blender units; import Scale Unit = Stud'
scene.render.filepath=os.path.join(ROOT,'previews','01_structure.png')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'Tenkaichi_Arena.blend'))
screenshot_view()
print('STRUCTURE_COMPLETE',len(scene.objects))
