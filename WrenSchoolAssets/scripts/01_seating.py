def chair_legs(w=.44,d=.43,h=.45,material='black'):
 for x in [-1,1]:
  for y in [-1,1]:
   a=(x*w*.55,y*d*.53,.025);b=(x*w*.40,y*d*.40,h)
   rod('Splayed tubular leg',a,b,.018,material);cylinder('Rubber foot',a,.021,.03,'rubber',12)
def shell_back(w,zlow,zhigh,material='sand'):
 vs=[];nx=12
 for side in [-1,1]:
  for z in [zlow,zhigh]:
   for j in range(nx+1):
    x=w*(j/nx-.5);y=.19-.065*(2*x/w)**2+.10*(z-zlow)
    vs.append((x,y+side*.016,z-.025*(abs(2*x/w)**6 if z==zhigh else 0)))
 stride=nx+1;fs=[]
 for j in range(nx):
  fs.extend([(j,j+1,stride+j+1,stride+j),(2*stride+j,3*stride+j,3*stride+j+1,2*stride+j+1),(j,2*stride+j,2*stride+j+1,j+1),(stride+j,stride+j+1,3*stride+j+1,3*stride+j)])
 fs.extend([(0,stride,3*stride,2*stride),(nx,2*stride-1,4*stride-1,3*stride-1)])
 o=mesh('Curved ergonomic back shell',vs,fs,material,smooth=True);bevel(o,.014,3)
 return o
def back_posts(top=.82):
 for x in [-.17,.17]:rod('Back support',(x,.16,.40),(x,.215,top),.013,'black')
def star_base(h=.45,radius=.31):
 cylinder('Gas lift',(0,0,h*.5),.028,h-.08,'metal',20)
 cylinder('Lift shroud',(0,0,.16),.049,.20,'black',20)
 for i in range(5):
  a=2*pi*i/5
  p=(radius*cos(a),radius*sin(a),.07);rod('Five-star spoke',(0,0,.14),p,.024,'black')
  ball('Twin caster',p,(.045,.035,.042),'rubber',12,8)

asset('Student 01 - Maths stack chair','02 Student seating',(0,4,0))
chair_legs();box('Moulded seat',(0,0,.475),(.46,.445,.055),'sand',.025);back_posts();shell_back(.45,.57,.89,'sand')
for x in [-.2,.2]:box('Stack bumper',(x,0,.425),(.035,.11,.022),'rubber',.008)

asset('Student 02 - Science lab stool','02 Student seating',(1.5,4,0))
cylinder('Rounded ash stool seat',(0,0,.69),.245,.055,'woodlight',40);bevel(bpy.context.scene.objects.get('Rounded ash stool seat') or ROOT.children[-1],.015)
for i in range(4):
 a=pi/4+i*pi/2;rod('Stool leg',(.255*cos(a),.255*sin(a),.025),(.17*cos(a),.17*sin(a),.67),.021,'black')
 cylinder('Stool foot',(.255*cos(a),.255*sin(a),.022),.024,.035,'rubber',12)
tube('Circular foot rail',[(.23*cos(2*pi*i/48),.23*sin(2*pi*i/48),.24) for i in range(48)],.012,'black',True)

asset('Student 03 - Technology swivel chair','02 Student seating',(3,4,0))
star_base(.47,.29);box('Moulded seat',(0,0,.5),(.46,.43,.065),'taupe',.03);back_posts(.84);shell_back(.425,.59,.91,'taupe')
rod('Adjustment lever',(.10,0,.43),(.28,-.03,.43),.009,'black');box('Lever grip',(.28,-.03,.43),(.08,.045,.02),'rubber',.008)

asset('Student 04 - Art cantilever chair','02 Student seating',(4.5,4,0))
for x in [-.215,.215]:
 tube('Continuous sled frame',[(x,.24,.035),(x,-.22,.035),(x,-.265,.075),(x,-.26,.40),(x,-.22,.45),(x,.15,.45),(x,.205,.71)],.021,'black')
 box('Floor glide',(x,-.12,.022),(.045,.14,.028),'rubber',.01)
rod('Rear cross brace',(-.215,.23,.035),(.215,.23,.035),.018,'black')
box('Ivory moulded seat',(0,0,.482),(.47,.455,.055),'ivory',.026);shell_back(.455,.56,.89,'ivory')

asset('Student 05 - Music posture chair','02 Student seating',(6,4,0))
chair_legs(.47,.46,.45);box('Upholstered seat',(0,0,.49),(.49,.46,.09),'fabricdark',.04)
back_posts(.90);back=box('Upright padded back',(0,.215,.77),(.46,.075,.31),'fabricdark',.035);back.rotation_euler.x=-.07
for x in [-.20,.20]:cylinder('Back fixing',(x,.26,.79),.012,.014,'metal',12).rotation_euler.x=pi/2

asset('Staff 01 - Task chair','03 Staff seating',(8,4,0))
star_base(.43,.36);box('Plush seat cushion',(0,0,.48),(.56,.54,.13),'fabric',.05)
rod('Back spine',(0,.19,.35),(0,.27,.98),.045,'black')
b=box('High upholstered back',(0,.27,.88),(.54,.12,.65),'fabric',.055);b.rotation_euler.x=-.10
box('Lumbar pad',(0,.185,.75),(.43,.07,.16),'fabricdark',.025)
for x in [-.32,.32]:
 rod('Arm riser',(x,0,.42),(x,.035,.67),.021,'black')
 box('Soft armrest',(x,-.01,.685),(.075,.35,.055),'taupe',.025)

asset('Staff 02 - Curved tub chair','03 Staff seating',(10,4,0))
box('Tub seat base',(0,0,.32),(.77,.69,.41),'fabricdark',.15)
box('Loose seat cushion',(0,-.03,.49),(.62,.59,.12),'fabric',.055)
vs=[];n=28
for rad,zmode in [(.43,0),(.33,0),(.43,1),(.33,1)]:
 for j in range(n+1):
  a=-.12+(pi+.24)*j/n;z=.25 if zmode==0 else .67+.20*max(0,sin(a));vs.append((rad*cos(a),rad*sin(a)-.01,z))
k=n+1;fs=[]
for j in range(n):
 fs.extend([(j,j+1,2*k+j+1,2*k+j),(k+j,3*k+j,3*k+j+1,k+j+1),(2*k+j,2*k+j+1,3*k+j+1,3*k+j),(j,k+j,k+j+1,j+1)])
fs.extend([(0,2*k,3*k,k),(n,k+n,3*k+n,2*k+n)])
o=mesh('Wraparound upholstered arms and back',vs,fs,'fabricdark',smooth=True);bevel(o,.035)
for x in [-.27,.27]:
 for y in [-.23,.23]:cylinder('Short oak foot',(x,y,.095),.042,.19,'wood',12)

asset('Staff 03 - Low lounge armchair','03 Staff seating',(12,4,0))
for x in [-.34,.34]:
 for y in [-.28,.28]:rod('Angled ash leg',(x*1.1,y*1.15,.025),(x,y,.48),.034,'woodlight')
 box('Oak armrest',(x,0,.61),(.075,.71,.065),'woodlight',.027)
 rod('Arm support',(x,-.23,.30),(x,-.23,.60),.024,'woodlight')
seat=box('Deep lounge cushion',(0,-.03,.40),(.63,.66,.17),'ivory',.065);seat.rotation_euler.x=.035
b=box('Reclined lounge back',(0,.30,.68),(.64,.16,.58),'fabric',.065);b.rotation_euler.x=-.18
print('Created eight seating designs')
