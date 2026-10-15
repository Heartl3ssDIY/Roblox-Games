exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\TenkaichiArena\source\common.py',encoding='utf-8').read(),'common.py','exec'))
import ast
src=ast.parse(open(os.path.join(ROOT,'source','01_structure.py'),encoding='utf-8').read())
exec(compile(ast.Module(body=[n for n in src.body if isinstance(n,ast.FunctionDef) and n.name=='hip_roof'],type_ignores=[]),'roof_function','exec'))
# Small tiled roof service pavilions at the back of the complex.
for side in [-1,1]:
 x=side*57; y=60; g='14_Annexes'
 box('Annex_foundation',(x,y,.65),(23,20,1.3),5,g,.12)
 box('Annex_plaster',(x,y,5.5),(21,18,9.8),0,g,.1)
 for dx in [-10,10]:box('Annex_timber',(x+dx,y-9.05,5.8),(.55,.35,9.8),1,g,.04)
 box('Annex_door',(x,y-9.18,4.7),(4,.2,7.8),6,g,.10)
 for dx in [-6.3,6.3]:
  box('Annex_window_frame',(x+dx,y-9.22,6.5),(4.3,.35,2.3),1,g,.06)
  box('Annex_window',(x+dx,y-9.43,6.5),(3.7,.12,1.75),11,g,.04)
 hip_roof('Annex',x,y,25,22,10.8,5.5,g)
 for k in range(2):box('Annex_step',(x,y-10.4-k*.8,.55-k*.22),(5.3,1.7,.9-k*.4),5,g,.06)
# Umbrellas with curved ribs, scalloped red edges and a real underside.
for side in [-1,1]:
 x=side*36.6;y=24;g='15_Parasols'
 box('Parasol_stone_foot',(x,y,.3),(1.6,1.6,.6),5,g,.12)
 beam('Parasol_post',(x,y,.5),(x,y,7.55),.13,6,g,10)
 for i in range(16):
  a=i*2*pi/16;b=(i+1)*2*pi/16
  rings=[(.06,7.7),(1.1,7.52),(2.3,6.95),(3.45,6.12)]
  v=[]
  for r,z in rings:v.extend([(x+r*cos(a),y+r*sin(a),z),(x+r*cos(b),y+r*sin(b),z)])
  v+= [(vx,vy,vz-.08) for vx,vy,vz in v]
  f=[]
  for j in range(3):f.extend([(2*j,2*j+1,2*j+3,2*j+2),(10+2*j,11+2*j,9+2*j,8+2*j)])
  f += [(0,8,9,1),(6,7,15,14)]
  for j in range(3):f.extend([(2*j,2*j+2,10+2*j,8+2*j),(2*j+1,9+2*j,11+2*j,3+2*j)])
  mesh('Parasol_canopy_panel',v,f,11 if i%4 else 3,g,True)
  am=(a+b)/2
  p=[(x+3.43*cos(a),y+3.43*sin(a),6.1),(x+3.43*cos(am),y+3.43*sin(am),5.77),(x+3.43*cos(b),y+3.43*sin(b),6.1)]
  tube('Parasol_red_scallop',p,[.19,.23,.19],1,g,6)
  tube('Parasol_rib',[(x+r*cos(a),y+r*sin(a),z+.04) for r,z in rings],[.045]*4,0,g,5)
 ellipsoid('Parasol_finial',(x,y,7.86),(.18,.18,.29),12,g,12,6)
# Tall curved festival banners. Both sides of cloth are modelled.
for side in [-1,1]:
 for j in range(2):
  bx=side*(44+4*j);by=35+5*j;g='16_FestivalBanners'
  h=32+5*j
  pts=[(bx+side*5*(t**2),by,h*t+.6) for t in [i/8 for i in range(9)]]
  tube('Festival_bamboo_pole',pts,[.19*(1-i*.06) for i in range(9)],6,g,8)
  box('Festival_pole_foot',(bx,by,.5),(1.4,1.4,1),5,g,.1)
  verts=[]
  for k in range(13):
   t=k/12;z=h*(.32+.68*t);xx=bx+side*5*((.32+.68*t)**2)
   width=3.6*sin(pi*(.1+.9*t))**.6+.1
   for edge in [0,1]:verts.append((xx+side*width*edge,by+.65*sin(t*8+edge*.8),z-.8*edge*sin(pi*t)))
  n=len(verts);verts += [(x,y+.06,z) for x,y,z in verts]
  faces=[]
  for k in range(12):
   a=k*2;faces.extend([(a,a+1,a+3,a+2),(n+a+2,n+a+3,n+a+1,n+a),(a,a+2,n+a+2,n+a),(a+1,n+a+1,n+a+3,a+3)])
  faces += [(0,n,n+1,1),(24,25,n+25,n+24)]
  mesh('Festival_ribbon',verts,faces,13 if j==0 else 12,g,True)
# Palms with bent ringed trunks and individually notched folded fronds.
def palm(x,y,height,seed):
 rng=random.Random(seed);g='20_Palm_%02d'%seed;leanx=rng.uniform(-2,2);leany=rng.uniform(-1.5,1.5)
 def center(t):return Vector((x+leanx*t*t,y+leany*t*t,.2+height*t))
 pts=[tuple(center(i/12)) for i in range(13)]
 tube('Palm_curved_trunk',pts,[.73-.34*i/12 for i in range(13)],6,g,10)
 for j in range(int(height/1.25)):
  t=(j+.25)/(height/1.25);p=center(t);r=.75-.34*t
  circle=[tuple(p+Vector((r*cos(i*2*pi/10),r*sin(i*2*pi/10),.09*sin(i*2*pi/10)))) for i in range(11)]
  tube('Palm_trunk_ring',circle,.075,5,g,5)
 crown=center(1)
 ellipsoid('Palm_crown',crown,(.85,.85,1.15),8,g,12,7)
 for i in range(9):
  ang=i*2*pi/9+rng.uniform(-.17,.17);length=rng.uniform(7.7,10.5);direction=Vector((cos(ang),sin(ang),0));cross=Vector((-sin(ang),cos(ang),0))
  verts=[];f=[];N=24
  for k in range(N+1):
   t=k/N;c=crown+direction*length*t+Vector((0,0,2.8*sin(pi*t)-4.1*t*t))
   width=(sin(pi*t)**.65)*1.4*(.36 if k%2 else 1)+.025
   verts += [tuple(c-cross*width),tuple(c+Vector((0,0,.24*sin(pi*t)))),tuple(c+cross*width)]
  n=len(verts);verts += [(vx,vy,vz-.055) for vx,vy,vz in verts]
  for k in range(N):
   a=k*3
   for u in range(2):f.extend([(a+u,a+u+3,a+u+4,a+u+1),(n+a+u+1,n+a+u+4,n+a+u+3,n+a+u)])
   f.extend([(a,n+a,n+a+3,a+3),(a+2,a+5,n+a+5,n+a+2)])
  f.extend([(0,1,2,n+2,n+1,n),(3*N,n+3*N,n+3*N+1,n+3*N+2,3*N+2,3*N+1)])
  mesh('Palm_folded_frond',verts,f,7 if i%3 else 8,g,True)
  tube('Palm_frond_spine',[tuple(crown+direction*length*t+Vector((0,0,2.8*sin(pi*t)-4.1*t*t+.12))) for t in [j/8 for j in range(9)]],[.1*(1-j/9) for j in range(9)],7,g,5)
 for i in range(3):
  a=i*2*pi/3;ellipsoid('Palm_coconut',tuple(crown+Vector((.65*cos(a),.65*sin(a),-.5))),(.36,.36,.48),6,g,10,6)
for i,(x,y,h) in enumerate([(-66,-50,22),(65,-49,24),(-69,38,24),(69,38,22),(-66,73,23),(66,73,25),(-36,74,24),(35,74,21),(-17,75,22),(18,75,25),(-52,37,22),(52,37,25)]):palm(x,y,h,i+1)
# Shrub clusters, planters and corner planting beds.
def shrub(x,y,s,seed):
 rng=random.Random(seed)
 for i in range(5):
  a=i*2*pi/5;ob=ellipsoid('Shrub_leaf_cluster',(x+cos(a)*s*.44,y+sin(a)*s*.4,s*.57+rng.uniform(-.1,.3)),(s*.8,s*.74,s*.82),7 if i%3 else 8,'21_Gardens',12,7)
  ob.rotation_euler.z=rng.uniform(0,pi)
for side in [-1,1]:
 for i,y in enumerate([-49,-41,34,42,73]):
  x=side*(57 if y<0 else 37 if y>60 else 35)
  box('Raised_garden_bed',(x,y,.38),(9,5,.76),5,'21_Gardens',.16)
  for k in [-1,0,1]:shrub(x+k*2.4,y,1.7,40+i*4+k)
 for i in range(8):shrub(side*(12+i*3.7),35.9,1.65,90+i)
 for i in range(5):shrub(side*(8+i*11),77,2,130+i)
# Stone lanterns and unobtrusive grounds props.
for side in [-1,1]:
 for y in [-43,33]:
  x=side*38.2;g='22_GroundsDetails'
  box('Lantern_base',(x,y,.35),(1.8,1.8,.7),5,g,.12)
  box('Lantern_stem',(x,y,1.7),(.65,.65,2.1),0,g,.1)
  box('Lantern_light_box',(x,y,3.2),(1.3,1.3,1.3),12,g,.08)
  for dx in [-.58,.58]:
   for dy in [-.58,.58]:box('Lantern_frame',(x+dx,y+dy,3.2),(.14,.14,1.55),6,g,.02)
  verts=[(x-1,y-1,3.9),(x+1,y-1,3.9),(x+1,y+1,3.9),(x-1,y+1,3.9),(x,y,4.7)]
  mesh('Lantern_cap',verts,[(3,2,1,0),(0,1,4),(1,2,4),(2,3,4),(3,0,4)],11,g)
 for y in [-42,34]:
  x=side*48
  box('Garden_bench',(x,y,1.5),(6,1.7,.38),6,'22_GroundsDetails',.08)
  for dx in [-2.1,2.1]:box('Garden_bench_leg',(x+dx,y,.78),(.48,1.4,1.4),5,'22_GroundsDetails',.07)
 # Green accent grasses keep pathways clear.
 for j in range(14):
  x=side*random.uniform(68,71);y=random.uniform(-29,29)
  for k in range(3):
   dx=random.uniform(-.35,.35)
   tube('Grass_blade',[(x+dx,y,.2),(x+dx+.14,y+.2,.9),(x+dx+.45,y+.24,1.3)],[.10,.07,.008],7,'21_Gardens',4)
# Broaden seams so the arena tile grid reads at game-camera distance.
for ob in collection('02_Ring').objects:
 if ob.name.startswith('Ring_paver_'):ob.scale.x=.992;ob.scale.y=.992
ob=bpy.data.objects.get('Ring_grout_bed')
if ob:atlas_uv(ob,14)
# Presentation camera and scene checkpoint.
scene=bpy.context.scene
for a in bpy.context.screen.areas:
 if a.type=='VIEW_3D':
  a.spaces.active.region_3d.view_camera_zoom=10
  a.spaces.active.shading.use_scene_world=True;a.spaces.active.shading.use_scene_lights=True
scene.camera=bpy.data.objects['Camera_Hero']
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'Tenkaichi_Arena.blend'))
print('LANDSCAPE_COMPLETE',len(scene.objects))
