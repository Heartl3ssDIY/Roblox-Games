def cabinet_shell(w,d,h):
 box('Cupboard carcass',(0,0,h*.5),(w,d,h),'wood',.022)
 box('Recessed plinth',(0,0,.055),(w-.10,d-.08,.11),'black',.01)
def cabinet_door(x,width,h):
 box('Flat sand cabinet door',(x,-.266,h*.5+.065),(width,.04,h-.13),'taupe',.016)
 hx=x+(-1 if x>0 else 1)*(width*.5-.07)
 rod('Slim vertical handle',(hx,-.304,h*.5-.04),(hx,-.304,h*.5+.14),.010,'black')
 for z in [h*.5-.03,h*.5+.13]:rod('Handle fixing',(hx,-.277,z),(hx,-.308,z),.005,'black')
asset('Tall double cupboard','06 Storage',(0,12,0))
cabinet_shell(.94,.50,1.86)
cabinet_door(-.228,.444,1.86);cabinet_door(.228,.444,1.86)
box('Top ash trim',(0,0,1.87),(.97,.53,.035),'woodlight',.012)

asset('Low staffroom cupboard','06 Storage',(1.9,12,0))
cabinet_shell(1.45,.50,.84)
for x in [-.474,0,.474]:
 box('Lower cabinet door',(x,-.266,.44),(.46,.04,.72),'taupe',.014)
 rod('Horizontal pull',(x-.10,-.302,.71),(x+.10,-.302,.71),.009,'black')
box('Ash worktop',(0,-.01,.873),(1.51,.57,.055),'woodlight',.018)

asset('Classroom tray cupboard','06 Storage',(4.0,12,0))
box('Tray unit top',(0,0,.81),(1.44,.45,.045),'woodlight',.012)
box('Tray unit bottom',(0,0,.075),(1.44,.45,.045),'wood',.012)
box('Tray unit back',(0,.215,.44),(1.44,.03,.71),'wood',.01)
for x in [-.70,-.235,.235,.70]:box('Tray divider',(x,0,.44),(.035,.45,.73),'wood',.007)
for col in range(3):
 for row in range(4):
  x=(col-1)*.467;z=.145+row*.17;m=['ivory','taupe','clay'][col]
  box('Tray bottom',(x,-.015,z),(.415,.39,.015),m,.006)
  for dx in [-.202,.202]:box('Tray side',(x+dx,-.015,z+.051),(.013,.39,.105),m,.006)
  box('Tray rear',(x,.173,z+.051),(.40,.014,.105),m,.006)
  box('Tray front',(x,-.205,z+.045),(.415,.022,.095),m,.012)
  box('Tray label',(x,-.218,z+.048),(.115,.003,.031),'ivory',.003)

ROOT=None;COL=STAGE
box('Staffroom prop pedestal',(7.0,12,.36),(2.2,1.00,.72),'plinth',.04)
asset('Graphite electric kettle','07 Staffroom',(6.4,12,.721))
cylinder('Power base',(0,0,.012),.125,.024,'black',40)
lathe('Kettle body',[(0,.026),(.093,.026),(.115,.055),(.118,.15),(.104,.232),(.083,.249),(0,.249)],'black',n=48)
cylinder('Steel bottom band',(0,0,.041),.106,.022,'metal',40)
lathe('Kettle lid',[(0,.251),(.084,.251),(.083,.258),(.071,.264),(0,.264)],'black',n=40)
box('Lid release',(0,0,.272),(.045,.026,.015),'taupe',.008)
handle=[]
for i in range(23):
 a=-pi*.44+pi*.88*i/22;handle.append((.115+.064*cos(a),0,.148+.096*sin(a)))
tube('Kettle handle',handle,.017,'black')
sp=lathe('Hollow kettle spout',[(.039,0),(.027,.09),(.022,.09),(.032,0)],'metal',(-.091,0,.167),n=24)
sp.rotation_euler.y=-.86
box('Water level window',(0,-.117,.149),(.021,.006,.101),'screen',.008)
for z in [.12,.15,.18]:box('Water graduation',(0,-.121,z),(.012,.001,.0017),'ivory',.0004)
box('Power switch',(.12,0,.052),(.05,.025,.014),'taupe',.005)
ball('Power light',(.107,-.024,.063),(.003,.002,.003),'leaflight',8,6)
text('Kettle branding','WREN',(0,-.109,.085),.012,'ivory')
def mug(material):
 lathe('Hollow ceramic mug',[(0,0),(.036,0),(.042,.008),(.044,.089),(.042,.099),(.036,.099),(.035,.015),(0,.015)],material,n=40)
 pts=[(.040+.034*sin(pi*i/24),0,.052+.035*cos(pi*i/24)) for i in range(25)]
 tube('Ceramic mug handle',pts,.008,material)
asset('Ivory staff mug','07 Staffroom',(6.83,11.89,.721));mug('ivory')
asset('Graphite staff mug','07 Staffroom',(7.10,11.94,.721));mug('black')
asset('Cup and saucer','07 Staffroom',(7.40,11.92,.721))
lathe('Saucer',[(0,.003),(.073,.003),(.079,.008),(.076,.015),(.042,.008),(0,.008)],'ivory',n=40)
lathe('Teacup',[(0,.009),(.027,.009),(.035,.02),(.049,.075),(.047,.080),(.042,.080),(.028,.025),(0,.02)],'ivory',n=40)
tube('Teacup handle',[(.042+.024*sin(pi*i/20),0,.049+.021*cos(pi*i/20)) for i in range(21)],.006,'ivory')
asset('Takeaway coffee cup','07 Staffroom',(7.65,12.12,.721))
lathe('Paper coffee cup',[(0,0),(.029,0),(.044,.122),(.039,.122),(.026,.007),(0,.007)],'ivory',n=32)
lathe('Graphite sleeve',[(.034,.041),(.041,.087),(.039,.087),(.032,.041)],'black',n=32)
lathe('Coffee lid',[(0,.122),(.046,.122),(.046,.130),(.037,.134),(.035,.143),(0,.143)],'black',n=32)

image=bpy.data.images.get('Wren-bird-white.png') or bpy.data.images.load(os.path.join(BASE,'textures','Wren-bird-white.png'))
image.pack()
def logo_material(name,base):
 m=mat(name,base,.5);p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED');n=m.node_tree.nodes
 t=n.new('ShaderNodeTexImage');t.image=image
 mix=n.new('ShaderNodeMixRGB');mix.inputs['Color1'].default_value=(*base,1);mix.inputs['Color2'].default_value=(.95,.95,.95,1)
 m.node_tree.links.new(t.outputs['Alpha'],mix.inputs['Factor']);m.node_tree.links.new(mix.outputs['Color'],p.inputs['Base Color']);return m
LOGO=logo_material('Exact revised Wren logo',(.023,.029,.036))
def logo(name,loc,width,material=LOGO):
 h=width*257/399
 o=mesh(name,[(-width/2,0,-h/2),(width/2,0,-h/2),(width/2,0,h/2),(-width/2,0,h/2)],[(0,1,2,3)],material,loc)
 uv=o.data.uv_layers.new(name='Logo UV')
 for p in o.data.polygons:
  for idx,co in zip(p.loop_indices,[(0,0),(1,0),(1,1),(0,1)]):uv.data[idx].uv=co
 return o
asset('Wren mobile whiteboard','08 Boards',(0,16,0))
box('Rounded graphite board frame',(0,0,1.57),(2.43,.13,1.46),'black',.065)
box('White enamel writing face',(0,-.073,1.60),(2.25,.025,1.25),'board',.042)
logo('User revised Wren emblem',(0,-.067, .901),.145)
box('Marker tray',(0,-.16,.825),(1.18,.20,.035),'metal',.018)
box('Tray front lip',(0,-.254,.85),(1.18,.018,.045),'black',.008)
for x in [-.86,.86]:
 rod('Board upright',(x,.045,.17),(x,.045,1.50),.031,'black')
 box('Board T-foot',(x,.045,.10),(.095,.77,.064),'black',.024)
 for y in [-.29,.38]:ball('Board locking caster',(x,y,.053),(.043,.038,.048),'rubber',12,8)
for x in [-.25,-.12]:
 pen=cylinder('Board marker',(x,-.15,.86),.009,.14,'black',16);pen.rotation_euler.y=pi/2
box('Magnetic eraser',(.74,-.097,1.17),(.13,.025,.068),'taupe',.018)

asset('Rounded Wren TV teaching board','08 Boards',(3.25,16,0))
box('TV rounded enclosure',(0,0,1.56),(2.20,.12,1.36),'black',.066)
box('Dark teaching display',(0,-.068,1.585),(2.035,.018,1.16),'screen',.044)
logo('TV bezel Wren emblem',(0,-.067,.929),.115)
for x in [-.66,.66]:
 rod('TV floor stand',(x,.05,.13),(x,.05,1.50),.032,'black')
 box('TV stand foot',(x,.02,.085),(.08,.65,.055),'black',.022)
 for y in [-.26,.28]:ball('TV stand wheel',(x,y,.044),(.038,.032,.04),'rubber',12,8)
text('TV welcome','WREN SCHOOL',(0,-.080,1.71),.145,'ivory')
text('TV subtitle','Learn. Create. Belong.',(0,-.080,1.48),.064,'taupe')
print('Storage, staffroom props, exact-logo whiteboard and TV board created')
