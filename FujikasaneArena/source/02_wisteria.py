exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\FujikasaneArena\source\common.py',encoding='utf-8').read(),'common.py','exec'))
flower_mat=MAT.copy();flower_mat.name='Fujikasane | softly luminous wisteria'
bs=next(n for n in flower_mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');tex=next(n for n in flower_mat.node_tree.nodes if n.type=='TEX_IMAGE')
flower_mat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Emission Color']);bs.inputs['Emission Strength'].default_value=.15;bs.inputs['Roughness'].default_value=.9
def canopy_lobe(builder,center,scale,cat,rng):
 seg=9;rings=4;pts=[Vector(center)+Vector((0,0,scale[2]))]
 for j in range(1,rings):
  a=pi*j/rings
  for i in range(seg):
   b=2*pi*i/seg;r=rng.uniform(.88,1.1);pts.append(Vector(center)+Vector((scale[0]*sin(a)*cos(b)*r,scale[1]*sin(a)*sin(b)*r,scale[2]*cos(a))))
 pts.append(Vector(center)-Vector((0,0,scale[2])));end=len(pts)-1
 for i in range(seg):builder.face([pts[0],pts[1+i],pts[1+(i+1)%seg]],cat)
 for j in range(rings-2):
  for i in range(seg):
   a=1+j*seg+i;b=1+j*seg+(i+1)%seg
   builder.face([pts[a],pts[b],pts[b+seg],pts[a+seg]],cat if j==0 else max(10,cat-1))
 for i in range(seg):builder.face([pts[end],pts[end-seg+(i+1)%seg],pts[end-seg+i]],max(10,cat-1))
def raceme(builder,origin,length,width,rng):
 origin=Vector(origin)
 levels=9
 for j in range(levels):
  t=j/(levels-1);radius=width*(1-t*.87);p=origin+Vector((.16*sin(t*3+rng.random()),.13*sin(t*4),-length*t))
  for k in range(4 if j<3 else 3):
   a=k*2*pi/(4 if j<3 else 3)+j*1.73+rng.uniform(-.2,.2)
   d=Vector((cos(a),sin(a),0));side=Vector((-sin(a),cos(a),0));center=p+d*(radius*.37)
   w=radius*.76;h=length/levels*.72
   tip=center+d*(radius*.55)-Vector((0,0,h*.64))
   top=center+Vector((0,0,h*.46))
   left=center-side*w;right=center+side*w
   cat=rng.choice([11,12,12,13]) if j<5 else rng.choice([10,11,12])
   builder.face([top,left,tip],cat,True);builder.face([top,tip,right],cat,True)
def tree(index,x,y,h,seed):
 rng=random.Random(seed);base=ground_height(x,y);g='20_Tree_%02d'%index;flowers='21_Blossoms_%02d'%index
 # Coiling multi-stem trunk and exposed roots.
 main=[(x+.7*sin(j*.7),y+.6*cos(j*.9),base+j*h/8) for j in range(9)]
 tube('Twisted_wisteria_trunk',main,[1.55,1.25,1.08,.97,.79,.61,.45,.29,.07],3,g,10)
 for strand in range(2):
  pts=[]
  for j in range(15):
   t=j/14;a=t*5+strand*pi
   pts.append((x+.67*cos(a),y+.67*sin(a),base+t*h*.76))
  tube('Coiling_trunk_strand',pts,[.5*(1-j/17) for j in range(15)],3,g,7)
 for k in range(7):
  a=k*2*pi/7+rng.uniform(-.2,.2);rr=rng.uniform(3,5)
  tube('Spreading_surface_root',[(x,y,base+1.3),(x+rr*.55*cos(a),y+rr*.55*sin(a),base+.2),(x+rr*cos(a),y+rr*sin(a),ground_height(x+rr*cos(a),y+rr*sin(a))+.08)],[.57,.32,.035],3,g,7)
 f=Builder()
 for k in range(9):
  a=2*pi*k/9+rng.uniform(-.2,.2);reach=rng.uniform(8.2,13)
  start=Vector((x,y,base+h*.47));mid=Vector((x+reach*.53*cos(a-.1),y+reach*.53*sin(a-.1),base+h*.87))
  tip=Vector((x+reach*cos(a),y+reach*sin(a),base+h+rng.uniform(-1.7,2)))
  tube('Broad_crooked_branch',[start,mid,tip],[.61,.32,.07],3,g,8)
  for side in [-1,1]:
   fork=tip+Vector((2.4*cos(a+side*.9),2.4*sin(a+side*.9),-.1))
   tube('Fine_outer_branch',[mid,tip,fork],[.23,.1,.025],3,g,6)
  # The upper mass is broken into overlapping small flower pillows rather than a round tree crown.
  for j in range(4):
   a2=rng.uniform(0,2*pi);rr=rng.uniform(.1,2.6);center=tip+Vector((rr*cos(a2),rr*sin(a2),rng.uniform(-.2,.8)))
   canopy_lobe(f,center,(rng.uniform(1.5,2.5),rng.uniform(1.5,2.4),rng.uniform(.65,1.2)),rng.choice([11,12,13]),rng)
  for j in range(11):
   a2=rng.uniform(0,2*pi);rr=rng.uniform(.3,3.7)
   p=tip+Vector((rr*cos(a2),rr*sin(a2),rng.uniform(-.4,.5)))
   length=rng.uniform(4.3,8.8);raceme(f,p,length,rng.uniform(.42,.72),rng)
 # A few pendants beneath the centre of the crown.
 for j in range(16):
  a=rng.uniform(0,2*pi);rr=rng.uniform(0,7)
  raceme(f,(x+rr*cos(a),y+rr*sin(a),base+h+rng.uniform(-1.5,1.7)),rng.uniform(3,6.5),rng.uniform(.42,.65),rng)
 ob=f.build('Wisteria_cascades_%02d'%index,flowers);ob.data.materials.clear();ob.data.materials.append(flower_mat)
 ob['Role']='Modeled wisteria flower clusters, not billboard foliage.'
 # A dark sparse leaf layer peeks through the blossoms.
 leaves=Builder()
 for j in range(120):
  a=rng.uniform(0,2*pi);rr=rng.uniform(3,11);p=Vector((x+rr*cos(a),y+rr*sin(a),base+h+rng.uniform(-1.8,.2)))
  d=Vector((cos(a),sin(a),.15));v=Vector((-sin(a),cos(a),0));w=rng.uniform(.18,.32)
  leaves.face([p-d*.75,p-v*w,p+d*.75,p+v*w],9,True)
 leaves.build('Small_wisteria_leaflets',g)
positions=[]
for side in [-1,1]:
 for j,y in enumerate([-62,-33,-3,28,59]):positions.append((side*(57+(-1 if j%2 else 2)),y,25+(j%3)*1.8))
for x,y,h in [(-30,86,26),(0,91,27),(30,86,25),(-32,-83,24),(32,-83,26)]:positions.append((x,y,h))
for i,(x,y,h) in enumerate(positions):tree(i,x,y,h,190+i*11)
# Scattered fallen blossom petals on the earth.
petals=Builder();rng=random.Random(120)
for i in range(1000):
 x=rng.uniform(-68,68);y=rng.uniform(-83,90)
 if (x/77)**2+(y/102)**2>.96:continue
 if abs(x)<30 and abs(y)<32 and rng.random()<.93:continue
 z=ground_height(x,y)+.07
 if abs(x)<7:z=max(z,.073)
 a=rng.uniform(0,2*pi);d=Vector((cos(a),sin(a),0));v=Vector((-sin(a),cos(a),0));p=Vector((x,y,z))
 petals.face([p-d*.18,p-v*.10,p+d*.2,p+v*.1],rng.choice([11,12,13]))
petals.build('Fallen_wisteria_petals','22_Petal_Scatter')
for side in [-1,1]:
 area('FK_Wisteria_Side_Glow_'+str(side),(side*62,-5,35),(side*47,8,18),40000,(.73,.46,1),48)
sc=bpy.context.scene
for screen in bpy.data.screens:
 for a in screen.areas:
  if a.type=='VIEW_3D':
   a.spaces.active.region_3d.view_perspective='CAMERA';a.spaces.active.overlay.show_overlays=False;a.spaces.active.shading.type='MATERIAL'
sc.camera=bpy.data.objects['FK_Camera_Hero'];sc.render.filepath=os.path.join(ROOT,'previews','Fujikasane_Hero.png')
bpy.data.libraries.write(os.path.join(ROOT,'Fujikasane_Arena_Editable.blend'),{sc},fake_user=True,compress=True)
bpy.ops.render.render(write_still=True)
print('Built',len(positions),'wisteria trees and rendered hero')
