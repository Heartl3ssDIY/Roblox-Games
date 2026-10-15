import bpy, bmesh, math, random, os, json
import numpy as np
from math import sin,cos,pi
from mathutils import Vector
ROOT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\TournamentOfPower'
PALETTE=[(227,215,176),(186,125,77),(69,114,130),(157,133,77),(40,49,48),(116,137,132),(91,66,49),(183,186,162),(215,173,101),(39,70,79),(213,198,150),(132,99,63),(34,44,43),(122,153,154),(75,77,60),(188,162,122)]
def collection(name):
 name='TOP | '+name
 c=bpy.data.collections.get(name)
 if c is None:
  c=bpy.data.collections.new(name); bpy.context.scene.collection.children.link(c)
 return c
def make_atlas():
 size=2048; tile=512; rng=np.random.default_rng(731)
 pixels=np.ones((size,size,4),dtype=np.float32)
 y,x=np.mgrid[0:tile,0:tile]/tile
 for k,color in enumerate(PALETTE):
  shade=np.ones((tile,tile))
  for freq,amp in [(6,.016),(13,.011),(27,.008),(62,.006)]:
   shade+=amp*np.sin(x*freq+y*freq*.49+rng.uniform(0,6))*np.cos(y*freq*.8-x*freq*.22)
  shade+=rng.normal(0,.007,(tile,tile))
  rgb=np.clip(np.array(color)[None,None,:]/255*shade[:,:,None],0,1)
  row,col=divmod(k,4);pixels[row*tile:(row+1)*tile,col*tile:(col+1)*tile,:3]=rgb
 img=bpy.data.images.new('TOP_ColorAtlas_2048',width=size,height=size,alpha=False)
 img.pixels.foreach_set(pixels.ravel());img.filepath_raw=os.path.join(ROOT,'textures','TOP_ColorAtlas.png');img.file_format='PNG';img.save();img.pack()
 mat=bpy.data.materials.new('TOP | painted stone atlas');mat.use_nodes=True
 bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
 bs.inputs['Roughness'].default_value=.76;bs.inputs['Specular IOR Level'].default_value=.28
 tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=img
 mat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
 return mat
MAT=bpy.data.materials.get('TOP | painted stone atlas')
def mesh(name,verts,faces,cats,group,smooth=False):
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
 ob=bpy.data.objects.new(name,me);collection(group).objects.link(ob);me.materials.append(MAT)
 uv=me.uv_layers.new(name='UVMap')
 for p in me.polygons:
  cat=cats[p.index] if isinstance(cats,list) else cats
  dominant=max(range(3),key=lambda i:abs(p.normal[i]))
  axes=[1,2] if dominant==0 else [0,2] if dominant==1 else [0,1]
  coords=[me.vertices[me.loops[li].vertex_index].co for li in p.loop_indices]
  lo=[min(v[a] for v in coords) for a in axes];hi=[max(v[a] for v in coords) for a in axes]
  for li in p.loop_indices:
   v=me.vertices[me.loops[li].vertex_index].co
   q=[(v[a]-lo[i])/max(hi[i]-lo[i],.001) for i,a in enumerate(axes)]
   uv.data[li].uv=((cat%4+.015+q[0]*.97)/4,(cat//4+.015+q[1]*.97)/4)
  p.use_smooth=smooth
 ob['TOP_Module']=group
 return ob
class Builder:
 def __init__(self):self.v=[];self.f=[];self.c=[]
 def face(self,pts,cat,shrink=0):
  pts=[Vector(p) for p in pts]
  if shrink:
   center=sum(pts,Vector())/len(pts);pts=[center+(p-center)*(1-shrink) for p in pts]
  n=len(self.v);self.v.extend([tuple(p) for p in pts]);self.f.append(tuple(range(n,n+len(pts))));self.c.append(cat)
 def build(self,name,group):return mesh(name,self.v,self.f,self.c,group)
def polar(r,a,z):return (r*cos(a),r*sin(a),z)
def disk(name,r,z,cat,group,n=192):
 b=Builder()
 for i in range(n): b.face([(0,0,z),polar(r,2*pi*i/n,z),polar(r,2*pi*(i+1)/n,z)],cat)
 return b.build(name,group)
def ring(name,r1,r2,z1,z2,cat,group,n=192,start=0,end=2*pi,bottom=False):
 b=Builder()
 for i in range(n):
  a=start+(end-start)*i/n;c=start+(end-start)*(i+1)/n
  pts=[polar(r1,a,z1),polar(r2,a,z2),polar(r2,c,z2),polar(r1,c,z1)]
  b.face(list(reversed(pts)) if bottom else pts,cat if not isinstance(cat,list) else cat[i%len(cat)])
 return b.build(name,group)
def cylinder(name,r,z0,z1,cat,group,n=128,caps=True):
 b=Builder()
 for i in range(n):
  a=2*pi*i/n;c=2*pi*(i+1)/n
  b.face([polar(r,a,z0),polar(r,c,z0),polar(r,c,z1),polar(r,a,z1)],cat if not isinstance(cat,list) else cat[i%len(cat)])
 if caps:
  b.face([polar(r,2*pi*i/n,z1) for i in range(n)],cat[0] if isinstance(cat,list) else cat)
  b.face([polar(r,-2*pi*i/n,z0) for i in range(n)],cat[0] if isinstance(cat,list) else cat)
 return b.build(name,group)
def mosaic(name,r1,r2,z1,z2,count,kind,group,bottom=False):
 b=Builder()
 for i in range(count):
  a=2*pi*i/count;c=2*pi*(i+1)/count;m=(a+c)/2
  if kind=='teeth':
   parts=[([polar(r1,m,z1),polar(r2,a,z2),polar(r2,m,z2),polar(r2,c,z2)],1),([polar(r1,a,z1),polar(r2,a,z2),polar(r1,m,z1)],0),([polar(r1,m,z1),polar(r2,c,z2),polar(r1,c,z1)],0)]
  else:
   parts=[([polar(r1,a,z1),polar(r2,a,z2),polar(r2,m,z2),polar(r2,c,z2),polar(r1,c,z1),polar(r1,m,z1)],2 if i%2==0 else 3)]
  for pts,cat in parts:b.face(list(reversed(pts)) if bottom else pts,cat,.008)
 return b.build(name,group)
def arcsolid(name,r1,r2,z0,z1,cat,group,start=-.13*pi,end=1.13*pi,n=160):
 b=Builder()
 for i in range(n):
  a=start+(end-start)*i/n;c=start+(end-start)*(i+1)/n
  b.face([polar(r1,a,z1),polar(r2,a,z1),polar(r2,c,z1),polar(r1,c,z1)],cat)
  b.face([polar(r1,a,z0),polar(r1,c,z0),polar(r2,c,z0),polar(r2,a,z0)],cat)
  b.face([polar(r2,a,z0),polar(r2,c,z0),polar(r2,c,z1),polar(r2,a,z1)],cat)
  b.face([polar(r1,a,z0),polar(r1,a,z1),polar(r1,c,z1),polar(r1,c,z0)],cat)
 b.face([polar(r1,start,z0),polar(r2,start,z0),polar(r2,start,z1),polar(r1,start,z1)],cat)
 b.face([polar(r1,end,z0),polar(r1,end,z1),polar(r2,end,z1),polar(r2,end,z0)],cat)
 return b.build(name,group)
def camera(name,loc,target,lens=45):
 d=bpy.data.cameras.new(name);o=bpy.data.objects.new(name,d);collection('90_Presentation').objects.link(o)
 o.location=loc;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();d.lens=lens;d.clip_end=2500
 return o
def area(name,loc,target,power,color,size):
 d=bpy.data.lights.new(name,'AREA');d.energy=power;d.color=color;d.shape='DISK';d.size=size
 o=bpy.data.objects.new(name,d);collection('90_Presentation').objects.link(o);o.location=loc;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
def join_group(group,name):
 obs=[o for o in collection(group).objects if o.type=='MESH']
 if not obs:return
 bpy.ops.object.select_all(action='DESELECT')
 for o in obs:o.select_set(True)
 bpy.context.view_layer.objects.active=obs[0]
 if len(obs)>1:bpy.ops.object.join()
 obs[0].name=name
 return obs[0]
