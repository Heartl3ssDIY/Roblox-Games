exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\MarinefordFrozenBay\source\common.py',encoding='utf-8').read(),'common.py','exec'))
sc=bpy.context.scene
# Lift the ice field just enough to prevent depth fighting in game viewports.
for v in bpy.data.objects['MF_Pale_Ice_Fields'].data.vertices:v.co.z=.065
for v in bpy.data.objects['MF_Hairline_Frozen_Fractures'].data.vertices:v.co.z=.075
for v in bpy.data.objects['COL_Frozen_Bay'].data.vertices:
 if v.co.z>0:v.co.z=.065
for ob in collection('22_Roofs').objects:
 if '_Tiles' in ob.name:apply_uv(ob,6)
# Slightly enlarge the Marine inscription without moving its baseline.
ob=bpy.data.objects.get('MF_Marine_Headquarters_Sign')
if ob:ob.scale=(1.3,1.3,1)
# Give all ice swatches softly marbled frost while preserving the portable atlas workflow.
im=bpy.data.images.get('MF_ColorAtlas');pix=np.array(im.pixels[:],np.float32).reshape(1024,1024,4)
yy,xx=np.mgrid[0:256,0:256]/256
colors=[(192,223,234),(211,237,242),(222,240,244),(105,163,188)]
for k,c in enumerate(colors[:3]):
 noise=.016*np.sin(xx*21+np.sin(yy*11)*2)+.01*np.sin(yy*32+xx*8)+.004*np.sin(xx*130-yy*90)
 rgb=np.clip(np.array(c)[None,None,:]/255+noise[:,:,None],0,1)
 rgb=np.where(rgb<=.04045,rgb/12.92,((rgb+.055)/1.055)**2.4)
 row,col=divmod(k,4);pix[row*256:(row+1)*256,col*256:(col+1)*256,:3]=rgb
im.pixels.foreach_set(pix.ravel());im.save()
oldim=im;oldim.name='MF_ColorAtlas_PreFrost'
im=bpy.data.images.load(ROOT+'/textures/MF_ColorAtlas.png',check_existing=False);im.name='MF_ColorAtlas';im.pack()
for material in bpy.data.materials:
 if material.use_nodes:
  for node in material.node_tree.nodes:
   if node.type=='TEX_IMAGE' and node.image==oldim:node.image=im
if oldim.users==0:bpy.data.images.remove(oldim)
bpy.context.view_layer.update()
bpy.data.libraries.write(ROOT+'/Marineford_Frozen_Bay_Editable.blend',{sc},fake_user=True,compress=True)
# Adapt the established verified export pipeline for this arena.
old=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\WanoFlowerCapital\source\04_export.py'
src=open(old,encoding='utf-8').read().replace('WanoFlowerCapital','MarinefordFrozenBay').replace('WA | ','MF | ').replace('WA_','MF_').replace('Wano_Flower_Capital','Marineford_Frozen_Bay')
src=src.replace("'combat_surface_height':.035","'combat_surface_height':.065").replace("'street_width':76","'bay_radius':96")
src=src.replace("['COL_Main_Ground','COL_Clear_Street']","['COL_Frozen_Bay']")
# Refresh vertex indexes after weld before duplicate-face comparisons.
src=src.replace("by_key={}", "bm.verts.ensure_lookup_table();bm.verts.index_update()\n  by_key={}")
open(ROOT+'/source/05_export.py','w',encoding='utf-8').write(src)
exec(compile(src,'05_export.py','exec'))
