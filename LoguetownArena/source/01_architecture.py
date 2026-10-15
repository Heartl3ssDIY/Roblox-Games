exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\LoguetownArena\source\common.py',encoding='utf-8').read(),'common.py','exec'))
sc=bpy.data.scenes.new('Loguetown Arena');bpy.context.window.scene=sc
sc.unit_settings.system='NONE'
try:sc.render.engine='BLENDER_EEVEE'
except TypeError:pass
MAT=make_atlas()
box('Raised_town_foundation',(0,3,-2.7),(148,146,5.4),1,'01_Foundation',.3)
box('Square_stone_base',(0,0,-.08),(138,136,.35),0,'02_Paving')
for row in range(44):
 y=-65+row*3
 for col in range(34):
  x=-66+col*4+(2 if row%2 else 0)
  if x>68:continue
  group='02_Paving_'+str(row//11)
  mesh('Paving_stone',[(x-1.97,y-1.47,.12),(x+1.97,y-1.47,.12),(x+1.97,y+1.47,.12),(x-1.97,y+1.47,.12)],[(0,1,2,3)],0 if random.random()<.7 else 1,group)
for x in [-33.2,33.2]:
 box('Battle_square_border',(x,0,.14),(.5,66.9,.04),14,'02_Paving')
for y in [-33.2,33.2]:
 box('Battle_square_border',(0,y,.14),(66.9,.5,.04),14,'02_Paving')
# Quayside entrance.
box('Lower_quay',(0,-79,-5),(148,20,2),1,'03_Waterfront')
for x in [-47,47]:
 box('Quay_retaining_wall',(x,-68.7,-1.4),(53,1.9,6.2),1,'03_Waterfront',.15)
 box('Quay_wall_coping',(x,-68.7,1.8),(54,2.7,.65),2,'03_Waterfront',.1)
 for xx in range(-24,25,6):
  box('Wall_masonry_joint',(x+xx,-69.69,-1.3),(.1,.02,5.4),11,'03_Waterfront')
for i in range(12):
 height=(i+1)*.35
 box('Entrance_stair_%02d'%i,(0,-82+i*1.08,-4.1+height/2),(28,1.1,height),2,'03_Waterfront')
box('Entry_landing',(0,-67.3,-.1),(28,6,.4),2,'03_Waterfront')
box('Harbor_water',(0,-97,-6.25),(170,36,.18),13,'04_Harbor_Water')
for x in [-26,26]:
 for i in range(11):
  box('Dock_plank',(x,-96+i*1.7,-4.2),(12,1.62,.45),11,'03_Waterfront')
 for xx in [x-5,x+5]:
  for yy in [-98,-90,-82]:
   beam('Dock_pile',(xx,yy,-9),(xx,yy,-2.7),.55,11,'03_Waterfront',10)
# Side street facades.
def building(name,w,d,h,cat,roofcat,loc,rotation,sign,variant):
 g='10_'+name
 box('Pastel_plaster_body',(0,d/2,h/2),(w,d,h),cat,g)
 for z in [.45,8.4,16.6,24.8,h]:
  if z>h:continue
  box('Facade_string_course',(0,d/2,z),(w+.65,d+.6,.4 if z<h else .8),2,g)
 for x in [-w/2+.45,w/2-.45]:
  box('Facade_corner_pilaster',(x,-.2,h/2),(.85,.55,h),2,g)
  for z in np.arange(.8,h-.5,2.2):box('Quoin_block',(x,-.4,z),(1.2,.52,.7),2,g)
 for j in range(3):
  x=(j-1)*w*.29
  archwindow(x,-.055,.8,4.3,6.8,g,True)
 for row,z in enumerate([10,18.2,26.4]):
  if z+5.7>h:continue
  for j in range(3):archwindow((j-1)*w*.29,-.055,z,3.1,5.2,g,False,variant%2==0 and row==0 and j==1)
 # Windows on both return walls, visible from approach.
 for sx in [-1,1]:
  for yy in [d*.28,d*.72]:
   for zz in [11.5,20]:
    if zz+4>h:continue
    box('Side_window_recess',(sx*(w/2+.02),yy,zz),(.12,2.9,4.7),9,g)
    for dy in [-1.5,1.5]:box('Side_window_trim',(sx*(w/2+.14),yy+dy,zz),(.3,.24,5),2,g)
    for dz in [-2.4,0,2.4]:box('Side_window_trim',(sx*(w/2+.14),yy,zz+dz),(.3,3.15,.22),2,g)
    box('Side_window_mullion',(sx*(w/2+.15),yy,zz),(.3,.15,4.8),2,g)
 hiproof(w+1.6,d,h+.45,6.8,roofcat,g)
 if variant%2==0:
  extrude('Front_gable',[(-7,h+.2),(7,h+.2),(0,h+5.5)],-.4,.6,cat,g)
  beam('Gable_trim',(-7,-.8,h+.3),(0,-.8,h+5.6),.22,2,g)
  beam('Gable_trim',(0,-.8,h+5.6),(7,-.8,h+.3),.22,2,g)
  archwindow(0,-.78,h+1.0,1.6,2.1,g)
 box('Chimney',(w*.3,d*.65,h+5),(1.7,1.7,5),cat,g)
 box('Chimney_cap',(w*.3,d*.65,h+7.6),(2.15,2.15,.45),2,g)
 box('Shop_sign',(0,-.64,8.35),(w*.64,.45,1.9),11,g,.1)
 text_obj('Shop_lettering',sign,(0,-.91,7.9),1.0,2,g)
 # Sloped striped canvas awning above shop entrances.
 for i in range(10):
  x=-w*.43+i*w*.086
  ob=mesh('Striped_shop_awning',[(x,-.65,7.3),(x+w*.086,-.65,7.3),(x+w*.086,-3.3,6.2),(x,-3.3,6.2)],[(0,1,2,3)],2 if i%2 else roofcat,g)
  box('Awning_valance',(x+w*.043,-3.31,5.97),(w*.086,.1,.48),2 if i%2 else roofcat,g)
 for x in [-w*.43,w*.43]:beam('Awning_support',(x,-3.2,.3),(x,-3.2,6.25),.09,8,g,6)
 o=join_group(g,'LT_'+name);o.location=loc;o.rotation_euler.z=rotation
 return o
names=['CHANDLERY','PROVISIONS','EAST BLUE','BAKERY']
for side in [-1,1]:
 for j,y in enumerate([-45,-15,15,45]):
  building(('West' if side<0 else 'East')+'_Block_%02d'%j,26,18,[27,34,29,32][(j+(side>0))%4],[3,4,5,2][(j+(side>0))%4],6 if j%3 else 7,(side*54,y,0),pi/2 if side<0 else -pi/2,names[(j+(side>0))%4],j)
# Grand civic facade at the north edge of the square.
g='20_Civic_Shell'
box('Civic_hall_body',(0,10,16),(88,20,32),4,g)
for z in [.6,2,12.5,14,27.5,31.6,33]:
 box('Civic_cornice',(0,10,z),(90,22,.7),2,g)
for x in np.arange(-42,43,7):
 box('Civic_pilaster',(float(x),-.6,15.5),(1.15,1.1,29),2,g)
 for z in [2.1,12.5,27.2,31.5]:box('Column_capital',(float(x),-.82,z),(1.85,1.6,.7),2,g)
for x in np.arange(-38.5,39,7):
 archwindow(float(x),-.06,2.3,4,9,'21_Civic_Windows',True)
 archwindow(float(x),-.06,15.3,3.9,10,'21_Civic_Windows')
hiproof(91,20,33.5,5,6,g)
for x in [-34,34]:
 lathe('Side_dome_drum',[(0,0),(5.6,0),(5.6,4),(0,4)],(x,10,35),2,g,40)
 prof=[(0,0),(6.4,0)]+[(6.4*cos(t*pi/2),6.8*sin(t*pi/2)) for t in np.linspace(.05,.97,14)]+[(.06,7)]
 lathe('Civic_side_dome',prof,(x,10,39),6,g,48)
 beam('Dome_finial',(x,10,45.8),(x,10,47.7),.14,14,g)
box('Central_clock_tower',(0,7,37.5),(15,14,14),2,g)
for x in [-6.6,6.6]:box('Tower_corner',(x,-.3,37.5),(.8,.7,13),3,g)
# Circular clock mounted vertically on facade.
o=disk('Clock_face',3.6,0,0,0,0,g,64);o.rotation_euler.x=pi/2;o.location=(0,-.35,38.5)
for k in range(12):
 a=2*pi*k/12
 beam('Clock_hour_mark',(2.9*sin(a),-.5,38.5+2.9*cos(a)),(3.23*sin(a),-.5,38.5+3.23*cos(a)),.07,8,g,6)
beam('Clock_hour_hand',(0,-.56,38.5),(-1.3,-.56,40.3),.11,8,g)
beam('Clock_minute_hand',(0,-.57,38.5),(2.45,-.57,39.4),.075,8,g)
prof=[(0,0),(8.5,0)]+[(8.5*cos(t*pi/2),10*sin(t*pi/2)) for t in np.linspace(.04,.98,16)]+[(.05,10.2)]
lathe('Central_civic_dome',prof,(0,7,44.5),6,g,48)
beam('Central_spire',(0,7,54),(0,7,57),.15,14,g)
for i in range(4):box('Hall_entry_step',(0,-3.5+i*.8,.25+i*.35),(90,1.1,.5+i*.7),2,g)
for group,name in [('20_Civic_Shell','LT_Civic_Hall'),('21_Civic_Windows','LT_Civic_Arched_Facade')]:
 o=join_group(group,name);o.location.y=66
# Cameras and daylight.
world=bpy.data.worlds.new('Loguetown | bright coastal sky');sc.world=world;world.use_nodes=True
bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.48,.68,.82,1);bg.inputs['Strength'].default_value=.65
area('LT_Sunlit_Key',(-70,-60,150),(0,0,0),290000,(1,.9,.74),65)
area('LT_Sky_Fill',(90,-20,110),(0,10,0),140000,(.69,.84,1),90)
area('LT_Rear_Rim',(-20,100,90),(0,0,10),170000,(1,.93,.79),70)
hero=camera('LT_Camera_Hero',(152,-209,152),(0,4,10),46);sc.camera=hero
camera('LT_Camera_Entrance',(0,-133,24),(0,30,16),28)
top=camera('LT_Camera_Top',(0,0,220),(0,0,0));top.data.type='ORTHO';top.data.ortho_scale=205
sc.render.resolution_x=1700;sc.render.resolution_y=1400;sc.render.resolution_percentage=100;sc.render.image_settings.file_format='PNG'
sc.render.filepath=os.path.join(ROOT,'previews','Loguetown_Blockout.png');sc.view_settings.view_transform='AgX';sc.view_settings.look='None'
for screen in bpy.data.screens:
 for a in screen.areas:
  if a.type=='VIEW_3D':
   a.spaces.active.region_3d.view_perspective='CAMERA';a.spaces.active.overlay.show_overlays=False;a.spaces.active.shading.type='MATERIAL'
bpy.data.libraries.write(os.path.join(ROOT,'Loguetown_Arena.blend'),{sc},fake_user=True,compress=True)
bpy.ops.render.render(write_still=True)
print('Architecture and town square built',len(sc.objects))
