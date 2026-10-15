import bpy,bmesh,math,random,os,json
import numpy as np
from math import sin,cos,pi
from mathutils import Vector,Matrix
ROOT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\LoguetownArena'
PALETTE=[(205,193,164),(200,190,165),(237,224,192),(219,188,128),(193,150,142),(156,183,181),(48,102,126),(174,89,62),(49,58,61),(36,65,78),(116,181,190),(110,76,48),(80,135,67),(63,173,185),(184,141,69),(49,99,58)]
random.seed(4981)
def collection(name):
 name='LT | '+name;c=bpy.data.collections.get(name)
 if c is None:c=bpy.data.collections.new(name);bpy.context.scene.collection.children.link(c)
 return c
def make_atlas():
 size=2048;tile=512;rng=np.random.default_rng(72);pixels=np.ones((size,size,4),np.float32)
 y,x=np.mgrid[0:tile,0:tile]/tile
 for k,color in enumerate(PALETTE):
  shade=1+.022*np.sin(x*21+y*7)*np.cos(y*31)+rng.normal(0,.012,(tile,tile))
  if k==11:shade+=.085*np.sin(x*102+np.sin(y*11)*2)+.04*np.sin(x*233+y*3)
  if k in [6,7]:
   yy=(y*8)%1;xx=((x*5)+(np.floor(y*8)%2)*.5)%1
   shade-=.14*(yy<.035)+.07*(xx<.025);shade+=.035*np.sin(xx*pi)
  if k==13:shade+=.075*np.sin(x*32+np.cos(y*19)*2)*np.cos(y*43+x*10)
  row,col=divmod(k,4);pixels[row*tile:(row+1)*tile,col*tile:(col+1)*tile,:3]=np.clip(np.array(color)[None,None,:]/255*shade[:,:,None],0,1)
 im=bpy.data.images.new('LT_ColorAtlas_2048',width=size,height=size,alpha=False);im.pixels.foreach_set(pixels.ravel());im.filepath_raw=os.path.join(ROOT,'textures','LT_ColorAtlas.png');im.file_format='PNG';im.save();im.pack()
 m=bpy.data.materials.new('Loguetown | painted architectural atlas');m.use_nodes=True
 bs=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Roughness'].default_value=.81;bs.inputs['Specular IOR Level'].default_value=.24
 t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=im;m.node_tree.links.new(t.outputs['Color'],bs.inputs['Base Color'])
 return m
MAT=bpy.data.materials.get('Loguetown | painted architectural atlas')
def atlas_uv(ob,cat):
 me=ob.data;uv=me.uv_layers.active or me.uv_layers.new(name='UVMap')
 for p in me.polygons:
  dominant=max(range(3),key=lambda i:abs(p.normal[i]));axes=[1,2] if dominant==0 else [0,2] if dominant==1 else [0,1]
  coords=[me.vertices[v].co for v in p.vertices]
  lo=[min(v[a] for v in coords) for a in axes];hi=[max(v[a] for v in coords) for a in axes]
  for li in p.loop_indices:
   v=me.vertices[me.loops[li].vertex_index].co;q=[(v[a]-lo[j])/max(hi[j]-lo[j],.001) for j,a in enumerate(axes)]
   uv.data[li].uv=((cat%4+.018+q[0]*.964)/4,(cat//4+.018+q[1]*.964)/4)
def mesh(name,verts,faces,cat,group,smooth=False):
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
 ob=bpy.data.objects.new(name,me);collection(group).objects.link(ob);me.materials.append(MAT)
 atlas_uv(ob,cat);ob['surface']=cat
 for p in me.polygons:p.use_smooth=smooth
 return ob
def box(name,loc,dim,cat,group,bevel=0):
 x,y,z=[v/2 for v in dim];v=[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]
 f=[(3,2,1,0),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)]
 ob=mesh(name,v,f,cat,group);ob.location=loc
 if bevel:
  bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.bevel(bm,geom=list(bm.edges),offset=bevel,segments=1);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(ob.data);bm.free();ob.data.update();atlas_uv(ob,cat)
 return ob
def tube(name,points,r,cat,group,sides=8):
 vs=[];fs=[]
 for j,pt in enumerate(points):
  p=Vector(pt);t=(Vector(points[min(j+1,len(points)-1)])-Vector(points[max(j-1,0)])).normalized()
  ref=Vector((0,0,1)) if abs(t.z)<.95 else Vector((0,1,0));u=t.cross(ref).normalized();v=t.cross(u).normalized()
  rad=r[j] if isinstance(r,list) else r
  for i in range(sides):vs.append(tuple(p+rad*(cos(i*2*pi/sides)*u+sin(i*2*pi/sides)*v)))
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
 return mesh(name,vs,fs,cat,group,True)
def disk(name,r,z,x,y,cat,group,n=64):
 return mesh(name,[(x,y,z)]+[(x+r*cos(i*2*pi/n),y+r*sin(i*2*pi/n),z) for i in range(n)],[(0,1+i,1+(i+1)%n) for i in range(n)],cat,group)
def ellipsoid(name,loc,scale,cat,group,seg=12,rings=6):
 vs=[(0,0,scale[2])];fs=[]
 for j in range(1,rings):
  a=pi*j/rings
  for i in range(seg):
   b=2*pi*i/seg;vs.append((scale[0]*sin(a)*cos(b),scale[1]*sin(a)*sin(b),scale[2]*cos(a)))
 vs.append((0,0,-scale[2]));end=len(vs)-1
 for i in range(seg):fs.append((0,1+i,1+(i+1)%seg))
 for j in range(rings-2):
  for i in range(seg):
   a=1+j*seg+i;b=1+j*seg+(i+1)%seg;fs.append((a,b,b+seg,a+seg))
 for i in range(seg):fs.append((end,end-seg+(i+1)%seg,end-seg+i))
 ob=mesh(name,vs,fs,cat,group);ob.location=loc;return ob
def extrude(name,coords,y,depth,cat,group):
 vs=[(x,y-depth/2,z) for x,z in coords]+[(x,y+depth/2,z) for x,z in coords];n=len(coords)
 fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 ob=mesh(name,vs,fs,cat,group)
 bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(ob.data);bm.free()
 return ob
def archshape(x,z,w,h):
 r=w/2;shoulder=z+h-r
 return [(x-r,z),(x+r,z),(x+r,shoulder)]+[(x+r*cos(i*pi/12),shoulder+r*sin(i*pi/12)) for i in range(1,13)]
def archwindow(x,y,z,w,h,group,door=False,balcony=False):
 r=w/2;shoulder=z+h-r
 extrude('Arched_recess',archshape(x,z,w,h),y-.07,.1,9,group)
 for sign in [-1,1]:
  box('Window_stone_jamb',(x+sign*(r+.15),y-.14,(z+shoulder)/2),(.3,.34,shoulder-z),2,group)
 for i in range(12):
  a=i*pi/12;b=(i+1)*pi/12
  coords=[(x+r*cos(a),shoulder+r*sin(a)),(x+(r+.32)*cos(a),shoulder+(r+.32)*sin(a)),(x+(r+.32)*cos(b),shoulder+(r+.32)*sin(b)),(x+r*cos(b),shoulder+r*sin(b))]
  extrude('Arch_voussoir',coords,y-.14,.34,2,group)
 box('Window_sill',(x,y-.27,z-.12),(w+.8,.75,.3),2,group)
 box('Window_mullion',(x,y-.17,z+h*.46),(.14,.15,h*.90),2,group)
 box('Window_crossbar',(x,y-.17,z+h*.42),(w,.15,.13),2,group)
 if door:
  box('Door_lower_panel',(x,y-.19,z+.65),(w-.28,.14,1.1),11,group)
  ellipsoid('Door_brass_handle',(x+.34,y-.32,z+1.55),(.10,.10,.1),14,group,8,4)
 else:
  for sign in [-1,1]:
   box('Window_reflection',(x+sign*w*.24,y-.135,z+h*.39),(w*.3,.025,h*.47),10,group)
 if balcony:
  box('Balcony_base',(x,y-1,z-.3),(w+1.4,2,.35),2,group)
  beam('Balcony_rail',(x-w*.7,y-1.9,z+1.7),(x+w*.7,y-1.9,z+1.7),.09,8,group)
  for i in range(7):
   xx=x-w*.7+w*1.4*i/6;beam('Balcony_baluster',(xx,y-1.9,z),(xx,y-1.9,z+1.7),.055,8,group,6)
def hiproof(w,d,z,h,cat,group):
 vs=[(-w/2,-.7,z),(w/2,-.7,z),(w/2,d+.7,z),(-w/2,d+.7,z),(-w*.25,d/2,z+h),(w*.25,d/2,z+h)]
 fs=[(0,1,5,4),(1,2,5),(2,3,4,5),(3,0,4),(3,2,1,0)]
 mesh('Hipped_tiled_roof',vs,fs,cat,group)
 beam('Roof_ridge',(-w*.25,d/2,z+h),(w*.25,d/2,z+h),.18,cat,group)
 for x in [-w/2,w/2]:
  target=(-w*.25 if x<0 else w*.25,d/2,z+h)
  for y in [-.7,d+.7]:beam('Roof_hip_seam',(x,y,z),target,.10,cat,group,6)
def text_obj(name,body,loc,size,cat,group):
 cu=bpy.data.curves.new(name,'FONT');cu.body=body;cu.size=size;cu.extrude=.016;cu.resolution_u=2;cu.align_x='CENTER'
 path=r'C:\Windows\Fonts\georgiab.ttf'
 if os.path.exists(path):
  font=bpy.data.fonts.get('Georgia Bold') or bpy.data.fonts.load(path);cu.font=font
 ob=bpy.data.objects.new(name,cu);collection(group).objects.link(ob);ob.location=loc;ob.rotation_euler=(pi/2,0,0)
 bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob;bpy.ops.object.convert(target='MESH')
 ob.data.materials.append(MAT);atlas_uv(ob,cat);return ob
def join_group(group,name):
 obs=[o for o in collection(group).objects if o.type=='MESH']
 if not obs:return None
 bpy.ops.object.select_all(action='DESELECT')
 for o in obs:o.select_set(True)
 bpy.context.view_layer.objects.active=obs[0]
 if len(obs)>1:bpy.ops.object.join()
 ob=obs[0];ob.name=name
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 return ob
def camera(name,loc,target,lens=45):
 d=bpy.data.cameras.new(name);o=bpy.data.objects.new(name,d);collection('90_Presentation').objects.link(o);o.location=loc;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();d.lens=lens;d.clip_end=2500;return o
def area(name,loc,target,power,color,size):
 d=bpy.data.lights.new(name,'AREA');d.energy=power;d.color=color;d.shape='DISK';d.size=size
 o=bpy.data.objects.new(name,d);collection('90_Presentation').objects.link(o);o.location=loc;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
