exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\MarinefordFrozenBay\source\common.py',encoding='utf-8').read(),'common.py','exec'))
sc=bpy.context.scene
def hiproof(name,loc,w,d,h):
 x,y,z=loc;b=Builder()
 rings=[]
 for s,zz in [(1.04,1.0),(1,0),(.78,h*.25),(.4,h)]:
  rings.append([(x-w*s/2,y-d*s/2,z+zz),(x+w*s/2,y-d*s/2,z+zz),(x+w*s/2,y+d*s/2,z+zz),(x-w*s/2,y+d*s/2,z+zz)])
 for j in range(3):
  for i in range(4):b.face([rings[j][i],rings[j][(i+1)%4],rings[j+1][(i+1)%4],rings[j+1][i]],7)
 b.face(list(reversed(rings[0])),6);b.face(rings[-1],7);b.build(name,'22_Roofs')
 for i in range(4):tube(name+'_Eave', [rings[0][i],rings[0][(i+1)%4]],.26,6,'22_Roofs',n=6)
 # Tile ridges follow each of the four sloping roof faces.
 for edge in range(4):
  for t in np.linspace(.03,.97,max(5,int((w if edge%2==0 else d)/2.7))):
   pts=[]
   for ring in rings:
    a=Vector(ring[edge]);c=Vector(ring[(edge+1)%4]);p=a.lerp(c,float(t));p.z+=.06;pts.append(p)
   tube(name+'_Tiles',pts,.08,13,'22_Roofs',n=5)
 for i in range(4):tube(name+'_Hip',[ring[i] for ring in rings],.18,6,'22_Roofs',n=6)
def facade(name,x,y,z,w,h):
 b=Builder()
 for xx in np.arange(-w/2+3,w/2-2,5):
  b.box((x+xx,y,z+h*.55),(1.35,.2,3.2),6)
  b.box((x+xx,y-.16,z+h*.55),(.16,.12,3.25),5)
 b.box((x,y,z+.6),(w,.35,.45),13);b.box((x,y,z+h-.6),(w,.35,.5),13)
 b.build(name,'21_Facade_Details')
# White fortress silhouette: massive lower keep, then four receding roof tiers.
tiers=[(82,43,27.4,22),(64,35,53.4,13),(48,29,70.4,11),(33,23,85.4,9),(20,17,98.4,8)]
for i,(w,d,z,h) in enumerate(tiers):
 box('MF_Keep_Tier_%d'%i,(0,145,z+h/2),(w,d,h),5,'20_Fortress_Body')
 box('MF_Tier_Cornice_%d'%i,(0,145,z+h-.2),(w+1.2,d+1.2,.8),4,'21_Facade_Details')
 hiproof('MF_Keep_Roof_%d'%i,(0,145,z+h),w+9,d+8,5 if i<3 else 4)
 if i:
  facade('MF_Upper_Windows_%d'%i,0,145-d/2-.15,z,w,h)
 else:
  # Wide blank central panel reserves the Marine lettering.
  for x in [-31,31]:facade('MF_Base_Windows',x,145-d/2-.15,z,16,h)
  for xx in [-40,-24,24,40]:
   box('MF_Main_Pilaster',(xx,123.2,38),(1.2,.85,22),4,'21_Facade_Details')
# Gate recess and stone arch; the arch is solid masonry, the recess is only a backdrop.
x=0;y=123.25;z=27.5;r=4.3
poly=[(-r,y,z),(r,y,z),(r,y,z+8)]
poly += [(r*cos(a),y,z+8+r*sin(a)) for a in np.linspace(0,pi,17)[1:]]
mesh('MF_Great_Gate_Dark',poly,[tuple(range(len(poly)))],11,'21_Facade_Details')
for j,a in enumerate(np.linspace(0,pi,17)[:-1]):
 b=a+pi/16
 mesh('MF_Gate_Arch',[(rr*cos(t),y-.22,z+8+rr*sin(t)) for rr,t in [(r,a),(r,b),(r+.9,b),(r+.9,a)]],[(0,1,2,3)],4,'21_Facade_Details')
for x in [-4.75,4.75]:box('MF_Gate_Jamb',(x,y-.2,z+4),(.9,.55,8),4,'21_Facade_Details')
# Marine headquarters sign, using installed Japanese/Chinese glyphs.
fontpath=next((p for p in [r'C:\Windows\Fonts\msyh.ttc',r'C:\Windows\Fonts\simhei.ttf',r'C:\Windows\Fonts\msgothic.ttc'] if os.path.exists(p)),None)
if fontpath:
 cu=bpy.data.curves.new('Marine Headquarters inscription','FONT');cu.body='\u6d77\u8ecd';cu.font=bpy.data.fonts.load(fontpath);cu.align_x='CENTER';cu.size=8.1;cu.extrude=.045
 ob=bpy.data.objects.new('MF_Marine_Headquarters_Sign',cu);collection('21_Facade_Details').objects.link(ob);ob.location=(0,122.96,42.4);ob.rotation_euler=(pi/2,0,0)
 bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob;bpy.ops.object.convert(target='MESH');ob=bpy.context.object;ob.data.materials.append(MAT);apply_uv(ob,6)
# Small roof finials.
for x in [-7,7]:
 tube('MF_Keep_Finial',[(x,145,113),(x*1.12,145,116),(x*1.03,145,117)],.3,12,'23_Flags',GOLD,n=8)
# Four watchtowers anchored in pale coastal rock shoulders.
for i,(x,y,h) in enumerate([(-78,136,43),(78,136,43),(-54,176,59),(54,176,59)]):
 crag('MF_Coastal_Rock_%d'%i,(x,y,18),17,h-18,4,'24_Coastal_Rocks',n=11)
 lathe('MF_Watchtower_Base_%d'%i,[(10,0),(8,5),(7.5,9)],(x,y,h-3),5,'25_Watchtowers',n=24)
 box('MF_Watchtower_%d'%i,(x,y,h+10),(13,12,12),5,'25_Watchtowers')
 facade('MF_Watchtower_Windows',x,y-6.1,h+4,13,12)
 hiproof('MF_Watchtower_Roof_%d'%i,(x,y,h+16),18,16,4.3)
 tube('MF_Flagpole_%d'%i,[(x,y,h+20),(x,y,h+29)],.14,13,'23_Flags',n=7)
 flag=[(x,y,h+29),(x+6,y+.45,h+28.4),(x+6,y+.8,h+25.8),(x,y,h+26.2)]
 # Closed thin flag avoids a reversed coincident face in FBX.
 ob=mesh('MF_Marine_Flag_%d'%i,flag+[(a,b+.08,c) for a,b,c in flag],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],14,'23_Flags')
 tube('MF_Flag_Emblem',[(x+1.5,y+.0,h+27.8),(x+3,y+.3,h+27),(x+4.5,y+.5,h+27.8)],.12,6,'23_Flags',n=5)
# Low flanking barracks, intentionally simplified.
for x,y,w in [(-63,108,18),(63,108,18),(-95,113,16),(95,113,16),(-101,152,16),(101,152,16)]:
 box('MF_Barracks',(x,y,24),(w,12,10.8),5,'26_Barracks')
 facade('MF_Barracks_Windows',x,y-6.1,18.6,w,10.8)
 hiproof('MF_Barracks_Roof',(x,y,29.4),w+4,17,3.3)
# Dome-mounted twin cannons along the quays.
for i,a in enumerate(np.linspace(math.radians(-135),math.radians(135),15)):
 before=set(bpy.data.objects);x=109*sin(a);y=109*cos(a)
 if abs(x)<10 and y>90:continue
 lathe('MF_Cannon_Plinth',[(3.5,0),(3.5,.5),(3,.8)],(0,0,15),4,'30_Cannons',n=24)
 dome('MF_Cannon_Turret',2.5,2.25,15.8,(0,0,0),6,'30_Cannons',GOLD,n=24)
 for xx in [-.9,.9]:
  tube('MF_Twin_Gun_Barrel',[(xx,-.8,17.4),(xx,-5.9,18.3)],[.57,.49],7,'30_Cannons',GOLD,n=12)
  tube('MF_Cannon_Muzzle',[(xx,-5.88,18.3),(xx,-6.1,18.34)],.36,11,'30_Cannons',n=12)
 trans=Matrix.Translation((x,y,3.6 if y>90 else 0))@Matrix.Rotation(-a,4,'Z')
 for ob in bpy.data.objects:
  if ob not in before:ob.matrix_world=trans@ob.matrix_world
# Frozen ships frame the outside of the playable bay.
def ship(name,x,y,angle):
 before=set(bpy.data.objects);n=20;vs=[];fs=[];cats=[]
 for rx,ry,z in [(1.5,6,.3),(3.2,8,1.8),(4,9,4.1)]:
  for i in range(n):
   a=i*2*pi/n;vs.append((rx*cos(a),ry*sin(a),z))
 for j in range(2):
  for i in range(n):a=j*n+i;b=j*n+(i+1)%n;fs.append((a,b,b+n,a+n));cats.append(8 if i%3 else 9)
 fs.extend([tuple(reversed(range(n))),tuple(2*n+i for i in range(n))]);cats.extend([9,8])
 mesh(name+'_Hull',vs,fs,cats,'40_Frozen_Ships')
 for z,rx,ry in [(2,3.35,8.2),(3.75,3.95,8.9),(4.4,4.03,9.03)]:
  tube(name+'_Hull_Band',[(rx*cos(a),ry*sin(a),z) for a in np.linspace(0,2*pi,41)],.14,12 if z==3.75 else 9,'40_Frozen_Ships',n=6)
 for yy,h in [(-3.8,17),(2.8,22)]:
  tube(name+'_Mast',[(0,yy,4),(0,yy,h)],[.26,.16],9,'40_Frozen_Ships',n=8)
  for zz,ww in [(h-3,6),(h-7,8)]:
   tube(name+'_Yard',[(-ww/2,yy,zz),(ww/2,yy,zz)],.12,9,'40_Frozen_Ships',n=6)
   # Furled, frosted canvas.
   tube(name+'_Furled_Sail',[(-ww/2,yy,zz-.4),(0,yy-.25,zz-.8),(ww/2,yy,zz-.4)],.3,2,'40_Frozen_Ships',n=7)
  for xx in [-3.5,3.5]:tube(name+'_Rigging',[(xx,yy,4.3),(0,yy,h-.2)],.035,9,'40_Frozen_Ships',n=5)
 for xx in [-3.7,3.7]:
  for yy in np.arange(-5,6,2.5):tube(name+'_Railing',[(xx,yy,4),(xx,yy,5)],.08,9,'40_Frozen_Ships',n=5)
 box(name+'_Stern_Cabin',(0,-5,5),(5,4,2.1),8,'40_Frozen_Ships')
 box(name+'_Cabin_Frost',(0,-5,6.12),(5.3,4.3,.25),2,'40_Frozen_Ships')
 trans=Matrix.Translation((x,y,0))@Matrix.Rotation(angle,4,'Z')
 for ob in bpy.data.objects:
  if ob not in before:ob.matrix_world=trans@ob.matrix_world
for name,x,y,a in [('MF_West_Frozen_Brig',-69,13,.22),('MF_East_Frozen_Brig',68,32,-.37)]:
 ship(name,x,y,a)
 for j in range(6):
  aa=j*2*pi/6
  crag(name+'_Ice',(x+5*cos(aa),y+9*sin(aa),0),2.3,random.uniform(1.2,3.2),1,'03_Perimeter_Ice',n=5)
print('Marineford fortress, watchtowers, cannons and frozen ships built:',len(sc.objects))
