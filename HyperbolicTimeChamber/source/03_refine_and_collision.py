exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\HyperbolicTimeChamber\source\common.py',encoding='utf-8').read(),'common.py','exec'))
sc=bpy.context.scene
# Keep the white field edge beyond all presentation cameras.
ob=bpy.data.objects['TC_White_Training_Expanse']
for v in ob.data.vertices:
 v.co.x*=2000/480;v.co.y=30+(v.co.y-30)*2000/480
ob.data.update()
floor=MAT.copy();floor.name='Time Chamber | white void floor'
bs=next(n for n in floor.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Emission Color'].default_value=(1,1,.98,1);bs.inputs['Emission Strength'].default_value=.42
ob.data.materials.clear();ob.data.materials.append(floor)
# Clean yellow-gold coating without a repeated stripe texture.
im=bpy.data.images['TC_ColorAtlas'];px=np.array(im.pixels[:],dtype=np.float32).reshape(1024,1024,4)
rgb=np.array((246,214,51))/255;rgb=np.where(rgb<=.04045,rgb/12.92,((rgb+.055)/1.055)**2.4)
px[256:512,0:256,:3]=rgb;im.pixels.foreach_set(px.ravel());im.save();im.pack()
gb=next(n for n in GOLD.node_tree.nodes if n.type=='BSDF_PRINCIPLED');gb.inputs['Metallic'].default_value=.32
gb=next(n for n in GLASS.node_tree.nodes if n.type=='BSDF_PRINCIPLED');gb.inputs['Alpha'].default_value=.25
profile=[(5.9,3.8),(6.1,4.5),(6.15,8),(5.9,11.8),(5.05,14.5),(3.3,16.5),(1.25,18.6),(.6,20),(.8,20.6),(2,21.6),(4.2,23.6),(5.6,26),(6.1,28.8),(6.1,34.3),(5.9,35.2)]
for side in [-1,1]:
 x=side*51
 for j,a in enumerate([0,pi]):
  tube('TC_Hourglass_Silhouette_%s_%s'%(side,j),[(x+r*cos(a),82+r*sin(a),z) for r,z in profile],.06,1,'21_Hourglass_Accents',n=6)
 ob=bpy.data.objects['TC_Upper_Green_Sand_'+str(side)]
 for v in ob.data.vertices:
  if v.co.z>32:v.co.z=34.3
 ob.data.update()
# Collision copies of convex architectural foundations; scenery stays separate.
box('COL_White_Training_Floor',(0,30,-.5),(2000,2000,1),14,'85_Collision')
terrace=[(-72,64),(72,64),(72,94),(69,100),(-69,100),(-72,94)]
slab('COL_Rear_Terrace',terrace,0,.625,14,'85_Collision')
for i,(r,z) in enumerate([(28,.6),(25,1.4),(22,2.2),(19,3)]):slab('COL_Curved_Step_%02d'%i,dshape(r),max(0,z-.8),z+.025,14,'85_Collision')
for side in [-1,1]:
 box('COL_Side_Room_'+str(side),(side*29,82,8.5),(23,24,11),14,'85_Collision')
 lathe('COL_Hourglass_'+str(side),[(6.5,.625),(6.5,35.5)],(side*51,82,0),14,'85_Collision',n=12)
 lathe('COL_Orb_Lamp_'+str(side),[(1.6,.625),(1.6,24.9)],(side*67,82,0),14,'85_Collision',n=8)
for j,t in enumerate(np.radians([210,250,290,330])):
 lathe('COL_Column_%s'%j,[(.9,3.025),(.9,22)],(17.65*cos(t),82+17.65*sin(t),0),14,'85_Collision',n=8)
box('COL_Rear_Interior_Wall',(0,98,12.5),(33.4,1,19),14,'85_Collision')
box('COL_Bench',(-8,85,4.15),(9,4,2.3),14,'85_Collision')
lathe('COL_Table',[(2.2,3.025),(2.2,9.85)],(8,84,0),14,'85_Collision',n=10)
for ob in collection('85_Collision').objects:ob.hide_render=True;ob['Roblox_Transparency']=1;ob['Roblox_CanCollide']=True
bpy.context.view_layer.update();collection('85_Collision').hide_render=True;collection('85_Collision').hide_viewport=True
sc.camera=bpy.data.objects['TC_Camera_Hero'];sc.render.resolution_x=1800;sc.render.resolution_y=1300;sc.render.filepath=os.path.join(ROOT,'previews','Time_Chamber_Hero.png')
bpy.data.libraries.write(os.path.join(ROOT,'Hyperbolic_Time_Chamber_Editable.blend'),{sc},fake_user=True,compress=True)
bpy.ops.render.render(write_still=True)
print('Refined materials and',len(collection('85_Collision').objects),'collision proxies')
