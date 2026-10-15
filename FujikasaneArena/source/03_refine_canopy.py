exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\FujikasaneArena\source\common.py',encoding='utf-8').read(),'common.py','exec'))
from collections import Counter
terrain=bpy.data.objects['Forest_earth']
for v in terrain.data.vertices:v.co.z=ground_height(v.co.x,v.co.y)
terrain.data.update()
# Continuous planar earth UV avoids a separate repeating pattern on each ground triangle.
uv=terrain.data.uv_layers.active
for loop in terrain.data.loops:
 v=terrain.data.vertices[loop.vertex_index].co
 uv.data[loop.index].uv=((.025+(v.x+84)/168*.95)/4,(.025+(v.y+110)/220*.95)/4)
# Shift the approach camera inside the entrance cut to show the actual clearing.
sc=bpy.context.scene
cam=bpy.data.objects['FK_Camera_Approach'];cam.location=(0,-76,12);cam.rotation_euler=(Vector((0,29,15))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.lens=23
hero=bpy.data.objects['FK_Camera_Hero'];hero.location=(115,-202,190);hero.rotation_euler=(Vector((0,0,14))-hero.location).to_track_quat('-Z','Y').to_euler();hero.data.lens=42
# Retain the pendant petals, replace isolated flat tops with connected soft crowns.
for c in list(sc.collection.children):
 if not c.name.startswith('FK | 21_Blossoms_'):continue
 for ob in list(c.objects):
  me=ob.data;counts=Counter(tuple(sorted(p.vertices)) for p in me.polygons)
  remove=[p.index for p in me.polygons if counts[tuple(sorted(p.vertices))]==1]
  bm=bmesh.new();bm.from_mesh(me);bm.faces.ensure_lookup_table()
  bmesh.ops.delete(bm,geom=[bm.faces[i] for i in remove],context='FACES')
  bm.to_mesh(me);bm.free()
# Palette makes earth subdued and the blossoms violet rather than almost white.
img=bpy.data.images['FK_ColorAtlas_2048'];arr=np.array(img.pixels[:],dtype=np.float32).reshape(2048,2048,4)
for k,factor in [(0,(.72,.70,.72)),(14,(.8,.78,.78)),(11,(.85,.77,.98)),(12,(.91,.84,1)),(13,(.95,.88,1))]:
 row,col=divmod(k,4);arr[row*512:(row+1)*512,col*512:(col+1)*512,:3]*=np.array(factor)[None,None,:]
img.pixels.foreach_set(arr.ravel());img.filepath_raw=os.path.join(ROOT,'textures','FK_ColorAtlas.png');img.save();img.pack()
flower_mat=bpy.data.materials['Fujikasane | softly luminous wisteria']
# Dense crown meshes with irregular outline and a lower lavender edge.
def soft_crown(name,center,scale,group,seed):
 rng=random.Random(seed);seg=18;rings=9;verts=[(center[0],center[1],center[2]+scale[2])];faces=[];cats=[]
 for j in range(1,rings):
  a=pi*j/rings
  for i in range(seg):
   b=2*pi*i/seg;noise=1+.10*sin(b*5+j*.7)+rng.uniform(-.06,.06)
   verts.append((center[0]+scale[0]*sin(a)*cos(b)*noise,center[1]+scale[1]*sin(a)*sin(b)*noise,center[2]+scale[2]*cos(a)*(1+.06*sin(b*4))))
 verts.append((center[0],center[1],center[2]-scale[2]));end=len(verts)-1
 for i in range(seg):faces.append((0,1+i,1+(i+1)%seg));cats.append(12)
 for j in range(rings-2):
  for i in range(seg):
   a=1+j*seg+i;b=1+j*seg+(i+1)%seg;faces.append((a,b,b+seg,a+seg));cats.append(12 if j<3 else 11 if j<5 else 10)
 for i in range(seg):faces.append((end,end-seg+(i+1)%seg,end-seg+i));cats.append(10)
 ob=mesh(name,verts,faces,cats,group,True);ob.data.materials.clear();ob.data.materials.append(flower_mat);return ob
# A lower-detail supplemental strand adds mass without doubling the existing petal count.
def strand(b,origin,length,width,rng):
 origin=Vector(origin)
 for j in range(9):
  t=j/8;r=width*(1-.88*t);p=origin+Vector((.12*sin(t*4),.1*cos(t*5),-length*t))
  for k in range(3):
   a=k*2*pi/3+j*1.5;d=Vector((cos(a),sin(a),0));v=Vector((-sin(a),cos(a),0))
   q=p+d*r*.3;h=length/9
   b.face([q+Vector((0,0,h*.2)),q-v*r*.65,q+d*r*.5-Vector((0,0,h*.9)),q+v*r*.65],12 if j<4 else 11,True)
positions=[]
for side in [-1,1]:
 for j,y in enumerate([-62,-33,-3,28,59]):positions.append((side*(57+(-1 if j%2 else 2)),y,25+(j%3)*1.8))
positions += [(-30,86,26),(0,91,27),(30,86,25),(-32,-83,24),(32,-83,26)]
for index,(x,y,h) in enumerate(positions):
 base=ground_height(x,y);rng=random.Random(810+index);g='23_Canopy_%02d'%index
 soft_crown('Wisteria_crown_center',(x,y,base+h-.5),(8.9,8.7,3.4),g,70+index)
 for j in range(8):
  a=2*pi*j/8+.19*sin(index);r=8+rng.uniform(-.5,1.2)
  soft_crown('Wisteria_crown_lobe',(x+r*cos(a),y+r*sin(a),base+h+rng.uniform(-1,.8)),(5.4,5.1,rng.uniform(2.5,3.8)),g,index*31+j)
 f=Builder()
 for j in range(38):
  a=2*pi*j/38+rng.uniform(-.15,.15);r=rng.uniform(7,13)
  strand(f,(x+r*cos(a),y+r*sin(a),base+h-.5),rng.uniform(5.5,11),rng.uniform(.65,1),rng)
 ob=f.build('Fuller_draped_blossoms',g);ob.data.materials.clear();ob.data.materials.append(flower_mat)
sc.camera=hero;sc.render.resolution_x=1700;sc.render.resolution_y=1400;sc.render.filepath=os.path.join(ROOT,'previews','Fujikasane_Hero.png')
bpy.ops.render.render(write_still=True)
sc.camera=bpy.data.objects['FK_Camera_Approach'];sc.render.resolution_x=1600;sc.render.resolution_y=1100;sc.render.filepath=os.path.join(ROOT,'previews','Fujikasane_Approach.png');bpy.ops.render.render(write_still=True)
sc.camera=hero
print('Filled canopies, corrected path and rendered')
