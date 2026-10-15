exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\MarinefordFrozenBay\source\common.py',encoding='utf-8').read(),'common.py','exec'))
sc=bpy.context.scene
random.seed(402)
def arc_solid(name,r0,r1,a0,a1,z0,z1,cat,group,steps=4):
 pts=[(r0*sin(a),r0*cos(a)) for a in np.linspace(a0,a1,steps+1)]
 pts += [(r1*sin(a),r1*cos(a)) for a in np.linspace(a1,a0,steps+1)]
 # This order is counter-clockwise in XY.
 return slab(name,pts,z0,z1,cat,group)
lathe('MF_Continuous_Frozen_Sea',[(96,-3),(96,0)],(0,0,0),0,'01_Frozen_Bay',n=128)
# Irregular pale ice floes are flush with the combat floor.
boundary=[(95.9*cos(a),95.9*sin(a)) for a in np.linspace(0,2*pi,129)[:-1]]
seeds=[]
while len(seeds)<92:
 x=random.uniform(-94,94);y=random.uniform(-94,94)
 if x*x+y*y<94**2 and all((x-a)**2+(y-b)**2>8**2 for a,b in seeds):seeds.append((x,y))
def halfclip(poly,nx,ny,d):
 out=[]
 for j,p in enumerate(poly):
  q=poly[(j+1)%len(poly)];dp=p[0]*nx+p[1]*ny-d;dq=q[0]*nx+q[1]*ny-d
  if dp<=0:out.append(p)
  if (dp<=0)!=(dq<=0):
   t=dp/(dp-dq);out.append((p[0]+t*(q[0]-p[0]),p[1]+t*(q[1]-p[1])))
 return out
floes=Builder()
for i,(x,y) in enumerate(seeds):
 p=boundary[:]
 for a,b in seeds:
  if (a,b)==(x,y):continue
  p=halfclip(p,a-x,b-y,(a*a+b*b-x*x-y*y)/2)
  if not p:break
 if len(p)>2:
  cx=sum(a for a,b in p)/len(p);cy=sum(b for a,b in p)/len(p)
  # Hairline fissures only; no raised lips.
  p=[(cx+(a-cx)*.997,cy+(b-cy)*.997,.012) for a,b in p]
  floes.face(p,random.choices([0,1,2],[1,6,2])[0])
floes.build('MF_Pale_Ice_Fields','02_Ice_Surface')
# Fine branching blue cracks, kept perfectly flush.
cracks=Builder()
def line_ribbon(points,width,cat):
 for a,b in zip(points,points[1:]):
  dx=b[0]-a[0];dy=b[1]-a[1];l=max(.001,math.hypot(dx,dy));ox=-dy/l*width/2;oy=dx/l*width/2
  cracks.face([(a[0]+ox,a[1]+oy,.025),(a[0]-ox,a[1]-oy,.025),(b[0]-ox,b[1]-oy,.025),(b[0]+ox,b[1]+oy,.025)],cat)
for i in range(23):
 angle=i*2*pi/23;pts=[]
 for j,r in enumerate([93,82,73,66,58,51]):
  a=angle+random.uniform(-.06,.06);pts.append((r*cos(a),r*sin(a)))
 line_ribbon(pts,random.uniform(.055,.15),3)
 for j in [2,4]:
  p=pts[j];a=angle+random.choice([-1,1])*.8
  line_ribbon([p,(p[0]-cos(a)*5,p[1]-sin(a)*5),(p[0]-cos(a)*9+2,p[1]-sin(a)*9)],.055,3)
cracks.build('MF_Hairline_Frozen_Fractures','02_Ice_Surface')
# The horseshoe opens toward negative Y.
angles=np.linspace(math.radians(-145),math.radians(145),43)
for i,(a,b) in enumerate(zip(angles,angles[1:])):
 arc_solid('MF_Harbour_Wall_%02d'%i,96,103,a,b,-3,17,4,'10_Harbour_Walls',2)
 arc_solid('MF_Wall_Cap_%02d'%i,95.5,104,a,b,17,18.3,5,'11_Wall_Trim',2)
 arc_solid('MF_Quay_Deck_%02d'%i,103,120,a,b,11,15,5,'12_Quays',2)
 arc_solid('MF_Outer_Parapet_%02d'%i,119,121,a,b,15,18,4,'11_Wall_Trim',2)
 mid=(a+b)/2
 # Tall steel inset and masonry pilaster on the inside face.
 panel=box('MF_Inner_Defence_Panel_%02d'%i,(0,0,0),(8.8,.28,12.8),13,'13_Defence_Panels')
 panel.matrix_world=Matrix.Translation((95.8*sin(mid),95.8*cos(mid),8.5))@Matrix.Rotation(-mid,4,'Z')
 for z in [3,7,11,15]:
  arc_solid('MF_Stone_Course',95.72,95.86,a,b,z,z+.1,13,'11_Wall_Trim',2)
 butt=box('MF_Buttress_%02d'%i,(0,0,0),(1.1,2.4,18),5,'11_Wall_Trim')
 butt.matrix_world=Matrix.Translation((96*sin(a),96*cos(a),8.7))@Matrix.Rotation(-a,4,'Z')
 for z in [4,12]:
  riv=ico('MF_Iron_Fastener',(95.54*sin(mid),95.54*cos(mid),z),(.24,.24,.24),6,'13_Defence_Panels',1)
# Rear island terrace, behind the bay.
poly=[(-113,90),(113,90),(124,136),(98,185),(58,202),(-58,202),(-98,185),(-124,136)]
slab('MF_Rear_Island',poly,-5,18,4,'14_Fortress_Terrace')
slab('MF_Rear_Island_Paving',poly,18,18.6,5,'14_Fortress_Terrace')
box('MF_Headquarters_Podium',(0,143,23),(94,58,8.8),5,'20_Fortress_Body')
for j in range(6):
 box('MF_HQ_Approach_Step_%02d'%j,(0,103+j*1.65,18.6+j*.65),(44,2,1.3),4 if j%2 else 5,'14_Fortress_Terrace')
# Small ice pressure ridges at the perimeter.
for i in range(42):
 a=random.uniform(0,2*pi);r=random.uniform(86,93)
 if abs(a-4.71)<.35:continue
 x=r*cos(a);y=r*sin(a);h=random.uniform(1.8,5.5)
 ob=crag('MF_Ice_Ridge_%02d'%i,(x,y,-.15),random.uniform(2,4),h,random.choice([0,1,2]),'03_Perimeter_Ice',n=5)
# Thin frost shards where bay ice meets the rampart.
for a in np.linspace(math.radians(-140),math.radians(140),28):
 x=92.5*sin(a);y=92.5*cos(a)
 crag('MF_Frost_Shard',(x,y,0),1.4,random.uniform(3,7),2,'03_Perimeter_Ice',n=5)
print('Bay, ice, harbour walls and rear terrace built:',len(sc.objects),'objects')
