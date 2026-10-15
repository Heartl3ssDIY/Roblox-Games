exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\HeavensArena\source\common.py',encoding='utf-8').read(),'common.py','exec'))
sc=bpy.context.scene
# Quiet stone tiles: no checker motif or central emblem.
ob=bpy.data.objects['HA_Unmarked_64x64_Tiled_Platform'];uv=ob.data.uv_layers.active
for p in ob.data.polygons:
 for li in p.loop_indices:
  q=uv.data[li].uv
  uv.data[li].uv=((1+.015+(q.x*4%1-.015))/4,(.015+(q.y*4%1-.015))/4)
im=bpy.data.images['HA_ColorAtlas'];px=np.array(im.pixels[:],dtype=np.float32).reshape(1024,1024,4)
base=np.array(PALETTE[1])/255;base=np.where(base<=.04045,base/12.92,((base+.055)/1.055)**2.4)
noise=np.random.default_rng(64).normal(0,.001,(256,256,1))
px[0:256,256:512,:3]=base+noise;im.pixels.foreach_set(px.ravel());im.save();im.pack()
# Gameplay surface and simplified boundary proxies.
floor=Builder()
verts=[]
for z in [-.6,.025]:
 for i in range(8):
  a=(i+.5)*pi/4;rad=79/cos(pi/8);verts.append((rad*cos(a),rad*sin(a),z))
floor.face(list(reversed(verts[:8])),4);floor.face(verts[8:],4)
for i in range(8):floor.face([verts[i],verts[(i+1)%8],verts[(i+1)%8+8],verts[i+8]],4)
floor.build('COL_Arena_Floor','85_Collision')
singlebox('COL_Combat_Platform',(0,0,.8975),(65.4,65.4,1.795),4,'85_Collision')
for sg in [-1,1]:
 for j in range(3):
  singlebox('COL_Platform_Step_%s_%s'%(sg,j),(0,sg*(33.2+j*.8),1.48-j*.42),(9,.8,.5),4,'85_Collision')
for i in range(8):
 b=Builder();a=i*pi/4;b.radialbox(a,0,78.5,6,2*79*tan(pi/8),1,12,4);b.build('COL_Spectator_Boundary%02d'%(i+1),'85_Collision')
for o in collection('85_Collision').objects:o['Roblox_CanCollide']=True;o['Roblox_Transparency']=1;o.hide_render=True
bpy.context.view_layer.update()
collection('85_Collision').hide_render=True;collection('85_Collision').hide_viewport=True
sc.camera=bpy.data.objects['HA_Camera_Hero'];sc.render.resolution_x=1700;sc.render.resolution_y=1400
bpy.data.libraries.write(os.path.join(ROOT,'Heavens_Arena_Editable.blend'),{sc},fake_user=True,compress=True)
print('Finished editable scene and',len(collection('85_Collision').objects),'collision proxies')
