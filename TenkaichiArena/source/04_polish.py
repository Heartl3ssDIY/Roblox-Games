exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\TenkaichiArena\source\common.py',encoding='utf-8').read(),'common.py','exec'))
# Improve sign proportions without stretching Japanese glyphs into a narrow strip.
for name in ['Tournament_sign_gold','Tournament_sign_red','Tournament_sign_ivory']:
 ob=bpy.data.objects[name]
 for v in ob.data.vertices:v.co.z=23.55+(v.co.z-23.55)*1.4
ob=bpy.data.objects['Tournament_calligraphy']
lo=[min(v.co[i] for v in ob.data.vertices) for i in range(3)];hi=[max(v.co[i] for v in ob.data.vertices) for i in range(3)]
ob.scale=(31/(hi[0]-lo[0]),3.6/(hi[1]-lo[1]),1)
ob.location.x=-(lo[0]+hi[0])*.5*ob.scale.x;ob.location.z=21.7-lo[1]*ob.scale.y
# Continuous supported walkway from the fighting platform to the temple.
for ob in list(collection('03_TempleDetails').objects):
 if ob.name.startswith('Temple_entry_step'):bpy.data.objects.remove(ob,do_unlink=True)
box('Entry_walkway_foundation',(0,33.5,1.2),(10,11,2.4),5,'03_TempleShell',.07)
floor=bpy.data.objects['Temple_floor']
floor.location.z=2.30
for v in floor.data.vertices:v.co.z *= .4/.26
for i,ob in enumerate(collection('02_RingSteps').objects):
 k=i%4;top=.6*(k+1);old=max(v.co.z for v in ob.data.vertices)-min(v.co.z for v in ob.data.vertices)
 for v in ob.data.vertices:v.co.z*=top/old
 ob.location.z=top/2
# Carved fascia endcaps, red rafters, and shallow cornice detail.
for side in [-1,1]:
 for i in range(12):
  x=side*(5+i*3)
  box('Eave_rafter_tail',(x,38.5,17.1),(.3,2.4,.44),6,'03_TempleDetails',.05)
 for i in range(7):
  x=side*(11+i*4.5)
  box('Temple_foundation_block',(x,38.2,1.15),(4.35,.7,1.8),5,'03_TempleDetails',.07)
 for y in [43,49,55,61]:
  box('Temple_side_timber',(side*39.05,y,9.6),(.25,.4,14.3),1,'03_TempleDetails',.035)
# Organic shrub silhouettes and quieter palm ring contrast.
for ob in collection('21_Gardens').objects:
 if ob.name.startswith('Shrub_leaf_cluster'):
  for v in ob.data.vertices:
   p=v.co;f=1+.065*sin(p.x*5+p.y*3)*cos(p.z*6);v.co*=f
  mod=ob.modifiers.new('Shrub_game_budget','DECIMATE');mod.ratio=.5
for c in bpy.context.scene.collection.children:
 if c.name.startswith('20_Palm'):
  rings=[o for o in c.objects if o.name.startswith('Palm_trunk_ring')]
  for i,ob in enumerate(rings):
   if i%2:bpy.data.objects.remove(ob,do_unlink=True)
   else:atlas_uv(ob,6)
  for ob in c.objects:
   if ob.name.startswith('Palm_folded_frond'):
    mod=ob.modifiers.new('Palm_game_budget','DECIMATE');mod.ratio=.57
# Portable surface maps. Tangent normal and roughness atlas match the color atlas.
size=2048;tile=512;yy,xx=np.mgrid[0:tile,0:tile];rng=np.random.default_rng(119)
normal=np.ones((size,size,4),dtype=np.float32);rough=np.ones((size,size,4),dtype=np.float32)
for k in range(16):
 n=rng.normal(0,1,(tile,tile));height=.07*np.sin(xx*.17)*np.sin(yy*.19)+n*.015
 if k==2:height=.75*np.sin(xx*.66+.4*np.sin(yy*.024))+.23*np.sin(xx*1.6+yy*.008)
 elif k==6:height=.3*np.sin(xx*.17+np.sin(yy*.02))+.1*np.sin(xx*.69)
 elif k in [12,13,11]:height=.04*np.sin(xx*pi)*np.cos(yy*pi*.93)
 elif k in [7,8,9]:height=.05*np.sin(xx*.15+yy*.22)
 gy,gx=np.gradient(height);nx=-gx;ny=-gy;nz=np.ones_like(nx);norm=np.sqrt(nx*nx+ny*ny+nz*nz)
 rgb=np.stack([nx/norm*.5+.5,ny/norm*.5+.5,nz/norm*.5+.5],axis=-1)
 row=k//4;col=k%4;ys=slice(row*tile,(row+1)*tile);xs=slice(col*tile,(col+1)*tile)
 normal[ys,xs,:3]=rgb
 value=.88 if k in [0,2,3,5,6,7,8,9,10] else .65 if k in [1,4,11] else .78
 rough[ys,xs,:3]=np.clip(value+n[:,:,None]*.025,.3,1)
mat=MAT;bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
for name,arr in [('Arena_NormalAtlas',normal),('Arena_RoughnessAtlas',rough)]:
 im=bpy.data.images.new(name,width=size,height=size,alpha=False);im.colorspace_settings.name='Non-Color';im.pixels.foreach_set(arr.ravel());im.filepath_raw=os.path.join(ROOT,'textures',name+'.png');im.file_format='PNG';im.save();im.pack()
 tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=im
 if 'Normal' in name:
  nm=mat.node_tree.nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.6
  mat.node_tree.links.new(tex.outputs['Color'],nm.inputs['Color']);mat.node_tree.links.new(nm.outputs['Normal'],bs.inputs['Normal'])
 else:mat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Roughness'])
# Save source before consolidating thousands of small construction components.
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'Tenkaichi_Arena_Editable.blend'))
print('POLISH_COMPLETE')
