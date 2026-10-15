import bpy,bmesh,math,random,os,json
import numpy as np
from math import sin,cos,pi
from mathutils import Vector
ROOT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\FujikasaneArena'
PALETTE=[(85,77,86),(137,144,156),(100,111,132),(68,53,72),(157,37,57),(33,30,45),(223,222,232),(106,116,147),(60,90,72),(46,69,73),(109,63,160),(157,98,207),(192,145,234),(228,196,250),(103,89,100),(139,107,189)]
random.seed(529)
def collection(name):
 name='FK | '+name;c=bpy.data.collections.get(name)
 if c is None:c=bpy.data.collections.new(name);bpy.context.scene.collection.children.link(c)
 return c
def make_atlas():
 size=2048;tile=512;rng=np.random.default_rng(44);pix=np.ones((size,size,4),np.float32);y,x=np.mgrid[0:tile,0:tile]/tile
 for k,color in enumerate(PALETTE):
  shade=1+.05*np.sin(x*19+y*9)*np.cos(y*27-x*6)+rng.normal(0,.018,(tile,tile))
  if k in [0,14]:shade+=.06*np.sin(x*87+y*65)*np.cos(y*66)+.025*np.sin(x*173-y*98)
  if k==3:shade+=.16*np.sin(x*90+np.sin(y*16)*2)+.08*np.sin(x*167+y*10)
  if k==4:shade=1+.035*np.sin(x*37)+rng.normal(0,.007,(tile,tile))
  if k>=10 and k!=14:shade=1+.09*np.sin(x*pi)*np.sin(y*pi)+.015*np.cos(y*31)
  rgb=np.clip(np.array(color)[None,None,:]/255*shade[:,:,None],0,1)
  if k==6:
   dx=x-.5;dy=y-.51;rad=np.sqrt(dx*dx+dy*dy)
   ink=(abs(rad-.32)<.012)
   # Stylized circular floral emblem, inspired by the reference's pale banner marks.
   for a in np.linspace(0,2*pi,7,endpoint=False):
    px=.22*cos(a);py=.22*sin(a)
    ux=(dx-px)*cos(a)+(dy-py)*sin(a);uy=-(dx-px)*sin(a)+(dy-py)*cos(a)
    ink|=((ux/.092)**2+(uy/.041)**2<1)
   ink|=(abs(rad-.12)<.011)
   for a in [-.55,0,.55]:
    ink|=((abs(dx-.13*np.sin((dy+.15)*9+a)))<.009)&(dy>-.2)&(dy<.16)
   rgb[ink]=np.array(PALETTE[7])/255
  row,col=divmod(k,4);pix[row*tile:(row+1)*tile,col*tile:(col+1)*tile,:3]=rgb
 im=bpy.data.images.new('FK_ColorAtlas_2048',width=size,height=size,alpha=False);im.pixels.foreach_set(pix.ravel());im.filepath_raw=os.path.join(ROOT,'textures','FK_ColorAtlas.png');im.file_format='PNG';im.save();im.pack()
 mat=bpy.data.materials.new('Fujikasane | shared painted atlas');mat.use_nodes=True;bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
 bs.inputs['Roughness'].default_value=.86;bs.inputs['Specular IOR Level'].default_value=.25
 tx=mat.node_tree.nodes.new('ShaderNodeTexImage');tx.image=im;mat.node_tree.links.new(tx.outputs['Color'],bs.inputs['Base Color'])
 return mat
MAT=bpy.data.materials.get('Fujikasane | shared painted atlas')
def atlas_uv(ob,cats):
 me=ob.data;uv=me.uv_layers.active or me.uv_layers.new(name='UVMap')
 for p in me.polygons:
  cat=cats[p.index] if isinstance(cats,list) else cats
  dominant=max(range(3),key=lambda i:abs(p.normal[i]));axes=[1,2] if dominant==0 else [0,2] if dominant==1 else [0,1]
  pts=[me.vertices[v].co for v in p.vertices];lo=[min(v[a] for v in pts) for a in axes];hi=[max(v[a] for v in pts) for a in axes]
  for li in p.loop_indices:
   v=me.vertices[me.loops[li].vertex_index].co;q=[(v[a]-lo[j])/max(hi[j]-lo[j],.001) for j,a in enumerate(axes)]
   uv.data[li].uv=((cat%4+.018+.964*q[0])/4,(cat//4+.018+.964*q[1])/4)
def mesh(name,verts,faces,cat,group,smooth=False):
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();ob=bpy.data.objects.new(name,me);collection(group).objects.link(ob);me.materials.append(MAT);atlas_uv(ob,cat)
 for p in me.polygons:p.use_smooth=smooth
 return ob
class Builder:
 def __init__(self):self.v=[];self.f=[];self.c=[]
 def face(self,pts,cat,double=False):
  n=len(self.v);self.v.extend([tuple(p) for p in pts]);f=tuple(range(n,n+len(pts)));self.f.append(f);self.c.append(cat)
  if double:self.f.append(tuple(reversed(f)));self.c.append(cat)
 def build(self,name,group):return mesh(name,self.v,self.f,self.c,group)
def box(name,loc,dim,cat,group,bevel=0):
 x,y,z=[v/2 for v in dim];v=[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]
 f=[(3,2,1,0),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)]
 ob=mesh(name,v,f,cat,group);ob.location=loc
 if bevel:
  bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.bevel(bm,geom=list(bm.edges),offset=bevel,segments=1);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(ob.data);bm.free();ob.data.update();atlas_uv(ob,cat)
 return ob
def tube(name,points,radii,cat,group,sides=9):
 vs=[];fs=[]
 for j,pt in enumerate(points):
  p=Vector(pt);t=(Vector(points[min(j+1,len(points)-1)])-Vector(points[max(0,j-1)])).normalized()
  ref=Vector((0,0,1)) if abs(t.z)<.95 else Vector((0,1,0));u=t.cross(ref).normalized();v=t.cross(u).normalized()
  r=radii[j] if isinstance(radii,list) else radii
  for i in range(sides):vs.append(tuple(p+r*(cos(i*2*pi/sides)*u+sin(i*2*pi/sides)*v)))
 for j in range(len(points)-1):
  for i in range(sides):
   a=j*sides+i;b=j*sides+(i+1)%sides;fs.append((a,b,b+sides,a+sides))
 fs.append(tuple(reversed(range(sides))));fs.append(tuple((len(points)-1)*sides+i for i in range(sides)))
 return mesh(name,vs,fs,cat,group,True)
def beam(name,a,b,r,cat,group,sides=8):return tube(name,[a,b],r,cat,group,sides)
def lathe(name,profile,loc,cat,group,n=48):
 vs=[];fs=[]
 for r,z in profile:
  for i in range(n):vs.append((loc[0]+r*cos(i*2*pi/n),loc[1]+r*sin(i*2*pi/n),loc[2]+z))
 for j in range(len(profile)-1):
  for i in range(n):
   a=j*n+i;b=j*n+(i+1)%n;fs.append((a,b,b+n,a+n))
 ob=mesh(name,vs,fs,cat,group,True)
 bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001);bm.to_mesh(ob.data);bm.free()
 return ob
def rock(name,loc,scale,group,seed,cat=2):
 rng=random.Random(seed);seg=9;vs=[];fs=[]
 for j in range(4):
  z=[-.15,.08,.65,1][j]
  for i in range(seg):
   a=2*pi*i/seg+.14*(j%2);rad=[.78,1,.86,.45][j]*rng.uniform(.83,1.14)
   vs.append((scale[0]*rad*cos(a),scale[1]*rad*sin(a),scale[2]*(z+rng.uniform(-.11,.11))))
 for j in range(3):
  for i in range(seg):
   a=j*seg+i;b=j*seg+(i+1)%seg
   fs.extend([(a,b,b+seg),(a,b+seg,a+seg)])
 fs.append(tuple(reversed(range(seg))));fs.append(tuple(range(seg*3,seg*4)))
 ob=mesh(name,vs,fs,cat,group);ob.location=loc
 return ob
def join_batch(obs,name):
 bpy.ops.object.select_all(action='DESELECT')
 for o in obs:o.select_set(True)
 bpy.context.view_layer.objects.active=obs[0]
 if len(obs)>1:bpy.ops.object.join()
 o=obs[0];o.name=name;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);return o
def camera(name,loc,target,lens=45):
 d=bpy.data.cameras.new(name);ob=bpy.data.objects.new(name,d);collection('90_Presentation').objects.link(ob);ob.location=loc;ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler();d.lens=lens;d.clip_end=2200;return ob
def area(name,loc,target,energy,color,size):
 d=bpy.data.lights.new(name,'AREA');d.energy=energy;d.color=color;d.shape='DISK';d.size=size
 ob=bpy.data.objects.new(name,d);collection('90_Presentation').objects.link(ob);ob.location=loc;ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler()
def ground_height(x,y):
 edge=max(abs(x)-43,y-63,0)
 base=max(0,edge*.34+.8*sin(x*.13)*sin(y*.17)*min(1,edge/8))
 def smooth(t):
  t=max(0,min(1,t));return t*t*(3-2*t)
 wx=1-smooth((abs(x)-12)/16)
 wy=1-smooth((y-80)/14)
 base*=1-wx*wy
 if y<-76:base-=2.4*smooth((-76-y)/8)*wx
 return base
