exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\WanoFlowerCapital\source\common.py',encoding='utf-8').read(),'common.py','exec'))
if MAT is None:MAT,GOLD,GLASS=make_materials()
sc=bpy.context.scene
poly=[(-100,-96),(100,-96),(110,-84),(110,186),(90,212),(-90,212),(-110,186),(-110,-84)]
slab('WA_Land_Base',poly,-3,0,10,'01_Ground')
road=[(-38,-96),(38,-96),(38,135),(28,147),(-28,147),(-38,135)]
slab('WA_Clear_Sandy_Street',road,0,.035,0,'02_Combat_Street')
# Paved borders keep all raised scenery outside the fighting region.
for side in [-1,1]:
 box('WA_Stone_Walkway_'+str(side),(side*41,19,.11),(6,230,.22),12,'03_Paving')
 for y in np.arange(-92,130,4):
  box('WA_Curb_%s_%s'%(side,int(y)),(side*38.25,y,.24),(.55,3.85,.4),14,'03_Paving')
# Simplified town buildings facing inward along the main street.
colors=[8,7,6,9,8,7]
for side in [-1,1]:
 for j,y in enumerate([-72,-37,-2,34,78,117]):
  building('WA_House_%s_%02d'%(side,j),(side*(55+2*(j%2)),y),23 if j%2 else 26,22,12+(j%3)*2,colors[(j+(side==1))%len(colors)],-side*pi/2)
 for j,y in enumerate([-66,-13,42,100,145]):
  building('WA_Outer_House_%s_%02d'%(side,j),(side*(84+(j%2)*3),y),23,21,14+(j%2)*4,colors[(j+2)%6],-side*pi/2)
# Blossom trees beside the houses, kept back from the open central lane.
for side in [-1,1]:
 for j,y in enumerate([-87,-52,16,59,136]):
  blossom_tree('WA_Cherry_%s_%s'%(side,j),(side*(77 if j%2 else 82),y,0),1.0+(j%3)*.13)
 for j,y in enumerate([-53,17,91]):
  x=side*39.8
  lathe('WA_Street_Lantern_Post_%s_%s'%(side,j),[(.65,0),(.65,.4),(.22,.8),(.22,10.8)],(x,y,0),3,'32_Lanterns',n=12)
  lathe('WA_Street_Lantern_%s_%s'%(side,j),[(.65,10.8),(1.1,11.15),(1.25,12.2),(1.1,13.3),(.65,13.6)],(x,y,0),4,'32_Lanterns',n=16)
  lathe('WA_Street_Lantern_Caps_%s_%s'%(side,j),[(.7,13.6),(.9,13.85),(.6,14)],(x,y,0),5,'32_Lanterns',GOLD,n=16)
# Wide red torii; the crossing stays clear.
for side in [-1,1]:
 lathe('WA_Torii_Foot_'+str(side),[(2.2,0),(2.2,1.2),(1.85,1.7)],(side*36,65,0),15,'20_Red_Gate',n=24)
 tube('WA_Torii_Pillar_'+str(side),[(side*36,65,1.5),(side*34.6,65,33)],[1.65,1.35],4,'20_Red_Gate',n=24)
 box('WA_Torii_Collar_'+str(side),(side*34.65,65,31.7),(4,4,1),5,'20_Red_Gate',GOLD)
box('WA_Torii_Lower_Beam',(0,65,27.7),(82,2.5,2.2),4,'20_Red_Gate')
# Upswept cap, constructed as closed segments.
b=Builder()
xs=np.linspace(-47,47,25)
for j in range(len(xs)-1):
 x0=xs[j];x1=xs[j+1];z0=33.3+3.3*(abs(x0)/47)**4;z1=33.3+3.3*(abs(x1)/47)**4
 pts=[(x0,62.9,z0),(x1,62.9,z1),(x1,67.1,z1),(x0,67.1,z0)]
 b.face(pts,4);b.face([(x,y,z+1.35) for x,y,z in reversed(pts)],15)
 b.face([pts[0],pts[1],(x1,62.9,z1+1.35),(x0,62.9,z0+1.35)],15)
 b.face([pts[2],pts[3],(x0,67.1,z0+1.35),(x1,67.1,z1+1.35)],15)
b.build('WA_Torii_Curved_Cap','20_Red_Gate')
box('WA_Torii_Center_Tie',(0,64.9,30.1),(1.4,2.9,4.5),4,'20_Red_Gate')
# A small red-railed bridge suggests the approach to the capital.
box('WA_Bridge_Deck',(0,126,1),(40,25,2),3,'21_Bridge')
for j,y in enumerate(np.arange(113.8,138,1.6)):box('WA_Bridge_Plank_%02d'%j,(0,y,2.1),(40,1.52,.22),2,'21_Bridge')
for side in [-1,1]:
 for j,y in enumerate([114,120,126,132,138]):
  x=side*19.3;box('WA_Bridge_Post_%s_%s'%(side,j),(x,y,4.1),(.85,.85,4),4,'21_Bridge')
  ico('WA_Bridge_Finial_%s_%s'%(side,j),(x,y,6.6),(.7,.7,.7),5,'21_Bridge',sub=1)
 for z in [3.4,5.3]:tube('WA_Bridge_Rail_%s_%s'%(side,z),[(side*19.3,113,z),(side*19.3,139,z)],.25,4,'21_Bridge',n=8)
# Loose petals at the road edges, never raised obstacles.
petals=Builder()
for _ in range(130):
 x=random.choice([-1,1])*random.uniform(34,44);y=random.uniform(-90,105);r=random.uniform(.1,.3)
 petals.face([(x-r,y,.27),(x,y-r*.65,.28),(x+r,y,.27),(x,y+r,.27)],13)
petals.build('WA_Edge_Petals','33_Petals')
for name,loc in [('WA_Arena_Center',(0,0,.035)),('WA_Team_A_Spawn',(0,-22,.035)),('WA_Team_B_Spawn',(0,22,.035)),('WA_Board_Min',(-32,-32,.035)),('WA_Board_Max',(32,32,.035))]:
 o=bpy.data.objects.new(name,None);collection('80_Gameplay_Markers').objects.link(o);o.location=loc;o.empty_display_size=1
open(os.path.join(ROOT,'source','building_bounds.json'),'w').write(json.dumps(BUILDING_BOUNDS,indent=2))
print('Built open street and',len(BUILDING_BOUNDS),'simple buildings')
