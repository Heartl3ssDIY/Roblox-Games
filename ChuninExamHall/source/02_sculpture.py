exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\ChuninExamHall\source\common.py',encoding='utf-8').read(),'common.py','exec'))
g='09_Sculpture_Sleeves'
for side in [-1,1]:
 xs=[5.5,9,14,20,26,30]
 ys=[37,38.5,40,41,41,40.5]
 zs=[10.5,8.5,7.7,7.4,7.6,8.2]
 rs=[2.7,3.9,4.9,5.25,4.8,3.6]
 pts=[(side*x,y,z) for x,y,z in zip(xs,ys,zs)]
 tube('Giant_Green_Sleeve',pts,rs,4,g,24)
 for direction in [-1,1]:
  for phase in range(12):
   path=[]
   for j in range(81):
    u=j/80;xx=6.2+23*u
    idx=min(4,max(0,next((k for k in range(5) if xs[k]<=xx<=xs[k+1]),4)))
    t=(xx-xs[idx])/(xs[idx+1]-xs[idx])
    cy=ys[idx]*(1-t)+ys[idx+1]*t
    cz=zs[idx]*(1-t)+zs[idx+1]*t
    r=(rs[idx]*(1-t)+rs[idx+1]*t)+.06
    theta=phase*2*pi/12+direction*u*2.7*pi
    path.append((side*xx,cy+r*cos(theta),cz+r*sin(theta)))
   tube('Sleeve_Diamond_Braid',path,.13,5 if direction==1 else 14,g,5)
 for xx,r in [(6.1,2.85),(7.0,3.05)]:
  idx=0;t=(xx-xs[0])/(xs[1]-xs[0])
  cy=ys[0]*(1-t)+ys[1]*t;cz=zs[0]*(1-t)+zs[1]*t
  tube('Sleeve_Cuff',[(side*xx,cy+r*cos(j*2*pi/40),cz+r*sin(j*2*pi/40)) for j in range(41)],.26,5,g,8)
g='10_Hand_Seal'
left=ellipsoid('Left_Hand_Palm',(-2.0,36.3,15.8),(3.6,2.7,6.6),8,g,20,12)
left.rotation_euler[1]=-.20
tube('Left_Stone_Wrist',[(-6.3,37.2,10.5),(-4.0,36.8,12),(-2.4,36.3,16.0)],[2.4,2.9,3.2],8,g,14)
tube('Raised_Index_Finger',[(-1.75,36.2,20),(-1.05,36.5,24),(-.8,37.1,28),(-.25,37.6,32)],[1.25,1.16,.94,.60],8,g,10)
ellipsoid('Index_Rounded_Tip',(-.25,37.6,32),(.60,.68,.63),8,g,12,6)
tube('Raised_Middle_Finger',[(.45,37.5,20.2),(.5,37.5,24),(.95,38.0,28),(.7,38.3,30.6)],[1.12,1.06,.86,.56],7,g,10)
ellipsoid('Middle_Rounded_Tip',(.7,38.3,30.6),(.56,.58,.58),8,g,12,6)
for index in range(3):
 z=21.2-index*2.1
 pts=[(-3.3,35,z-.5),(-2.5,33.9,z+.1),(-.8,33.4,z+.6),(1.0,34,z+.4)]
 tube('Left_Curled_Finger_'+str(index),pts,[.82,.94,.9,.66],8,g,10)
 tube('Finger_Crease_'+str(index),[(-2.55,33.04,z-.35),(-1.4,32.95,z+.05),(-.45,33.14,z+.20)],.045,2,g,5)
right=ellipsoid('Right_Hand_Palm',(3.55,35.05,12.7),(4.1,3.0,4.3),8,g,20,12)
right.rotation_euler[1]=-.65
tube('Right_Wrist',[(7,37.3,10.7),(5.6,36.5,11.8),(4.4,35.2,12.5)],[2.4,2.7,3.0],8,g,14)
for index in range(4):
 x=.0+index*1.25
 tube('Right_Folded_Finger_'+str(index),[(x+1,34,15.1-index*.18),(x,32.15,14.5-index*.18),(x+.25,31.75,12.6-index*.18),(x+1,33,11.9-index*.18)],[.75,.85,.81,.55],8,g,10)
 tube('Right_Knuckle_Crease_'+str(index),[(x-.33,31.9,13.2-index*.18),(x+.18,31.0,13.15-index*.18),(x+.70,31.75,12.98-index*.18)],.045,2,g,5)
tube('Crossing_Thumb',[(6,34,15.7),(3.5,32.2,17),(.7,32.5,17.8),(-.5,33.4,17.4)],[1.3,1.2,.95,.63],8,g,12)
ellipsoid('Thumb_Knuckle',(3.5,32.1,17),(1.18,1.0,1.0),8,g,12,6)
for pts in [
 [(-2.6,33.75,12.2),(-3.2,33.8,14.0),(-2.9,33.75,15.4)],
 [(-1.55,35.4,25),(-1.3,35.43,25.15),(-.3,35.6,25.25)],
 [(-1.05,36.2,29),(-.4,36.25,29.1),(.2,36.6,29.3)],
 [(3.2,31.98,16.7),(3.9,31.65,16.3),(4.4,31.9,16.0)]
]:
 tube('Sculpted_Stone_Crease',pts,.045,2,g,5)
g='11_Hall_Details'
for side in [-1,1]:
 x=side*35
 box('Rear_Door_Frame',(x,46.45,7.5),(6.4,.7,12),2,g,.12)
 box('Rear_Door',(x,45.98,7.4),(5.3,.2,10.7),6,g,.05)
 for dx in [-1.8,-.9,0,.9,1.8]:
  box('Door_Slat',(x+dx,45.78,7.4),(.09,.07,10.4),9,g)
 box('Door_Handle',(x+side*.9,45.58,7),(.16,.22,1.2),12,g,.02)
 for y in [-30,-6,18,40]:
  box('Wall_Lamp_Mount',(side*39.6,y,24),(1.5,1.5,2.5),6,g,.1)
  beam('Lamp_Bracket',(side*39.2,y,24),(side*37.9,y,24),.18,9,g)
  ellipsoid('Amber_Lantern',(side*37.8,y,24.2),(.75,.7,1.3),13,g,12,6)
  for z in [23.2,25.2]:
   box('Lantern_Frame',(side*37.8,y,z),(1.7,1.5,.22),9,g,.04)
  d=bpy.data.lights.new('Warm_Wall_Light','POINT');d.energy=100;d.color=(1,.56,.24);d.shadow_soft_size=2
  ob=bpy.data.objects.new(d.name,d);collection('90_Presentation').objects.link(ob);ob.location=(side*37,y,24)
# Small missing floor chips at the perimeter retain a clear combat center.
for i in range(70):
 x=random.choice([-1,1])*random.uniform(22,30.9);y=random.uniform(-43,21);r=random.uniform(.06,.24)
 verts=[(x,y,.215),(x+r,y+.08,.215),(x+.2*r,y+r*1.8,.215)]
 mesh('Floor_Surface_Chip',verts,[(0,1,2)],1,'03_Floor_Weathering')
hero=camera('Camera_Hall_Hero',(0,-102,77),(0,8,11),35)
detail=camera('Camera_Hand_Detail',(30,-14,33),(0,38,17),48)
overview=camera('Camera_Gameplay',(0,-74,94),(0,1,1),38)
bpy.context.scene.camera=hero
world=bpy.data.worlds.new('Chunin_Hall_World');world.use_nodes=True
bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND')
bg.inputs['Color'].default_value=(.18,.23,.27,1);bg.inputs['Strength'].default_value=.45
bpy.context.scene.world=world
for name,loc,target,power,size,color in [
 ('Overhead_Softbox',(0,-4,62),(0,0,0),75000,55,(.87,.95,1)),
 ('Front_Fill',(0,-60,30),(0,25,12),24000,40,(1,.89,.68)),
 ('Rear_Window_Light',(0,42,40),(0,-2,5),30000,30,(.62,.8,1)),
]:
 d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size;d.color=color
 ob=bpy.data.objects.new(name,d);collection('90_Presentation').objects.link(ob);ob.location=loc
 ob.rotation_euler=(Vector(target)-Vector(loc)).to_track_quat('-Z','Y').to_euler()
scene=bpy.context.scene
scene.render.resolution_x=1500;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.filepath=os.path.join(ROOT,'previews','Chunin_Hall_Hero.png')
for screen in bpy.data.screens:
 for a in screen.areas:
  if a.type=='VIEW_3D':
   a.spaces.active.region_3d.view_perspective='CAMERA'
   a.spaces.active.overlay.show_overlays=False
   a.spaces.active.shading.type='MATERIAL'
print("Hand-sign sculpture, braided sleeves, lamps and presentation cameras built.")
