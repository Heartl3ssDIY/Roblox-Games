# Use the supplied alpha as real transparency, so no rectangular badge is visible.
LOGO.name='School | Supplied bird emblem — transparent';nodes=LOGO.node_tree.nodes
p=next(n for n in nodes if n.type=='BSDF_PRINCIPLED');tex=next(n for n in nodes if n.type=='TEX_IMAGE')
for li in list(LOGO.node_tree.links):
 if li.to_node==p and li.to_socket==p.inputs['Base Color']:LOGO.node_tree.links.remove(li)
p.inputs['Base Color'].default_value=(.93,.93,.93,1)
LOGO.node_tree.links.new(tex.outputs['Alpha'],p.inputs['Alpha']);LOGO.surface_render_method='DITHERED'

def natural_leaf_coverage(objects,count,size):
 vs=[];fs=[];indices=[]
 for ob in objects:
  sx=max(abs(v.co.x) for v in ob.data.vertices);sy=max(abs(v.co.y) for v in ob.data.vertices);sz=max(abs(v.co.z) for v in ob.data.vertices)
  for i in range(count):
   zz=random.uniform(-1,1);aa=random.uniform(0,2*pi);rad=math.sqrt(1-zz*zz);normal=Vector((rad*cos(aa),rad*sin(aa),zz));centre=ob.location+Vector((sx*normal.x,sy*normal.y,sz*normal.z))*random.uniform(.88,1.08)
   tangent=normal.cross(Vector((0,0,1)))
   if tangent.length<.001:tangent=Vector((1,0,0))
   tangent.normalize();side=normal.cross(tangent).normalized();angle=random.uniform(-pi,pi);along=tangent*cos(angle)+side*sin(angle);across=normal.cross(along).normalized();length=size*random.uniform(.7,1.3);width=length*.26
   off=len(vs);steps=7
   for k in range(steps+1):
    t=k/steps;cen=centre+along*(t-.5)*length+normal*(.030*sin(pi*t));w=width*sin(pi*t)**.85
    vs.extend([tuple(cen-across*w),tuple(cen+across*w)])
   for k in range(steps):fs.append((off+2*k,off+2*k+1,off+2*k+3,off+2*k+2));indices.append(random.choice([0,0,0,1,2]))
 o=mesh('Natural overlapping leaf canopy',vs,fs,'leaf',smooth=True);o.data.materials.append(MAT['leaflight']);o.data.materials.append(MAT['leafdark'])
 for poly,idx in zip(o.data.polygons,indices):poly.material_index=idx
 return o
for frag,num,size in [('Broadleaf school tree',680,.30),('Outdoor shrub planter',185,.115),('Outdoor round shrub',240,.14)]:
 select_asset(frag)
 for ob in [o for o in COL.objects if 'Layered individual foliage' in o.name]:bpy.data.objects.remove(ob,do_unlink=True)
 crowns=[o for o in COL.objects if o.type=='MESH' and any(s in o.name for s in ['crown','Dense rounded shrub'])]
 natural_leaf_coverage(crowns,num,size)
 for ob in crowns:ob.scale=(.84,.84,.84);ob.data.materials[0]=MAT['leafdark']
select_asset('Evergreen school tree')
for ob in [o for o in COL.objects if 'Dense layered conifer tips' in o.name]:bpy.data.objects.remove(ob,do_unlink=True)
vs=[];fs=[]
for ring in range(15):
 z=.82+ring*.19;radius=1.02*(1-(z-.75)/3.2)
 for j in range(16):
  a=j*2*pi/16+ring*.47;radial=Vector((cos(a),sin(a),-.18));tangent=Vector((-sin(a),cos(a),0))
  for k in range(12):
   t=.25+.75*k/11;centre=Vector((0,0,z))+radial*radius*t;wid=.12*(1-t*.55)
   off=len(vs);vs.extend([tuple(centre-tangent*wid),tuple(centre+radial*.19+Vector((0,0,.03))),tuple(centre+tangent*wid),tuple(centre+Vector((0,0,.026)))])
   fs.extend([(off,off+1,off+3),(off+1,off+2,off+3)])
o=mesh('Dense radiating conifer sprays',vs,fs,'leafdark',smooth=True);o.data.materials.append(MAT['leaf'])
for i,p in enumerate(o.data.polygons):p.material_index=1 if i%5==0 else 0
select_asset('Indoor broadleaf')
for ob in [o for o in COL.objects if 'Leaf secondary vein' in o.name]:bpy.data.objects.remove(ob,do_unlink=True)
for i,ob in enumerate([o for o in COL.objects if 'Sculpted broadleaf blade' in o.name]):
 # Place vein tips on the actual surface grid, never beyond the leaf margin.
 for row in [4,7,10,12]:
  mid=ob.data.vertices[row*7+3].co+Vector((0,0,.0008))
  for col in [1,5]:
   tip=ob.data.vertices[(row+1)*7+col].co+Vector((0,0,.0008));tube('Surface leaf vein',[tuple(mid),tuple(tip)],.00055,'leaflight')
select_asset('Graphite electric kettle')
for z in [.054,.242]:rod('Handle attachment',(.10,0,z),(.139,0,z),.014,'black',20)
# Smoother shading on all newly bevelled machined parts.
for ob in scene.objects:
 if ob.type=='MESH' and any(m.type=='BEVEL' for m in ob.modifiers):
  for poly in ob.data.polygons:poly.use_smooth=True
  if not any(m.type=='WEIGHTED_NORMAL' for m in ob.modifiers):ob.modifiers.new('Weighted surface normals','WEIGHTED_NORMAL')
print('Transparency, natural foliage coverage, vein placement and fittings refined')
