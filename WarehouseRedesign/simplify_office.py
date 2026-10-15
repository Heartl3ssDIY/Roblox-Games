box('DeskTop',(78,-11,3),(9,4,.4),'Wood','OfficeFurniture')
box('DeskLeftSupport',(74,-11,1.4),(.4,3.5,2.8),'Pillar','OfficeFurniture','Pillar')
box('DeskDrawerCabinet',(81,-11,1.4),(2.2,3.5,2.8),'Pillar','OfficeFurniture','Pillar')
for i in range(3):
    z=.49+i*.9
    box('DeskDrawer%d'%(i+1),(81,-12.85,z),(2.05,.2,.82),'OfficeWall','OfficeFurniture')
    box('DeskDrawerHandle%d'%(i+1),(81,-13.03,z),(.65,.16,.1),'Metal','OfficeFurniture')
box('DeskModesty',(76.95,-9.35,1.7),(5.5,.2,2.2),'Pillar','OfficeFurniture','Pillar')
box('DeskNotebookCover',(75.25,-10.4,3.24),(1.25,1.55,.08),'Red','OfficeFurniture')
box('DeskNotebookPages',(75.25,-10.4,3.32),(1.17,1.47,.08),'Label','OfficeFurniture')
box('DeskLampBase',(81.4,-10.2,3.27),(.8,.8,.14),'Pillar','OfficeFurniture')
box('DeskLampStem',(81.4,-10.2,3.88),(.16,.16,1.08),'Pillar','OfficeFurniture')
box('DeskLampShade',(81.4,-10.2,4.55),(1.1,.8,.26),'Trim','OfficeFurniture','Trim')

solid('OfficeStorageBody',[
 ((84,-32.3,2.1),(.3,2.2,4.2)),((95.7,-32.3,2.1),(.3,2.2,4.2)),
 ((89.85,-33.3,2.1),(11.4,.2,4.2)),((89.85,-32.2,.15),(11.4,2,.3)),
 ((89.85,-32.2,4.05),(11.4,2,.3))],'Pillar','OfficeFurniture','Pillar')
for i,x in enumerate((86,89.85,93.7)):
    box('StorageDoor%d'%i,(x,-31.05,2.1),(3.7,.25,3.5),'OfficeWall','OfficeFurniture')
    box('StorageHandle%d'%i,(x+1.2,-30.85,2.1),(.1,.15,.7),'Metal','OfficeFurniture')
box('StorageTop',(89.85,-32.3,4.32),(12,2.2,.24),'Wood','OfficeFurniture')

solid('OfficeBookcase',[
 ((62.65,-32.5,3.5),(.3,1.6,7)),((69.35,-32.5,3.5),(.3,1.6,7)),
 ((66,-33.2,3.5),(6.4,.2,7)),((66,-32.4,.15),(6.4,1.4,.3)),((66,-32.4,6.85),(6.4,1.4,.3))],'Pillar','OfficeFurniture','Pillar')
for z in (2.25,4.5):box('BookcaseShelf',(66,-32.4,z),(6.4,1.4,.25),'Wood','OfficeFurniture')
for i,(x,z,key) in enumerate([(63.5,.3,'Red'),(64.3,.3,'Trim'),(65.1,.3,'Green'),(66.3,2.375,'Trim'),(67.1,2.375,'Red'),(68.2,4.625,'Green')]):
    box('OfficeBinder%d'%i,(x,-32.25,z+.65),(.65,1,1.3),key,'OfficeFurniture')

box('OfficeRug',(78,-15,.025),(8,4,.05),'Fabric','OfficeFurniture')
cylinder('OfficePlanter',(93,-4,.85),.9,1.7,'Wood','OfficeFurniture',sides=8)
box('OfficePlantStem',(93,-4,2.1),(.16,.16,.8),'Wood','OfficeFurniture')
v=[(0,0,2.5),(-1.1,-.8,3.2),(1.1,-.8,3.2),(1.1,.8,3.2),(-1.1,.8,3.2),(0,0,4.7)]
ob=mesh('OfficePlant',v,[(0,2,1),(0,3,2),(0,4,3),(0,1,4),(5,1,2),(5,2,3),(5,3,4),(5,4,1)],'Green','OfficeFurniture',bevel=0);ob.location=(93,-4,0)

tx,ty=88.66403198242188,-26.830001831054688
cylinder('TeleporterBase',(tx,ty,.5),4.5,1,'Pillar','Teleporter','Pillar',sides=16)
cylinder('TeleporterPad',(tx,ty,1.075),3.8,.15,'Neon','Teleporter','Neon',sides=16)
box('TeleporterSign',(tx,-33.25,6.15),(12,.3,3.6),'Pillar','Teleporter','Pillar')

def chair(name,x,y,flip=False):
    ground=.05 if y==-15 else 0
    direction=-1 if not flip else 1
    solid(name+'_Frame',[((x+dx,y+dy,(1.9+ground)/2),(.2,.2,1.9-ground)) for dx in (-.85,.85) for dy in (-.85,.85)],'Pillar','Presentation')
    box(name+'_Seat',(x,y,2.05),(2.3,2.1,.3),'Fabric','Presentation')
    box(name+'_Back',(x,y+direction*1.25,3.15),(2.3,.3,2.2),'Fabric','Presentation')
    for dx in (-.95,.95):box(name+'_BackSupport',(x+dx,y+direction*1.25,1.1),(.15,.15,1.9),'Pillar','Presentation')
chair('Preview_PlayerChair',78,-15)
chair('Preview_InvestorChair',78,-7,True)
box('Preview_LaptopBase',(78,-10,3.275),(1.8,1.5,.15),'Pillar','Presentation')
box('Preview_LaptopLid',(78,-9.325,3.93),(1.8,.15,1.16),'Pillar','Presentation')
box('Preview_LaptopScreen',(78,-9.41,3.95),(1.55,.02,.92),'Neon','Presentation')
for side,y,xs in [('Load',-44.23,[-39,-13,13,39]),('Receive',44.23,[-18,18])]:
 for i,x in enumerate(xs,1):
    curve=bpy.data.curves.new('Preview_BayText','FONT');curve.body=side.upper()+' '+str(i);curve.size=.9;curve.align_x='CENTER';curve.extrude=0
    ob=bpy.data.objects.new('Preview_BayText',curve);finish(ob,'White','Presentation')
    ob.location=(x,y,12.7);ob.rotation_euler=(math.pi/2,0,math.pi if y<0 else 0)
curve=bpy.data.curves.new('Preview_Name','FONT');curve.body='YOUR WAREHOUSE';curve.size=1.8;curve.align_x='CENTER';curve.extrude=0
ob=bpy.data.objects.new('Preview_Name',curve);finish(ob,'White','Presentation');ob.location=(0,46.32,17);ob.rotation_euler=(math.pi/2,0,math.pi)

scene['Description']='Simplified Roblox warehouse: original flat roof dimensions, plain walls, matte colours, no bevels.'
scene.camera=bpy.data.objects['Interior Overview']
bpy.data.objects['OfficeRoof'].dimensions.x=41
bpy.data.objects['OfficeRoof'].location.x=76
cam=bpy.data.objects.get('Office Detail')
if not cam:
    data=bpy.data.cameras.new('Office Detail');cam=bpy.data.objects.new('Office Detail',data);cols['Presentation'].objects.link(cam)
cam.location=(59,-24,9)
cam.rotation_euler=(Vector((78,-11,2.5))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.lens=37
for ob in cols['Presentation'].objects:
    if ob.type=='LIGHT':
        if ob.name.startswith('Interior Area'):ob.data.energy=1600
for key in ('Key','Fill','Rim'):
    bpy.data.objects[key].data.energy={'Key':320000,'Fill':180000,'Rim':220000}[key]
next(n for n in scene.world.node_tree.nodes if n.type=='BACKGROUND').inputs['Strength'].default_value=.6
cols['Roof'].hide_viewport=True
for window in bpy.context.window_manager.windows:
 for area in window.screen.areas:
  if area.type=='VIEW_3D':
   space=area.spaces.active;space.camera=scene.camera;space.use_local_camera=True;space.shading.type='MATERIAL'
   region=next((r for r in area.regions if r.type=='WINDOW'),None)
   if region:
    with bpy.context.temp_override(window=window,area=area,region=region):
     space.region_3d.view_perspective='PERSP';bpy.ops.view3d.view_camera();space.region_3d.view_camera_zoom=18;space.region_3d.update()
print('Finished simplified asset:',sum(bool(o.get('Export')) for o in scene.objects),'exported parts')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'To_be_rich_Warehouse.blend'))
