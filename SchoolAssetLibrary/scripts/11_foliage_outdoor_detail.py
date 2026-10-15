select_asset('Indoor broadleaf')
oldleaves=[o for o in COL.objects if 'Broad waxy leaf' in o.name]
for idx,old in enumerate(oldleaves):
 a=old.data.vertices[0].co.copy();b=old.data.vertices[3].co.copy();direction=b-a;side=direction.cross(Vector((0,0,1))).normalized();width=.10
 vs=[];rows=16;cols=6
 for i in range(rows+1):
  t=i/rows;center=a+direction*t+Vector((0,0,.045*sin(pi*t)));wid=width*(sin(pi*t)**.72)
  for j in range(cols+1):
   u=2*j/cols-1;v=center+side*wid*u;v.z-=.025*u*u*sin(pi*t);vs.append(tuple(v))
 fs=[(i*(cols+1)+j,i*(cols+1)+j+1,(i+1)*(cols+1)+j+1,(i+1)*(cols+1)+j) for i in range(rows) for j in range(cols)]
 material=old.data.materials[0];bpy.data.objects.remove(old,do_unlink=True);mesh('Sculpted broadleaf blade',vs,fs,material,smooth=True)
 line=[tuple(a+direction*(i/30)+Vector((0,0,.045*sin(pi*i/30)+.001))) for i in range(31)]
 tube('Leaf midrib',line,.0015,'leaflight')
 for t in [.22,.36,.50,.64,.77]:
  center=a+direction*t+Vector((0,0,.045*sin(pi*t)+.001))
  for sign in [-1,1]:
   end=a+direction*(t+.11)+side*(sign*width*sin(pi*t)*.82)+Vector((0,0,.022*sin(pi*t)))
   tube('Leaf secondary vein',[tuple(center),tuple((center+end)*.5+direction*.018),tuple(end)],.00055,'leaflight')

def cover_canopies(objects,density=65,leafsize=.12):
 vs=[];fs=[];indices=[]
 for ob in objects:
  # Ellipsoid surface seeded with small curved leaf blades.
  sx=max(abs(v.co.x) for v in ob.data.vertices);sy=max(abs(v.co.y) for v in ob.data.vertices);sz=max(abs(v.co.z) for v in ob.data.vertices)
  for i in range(density):
   z=1-2*(i+.5)/density;a=i*2.399+random.random()*.28;r=math.sqrt(max(0,1-z*z));normal=Vector((r*cos(a),r*sin(a),z));center=ob.location+Vector((sx*normal.x,sy*normal.y,sz*normal.z))
   tangent=normal.cross(Vector((0,0,1)))
   if tangent.length<.01:tangent=Vector((1,0,0))
   tangent.normalize();side=normal.cross(tangent).normalized();length=leafsize*(.7+.6*random.random());width=length*.35
   points=[center-tangent*length*.5,center-tangent*length*.17+side*width,center+tangent*length*.26+side*width*.72,center+tangent*length*.57,center+tangent*length*.26-side*width*.72,center-tangent*length*.17-side*width,center+normal*.022]
   off=len(vs);vs.extend(tuple(p) for p in points)
   for j in range(6):fs.append((off+j,off+(j+1)%6,off+6));indices.append(i%3)
 o=mesh('Layered individual foliage',vs,fs,'leaf',smooth=True);o.data.materials.append(MAT['leaflight']);o.data.materials.append(MAT['leafdark'])
 for p,idx in zip(o.data.polygons,indices):p.material_index=idx
 return o
for frag,density,size in [('Broadleaf school tree',140,.23),('Outdoor shrub planter',45,.105),('Outdoor round shrub',60,.12)]:
 select_asset(frag);crowns=[o for o in COL.objects if o.type=='MESH' and any(s in o.name for s in ['crown','Dense rounded shrub'])]
 for ob in crowns:
  mod=ob.modifiers.new('Smooth botanical crown','SUBSURF');mod.subdivision_type='CATMULL_CLARK';mod.levels=1;mod.render_levels=2
 cover_canopies(crowns,density,size)
 if 'planter' in frag:
  for i in range(70):
   x=random.uniform(-.74,.74);y=random.uniform(-.16,.16);ball('Planter surface pebble',(x,y,.498),(random.uniform(.006,.016),.011,.007),'bark',8,6)

select_asset('Evergreen school tree')
vs=[];fs=[]
for tier,(radius,z,h) in enumerate([(1.05,.75,1.4),(.87,1.45,1.3),(.64,2.1,1.2),(.41,2.78,1.)]):
 for i in range(110):
  t=random.uniform(.05,.87);a=i*2.399;rrad=radius*(1-t)**.85
  centre=Vector((rrad*cos(a),rrad*sin(a),z+h*t));tangent=Vector((-sin(a),cos(a),0));radial=Vector((cos(a),sin(a),.3));size=.13*(1-t*.35)
  off=len(vs);vs.extend([tuple(centre-tangent*size),tuple(centre+radial*size*.8+Vector((0,0,.14))),tuple(centre+tangent*size),tuple(centre+Vector((0,0,.025)))])
  fs.extend([(off,off+1,off+3),(off+1,off+2,off+3)])
mesh('Dense layered conifer tips',vs,fs,'leaf',smooth=True)

for frag in ['Outdoor backed bench','Outdoor backless bench']:
 select_asset(frag);length=1.85 if 'backed' in frag else 1.65
 for ob in [o for o in COL.objects if 'Ash seat slat' in o.name]:
  for x in [-length*.37,length*.37]:screw('Seat slat carriage bolt',(x,ob.location.y,.497),(0,0,1),.006)
  for x in [-length*.5,length*.5]:
   side=box('Slat exposed endgrain',(x,ob.location.y,ob.location.z),(.0015,.084,.041),'endgrain',.003)
 for ob in [o for o in COL.objects if 'Ash back slat' in o.name]:
  for x in [-length*.37,length*.37]:screw('Backrest slat bolt',(x,ob.location.y-.03,ob.location.z),(0,-1,.23),.006)
 for x in [-length*.37,length*.37]:
  for y in [-.25,.25]:
   box('Steel foot mounting plate',(x,y,.015),(.12,.10,.018),'black',.010)
   for dx in [-.036,.036]:screw('Ground fixing',(x+dx,y,.025),(0,0,1),.007)
print('Sculpted veined leaves, layered tree and shrub foliage, bench fasteners and endgrain completed')
