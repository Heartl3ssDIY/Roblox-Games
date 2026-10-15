select_asset('Upright piano')
for ob in list(COL.objects):
 if ob.type=='FONT':bpy.data.objects.remove(ob,do_unlink=True)
box('Recessed piano front panel',(0,-.181,.985),(1.32,.025,.277),'wood',.014)
for x in [-.68,.68]:box('Upper panel edge trim',(x,-.184,.987),(.024,.025,.29),'black',.006)
box('Lower panel inset',(0,-.183,.40),(1.22,.018,.49),'black',.016)
for x in [-.632,.632]:box('Lower cabinet trim',(x,-.2,.40),(.017,.019,.49),'wood',.004)
box('Keyboard red felt rail',(0,-.211,.82),(1.31,.011,.016),'pink',.003)
for x in [-.57,.57]:
 cylinder('Lid brass hinge',(x,.12,1.165),.009,.13,'brass',24).rotation_euler.y=pi/2
 for xx in [x-.036,x+.036]:screw('Hinge screw',(xx,.13,1.187),(0,0,1),.004,'brass')
for x in [-.6,.6]:
 for z in [.20,.58]:screw('Cabinet panel screw',(x,-.20,z),(0,-1,0),.004)
box('Rear soundboard',(0,.324,.70),(1.30,.024,.89),'woodlight',.004)
for x in [-.5,-.3,-.1,.1,.3,.5]:box('Soundboard vertical rib',(x,.351,.68),(.025,.035,.84),'wood',.003)
for i in range(12):
 x=-.50+i*.091;rod('Rear soundboard string',(x,.369,.25),(x+.09,.369,1.03),.0011,'brass',6)
for x in [-.11,0,.11]:
 for j in range(5):box('Pedal anti-slip groove',(x-.016+j*.008,-.381,.100),(.002,.05,.0008),'black',.0003)
select_asset('Piano bench')
for x in [-.22,0,.22]:ball('Bench tuft button',(x,0,.532),(.010,.010,.0025),'fabricdark',20,10)

select_asset('Acoustic guitar')
points=smooth_outline([(0,.07),(.13,.084),(.195,.16),(.185,.26),(.11,.33),(.149,.41),(.127,.50),(.055,.55),(0,.548),(-.055,.55),(-.127,.50),(-.149,.41),(-.11,.33),(-.185,.26),(-.195,.16),(-.13,.084)],12)
for ob in list(COL.objects):
 if any(k in ob.name for k in ['Guitar curved body','Spruce guitar top']):bpy.data.objects.remove(ob,do_unlink=True)
body=outline('Smooth bound guitar body',points,.125,'wood',rounding=.005)
for p in body.data.polygons:
 if len(p.vertices)==4:p.use_smooth=True
top=outline('Textured spruce soundboard',points,.008,'woodlight',(0,-.065,0),.002)
for y in [-.070,.063]:tube('Ivory guitar edge binding',[(x,y,z) for x,z in points],.0026,'ivory',True)
for r,m in [(.056,'ivory'),(.059,'wood'),(.062,'ivory'),(.066,'wood')]:tube('Inlaid soundhole rosette',[(r*cos(2*pi*i/96),-.082,.382+r*sin(2*pi*i/96)) for i in range(96)],.0012,m,True)
outline('Subtle dark pickguard',smooth_outline([(.042,.333),(.084,.426),(.118,.408),(.14,.338),(.098,.279)],8),.002,'rubber',(0,-.072,0),.001)
for i in range(6):
 x=-.024+i*.0096;ball('Ivory bridge pin',(x,-.094,.202),(.0024,.002,.0024),'ivory',12,8)
for side in [-1,1]:
 for i in range(3):
  z=.992+i*.041;box('Tuning machine housing',(side*.024,.024,z),(.027,.015,.023),'metal',.006)
  screw('Tuner fixing',(side*.024,.034,z),(0,1,0),.0035)
  for j in range(3):tube('Wound string at tuning post',[(side*.026+.003*cos(2*pi*k/24),-.022+.003*sin(2*pi*k/24),z+j*.0015) for k in range(24)],.00045,'silver',True)
rod('Guitar strap pin',(0,0,.073),(0,0,.058),.004,'metal',16)
box('Fingerboard nut',(0,-.037,.977),(.055,.015,.006),'ivory',.001)

select_asset('Clarinet')
for ob in COL.objects:
 if ob.type=='MESH' and any(t in ob.name for t in ['Silver','Key','key']):
  if ob.data.materials:ob.data.materials[0]=MAT['silver']
for i in range(7):
 z=.23+i*.045
 tube('Open ring key',[(.010*cos(2*pi*k/40),-.031,z+.010*sin(2*pi*k/40)) for k in range(40)],.0014,'silver',True)
 rod('Tone hole',(0,-.032,z),(0,-.034,z),.0062,'rubber',20)
 for x in [-.014,.017]:rod('Keywork post',(x,-.013,z-.012),(x,-.021,z-.012),.003,'silver',12)
for i,z in enumerate([.18,.24,.30,.44,.49,.54]):
 sign=-1 if i%2==0 else 1
 tube('Auxiliary articulated key',[(sign*.016,.005,z),(sign*.033,-.006,z+.005),(sign*.035,-.018,z+.026)],.0028,'silver')
 rod('Auxiliary key spatula',(sign*.035,-.02,z+.025),(sign*.035,-.023,z+.025),.008,'silver',20)
tube('Bell silver rim',[(.058*cos(2*pi*i/72),.058*sin(2*pi*i/72),.026) for i in range(72)],.002,'silver',True)

select_asset('Simple school laptop')
for key in [o for o in COL.objects if o.name.startswith('Key ')]:
 # Key labels remain live text; no unconfirmed branding.
 pos=key.location;label=key.name.split(' ')[1].split('.')[0];row,col=[int(v) for v in label.split('-')]
 chars=['1234567890-=','QWERTYUIOP[]','ASDFGHJKL;\'','ZXCVBNM,./  ','            ']
 ch=chars[row][col] if col<len(chars[row]) else ''
 if ch.strip():text('Key legend '+ch,ch,(pos.x,pos.y-.002,pos.z+.0026),.0065,'ivory',(0,0,0))
for side in [-1,1]:
 for i in range(12):box('Speaker perforation',(side*.164,-.027+i*.010,.024),(.002,.0035,.001),'rubber',.0004)
 for j in range(2):box('USB port',(side*.1778,-.025+j*.062,.011),(.001,.028,.007),'rubber',.002)
 screw('Case corner screw',(side*.150,-.092,.000),(0,0,-1),.0025)
rod('Headphone socket',(-.178,-.090,.012),(-.179,-.090,.012),.003,'rubber',20)
for x in [-.125,.125]:
 for y in [-.075,.078]:box('Laptop rubber foot',(x,y,-.003),(.040,.010,.005),'rubber',.003)
lid=findpart('Laptop hinge')
oldroot=ROOT;ROOT=lid
box('Display bottom trim',(0,-.009,.022),(.315,.003,.006),'rubber',.001)
for x in [-.011,.011]:ball('Camera microphone',(x,-.01,.221),(.001,.0007,.001),'rubber',12,8)
ROOT=oldroot
select_asset('Desktop monitor')
for x in [-.24,-.20,-.16,-.12,-.08,-.04,0,.04,.08,.12,.16,.20,.24]:box('Rear monitor vent',(x,.042,.485),(.020,.005,.042),'rubber',.006)
for x in [-.08,.08]:
 for z in [.33,.44]:screw('VESA mounting screw',(x,.042,z),(0,1,0),.007)
for x in [.19,.22,.25]:box('Monitor control button',(x,-.001,.197),(.017,.012,.004),'rubber',.002)
box('Monitor cable port',(0,.044,.235),(.035,.005,.015),'rubber',.003)
tube('Monitor power cable',[(0,.05,.25),(.02,.07,.20),(.02,.06,.07),(.08,.03,.025),(.19,.03,.025)],.003,'rubber')
print('Instrument construction and electronics detail complete; no school names on objects')
