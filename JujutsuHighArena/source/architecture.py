exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\JujutsuHighArena\source\common.py',encoding='utf-8').read(),'common.py','exec'))
random.seed(819)
def temple_roof(name,loc,w,d,h,group='12_Tiled_Roofs'):
 x,y,z=loc;b=Builder();rings=[]
 for sx,sy,zz in [(1.035,1.055,.8),(1,1,0),(.8,.67,h*.24),(.56,.025,h)]:
  rings.append([(x-w*sx/2,y-d*sy/2,z+zz),(x+w*sx/2,y-d*sy/2,z+zz),(x+w*sx/2,y+d*sy/2,z+zz),(x-w*sx/2,y+d*sy/2,z+zz)])
 for j in range(3):
  for i in range(4):b.face([rings[j][i],rings[j][(i+1)%4],rings[j+1][(i+1)%4],rings[j+1][i]],6)
 b.face(list(reversed(rings[0])),3);b.face(rings[-1],6);b.build(name,group)
 for edge in range(4):
  tube(name+'_Eave',[rings[0][edge],rings[0][(edge+1)%4]],.27,7,group,n=6)
  for t in np.linspace(.015,.985,max(4,int((w if edge%2==0 else d)/1.6))):
   pts=[]
   for ring in rings:
    p=Vector(ring[edge]).lerp(Vector(ring[(edge+1)%4]),float(t));p.z+=.06;pts.append(p)
   tube(name+'_Tile_Roll',pts,.1,7,group,n=5)
 tube(name+'_Ridge',[(x-w*.30,y,z+h+.3),(x+w*.30,y,z+h+.3)],.35,7,group,n=8)
 for side in [-1,1]:
  tube(name+'_Ridge_End',[(x+side*w*.28,y,z+h+.3),(x+side*w*.32,y,z+h+.6),(x+side*w*.33,y,z+h+1)],.25,7,group,n=7)
def screen_wall(name,w,d,z,h):
 b=Builder()
 # White infill and timber frame, with translucent-looking opaque shoji panels.
 for xx in np.arange(-w/2+3,w/2,6):
  if abs(xx)<4:cat=15
  else:cat=5
  b.box((xx,-d/2-.07,z+h*.54),(5.45,.2,h*.68),cat)
  for ox in [-2.75,0,2.75]:b.box((xx+ox,-d/2-.2,z+h*.54),(.16,.14,h*.70),3)
  for zz in np.arange(z+2,z+h-1,1.7):b.box((xx,-d/2-.2,zz),(5.5,.15,.13),4)
 for xx in np.linspace(-w/2,w/2,max(3,int(w/6)+1)):
  b.box((xx,-d/2-.32,z+h/2),(.55,.7,h+.3),3)
 for zz in [z+.5,z+h*.2,z+h-.1]:
  b.box((0,-d/2-.3,zz),(w+.8,.65,.45),3)
 # Side posts show through gaps between buildings.
 for yy in [-d/2,d/2]:
  for xx in [-w/2,w/2]:b.box((xx,yy,z+h/2),(.65,.65,h),3)
 b.build(name,'11_Timber_and_Screens')
def gable(name,loc,w,h):
 x,y,z=loc;v=[(x-w/2,y,z),(x+w/2,y,z),(x,y,z+h),(x-w/2,y+.35,z),(x+w/2,y+.35,z),(x,y+.35,z+h)]
 mesh(name+'_White_Gable',v,[(0,2,1),(3,4,5),(0,1,4,3),(1,2,5,4),(2,0,3,5)],5,'11_Timber_and_Screens')
 for a,b in [((x-w/2,y-.18,z),(x,y-.18,z+h)),((x,y-.18,z+h),(x+w/2,y-.18,z)),((x-w/2,y-.18,z),(x+w/2,y-.18,z))]:
  tube(name+'_Gable_Frame',[a,b],.25,3,'11_Timber_and_Screens',n=6)
 for xx in np.arange(-w/2+2,w/2,2):
  hh=h*(1-abs(xx)/(w/2))
  box(name+'_Gable_Post',(x+xx,y-.18,z+hh/2),(.18,.22,max(.1,hh)),3,'11_Timber_and_Screens')
def hall(name,loc,w,d,h,angle=0,main=False):
 before=set(bpy.data.objects);x,y,z=loc
 box(name+'_Stone_Base',(0,0,z+.75),(w+3,d+5,1.5),2,'10_Hall_Bodies')
 box(name+'_Plaster',(0,0,z+1.5+h/2),(w,d,h),5,'10_Hall_Bodies')
 box(name+'_Veranda',(0,-d/2-2,z+1.55),(w+3,4,.5),4,'11_Timber_and_Screens')
 # Simple parallel wood planks across the veranda.
 b=Builder()
 for xx in np.arange(-w/2,w/2,2):
  b.box((xx,-d/2-2,z+1.82),(.04,3.9,.02),3)
 b.build(name+'_Veranda_Planks','11_Timber_and_Screens')
 screen_wall(name+'_Screens',w,d,z+1.5,h)
 for xx in np.linspace(-w/2+1,w/2-1,max(4,int(w/7))):
  box(name+'_Porch_Post',(xx,-d/2-3,z+1.5+h/2),(.48,.48,h),3,'11_Timber_and_Screens')
  box(name+'_Bracket',(xx,-d/2-3,z+h+.8),(1.7,1.2,.45),4,'11_Timber_and_Screens')
 temple_roof(name+'_Roof',(0,0,z+h+1.7),w+9,d+11,h*.48+2)
 if main:
  gable(name,(0,-(d+11)/2-.25,z+h+2.6),24,8)
  # Three split purple entrance curtains under the central gable.
  for xx in [-4.2,0,4.2]:
   box(name+'_Noren',(xx,-d/2-3.12,z+h-1),(4,.12,3),13,'13_Shrine_Details')
  for xx in [-4.2,4.2]:
   lathe_ob=None
   tube(name+'_Curtain_Crest',[(xx+.5*cos(a),-d/2-3.21,z+h-1+.5*sin(a)) for a in np.linspace(0,2*pi,17)],.055,14,'13_Shrine_Details',n=5)
  for j in range(4):box(name+'_Step',(0,-d/2-6+j,z+.2+j*.38),(25,1.3,.4),2,'14_Stairs')
 trans=Matrix.Translation((x,y,0))@Matrix.Rotation(angle,4,'Z')
 for ob in bpy.data.objects:
  if ob not in before:ob.matrix_world=trans@ob.matrix_world
 BUILDING_BOUNDS.append({'name':name,'x':x,'y':y,'z':z,'w':w+3,'d':d+5,'h':h+3,'angle':angle})
