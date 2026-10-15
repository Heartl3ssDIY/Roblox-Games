def plant_pot(r=.19,h=.32,material='taupe'):
 lathe('Tapered planter',[(0,0),(r*.75,0),(r,.94*h),(r,.99*h),(r*.90,h),(r*.86,.95*h),(r*.69,.05),(0,.05)],material,n=32)
 cylinder('Visible potting soil',(0,0,h*.87),r*.85,.015,'soil',28)
asset('Indoor broadleaf plant','09 Indoor plants',(8,16,0))
plant_pot(.21,.34,'ivory')
rod('Main stem',(0,0,.28),(.015,.025,1.20),.016,'bark',12,r2=.006)
for i in range(14):
 a=i*2.399;z=.44+i*.052;start=(0,0,z);end=(.32*cos(a),.32*sin(a),z+.21)
 rod('Leaf petiole',start,(end[0]*.42,end[1]*.42,z+.10),.006,'leafdark',8)
 leaf('Broad waxy leaf',(end[0]*.30,end[1]*.30,z+.07),end,.115,['leaf','leaflight','leafdark'][i%3])

asset('Indoor snake plant','09 Indoor plants',(9.2,16,0))
plant_pot(.18,.29,'black')
for i in range(11):
 a=i*2.399;r=.025+(i%3)*.028;h=.40+(i%4)*.105
 start=Vector((r*cos(a),r*sin(a),.25));end=start+Vector((.11*cos(a),.11*sin(a),h));side=Vector((-sin(a),cos(a),0))*.035
 mid=start+(end-start)*.53
 o=mesh('Upright sculpted leaf',[tuple(start-side*.45),tuple(start+side*.45),tuple(mid+side),tuple(end),tuple(mid-side),tuple(mid+Vector((0,-.012,0)))],[(0,1,5),(1,2,5),(2,3,5),(3,4,5),(4,0,5)],'leaflight' if i%3==0 else 'leaf',smooth=True)
 rod('Leaf centre stripe',tuple(start),tuple(end),.0018,'leaflight',6)

asset('Outdoor shrub planter','10 Outdoors',(8,20,0))
box('Stone planter',(0,0,.24),(1.75,.57,.48),'taupe',.055)
box('Recessed soil',(0,0,.477),(1.57,.40,.025),'soil',.02)
for k,x in enumerate([-.58,0,.58]):
 for i in range(5):
  a=2*pi*i/5;ball('Dense rounded shrub',(x+.11*cos(a),.065*sin(a),.66+(i%2)*.055),(.30,.23,.24),['leaf','leafdark','leaflight'][(i+k)%3],12,8)

asset('Outdoor round shrub','10 Outdoors',(10.1,20,0))
for i in range(7):
 a=2*pi*i/7;ball('Low shrub crown',(.19*cos(a),.15*sin(a),.27+(i%2)*.08),(.33,.30,.27),['leaf','leafdark','leaflight'][i%3],12,8)
rod('Shrub stem',(0,0,0),(0,0,.32),.04,'bark',10)

asset('Broadleaf school tree','10 Outdoors',(0,21,0))
rod('Tapered trunk',(0,0,0),(.04,0,2.8),.14,'bark',12,r2=.055)
for i in range(5):
 a=2*pi*i/5;end=(.69*cos(a),.69*sin(a),2.3+(i%2)*.35)
 rod('Tree branch',(0,0,1.5),end,.055,'bark',10,r2=.018)
 ball('Sculpted leafy crown',end,(.79,.66,.91),['leaf','leaflight','leafdark'][i%3],12,10)
ball('Top leafy crown',(.03,0,3.08),(.68,.64,.84),'leaf',12,10)

asset('Evergreen school tree','10 Outdoors',(3.1,21,0))
rod('Evergreen trunk',(0,0,0),(0,0,3.5),.115,'bark',12,r2=.025)
for r,z,h in [(1.05,.75,1.40),(.87,1.45,1.30),(.64,2.10,1.2),(.41,2.78,1.00)]:
 lathe('Layered evergreen canopy',[(0,z),(r*.85,z),(r,z+.13),(r*.63,z+h*.40),(r*.24,z+h*.76),(0,z+h)],'leafdark' if r>.8 else 'leaf',n=12,smooth=False)

def bench_frame(length=1.8,back=True):
 for x in [-length*.37,length*.37]:
  for y in [-.20,.20]:rod('Bench splayed leg',(x,y*1.25,.025),(x,y,.45),.035,'black')
  rod('Bench side rail',(x,-.25,.40),(x,.25,.40),.028,'black')
  if back:rod('Bench back upright',(x,.19,.35),(x,.34,.94),.028,'black')
 rod('Underseat crossbar',(-length*.37,0,.27),(length*.37,0,.27),.024,'black')
 for i in range(5):box('Ash seat slat',(0,-.23+i*.115,.468),(length,.103,.055),'woodlight',.009)
 if back:
  for i in range(4):
   z=.62+i*.10;y=.23+(z-.50)*.24;b=box('Ash back slat',(0,y,z),(length,.055,.085),'woodlight',.008);b.rotation_euler.x=-.235
  for x in [-length*.44,length*.44]:
   rod('Arm support',(x,-.16,.44),(x,-.16,.66),.024,'black')
   box('Rounded bench arm',(x,0,.68),(.073,.50,.055),'black',.024)
asset('Outdoor backed bench','10 Outdoors',(5.8,21,0));bench_frame(1.85,True)
asset('Outdoor backless bench','10 Outdoors',(5.8,19.4,0));bench_frame(1.65,False)
print('Indoor plants, outdoor shrubs, two trees and two benches completed')
