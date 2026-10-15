asset('Upright piano','04 Music',(0,8,0))
box('Piano lower cabinet',(0,.07,.37),(1.48,.49,.70),'black',.028)
box('Piano soundboard cabinet',(0,.14,.90),(1.48,.38,.53),'black',.025)
box('Smoked oak top lid',(0,.10,1.18),(1.53,.52,.047),'wood',.019)
for x in [-.724,.724]:
 box('Oak side cheek',(x,-.14,.76),(.075,.56,.13),'wood',.024)
 box('Piano front leg',(x,-.35,.32),(.095,.10,.60),'black',.021)
 cylinder('Piano foot glide',(x,-.35,.021),.053,.034,'rubber',12)
box('Keyboard bed',(0,-.30,.745),(1.42,.37,.05),'black',.014)
keyw=1.29/52
for i in range(52):
 x=-1.29/2+keyw*(i+.5);box('Ivory piano key %02d'%i,(x,-.34,.789),(keyw-.0011,.25,.038),'white',.002)
 if i<51 and i%7 in [0,2,3,5,6]:box('Black piano key %02d'%i,(x+keyw*.5,-.277,.819),(keyw*.61,.13,.034),'rubber',.002)
box('Keyboard front lip',(0,-.483,.76),(1.42,.025,.065),'wood',.009)
text('Piano maker','W R E N',(0,-.057,1.04),.048,'brass')
box('Music ledge',(0,-.08,.90),(.66,.10,.025),'wood',.007)
for x in [-.11,0,.11]:
 rod('Pedal stem',(x,-.16,.14),(x,-.34,.09),.014,'brass')
 box('Piano pedal',(x,-.36,.087),(.046,.12,.025),'brass',.011)
asset('Piano bench','04 Music',(0,7.08,0))
box('Upholstered piano bench',(0,0,.48),(.72,.34,.10),'fabricdark',.034)
box('Bench oak apron',(0,0,.40),(.67,.29,.065),'wood',.014)
for x in [-.28,.28]:
 for y in [-.11,.11]:box('Bench leg',(x,y,.205),(.045,.045,.40),'black',.008)

def smooth_outline(points,steps=4):
 result=[]
 for i in range(len(points)):
  p0=Vector(points[(i-1)%len(points)]);p1=Vector(points[i]);p2=Vector(points[(i+1)%len(points)]);p3=Vector(points[(i+2)%len(points)])
  for k in range(steps):
   t=k/steps;p=.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t);result.append(tuple(p))
 return result
asset('Acoustic guitar and stand','04 Music',(2.1,8,0))
pts=smooth_outline([(0,.07),(.13,.084),(.195,.16),(.185,.26),(.11,.33),(.149,.41),(.127,.50),(.055,.55),(0,.548),(-.055,.55),(-.127,.50),(-.149,.41),(-.11,.33),(-.185,.26),(-.195,.16),(-.13,.084)])
outline('Guitar curved body',pts,.125,'wood',rounding=.008)
outline('Spruce guitar top',pts,.008,'woodlight',(0,-.065,0),.003)
rod('Soundhole rosette',(0,-.074,.382),(0,-.079,.382),.063,'brass',40)
rod('Dark soundhole',(0,-.08,.382),(0,-.081,.382),.055,'rubber',40)
box('Guitar neck',(0,0,.756),(.049,.045,.43),'wood',.008)
box('Fingerboard',(0,-.029,.756),(.051,.012,.43),'rubber',.003)
head=box('Headstock',(0,.003,1.035),(.071,.04,.145),'wood',.016);head.rotation_euler.x=-.09
box('Bridge',(0,-.079,.214),(.143,.020,.031),'wood',.006)
box('Bridge saddle',(0,-.092,.223),(.102,.010,.008),'ivory',.002)
for i in range(18):
 z=.96-.43*(1-2**(-i/12));rod('Fret',(-.025,-.037,z),(.025,-.037,z),.0012,'metal',8)
for x in [-.018,-.0108,-.0036,.0036,.0108,.018]:rod('Guitar string',(x,-.096,.22),(x,-.039,1.075),.00062,'metal',6)
for i in range(3):
 for side in [-1,1]:
  rod('Tuning post',(side*.027,0,.992+i*.041),(side*.045,0,.992+i*.041),.004,'metal',10)
  ball('Tuning peg',(side*.052,0,.992+i*.041),(.009,.006,.011),'metal',12,8)
for z in [.78,.865,.919]:ball('Fret marker',(0,-.037,z),(.003,.001,.003),'ivory',8,6)
rod('Guitar stand upright',(0,.14,.05),(0,.14,.61),.015,'black')
for side in [-1,1]:
 rod('Guitar stand foot',(0,.14,.055),(side*.21,-.02,.025),.014,'black')
 tube('Padded guitar cradle',[(side*.12,.12,.12),(side*.12,-.02,.12),(side*.12,-.08,.17)],.012,'rubber')

asset('Clarinet and stand','04 Music',(3.25,8,0))
lathe('Clarinet bell',[(.012,.12),(.017,.11),(.025,.075),(.052,.025),(.057,.022),(.060,.034),(.047,.050),(.032,.085),(.026,.14)],'black',n=32)
lathe('Clarinet lower joint',[(0,.13),(.023,.13),(.025,.18),(.022,.41),(0,.41)],'black',n=24)
lathe('Clarinet upper joint',[(0,.41),(.021,.41),(.019,.60),(0,.60)],'black',n=24)
lathe('Clarinet barrel',[(0,.60),(.025,.60),(.026,.62),(.021,.66),(0,.66)],'black',n=24)
mouth=outline('Clarinet mouthpiece',[(-.02,.65),(.02,.65),(.019,.70),(.010,.746),(-.007,.746),(-.018,.70)],.030,'rubber',rounding=.003)
for z,r in [(.132,.024),(.39,.023),(.41,.023),(.60,.026),(.655,.023)]:cylinder('Silver joint ring',(0,0,z),r,.009,'metal',24)
for i in range(9):
 z=.18+i*.043;rod('Silver key cup',(0,-.020,z),(0,-.030,z),.009,'metal',16)
 rod('Key hinge',(.024,-.005,z-.009),(.024,-.005,z+.012),.0025,'metal',8)
 rod('Key arm',(.022,-.006,z),(0,-.026,z),.0025,'metal',8)
rod('Long silver key rod',(.026,0,.15),(.026,0,.55),.0028,'metal',8)
for z in [.68,.692]:cylinder('Mouthpiece ligature',(0,0,z),.021,.005,'brass',24)
box('Reed',(0,-.017,.72),(.010,.002,.038),'woodlight',.001)
cylinder('Clarinet stand foot',(0,.04,.015),.105,.024,'black',32)
rod('Clarinet support',(0,.044,.016),(0,.044,.15),.011,'black')
print('Piano, bench, acoustic guitar and clarinet completed')
