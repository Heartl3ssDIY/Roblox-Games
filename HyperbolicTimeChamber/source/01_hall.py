exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\HyperbolicTimeChamber\source\common.py',encoding='utf-8').read(),'common.py','exec'))
if MAT is None:MAT,GOLD,GLASS=make_materials()
sc=bpy.context.scene
box('TC_White_Training_Expanse',(0,30,-.25),(480,480,.5),15,'01_Training_Floor')
terrace=[(-72,64),(72,64),(72,94),(69,100),(-69,100),(-72,94)]
slab('TC_Rear_Terrace',terrace,0,.6,12,'02_Platforms');tiles('TC_Terrace_Tiles',terrace,.625,'03_Tiles')
for i,(r,z) in enumerate([(28,.6),(25,1.4),(22,2.2),(19,3)]):
 poly=dshape(r)
 slab('TC_Curved_Step_%02d'%i,poly,max(0,z-.8),z,12,'02_Platforms');tiles('TC_Step_Tiles_%02d'%i,poly,z+.025,'03_Tiles')
 # pale blue nosing follows the semicircular front and straight sides.
 pts=[(x,y,z+.015) for x,y in poly[:41]];tube('TC_Step_Edge_%02d'%i,pts,.09,2,'04_Trim',n=6)
# Curved back of the pavilion with alternating glazing and white mullions.
walls=Builder();windows=Builder();relief=Builder()
for i in range(18):
 t0=i*pi/18;t1=(i+1)*pi/18
 for r,z0,z1,cat,b in [(17.9,3,9,0,walls),(17.9,9,21.4,2,windows),(18,21.4,22.1,0,walls)]:
  p0=(r*cos(t0),82+r*sin(t0));p1=(r*cos(t1),82+r*sin(t1))
  b.face([(p0[0],p0[1],z0),(p1[0],p1[1],z0),(p1[0],p1[1],z1),(p0[0],p0[1],z1)],cat)
  # inner faces for the visible hall interior.
  b.face([(p0[0]*.993,82+(p0[1]-82)*.993,z1),(p1[0]*.993,82+(p1[1]-82)*.993,z1),(p1[0]*.993,82+(p1[1]-82)*.993,z0),(p0[0]*.993,82+(p0[1]-82)*.993,z0)],cat)
for i in range(10):
 t=i*pi/9;x=18*cos(t);y=82+18*sin(t)
 tube('TC_Wall_Mullion_%02d'%i,[(x,y,3),(x,y,22)],.19,0,'06_Pavilion_Walls',n=8)
for i in range(14):
 t=(i+.5)*pi/14;r=18.06
 center=Vector((r*cos(t),82+r*sin(t),6));u=Vector((-sin(t),cos(t),0))
 pts=[center+u*1.35,center+Vector((0,0,1.8)),center-u*1.35,center-Vector((0,0,1.8)),center+u*1.35]
 tube('TC_Skirt_Diamond_%02d'%i,[tuple(p) for p in pts],.075,1,'07_Column_Detail',n=5)
walls.build('TC_White_Curved_Walls','06_Pavilion_Walls');windows.build('TC_Blue_Curved_Windows','06_Pavilion_Walls')
# Turned white front columns and delicate collar rings.
for j,t in enumerate(np.radians([210,250,290,330])):
 x=17.65*cos(t);y=82+17.65*sin(t)
 profile=[(.87,3.03),(.87,3.35),(.65,3.55),(.53,4.5),(.45,5),(.45,7),(.67,7.3),(.67,7.65),(.45,8),(.45,12),(.65,12.2),(.65,12.5),(.44,12.8),(.44,17),(.64,17.3),(.64,17.7),(.48,18),(.48,20.5),(.8,21.25),(.86,21.9)]
 lathe('TC_Turned_Column_%02d'%j,profile,(x,y,0),0,'07_Column_Detail',n=24)
lathe('TC_Eave_Ring',[(18,21.7),(19.3,21.9),(19.3,22.55),(18.8,22.9)],(0,82,0),0,'08_Dome')
lathe('TC_Gold_Dome_Base',[(18.6,22.75),(18.8,23.0),(18.8,23.35)],(0,82,0),4,'08_Dome',GOLD)
dome('TC_Golden_Dome',18.6,11.7,23.15,(0,82,0),4,'08_Dome',GOLD,n=96)
for i in range(24):
 a=i*2*pi/24;pts=[(18.63*cos(t)*cos(a),82+18.63*cos(t)*sin(a),23.15+11.73*sin(t)) for t in np.linspace(0,pi/2-.065,23)]
 tube('TC_Dome_Rib_%02d'%i,pts,.055,5,'09_Gold_Detail',GOLD,n=5)
lathe('TC_Dome_Finial',[(1.85,34.6),(1.85,35),(1.25,35.4),(.75,35.8),(1.5,36.4),(1.85,37.5),(1.5,38.6),(.55,39.25),(.1,41.3)],(0,82,0),4,'09_Gold_Detail',GOLD,n=40)
# Barrel-vaulted pink side rooms.
for side in [-1,1]:
 x=side*29
 box('TC_Side_Room_%s'%side,(x,82,8.45),(23,24,10.9),0,'10_Side_Rooms')
 roof=Builder();ribs=Builder()
 for j in range(24):
  t0=j*pi/24;t1=(j+1)*pi/24
  ya=82+12.25*cos(t0);yb=82+12.25*cos(t1);za=14+7.1*sin(t0);zb=14+7.1*sin(t1)
  roof.face([(x-12,ya,za),(x+12,ya,za),(x+12,yb,zb),(x-12,yb,zb)],6)
 # Front and back white roof cornices.
 box('TC_Pink_Eave_%s'%side,(x,69.7,14.1),(24.6,.45,.55),0,'10_Side_Rooms')
 box('TC_Pink_Eave_Back_%s'%side,(x,94.3,14.1),(24.6,.45,.55),0,'10_Side_Rooms')
 for xx in [x-12,x+12]:
  arc=[(xx,82+12.25*cos(t),14+7.1*sin(t)) for t in np.linspace(0,pi,33)]
  tube('TC_Roof_End_Trim_%s_%s'%(side,xx),arc,.22,0,'11_Pink_Roofs',n=8)
  roof.face([(xx,82+12.25*cos(t),14+7.1*sin(t)) for t in np.linspace(0,pi,33)],1)
 for j in range(1,12):
  t=j*pi/12
  tube('TC_Roof_Seam_%s_%s'%(side,j),[(x-11.8,82+12.28*cos(t),14+7.14*sin(t)),(x+11.8,82+12.28*cos(t),14+7.14*sin(t))],.045,7,'11_Pink_Roofs',n=5)
 roof.build('TC_Pink_Barrel_Roof_%s'%side,'11_Pink_Roofs')
 # Rounded horizontal window on front wall.
 for label,width,height,y,cat in [('Frame',16.5,2.55,69.96,1),('Glass',15.35,1.5,69.91,3)]:
  p=[]
  for a in np.linspace(-pi/2,pi/2,17):p.append((x+(width-height)/2+height/2*cos(a),y,9+height/2*sin(a)))
  for a in np.linspace(pi/2,3*pi/2,17):p.append((x-(width-height)/2+height/2*cos(a),y,9+height/2*sin(a)))
  mesh('TC_Side_Window_'+label+str(side),p,[tuple(range(len(p)))],cat,'10_Side_Rooms')
# Restrained interior furnishings visible through the open portico.
box('TC_Rear_Door_Frame',(0,96.3,9.3),(7.2,.5,12.5),0,'12_Interior')
box('TC_Rear_Door_Left',(-1.55,95.95,9.1),(2.9,.18,11.5),10,'12_Interior')
box('TC_Rear_Door_Right',(1.55,95.95,9.1),(2.9,.18,11.5),10,'12_Interior')
for x in [-.3,.3]:tube('TC_Door_Handle_'+str(x),[(x,95.6,8.3),(x,95.6,9.1)],.08,4,'12_Interior',GOLD)
box('TC_Bench_Platform',(-8,85,3.9),(9,4,1.7),10,'12_Interior')
box('TC_Bench_Cushion',(-8,85,4.95),(8.8,3.9,.6),13,'12_Interior')
lathe('TC_Small_Table',[(1.6,3.05),(1.6,3.3),(.2,3.5),(.2,6.6),(2.2,6.7),(2.2,7)],(8,84,0),5,'12_Interior',GOLD,n=32)
lathe('TC_Water_Vessel',[(.7,7.01),(.9,8.3),(.5,8.9),(.4,9.7),(.5,9.85)],(8,84,0),9,'12_Interior',n=24)
# White arched clock tab on the front of the gold dome.
outline=[(-3.2,22.5),(3.2,22.5),(3.2,26.7)]
outline.extend((3.2*cos(t),26.7+3.2*sin(t)) for t in np.linspace(0,pi,25))
outline.append((-3.2,22.5))
vs=[(x,62.78,z) for x,z in outline]
mesh('TC_Clock_Arch',vs,[tuple(range(len(vs)))],0,'13_Clock')
def disc(name,r,y,z,cat):
 vs=[(r*cos(t),y,z+r*sin(t)) for t in np.linspace(0,2*pi,65)[:-1]]
 return mesh(name,vs,[tuple(range(64))],cat,'13_Clock',GOLD if cat==4 else None)
disc('TC_Clock_Bezel',2.48,62.68,26.6,4);disc('TC_Clock_Face',2.18,62.64,26.6,11)
for i in range(12):
 t=i*2*pi/12;tube('TC_Clock_Tick_%02d'%i,[(1.82*sin(t),62.57,26.6+1.82*cos(t)),(2.02*sin(t),62.57,26.6+2.02*cos(t))],.045,14,'13_Clock',n=5)
tube('TC_Clock_Minute',[(0,62.5,26.6),(0,62.5,28.3)],.07,14,'13_Clock',n=6)
tube('TC_Clock_Hour',[(0,62.49,26.6),(.5,62.49,27.6)],.09,14,'13_Clock',n=6)
disc('TC_Clock_Pin',.16,62.42,26.6,4)
print('Hall, clock, roofs and curved tiled steps built')
