import bpy, bmesh, math, random, os, json
import numpy as np
from mathutils import Vector, Matrix
from math import sin, cos, pi
ROOT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\TenkaichiArena'
random.seed(2718)
PALETTE=[(231,219,188),(171,49,32),(183,137,60),(178,195,193),(39,65,128),(192,166,123),(100,57,31),(81,134,49),(33,92,49),(112,153,53),(208,186,136),(35,128,145),(231,175,48),(205,59,47),(36,41,34),(246,232,196)]
def collection(name):
 c=bpy.data.collections.get(name)
 if c is None:
  c=bpy.data.collections.new(name); bpy.context.scene.collection.children.link(c)
 return c
def make_atlas():
 size=2048; tile=512
 rng=np.random.default_rng(91); pixels=np.ones((size,size,4),dtype=np.float32)
 yy,xx=np.mgrid[0:tile,0:tile]; x=xx/tile; y=yy/tile
 for k,color in enumerate(PALETTE):
  noise=rng.normal(0,1,(tile,tile))
  broad=(np.sin(x*24+y*7)+np.cos(x*43-y*28)+np.sin(x*73+y*83))*.008
  shade=1+broad+noise*.012
  if k==2:
   line=rng.uniform(-.18,.18,tile)
   shade=1+line[None,:]+.055*np.sin(xx*.66+np.sin(y*9)*1.4)+noise*.025
   shade-=.06*(np.sin(y*19)>0.9)
  if k==6:
   shade=1+.10*np.sin(xx*.09+3*np.sin(y*5))+.05*np.sin(xx*.33+np.sin(y*8))+noise*.02
  if k in [0,3,5]:
   shade+=.016*np.sin(x*160+y*117)
   edge=np.minimum.reduce([x,1-x,y,1-y]); shade+=np.maximum(0,.045-edge)*1.1
  if k in [7,8,9]: shade+=.025*np.sin(xx*.12+yy*.09)
  if k in [1,4,11,12,13]: shade+=.013*np.sin(xx*1.7)*np.cos(yy*1.7)
  rgb=np.clip(np.array(color)[None,None,:]/255*shade[:,:,None],0,1)
  row=k//4; col=k%4; pixels[row*tile:(row+1)*tile,col*tile:(col+1)*tile,:3]=rgb
 img=bpy.data.images.new('Arena_ColorAtlas_2048',width=size,height=size,alpha=False)
 img.pixels.foreach_set(pixels.ravel()); img.filepath_raw=os.path.join(ROOT,'textures','Arena_ColorAtlas.png'); img.file_format='PNG'; img.save(); img.pack()
 mat=bpy.data.materials.new('Arena | shared textured palette'); mat.use_nodes=True
 bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
 bs.inputs['Roughness'].default_value=.82
 tex=mat.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=img
 mat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
 return mat
MAT=bpy.data.materials.get('Arena | shared textured palette')
def mesh(name,verts,faces,cat,group,smooth=False):
 me=bpy.data.meshes.new(name); me.from_pydata(verts,[],faces); me.update()
 bm=bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(me); bm.free(); me.update()
 ob=bpy.data.objects.new(name,me); collection(group).objects.link(ob); me.materials.append(MAT)
 ob['surface']=cat; ob['module']=group; ob.color=tuple(v/255 for v in PALETTE[cat])+(1,)
 atlas_uv(ob,cat)
 for p in me.polygons: p.use_smooth=smooth
 return ob
def atlas_uv(ob,cat):
 me=ob.data; uv=me.uv_layers.new(name='UVMap') if not me.uv_layers else me.uv_layers.active
 coords=[v.co for v in me.vertices]
 lo=[min(v[i] for v in coords) for i in range(3)]; hi=[max(v[i] for v in coords) for i in range(3)]
 for p in me.polygons:
  dominant=max(range(3),key=lambda i:abs(p.normal[i])); axes=([1,2] if dominant==0 else [0,2] if dominant==1 else [0,1])
  for li in p.loop_indices:
   v=me.vertices[me.loops[li].vertex_index].co
   q=[(v[a]-lo[a])/max(hi[a]-lo[a],.001) for a in axes]
   uv.data[li].uv=((cat%4+.012+q[0]*.976)/4,(cat//4+.012+q[1]*.976)/4)
def box(name,loc,dim,cat,group,bevel=0):
 x,y,z=[v/2 for v in dim]
 verts=[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]
 faces=[(3,2,1,0),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)]
 ob=mesh(name,verts,faces,cat,group); ob.location=loc
 if bevel:
  bm=bmesh.new(); bm.from_mesh(ob.data); bmesh.ops.bevel(bm,geom=list(bm.edges),offset=bevel,segments=1); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(ob.data); bm.free(); ob.data.update(); atlas_uv(ob,cat)
 return ob
def ellipsoid(name,loc,scale,cat,group,seg=16,rings=8):
 verts=[(0,0,scale[2])]; faces=[]
 for j in range(1,rings):
  a=pi*j/rings
  for i in range(seg):
   b=2*pi*i/seg; verts.append((scale[0]*sin(a)*cos(b),scale[1]*sin(a)*sin(b),scale[2]*cos(a)))
 verts.append((0,0,-scale[2])); end=len(verts)-1
 for i in range(seg): faces.append((0,1+i,1+(i+1)%seg))
 for j in range(rings-2):
  for i in range(seg):
   a=1+j*seg+i; b=1+j*seg+(i+1)%seg; faces.append((a,b,b+seg,a+seg))
 for i in range(seg): faces.append((end,end-seg+(i+1)%seg,end-seg+i))
 ob=mesh(name,verts,faces,cat,group,True); ob.location=loc; return ob
def tube(name,points,radii,cat,group,sides=8):
 verts=[]; faces=[]
 for j,pt in enumerate(points):
  p=Vector(pt); t=Vector(points[min(j+1,len(points)-1)])-Vector(points[max(0,j-1)])
  t.normalize(); ref=Vector((0,0,1)) if abs(t.z)<.95 else Vector((0,1,0)); u=t.cross(ref).normalized(); v=t.cross(u).normalized()
  r=radii[j] if isinstance(radii,(list,tuple)) else radii
  for i in range(sides): verts.append(tuple(p+r*(cos(i*2*pi/sides)*u+sin(i*2*pi/sides)*v)))
 for j in range(len(points)-1):
  for i in range(sides): a=j*sides+i; b=j*sides+(i+1)%sides; faces.append((a,b,b+sides,a+sides))
 faces.append(tuple(reversed(range(sides)))); faces.append(tuple((len(points)-1)*sides+i for i in range(sides)))
 return mesh(name,verts,faces,cat,group,True)
def beam(name,a,b,r,cat,group,sides=8): return tube(name,[a,b],[r,r],cat,group,sides)
def extrude_profile(name,coords,y,depth,cat,group):
 verts=[(x,y-depth/2,z) for x,z in coords]+[(x,y+depth/2,z) for x,z in coords]; n=len(coords)
 faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 return mesh(name,verts,faces,cat,group)
def join_group(group,name=None):
 obs=[o for o in collection(group).objects if o.type=='MESH']
 if not obs:return
 bpy.ops.object.select_all(action='DESELECT')
 for o in obs:o.select_set(True)
 bpy.context.view_layer.objects.active=obs[0]; bpy.ops.object.join(); ob=obs[0]; ob.name=name or group
 return ob
def text_obj(name,body,loc,size,cat,group,font=None):
 cu=bpy.data.curves.new(name,'FONT'); cu.body=body; cu.size=size; cu.extrude=.012; cu.resolution_u=3
 if font:cu.font=font
 ob=bpy.data.objects.new(name,cu); collection(group).objects.link(ob); ob.location=loc; ob.rotation_euler=(pi/2,0,0)
 bpy.context.view_layer.update(); ob.location.x-=ob.dimensions.x/2
 bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); bpy.context.view_layer.objects.active=ob; bpy.ops.object.convert(target='MESH')
 ob.data.materials.clear(); ob.data.materials.append(MAT); ob['surface']=cat; atlas_uv(ob,cat); return ob
def camera(name,loc,target,lens=45):
 d=bpy.data.cameras.new(name); ob=bpy.data.objects.new(name,d); collection('90_Presentation').objects.link(ob); ob.location=loc; ob.rotation_euler=(Vector(target)-Vector(loc)).to_track_quat('-Z','Y').to_euler(); d.lens=lens; d.clip_end=2000; return ob
def screenshot_view():
 sc=bpy.context.scene
 for screen in bpy.data.screens:
  for a in screen.areas:
   if a.type=='VIEW_3D':
    a.spaces.active.region_3d.view_perspective='CAMERA'; a.spaces.active.overlay.show_overlays=False; a.spaces.active.shading.type='MATERIAL'
