exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\WanoFlowerCapital\source\common.py',encoding='utf-8').read(),'common.py','exec'))
sc=bpy.context.scene
im=bpy.data.images['WA_ColorAtlas'];pix=np.array(im.pixels[:],dtype=np.float32).reshape(1024,1024,4)
for cat,color in [(2,(196,155,112)),(3,(119,83,70))]:
 rgb=np.array(color)/255;rgb=np.where(rgb<=.04045,rgb/12.92,((rgb+.055)/1.055)**2.4)
 row,col=divmod(cat,4);pix[row*256:(row+1)*256,col*256:(col+1)*256,:3]=rgb
im.pixels.foreach_set(pix.ravel());im.save();im.pack()
# Slim the distant needle mountain so it supports the castle silhouette.
for name in ['WA_Distant_Blue_Peak','WA_Peak_Snow']:
 ob=bpy.data.objects[name]
 for v in ob.data.vertices:v.co.x=-68+(v.co.x+68)*.72;v.co.y=193+(v.co.y-193)*.72
 ob.data.update()
# Rebuild the gate cap with a red fascia and a dark top.
ob=bpy.data.objects['WA_Torii_Curved_Cap'];bpy.data.objects.remove(ob,do_unlink=True)
b=Builder();xs=np.linspace(-47,47,25)
for j in range(len(xs)-1):
 a=xs[j];c=xs[j+1];za=33.3+3.3*(abs(a)/47)**4;zc=33.3+3.3*(abs(c)/47)**4
 v=[(a,62.9,za),(c,62.9,zc),(c,67.1,zc),(a,67.1,za),(a,62.9,za+1.35),(c,62.9,zc+1.35),(c,67.1,zc+1.35),(a,67.1,za+1.35)]
 for f,cat in [((3,2,1,0),4),((0,1,5,4),4),((1,2,6,5),4),((2,3,7,6),4),((3,0,4,7),4),((4,5,6,7),15)]:b.face([v[k] for k in f],cat)
b.build('WA_Torii_Curved_Cap','20_Red_Gate')
for side in [-1,1]:
 ob=bpy.data.objects['WA_Torii_Pillar_'+str(side)]
 for v in ob.data.vertices:
  if v.co.z>31:v.co.z+=1.9
 ob.data.update()
 ob=bpy.data.objects['WA_Torii_Collar_'+str(side)]
 for v in ob.data.vertices:v.co.z+=2
 ob.data.update()
ob=bpy.data.objects['WA_Torii_Center_Tie']
for v in ob.data.vertices:v.co.z=31+(v.co.z-30.1)*1.45
ob.data.update()
# Close the undersides of the simplified gabled roofs.
targets=[o for o in list(sc.objects) if o.type=='MESH' and 'Roof' in o.name and not any(s in o.name for s in ['_Eave_','_Tile_Ridge_','_Top_Ridge'])]
for ob in targets:
 vs=ob.data.vertices;lo=[min(v.co[j] for v in vs) for j in range(3)];hi=[max(v.co[j] for v in vs) for j in range(3)]
 if hi[2]-lo[2]<2:continue
 x0,y0,z=lo;x1,y1,_=hi
 b=Builder();b.face([(x0,y0,z),(x0,y1,z),(x1,y1,z),(x1,y0,z)],3)
 for x,reverse in [(x0,False),(x1,True)]:
  ys=np.linspace(y0,y1,17)
  for j in range(16):
   a=ys[j];c=ys[j+1];za=z+.3+1.25+.65*abs(a/max(abs(y0),abs(y1)))**6;zc=z+.3+1.25+.65*abs(c/max(abs(y0),abs(y1)))**6
   pts=[(x,a,z),(x,c,z),(x,c,zc),(x,a,za)]
   if reverse:pts.reverse()
   b.face(pts,3)
 new=b.build(ob.name+'_Soffit','13_Roof_Undersides');new.matrix_world=ob.matrix_world.copy()
for side in [-1,1]:
 for j,y in enumerate([-54,16]):
  blossom_tree('WA_Street_Cherry_%s_%s'%(side,j),(side*44.2,y,0),1.3)
# Better overview framing keeps the entire skyline in shot.
cam=bpy.data.objects['WA_Camera_Hero'];cam.data.ortho_scale=410;cam.rotation_euler=(Vector((0,62,54))-cam.location).to_track_quat('-Z','Y').to_euler()
# Simplified gameplay collision only.
box('COL_Main_Ground',(0,53,-.45),(216,300,.9),15,'85_Collision')
box('COL_Clear_Street',(0,0,.0175),(76,190,.035),15,'85_Collision')
bounds=json.load(open(os.path.join(ROOT,'source','building_bounds.json')))
for item in bounds:
 ob=box('COL_'+item['name'],(0,0,item['h']/2),(item['w'],item['d'],item['h']),15,'85_Collision')
 ob.matrix_world=Matrix.Translation((item['x'],item['y'],0))@Matrix.Rotation(item['angle'],4,'Z')
for side in [-1,1]:
 box('COL_Torii_'+str(side),(side*35.3,65,17.5),(4.2,4.2,35),15,'85_Collision')
 for y in [-54,16]:lathe('COL_Street_Tree_%s_%s'%(side,y),[(1.2,0),(1.2,19)],(side*44.2,y,0),15,'85_Collision',n=8)
box('COL_Bridge',(0,126,1.15),(40,25,2.3),15,'85_Collision')
box('COL_Palace_Gatehouse',(0,147,12),(34,25,24),15,'85_Collision')
box('COL_Palace_Pedestal',(0,177,30),(55,55,60),15,'85_Collision')
for ob in collection('85_Collision').objects:ob.hide_render=True;ob['Roblox_CanCollide']=True;ob['Roblox_Transparency']=1
bpy.context.view_layer.update();collection('85_Collision').hide_render=True;collection('85_Collision').hide_viewport=True
sc['Combat_Size']='64 x 64 Blender units';sc['Interpretation']='Simplified Wano Flower Capital street with red torii, castle, curved cherry tree and mountains'
sc.camera=bpy.data.objects['WA_Camera_Hero'];sc.render.resolution_x=1700;sc.render.resolution_y=1500;sc.render.filepath=os.path.join(ROOT,'previews','Wano_Hero.png')
bpy.data.libraries.write(os.path.join(ROOT,'Wano_Flower_Capital_Editable.blend'),{sc},fake_user=True,compress=True)
bpy.ops.render.render(write_still=True)
print('Refined Wano scene and',len(collection('85_Collision').objects),'collision proxies')
