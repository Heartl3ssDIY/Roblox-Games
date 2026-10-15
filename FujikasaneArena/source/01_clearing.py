exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\FujikasaneArena\source\common.py',encoding='utf-8').read(),'common.py','exec'))
sc=bpy.context.scene if bpy.context.scene.name=='Mount Fujikasane | Final Selection' and not bpy.context.scene.objects else bpy.data.scenes.new('Mount Fujikasane | Final Selection');bpy.context.window.scene=sc
sc.unit_settings.system='NONE'
try:sc.render.engine='BLENDER_EEVEE'
except TypeError:pass
MAT=make_atlas()
# Flat central clearing with irregular rising woodland perimeter.
vs=[(0,0,0)];fs=[];n=96;nr=22
for j in range(1,nr+1):
 t=j/nr
 for i in range(n):
  a=2*pi*i/n;w=1+.027*sin(a*7)+.018*cos(a*11)
  x=79*t*w*cos(a);y=104*t*w*sin(a);vs.append((x,y,ground_height(x,y)))
for i in range(n):fs.append((0,1+i,1+(i+1)%n))
for j in range(nr-1):
 for i in range(n):
  a=1+j*n+i;b=1+j*n+(i+1)%n;fs.extend([(a,b,b+n),(a,b+n,a+n)])
mesh('Forest_earth',vs,fs,0,'01_Terrain')
rim=Builder();start=1+(nr-1)*n
for i in range(n):
 p=vs[start+i];q=vs[start+(i+1)%n]
 rim.face([p,(p[0]*.98,p[1]*.98,-7),(q[0]*.98,q[1]*.98,-7),q],3)
rim.build('Earthen_cutaway_edge','01_Terrain')
for row in range(47):
 y=-75+row*3.2
 for col in range(5):
  x=(col-2)*2.7
  ob=box('Weathered_path_slab',(x,y,.025),(2.58,3.03,.07),1,'02_Stone_Path',.045)
  ob.rotation_euler.z=random.uniform(-.006,.006)
for i in range(6):
 y=-84+i*1.35
 box('Approach_stone_step',(0,y,-2.4+(i+1)*.4-.22),(15,1.4,.44),1,'03_Stone_Stairs',.08)
for side in [-1,1]:
 for i in range(16):
  x=side*(43+i*.4);y=58+i*1.65;top=.45+i*.63
  box('Forest_ascent_step',(x,y,top-.28),(12,1.72,.56),1,'03_Stone_Stairs',.1)
 for edge in [-1,1]:
  pts=[(side*(43+i*.4)+edge*6.3,58+i*1.65,.65+i*.63) for i in range(16)]
  tube('Ascent_stone_curbstones',pts,.3,2,'03_Stone_Stairs',6)
# Moss and small ground-cover islands, all clear of the central fighting area.
moss=Builder()
for i in range(290):
 side=random.choice([-1,1]);x=side*random.uniform(35,73);y=random.uniform(-80,88)
 if (x/77)**2+(y/102)**2>.94:continue
 z=ground_height(x,y)+.025;r=random.uniform(.45,2.6);pts=[]
 for k in range(9):
  a=2*pi*k/9;rr=r*random.uniform(.7,1.2);xx=x+rr*cos(a);yy=y+rr*sin(a)
  pts.append((xx,yy,ground_height(xx,yy)+.03))
 center=(x,y,z)
 for k in range(9):moss.face([center,pts[k],pts[(k+1)%9]],8 if i%3 else 9)
moss.build('Soft_moss_patches','04_Undergrowth')
for side in [-1,1]:
 for cluster,y in enumerate([-51,-12,24,61]):
  for i in range(6):
   x=side*random.uniform(47,65);yy=y+random.uniform(-8,8)
   rock('Weathered_boundary_boulder',(x,yy,ground_height(x,yy)),(random.uniform(3,7),random.uniform(3,6),random.uniform(3,8)),'05_Rock_Outcrops',70+cluster*21+i+(side+1)*41)
# Small rear ceremonial stone.
rock('Ceremonial_stone',(0,74,.7),(6.1,3.6,4.2),'06_Rear_Ceremony',928,2)
for i in range(3):box('Ceremony_step',(0,65+i*2,.15+i*.23),(18,2.05,.45),1,'06_Rear_Ceremony',.12)
# Tall standalone vermilion posts.
def post(x,y,h,r,group):
 lathe('Post_stone_foot',[(0,0),(r*1.5,0),(r*1.5,.45),(r*1.15,.6),(0,.6)],(x,y,.02),2,group,12)
 lathe('Vermilion_pillar',[(0,.5),(r,.5),(r,h-.2),(r*.88,h),(0,h)],(x,y,0),4,group,48)
 lathe('Black_post_cap',[(0,h-.05),(r*1.05,h-.05),(r*1.05,h+.25),(r*.94,h+.4),(0,h+.4)],(x,y,0),5,group,48)
 for zz in [h-1.2,h-4.7]:
  pts=[(x+(r+.045)*cos(t*2*pi),y+(r+.045)*sin(t*2*pi),zz+.45*sin(t*2*pi)) for t in np.linspace(0,1,49)]
  tube('Black_rope_binding',pts,.09,5,group,6)
posts=[(-38,-43),(38,-43),(-40,0),(40,0),(-38,43),(38,43)]
for x,y in posts:post(x,y,26,1.35,'07_Vermilion_Posts')
for x in [-9,9]:post(x,68,17.5,.8,'06_Rear_Ceremony')
def banner(name,center,tangent,w,h,group,seed):
 rng=random.Random(seed);cx,cy,cz=center;t=Vector(tangent).normalized();perp=Vector((-t.y,t.x,0));verts=[];faces=[];nu=6;nv=4
 for j in range(nv+1):
  v=j/nv
  for i in range(nu+1):
   u=i/nu;p=Vector((cx,cy,cz))+t*((u-.5)*w)+Vector((0,0,-v*h))
   p+=perp*(.12*sin(u*pi*2+seed)*sin(v*pi/2)+.14*v*v)
   verts.append(tuple(p))
 for j in range(nv):
  for i in range(nu):
   a=j*(nu+1)+i;faces.append((a,a+1,a+nu+2,a+nu+1));faces.append((a+nu+1,a+nu+2,a+1,a))
 ob=mesh(name,verts,faces,6,group);uv=ob.data.uv_layers.active
 for p in ob.data.polygons:
  for li in p.loop_indices:
   vi=ob.data.loops[li].vertex_index;j,i=divmod(vi,nu+1);u=i/nu;v=1-j/nv
   uv.data[li].uv=((2+.018+.964*u)/4,(1+.018+.964*v)/4)
 return ob
def rope_flags(a,b,sag,flags,group,seed):
 a=Vector(a);b=Vector(b);pts=[]
 def pt(t):return a.lerp(b,t)+Vector((0,0,-sag*4*t*(1-t)))
 for t in np.linspace(0,1,61):pts.append(tuple(pt(t)))
 tube('Sagging_ceremonial_rope',pts,.095,5,group,6)
 for i in range(flags):
  t=(i+1)/(flags+1);p=pt(t);direction=b-a;direction.z=0
  banner('White_floral_banner',p,direction,3.0 if flags>6 else 2.5,3.2 if flags>6 else 2.6,group,seed+i)
rope_flags((-38,-43,24),(38,-43,24),4.8,15,'08_Banner_Ropes',10)
rope_flags((-38,43,24),(38,43,24),4.6,15,'08_Banner_Ropes',40)
for side in [-1,1]:
 rope_flags((side*38,-43,23),(side*40,0,23),3.2,8,'08_Banner_Ropes',70+(side+1)*9)
 rope_flags((side*40,0,23),(side*38,43,23),3.2,8,'08_Banner_Ropes',110+(side+1)*9)
rope_flags((-9,68,16),(9,68,16),1.2,5,'06_Rear_Ceremony',151)
# Twigs, grass and petal scatter follow the perimeter rather than fill the combat area.
grass=Builder()
for k in range(450):
 x=random.choice([-1,1])*random.uniform(34,74);y=random.uniform(-85,88)
 if (x/77)**2+(y/102)**2>.95:continue
 z=ground_height(x,y)+.035
 for j in range(3):
  a=random.uniform(0,2*pi);w=random.uniform(.06,.15);h=random.uniform(.3,.85)
  grass.face([(x-w*cos(a),y-w*sin(a),z),(x+w*cos(a),y+w*sin(a),z),(x+.24*cos(a+.7),y+.24*sin(a+.7),z+h)],8 if k%3 else 9,True)
grass.build('Woodland_grass','04_Undergrowth')
# Cameras and cool evening light.
world=bpy.data.worlds.new('Fujikasane | blue twilight');sc.world=world;world.use_nodes=True
bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.022,.028,.065,1);bg.inputs['Strength'].default_value=.45
area('FK_Moon_Key',(-50,-40,115),(0,0,0),160000,(.65,.72,1),70)
area('FK_Clearing_Fill',(20,-95,65),(0,15,0),115000,(.77,.72,1),75)
area('FK_Forest_Rim',(0,80,70),(0,0,10),180000,(.67,.54,1),65)
hero=camera('FK_Camera_Hero',(112,-181,158),(0,2,9),44);sc.camera=hero
camera('FK_Camera_Approach',(0,-112,17),(0,28,16),26)
top=camera('FK_Camera_Top',(0,0,245),(0,0,0));top.data.type='ORTHO';top.data.ortho_scale=226
sc.render.resolution_x=1700;sc.render.resolution_y=1400;sc.render.resolution_percentage=100;sc.render.image_settings.file_format='PNG';sc.view_settings.view_transform='AgX';sc.view_settings.look='None'
sc.render.filepath=os.path.join(ROOT,'previews','Fujikasane_Structure.png')
bpy.data.libraries.write(os.path.join(ROOT,'Fujikasane_Arena.blend'),{sc},fake_user=True,compress=True)
print('Clearing, posts, banners and stone paths built',len(sc.objects))
