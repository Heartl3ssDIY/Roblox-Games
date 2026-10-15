def pencil_at(name,loc,rot=(0,0,0),pen=False):
 global ROOT
 parent=ROOT;o=bpy.data.objects.new(name,None);COL.objects.link(o);o.parent=parent;o.location=loc;o.rotation_euler=rot;ROOT=o
 if not pen:
  cylinder('Hexagonal black lacquer',(0,0,.103),.0046,.146,'black',6)
  cylinder('Sharpened cedar',(0,0,.018),.0046,.024,'woodlight',6,r2=.0009).rotation_euler.x=pi
  cylinder('Graphite tip',(0,0,.004),.0012,.008,'rubber',6,r2=0).rotation_euler.x=pi
  cylinder('Silver eraser ferrule',(0,0,.181),.0049,.013,'metal',12)
  for z in [.177,.180,.183]:cylinder('Ferrule ridge',(0,0,z),.00505,.0008,'metal',12)
  e=cylinder('Pink eraser',(0,0,.192),.0048,.012,'pink',12);bevel(e,.0012,2)
 else:
  cylinder('Pen barrel',(0,0,.075),.0052,.115,'black',16)
  cylinder('Brushed tip',(0,0,.012),.0047,.012,'metal',16,r2=.0007).rotation_euler.x=pi
  cylinder('Writing nib',(0,0,.003),.0008,.006,'black',10)
  cylinder('Click button',(0,0,.14),.0036,.009,'metal',16)
  box('Pocket clip',(0,-.006,.117),(.0023,.002,.033),'metal',.0008)
  for z in [.035,.039,.043]:cylinder('Grip ring',(0,0,z),.0055,.001,'rubber',16)
 ROOT=parent
 return o

ROOT=None;COL=STAGE
box('Stationery review pedestal',(.65,0,.36),(1.65,.90,.72),'plinth',.045)
asset('Black pencil - pink eraser','01 Stationery',(.03,-.22,.727));pencil_at('Pencil',(0,0,.006),(pi/2,0,-.32))
asset('Black retractable pen','01 Stationery',(.17,-.22,.727));pencil_at('Pen',(0,0,.006),(pi/2,0,-.32),True)
asset('Round graphite pencil pot','01 Stationery',(.56,.04,.723))
lathe('Hollow pencil pot',[(0,0),(.064,0),(.07,.007),(.07,.11),(.067,.117),(.060,.117),(.058,.108),(.058,.012),(0,.012)],'black',n=40)
for i in range(20):
 a=2*pi*i/20;rod('Raised pot rib',(.070*cos(a),.070*sin(a),.015),(.070*cos(a),.070*sin(a),.10),.0011,'taupe',6)
for i in range(5):
 a=2*pi*i/5;pencil_at('Pencil in pot',(.026*cos(a),.026*sin(a),.014),(.13*cos(a),.13*sin(a),a),False)
asset('Square ivory pen pot','01 Stationery',(.92,.05,.723))
box('Pot base',(0,0,.009),(.13,.13,.018),'ivory',.008)
for x in [-.058,.058]:box('Pot side',(x,0,.061),(.014,.13,.12),'ivory',.006)
for y in [-.058,.058]:box('Pot side',(0,y,.061),(.106,.014,.12),'ivory',.006)
for i in range(4):pencil_at('Pen in pot',(-.024+i*.016,0,.018),(0,.08*(i-1.5),0),True)
asset('Whiteboard marker and eraser','01 Stationery',(1.20,-.15,.728))
cylinder('Marker barrel',(0,0,.012),.009,.115,'ivory',16).rotation_euler.x=pi/2
cylinder('Marker cap',(0,-.065,.012),.01,.03,'black',16).rotation_euler.x=pi/2
box('Whiteboard eraser',(0,.12,.026),(.10,.055,.037),'black',.012);box('Felt pad',(0,.12,.004),(.096,.052,.008),'rubber',.003)

asset('Simple school laptop','05 Technology',(8,8,.74))
box('Rounded laptop base',(0,0,.011),(.355,.245,.022),'black',.009)
box('Keyboard recess',(0,.025,.024),(.311,.124,.004),'rubber',.008)
for row in range(5):
 for col in range(12):
  box('Key %02d-%02d'%(row,col),(-.14+col*.0255,-.018+row*.021,.028),(.021,.016,.004),'taupe',.002)
box('Spacebar',(0,-.043,.028),(.125,.015,.004),'taupe',.002)
box('Trackpad',(0,-.083,.024),(.10,.050,.003),'metal',.004)
lid=bpy.data.objects.new('Laptop hinge — adjustable',None);COL.objects.link(lid);lid.parent=ROOT;lid.location=(0,.11,.027);lid.rotation_euler.x=-.20
save=ROOT;ROOT=lid
box('Screen lid',(0,0,.117),(.355,.014,.234),'black',.009)
box('Laptop display',(0,-.008,.122),(.325,.002,.197),'screen',.004)
ball('Webcam',(0,-.009,.221),(.002,.001,.002),'rubber',10,6)
text('Laptop wordmark','WREN',(0,-.009,.013),.009,'ivory')
ROOT=save
for x in [-.13,.13]:cylinder('Hinge barrel',(x,.103,.025),.009,.06,'metal',16).rotation_euler.y=pi/2
asset('Desktop monitor','05 Technology',(9.2,8,.74))
box('Monitor foot',(0,0,.014),(.27,.20,.027),'black',.017)
box('Monitor neck',(0,.045,.16),(.065,.045,.29),'metal',.01)
box('Rounded monitor housing',(0,.02,.38),(.61,.038,.37),'black',.018)
box('Monitor display',(0,-.001,.387),(.578,.006,.326),'screen',.009)
text('Monitor brand','WREN',(0,-.007,.211),.013,'ivory')
ball('Power indicator',(.271,-.006,.217),(.003,.002,.003),'leaflight',8,6)
asset('Compact desktop keyboard and mouse','05 Technology',(9.2,7.60,.742))
box('Keyboard body',(0,0,.012),(.39,.135,.022),'black',.009)
for row in range(4):
 for col in range(14):box('Keyboard key',(-.171+col*.0263,-.045+row*.029,.026),(.022,.024,.005),'taupe',.002)
box('Keyboard space bar',(0,-.05,.030),(.11,.022,.004),'black',.002)
ball('Mouse',(.29,0,.019),(.032,.055,.024),'black',20,12)
box('Mouse centre seam',(.29,-.010,.041),(.0018,.050,.001),'rubber',.0005)
ROOT=None;COL=STAGE
box('Technology review pedestal',(8.7,8,.36),(2.3,1.40,.72),'plinth',.04)
print('Stationery and technology models created')
