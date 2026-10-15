exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\ChuninExamHall\source\common.py',encoding='utf-8').read(),'common.py','exec'))
# Keep a full 64 x 64 fighting zone free of the stairs and dais.
for ob in collection('01_Foundation').objects:
 if ob.name=='Hall_Foundation':ob.location.y=-4;ob.scale.y=110/102
 if ob.name=='Dark_Grout_Bed':ob.location.y=-6;ob.scale.y=100.4/92.4
for row,y in enumerate([-54,-50]):
 for col in range(16):
  box('Entry_Floor_%02d_%02d'%(row,col),(-30+col*4,y,.09),(3.96,3.96,.22),0,'02_Tiled_Floor',.025)
for x in [-32,-16,0,16,32]:
 box('Entry_Grid_Seam',(x,-52,.207),(.12,8,.012),9,'03_Floor_Weathering')
for side,g in [(-1,'05_West_Gallery'),(1,'06_East_Gallery')]:
 for ob in list(collection(g).objects):
  if ob.name.startswith('Access_Stair'):
   ob.location.x=side*36;ob.scale.x=.78
  if ob.name.startswith('Gallery_Support') or ob.name.startswith('Gallery_Walking_Surface') or ob.name.startswith('Gallery_Front_Fascia'):
   ob.location.y=6.2;ob.scale.y=79.6/94
  if (ob.name.startswith('Rail_Baluster') or ob.name.startswith('Gallery_Rail')):
   for v in ob.data.vertices:
    if v.co.y < -33.6:v.co.y=-33.6
  if ob.name.startswith('Rail_Baluster'):
   if max(v.co.y for v in ob.data.vertices)<-33.59:bpy.data.objects.remove(ob,do_unlink=True);continue
  if (ob.name.startswith('Rail_Primary_Post') or ob.name.startswith('Post_Cap')) and ob.location.y<-33.6:
   bpy.data.objects.remove(ob,do_unlink=True);continue
  if ob.name.startswith('Stair_'):
   for v in ob.data.vertices:v.co.x += side*10.6
 for y in [-53]:
  box('Stair_Entry_Landing',(side*36,y,.11),(7.8,6,.22),3,g,.03)
# Portable normal/roughness atlases, with subtle stone relief rather than heavy noise.
size=2048;tile=512;yy,xx=np.mgrid[0:tile,0:tile];rng=np.random.default_rng(44)
normal=np.ones((size,size,4),dtype=np.float32);rough=np.ones_like(normal)
for k in range(16):
 noise=rng.normal(0,1,(tile,tile))
 height=.012*np.sin(xx*.19)*np.cos(yy*.23)+noise*.003
 if k==6:height=.09*np.sin(xx*.14+np.sin(yy*.025))
 gy,gx=np.gradient(height);norm=np.sqrt(1+gx*gx+gy*gy)
 rgb=np.stack([-.5*gx/norm+.5,-.5*gy/norm+.5,1/norm*.5+.5],axis=-1)
 ys=slice(k//4*tile,(k//4+1)*tile);xs=slice(k%4*tile,(k%4+1)*tile)
 normal[ys,xs,:3]=rgb
 rough[ys,xs,:3]=np.clip((.86 if k not in [10,11,12,13] else .6)+noise[:,:,None]*.01,0,1)
bs=next(n for n in MAT.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
for name,arr in [('Chunin_NormalAtlas',normal),('Chunin_RoughnessAtlas',rough)]:
 im=bpy.data.images.new(name,width=size,height=size,alpha=False);im.colorspace_settings.name='Non-Color'
 im.pixels.foreach_set(arr.ravel());im.filepath_raw=os.path.join(ROOT,'textures',name+'.png');im.file_format='PNG';im.save();im.pack()
 tex=MAT.node_tree.nodes.new('ShaderNodeTexImage');tex.image=im
 if 'Normal' in name:
  nm=MAT.node_tree.nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.4
  MAT.node_tree.links.new(tex.outputs['Color'],nm.inputs['Color']);MAT.node_tree.links.new(nm.outputs['Normal'],bs.inputs['Normal'])
 else:MAT.node_tree.links.new(tex.outputs['Color'],bs.inputs['Roughness'])
# Gameplay reference markers and collision proxies do not render.
for name,loc in [('Arena_Center',(0,-20,.22)),('Team_A_Spawn',(0,-39,.22)),('Team_B_Spawn',(0,-1,.22)),('Camera_Target',(0,-20,0))]:
 ob=bpy.data.objects.new(name,None);collection('80_GameplayMarkers').objects.link(ob);ob.location=loc;ob.empty_display_size=1
 ob['purpose']='Gameplay reference only'
g='85_CollisionProxies'
box('COL_Main_Floor',(0,-6,-.4),(64,100,1.2),9,g)
for side in [-1,1]:
 box('COL_Gallery',(side*36,6.2,7),(8,79.6,14),9,g)
 box('COL_Outer_Wall',(side*40.5,-1,21),(1.4,99,44),9,g)
 for i in range(14):
  top=i+1
  box('COL_Stair_'+str(side)+'_'+str(i),(side*36,-46+i*.85,top/2),(7.8,.85,top),9,g)
box('COL_Rear_Wall',(0,48.5,21),(81,1.5,44),9,g)
box('COL_Dais_Rear',(0,37,.84),(64,22,1.3),9,g)
coords=[(13*cos(-pi*j/16),26+13*sin(-pi*j/16)) for j in range(17)];n=len(coords)
mesh('COL_Dais_Curve',[(x,y,.2) for x,y in coords]+[(x,y,1.5) for x,y in coords],[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],9,g)
box('COL_Sculpture',(0,40,7),(59,11,12),9,g)
for ob in collection(g).objects:ob.hide_render=True;ob['export_role']='collision'
collection(g).hide_render=True;collection(g).hide_viewport=True
scene=bpy.context.scene
scene.camera=bpy.data.objects['Camera_Hall_Hero']
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'Chunin_Exam_Hall_Editable.blend'))
print("Clear 64 x 64 combat footprint, PBR textures and collision proxies prepared.")
