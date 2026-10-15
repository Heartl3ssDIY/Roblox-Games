exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\TenkaichiArena\source\common.py',encoding='utf-8').read(),'common.py','exec'))
# Two stepped spectator stands. Four seating banks leave three stair aisles.
for side,label in [(-1,'West'),(1,'East')]:
 group='10_Stands_'+label
 for row in range(8):
  x=side*(44.5+row*2.8); top=1.0+row*1.42
  box(label+'_terrace_%02d'%row,(x,-4,top/2),(2.8,66,top),5,group,.08)
  box(label+'_tread_%02d'%row,(x,-4,top+.1),(2.85,65.9,.2),0,group,.05)
  for yc,ln in [(-31,10),(-14.5,17),(6.5,17),(23,10)]:
   box(label+'_bench_seat',(x+side*.35,yc,top+.87),(1.58,ln,.28),11,group,.08)
   box(label+'_bench_back',(x+side*1.04,yc,top+1.36),(.22,ln,1.03),11,group,.06)
   for dy in [-ln*.35,ln*.35]:box(label+'_bench_foot',(x+side*.35,yc+dy,top+.46),(1.0,.22,.70),6,group,.04)
  for aisle in [-24,-4,16]:
   box(label+'_aisle_halfstep',(x-side*.7,aisle,top+.37),(1.4,3.35,.54),3,group,.04)
   box(label+'_aisle_fullstep',(x+side*.7,aisle,top+.76),(1.4,3.35,1.32),3,group,.04)
 # Blue back wall, pale coping and red lower band.
 box(label+'_rear_wall',(side*66.5,-4,6.7),(1.2,68,13.4),0,group,.10)
 box(label+'_rear_red_band',(side*66.5,-4,12.7),(1.35,68,.42),1,group,.04)
 box(label+'_rear_cap',(side*66.5,-4,13.55),(1.65,68,.38),11,group,.06)
 for y in [-38,30]:
  profile=[(side*42.7,0),(side*67.1,0),(side*67.1,14),(side*42.7,2.4)]
  extrude_profile(label+'_raked_side',profile,y,1.0,0,group)
  beam(label+'_sloping_handrail',(side*43,y,2.6),(side*66.7,y,14),.14,11,group)
  for row in range(0,8,2):
   x=side*(44.5+row*2.8); z=2.6+row*1.42
   beam(label+'_rail_stanchion',(x,y,z-1.3),(x,y,z),.11,11,group)
 # Low arena-side spectator barrier.
 box(label+'_front_barrier',(side*42.4,-4,1.05),(.7,67,2.1),0,group,.08)
 box(label+'_barrier_cap',(side*42.4,-4,2.2),(1.0,67,.26),1,group,.05)
 for y in range(-36,31,6):
  box(label+'_barrier_post',(side*42.4,y,2.35),(1.2,1.2,.5),5,group,.08)
 # Stair handrails through middle aisle.
 beam(label+'_aisle_rail',(side*43,-4,3.0),(side*65.4,-4,14.4),.105,6,group)
 for row in [0,2,4,6,7]:
  x=side*(44.5+row*2.8); z=1+row*1.42
  beam(label+'_aisle_rail_post',(x,-4,z+.1),(x,-4,z+2.55),.105,6,group)
# Lower front galleries leave a central entrance and camera corridor.
for side in [-1,1]:
 group='11_FrontGallery'
 for row in range(4):
  y=-49-row*2.7; top=.8+row*1.3
  box('Front_gallery_tier',(side*24,y,top/2),(30,2.7,top),5,group,.08)
  box('Front_gallery_seat',(side*24,y-.3,top+.8),(29,1.45,.28),11,group,.08)
  box('Front_gallery_backrest',(side*24,y-1,top+1.25),(29,.25,.95),11,group,.06)
 box('Front_gallery_rear',(side*24,-59.5,3.4),(31,1,6.8),0,group,.1)
 box('Front_gallery_cap',(side*24,-59.5,6.9),(31,1.3,.3),1,group,.05)
box('Visitor_entry_walk',(0,-54,.24),(13,23,.25),10,'01_Ground',.1)
# Low perimeter walls around the garden.
for side in [-1,1]:
 box('Garden_side_wall',(side*73,23,2.1),(1.2,113,4.2),0,'12_Perimeter',.1)
 box('Garden_side_coping',(side*73,23,4.3),(1.6,113,.35),1,'12_Perimeter',.07)
box('Garden_back_wall',(0,80,2.1),(147,1.2,4.2),0,'12_Perimeter',.1)
box('Garden_back_coping',(0,80,4.3),(147,1.6,.35),1,'12_Perimeter',.07)
for x in [-73,73]:
 for y in [-34,2,40,80]:
  box('Boundary_pier',(x,y,2.55),(2,2,5.1),5,'12_Perimeter',.1)
  box('Boundary_pier_cap',(x,y,5.15),(2.4,2.4,.4),0,'12_Perimeter',.07)
# Red panel screen behind the fighting floor.
for side in [-1,1]:
 group='07_CeremonialGate'
 box('Screen_stone_base',(side*20,30.2,2.8),(25,1.6,.8),5,group,.1)
 box('Screen_red_panel',(side*20,30.4,6.2),(24.8,1.25,6),1,group,.07)
 box('Screen_pale_coping',(side*20,30.1,9.3),(25.3,1.8,.6),0,group,.08)
 for z in [3.8,4.6,5.4,6.2,7,7.8,8.6]:box('Screen_horizontal_relief',(side*20,29.7,z),(24,.14,.08),13,group)
 for x in [side*32,side*8]:
  box('Screen_corner_post',(x,30.2,6.4),(1.5,1.9,8),0,group,.1)
  ellipsoid('Screen_post_finial',(x,30.2,10.5),(.75,.75,.65),5,group,12,6)
 # Inner gate pillars have stepped Balinese-inspired profiles.
 x=side*6.7
 for z,w,dep,h in [(2.8,3.2,3,.8),(4.8,2.6,2.4,3.4),(7.5,2.25,2.2,2),(9.4,2,2.1,1.7),(11.1,1.65,1.85,1.4),(12.5,1.3,1.5,1.2),(13.7,.95,1.15,1.1),(14.6,.52,.7,.9)]:
  box('Gate_pillar_tier',(x,30.5,z),(w,dep,h),0,group,.07)
 for z in [4.8,7.9,10.25]:
  box('Gate_pillar_red_inlay',(x,29.24,z),(1.1,.13,1.4),1,group,.10)
 for k in range(6):
  xx=x+side*(1.1+k*.46);zz=12.2-k*1.25
  box('Gate_stepped_wing',(xx,30.4,(zz+2.4)/2),(.8,1.5,zz-2.4),0,group,.07)
  ellipsoid('Gate_carved_rosette',(xx,29.58,zz-.5),(.37,.16,.37),5,group,10,6)
  tube('Gate_curl',[(xx,29.65,zz),(xx+side*.32,29.65,zz+.4),(xx+side*.14,29.65,zz+.8)],[.17,.14,.03],0,group)
 tube('Gate_pillar_tip',[(x,30.5,14.8),(x,30.5,15.6),(x-side*.17,30.5,16.7)],[.35,.22,.02],0,group,8)
# Hand-built architectural guardian masks: rounded eyes, horns, teeth, curled cheeks.
def guardian(prefix,origin,s,group):
 ox,oy,oz=origin
 def p(v):return (ox+v[0]*s,oy+v[1]*s,oz+v[2]*s)
 def e(n,loc,sc,cat=0,seg=16,rings=8):return ellipsoid(prefix+'_'+n,p(loc),tuple(v*s for v in sc),cat,group,seg,rings)
 def t(n,pts,rs,cat=0,sides=8):return tube(prefix+'_'+n,[p(v) for v in pts],[r*s for r in rs],cat,group,sides)
 e('carved_head',(0,0,0),(4.6,.95,2.8),5)
 e('forehead',(0,-.55,1.45),(3.7,.55,1.6),0)
 for side in [-1,1]:
  e('temple_curl',(side*3.8,-.65,-.15),(1.05,.65,1.6),0)
  e('eye_socket',(side*1.6,-1.0,.9),(1.43,.32,1.4),6)
  e('eye_dome',(side*1.6,-1.28,.95),(1.04,.30,1.02),0)
  pts=[(side*1.6+1.25*cos(a),-1.27,.95+1.24*sin(a)) for a in [i*2*pi/24 for i in range(25)]]
  t('eye_rim',pts,[.19]*len(pts))
  t('brow',[(side*.4,-1.35,1.65),(side*.95,-1.48,2.4),(side*2.05,-1.42,2.7),(side*3.1,-.8,2.1)],[.3,.38,.4,.14])
  t('horn',[(side*3.3,-.05,1.95),(side*4.1,-.0,3.1),(side*4.45,.12,4.25),(side*4.3,.22,5.55)],[.7,.5,.28,.015],0,10)
  t('cheek_scroll',[(side*2.4,-1.1,-.35),(side*3.8,-1.3,-.6),(side*4.2,-1.1,-1.4),(side*3.5,-1.3,-1.8),(side*3.0,-1.4,-1.4)],[.3,.36,.32,.25,.10])
  for k in range(3):t('beard_spike',[(side*(2.3+k*.65),-.6,-1.7),(side*(2.65+k*.7),-.7,-2.7+k*.3),(side*(3.0+k*.7),-.65,-2.35+k*.36)],[.35,.26,.015])
 e('nose_bridge',(0,-1.05,.40),(.75,.7,1.1),0)
 e('nose_tip',(0,-1.6,-.05),(.9,.45,.48),0)
 for side in [-1,1]:e('nostril',(side*.46,-1.96,-.05),(.21,.08,.14),14,12,6)
 e('mouth_cavity',(0,-.9,-1.35),(2.8,.46,.87),14)
 t('upper_lip',[(-2.9,-1.25,-.9),(-1.6,-1.55,-.72),(0,-1.5,-.86),(1.6,-1.55,-.72),(2.9,-1.25,-.9)],[.2,.25,.25,.25,.2])
 t('jaw',[(-3.3,-.8,-1.25),(-2.5,-1.1,-2.1),(0,-1.2,-2.5),(2.5,-1.1,-2.1),(3.3,-.8,-1.25)],[.35,.4,.45,.4,.35])
 for i in range(7):
  xx=(i-3)*.62
  box(prefix+'_upper_tooth',p((xx,-1.4,-1.0)),(.48*s,.30*s,.48*s),15,group,.04*s)
  box(prefix+'_lower_tooth',p((xx,-1.34,-1.77)),(.43*s,.28*s,.32*s),15,group,.035*s)
 for side in [-1,1]:t('fang',[(side*2.26,-1.4,-.85),(side*2.1,-1.62,-1.4),(side*1.9,-1.6,-1.56)],[.27,.16,.02],15)
 e('chin',(0,-.8,-2.4),(1.4,.38,.5),0)
for side in [-1,1]:guardian('Guardian_'+('Left' if side<0 else 'Right'),(side*20,29.3,6),1.10,'08_Guardians')
guardian('Pavilion_crest',(0,45.4,31.2),.75,'05_Pavilion')
# Non-blocking emblem medallion above the gateway passage.
ellipsoid('Martial_emblem_disc',(0,39.00,10.8),(1.6,.15,1.6),15,'06_Sign',24,12)
font=bpy.data.fonts.get('YuGothB.ttc') or bpy.data.fonts.load(r'C:\Windows\Fonts\YuGothB.ttc')
ob=text_obj('Martial_emblem_character','武',(0,38.80,9.7),2.8,1,'06_Sign',font)
pts=[(1.4*cos(i*2*pi/32),38.78,10.8+1.4*sin(i*2*pi/32)) for i in range(33)]
tube('Martial_emblem_circle',pts,.075,1,'06_Sign',6)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'Tenkaichi_Arena.blend'))
print('STANDS_GATE_COMPLETE',len(bpy.context.scene.objects))
