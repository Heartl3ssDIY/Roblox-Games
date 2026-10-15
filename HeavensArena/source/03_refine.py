exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\HeavensArena\source\common.py',encoding='utf-8').read(),'common.py','exec'))
sc=bpy.context.scene
for o in sc.objects:
 if o.type=='LIGHT':o.data.energy*=.24
# Convert authored sRGB palette samples to linear pixels before PNG encoding.
im=bpy.data.images['HA_ColorAtlas'];px=np.array(im.pixels[:],dtype=np.float32).reshape(1024,1024,4)
rgb=px[:,:,:3];px[:,:,:3]=np.where(rgb<=.04045,rgb/12.92,((rgb+.055)/1.055)**2.4)
im.pixels.foreach_set(px.ravel());im.save();im.pack()
for name,value in [('HA_NormalAtlas',(.5,.5,1)),('HA_RoughnessAtlas',(.8,.8,.8))]:
 im=bpy.data.images[name];im.colorspace_settings.name='Non-Color';data=np.ones((1024,1024,4),np.float32);data[:,:,:3]=value;im.pixels.foreach_set(data.ravel());im.save();im.pack()
# Solid backing beneath the terraces and a closed exterior shell.
for i in range(8):
 a=i*pi/4;b=Builder();steps=Builder();outer=Builder()
 for r0,r1,z0,z1 in [(79.8,98.8,2.05,13.2),(102.8,126.5,16.6,30.5)]:
  pts=[]
  for sign in [-1,1]:
   pts.extend([point(a,sign*r*tan(pi/8),r,z) for r,z in [(r0,-.3),(r1,-.3),(r1,z1),(r0,z0)]])
  for face in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]:b.face([pts[j] for j in face],5)
 for j in range(6):
  r=76+j*.667;z=(j+1)*3.4/6
  steps.radialbox(a,0,r+.333,z/2,7.6,.667,z,11)
  steps.radialbox(a,0,r+.045,z+.02,7.6,.09,.03,6)
 for j in range(5):
  r=98.8+j*.84;z=14.25+(j+1)*(.77)
  steps.radialbox(a,0,r+.42,z-.35,7.6,.84,.7,11)
  steps.radialbox(a,0,r+.045,z+.015,7.6,.09,.025,6)
 # Outer wall beneath upper gallery.
 outer.radialbox(a,0,130,14.8,2*130*tan(pi/8),1.3,32,5)
 for z in [1,15.5,31.5]:outer.radialbox(a,0,130.8,z,2*130*tan(pi/8),.3,.65,4)
 for u in [-42,-21,0,21,42]:outer.radialbox(a,u,130.8,15,.7,.3,31,4)
 b.build('HA_Stand_Foundation%02d'%(i+1),'16_Solid_Structure')
 steps.build('HA_Stair_Connections%02d'%(i+1),'11_Stairs')
 outer.build('HA_Exterior_Shell%02d'%(i+1),'16_Solid_Structure')
sc.camera=bpy.data.objects['HA_Camera_Hero'];sc.render.filepath=os.path.join(ROOT,'previews','Heavens_Arena_Hero.png')
bpy.context.view_layer.update()
bpy.ops.render.render(write_still=True)
print('Refined structure, palette and lighting')
