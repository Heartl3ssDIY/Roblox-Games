import bpy,bmesh,math,random,os,json
import numpy as np
from math import sin,cos,pi,tan
from mathutils import Vector
ROOT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\HeavensArena'
random.seed(811)
PALETTE=[(99,147,165),(196,208,200),(120,167,151),(169,198,181),(42,57,64),(75,98,104),(203,178,129),(236,232,210),(244,246,235),(88,115,114),(56,100,117),(159,175,173),(169,101,65),(32,48,57),(217,220,204),(118,151,153)]
def collection(name):
 key='HA | '+name;c=bpy.data.collections.get(key)
 if c is None:c=bpy.data.collections.new(key);bpy.context.scene.collection.children.link(c)
 return c
def atlas():
 size=1024;tile=256;rng=np.random.default_rng(811);y,x=np.mgrid[0:tile,0:tile]/tile
 pix=np.ones((size,size,4),np.float32);rough=np.ones_like(pix);normal=np.ones_like(pix);normal[:,:,:3]=(.5,.5,1)
 for k,color in enumerate(PALETTE):
  shade=1+rng.normal(0,.007,(tile,tile))+.012*np.sin(x*38+y*21)*np.cos(y*41)
  if k==6:shade+=.05*np.sin(y*120+.8*np.sin(x*13))
  if k==1:shade+=.025*np.cos(y*17+x*15)
  rgb=np.clip(np.array(color)[None,None,:]/255*shade[:,:,None],0,1);row,col=divmod(k,4)
  pix[row*tile:(row+1)*tile,col*tile:(col+1)*tile,:3]=rgb
  rough[row*tile:(row+1)*tile,col*tile:(col+1)*tile,:3]=.7 if k in [0,2,3,4,5,10,13] else .86
 ims=[]
 for name,data in [('HA_ColorAtlas',pix),('HA_NormalAtlas',normal),('HA_RoughnessAtlas',rough)]:
  im=bpy.data.images.new(name,width=size,height=size,alpha=False);im.pixels.foreach_set(data.ravel());im.filepath_raw=os.path.join(ROOT,'textures',name+'.png');im.file_format='PNG';im.save();im.pack();ims.append(im)
 mat=bpy.data.materials.new('Heavens Arena | shared atlas');mat.use_nodes=True
 bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Roughness'].default_value=.8;bs.inputs['Specular IOR Level'].default_value=.25
 tx=mat.node_tree.nodes.new('ShaderNodeTexImage');tx.image=ims[0];mat.node_tree.links.new(tx.outputs['Color'],bs.inputs['Base Color'])
 # Flat normal and broad roughness maps remain portable across renderers.
 nr=mat.node_tree.nodes.new('ShaderNodeTexImage');nr.image=ims[1];nr.image.colorspace_settings.name='Non-Color'
 nm=mat.node_tree.nodes.new('ShaderNodeNormalMap');mat.node_tree.links.new(nr.outputs['Color'],nm.inputs['Color']);mat.node_tree.links.new(nm.outputs['Normal'],bs.inputs['Normal'])
 rr=mat.node_tree.nodes.new('ShaderNodeTexImage');rr.image=ims[2];rr.image.colorspace_settings.name='Non-Color';mat.node_tree.links.new(rr.outputs['Color'],bs.inputs['Roughness'])
 glow=mat.copy();glow.name='Heavens Arena | stadium lamps'
 gb=next(n for n in glow.node_tree.nodes if n.type=='BSDF_PRINCIPLED');gb.inputs['Emission Color'].default_value=(.84,.93,1,1);gb.inputs['Emission Strength'].default_value=3
 return mat,glow
MAT=bpy.data.materials.get('Heavens Arena | shared atlas');GLOW=bpy.data.materials.get('Heavens Arena | stadium lamps')
class Builder:
 def __init__(self):self.v=[];self.f=[];self.c=[]
 def face(self,pts,cat):
  n=len(self.v);self.v.extend([tuple(p) for p in pts]);self.f.append(tuple(range(n,n+len(pts))));self.c.append(cat)
 def box(self,loc,dim,cat,a=0):
  x,y,z=[d/2 for d in dim]
  vs=[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]
  vs=[(loc[0]+v[0]*cos(a)-v[1]*sin(a),loc[1]+v[0]*sin(a)+v[1]*cos(a),loc[2]+v[2]) for v in vs]
  for f in [(3,2,1,0),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)]:self.face([vs[i] for i in f],cat)
 def radialbox(self,a,u,r,z,du,dr,dz,cat):
  self.box((r*cos(a)-u*sin(a),r*sin(a)+u*cos(a),z),(dr,du,dz),cat,a)
 def sector(self,a,r0,r1,z0,z1,cat,ufrac=1):
  # Closed trapezoidal slab spanning one octagon side.
  verts=[]
  for z in [z0,z1]:
   for r,u in [(r0,-r0*tan(pi/8)*ufrac),(r1,-r1*tan(pi/8)*ufrac),(r1,r1*tan(pi/8)*ufrac),(r0,r0*tan(pi/8)*ufrac)]:
    verts.append((r*cos(a)-u*sin(a),r*sin(a)+u*cos(a),z))
  for f in [(3,2,1,0),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)]:self.face([verts[i] for i in f],cat)
 def beam(self,a,b,r,cat,n=6):
  av=Vector(a);bv=Vector(b);t=(bv-av).normalized();ref=Vector((0,0,1)) if abs(t.z)<.9 else Vector((0,1,0));u=t.cross(ref).normalized();v=t.cross(u).normalized()
  p=[[c+r*(u*cos(i*2*pi/n)+v*sin(i*2*pi/n)) for i in range(n)] for c in [av,bv]]
  self.face(list(reversed(p[0])),cat);self.face(p[1],cat)
  for i in range(n):self.face([p[0][i],p[0][(i+1)%n],p[1][(i+1)%n],p[1][i]],cat)
 def build(self,name,group,material=None):
  me=bpy.data.meshes.new(name);me.from_pydata(self.v,[],self.f);me.update();ob=bpy.data.objects.new(name,me);collection(group).objects.link(ob);me.materials.append(material or MAT)
  layer=me.uv_layers.new(name='UVMap')
  for p in me.polygons:
   cat=self.c[p.index];axes=[i for i in range(3) if i!=max(range(3),key=lambda j:abs(p.normal[j]))]
   pts=[me.vertices[v].co for v in p.vertices];lo=[min(v[a] for v in pts) for a in axes];hi=[max(v[a] for v in pts) for a in axes]
   for li in p.loop_indices:
    v=me.vertices[me.loops[li].vertex_index].co
    uv=[(v[a]-lo[j])/max(hi[j]-lo[j],.0001) for j,a in enumerate(axes)]
    layer.data[li].uv=((cat%4+.015+.97*uv[0])/4,(cat//4+.015+.97*uv[1])/4)
  return ob
def singlebox(name,loc,dim,cat,group):
 b=Builder();b.box(loc,dim,cat);return b.build(name,group)
def point(a,u,r,z):return (r*cos(a)-u*sin(a),r*sin(a)+u*cos(a),z)
def camera(name,loc,target,lens=45,ortho=None):
 d=bpy.data.cameras.new(name);o=bpy.data.objects.new(name,d);collection('90_Presentation').objects.link(o);o.location=loc;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();d.lens=lens;d.clip_end=2000
 if ortho:d.type='ORTHO';d.ortho_scale=ortho
 return o
