exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\JujutsuHighArena\source\architecture.py',encoding='utf-8').read(),'architecture.py','exec'))
sc=bpy.context.scene
# Sculpted campus footprint and a level, uncluttered practice court.
campus=[(-128,-96),(-105,-118),(100,-118),(131,-92),(143,118),(111,181),(-97,181),(-139,133)]
slab('JH_Campus_Earth',campus,-5,-.4,8,'01_Ground')
box('JH_Courtyard_Foundation',(0,0,-.6),(96,132,1.2),2,'01_Ground')
box('JH_Open_Training_Court',(0,0,.025),(80,116,.05),0,'02_Combat_Courtyard')
# Broad stone edging and walks, flush with the sand.
for x in [-44,44]:box('JH_Side_Walk',(x,0,.025),(8,132,.05),2,'03_Stone_Walks')
for y in [-62,62]:box('JH_End_Walk',(0,y,.025),(80,8,.05),2,'03_Stone_Walks')
pavers=Builder()
for x in [-44,44]:
 for y in np.arange(-65,65,4):
  for dx in [-2,2]:pavers.box((x+dx,y+1.95,.065),(3.95,3.87,.04),random.choice([2,11,14]))
for y in [-62,62]:
 for x in np.arange(-39,40,4):
  for dy in [-2,2]:pavers.box((x+1.95,y+dy,.065),(3.87,3.95,.04),2 if x%3 else 11)
pavers.build('JH_Courtyard_Paving','03_Stone_Walks')
# Perimeter drainage is a subtle line rather than a raised obstacle.
for x in [-39.8,39.8]:box('JH_Drain_Line',(x,0,.059),(.13,116,.025),3,'03_Stone_Walks')
box('JH_Rear_Terrace',(0,92,.55),(216,58,1.9),2,'01_Ground')
hall('JH_Main_Training_Hall',(0,80,1.5),62,26,16,main=True)
hall('JH_West_Dojo',(-63,18,0),64,22,12,angle=pi/2)
hall('JH_East_Dojo',(63,18,0),64,22,12,angle=-pi/2)
hall('JH_West_Entrance_Hall',(-65,-48,0),25,23,11,angle=pi/2)
hall('JH_East_Entrance_Hall',(65,-48,0),25,23,11,angle=-pi/2)
# Tall dark timber campus building from the aerial reference.
x=24;y=128;w=49;d=37;z=1.5
box('JH_Main_Block_Plinth',(x,y,z+1),(w+5,d+5,2),2,'20_Campus_Block')
box('JH_Main_Block_Shadow',(x,y,z+24),(w,d,46),3,'20_Campus_Block')
b=Builder()
for level in range(5):
 zz=z+3+level*8.2
 b.box((x,y,zz),(w+3,d+3,.8),4)
 b.box((x,y,zz+6.9),(w+1,d+1,.5),3)
 for xx in np.arange(-w/2+2,w/2-1,4.6):
  b.box((x+xx,y-d/2-.08,zz+3.6),(3.45,.24,4.7),15)
  for ox in [-1.8,1.8]:b.box((x+xx+ox,y-d/2-.25,zz+3.5),(.24,.32,6.5),4)
  b.box((x+xx,y-d/2-.3,zz+2.1),(3.6,.18,.18),5)
 for yy in np.arange(-d/2+2,d/2-1,4.6):
  for side in [-1,1]:
   b.box((x+side*(w/2+.08),y+yy,zz+3.6),(.24,3.45,4.7),15)
   b.box((x+side*(w/2+.2),y+yy,zz+2.1),(.18,3.6,.18),5)
 for xx in [-w/2,w/2]:
  for yy in [-d/2,d/2]:b.box((x+xx,y+yy,zz+3.3),(.8,.8,7.6),4)
b.build('JH_Main_Block_Timber_Grid','21_Campus_Block_Trim')
temple_roof('JH_Main_Block_Roof',(x,y,49),58,46,10,'22_Campus_Block_Roof')
BUILDING_BOUNDS.append({'name':'JH_Main_Block','x':x,'y':y,'z':1.5,'w':w+3,'d':d+3,'h':49,'angle':0})
# Five-storey pagoda with verandas and projecting grey tiled eaves.
px=-77;py=92
box('JH_Pagoda_Plinth',(px,py,2.3),(29,29,4.6),2,'24_Pagoda')
for level in range(5):
 w=20-level*1.35;z=4.6+level*10.2
 box('JH_Pagoda_Tier',(px,py,z+3.8),(w,w,7.6),5,'24_Pagoda')
 b=Builder()
 for side in [-1,1]:
  for t in np.linspace(-w/2,w/2,5):
   b.box((px+t,py+side*w/2,z+3.8),(.42,.5,7.8),3)
   b.box((px+side*w/2,py+t,z+3.8),(.5,.42,7.8),3)
  for zz in [z+.5,z+3.2,z+7.2]:
   b.box((px,py+side*w/2,zz),(w+.8,.6,.45),3)
   b.box((px+side*w/2,py,zz),(.6,w+.8,.45),3)
  for t in np.linspace(-w/2+2,w/2-2,4):
   b.box((px+t,py+side*(w/2+.03),z+5.2),(2.6,.18,2.8),15)
   b.box((px+side*(w/2+.03),py+t,z+5.2),(.18,2.6,2.8),15)
 b.build('JH_Pagoda_Timber','24_Pagoda')
 box('JH_Pagoda_Balcony',(px,py,z+.2),(w+3,w+3,.45),4,'24_Pagoda')
 temple_roof('JH_Pagoda_Roof',(px,py,z+7.7),w+8,w+8,4,'25_Pagoda_Roofs')
tube('JH_Pagoda_Finial',[(px,py,58),(px,py,71)],[.26,.1],12,'24_Pagoda',GOLD,n=8)
for z in np.arange(60,69,1.1):lathe('JH_Finial_Ring',[(1.5-(z-60)*.1,0),(1.5-(z-60)*.1,.12)],(px,py,z),12,'24_Pagoda',GOLD,n=16)
BUILDING_BOUNDS.append({'name':'JH_Pagoda','x':px,'y':py,'z':0,'w':28,'d':28,'h':58,'angle':0})
# Tiled enclosure walls with an open central entrance.
for side in [-1,1]:
 box('JH_Front_Garden_Wall',(side*67,-77,3),(102,2.4,6),5,'30_Enclosure_Walls')
 box('JH_Front_Wall_Base',(side*67,-77,.4),(103,3.2,.8),2,'30_Enclosure_Walls')
 temple_roof('JH_Front_Wall_Tiles',(side*67,-77,6),104,5,1.1,'31_Enclosure_Roofs')
 box('JH_Side_Garden_Wall',(side*119,22,3),(2.4,199,6),5,'30_Enclosure_Walls')
 before=set(bpy.data.objects);temple_roof('JH_Side_Wall_Tiles',(0,0,6),200,5,1.1,'31_Enclosure_Roofs')
 for o in bpy.data.objects:
  if o not in before:o.matrix_world=Matrix.Translation((side*119,22,0))@Matrix.Rotation(pi/2,4,'Z')@o.matrix_world
# Timber entrance gate without doors blocking the route.
for x in [-12,12]:
 box('JH_Entry_Post_Foot',(x,-77,.8),(2.8,2.8,1.6),2,'32_Entry_Gate')
 box('JH_Entry_Post',(x,-77,7),(1.3,1.3,13),3,'32_Entry_Gate')
box('JH_Entry_Lintel',(0,-77,12.5),(28,1.8,1.4),4,'32_Entry_Gate')
temple_roof('JH_Entry_Roof',(0,-77,13.4),34,13,5,'32_Entry_Gate')
for j in range(5):
 box('JH_Approach_Step',(0,-82-j*2,-.12-j*.42),(27,2.15,.5),2,'14_Stairs')
# Stone lanterns and edge training props.
def lantern(x,y):
 lathe('JH_Stone_Lantern_Base',[(1.4,0),(1.4,.35),(.65,.6),(.55,3.7),(1.1,4)],(x,y,0),2,'33_Lanterns',n=12)
 box('JH_Lantern_Light',(x,y,4.7),(1.3,1.3,1.4),5,'33_Lanterns')
 for dx in [-.75,.75]:
  for dy in [-.75,.75]:box('JH_Lantern_Post',(x+dx,y+dy,4.7),(.23,.23,1.6),2,'33_Lanterns')
 lathe('JH_Lantern_Cap',[(1.5,0),(1.6,.2),(.4,1.1),(.15,1.3)],(x,y,5.5),2,'33_Lanterns',n=4)
for x in [-43,43]:
 for y in [-48,48]:lantern(x,y)
for x in [-43,43]:
 for y in [-16,1,18]:
  tube('JH_Practice_Post',[(x,y,0),(x,y,3.8)],.34,4,'34_Training_Props',n=8)
  tube('JH_Practice_Wrap',[(x,y,2.1),(x,y,3.2)],.4,1,'34_Training_Props',n=8)
open(ROOT+'/source/building_bounds.json','w').write(json.dumps(BUILDING_BOUNDS,indent=2))
print('Courtyard and campus architecture built:',len(sc.objects))
