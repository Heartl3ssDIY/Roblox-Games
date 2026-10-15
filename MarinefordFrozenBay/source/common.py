import bpy,bmesh,math,random,os,json
import numpy as np
from math import sin,cos,pi
from mathutils import Vector
ROOT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\MarinefordFrozenBay'
PALETTE=[(173,216,229),(211,237,242),(226,242,244),(105,163,188),(184,197,201),(223,226,219),(36,56,77),(49,62,77),(117,89,68),(72,59,53),(141,61,57),(30,40,49),(189,158,86),(132,157,174),(238,248,247),(64,97,150)]
def collection(name):
 key='MF | '+name;c=bpy.data.collections.get(key)
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
  rough[row*tile:(row+1)*tile,col*tile:(col+1)*tile,:3]=.3 if k in [0,1,2,3] else .72
 ims=[]
 for name,data in [('MF_ColorAtlas',pix),('MF_NormalAtlas',normal),('MF_RoughnessAtlas',rough)]:
  im=bpy.data.images.new(name,width=size,height=size,alpha=False)
  if name!='MF_ColorAtlas':im.colorspace_settings.name='Non-Color'
  im.pixels.foreach_set(data.ravel());im.filepath_raw=os.path.join(ROOT,'textures',name+'.png');im.file_format='PNG';im.save();im.pack();ims.append(im)
 m=bpy.data.materials.new('Marineford | stone and ice');m.use_nodes=True;b=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
 b.inputs['Specular IOR Level'].default_value=.3
 tx=m.node_tree.nodes.new('ShaderNodeTexImage');tx.image=ims[0];m.node_tree.links.new(tx.outputs['Color'],b.inputs['Base Color'])
 tx=m.node_tree.nodes.new('ShaderNodeTexImage');tx.image=ims[2];m.node_tree.links.new(tx.outputs['Color'],b.inputs['Roughness'])
 tx=m.node_tree.nodes.new('ShaderNodeTexImage');tx.image=ims[1];nm=m.node_tree.nodes.new('ShaderNodeNormalMap');m.node_tree.links.new(tx.outputs['Color'],nm.inputs['Color']);m.node_tree.links.new(nm.outputs['Normal'],b.inputs['Normal'])
 gold=m.copy();gold.name='Marineford | metal';gb=next(n for n in gold.node_tree.nodes if n.type=='BSDF_PRINCIPLED');gb.inputs['Metallic'].default_value=.48
 glass=bpy.data.materials.get('MF_Glass') or bpy.data.materials.new('MF_Glass');glass.use_nodes=True;b=next(n for n in glass.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
 b.inputs['Base Color'].default_value=(.36,.74,.59,1);b.inputs['Roughness'].default_value=.16;b.inputs['Alpha'].default_value=.19;b.inputs['Metallic'].default_value=.05
 glass.surface_render_method='BLENDED';glass.use_backface_culling=True
 return m,gold,glass
MAT=bpy.data.materials.get('Marineford | stone and ice');GOLD=bpy.data.materials.get('Marineford | metal');GLASS=bpy.data.materials.get('MF_Glass')
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
  for i in range(n):vs.append(tuple(Vector(pt)+(r[j] if isinstance(r,list) else r)*(u*cos(i*2*pi/n)+v*sin(i*2*pi/n))))
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

from mathutils import Matrix
random.seed(927)
BUILDING_BOUNDS=[]
def roof(name,w,d,z,h,cat,group):
 b=Builder()
 def zz(x,y):return z+h*(1-abs(x/(w/2)))**1.55+1.25*abs(x/(w/2))**8+.65*abs(y/(d/2))**6
 xx=np.linspace(-w/2,w/2,17)
 for j in range(len(xx)-1):
  a=xx[j];c=xx[j+1]
  b.face([(a,-d/2,zz(a,-d/2)),(c,-d/2,zz(c,-d/2)),(c,d/2,zz(c,d/2)),(a,d/2,zz(a,d/2))],cat)
 for y,rev in [(-d/2,False),(d/2,True)]:
  pts=[(-w/2,y,z-.3),(w/2,y,z-.3)]+[(x,y,zz(x,y)) for x in reversed(xx)]
  if rev:pts.reverse()
  b.face(pts,cat)
 ob=b.build(name,group)
 for y in [-d/2,d/2]:tube(name+'_Eave_'+str(y),[(x,y,zz(x,y)+.07) for x in xx],.18,cat,group,n=6)
 for y in np.arange(-d/2+2,d/2-1,2.4):tube(name+'_Tile_Ridge_'+str(round(y,1)),[(x,y,zz(x,y)+.06) for x in xx],.065,cat,group,n=5)
 tube(name+'_Top_Ridge',[(0,y,zz(0,y)+.16) for y in np.linspace(-d/2-1,d/2+1,17)],.28,cat,group,n=8)
 return ob
def ico(name,loc,scale,cat,group,sub=2):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1,location=(0,0,0));o=bpy.context.object;o.name=name
 for c in list(o.users_collection):c.objects.unlink(o)
 collection(group).objects.link(o)
 for v in o.data.vertices:
  n=1+random.uniform(-.07,.07);v.co=(loc[0]+v.co.x*scale[0]*n,loc[1]+v.co.y*scale[1]*n,loc[2]+v.co.z*scale[2]*n)
 o.data.materials.append(MAT);o.data.update();apply_uv(o,cat);return o
def blossom_tree(name,loc,scale=1):
 x,y,z=loc
 tube(name+'_Trunk',[(x,y,z),(x+.7*scale,y,z+5*scale),(x-.4*scale,y,z+9*scale),(x+1.2*scale,y+.5*scale,z+12*scale)],[.8*scale,.65*scale,.46*scale,.2*scale],3,'30_Cherry_Trunks',n=8)
 for j,(dx,dy,dz) in enumerate([(-4,0,11),(3,2,12),(0,-3,12),(-2,3,14),(3,-1,15)]):
  tube(name+'_Branch'+str(j),[(x,y,z+7*scale),(x+dx*.65*scale,y+dy*.65*scale,z+(dz-2)*scale),(x+dx*scale,y+dy*scale,z+dz*scale)],[.4*scale,.25*scale,.12*scale],3,'30_Cherry_Trunks',n=7)
  ico(name+'_Flowers'+str(j),(x+dx*scale,y+dy*scale,z+dz*scale),(4.3*scale,3.5*scale,2.6*scale),13 if j%2 else 6,'31_Cherry_Crowns')
def building(name,loc,w,d,h,cat,angle=0):
 before=set(bpy.data.objects);x,y=loc
 box(name+'_Plinth',(0,0,.45),(w+.8,d+.8,.9),12,'10_House_Bodies')
 box(name+'_Plaster',(0,0,h/2+.9),(w,d,h),1 if cat in [6,7] else 2,'10_House_Bodies')
 timber=Builder()
 for xx in [-w/2,w/2]:
  for yy in [-d/2,d/2]:timber.box((xx,yy,h/2+.9),(.45,.45,h+.3),3)
 for z in [1.2,h*.48,h+.8]:timber.box((0,-d/2-.06,z),(w+.4,.3,.38),3)
 timber.box((0,-d/2-.1,4),(3.8,.18,6.2),3)
 for xx in [-w*.3,w*.3]:
  timber.box((xx,-d/2-.13,h*.62),(w*.22,.18,h*.3),11)
  for ox in [-.6,0,.6]:timber.box((xx+ox,-d/2-.24,h*.62),(.09,.12,h*.3+.15),3)
 timber.build(name+'_Timber','11_Facades')
 roof(name+'_Roof',w+4,d+4,h+1.2,4.1,cat,'12_Roofs')
 # A small ground-floor awning and one simple hanging shop banner.
 box(name+'_Awning',(0,-d/2-1.3,7.8),(w*.8,2.8,.4),cat,'11_Facades')
 box(name+'_Banner',(w*.32,-d/2-1.5,5.6),(1.7,.14,3),6 if cat==8 else 8,'11_Facades')
 # Narrow white stripe is decorative, not text.
 box(name+'_Banner_Mark',(w*.32,-d/2-1.59,5.6),(.22,.03,1.5),14,'11_Facades')
 trans=Matrix.Translation((x,y,0))@Matrix.Rotation(angle,4,'Z')
 for o in bpy.data.objects:
  if o not in before:o.matrix_world=trans@o.matrix_world
 BUILDING_BOUNDS.append({'name':name,'x':x,'y':y,'w':w,'d':d,'h':h+2,'angle':angle})
def crag(name,loc,r,h,cat,group,n=13):
 x,y,z=loc;randoms=[random.uniform(.8,1.15) for _ in range(n)];v=[];f=[]
 for j,(rr,zz) in enumerate([(1,0),(1.04,.18),(.7,.55),(.63,.84),(.36,1)]):
  for i in range(n):
   a=i*2*pi/n;v.append((x+r*rr*randoms[i]*cos(a),y+r*rr*randoms[i]*sin(a),z+h*zz+(.8*sin(i*3) if j else 0)))
 for j in range(4):
  for i in range(n):
   a=j*n+i;b=j*n+(i+1)%n;f.append((a,b,b+n,a+n))
 f.append(tuple(reversed(range(n))));f.append(tuple(4*n+i for i in range(n)))
 return mesh(name,v,f,cat,group)
