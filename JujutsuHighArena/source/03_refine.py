exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\JujutsuHighArena\source\common.py',encoding='utf-8').read(),'common.py','exec'))
sc=bpy.context.scene;random.seed(779)
# Softer, brighter greens and matte foliage match the sunlit campus references.
changes={8:(89,139,76),9:(122,166,85),10:(159,190,106)}
old=bpy.data.images['JH_ColorAtlas'];pix=np.array(old.pixels[:],np.float32).reshape(1024,1024,4)
yy,xx=np.mgrid[0:256,0:256]/256
for k,color in changes.items():
 shade=1+.022*np.sin(xx*28)*np.cos(yy*23)
 rgb=np.clip(np.array(color)[None,None,:]/255*shade[:,:,None],0,1)
 rgb=np.where(rgb<=.04045,rgb/12.92,((rgb+.055)/1.055)**2.4)
 row,col=divmod(k,4);pix[row*256:(row+1)*256,col*256:(col+1)*256,:3]=rgb
old.pixels.foreach_set(pix.ravel());old.save()
old.name='JH_ColorAtlas_PreRefine';fresh=bpy.data.images.load(ROOT+'/textures/JH_ColorAtlas.png',check_existing=False);fresh.name='JH_ColorAtlas';fresh.pack()
for mat in bpy.data.materials:
 if mat.use_nodes:
  for node in mat.node_tree.nodes:
   if node.type=='TEX_IMAGE' and node.image==old:node.image=fresh
if old.users==0:bpy.data.images.remove(old)
old=bpy.data.images['JH_RoughnessAtlas'];pix=np.array(old.pixels[:],np.float32).reshape(1024,1024,4)
for k in [8,9,10]:
 row,col=divmod(k,4);pix[row*256:(row+1)*256,col*256:(col+1)*256,:3]=.95
old.pixels.foreach_set(pix.ravel());old.save();old.name='JH_RoughnessAtlas_PreRefine'
fresh=bpy.data.images.load(ROOT+'/textures/JH_RoughnessAtlas.png',check_existing=False);fresh.name='JH_RoughnessAtlas';fresh.colorspace_settings.name='Non-Color';fresh.pack()
for mat in bpy.data.materials:
 if mat.use_nodes:
  for node in mat.node_tree.nodes:
   if node.type=='TEX_IMAGE' and node.image==old:node.image=fresh
if old.users==0:bpy.data.images.remove(old)
for mat in [MAT,GOLD]:
 b=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');b.inputs['Specular IOR Level'].default_value=.18
# Break up the canopy outline with small, matte leaf clusters.
bm=bmesh.new();bmesh.ops.create_icosphere(bm,subdivisions=1,radius=1)
bm.verts.ensure_lookup_table();bm.verts.index_update()
leaf_v=[v.co.copy() for v in bm.verts];leaf_f=[tuple(v.index for v in f.verts) for f in bm.faces];bm.free()
detail=Builder()
for i,ob in enumerate(list(collection('41_Tree_Canopies').objects)):
 pts=[v.co.copy() for v in ob.data.vertices];centre=sum(pts,Vector())/len(pts)
 for v in ob.data.vertices:v.co=centre+(v.co-centre)*random.uniform(.93,1.07)
 for p in ob.data.polygons:p.use_smooth=False
 bounds=[max(p[j] for p in pts)-min(p[j] for p in pts) for j in range(3)]
 for j in range(4):
  a=random.uniform(0,2*pi);loc=centre+Vector((cos(a)*bounds[0]*.37,sin(a)*bounds[1]*.37,random.uniform(-.15,.25)*bounds[2]))
  scale=(bounds[0]*.27,bounds[1]*.26,bounds[2]*.32);cat=random.choice([8,9,9,10])
  verts=[loc+Vector((v.x*scale[0],v.y*scale[1],v.z*scale[2])) for v in leaf_v]
  for f in leaf_f:detail.face([verts[k] for k in f],cat)
detail.build('JH_Foliage_Outer_Clusters','41_Tree_Canopies')
bpy.data.lights['JH_Afternoon_Sun'].energy=3.1;bpy.data.lights['JH_Sky_Fill'].energy=800000
bpy.data.objects['JH_Camera_Hero'].data.ortho_scale=372
for area in bpy.context.screen.areas:
 if area.type=='VIEW_3D':
  area.spaces.active.clip_start=.5;area.spaces.active.clip_end=3000
  area.spaces.active.region_3d.view_distance=340;area.spaces.active.region_3d.view_location=(0,30,15);area.spaces.active.region_3d.view_rotation=sc.camera.rotation_euler.to_quaternion()
bpy.context.view_layer.update()
bpy.data.libraries.write(ROOT+'/Jujutsu_High_Editable.blend',{sc},fake_user=True,compress=True)
sc.render.filepath=ROOT+'/previews/Jujutsu_High_Refined.png'
print('Foliage and daylight refined')
