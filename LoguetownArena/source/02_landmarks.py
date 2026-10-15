exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\LoguetownArena\source\common.py',encoding='utf-8').read(),'common.py','exec'))
# Roger's execution platform, kept beyond the fighting area.
g='30_Execution_Platform';cx=0;cy=48
box('Scaffold_footing',(cx,cy,.35),(12,12,.5),1,g)
for x in [-4.6,4.6]:
 for y in [cy-4.6,cy+4.6]:
  box('Scaffold_steel_upright',(x,y,10),(.65,.65,20),8,g)
  box('Steel_foot_plate',(x,y,.8),(1.4,1.4,.22),8,g)
for z in [1,6.8,12.6,18.4]:
 for y in [cy-4.6,cy+4.6]:box('Scaffold_crossbar',(0,y,z),(9.7,.5,.5),8,g)
 for x in [-4.6,4.6]:box('Scaffold_crossbar',(x,cy,z),(.5,9.7,.5),8,g)
for z in [1,6.8,12.6]:
 for y in [cy-4.6,cy+4.6]:
  beam('Scaffold_X_brace',(-4.6,y,z),(4.6,y,z+5.8),.21,8,g,6)
  beam('Scaffold_X_brace',(4.6,y,z),(-4.6,y,z+5.8),.21,8,g,6)
 for x in [-4.6,4.6]:
  beam('Scaffold_X_brace',(x,cy-4.6,z),(x,cy+4.6,z+5.8),.21,8,g,6)
  beam('Scaffold_X_brace',(x,cy+4.6,z),(x,cy-4.6,z+5.8),.21,8,g,6)
box('Execution_deck_frame',(0,cy,19.7),(12,12,.7),8,g)
for i in range(12):box('Execution_deck_board',(-5.5+i,cy,20.15),(.94,11.8,.24),11,g)
for x in [-5.5,5.5]:
 for y in [cy-5.5,cy,cy+5.5]:beam('Deck_railing_post',(x,y,20.2),(x,y,22.1),.1,8,g)
 beam('Deck_side_rail',(x,cy-5.5,22.1),(x,cy+5.5,22.1),.11,8,g)
beam('Deck_rear_rail',(-5.5,cy+5.5,22.1),(5.5,cy+5.5,22.1),.11,8,g)
for x in [-1.25,1.25]:beam('Scaffold_access_ladder',(x,cy+7.6,.4),(x,cy+5.6,20.4),.12,8,g)
for i in range(20):
 z=.9+i;y=cy+7.6-(z-.4)/10
 beam('Scaffold_ladder_rung',(-1.25,y,z),(1.25,y,z),.10,8,g)
# Paired fountains outside the fighting square.
def fountain(x,y,group):
 lathe('Fountain_octagonal_plinth',[(0,0),(7.7,0),(7.7,.25),(7.2,.6),(0,.6)],(x,y,.15),1,group,8)
 lathe('Carved_basin_rim',[(0,.3),(6.7,.3),(6.8,.5),(6.8,1.2),(6.55,1.45),(6.15,1.45),(5.95,1.1),(5.95,.8),(.05,.8)],(x,y,.15),2,group,64)
 disk('Basin_turquoise_water',5.94,1.19,x,y,13,group)
 lathe('Fountain_tiered_stone',[(.03,1),(1.7,1),(1.7,1.4),(1.2,1.7),(.7,3.5),(1.3,3.8),(3.2,4.3),(3.35,4.65),(3.15,4.9),(2.8,4.8),(.7,4.35),(.52,6.8),(1.8,7.15),(1.8,7.45),(1.6,7.6),(.45,7.25),(.32,8.45),(.06,8.85)],(x,y,0),2,group,48)
 disk('Upper_bowl_water',2.7,4.79,x,y,13,group)
 disk('Crown_bowl_water',1.47,7.48,x,y,13,group)
 for k in range(6):
  a=2*pi*k/6;points=[]
  for t in np.linspace(0,1,12):
   r=.3+4.8*t;z=7.8+2*t-8.6*t*t
   points.append((x+r*cos(a),y+r*sin(a),z))
  tube('Arcing_fountain_stream',points,.045,10,group,6)
 for k in range(4):
  r=1.8+k*.85
  lathe('Water_ripple',[(r-.025,1.195),(r+.025,1.195)],(x,y,0),10,group,48)
fountain(-43,-18,'31_West_Fountain')
fountain(43,-18,'32_East_Fountain')
# Entrance columns and sign.
g='33_Entrance_Sign'
for x in [-19,19]:
 box('Gate_pedestal',(x,-60,1),(2.8,2.8,2),1,g,.12)
 box('Gate_column',(x,-60,7.5),(1.6,1.6,12),2,g,.09)
 box('Gate_capital',(x,-60,13.2),(2.4,2.4,.8),2,g,.1)
 lathe('Gate_cap',[(0,0),(1.7,0),(.15,2.3)],(x,-60,13.6),6,g,4)
box('Entrance_crossbeam',(0,-60,13.3),(39,1.5,.75),11,g,.12)
box('Loguetown_signboard',(0,-60,13.1),(30,.9,4.2),11,g,.14)
for z in [11.1,15.1]:box('Sign_brass_border',(0,-60.53,z),(30.2,.14,.18),14,g)
for x in [-15,15]:box('Sign_brass_border',(x,-60.53,13.1),(.18,.14,4.15),14,g)
text_obj('LOGUETOWN','LOGUETOWN',(0,-60.57,11.9),2.7,2,g)
# Small market stalls.
def stall(x,y,cat,group):
 box('Market_counter',(x,y,1.6),(8,3.2,2.8),11,group,.1)
 for xx in [x-3.7,x+3.7]:
  for yy in [y-1.4,y+1.4]:beam('Stall_post',(xx,yy,.2),(xx,yy,6.2),.13,11,group)
 for i in range(8):
  xx=x-4.5+i*1.125
  mesh('Striped_market_canopy',[(xx,y-2.4,5.45),(xx+1.125,y-2.4,5.45),(xx+1.125,y,6.7),(xx,y,6.7),(xx,y+2.4,5.45),(xx+1.125,y+2.4,5.45)],[(0,1,2,3),(3,2,5,4)],2 if i%2 else cat,group)
  box('Market_awning_fringe',(xx+.5625,y-2.4,5.18),(1.125,.12,.55),2 if i%2 else cat,group)
 for xx in [x-2.5,x,x+2.5]:
  box('Produce_tray',(xx,y-.6,3.15),(2.1,1.8,.32),3,group)
  for i in range(4):
   ellipsoid('Market_produce',(xx+(i%2-.5)*.7,y-.6+(i//2-.5)*.6,3.55),(.35,.33,.34),7 if i%2 else 12,group,8,4)
 for xx in [x-5.3,x+5.3]:
  lathe('Wooden_barrel',[(.05,0),(.7,0),(.88,.7),(.9,1.3),(.72,2),(.05,2)],(xx,y,.15),11,group,12)
  for zz in [.45,1.7]:lathe('Barrel_iron_hoop',[(.87,zz),(.87,zz+.12)],(xx,y,.15),8,group,12)
stall(-43,20,7,'34_Market_West');stall(43,20,6,'35_Market_East')
# Planters and greenery.
def palm(x,y,h,group,seed):
 rng=random.Random(seed)
 box('Palm_planter',(x,y,.6),(5,5,1.1),2,group,.15)
 box('Palm_soil',(x,y,1.18),(4.3,4.3,.12),11,group)
 points=[(x+.35*sin(i*.9),y+.3*cos(i),1+i*h/8) for i in range(9)]
 tube('Palm_trunk',points,[.52-i*.026 for i in range(9)],11,group,9)
 top=Vector(points[-1])
 for k in range(10):
  a=2*pi*k/10+rng.uniform(-.12,.12);length=rng.uniform(6,8)
  direction=Vector((cos(a),sin(a),0));side=Vector((-sin(a),cos(a),0))
  vs=[];fs=[]
  for j in range(9):
   t=j/8;center=top+direction*(length*t)+Vector((0,0,2.6*sin(pi*t)-1.8*t))
   width=.95*sin(pi*t)**.7 if j not in [0,8] else .02
   vs.extend([tuple(center-side*width),tuple(center+Vector((0,0,.18))),tuple(center+side*width)])
  for j in range(8):
   a0=j*3;fs.extend([(a0,a0+3,a0+4),(a0,a0+4,a0+1),(a0+1,a0+4,a0+5),(a0+1,a0+5,a0+2)])
  mesh('Palm_frond',vs,fs,12 if k%2 else 15,group)
for k,(x,y,h) in enumerate([(-41,-51,17),(41,-51,19),(-61,-79,15),(61,-79,15)]):palm(x,y,h,'36_Palms',k+20)
def broadtree(x,y,group,seed):
 rng=random.Random(seed)
 box('Tree_planter',(x,y,.55),(6,6,1),2,group,.2);box('Tree_soil',(x,y,1.11),(5.4,5.4,.1),11,group)
 beam('Tree_trunk',(x,y,.8),(x+.4,y,9),.47,11,group,9)
 for k in range(7):
  a=2*pi*k/7;xx=x+3*cos(a);yy=y+3*sin(a);zz=9+rng.uniform(-1,2)
  beam('Tree_branch',(x,y,5),(xx,yy,zz),.19,11,group,7)
  ellipsoid('Leaf_crown',(xx,yy,zz+2),(3.1,3,3.6),12 if k%3 else 15,group,12,7)
 ellipsoid('Leaf_crown_top',(x,y,13),(4,3.8,4),12,group,12,7)
for k,(x,y) in enumerate([(-45,43),(45,43),(-47,-1),(47,-1)]):broadtree(x,y,'37_Planter_Trees',k+8)
for x in [-25,25]:
 box('Rear_flowerbed',(x,49,.65),(15,6,1.2),2,'38_Garden',.16)
 box('Garden_soil',(x,49,1.27),(14,5,.1),11,'38_Garden')
 for i in range(6):
  ellipsoid('Garden_shrub',(x-5.7+i*2.3,49,2.1),(1.4,1.9,1.3),12,'38_Garden')
  for j in range(3):ellipsoid('Flower',(x-5.7+i*2.3+random.uniform(-.7,.7),49+random.uniform(-1.1,1.1),3),( .19,.19,.19),7 if i%2 else 3,'38_Garden',6,3)
# Street lamps and benches.
def lamp(x,y,group):
 lathe('Lamp_base',[(0,0),(.55,0),(.55,.5),(.3,.8),(.17,1.2),(.17,8.1),(.4,8.2)],(x,y,.15),8,group,12)
 box('Lantern_glass',(x,y,9),(1,1,1.7),3,group)
 for xx in [-.54,.54]:
  for yy in [-.54,.54]:beam('Lantern_frame',(x+xx,y+yy,8.1),(x+xx,y+yy,9.95),.065,8,group,6)
 lathe('Lantern_roof',[(0,0),(.95,0),(.15,.85),(.06,1.15)],(x,y,9.95),8,group,4)
for x in [-38,38]:
 for y in [-42,7,35,59]:lamp(x,y,'39_Street_Furniture')
for x in [-43,43]:
 for y in [-34,32]:
  for z,yy in [(1.35,y),(2.8,y+.65)]:
   for i in range(3):
    box('Bench_slat',(x,yy+(i-.5)*.26,z),(6,.22,.18),11,'39_Street_Furniture')
  for xx in [x-2.3,x+2.3]:
   beam('Bench_leg',(xx,y,.2),(xx,y,1.4),.12,8,'39_Street_Furniture')
   beam('Bench_back',(xx,y+.95,.2),(xx,y+.95,3.1),.11,8,'39_Street_Furniture')
# Gameplay markers.
for name,loc in [('LT_Arena_Center',(0,0,.12)),('LT_Team_A_Spawn',(0,-22,.12)),('LT_Team_B_Spawn',(0,22,.12)),('LT_Board_Min',(-32,-32,.12)),('LT_Board_Max',(32,32,.12))]:
 o=bpy.data.objects.new(name,None);collection('80_Gameplay_Markers').objects.link(o);o.location=loc;o.empty_display_size=2
sc=bpy.context.scene
sc.render.filepath=os.path.join(ROOT,'previews','Loguetown_Hero.png')
sc.camera=bpy.data.objects['LT_Camera_Hero'];sc.camera.location=(132,-218,169);sc.camera.rotation_euler=(Vector((0,-4,12))-sc.camera.location).to_track_quat('-Z','Y').to_euler();sc.camera.data.lens=43
bpy.data.libraries.write(os.path.join(ROOT,'Loguetown_Arena_Editable.blend'),{sc},fake_user=True,compress=True)
bpy.ops.render.render(write_still=True)
print('Landmarks, fountains, entrance and town props added',len(sc.objects))
