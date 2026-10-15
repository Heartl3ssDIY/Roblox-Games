import bpy, math, os, json, random
from mathutils import Vector
from math import sin,cos,pi
BASE=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\WrenSchoolAssets'
random.seed(42)
scene=bpy.data.scenes.new('Wren School | Asset Review 01')
bpy.context.window.scene=scene
scene.render.engine='BLENDER_EEVEE'
scene.render.resolution_x=1600;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.image_settings.color_mode='RGBA'
scene.render.film_transparent=False
scene.render.filepath=os.path.join(BASE,'renders','wren-overview.png')
MCP=bpy.data.collections.new('MCP');scene.collection.children.link(MCP)
LIB=bpy.data.collections.new('WREN | School assets — first review');MCP.children.link(LIB)
STAGE=bpy.data.collections.new('Presentation | cameras, lights, floor');scene.collection.children.link(STAGE)
CATS={};ASSETS=[];ROOT=None;COL=STAGE
def category(name):
 c=bpy.data.collections.new(name);LIB.children.link(c);CATS[name]=c;return c
for name in ['01 Stationery','02 Student seating','03 Staff seating','04 Music','05 Technology','06 Storage','07 Staffroom','08 Boards','09 Indoor plants','10 Outdoors']:category(name)
def asset(name,cat,loc):
 global ROOT,COL
 COL=bpy.data.collections.new('Wren | '+name);CATS[cat].children.link(COL)
 ROOT=bpy.data.objects.new('Wren_'+name.replace(' ','_'),None);COL.objects.link(ROOT);ROOT.location=loc
 ROOT['asset_name']=name;ROOT['category']=cat;ROOT['revision']='First review — editable source';ROOT['units']='metres'
 ASSETS.append({'name':name,'root':ROOT.name,'collection':COL.name,'category':cat})
 return ROOT
def mat(name,color,rough=.6,metal=0,texture=None):
 m=bpy.data.materials.new('Wren | '+name);m.use_nodes=True;m.diffuse_color=(*color,1)
 n=m.node_tree.nodes;p=next(x for x in n if x.type=='BSDF_PRINCIPLED');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
 if texture:
  tex=n.new('ShaderNodeTexNoise');tex.inputs['Scale'].default_value=65 if texture=='fabric' else 5;tex.inputs['Detail'].default_value=2
  coords=n.new('ShaderNodeTexCoord');mapping=n.new('ShaderNodeMapping');mapping.inputs['Scale'].default_value=(2,34,4) if texture=='wood' else (1,1,1)
  m.node_tree.links.new(coords.outputs['Generated'],mapping.inputs['Vector']);m.node_tree.links.new(mapping.outputs['Vector'],tex.inputs['Vector'])
  mix=n.new('ShaderNodeMixRGB');mix.inputs['Color1'].default_value=(*(v*.84 for v in color),1);mix.inputs['Color2'].default_value=(*(min(1,v*1.06) for v in color),1)
  m.node_tree.links.new(tex.outputs['Factor'],mix.inputs['Factor']);m.node_tree.links.new(mix.outputs['Color'],p.inputs['Base Color'])
  bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.11;bump.inputs['Distance'].default_value=.008 if texture=='wood' else .002
  m.node_tree.links.new(tex.outputs['Factor'],bump.inputs['Height']);m.node_tree.links.new(bump.outputs['Normal'],p.inputs['Normal'])
 return m
MAT={
 'black':mat('Graphite powder coat',(.023,.029,.036),.52),
 'rubber':mat('Soft black rubber',(.012,.015,.019),.88),
 'screen':mat('Blue black screen',(.014,.028,.042),.25),
 'sand':mat('Sand shell',(.62,.46,.34),.66),
 'ivory':mat('Warm ivory',(.79,.72,.61),.58),
 'taupe':mat('Mushroom taupe',(.39,.31,.27),.7),
 'clay':mat('Muted clay',(.51,.31,.25),.65),
 'fabric':mat('Oatmeal woven fabric',(.64,.51,.4),.91,texture='fabric'),
 'fabricdark':mat('Warm taupe upholstery',(.31,.24,.21),.92,texture='fabric'),
 'wood':mat('Smoked oak',(.34,.21,.12),.65,texture='wood'),
 'woodlight':mat('Natural ash',(.62,.43,.25),.64,texture='wood'),
 'pink':mat('Dusty pink eraser',(.72,.30,.38),.87),
 'metal':mat('Brushed steel',(.35,.4,.43),.36,.72),
 'brass':mat('Muted brass',(.39,.27,.12),.36,.65),
 'white':mat('Porcelain white',(.88,.88,.82),.29),
 'board':mat('Warm white enamel',(.88,.9,.87),.37),
 'leaf':mat('Forest foliage',(.055,.14,.075),.9),
 'leaflight':mat('Sage foliage',(.14,.25,.13),.87),
 'leafdark':mat('Deep green foliage',(.032,.079,.04),.94),
 'soil':mat('Potting soil',(.046,.028,.019),1),
 'bark':mat('Bark',(.19,.104,.052),.94,texture='wood'),
 'floor':mat('Gallery warm grey',(.24,.26,.27),.82),
 'plinth':mat('Display stone',(.38,.40,.41),.85),
}
def link(ob,material=None,loc=(0,0,0)):
 COL.objects.link(ob)
 if ROOT:ob.parent=ROOT
 ob.location=loc
 if material:ob.data.materials.append(MAT[material] if isinstance(material,str) else material)
 return ob
def mesh(name,verts,faces,material,loc=(0,0,0),smooth=False):
 m=bpy.data.meshes.new(name+' mesh');m.from_pydata(verts,[],faces);m.update();o=bpy.data.objects.new(name,m);link(o,material,loc)
 if smooth:
  for p in m.polygons:p.use_smooth=True
 return o
def bevel(o,width=.02,segments=3):
 mod=o.modifiers.new('Soft manufactured edges','BEVEL');mod.width=width;mod.segments=segments
 return o
def box(name,loc,size,material,rounding=.015):
 x,y,z=[v/2 for v in size]
 vs=[(-x,-y,-z),(-x,-y,z),(-x,y,-z),(-x,y,z),(x,-y,-z),(x,-y,z),(x,y,-z),(x,y,z)]
 o=mesh(name,vs,[(0,4,6,2),(1,3,7,5),(0,1,5,4),(2,6,7,3),(0,2,3,1),(4,5,7,6)],material,loc)
 if rounding:bevel(o,min(rounding,min(size)*.45))
 return o
def lathe(name,profile,material,loc=(0,0,0),n=32,smooth=True):
 vs=[(r*cos(2*pi*j/n),r*sin(2*pi*j/n),z) for r,z in profile for j in range(n)];fs=[]
 for i in range(len(profile)-1):
  for j in range(n):a=i*n+j;b=i*n+(j+1)%n;fs.append((a,b,b+n,a+n))
 return mesh(name,vs,fs,material,loc,smooth)
def cylinder(name,loc,r,depth,material,n=20,r2=None):
 r2=r if r2 is None else r2
 return lathe(name,[(0,-depth/2),(r,-depth/2),(r2,depth/2),(0,depth/2)],material,loc,n)
def rod(name,a,b,r,material,n=12,r2=None):
 a,b=Vector(a),Vector(b);o=cylinder(name,(a+b)/2,r,(b-a).length,material,n,r2);o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o
def ball(name,loc,scale,material,n=16,rings=10):
 vs=[]
 for i in range(rings+1):
  t=pi*i/rings
  for j in range(n):p=2*pi*j/n;vs.append((scale[0]*sin(t)*cos(p),scale[1]*sin(t)*sin(p),scale[2]*cos(t)))
 fs=[(i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j) for i in range(rings) for j in range(n)]
 return mesh(name,vs,fs,material,loc,True)
def tube(name,points,r,material,cyclic=False):
 c=bpy.data.curves.new(name+' curve','CURVE');c.dimensions='3D';c.bevel_depth=r;c.bevel_resolution=2;c.resolution_u=12
 sp=c.splines.new('POLY');sp.points.add(len(points)-1)
 for p,co in zip(sp.points,points):p.co=(*co,1)
 sp.use_cyclic_u=cyclic;o=bpy.data.objects.new(name,c);return link(o,material)
def text(name,words,loc,size,material='ivory',rot=(pi/2,0,0),align='CENTER'):
 c=bpy.data.curves.new(name+' text','FONT');c.body=words;c.size=size;c.align_x=align;c.extrude=.0003
 o=bpy.data.objects.new(name,c);link(o,material,loc);o.rotation_euler=rot;return o
def outline(name,points,depth,material,loc=(0,0,0),rounding=.005):
 vs=[(x,-depth/2,z) for x,z in points]+[(x,depth/2,z) for x,z in points];n=len(points)
 fs=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(j,(j+1)%n,(j+1)%n+n,j+n) for j in range(n)]
 o=mesh(name,vs,fs,material,loc)
 if rounding:bevel(o,rounding)
 return o
def leaf(name,a,b,width,material='leaf'):
 a,b=Vector(a),Vector(b);v=b-a;side=v.cross(Vector((0,0,1)))
 if side.length<.01:side=Vector((1,0,0))
 side.normalize();mid=a+v*.5
 vs=[tuple(a),tuple(a+v*.32+side*width*.85),tuple(a+v*.7+side*width*.6),tuple(b),tuple(a+v*.7-side*width*.6),tuple(a+v*.32-side*width*.85),tuple(mid+Vector((0,-.025,.015)))]
 return mesh(name,vs,[(i,(i+1)%6,6) for i in range(6)],material,smooth=True)
def cam(name,loc,target,scale):
 d=bpy.data.cameras.new(name);o=bpy.data.objects.new(name,d);STAGE.objects.link(o);o.location=loc;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();d.type='ORTHO';d.ortho_scale=scale;d.lens=52;return o
def area(name,loc,power,size,target):
 d=bpy.data.lights.new(name,'AREA');o=bpy.data.objects.new(name,d);STAGE.objects.link(o);o.location=loc;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();d.energy=power;d.shape='DISK';d.size=size
ROOT=None;COL=STAGE
box('Gallery floor',(6,9,-.14),(48,46,.25),'floor',.02)
area('Key | large softbox',(1,-4,15),3600,10,(6,8,0))
area('Fill | cool softbox',(17,8,11),2700,9,(5,7,0))
area('Rim | daylight',(2,22,13),4200,8,(6,10,0))
w=bpy.data.worlds.new('Wren studio ambient');w.use_nodes=True;bg=next(n for n in w.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.45,.52,.6,1);bg.inputs['Strength'].default_value=.45;scene.world=w
scene.camera=cam('CAM | Full library',(26,-26,27),(6,8.5,1),26)
scene['project']='Wren School';scene['stage']='First asset review';scene['source_logo']='User-revised Wren-bird-white.png'
print('Wren library foundation created')
