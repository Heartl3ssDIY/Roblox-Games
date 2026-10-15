rich_material('ceramic','#D6C7AF','ceramic',.23,0)
for fragment,w,d,h in [('Tall double',.94,.50,1.86),('Low staffroom cupboard',1.45,.50,.84)]:
 select_asset(fragment);old=findpart('Cupboard carcass');bpy.data.objects.remove(old,do_unlink=True)
 for x in [-w/2+.014,w/2-.014]:box('Veneered cabinet side',(x,0,h/2+.04),(.028,d,h-.08),'wood',.006)
 box('Cabinet back panel',(0,d/2-.009,h/2),(w-.05,.018,h-.11),'woodlight',.003)
 for z in [.11,h-.025]:box('Cabinet horizontal panel',(0,0,z),(w-.045,d,.025),'wood',.004)
 heights=[.51,.93,1.36] if h>1 else [.44]
 for z in heights:
  box('Adjustable oak shelf',(0,.005,z),(w-.059,d-.055,.026),'woodlight',.005)
  for x in [-w/2+.04,w/2-.04]:
   for y in [-.14,.16]:rod('Shelf support pin',(x,y,z-.025),(x,y,z-.007),.004,'metal',12)
 for x in [-w/2+.018,w/2-.018]:
  for z in [h*.22,h*.76]:
   box('Concealed hinge plate',(x,-.212,z),(.023,.070,.045),'metal',.003)
   cylinder('Cabinet hinge barrel',(x,-.247,z),.007,.048,'metal',16)
 if h>1:
  hinge=bpy.data.objects.new('Right door hinge — editable',None);COL.objects.link(hinge);hinge.parent=ROOT;hinge.location=(.451,-.266,.93)
  for ob in list(COL.objects):
   if ob.parent==ROOT and ob!=hinge and ob.location.x>0 and any(k in ob.name for k in ['Flat sand cabinet door','Slim vertical handle','Handle fixing']):ob.parent=hinge;ob.location-=hinge.location
  hinge.rotation_euler.z=.32
  # Low-key storage inside, visible through the open door.
  for i in range(5):
   x=-.22+i*.082;box('Neutral archive folder',(x,.06,.72),(.061,.25,.37),['taupe','ivory','sand'][i%3],.006)
   box('Folder spine label',(x,-.068,.78),(.036,.003,.09),'ivory',.002)
for record in [r for r in ASSETS if r['category']=='06 Storage']:
 select_asset(record['name'])
 for ob in [o for o in COL.objects if 'Tray front' in o.name]:
  x,y,z=ob.location;box('Inset tray finger grip',(x,y-.012,z+.027),(.10,.006,.020),'black',.009)
 for ob in [o for o in COL.objects if 'Tray label' in o.name]:
  ob.location.z-=.016;ob.scale.z=.60

select_asset('Graphite electric kettle')
tube('Kettle lid seam',[(.084*cos(2*pi*i/96),.084*sin(2*pi*i/96),.25) for i in range(96)],.0013,'rubber',True)
tube('Lid steel trim',[(.079*cos(2*pi*i/96),.079*sin(2*pi*i/96),.26) for i in range(96)],.0011,'metal',True)
tube('Detachable base cord',[(.04,.10,.016),(.08,.18,.008),(.17,.22,.006),(.25,.20,.006),(.28,.13,.006),(.25,.08,.007)],.0035,'rubber')
box('Kettle power plug',(.255,.059,.014),(.039,.043,.024),'black',.008)
for x in [.248,.262]:rod('Plug contact',(x,.038,.014),(x,.025,.014),.0025,'metal',8)
for i in range(5):
 z=.106+i*.021;text('Water measurement',str(250+i*250),(0,-.122,z),.006,'ivory')
for x,y in [(-.05,-.05),(.05,-.05),(0,.06)]:screw('Base screw',(x,y,.001),(0,0,-1),.004)

for fragment in ['Ivory staff mug','Graphite staff mug','Cup and saucer']:
 select_asset(fragment)
 for ob in COL.objects:
  if ob.type in ['MESH','CURVE'] and ob.data.materials and ob.data.materials[0]==MAT['ivory']:ob.data.materials[0]=MAT['ceramic']
 if 'staff mug' in fragment:
  m='ceramic' if 'Ivory' in fragment else 'black'
  tube('Rolled glazed mug lip',[(.039*cos(2*pi*i/96),.039*sin(2*pi*i/96),.098) for i in range(96)],.0028,m,True)
  lathe('Unglazed mug foot',[(.027,.001),(.028,.003),(.033,.003),(.034,.001)],'ivory',n=48)
select_asset('Takeaway coffee cup')
tube('Lid raised drinking rim',[(.036*cos(2*pi*i/96),.036*sin(2*pi*i/96),.140) for i in range(96)],.0015,'black',True)
box('Lid drinking opening',(0,-.027,.144),(.014,.006,.001),'rubber',.0025)
for i in range(50):
 a=2*pi*i/50;rod('Sleeve corrugation',(.034*cos(a),.034*sin(a),.041),(.041*cos(a),.041*sin(a),.087),.00055,'taupe',5)

for fragment in ['mobile whiteboard','TV teaching board']:
 select_asset(fragment)
 frame=findpart('board frame') if 'whiteboard' in fragment else findpart('TV rounded enclosure')
 w=2.43 if 'whiteboard' in fragment else 2.20
 for x in [-w*.5+.09,w*.5-.09]:
  for z in [.91,2.22 if 'whiteboard' in fragment else 2.17]:screw('Frame recessed fastener',(x,-.066,z),(0,-1,0),.006)
 for x in [-.86,.86] if 'whiteboard' in fragment else [-.66,.66]:
  cylinder('Height adjustment collar',(x,.045,.64),.045,.065,'black',32)
  rod('Height adjustment lock',(x,.012,.64),(x,-.035,.64),.010,'metal',16)
  cylinder('Adjustment hand knob',(x,-.04,.64),.023,.021,'black',20).rotation_euler.x=pi/2
  for y in [-.29,.38] if 'whiteboard' in fragment else [-.26,.28]:
   box('Wheel brake lever',(x,y-.018,.098),(.038,.054,.008),'metal',.004)
 if 'whiteboard' in fragment:
  for x in [-.43,-.25,-.07]:
   cylinder('Small board magnet',(x,-.103,2.16),.014,.012,'taupe',24).rotation_euler.x=pi/2
  for i in range(10):box('Eraser grip rib',(.69+i*.010,-.112,1.17),(.003,.003,.056),'black',.001)
 else:
  for i in range(25):box('TV rear cooling vent',(-.83+i*.07,.064,1.99),(.038,.008,.10),'rubber',.005)
  box('TV I-O recess',(.60,.066,1.18),(.22,.008,.14),'rubber',.009)
  for x in [.54,.59,.64]:box('HDMI input',(x,.073,1.19),(.034,.006,.015),'metal',.003)
  tube('TV power cable',[(.68,.08,1.18),(.68,.09,.85),(.66,.11,.40),(.5,.14,.07)],.006,'rubber')

for fragment in ['Black pencil','Black retractable pen','Round graphite pencil pot','Square ivory pen pot']:
 select_asset(fragment)
 for ob in list(COL.objects):
  if ob.type=='EMPTY' and ('Pencil' in ob.name or 'Pen' in ob.name):
   oldroot=ROOT;ROOT=ob
   if 'Pencil' in ob.name:text('Pencil grade','HB',(0,-.0047,.09),.0042,'ivory',(pi/2,0,0))
   else:
    for z in [.065,.08,.095]:tube('Subtle pen barrel ring',[(.00525*cos(2*pi*i/32),.00525*sin(2*pi*i/32),z) for i in range(32)],.00020,'metal',True)
   ROOT=oldroot
print('Cabinets now have interiors and hinges; kettle, cup, stationery and board fittings added')
