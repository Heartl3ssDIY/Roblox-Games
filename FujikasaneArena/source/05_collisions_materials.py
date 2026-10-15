exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\FujikasaneArena\source\common.py',encoding='utf-8').read(),'common.py','exec'))
sc=bpy.context.scene
# Correct closed crown face orientation.
for c in sc.collection.children:
 if c.name.startswith('FK | 23_Canopy_'):
  for ob in c.objects:
   if ob.name.startswith('Wisteria_crown'):
    bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(ob.data);bm.free()
collection('24_Crown_Detail').hide_render=True;collection('24_Crown_Detail').hide_viewport=True
rim=bpy.data.objects['Earthen_cutaway_edge']
for v in rim.data.vertices:
 if v.co.z>-6.9:v.co.z=ground_height(v.co.x,v.co.y)
# Stone flights rest on their foundations instead of floating above the slope.
for ob in collection('03_Stone_Stairs').objects:
 if ob.name.startswith('Forest_ascent_step'):
  top=ob.location.z+.28
  base=min(top-.4,ground_height(ob.location.x,ob.location.y)-.25)
  ob.scale.z=(top-base)/.56;ob.location.z=(top+base)/2
bpy.context.view_layer.update()
g='85_Collision'
box('COL_Clearing',(0,0,-.97),(86,126,2.06),5,g)
box('COL_Approach',(0,-70,-.47),(30,14,1.06),5,g)
box('COL_Rear_Terrace',(0,71,-.47),(34,18,1.06),5,g)
for ob in list(collection('03_Stone_Stairs').objects):
 if 'step' in ob.name:
  copy=ob.copy();copy.data=ob.data.copy();copy.name='COL_'+ob.name;collection(g).objects.link(copy)
for i,(x,y) in enumerate([(-38,-43),(38,-43),(-40,0),(40,0),(-38,43),(38,43),(-9,68),(9,68)]):
 h=26 if i<6 else 17.5;r=1.35 if i<6 else .8
 lathe('COL_Red_Post',[(0,0),(r,0),(r,h),(0,h)],(x,y,0),5,g,16)
for side in [-1,1]:
 for yy in [-51,-12,24,61]:
  box('COL_Rock_Outcrop',(side*55,yy,ground_height(side*55,yy)+3),(11,15,6),5,g)
positions=[]
for side in [-1,1]:
 for j,y in enumerate([-62,-33,-3,28,59]):positions.append((side*(57+(-1 if j%2 else 2)),y,25+(j%3)*1.8))
positions += [(-30,86,26),(0,91,27),(30,86,25),(-32,-83,24),(32,-83,26)]
for x,y,h in positions:lathe('COL_Tree_Trunk',[(0,0),(1.4,0),(1.4,h*.65),(0,h*.65)],(x,y,ground_height(x,y)),5,g,12)
box('COL_Ceremonial_Stone',(0,74,2),(10,6,4),5,g)
collection(g).hide_viewport=True;collection(g).hide_render=True
for name,loc in [('FK_Arena_Center',(0,0,.06)),('FK_Team_A_Spawn',(0,-22,.06)),('FK_Team_B_Spawn',(0,22,.06)),('FK_Board_Min',(-32,-32,.06)),('FK_Board_Max',(32,32,.06))]:
 o=bpy.data.objects.new(name,None);collection('80_Gameplay_Markers').objects.link(o);o.location=loc;o.empty_display_size=2
# Packed normal and roughness maps shared by the scene materials.
size=1024;tile=256;normal=np.ones((size,size,4),np.float32);rough=np.ones((size,size,4),np.float32);rng=np.random.default_rng(228)
y,x=np.mgrid[0:tile,0:tile]/tile
for k in range(16):
 h=.009*np.sin(x*69+y*43)*np.cos(y*57)+rng.normal(0,.001,(tile,tile))
 if k==3:h+=.032*np.sin(x*85+np.sin(y*17)*2)
 if k in [0,14]:h+=.018*np.sin(x*148+y*71)*np.cos(y*113)
 if k>=10 and k!=14:h*=.2
 dy,dx=np.gradient(h);n=np.stack([-dx*2,-dy*2,np.ones_like(h)],axis=2);n/=np.linalg.norm(n,axis=2)[:,:,None]
 row,col=divmod(k,4);normal[row*tile:(row+1)*tile,col*tile:(col+1)*tile,:3]=n*.5+.5
 val=.45 if k==4 else .67 if k==5 else .9
 rough[row*tile:(row+1)*tile,col*tile:(col+1)*tile,:3]=np.clip(val+h,.2,1)[:,:,None]
for name,data in [('FK_NormalAtlas',normal),('FK_RoughnessAtlas',rough)]:
 im=bpy.data.images.new(name,width=size,height=size,alpha=False);im.colorspace_settings.name='Non-Color';im.pixels.foreach_set(data.ravel());im.filepath_raw=os.path.join(ROOT,'textures',name+'.png');im.file_format='PNG';im.save();im.pack()
 for matname in ['Fujikasane | shared painted atlas','Fujikasane | softly luminous wisteria']:
  mat=bpy.data.materials[matname];bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');tx=mat.node_tree.nodes.new('ShaderNodeTexImage');tx.image=im
  if 'Normal' in name:
   nm=mat.node_tree.nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.35;mat.node_tree.links.new(tx.outputs['Color'],nm.inputs['Color']);mat.node_tree.links.new(nm.outputs['Normal'],bs.inputs['Normal'])
  else:mat.node_tree.links.new(tx.outputs['Color'],bs.inputs['Roughness'])
bpy.data.libraries.write(os.path.join(ROOT,'Fujikasane_Arena_Editable.blend'),{sc},fake_user=True,compress=True)
print('Collision and surface maps ready')
