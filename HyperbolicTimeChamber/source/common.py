import bpy,bmesh,math,random,os,json
import numpy as np
from math import sin,cos,pi
from mathutils import Vector
ROOT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\HyperbolicTimeChamber'
PALETTE=[(245,246,239),(189,217,222),(135,182,194),(58,86,108),(239,192,45),(172,119,30),(216,138,186),(162,86,147),(57,183,107),(133,225,165),(74,54,88),(246,234,190),(127,167,174),(227,194,224),(39,57,63),(252,252,249)]
def collection(name):
 key='TC | '+name;c=bpy.data.collections.get(key)
 if c is None:c=bpy.data.collections.new(key);bpy.context.scene.collection.children.link(c)
 return c
def make_materials():
 size=1024;tile=256;pix=np.ones((size,size,4),np.float32);rough=np.ones_like(pix);normal=np.ones_like(pix);normal[:,:,:3]=(.5,.5,1)
 y,x=np.mgrid[0:tile,0:tile]/tile;rng=np.random.default_rng(34)
 for k,color in enumerate(PALETTE):
  shade=1+rng.normal(0,.002,(tile,tile))
  if k in [4,5]:shade+=.035*np.sin(x*pi)
  if k in [6,7]:shade+=.012*np.sin(y*2*pi)
  rgb=np.clip(np.array(color)[None,None,:]/255*shade[:,:,None],0,1);rgb=np.where(rgb<=.04045,rgb/12.92,((rgb+.055)/1.055)**2.4)
  row,col=divmod(k,4);pix[row*tile:(row+1)*tile,col*tile:(col+1)*tile,:3]=rgb
  rough[row*tile:(row+1)*tile,col*tile:(col+1)*tile,:3]=.48 if k in [4,5,8,9] else .72
 ims=[]
 for name,data in [('TC_ColorAtlas',pix),('TC_NormalAtlas',normal),('TC_RoughnessAtlas',rough)]:
  im=bpy.data.images.new(name,width=size,height=size,alpha=False)
  if name!='TC_ColorAtlas':im.colorspace_settings.name='Non-Color'
  im.pixels.foreach_set(data.ravel());im.filepath_raw=os.path.join(ROOT,'textures',name+'.png');im.file_format='PNG';im.save();im.pack();ims.append(im)
 m=bpy.data.materials.new('Time Chamber | painted architecture');m.use_nodes=True;b=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
 b.inputs['Specular IOR Level'].default_value=.3
 tx=m.node_tree.nodes.new('ShaderNodeTexImage');tx.image=ims[0];m.node_tree.links.new(tx.outputs['Color'],b.inputs['Base Color'])
 tx=m.node_tree.nodes.new('ShaderNodeTexImage');tx.image=ims[2];m.node_tree.links.new(tx.outputs['Color'],b.inputs['Roughness'])
 tx=m.node_tree.nodes.new('ShaderNodeTexImage');tx.image=ims[1];nm=m.node_tree.nodes.new('ShaderNodeNormalMap');m.node_tree.links.new(tx.outputs['Color'],nm.inputs['Color']);m.node_tree.links.new(nm.outputs['Normal'],b.inputs['Normal'])
 gold=m.copy();gold.name='Time Chamber | brushed gold';gb=next(n for n in gold.node_tree.nodes if n.type=='BSDF_PRINCIPLED');gb.inputs['Metallic'].default_value=.48
 glass=bpy.data.materials.get('TC_Glass') or bpy.data.materials.new('TC_Glass');glass.use_nodes=True;b=next(n for n in glass.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
 b.inputs['Base Color'].default_value=(.36,.74,.59,1);b.inputs['Roughness'].default_value=.16;b.inputs['Alpha'].default_value=.19;b.inputs['Metallic'].default_value=.05
 glass.surface_render_method='BLENDED';glass.use_backface_culling=True
 return m,gold,glass
MAT=bpy.data.materials.get('Time Chamber | painted architecture');GOLD=bpy.data.materials.get('Time Chamber | brushed gold');GLASS=bpy.data.materials.get('TC_Glass')
def apply_uv(ob,cats):
 me=ob.data;layer=me.uv_layers.active or me.uv_layers.new(name='UVMap')
 for p in me.polygons:
  cat=cats[p.index] if isinstance(cats,list) else cats
  axes=[i for i in range(3) if i!=max(range(3),key=lambda j:abs(p.normal[j]))]
  pts=[me.vertices[v].co for v in p.vertices];lo=[min(v[a] for v in pts) for a in axes];hi=[max(v[a] for v in pts) for a in axes]
  for li in p.loop_indices:
   v=me.vertices[me.loops[li].vertex_index].co;q=[(v[a]-lo[j])/max(hi[j]-lo[j],.0001) for j,a in enumerate(axes)]
   layer.data[li].uv=((cat%4+.02+.96*q[0])/4,(cat//4+.02+.96*q[1])/4)
def mesh(name,vs,fs,cat,group,material=None,smooth=False):
 me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.update();ob=bpy.data.objects.new(name,me);collection(group).objects.link(ob);me.materials.append(material or MAT);apply_uv(ob,cat)
 for p in me.polygons:p.use_smooth=smooth
 return ob
class Builder:
 def __init__(self):self.v=[];self.f=[];self.c=[]
 def face(self,pts,cat):
  n=len(self.v);self.v.extend(tuple(p) for p in pts);self.f.append(tuple(range(n,n+len(pts))));self.c.append(cat)
 def box(self,loc,dim,cat):
  x,y,z=[d/2 for d in dim];v=[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)];v=[tuple(loc[j]+p[j] for j in range(3)) for p in v]
  for f in [(3,2,1,0),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)]:self.face([v[i] for i in f],cat)
 def build(self,name,group,material=None):return mesh(name,self.v,self.f,self.c,group,material)
def box(name,loc,dim,cat,group,material=None):
 b=Builder();b.box(loc,dim,cat);return b.build(name,group,material)
def lathe(name,profile,loc,cat,group,material=None,n=64):
 v=[];f=[]
 for r,z in profile:
  for i in range(n):v.append((loc[0]+r*cos(i*2*pi/n),loc[1]+r*sin(i*2*pi/n),loc[2]+z))
 for j in range(len(profile)-1):
  for i in range(n):
   a=j*n+i;b=j*n+(i+1)%n;f.append((a,b,b+n,a+n))
 f.append(tuple(reversed(range(n))));f.append(tuple((len(profile)-1)*n+i for i in range(n)))
 ob=mesh(name,v,f,cat,group,material,True)
 ob.data.polygons[-1].use_smooth=False;ob.data.polygons[-2].use_smooth=False
 return ob
def tube(name,points,r,cat,group,material=None,n=8):
 vs=[];fs=[]
 for j,pt in enumerate(points):
  t=(Vector(points[min(j+1,len(points)-1)])-Vector(points[max(0,j-1)])).normalized();ref=Vector((0,0,1)) if abs(t.z)<.95 else Vector((0,1,0));u=t.cross(ref).normalized();v=t.cross(u).normalized()
  for i in range(n):vs.append(tuple(Vector(pt)+r*(u*cos(i*2*pi/n)+v*sin(i*2*pi/n))))
 for j in range(len(points)-1):
  for i in range(n):
   a=j*n+i;b=j*n+(i+1)%n;fs.append((a,b,b+n,a+n))
 fs.append(tuple(reversed(range(n))));fs.append(tuple((len(points)-1)*n+i for i in range(n)))
 return mesh(name,vs,fs,cat,group,material,True)
def dome(name,r,h,z,loc,cat,group,material=None,n=64):
 profile=[(r*cos(t),z+h*sin(t)) for t in np.linspace(0,pi/2-.005,18)]
 return lathe(name,profile,loc,cat,group,material,n)
def slab(name,poly,z0,z1,cat,group):
 n=len(poly);v=[(x,y,z) for z in [z0,z1] for x,y in poly]
 f=[tuple(reversed(range(n))),tuple(range(n,2*n))]
 f.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
 return mesh(name,v,f,cat,group)
def dshape(r,cy=65,back=101):
 return [(r*cos(t),cy+r*sin(t)) for t in np.linspace(pi,2*pi,41)]+[(r,back),(-r,back)]
def clip(poly,bound):
 for j,a in enumerate(bound):
  b=bound[(j+1)%len(bound)];out=[]
  if not poly:break
  def d(p):return (b[0]-a[0])*(p[1]-a[1])-(b[1]-a[1])*(p[0]-a[0])
  for i,p in enumerate(poly):
   q=poly[(i+1)%len(poly)];dp=d(p);dq=d(q)
   if dp>=-1e-7:out.append(p)
   if (dp>=0)!=(dq>=0):
    t=dp/(dp-dq);out.append((p[0]+t*(q[0]-p[0]),p[1]+t*(q[1]-p[1])))
  poly=out
 return poly
def tiles(name,poly,z,group,step=3):
 b=Builder()
 for x in np.arange(math.floor(min(p[0] for p in poly)/step)*step,max(p[0] for p in poly),step):
  for y in np.arange(math.floor(min(p[1] for p in poly)/step)*step,max(p[1] for p in poly),step):
   p=clip([(x+.025,y+.025),(x+step-.025,y+.025),(x+step-.025,y+step-.025),(x+.025,y+step-.025)],poly)
   if len(p)>=3:b.face([(xx,yy,z) for xx,yy in p],1)
 return b.build(name,group)
def camera(name,loc,target,ortho=None,lens=45):
 d=bpy.data.cameras.new(name);o=bpy.data.objects.new(name,d);collection('90_Presentation').objects.link(o);o.location=loc;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();d.lens=lens;d.clip_end=3000
 if ortho:d.type='ORTHO';d.ortho_scale=ortho
 return o
